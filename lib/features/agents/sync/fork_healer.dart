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
      plan = planJoin(
        headIds: projection.headIds,
        viewComplete:
            projection.danglingParentIds.isEmpty &&
            !_hasUnsyncedEdge(
              messages: messages,
              links: links,
              headIds: projection.headIds,
            ),
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

/// True while some present row still waits for a `messagePrev` edge that
/// makes a present parent look like a head (ADR 0071).
///
/// A row whose edge has not synced projects as a root, so its parent — no
/// longer shown to have a child — reads as a head, and a join planned now
/// would link a parent and its own descendant. Two shapes tell it from the
/// rows alone:
///
/// - a message minted with a `prevMessageId` naming a present row has an edge
///   to it, so none arriving means the edge is in flight (one naming an
///   absent row says nothing: the observation sweep deletes the edges into
///   what it prunes, and an absent parent is no false head);
/// - a join — head or not — whose arrived parents do not reproduce its
///   content-addressed id ([isJoinComplete]) but do together with some of
///   [headIds] is waiting for the edges to those heads.
///
/// A join row does not name its parents, so a join still missing the edge to
/// a parent that is not a head here (absent, or with another child) goes
/// unnoticed (README: residuals). A dangling parent (an edge ahead of its
/// parent node) is the projection's `danglingParentIds`, checked alongside.
bool _hasUnsyncedEdge({
  required List<AgentMessageEntity> messages,
  required List<AgentLink> links,
  required List<String> headIds,
}) {
  final present = {for (final message in messages) message.id};
  final parentsByChild = <String, Set<String>>{};
  for (final link in links) {
    if (link is MessagePrevLink && link.deletedAt == null) {
      (parentsByChild[link.fromId] ??= <String>{}).add(link.toId);
    }
  }
  for (final message in messages) {
    final arrived = parentsByChild[message.id] ?? const <String>{};
    if (arrived.isEmpty && present.contains(message.prevMessageId)) {
      return true;
    }
    if (message.kind == AgentMessageKind.system &&
        hasJoinIdShape(message.id) &&
        !isJoinComplete(joinId: message.id, arrivedParentIds: arrived) &&
        _completedByHeads(
          joinId: message.id,
          arrived: arrived,
          otherHeads: [
            for (final head in headIds)
              if (head != message.id && !arrived.contains(head)) head,
          ],
        )) {
      return true;
    }
  }
  return false;
}

/// Beyond this many other heads the subset search in [_completedByHeads]
/// (one digest per subset) is skipped rather than run on every wake.
const _maxJoinSearchHeads = 12;

/// Whether [arrived] plus a non-empty subset of [otherHeads] reproduces
/// [joinId]. With more than [_maxJoinSearchHeads] other heads it answers no,
/// like any other join the healer cannot place (README: residuals).
bool _completedByHeads({
  required String joinId,
  required Set<String> arrived,
  required List<String> otherHeads,
}) {
  if (otherHeads.length > _maxJoinSearchHeads) return false;
  final subsetCount = 1 << otherHeads.length;
  for (var mask = 1; mask < subsetCount; mask++) {
    if (isJoinComplete(
      joinId: joinId,
      arrivedParentIds: {
        ...arrived,
        for (var i = 0; i < otherHeads.length; i++)
          if ((mask & (1 << i)) != 0) otherHeads[i],
      },
    )) {
      return true;
    }
  }
  return false;
}
