import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_phase_a.dart';

/// Creates and wires relationship agents (ADR 0059 Decision 2: one durable
/// identity per tracked person, created LAZILY on the first `important`
/// mark — the flag is the single consent switch for proactive behavior).
///
/// Ids are deterministic per relationship (`relationshipAgentIdFor`), so
/// two devices marking the same person important converge on one agent,
/// and creation is idempotent: an existing identity is returned untouched.
class RelationshipAgentService {
  RelationshipAgentService({
    required this._agentService,
    required this._repository,
    required this._syncService,
    required this._orchestrator,
  });

  final AgentService _agentService;
  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final WakeOrchestrator _orchestrator;

  /// Ensures the agent for [relationship] exists and is live: identity,
  /// agent→relationship link and first cadence tick land in ONE
  /// transaction; the agent leaves this method subscribed and with an
  /// immediate deterministic evaluation queued (€0 — a person marked
  /// important after the cadence hour must not wait a day for a register).
  ///
  /// Idempotent: an existing identity — whatever its lifecycle — is
  /// returned as-is. Un-marking `important` deliberately does NOT touch
  /// the agent: Phase A gates on eligibility every tick, so the switch is
  /// instant in both directions with no re-wiring.
  Future<AgentIdentityEntity> ensureAgentForRelationship(
    RelationshipEntry relationship,
  ) async {
    final relationshipId = relationship.meta.id;
    final agentId = relationshipAgentIdFor(relationshipId);
    final now = clock.now();

    final identity = await _syncService.runInTransaction(() async {
      // Inside the transaction, not a preflight: two concurrent marks must
      // serialize here so the loser sees the winner's identity.
      final existing = await _repository.getEntity(agentId);
      if (existing is AgentIdentityEntity) return existing;
      final created = await _agentService.createAgent(
        kind: AgentKinds.relationshipAgent,
        displayName: relationship.data.title,
        config: const AgentConfig(automaticUpdatesEnabled: true),
        agentId: agentId,
      );
      await _syncService.upsertLink(
        AgentLink.agentRelationship(
          id: relationshipAgentLinkId(agentId),
          fromId: agentId,
          toId: relationshipId,
          createdAt: now,
          updatedAt: now,
          vectorClock: null,
        ),
      );
      // First cadence tick — recurrence by re-arm starts here.
      await _syncService.upsertEntity(
        relationshipCadenceWake(agentId, now),
      );
      return created;
    });

    await registerSubscription(agentId, relationshipId: relationshipId);
    _orchestrator.enqueueManualWake(
      agentId: agentId,
      reason: 'relationship marked important',
    );
    return identity;
  }

  /// Subscribes the agent to its relationship's wake token. Check-ins emit
  /// the denormalized `relationshipId` through `affectedIds` (the
  /// `HabitCompletionEntry.habitId` precedent), so ONE token covers the
  /// person and every check-in. Phase A is €0, so matches drain
  /// immediately rather than riding the deferral.
  Future<void> registerSubscription(
    String agentId, {
    String? relationshipId,
  }) async {
    final subjectId = relationshipId ?? await watchedRelationshipId(agentId);
    if (subjectId == null) return;
    _orchestrator
      ..removeSubscriptions(agentId)
      ..addSubscription(
        AgentSubscription(
          id: relationshipSignalSubscriptionId(agentId),
          agentId: agentId,
          matchEntityIds: {subjectId},
          deferPropagatedMatches: false,
          drainImmediately: true,
        ),
      );
  }

  /// Drops the agent's runtime subscriptions (a paused or destroyed agent
  /// must stop waking on signals; re-activation re-registers).
  void removeSubscription(String agentId) =>
      _orchestrator.removeSubscriptions(agentId);

  /// The deletion cascade's agent leg (ADR 0037 §5 / ADR 0059 Decision 7):
  /// destroying the identity retires it from every active surface and
  /// wake path, while its rows remain for audit like any destroyed agent.
  /// Returns false when no agent was ever created for [relationshipId].
  Future<bool> handleRelationshipDeleted(String relationshipId) async {
    final agentId = relationshipAgentIdFor(relationshipId);
    final existing = await _repository.getEntity(agentId);
    if (existing is! AgentIdentityEntity) return false;
    final destroyed = await _agentService.destroyAgent(agentId);
    if (!destroyed) return false;
    _agentService
      ..cancelPendingWake(agentId)
      ..abortRunningWake(agentId);
    removeSubscription(agentId);
    return true;
  }

  /// The explicit "Brief me" trigger (plan v2 phase 5 item 5): ensures
  /// the agent exists — Brief me on a not-yet-important person is the
  /// plan's "explicit enable" — then routes one manual wake through the
  /// LLM tier via the report-refresh token. Provider disclosure happens in
  /// the UI BEFORE this is called (ADR 0037: name the provider first).
  Future<void> requestBriefing(RelationshipEntry relationship) async {
    final identity = await ensureAgentForRelationship(relationship);
    _orchestrator.enqueueManualWake(
      agentId: identity.agentId,
      reason: 'brief me',
      triggerTokens: const {relationshipReportRefreshTriggerToken},
    );
  }

  /// The relationship this agent watches, via its `agentRelationship` link,
  /// or null while the link has not been written yet (creation writes it
  /// before the first wake, so a null here is a benign startup race).
  Future<String?> watchedRelationshipId(String agentId) async {
    final links = await _repository.getLinksFrom(
      agentId,
      type: AgentLinkTypes.agentRelationship,
    );
    return links.isEmpty ? null : links.first.toId;
  }
}

/// Stable subscription id, so repeated `restoreSubscriptions` replace
/// instead of accumulate.
String relationshipSignalSubscriptionId(String agentId) =>
    '${agentId}_relationship_signals';
