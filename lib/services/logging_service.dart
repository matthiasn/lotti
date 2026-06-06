import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:intl/intl.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/database/slow_query_logging.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:path/path.dart' as p;

class LoggingService {
  bool _enableLogging = !isTestEnv;
  bool _enableSlowQueryLogging = false;
  final _dateFmt = DateFormat('yyyy-MM-dd');
  static const Duration _fileFlushInterval = Duration(milliseconds: 500);
  static const int _fileFlushLineThreshold = 40;
  static const String _generalLogStem = 'lotti';
  static const String _syncLogStem = 'sync';

  /// File stem for the shared daily error log. Every exception and every
  /// error-level event is mirrored here (in full) so all errors can be
  /// inspected in one place. Under normal operation this file stays empty.
  static const String _errorLogStem = 'error';

  /// Domains whose info-level events are routed to the sync log file instead
  /// of the general log. Exposed so `DomainLogger` can avoid duplicate writes.
  static const Set<String> syncFileDomains = <String>{'sync'};
  final Map<String, List<String>> _pendingFileLinesByStem =
      <String, List<String>>{};
  final Map<String, Timer> _fileFlushTimers = <String, Timer>{};

  /// Seam for scheduling the buffered-flush timer. Defaults to the real
  /// [Timer] constructor; tests override it so the 500 ms flush path can be
  /// driven deterministically under `fakeAsync` (whose virtual clock cannot
  /// otherwise advance a real `Timer`). Production behavior is identical to
  /// `Timer(duration, callback)` by default.
  @visibleForTesting
  Timer Function(Duration duration, void Function() callback) timerFactory =
      Timer.new;
  final Map<String, Future<void>> _fileDrains = <String, Future<void>>{};
  final List<Future<void>> _pendingWrites = <Future<void>>[];

  StreamSubscription<bool>? _loggingFlagSubscription;
  StreamSubscription<bool>? _slowQueryFlagSubscription;

  void _syncSlowQueryLoggingGate() {
    SlowQueryLoggingGate.isEnabled = _enableLogging && _enableSlowQueryLogging;
    // First-call stack capture rides on the slow-query gate. The gate
    // is binary, but stacks are only useful as a one-shot diagnostic;
    // they're tracked per unique statement so an enabled gate produces
    // exactly one stack per query shape per process. Disabling the
    // gate clears the seen-set via [SlowQueryLoggingGate.resetForTest]
    // is for tests only — a real toggle keeps the seen-set so callers
    // re-enabling mid-session don't get a second flood of stacks.
    SlowQueryLoggingGate.captureFirstCallStack =
        _enableLogging && _enableSlowQueryLogging;
  }

  /// Starts config-flag listeners and completes after both initial values have
  /// seeded the slow-query gate.
  ///
  /// Cancels any existing subscriptions first so a repeated call (e.g. hot
  /// restart or test re-init) does not leak the previous listeners.
  Future<void> listenToConfigFlag() async {
    await _loggingFlagSubscription?.cancel();
    await _slowQueryFlagSubscription?.cancel();

    final loggingReady = Completer<void>();
    final slowQueryReady = Completer<void>();
    var hasLoggingValue = false;
    var hasSlowQueryValue = false;

    void completeReady(Completer<void> completer) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    void completeReadyError(
      Completer<void> completer,
      Object error,
      StackTrace stackTrace,
    ) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }

    void syncGateWhenReady() {
      if (hasLoggingValue && hasSlowQueryValue) {
        _syncSlowQueryLoggingGate();
      }
    }

    _loggingFlagSubscription = getIt<JournalDb>()
        .watchConfigFlag(enableLoggingFlag)
        .listen(
          (value) {
            _enableLogging = value;
            hasLoggingValue = true;
            syncGateWhenReady();
            completeReady(loggingReady);
          },
          onError: (Object error, StackTrace stackTrace) {
            completeReadyError(loggingReady, error, stackTrace);
          },
          onDone: () => completeReady(loggingReady),
        );
    _slowQueryFlagSubscription = getIt<JournalDb>()
        .watchConfigFlag(logSlowQueriesFlag)
        .listen(
          (value) {
            _enableSlowQueryLogging = value;
            hasSlowQueryValue = true;
            syncGateWhenReady();
            completeReady(slowQueryReady);
          },
          onError: (Object error, StackTrace stackTrace) {
            completeReadyError(slowQueryReady, error, stackTrace);
          },
          onDone: () => completeReady(slowQueryReady),
        );

