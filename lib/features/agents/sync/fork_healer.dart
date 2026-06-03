import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/projection/agent_event_adapter.dart';
import 'package:lotti/features/agents/projection/agent_projection.dart';
import 'package:lotti/features/agents/projection/canonical_order.dart';
import 'package:lotti/features/agents/projection/join_plan.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

/// Heals a forked agent log (ADR 0018 rule 8): when the agent's `messagePrev`
/// DAG has ≥2 surviving heads at wake start, emit one content-addressed
/// **join-by-continuation** node linking every head, collapsing the fork to a
/// single tip so context assembly and the on-device prefix stay bounded.
///
/// This is an **optimization, never a correctness mechanism** — the projection
/// is multi-head tolerant, so an unhealed fork is already consistent across
/// devices (ADR 0018 rule 7). The join only re-converges the heads and re-warms
/// the prefix; nothing reads it for correctness.
///
/// It reads the agent's full message log + `messagePrev` edges, folds them
/// through the same projection the derive/shadow path uses, and — when
/// [planJoin] approves — appends the join via [AgentSyncService.appendJoin]
/// (deterministic, idempotent, content-addressed). Best-effort and non-fatal:
/// a corrupt synced log (duplicate id / cycle) is caught and skipped rather
/// than aborting the wake.
class ForkHealer {
  /// Creates a healer over an [AgentSyncService] — its repository for the reads,
  /// its append path for the join write.
  ForkHealer({required AgentSyncService syncService}) : _sync = syncService;

  final AgentSyncService _sync;

  AgentRepository get _repository => _sync.repository;

  /// Heals [agentId]'s fork if one survives at wake start, returning the emitted
  /// join id, or null when there was nothing to heal (no fork, an unsettled
  /// view with dangling parents, or a corrupt log). [at] timestamps the join;
  /// [threadId]/[runKey] carry the wake's provenance.
  Future<String?> maybeHealFork({
    required String agentId,
    required DateTime at,
    String? threadId,
    String? runKey,
  }) async {
    final messages = await _repository.getAgentMessages(agentId);
    // A fork needs ≥2 messages; skip the edge load entirely otherwise.
    if (messages.length < 2) return null;

    // messagePrev edges have `fromId = childMessageId`, so they are fetched by
    // the agent's message ids (not by agentId). Batched to avoid an N+1.
    final linksByChild = await _repository.getLinksFromMultiple(
      [for (final message in messages) message.id],
      type: AgentLinkTypes.messagePrev,
    );
    final links = [for (final group in linksByChild.values) ...group];

    final JoinPlan? plan;
    try {
      final projection = project(
        canonicalOrder(agentEventsFromLog(messages, links)),
      );
      plan = planJoin(
        headIds: projection.headIds,
        viewComplete: projection.danglingParentIds.isEmpty,
      );
    } catch (exception, stackTrace) {
      // A peer may have synced a malformed log (duplicate id / cycle). Healing
      // is best-effort — never abort the wake; the projection self-heals once
      // the log is consistent again.
      getIt<DomainLogger>().error(
        LogDomain.sync,
        exception,
        message: 'fork-heal projection failed for $agentId; skipping',
        stackTrace: stackTrace,
        subDomain: 'agentSync.forkHeal',
      );
      return null;
    }

    if (plan == null) return null;
    await _sync.appendJoin(
      agentId: agentId,
      joinId: plan.joinId,
      parentIds: plan.parentIds,
      at: at,
      threadId: threadId,
      runKey: runKey,
    );
    return plan.joinId;
  }
}
