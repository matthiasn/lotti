import 'package:clock/clock.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_phase_a.dart';
import 'package:lotti/features/relationships/service/relationship_agent_service.dart';
import 'package:lotti/services/domain_logging.dart';

/// Startup and pre-scan maintenance for relationship agents (the
/// [AgentRuntimeMaintenance] contract, the goal-runtime shape):
/// subscriptions are in-memory and must be rebuilt every launch; cadence
/// wakes are re-armed by each run but self-healed here in case the last
/// run died before re-arming; an agent whose person was deleted without
/// its teardown running is reaped before anything is healed; and every live
/// person's agent is reconciled to what the user asked for last (ADR 0111,
/// `specs/tla/RelationshipAgentLifecycle.tla`).
///
/// Every per-agent repair is individually contained — one broken
/// relationship must never take the others (or another feature's
/// maintenance) down with it.
class RelationshipRuntimeMaintenance implements AgentRuntimeMaintenance {
  RelationshipRuntimeMaintenance({
    required this._agentService,
    required this._repository,
    required this._syncService,
    required this._relationshipAgentService,
    required this._relationshipRepository,
    this._domainLogger,
    this.inferenceIsConfigured,
    this.onIdentityRestored,
  });

  final AgentService _agentService;
  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final RelationshipAgentService _relationshipAgentService;
  final RelationshipRepository _relationshipRepository;
  final DomainLogger? _domainLogger;

  /// Checks the same effective route as Phase B, including device settings.
  final Future<bool> Function(AgentIdentityEntity)? inferenceIsConfigured;

  /// Rescans pending retries after an active identity arrives through sync.
  final void Function()? onIdentityRestored;

  @override
  Future<void> restoreSubscriptions() async {
    final List<AgentIdentityEntity> agents;
    try {
      agents = await _activeRelationshipAgents();
    } catch (error, stackTrace) {
      _log('restoreSubscriptions', 'listAgents', error, stackTrace);
      return;
    }
    for (final identity in agents) {
      try {
        await _relationshipAgentService.registerSubscription(identity.agentId);
      } catch (error, stackTrace) {
        _log('restoreSubscriptions', identity.agentId, error, stackTrace);
      }
    }
  }

  @override
  Future<void> beforeWakeScan() async {
    final now = clock.now();
    final List<AgentIdentityEntity> agents;
    try {
      agents = await _activeRelationshipAgents();
    } catch (error, stackTrace) {
      _log('beforeWakeScan', 'listAgents', error, stackTrace);
      return;
    }
    for (final identity in agents) {
      try {
        if (await _reapIfRelationshipGone(identity.agentId)) continue;
        final record = await _repository.getEntity(
          scheduledWakeRecordId(
            identity.agentId,
            workspaceKey: relationshipCadenceWorkspaceKey,
          ),
        );
        final needsHeal =
            record is! ScheduledWakeEntity ||
            (record.status == ScheduledWakeStatus.consumed &&
                record.scheduledAt.isBefore(now));
        if (needsHeal) {
          await _syncService.upsertEntity(
            relationshipCadenceWake(identity.agentId, now),
          );
        }
        await _resumeConfiguredEscalations(identity, now);
      } catch (error, stackTrace) {
        _log('beforeWakeScan', identity.agentId, error, stackTrace);
      }
    }
    await _reconcileLivePeople();
  }

  /// Every live person's agent to where the user's latest word puts it: a
  /// missing one created, one the reaper or the cascade destroyed brought
  /// back, the user's stop kept over whatever a concurrent write left
  /// ([RelationshipAgentService.reconcileAgent]). Private people included —
  /// a display preference must not decide whether someone is tracked.
  Future<void> _reconcileLivePeople() async {
    final List<RelationshipEntry> people;
    try {
      people = await _relationshipRepository.getAllRelationshipsUnfiltered();
    } catch (error, stackTrace) {
      _log('reconcile', 'listRelationships', error, stackTrace);
      return;
    }
    for (final person in people) {
      try {
        await _relationshipAgentService.reconcileAgent(
          person,
          conflicting: await _relationshipRepository.openConflictVersions(
            person.meta.id,
          ),
        );
      } catch (error, stackTrace) {
        _log('reconcile', person.meta.id, error, stackTrace);
      }
    }
  }

