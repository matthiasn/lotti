import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
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
  /// view with dangling parents, a partially-synced join, or a corrupt log).
  /// [at] timestamps the local join envelope; wake provenance is deliberately
  /// not persisted on the join so content-addressed duplicate rows stay
  /// structurally identical across devices.
  Future<String?> maybeHealFork({
    required String agentId,
    required DateTime at,
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
      if (_hasPendingJoinHead(
        projection: projection,
        messages: messages,
        links: links,
      )) {
        return null;
      }
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
    );
    return plan.joinId;
  }
}

/// True while a join node has synced before all of its `messagePrev` edges.
///
/// A parentless or partially-parented join is itself a projected head. Without
/// this guard, the healer would treat `{old heads + pending join}` as a fresh
/// fork and mint a second-order join. If the join's already-arrived parents plus
/// any subset of the other current heads reproduce the join's content-addressed
/// id, the correct action is to wait for the missing edges to arrive.
bool _hasPendingJoinHead({
  required AgentProjection projection,
  required List<AgentMessageEntity> messages,
  required List<AgentLink> links,
}) {
  if (projection.headIds.length < 2) return false;

  final messagesById = {
    for (final message in messages) message.id: message,
  };
  final parentsByChild = <String, Set<String>>{};
  for (final link in links) {
    if (link is MessagePrevLink && link.deletedAt == null) {
      (parentsByChild[link.fromId] ??= <String>{}).add(link.toId);
    }
  }

  final headIds = projection.headIds.toSet();
  for (final headId in projection.headIds) {
    final message = messagesById[headId];
    if (message == null || message.kind != AgentMessageKind.system) continue;

    final arrivedParents = parentsByChild[headId] ?? const <String>{};
    if (arrivedParents.length >= 2) continue;

    final otherHeads = [
      for (final otherHeadId in headIds)
        if (otherHeadId != headId) otherHeadId,
    ];
    if (_hasJoinParentSubset(
      arrivedParents: arrivedParents,
      otherHeads: otherHeads,
      joinId: headId,
    )) {
      return true;
    }
  }

  return false;
}

bool _hasJoinParentSubset({
  required Set<String> arrivedParents,
  required List<String> otherHeads,
  required String joinId,
}) {
  final subsetCount = 1 << otherHeads.length;
  for (var mask = 0; mask < subsetCount; mask++) {
    final candidateParents = <String>{...arrivedParents};
    for (var i = 0; i < otherHeads.length; i++) {
      if ((mask & (1 << i)) != 0) {
        candidateParents.add(otherHeads[i]);
      }
    }
    if (candidateParents.length >= 2 &&
        computeJoinId(candidateParents) == joinId) {
      return true;
    }
  }

  return false;
}
