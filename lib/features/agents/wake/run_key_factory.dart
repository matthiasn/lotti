import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Deterministic run-key and operation-ID generation using SHA-256.
///
/// Every key is derived from domain-stable inputs so that:
/// - Duplicate wake triggers for the same logical event produce the same key.
/// - The `WakeQueue` can deduplicate before inserting into the run log.
/// - Tool-call operation IDs are stable across retries.
class RunKeyFactory {
  RunKeyFactory._();

  /// Subscription wake: SHA256(agentId | subscriptionId | batchTokensHash |
  /// wakeCounter).
  ///
  /// The [wakeCounter] (from `AgentStateEntity`) is included so that a second
  /// wake cycle for the same subscription produces a fresh key even when
  /// [batchTokens] is identical.
  static String forSubscription({
    required String agentId,
    required String subscriptionId,
    required Set<String> batchTokens,
    required int wakeCounter,
  }) {
    final batchTokensHash = _hashTokens(batchTokens);
    return _sha256('$agentId|$subscriptionId|$batchTokensHash|$wakeCounter');
  }

  /// Timer wake: SHA256(agentId | timerId | scheduledAt).
  static String forTimer({
    required String agentId,
    required String timerId,
    required DateTime scheduledAt,
  }) {
    return _sha256('$agentId|$timerId|${scheduledAt.toIso8601String()}');
  }

  /// User-initiated wake: SHA256(agentId | sessionId | turnId).
  static String forUserInitiated({
    required String agentId,
    required String sessionId,
    required String turnId,
  }) {
    return _sha256('$agentId|$sessionId|$turnId');
  }

  /// Manual (system/user) wake: SHA256(agentId | reason | timestamp).
  ///
  /// Uses the ISO-8601 timestamp to ensure uniqueness across invocations.
  static String forManual({
    required String agentId,
    required String reason,
    required DateTime timestamp,
  }) {
    return _sha256('$agentId|$reason|${timestamp.toIso8601String()}');
  }

  /// Operation ID for a tool call within a run:
  /// SHA256(runKey | actionStableId).
  static String operationId({
    required String runKey,
    required String actionStableId,
  }) {
    return _sha256('$runKey|$actionStableId');
  }

  /// Action stable ID for a tool call:
  /// SHA256(toolName | canonicalArgsHash | sortedTargetRefs).
  ///
  /// [args] is JSON-encoded canonically before hashing so that key ordering
  /// differences in the map do not change the result.
  static String actionStableId({
    required String toolName,
    required Map<String, dynamic> args,
    required List<String> targetRefs,
  }) {
    final argsHash =
        _sha256(jsonEncode(SplayTreeMap<String, dynamic>.from(args)));
    final refsJoined = (List<String>.from(targetRefs)..sort()).join(',');
    return _sha256('$toolName|$argsHash|$refsJoined');
  }

  // ── private helpers ────────────────────────────────────────────────────────

  static String _hashTokens(Set<String> tokens) {
    final sorted = tokens.toList()..sort();
    return _sha256(sorted.join('|'));
  }

  static String _sha256(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }
}