    await Future.wait(<Future<void>>[
      loggingReady.future,
      slowQueryReady.future,
    ]);
  }

  Future<void> dispose() async {
    await _loggingFlagSubscription?.cancel();
    await _slowQueryFlagSubscription?.cancel();
  }

  // --- Text file sink -----------------------------------------------------
  Future<void> _appendToNamedFile(
    String fileStem,
    String line, {
    bool forceFlush = false,
  }) async {
    if (isTestEnv) {
      _appendToNamedFileSync(fileStem, line);
      return;
    }

    final pendingLines = _pendingFileLinesByStem.putIfAbsent(
      fileStem,
      () => <String>[],
    )..add(line);
    final shouldFlushNow =
        forceFlush || pendingLines.length >= _fileFlushLineThreshold;

    if (!shouldFlushNow) {
      _fileFlushTimers[fileStem] ??= timerFactory(
        _fileFlushInterval,
        () {
          _fileFlushTimers.remove(fileStem);
          unawaited(_flushPendingLines(fileStem, forceFlush: forceFlush));
        },
      );
      return;
    }

    _fileFlushTimers.remove(fileStem)?.cancel();
    await _flushPendingLines(fileStem, forceFlush: forceFlush);
  }

  void _appendToNamedFileSync(String fileStem, String line) {
    try {
      final dir = getDocumentsDirectory();
      final logDir = Directory(p.join(dir.path, 'logs'));
      final fileName = '$fileStem-${_dateFmt.format(DateTime.now())}.log';
      final file = File(p.join(logDir.path, fileName));
      // Synchronous in tests to avoid timing flakes under parallel runners.
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
      file.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
    } catch (_) {
      // Swallow file-sink errors so logging never interferes with app flows.
    }
  }

  Future<void> _flushPendingLines(
    String fileStem, {
    bool forceFlush = false,
  }) async {
    final pendingLines = _pendingFileLinesByStem[fileStem];
    if (pendingLines == null || pendingLines.isEmpty) {
      return;
    }

    final lines = List<String>.from(pendingLines);
    pendingLines.clear();

    final currentDrain = _fileDrains[fileStem] ?? Future<void>.value();
    final nextDrain = currentDrain.then((_) async {
      try {
        final dir = getDocumentsDirectory();
        final logDir = Directory(p.join(dir.path, 'logs'));
        final fileName = '$fileStem-${_dateFmt.format(DateTime.now())}.log';
        final file = File(p.join(logDir.path, fileName));
        await logDir.create(recursive: true);
        final payload = '${lines.join('\n')}\n';
        await file.writeAsString(
          payload,
          mode: FileMode.append,
          flush: forceFlush,
        );
      } catch (_) {
        // Swallow file-sink errors so logging never interferes with app flows.
      }
    });
    _fileDrains[fileStem] = nextDrain;

    await nextDrain;
  }

  /// Awaits all pending writes and flushes all buffered log lines to disk.
  ///
  /// Called during app shutdown so that log entries buffered behind the 500 ms
  /// timer are not lost when `_exit(0)` terminates the process before the
  /// timer fires.
  Future<void> flush() async {
    // Await all tracked unawaited writes (captureEvent / captureException).
    // Snapshot first since whenComplete callbacks remove items during iteration.
    await Future.wait(List<Future<void>>.of(_pendingWrites));
    // Cancel any pending timer-based flushes and drain remaining lines.
    for (final entry in _fileFlushTimers.entries.toList()) {
      entry.value.cancel();
    }
    _fileFlushTimers.clear();
    for (final stem in _pendingFileLinesByStem.keys.toList()) {
      await _flushPendingLines(stem, forceFlush: true);
    }
  }

  /// Test-only alias for [flush]. Kept for backwards compatibility with
  /// existing tests that called this directly.
  @visibleForTesting
  Future<void> flushAllForTest() => flush();

  String? _domainFileStem(String domain) {
    if (syncFileDomains.contains(domain)) {
      return _syncLogStem;
    }
    return null;
  }

  bool _shouldWriteToGeneral(String domain, {required bool isException}) {
    if (isException) return true;
    return !syncFileDomains.contains(domain);
  }

  String _formatLine({
    required DateTime ts,
    required String level,
    required String domain,
    required String message,
    String? subDomain,
  }) {
    final t = ts.toIso8601String();
    final sd = (subDomain == null || subDomain.isEmpty) ? '' : ' $subDomain';
    return '$t [$level] $domain$sd: $message';
  }

  Future<void> _captureEventAsync(
    dynamic event, {
    required String domain,
    String? subDomain,
    InsightLevel level = InsightLevel.info,
    InsightType type = InsightType.log,
  }) async {
    final now = DateTime.now();
    final line = _formatLine(
      ts: now,
      level: level.name.toUpperCase(),
      domain: domain,
      subDomain: subDomain,
      message: event.toString(),
    );

    final forceFlush = level == InsightLevel.error;
    final writes = <Future<void>>[];
    if (_shouldWriteToGeneral(domain, isException: false)) {
      writes.add(
        _appendToNamedFile(_generalLogStem, line, forceFlush: forceFlush),
      );
    }

    final domainFileStem = _domainFileStem(domain);
    if (domainFileStem != null) {
      writes.add(
        _appendToNamedFile(domainFileStem, line, forceFlush: forceFlush),
      );
    }
    if (level == InsightLevel.error) {
      writes.add(_appendToNamedFile(_errorLogStem, line, forceFlush: true));
    }
    await Future.wait(writes);
  }

  void captureEvent(
    dynamic event, {
    required String domain,
    String? subDomain,
    InsightLevel level = InsightLevel.info,
    InsightType type = InsightType.log,
  }) {
    if (!_enableLogging) {
      return;
    }
    final future = _captureEventAsync(
      event,
      domain: domain,
      subDomain: subDomain,
      level: level,
      type: type,
    );
    _pendingWrites.add(future);
    unawaited(future.whenComplete(() => _pendingWrites.remove(future)));
  }

  Future<void> _captureExceptionAsync(
    dynamic exception, {
    required String domain,
    String? subDomain,
    dynamic stackTrace,
    InsightLevel level = InsightLevel.error,
    InsightType type = InsightType.exception,
  }) async {
    final now = DateTime.now();
    final line = _formatLine(
      ts: now,
      level: level.name.toUpperCase(),
      domain: domain,
      subDomain: subDomain,
      message: '$exception ${stackTrace ?? ''}'.trim(),
    );

    final writes = <Future<void>>[
      _appendToNamedFile(_generalLogStem, line, forceFlush: true),
      _appendToNamedFile(_errorLogStem, line, forceFlush: true),
    ];
    final domainFileStem = _domainFileStem(domain);
    if (domainFileStem != null) {
      writes.add(
        _appendToNamedFile(domainFileStem, line, forceFlush: true),
      );
    }
    await Future.wait(writes);
  }

  void captureException(
    dynamic exception, {
    required String domain,
    String? subDomain,
    dynamic stackTrace,
    InsightLevel level = InsightLevel.error,
    InsightType type = InsightType.exception,
  }) {
    DevLogger.error(
      name: 'LoggingService',
      message: 'EXCEPTION $domain ${subDomain ?? ''}',
      error: exception,
      stackTrace: stackTrace is StackTrace ? stackTrace : null,
    );
    final future = _captureExceptionAsync(
      exception,
      domain: domain,
      subDomain: subDomain,
      stackTrace: stackTrace,
      level: level,
      type: type,
    );
    _pendingWrites.add(future);
    unawaited(future.whenComplete(() => _pendingWrites.remove(future)));
  }
}
