import 'dart:async';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:path/path.dart' as p;

class LoggingService {
  bool _enableLogging = !isTestEnv;
  final _dateFmt = DateFormat('yyyy-MM-dd');
  static const Duration _fileFlushInterval = Duration(milliseconds: 500);
  static const int _fileFlushLineThreshold = 40;
  static const String _generalLogStem = 'lotti';
  static const String _syncLogStem = 'sync';
  static const Set<String> _syncFileDomains = <String>{
    'sync',
    'MATRIX_SYNC',
    'MATRIX_SERVICE',
    'OUTBOX',
    'AGENT_SYNC',
    'SYNC_SEQUENCE',
    'SYNC_BACKFILL',
  };
  final Map<String, List<String>> _pendingFileLinesByStem =
      <String, List<String>>{};
  final Map<String, Timer> _fileFlushTimers = <String, Timer>{};
  final Map<String, Future<void>> _fileDrains = <String, Future<void>>{};

  void listenToConfigFlag() {
    getIt<JournalDb>().watchConfigFlag(enableLoggingFlag).listen((value) {
      _enableLogging = value;
    });
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
      _fileFlushTimers[fileStem] ??= Timer(
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

  String? _domainFileStem(String domain) {
    if (_syncFileDomains.contains(domain)) {
      return _syncLogStem;
    }
    return null;
  }

  bool _shouldWriteToGeneral(String domain, {required bool isException}) {
    if (isException) return true;
    return !_syncFileDomains.contains(domain);
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
    if (_shouldWriteToGeneral(domain, isException: false)) {
      await _appendToNamedFile(
        _generalLogStem,
        line,
        forceFlush: forceFlush,
      );
    }

    final domainFileStem = _domainFileStem(domain);
    if (domainFileStem != null) {
      await _appendToNamedFile(
        domainFileStem,
        line,
        forceFlush: forceFlush,
      );
    }
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
    unawaited(
      _captureEventAsync(
        event,
        domain: domain,
        subDomain: subDomain,
        level: level,
        type: type,
      ),
    );
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

    await _appendToNamedFile(_generalLogStem, line, forceFlush: true);
    final domainFileStem = _domainFileStem(domain);
    if (domainFileStem != null) {
      await _appendToNamedFile(domainFileStem, line, forceFlush: true);
    }
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
    unawaited(
      _captureExceptionAsync(
        exception,
        domain: domain,
        subDomain: subDomain,
        stackTrace: stackTrace,
        level: level,
        type: type,
      ),
    );
  }
}
