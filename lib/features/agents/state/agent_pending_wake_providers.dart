import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
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

final FutureProviderFamily<String?, String?> pendingWakeTargetTitleProvider =
    FutureProvider.family<String?, String?>((
      ref,
      String? entryId,
    ) async {
      if (entryId == null || entryId.isEmpty) {
        return null;
      }

      // Re-fetch when the journal entry is updated (e.g. title is set after
      // creation), so the UI reactively shows the new title.
      final notifications = ref.watch(updateNotificationsProvider);
      ref.watch(
        StreamProvider<void>((ref) {
          return notifications.updateStream.where(
            (ids) => ids.contains(entryId),
          );
        }),
      );

      final journalDb = ref.watch(journalDbProvider);
      final entry = await journalDb.journalEntityById(entryId);

      return switch (entry) {
        Task(:final data) => data.title,
        ProjectEntry(:final data) => data.title,
        _ => null,
      };
    });

/// Fetches wake runs from the last 24 hours and groups them by hour.
///
/// Each bucket includes a per-reason breakdown (subscription, creation, etc.)
/// to help diagnose unexpected spikes in agent activity.
final hourlyWakeActivityProvider = FutureProvider<List<HourlyWakeActivity>>((
  ref,
) async {
  ref.watch(agentUpdateStreamProvider(agentNotification));

  final repository = ref.watch(agentRepositoryProvider);
  final now = clock.now();
  final since = now.subtract(const Duration(hours: 24));
  final runs = await repository.getWakeRunsInWindow(since: since, until: now);

  // Group runs into hourly buckets.
  final buckets = <DateTime, Map<String, int>>{};
  for (final run in runs) {
    final created = run.createdAt;
    final hourKey = DateTime(
      created.year,
      created.month,
      created.day,
      created.hour,
    );
    final reasons = buckets.putIfAbsent(hourKey, () => <String, int>{});
    reasons[run.reason] = (reasons[run.reason] ?? 0) + 1;
  }

  // Build sorted list covering all 24 hours (even empty ones).
  final result = <HourlyWakeActivity>[];
  for (var h = 0; h < 24; h++) {
    final hourStart = DateTime(
      since.year,
      since.month,
      since.day,
      since.hour + h,
    );
    final reasons = buckets[hourStart] ?? const {};
    final count = reasons.values.fold<int>(0, (sum, c) => sum + c);
    result.add(
      HourlyWakeActivity(hour: hourStart, count: count, reasons: reasons),
    );
  }
  return result;
});
