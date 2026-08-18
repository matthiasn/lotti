import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/goals/repository/goal_repository.dart';
import 'package:lotti/services/domain_logging.dart';

/// Deterministic id for the link binding a goal agent to its journal entry.
///
/// Derived from the natural key the database already enforces uniqueness on,
/// so concurrent backfills on two devices converge on one link instead of
/// colliding.
String agentGoalLinkId({required String agentId, required String goalId}) =>
    'agent_goal_link:$agentId:$goalId';

/// Keeps the journal-side goal in step with the agent-side spec chain.
///
/// The agent database owns the operational definition — the immutable version
/// chain, the head pointer and their CRDT merge rules (ADR 0053). The journal
/// owns the durable, user-authored record. This is the one seam between them,
/// so there is a single place that can be wrong rather than three.
///
/// Every operation is idempotent: the ids are derived, an existing goal is
/// refreshed rather than duplicated, and a snapshot that already exists is left
/// exactly as it was. That matters because the callers legitimately re-run —
/// creation retries after a deferred outbox flush fails, and the startup
/// backfill runs on every device that syncs the goal.
///
/// Failure is non-fatal by design. A goal whose journal mirror could not be
/// written is still a working goal: the agent tier is unaffected, and the next
/// launch's backfill repairs it. Throwing here would turn a mirroring problem
/// into a failed goal creation.
class GoalMirrorService {
  GoalMirrorService({
    required GoalRepository goalRepository,
    required AgentRepository agentRepository,
    required this._syncService,
    this._domainLogger,
  }) : _goals = goalRepository,
       _agents = agentRepository;

  final GoalRepository _goals;
  final AgentRepository _agents;
  final AgentSyncService _syncService;
  final DomainLogger? _domainLogger;

  /// Mirrors [version] — the goal's current definition — into the journal, and
  /// binds the agent to it.
  ///
  /// Returns the goal entry, or null when nothing could be written. Never
  /// throws.
  Future<GoalEntry?> mirrorSpec({
    required GoalSpecVersionEntity version,
    String? categoryId,
  }) async {
    final agentId = version.agentId;
    try {
      final goalId = _goals.goalIdForAgent(agentId);

      // The snapshot first: the goal points at it, so writing the goal first
      // would briefly name a row that does not exist.
      final snapshot = await _goals.ensureSpecSnapshot(
        goalId: goalId,
        specVersionId: version.id,
        title: version.title,
        statement: version.statement,
        criteria: version.criteria,
        specVersion: version.version,
        createdAt: version.createdAt,
        startDate: version.startDate,
        targetDate: version.targetDate,
        rationale: version.rationale,
        categoryId: categoryId,
      );

      final goal = await _goals.upsertGoal(
        agentId: agentId,
        title: version.title,
        statement: version.statement,
        criteria: version.criteria,
        specVersion: version.version,
        // Falls back to the agent-side id only if the snapshot could not be
        // written, so the field is never left dangling.
        specVersionId: snapshot?.meta.id ?? version.id,
        startDate: version.startDate,
        targetDate: version.targetDate,
        rationale: version.rationale,
        categoryId: categoryId,
      );

      if (goal != null) await _ensureAgentGoalLink(agentId, goal.meta.id);
      return goal;
    } catch (error, stackTrace) {
      _log('mirrorSpec', agentId, error, stackTrace);
      return null;
    }
  }

  /// Mirrors the goal's CURRENT head, resolving it from the agent store.
  ///
  /// The repair entry point: the backfill and a synced identity both know an
  /// agent id and nothing else.
  Future<GoalEntry?> mirrorHead(String agentId, {String? categoryId}) async {
    try {
      final head = await _agents.getEntity(goalSpecHeadId(agentId));
      if (head is! GoalSpecHeadEntity) return null;
      final version = await _agents.getEntity(head.versionId);
      if (version is! GoalSpecVersionEntity) return null;
      return await mirrorSpec(version: version, categoryId: categoryId);
    } catch (error, stackTrace) {
      _log('mirrorHead', agentId, error, stackTrace);
      return null;
    }
  }

  /// Binds the agent to its goal entry, once. The link is the disposable side
  /// pointing at the durable one, so a missing link is repairable and a missing
  /// goal is not — which is why the goal is written first.
  ///
  /// The id is **derived**, not minted. `agent_links` carries a unique index on
  /// `(from_id, to_id, type)`, while `upsertLink` resolves conflicts by `id`
  /// alone — so two devices that backfilled before either saw the other's link
  /// would hold two different ids for the same natural key, and receiving the
  /// peer's link would fail the uniqueness constraint and retry forever.
  /// Deriving the id from the pair makes both devices write the same row.
  Future<void> _ensureAgentGoalLink(String agentId, String goalId) async {
    final existing = await _agents.getLinksFrom(
      agentId,
      type: AgentLinkTypes.agentGoal,
    );
    if (existing.any((link) => link.toId == goalId && link.deletedAt == null)) {
      return;
    }
    final now = clock.now();
    await _syncService.upsertLink(
      AgentLink.agentGoal(
        id: agentGoalLinkId(agentId: agentId, goalId: goalId),
        fromId: agentId,
        toId: goalId,
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
      ),
    );
  }

  void _log(String subDomain, String agentId, Object error, StackTrace trace) {
    _domainLogger?.error(
      LogDomain.agentRuntime,
      error,
      stackTrace: trace,
      subDomain: 'GoalMirrorService.$subDomain',
      message: 'mirroring the journal-side goal failed for $agentId',
    );
  }
}
