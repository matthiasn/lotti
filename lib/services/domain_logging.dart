import 'dart:io';

import 'package:intl/intl.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/platform.dart';

export 'package:lotti/services/logging_domains.dart';

/// Domain-aware logging layer on top of [LoggingService].
///
/// `DomainLogger` is the single logging entry point for app code. It:
/// - gates info-level [log] calls on a per-domain enabled flag
///   ([enabledDomains]), populated from config flags;
/// - delegates to [LoggingService] (the low-level file sink) for the general
///   and per-domain log files, plus the daily **full** error log;
/// - writes a second, **PII-safe** error log (`error-safe-*.log`) that records
///   the error's runtime type only — never the raw exception string — so it
///   can be shared/inspected without leaking user-authored content;
/// - writes a per-domain file at `{documentsDir}/logs/{domain}-YYYY-MM-DD.log`
///   so each domain's telemetry can be reviewed in isolation ([LogDomain.sync]
///   routes to the shared `sync-*.log` instead).
///
/// Callers must treat [log] messages as telemetry, not content: never include
/// task titles, notes, timer summaries, tool argument values, prompt text,
/// model output, or other user-authored content. Exception objects passed to
/// [error] are recorded in full in the general + daily error log (matching the
/// historical `captureException` behavior) but only by runtime type in the
/// PII-safe error log.
class DomainLogger {
  DomainLogger({required this._loggingService});

  final LoggingService _loggingService;
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  /// File stem for the daily PII-safe error log.
  static const String errorSafeLogStem = 'error-safe';

  /// Set of currently enabled domains.
  ///
  /// Managed externally (e.g. via config flag watchers in
  /// `domainLoggerProvider`). When a domain is absent, [log] is a no-op for it,
  /// while [error] still logs.
  final Set<LogDomain> enabledDomains = <LogDomain>{};

  /// Whether [domain] is currently enabled for info-level logging.
  bool isEnabled(LogDomain domain) => enabledDomains.contains(domain);

  /// Replace the set of enabled domains in one shot.
  void setEnabledDomains(Iterable<LogDomain> domains) {
    enabledDomains
      ..clear()
      ..addAll(domains);
  }

  /// Log a domain-specific message at the given [level].
  ///
  /// No-op if [domain] is not in [enabledDomains].
  void log(
    LogDomain domain,
    String message, {
    String? subDomain,
    InsightLevel level = InsightLevel.info,
  }) {
    if (!enabledDomains.contains(domain)) return;
    _loggingService.captureEvent(
      message,
      domain: domain.wireName,
      subDomain: subDomain,
      level: level,
    );
    if (domain.routesToSyncFile) return;
    _appendToDomainFile(
      domain: domain.wireName,
      level: level.name.toUpperCase(),
      subDomain: subDomain,
      message: message,
    );
  }

  /// Log an [error] (with optional [stackTrace] and human-readable [message]).
  ///
  /// Always logs regardless of [enabledDomains] — errors are never silently
  /// swallowed. Two destinations:
  /// - the general + daily **full** error log via [LoggingService], recording
  ///   the full error string for diagnostics;
  /// - the daily **PII-safe** error log, recording the error's runtime type
  ///   only so it can be shared without leaking user-authored content.
  void error(
    LogDomain domain,
    Object error, {
    StackTrace? stackTrace,
    String? subDomain,
    String? message,
  }) {
    // Full, diagnostic description for the general + daily full error log.
    final fullDescription = fullErrorDescription(error, message);
    _loggingService.captureException(
      fullDescription,
      domain: domain.wireName,
      subDomain: subDomain,
      stackTrace: stackTrace,
    );

    // PII-safe description: never includes the raw error string.
    final safeDescription = safeErrorDescription(error, message);
    _appendToSharedFile(
      fileStem: errorSafeLogStem,
      domain: domain.wireName,
      level: 'ERROR',
      subDomain: subDomain,
      message: safeDescription,
      stackTrace: stackTrace,
    );

    // Per-domain file (skipped for sync, which routes to the shared sync log).
    if (domain.routesToSyncFile) return;
    _appendToDomainFile(
      domain: domain.wireName,
      level: 'ERROR',
      subDomain: subDomain,
      message: fullDescription,
      stackTrace: stackTrace,
    );
  }

  /// Full, diagnostic description of an error: `'<message>: <error>'`, or just
  /// `'<error>'` when no message is given. Includes the raw error string and is
  /// only written to the general + daily **full** error log.
  static String fullErrorDescription(Object error, String? message) {
    final hasMessage = message != null && message.isNotEmpty;
    return hasMessage ? '$message: $error' : '$error';
  }

  /// PII-safe description of an error: `'<message> (errorType=<Type>)'`, or just
  /// `'errorType=<Type>'` when no message is given. Never includes the raw
  /// error string, so it is safe for the shared `error-safe-*.log`.
  static String safeErrorDescription(Object error, String? message) {
    final hasMessage = message != null && message.isNotEmpty;
    final type = 'errorType=${error.runtimeType}';
    return hasMessage ? '$message ($type)' : type;
  }

  // ── File sinks ──────────────────────────────────────────────────────────

  /// Appends a formatted line to `{documentsDir}/logs/{domain}-YYYY-MM-DD.log`.
  void _appendToDomainFile({
    required String domain,
    required String level,
    required String message,
    String? subDomain,
    StackTrace? stackTrace,
  }) {
    final sd = (subDomain == null || subDomain.isEmpty) ? '' : ' $subDomain';
    _writeLine(
      fileStem: domain,
      line: '${_now()} [$level]$sd: $message',
      stackTrace: stackTrace,
    );
  }

  /// Appends a formatted line to a shared (multi-domain) log file, including
  /// the [domain] in the line since the file is not domain-scoped.
  void _appendToSharedFile({
    required String fileStem,
    required String domain,
    required String level,
    required String message,
    String? subDomain,
    StackTrace? stackTrace,
  }) {
    final sd = (subDomain == null || subDomain.isEmpty) ? '' : ' $subDomain';
    _writeLine(
      fileStem: fileStem,
      line: '${_now()} [$level] $domain$sd: $message',
      stackTrace: stackTrace,
    );
  }

  String _now() => DateTime.now().toIso8601String();

  /// Best-effort synchronous append. File-sink errors are swallowed so logging
  /// never interferes with app flows. Skipped entirely in test environments.
  void _writeLine({
    required String fileStem,
    required String line,
    StackTrace? stackTrace,
  }) {
    if (isTestEnv) return;
    try {
      final dir = getDocumentsDirectory();
      final logDir = Directory('${dir.path}/logs');
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
      final date = _dateFmt.format(DateTime.now());
      final file = File('${logDir.path}/$fileStem-$date.log');
      final buffer = StringBuffer(line)..writeln();
      if (stackTrace != null) {
        buffer.writeln(stackTrace);
      }
      file.writeAsStringSync(
        buffer.toString(),
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Swallow file-sink errors.
    }
  }

  // ── PII scrubbing helpers ───────────────────────────────────────────────

  /// Replaces a full UUID with a short, correlation-safe placeholder.
  ///
  /// Example: `'a1b2c3d4-e5f6-7890-abcd-ef1234567890'` → `'[id:a1b2c3]'`
  static String sanitizeId(String id) {
    if (id.length < 6) return '[id:$id]';
    return '[id:${id.substring(0, 6)}]';
  }
}
