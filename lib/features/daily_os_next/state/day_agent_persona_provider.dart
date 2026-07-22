import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_directive_models.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart'
    as agent_providers;
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/services/db_notification.dart';

/// Observable persona state of the agent working one day (ADR 0032 §7):
/// character animation and status badges map to these runtime facts, never
/// to invented moods.
enum DayAgentPersonaState {
  /// No pending or running work for the day.
  idle,

  /// A wake for this day is currently executing.
  working,

  /// The newest status event for the day is `attentionNeeded`.
  attention,

  /// The newest status event for the day is `dayClosed` (and nothing is
  /// running) — the day wrapped up.
  celebrating,
}

/// Derives the persona state for the date's day agent from observable
/// runtime facts (ADR 0032 §7 + phase 4 badge):
///
/// 1. `working` while a wake for this day executes (per-day agent or the
///    coordinator scoped to this day's workspace);
/// 2. otherwise the newest `DayStatusEventEntity` for the day decides —
///    `attentionNeeded` → [DayAgentPersonaState.attention], `dayClosed` →
///    [DayAgentPersonaState.celebrating];
/// 3. otherwise `idle` (an `onTrack` event is deliberate silence-equivalent).
// ignore: specify_nonobvious_property_types
final dayAgentPersonaStateProvider = FutureProvider.autoDispose
    .family<DayAgentPersonaState, DateTime>((ref, date) async {
      if (ref.watch(dayAgentIsRunningProvider(date))) {
        return DayAgentPersonaState.working;
      }
      final dayId = dayAgentIdForDate(date);
      // Status events land under the day-owner's id; refresh on both the
      // day-scoped and broad agent notifications (sync-originated writes
      // notify by agent id).
      ref
        ..watch(agentUpdateStreamProvider(dayId))
        ..watch(agentUpdateStreamProvider(agentNotification));
      final owner = await ref.watch(
        agent_providers.dayAgentProvider(date).future,
      );
      if (owner is! AgentIdentityEntity) return DayAgentPersonaState.idle;
      final repository = ref.watch(agentRepositoryProvider);
      final rows = await repository.getEntitiesByAgentId(
        owner.agentId,
        type: AgentEntityTypes.dayStatusEvent,
      );
      DayStatusEventEntity? newest;
      for (final row in rows) {
        if (row is! DayStatusEventEntity) continue;
        if (row.deletedAt != null || row.dayId != dayId) continue;
        if (newest == null || row.raisedAt.isAfter(newest.raisedAt)) {
          newest = row;
        }
      }
      return switch (newest?.status) {
        DayStatusKind.attentionNeeded => DayAgentPersonaState.attention,
        DayStatusKind.dayClosed => DayAgentPersonaState.celebrating,
        DayStatusKind.onTrack || null => DayAgentPersonaState.idle,
      };
    });

/// Total tokens the day's own agent has spent, or null when the day is
/// coordinator-owned (pre-cutover) — the coordinator's lifetime aggregate
/// would misattribute other days' spend, so the badge shows nothing there
/// (ADR 0032 phase 4: query by agent id, no new storage).
// ignore: specify_nonobvious_property_types
final dayAgentTokenSpendProvider = FutureProvider.autoDispose
    .family<int?, DateTime>((ref, date) async {
      final owner = await ref.watch(
        agent_providers.dayAgentProvider(date).future,
      );
      if (owner is! AgentIdentityEntity || !isPerDayAgentId(owner.agentId)) {
        return null;
      }
      ref.watch(agentUpdateStreamProvider(owner.agentId));
      final repository = ref.watch(agentRepositoryProvider);
      final usage = await repository.getTokenUsageForAgent(owner.agentId);
      var total = 0;
      for (final row in usage) {
        total +=
            (row.inputTokens ?? 0) +
            (row.outputTokens ?? 0) +
            (row.thoughtsTokens ?? 0);
      }
      return total;
    });
