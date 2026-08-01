import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_retention_policy.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart';
import 'package:lotti/services/domain_logging.dart';

/// Outcome of one retention sweep, per source.
class AgentRetentionResult {
  const AgentRetentionResult({this.dayStatusEvents = 0});

  final int dayStatusEvents;

  int get total => dayStatusEvents;

  @override
  String toString() => 'dayStatusEvents=$dayStatusEvents';
}

/// Forgets the derived rows the agent store no longer needs.
///
/// Bounding the *reads* stopped per-action cost from growing with history, but
/// the rows themselves still accumulated: the coordinator is long-lived and
/// writes observations on every wake, forever. Unbounded growth shows up as
/// database size, sync payload, backup size and slower whole-table maintenance
/// — all of which degrade the experience over months even when every individual
/// query is indexed.
///
/// **Runs on the once-per-start repair pass rather than owning a scheduler**,
/// the same shape the processing outbox's retention uses. That is what makes it
/// safe to interrupt: the policy is a pure function of the store's contents, so
/// a sweep cut short by a process kill simply leaves rows for the next start,
/// and a sweep that runs twice removes nothing the second time. Work happens in
/// bounded batches off the UI's path.
/// Mirrors the digest's own sync-lag overlap when reading its watermark, so
/// retention never trims inside the window the digest still re-reads.
const _digestSyncLagSlack = Duration(hours: 12);

class AgentRetentionService {
  AgentRetentionService({
    required this.repository,
    required this.domainLogger,
    this.policy = const AgentRetentionPolicy(),
  });

  final AgentRepository repository;
  final DomainLogger domainLogger;
  final AgentRetentionPolicy policy;

  /// The digest's unconsumed backlog is never eligible: returns the earlier of
  /// [cutoff] and the coordinator's watermark, so a stalled digest holds
  /// retention back rather than losing the events it has yet to read.
  ///
  /// Fail-soft in the safe direction — an unreadable log yields the epoch,
  /// which prunes nothing.
  Future<DateTime> _watermarkFloored(DateTime cutoff) async {
    try {
      // Unbounded: the coordinator writes other system messages between
      // digests — wake bookkeeping, fork joins — so a fixed page can push the
      // real milestone out of view while scheduling is stalled. Reading no
      // marker floors the cutoff at the epoch and retention then prunes
      // nothing at all, which is a silent stall rather than a safe default.
      final markers = await repository.getMessagesByKind(
        dailyOsPlannerAgentId,
        AgentMessageKind.system,
      );
      // Max rather than first: nothing in `getMessagesByKind` promises an
      // order, and depending on one would make the watermark quietly wrong
      // rather than loudly broken.
      DateTime? newest;
      for (final marker in markers) {
        if (marker.metadata.milestone != AgentMilestone.dailyWakeCompleted) {
          continue;
        }
        if (newest == null || marker.createdAt.isAfter(newest)) {
          newest = marker.createdAt;
        }
      }
      // No digest has ever completed, so nothing has been consumed.
      if (newest == null) return DateTime.fromMillisecondsSinceEpoch(0);
      final watermark = newest.subtract(_digestSyncLagSlack);
      return watermark.isBefore(cutoff) ? watermark : cutoff;
    } catch (e, s) {
      domainLogger.error(
        LogDomain.agentRuntime,
        e,
        message: 'failed to read the digest watermark; skipping status events',
        stackTrace: s,
      );
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  /// Sweeps every retention-eligible source once.
  ///
  /// Fail-soft: retention is housekeeping and must never keep the app from
  /// starting, so an error logs and returns whatever was already collected.
  Future<AgentRetentionResult> sweep() async {
    final now = clock.now();
    var result = const AgentRetentionResult();
    try {
      // Never past what the digest has actually consumed. Its watermark is the
      // newest `dailyWakeCompleted` milestone (minus a 12h sync-lag slack),
      // and a digest that has failed or stayed pending for longer than the
      // retention window would otherwise find its backlog already deleted —
      // silently, and precisely in the "came back after a break" case the
      // collapse-into-one-catch-up behaviour exists to serve.
      final cutoff = await _watermarkFloored(
        now.subtract(policy.dayStatusEvents),
      );
      final dayStatusEvents = await repository.pruneDayStatusEventsBefore(
        cutoff,
        batchSize: policy.batchSize,
        maxBatches: policy.maxBatchesPerSweep,
      );
      result = AgentRetentionResult(dayStatusEvents: dayStatusEvents);
    } catch (e, s) {
      domainLogger.error(
        LogDomain.agentRuntime,
        e,
        message: 'agent retention sweep failed after $result',
        stackTrace: s,
      );
      return result;
    }
    if (result.total > 0) {
      domainLogger.log(
        LogDomain.agentRuntime,
        'retention pruned ${result.total} row(s): $result',
        subDomain: 'retention',
      );
    }
    return result;
  }
}
