import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/hourly_wake_activity.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/db_notification.dart';

final pendingWakeRecordsProvider = FutureProvider<List<PendingWakeRecord>>((
  ref,
) async {
  ref.watch(agentUpdateStreamProvider(agentNotification));

  final agentService = ref.watch(agentServiceProvider);
  final repository = ref.watch(agentRepositoryProvider);
  final identities = await agentService.listAgents();
  final statesByAgentId = await repository.getAgentStatesByAgentIds(
    identities.map((identity) => identity.agentId).toList(),
  );

  final records = <PendingWakeRecord>[];
  for (final identity in identities) {
    final state = statesByAgentId[identity.agentId];
    if (state == null || state.deletedAt != null) {
      continue;
    }

    final nextWakeAt = state.nextWakeAt;
    if (nextWakeAt != null) {
      records.add(
        PendingWakeRecord(
          agent: identity,
          state: state,
          type: PendingWakeType.pending,
          dueAt: nextWakeAt,
        ),
      );
    }

    final scheduledWakeAt = state.scheduledWakeAt;
    if (scheduledWakeAt != null) {
      records.add(
        PendingWakeRecord(
          agent: identity,
          state: state,
          type: PendingWakeType.scheduled,
          dueAt: scheduledWakeAt,
        ),
      );
    }
  }

  records.sort((a, b) => a.dueAt.compareTo(b.dueAt));
  return records;
});

final StreamProviderFamily<void, String> _entryUpdateProvider = StreamProvider
    .autoDispose
    .family<void, String>((
      ref,
      entryId,
    ) {
      final notifications = ref.watch(updateNotificationsProvider);
      return notifications.updateStream
          .where((ids) => ids.contains(entryId))
          .map<void>((_) {});
    });

final FutureProviderFamily<String?, String?> pendingWakeTargetTitleProvider =
    FutureProvider.family<String?, String?>((
      ref,
      String? entryId,
    ) async {
      if (entryId == null || entryId.isEmpty) {
        return null;
      }

      ref.watch(_entryUpdateProvider(entryId));

      final journalDb = ref.watch(journalDbProvider);
      final entry = await journalDb.journalEntityById(entryId);

      return switch (entry) {
        Task(:final data) => data.title,
        ProjectEntry(:final data) => data.title,
        _ => null,
      };
    });

/// Snapshot of currently-running agent wake instances paired with the
/// linked task / project title the agent is acting on. Falls back to
/// the agent's own displayName when the agent has no linked subject
/// (e.g. an improver agent), and finally to the agentId so the row
/// never renders empty.
class OngoingWakeRecord {
  const OngoingWakeRecord({
    required this.agentId,
    required this.title,
    required this.startedAt,
  });

  final String agentId;
  final String title;
  final DateTime startedAt;

  String get id => 'ongoing:$agentId';
}

/// Stream over `WakeRunner.runningAgentIds` used to invalidate
/// `ongoingWakeRecordsProvider` whenever the set of active agents
/// changes. Kept private so callers reach for the structured record
/// list above instead of the raw IDs.
final StreamProvider<Set<String>> _runningAgentIdsStreamProvider =
    StreamProvider.autoDispose<Set<String>>((ref) {
      final runner = ref.watch(wakeRunnerProvider);
      return runner.runningAgentIds;
    });

/// Stream of currently-running wakes with their start timestamps and a
/// human-readable title. Emits initially with whatever is already
/// running, then on every WakeRunner state change. Templates and
/// identities are resolved lazily so a slow lookup doesn't block the
/// "running" indicator from updating.
final FutureProvider<List<OngoingWakeRecord>> ongoingWakeRecordsProvider =
    FutureProvider.autoDispose<List<OngoingWakeRecord>>((ref) async {
      final runner = ref.watch(wakeRunnerProvider);
      // Re-emit when the runner's running set changes.
      ref.listen<AsyncValue<Set<String>>>(_runningAgentIdsStreamProvider, (
        prev,
        next,
      ) {
        if (next.hasValue) ref.invalidateSelf();
      });

      final startedById = runner.activeStartedAtById;
      if (startedById.isEmpty) return const <OngoingWakeRecord>[];

      final service = ref.watch(agentServiceProvider);
      final repository = ref.watch(agentRepositoryProvider);
      final results = <OngoingWakeRecord>[];
      for (final entry in startedById.entries) {
        final agentId = entry.key;
        final startedAt = entry.value;

        String? title;
        // Prefer the linked task/project title — that's what the user
        // identifies the wake by ("Improve Agent UI/UX…"), not the
        // agent persona behind it.
        try {
          final stateEntity = await repository.getAgentState(agentId);
          final slots = stateEntity?.mapOrNull(agentState: (s) => s.slots);
          final subjectId = slots?.activeTaskId ?? slots?.activeProjectId;
          if (subjectId != null && subjectId.isNotEmpty) {
            title = await ref.watch(
              pendingWakeTargetTitleProvider(subjectId).future,
            );
            title = title?.trim();
          }
        } catch (_) {
          // Subject lookup is best-effort.
        }

        if (title == null || title.isEmpty) {
          final identity = await service.getAgent(agentId);
          if (identity is AgentIdentityEntity) {
            title = identity.displayName.trim();
          }
        }

        results.add(
          OngoingWakeRecord(
            agentId: agentId,
            title: title != null && title.isNotEmpty ? title : agentId,
            startedAt: startedAt,
          ),
        );
      }

      results.sort((a, b) => a.startedAt.compareTo(b.startedAt));
      return results;
    });

final hourlyWakeActivityProvider = FutureProvider<List<HourlyWakeActivity>>((
  ref,
) async {
  ref.watch(agentUpdateStreamProvider(agentNotification));

  final repository = ref.watch(agentRepositoryProvider);
  final now = clock.now();
  final currentHour = DateTime(now.year, now.month, now.day, now.hour);
  final since = currentHour.subtract(const Duration(hours: 23));
  final runs = await repository.getWakeRunsInWindow(since: since, until: now);

  final buckets = <DateTime, Map<String, int>>{};
  for (final run in runs) {
    final created = run.createdAt.toLocal();
    final hourKey = DateTime(
      created.year,
      created.month,
      created.day,
      created.hour,
    );
    final reasons = buckets.putIfAbsent(hourKey, () => <String, int>{});
    reasons[run.reason] = (reasons[run.reason] ?? 0) + 1;
  }

  final result = <HourlyWakeActivity>[];
  for (var i = 23; i >= 0; i--) {
    final hourStart = currentHour.subtract(Duration(hours: i));
    final reasons = buckets[hourStart] ?? const {};
    final count = reasons.values.fold<int>(0, (sum, c) => sum + c);
    result.add(
      HourlyWakeActivity(hour: hourStart, count: count, reasons: reasons),
    );
  }
  return result;
});
