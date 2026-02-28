import 'dart:io';

import 'package:intl/intl.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/platform.dart';

/// Domain constants for structured logging.
///
/// Each domain corresponds to a config flag that can be toggled
/// independently in Settings > Advanced > Logging Domains.
abstract final class LogDomains {
  static const agentRuntime = 'agent_runtime';
  static const agentWorkflow = 'agent_workflow';
  static const sync = 'sync';
  static const ai = 'ai';
  static const general = 'general';
}

/// Lightweight domain-specific logging layer on top of [LoggingService].
///
/// Provides:
/// - PII-safe sanitization helpers for entity IDs and content bodies.
/// - Per-domain enabled check (reads from [enabledDomains]).
/// - Delegates to [LoggingService] for the DB + general-file dual-sink.
/// - Writes an additional **per-domain log file** at
///   `{documentsDir}/logs/{domain}-YYYY-MM-DD.log` so each domain's
///   telemetry can be reviewed in isolation.
class DomainLogger {
  DomainLogger({required LoggingService loggingService})
      : _loggingService = loggingService;

  final LoggingService _loggingService;
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  /// Set of currently enabled domain names.
  ///
  /// Managed externally (e.g. via config flag watchers). When empty, [log]
  /// is disabled for all domains, while [error] still logs.
  final Set<String> enabledDomains = {};

  /// Log a domain-specific message at the given [level].
  ///
  /// No-op if [domain] is not in [enabledDomains].
  void log(
    String domain,
    String message, {
    String? subDomain,
    InsightLevel level = InsightLevel.info,
  }) {
    if (!enabledDomains.contains(domain)) return;
    _loggingService.captureEvent(
      message,
      domain: domain,
      subDomain: subDomain,
      level: level,
    );
    _appendToDomainFile(
      domain: domain,
      level: level.name.toUpperCase(),
      subDomain: subDomain,
      message: message,
    );
  }

  /// Log an error with optional exception and stack trace.
  ///
  /// Always logs regardless of [enabledDomains] — errors should never be
  /// silently swallowed.
  void error(
    String domain,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? subDomain,
  }) {
    final fullMessage = '$message${error != null ? ': $error' : ''}';
    _loggingService.captureException(
      fullMessage,
      domain: domain,
      subDomain: subDomain,
      stackTrace: stackTrace,
    );
    _appendToDomainFile(
      domain: domain,
      level: 'ERROR',
      subDomain: subDomain,
      message: fullMessage,
      stackTrace: stackTrace,
    );
  }

  // ── Per-domain file sink ────────────────────────────────────────────────

  /// Appends a formatted line to `{documentsDir}/logs/{domain}-YYYY-MM-DD.log`.
  ///
  /// Best-effort: file-sink errors are swallowed so logging never interferes
  /// with app flows. Skipped entirely in test environments.
  void _appendToDomainFile({
    required String domain,
    required String level,
    required String message,
    String? subDomain,
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
      final file = File('${logDir.path}/$domain-$date.log');
      final ts = DateTime.now().toIso8601String();
      final sd = (subDomain == null || subDomain.isEmpty) ? '' : ' $subDomain';
      final line = '$ts [$level]$sd: $message';
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

  /// Replaces content/message body with a length placeholder.
  ///
  /// Example: `'Hello world, this is a secret'` → `'[content: 28 chars]'`
  static String sanitizeContent(String content) {
    return '[content: ${content.length} chars]';
  }
}
