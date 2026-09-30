import 'dart:async';
import 'dart:developer' as developer;

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
import 'package:lotti/features/relationships/runtime/relationship_agent_reconciliation.dart';

/// The lazy-create trigger every door that turns reminders on shares — the
/// person editor, the person page's card and contact import (ADR 0059
/// Decision 2): marking a person important is what mints their agent, and an
/// existing agent makes this an idempotent re-subscribe plus one €0
/// re-evaluation, so a cadence edit takes effect immediately.
///
/// Fire-and-forget with contained failure: agent wiring must never fail the
/// save the user just watched succeed. Takes the [service] rather than a
/// `ref`, because it outlives its caller by design — the agent is created
/// after the sheet has popped or the import page has closed. A person who is
/// not important is left alone. [source] names the caller in the log.
void ensureRelationshipAgentInBackground(
  RelationshipAgentService service,
  RelationshipEntry relationship, {
  required String source,
}) {
  if (!relationship.data.important) return;
  unawaited(() async {
    try {
      await service.ensureAgentForRelationship(relationship);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to ensure relationship agent',
        name: source,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }());
}

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
  /// preserved, with one refresh: a renamed person's title is written
  /// through to `displayName` (the goal revision-service precedent), so
  /// the chat page never stays labeled with a stale name. The rename leaves
  /// the lifecycle stamp alone, so it never overturns a concurrent destroy
  /// (ADR 0111). An agent this device deleted is not created again here:
  /// that is [reconcileAgent]'s call, for a mark newer than the delete, and
  /// null is returned. Un-marking
  /// `important` deliberately does NOT touch the agent: Phase A gates on
  /// eligibility every tick, so the switch is instant in both directions
  /// with no re-wiring. Instant includes the banner already on the dock —
  /// Phase A retires it on the ineligible path, since the render side
  /// filters on the person existing rather than on their consent.
  Future<AgentIdentityEntity?> ensureAgentForRelationship(
    RelationshipEntry relationship,
  ) async {
    final relationshipId = relationship.meta.id;
    final agentId = relationshipAgentIdFor(relationshipId);
    final now = clock.now();

    final identity = await _syncService.runInTransaction(() async {
      // Inside the transaction, not a preflight: two concurrent marks must
      // serialize here so the loser sees the winner's identity.
      final existing = await _repository.getEntity(agentId);
      if (existing is AgentIdentityEntity) {
        if (existing.displayName == relationship.data.title) return existing;
        final renamed = existing.copyWith(
          displayName: relationship.data.title,
          updatedAt: now,
        );
        await _syncService.upsertEntity(renamed);
        return renamed;
      }
      if (await _repository.deletedAgentAt(agentId) != null) return null;
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
    if (identity == null) return null;

    await _activateRuntime(
      agentId,
      relationshipId: relationshipId,
      reason: 'relationship marked important',
    );
    return identity;
  }

  /// Sets [relationship]'s agent to what the user asked for last (ADR 0111,
  /// [reconcileRelationshipAgent]): the maintenance pass's repair for a
  /// live person. It creates an agent a lost background ensure never wrote,
  /// brings back one the reaper or the delete cascade destroyed, and keeps
  /// the user's stop when it is newer than every mark and resume, whatever
  /// a concurrent write left. [conflicting] are the person's versions held
  /// as open sync conflicts.
  Future<void> reconcileAgent(
    RelationshipEntry relationship, {
    List<RelationshipEntry> conflicting = const [],
  }) async {
    final agentId = relationshipAgentIdFor(relationship.meta.id);
    final existing = await _repository.getEntity(agentId);
    final identity = existing is AgentIdentityEntity ? existing : null;
    final deletedAt = identity == null
        ? await _repository.deletedAgentAt(agentId)
        : null;
    final decision = reconcileRelationshipAgent(
      person: relationship.data,
      identity: identity,
      deletedAt: deletedAt,
      conflicting: [for (final version in conflicting) version.data],
    );
    switch (decision) {
      case RelationshipAgentReconciliation.none:
        return;
      case RelationshipAgentReconciliation.create:
        if (deletedAt != null) await _repository.forgetDeletedAgent(agentId);
        await ensureAgentForRelationship(relationship);
      case RelationshipAgentReconciliation.activate:
        if (await _agentService.resumeAgent(agentId)) {
          await _activateRuntime(
            agentId,
            relationshipId: relationship.meta.id,
            reason: 'relationship agent reconciled',
          );
        }
      case RelationshipAgentReconciliation.pause:
        if (await _agentService.pauseAgent(agentId)) {
          _stopRuntime(agentId);
        }
      case RelationshipAgentReconciliation.destroy:
        if (await _agentService.destroyAgent(agentId)) {
          _stopRuntime(agentId);
        }
    }
  }

  /// Subscribes an active agent and queues one €0 evaluation, so a person
  /// asked for after the cadence hour need not wait a day for a register.
  Future<void> _activateRuntime(
    String agentId, {
    required String relationshipId,
    required String reason,
  }) async {
    await registerSubscription(agentId, relationshipId: relationshipId);
    _orchestrator.enqueueManualWake(agentId: agentId, reason: reason);
  }

  /// Takes a paused or destroyed agent out of every wake path.
  void _stopRuntime(String agentId) {
    _agentService
      ..cancelPendingWake(agentId)
      ..abortRunningWake(agentId);
    removeSubscription(agentId);
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
    _stopRuntime(agentId);
    return true;
  }

  /// The explicit "Brief me" trigger (plan v2 phase 5 item 5): ensures
  /// the agent exists — Brief me on a not-yet-important person is the
  /// plan's "explicit enable" — then routes one manual wake through the
  /// LLM tier via the report-refresh token. There is no confirmation step:
  /// the briefing card names the model and provider before this is called
  /// (ADR 0061). A missing model surfaces as the failed wake's *Choose a
  /// model*.
  Future<void> requestBriefing(RelationshipEntry relationship) async {
    final identity = await ensureAgentForRelationship(relationship);
    if (identity == null) return;
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
