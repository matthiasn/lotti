import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_automation_policy.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/project_update_slots.dart';
import 'package:lotti/services/domain_logging.dart';

/// When a project agent updates its report on its own: at most once per
/// update slot, on one device (`specs/tla/ProjectWakeGovernor.tla`).
///
/// A report goes stale when its project changes; staleness is the agent
/// state's two max-joined watermarks, `reportStaleAt` and `reportFreshAt`.
/// While the report is stale, automatic updates are on, and no slot is
/// pending, [arm] arms the next free slot: a synced scheduled-wake record
/// whose id is the agent and the slot's start, so every device that arms it
/// arms the same row. Arming is inert — it starts no work; the scheduled-wake
/// manager fires the slot through its lease on one device, which consumes
/// every pending slot of the agent ([consumeAll]).
///
/// Arming is safe to call from anywhere and as often as anything changes —
/// a local change, the end of a run, state arriving by sync, a restart — and
/// that is the point: whatever path noticed staleness, at most one slot is
/// pending, and the lease turns it into at most one run.
class ProjectUpdateCadence {
  ProjectUpdateCadence({
    required this._repository,
    required this._syncService,
    this.domainLogger,
  });

  final AgentRepository _repository;
  final AgentSyncService _syncService;
  final DomainLogger? domainLogger;

  /// How far ahead [arm] looks for a slot no record exists for yet. A slot
  /// consumed early (with an earlier one) is skipped; a day of hourly slots
  /// is far more than a stale report can have consumed ahead.
  static const _maxSlotsAhead = 48;

  /// Arms the next update slot of [agentId] when its report is stale, its
  /// automatic updates are on and no slot is pending. Returns the pending
  /// slot — the one armed, or the one already there — or null when none is
  /// owed.
  Future<ScheduledWakeEntity?> arm(String agentId) =>
      _syncService.runInTransaction(() async {
        final identity = await _repository.getEntity(agentId);
        if (identity is! AgentIdentityEntity ||
            identity.kind != AgentKinds.projectAgent ||
            !projectAgentAutomaticWakesAllowed(
              config: identity.config,
              lifecycle: identity.lifecycle,
            )) {
          return null;
        }
        final pending = await pendingSlots(agentId);
        if (pending.isNotEmpty) return pending.first;
        final state = await _repository.getAgentState(agentId);
        if (state == null || !state.isReportStale) return null;

        final now = clock.now();
        final interval = effectiveUpdateIntervalMinutes(identity.config);
        var slot = nextProjectUpdateSlot(now, intervalMinutes: interval);
        for (var i = 0; i < _maxSlotsAhead; i++) {
          final existing = await _repository.getEntity(
            projectUpdateSlotRecordId(agentId, slot),
          );
          if (existing == null) break;
          slot = nextProjectUpdateSlot(slot, intervalMinutes: interval);
        }
        final record =
            AgentDomainEntity.scheduledWake(
                  id: projectUpdateSlotRecordId(agentId, slot),
                  agentId: agentId,
                  scheduledAt: slot.toUtc(),
                  status: ScheduledWakeStatus.pending,
                  reason: WakeReason.scheduled.name,
                  updatedAt: now,
                  vectorClock: null,
                  workspaceKey: projectUpdateWorkspaceKey(slot),
                  triggerTokens: const [ProjectUpdateSlots.triggerToken],
                )
                as ScheduledWakeEntity;
        await _syncService.upsertEntity(record);
        _log(
          'armed update slot ${record.workspaceKey} for '
          '${DomainLogger.sanitizeId(agentId)}',
        );
        // The stored row, stamped with this device's clock.
        final stored = await _repository.getEntity(record.id);
        return stored is ScheduledWakeEntity ? stored : record;
      });

  /// Re-plans [agentId]'s pending slot after its update interval changed: a
  /// slot off the new grid's next start is consumed, and the next slot on the
  /// new grid armed when one is owed ([arm]). A pending slot already at that
  /// start is kept, so re-planning to the grid it is on changes nothing.
  Future<ScheduledWakeEntity?> replan(String agentId) =>
      _syncService.runInTransaction(() async {
        final identity = await _repository.getEntity(agentId);
        if (identity is! AgentIdentityEntity ||
            identity.kind != AgentKinds.projectAgent) {
          return null;
        }
        final now = clock.now();
        final next = nextProjectUpdateSlot(
          now,
          intervalMinutes: effectiveUpdateIntervalMinutes(identity.config),
        ).toUtc();
        for (final record in await pendingSlots(agentId)) {
          if (record.scheduledAt.toUtc() != next) await _consume(record, now);
        }
        return arm(agentId);
      });

  /// The pending update slots of [agentId], earliest first.
  Future<List<ScheduledWakeEntity>> pendingSlots(String agentId) async {
    final pending = await _repository.getPendingScheduledWakeRecords();
    return [
      for (final record in pending)
        if (record.agentId == agentId &&
            isProjectUpdateWorkspace(record.workspaceKey))
          record,
    ]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }

  /// Consumes every pending update slot of [agentId]: a run reads the agent
  /// as of its start, which covers every change any of them was armed for.
  /// Also the user's "Skip" and the end of automatic updates.
  Future<int> consumeAll(String agentId) =>
      _syncService.runInTransaction(() async {
        final now = clock.now();
        final pending = await pendingSlots(agentId);
        for (final record in pending) {
          await _consume(record, now);
        }
        return pending.length;
      });

  Future<void> _consume(ScheduledWakeEntity record, DateTime now) =>
      _syncService.upsertEntity(
        record.copyWith(
          status: ScheduledWakeStatus.consumed,
          consumedAt: now,
          updatedAt: now,
        ),
      );

  void _log(String message) =>
      domainLogger?.log(LogDomain.agentRuntime, message, subDomain: 'cadence');
}