  /// A config repair shortens only pending, backed-off escalation retries.
  /// The sync-aware write causally supersedes the previous deadline and clears
  /// its lease; the scheduled manager still elects one device before inference.
  /// Backed off means the last wake failed, read from the outcome watermarks
  /// every device agrees on (`lastWakeMayHaveFailed`, ADR 0115) — or, for a
  /// row no failed wake has stamped since the watermark existed, from the
  /// failure count: a deadline shortened on a stale count is harmless, a
  /// face shown from one is not.
  Future<void> _resumeConfiguredEscalations(
    AgentIdentityEntity identity,
    DateTime now,
  ) async {
    final configured = inferenceIsConfigured;
    if (configured == null) return;
    final state = await _repository.getAgentState(identity.agentId);
    if (state == null || !state.lastWakeMayHaveFailed) return;
    final records = await _repository.getEntitiesByAgentId(
      identity.agentId,
      type: 'scheduledWake',
    );
    final retries = records
        .whereType<ScheduledWakeEntity>()
        .where(
          (record) =>
              record.status == ScheduledWakeStatus.pending &&
              record.scheduledAt.isAfter(now) &&
              relationshipEscalationDueDayFromTriggerTokens(
                    record.triggerTokens.toSet(),
                  ) !=
                  null,
        )
        .toList();
    if (retries.isEmpty || !await configured(identity)) return;
    await _syncService.runInTransaction(() async {
      for (final record in retries) {
        // Check and update atomically: sync may consume or replace a retry
        // while route resolution awaits storage.
        final current = await _repository.getEntity(record.id);
        if (current != record) continue;
        await _syncService.upsertEntity(
          record.copyWith(
            scheduledAt: now.toUtc(),
            updatedAt: now,
            leaseHostId: null,
            leaseUntil: null,
          ),
        );
      }
    });
  }

  /// Tears down an agent whose person is gone, and reports whether it did.
  ///
  /// The delete cascade's agent leg is best-effort by design — the details
  /// page fires it unawaited, and the generic journal delete path (a deep
  /// link to the entry, a synced-in tombstone) never fires it at all. This
  /// is the repair the delete surfaces defer to: without it the orphaned
  /// identity stays `active`, so the heal below would re-arm its cadence
  /// wake on every scan and the agent would wake about a person who no
  /// longer exists, forever.
  ///
  /// The relationship is read UNFILTERED — a private person hidden by the
  /// display preference is not a deleted one, and reaping their agent would
  /// silently un-track them on that device alone. A missing link is the
  /// creation race, not a deletion, so it never reaps; nor does a person
  /// with no row at all, which has not arrived yet. Only a tombstone reaps
  /// (ADR 0111): the agent and its link sync apart from the journal, and a
  /// device that received them first once destroyed the agent everywhere.
  Future<bool> _reapIfRelationshipGone(String agentId) async {
    final relationshipId = await _relationshipAgentService
        .watchedRelationshipId(agentId);
    if (relationshipId == null) return false;
    // No row is a person that has not arrived yet — the agent and its link
    // travel apart from the journal and can come first — not a deleted one.
    if (!await _relationshipRepository.isRelationshipDeleted(relationshipId)) {
      return false;
    }
    await _relationshipAgentService.handleRelationshipDeleted(relationshipId);
    return true;
  }

  /// Mirrors a synced-in relationship-agent identity into the runtime
  /// mid-session: an active one subscribes to its relationship immediately,
  /// a paused or destroyed one is unsubscribed. Failures are contained: the
  /// sync apply loop must never stall on one agent.
  @override
  Future<void> onIdentityReceived(AgentIdentityEntity identity) async {
    if (identity.kind != AgentKinds.relationshipAgent) return;
    try {
      if (identity.lifecycle != AgentLifecycle.active) {
        _relationshipAgentService.removeSubscription(identity.agentId);
        return;
      }
      await _relationshipAgentService.registerSubscription(identity.agentId);
      onIdentityRestored?.call();
    } catch (error, stackTrace) {
      _log('onIdentityReceived', identity.agentId, error, stackTrace);
    }
  }

  Future<List<AgentIdentityEntity>> _activeRelationshipAgents() async {
    final agents = await _agentService.listAgents(
      lifecycle: AgentLifecycle.active,
    );
    return agents
        .where((agent) => agent.kind == AgentKinds.relationshipAgent)
        .toList(growable: false);
  }

  void _log(
    String phase,
    String agentId,
    Object error,
    StackTrace stackTrace,
  ) {
    _domainLogger?.error(
      LogDomain.agentRuntime,
      error,
      message: 'relationship runtime maintenance $phase failed for one agent',
      stackTrace: stackTrace,
    );
  }
}
