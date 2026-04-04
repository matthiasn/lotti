import 'package:clock/clock.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';

/// Internal record of which entities an agent mutated and when.
class MutationRecord {
  MutationRecord({required this.entityIds, required this.recordedAt});

  final Set<String> entityIds;
  final DateTime recordedAt;
}

/// Stateful tracker that manages self-notification suppression.
///
/// Tracks which entities an agent recently mutated so that notifications
/// triggered by those mutations can be suppressed, preventing the agent
/// from waking on its own writes.
///
/// Maintains two layers of suppression:
/// - **Confirmed**: recorded after execution completes, with a TTL.
/// - **Pre-registered**: set before execution starts (conservative
///   over-approximation), cleared explicitly after execution.
class WakeSuppressionTracker {
  static const suppressionTtl = Duration(seconds: 5);

  final _recentlyMutatedEntries = <String, MutationRecord>{};
  final _preRegisteredSuppression = <String, MutationRecord>{};

  void clearAgent(String agentId) {
    clearConfirmed(agentId);
    clearPreRegistered(agentId);
  }

  void clearConfirmed(String agentId) {
    _recentlyMutatedEntries.remove(agentId);
  }

  void clearPreRegistered(String agentId) {
    _preRegisteredSuppression.remove(agentId);
  }

  void preRegisterSuppression(String agentId, Set<String> entityIds) {
    if (entityIds.isEmpty) return;
    _preRegisteredSuppression[agentId] = MutationRecord(
      entityIds: entityIds,
      recordedAt: clock.now(),
    );
  }

  void recordMutatedEntities(
    String agentId,
    Map<String, VectorClock> entries,
  ) {
    _recentlyMutatedEntries[agentId] = MutationRecord(
      entityIds: entries.keys.toSet(),
      recordedAt: clock.now(),
    );
  }

  bool isSuppressed(String agentId, Set<String> matchedTokens) {
    final record = _recentlyMutatedEntries[agentId];
    if (record == null || record.entityIds.isEmpty) return false;

    final elapsed = clock.now().difference(record.recordedAt);
    if (elapsed > suppressionTtl) {
      _recentlyMutatedEntries.remove(agentId);
      return false;
    }

    return matchedTokens.every(record.entityIds.contains);
  }

  bool isPreRegisteredSuppressed(String agentId, Set<String> matchedTokens) {
    final record = _preRegisteredSuppression[agentId];
    if (record == null || record.entityIds.isEmpty) return false;
    return matchedTokens.every(record.entityIds.contains);
  }

  /// Debug representation of the suppression state for [agentId].
  String debugState(String agentId) {
    final confirmed = _recentlyMutatedEntries[agentId];
    final preReg = _preRegisteredSuppression[agentId];
    final confirmedAge = confirmed != null
        ? '${clock.now().difference(confirmed.recordedAt).inMilliseconds}ms ago'
        : 'none';
    final confirmedIds =
        confirmed?.entityIds.map(DomainLogger.sanitizeId).join(',') ?? '∅';
    final preRegIds =
        preReg?.entityIds.map(DomainLogger.sanitizeId).join(',') ?? '∅';
    return 'confirmed=[$confirmedIds]($confirmedAge) '
        'preReg=[$preRegIds]';
  }
}
