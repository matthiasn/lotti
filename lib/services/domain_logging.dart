import 'package:lotti/database/logging_db.dart';
import 'package:lotti/services/logging_service.dart';

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
/// - Delegates to [LoggingService] for the actual dual-sink (DB + file)
///   persistence.
class DomainLogger {
  DomainLogger({required LoggingService loggingService})
      : _loggingService = loggingService;

  final LoggingService _loggingService;

  /// Set of currently enabled domain names.
  ///
  /// Managed externally (e.g. via config flag watchers). When empty, all
  /// domains are treated as disabled and [log] / [error] are no-ops.
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
    _loggingService.captureException(
      '$message${error != null ? ': $error' : ''}',
      domain: domain,
      subDomain: subDomain,
      stackTrace: stackTrace,
    );
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
