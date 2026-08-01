import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/service/agent_retention_policy.dart';
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
class AgentRetentionService {
  AgentRetentionService({
    required this.repository,
    required this.domainLogger,
    this.policy = const AgentRetentionPolicy(),
  });

  final AgentRepository repository;
  final DomainLogger domainLogger;
  final AgentRetentionPolicy policy;

  /// Sweeps every retention-eligible source once.
  ///
  /// Fail-soft: retention is housekeeping and must never keep the app from
  /// starting, so an error logs and returns whatever was already collected.
  Future<AgentRetentionResult> sweep() async {
    final now = clock.now();
    var result = const AgentRetentionResult();
    try {
      final dayStatusEvents = await repository.pruneDayStatusEventsBefore(
        now.subtract(policy.dayStatusEvents),
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
