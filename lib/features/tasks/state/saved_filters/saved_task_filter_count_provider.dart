import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_page_state.dart';
import 'package:lotti/classes/saved_task_filter.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_activator.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_repository.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/state/task_due_day_provider.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';

/// Override hook so widget tests can provide a fake repository without going
/// through GetIt.
final Provider<SavedTaskFilterCountRepository>
savedTaskFilterCountRepositoryProvider =
    Provider.autoDispose<SavedTaskFilterCountRepository>(
      savedTaskFilterCountRepository,
      name: 'savedTaskFilterCountRepositoryProvider',
    );
SavedTaskFilterCountRepository savedTaskFilterCountRepository(Ref ref) {
  return SavedTaskFilterCountRepository(
    db: ref.read(journalDbProvider),
    cache: getIt<EntitiesCacheService>(),
    agentRepository: AgentRepository(ref.read(agentDatabaseProvider)),
  );
}

/// Debounce window for notification-driven recomputes.
///
/// Each recompute fans out one `repo.count` per saved filter, so an
/// unfiltered burst of `taskNotification`s (e.g. while a batch of tasks
/// arrives over sync) would otherwise re-run every saved-filter count once
/// per batch. `UpdateNotifications` already coalesces sync bursts into ~1s
/// batches and local edits into 100 ms batches; this second, short stage
/// collapses any remaining back-to-back batches into a single recompute.
/// The initial computation is never debounced — only invalidations are.
const _savedTaskFilterCountsDebounce = Duration(milliseconds: 300);

/// Recomputes the provider behind [ref] (debounced) whenever a task-shaped
/// notification arrives — the wiring every task-count provider shares.
///
/// `UpdateNotifications.updateStream` multiplexes both locally-originated
/// notifications and sync-originated ones, so counts stay in step when tasks
/// arrive from another device.
void invalidateOnTaskNotifications(Ref ref) {
  Timer? debounce;
  final sub = ref.read(updateNotificationsProvider).updateStream.listen((
    affectedIds,
  ) {
    if (!affectedIds.contains(taskNotification)) return;
    debounce?.cancel();
    debounce = Timer(_savedTaskFilterCountsDebounce, ref.invalidateSelf);
  });
  ref.onDispose(() {
    debounce?.cancel();
    sub.cancel();
  });
}

/// Live `{savedFilterId → matching task count}` for every persisted saved
/// filter, recomputed (debounced) when the filter list changes or when a
/// task-shaped notification arrives.
///
/// `UpdateNotifications.updateStream` multiplexes both locally-originated
/// notifications and sync-originated ones (the latter are debounced by
/// `UpdateNotifications` and flushed onto the same controller), so counts
/// stay in sync when tasks arrive from another device.
final FutureProvider<Map<String, int>> savedTaskFilterCountsProvider =
    FutureProvider.autoDispose<Map<String, int>>(
      savedTaskFilterCounts,
      name: 'savedTaskFilterCountsProvider',
    );
Future<Map<String, int>> savedTaskFilterCounts(Ref ref) async {
  final saved =
      ref.watch(savedTaskFiltersControllerProvider).value ??
      const <SavedTaskFilter>[];
  if (saved.isEmpty) return const <String, int>{};

  invalidateOnTaskNotifications(ref);

  final repo = ref.watch(savedTaskFilterCountRepositoryProvider);
  final counts = await Future.wait(
    saved.map((filter) => repo.count(filter.filter)),
  );

  return {
    for (var i = 0; i < saved.length; i++) saved[i].id: counts[i],
  };
}

/// Live `{savedFilterId → due urgency}` for every saved filter: whether the
/// open tasks it matches include an overdue one (red marker), else one due
/// today (orange marker), else neither.
///
/// Recomputed on the same triggers as [savedTaskFilterCountsProvider], and
/// at local midnight, when yesterday's due-today tasks turn overdue without
/// any task changing.
final FutureProvider<Map<String, DueDateUrgency>>
savedTaskFilterDueUrgenciesProvider =
    FutureProvider.autoDispose<Map<String, DueDateUrgency>>(
      savedTaskFilterDueUrgencies,
      name: 'savedTaskFilterDueUrgenciesProvider',
    );
Future<Map<String, DueDateUrgency>> savedTaskFilterDueUrgencies(
  Ref ref,
) async {
  final saved =
      ref.watch(savedTaskFiltersControllerProvider).value ??
      const <SavedTaskFilter>[];
  if (saved.isEmpty) return const <String, DueDateUrgency>{};

  ref.watch(taskDueDayProvider);
  invalidateOnTaskNotifications(ref);

  final repo = ref.watch(savedTaskFilterCountRepositoryProvider);
  final urgencies = await Future.wait(
    saved.map((filter) => repo.dueUrgency(filter.filter)),
  );

  return {
    for (var i = 0; i < saved.length; i++) saved[i].id: urgencies[i],
  };
}

/// The filter used to count "all tasks" — every status, no other constraint.
///
/// The count repository treats an empty status set as "no constraint → 0", so
/// the rail/sheet "All" total selects every known status explicitly. Empty
/// category / label / priority sets then read as "any", giving the true total.
const TasksFilter _allTasksFilter = TasksFilter(
  selectedTaskStatuses: {...allTaskStatuses},
);

/// Live total task count for the rail/sheet "All" entry.
///
/// Mirrors [savedTaskFilterCountsProvider]'s debounce + notification wiring so
/// the total stays in step with the per-filter counts (stale-while-revalidate
/// on the consumer side via `skipLoadingOnReload`). Recomputed when a
/// task-shaped notification arrives.
final FutureProvider<int> allTasksTotalCountProvider =
    FutureProvider.autoDispose<int>(
      allTasksTotalCount,
      name: 'allTasksTotalCountProvider',
    );
Future<int> allTasksTotalCount(Ref ref) async {
  invalidateOnTaskNotifications(ref);

  final repo = ref.watch(savedTaskFilterCountRepositoryProvider);
  return repo.count(_allTasksFilter);
}

/// Live count of tasks matching the current ad-hoc tasks filter — the
/// magnitude shown on the rail's "Custom" pill so an active filter never hides
/// how many tasks it matches.
///
/// Recomputes when the live filter changes (it watches the page state) and,
/// like the other count providers, when a task-shaped notification arrives
/// (debounced). It mirrors the live list's empty-status handling: the count
/// repository treats an empty status set as "no constraint → 0", but the list
/// expands it to every status, so an empty selection is expanded to
/// [allTaskStatuses] here too and the pill's number agrees with the list.
final FutureProvider<int> currentTasksFilterCountProvider =
    FutureProvider.autoDispose<int>(
      currentTasksFilterCount,
      name: 'currentTasksFilterCountProvider',
    );
Future<int> currentTasksFilterCount(Ref ref) async {
  final pageState = ref.watch(journalPageControllerProvider(true));
  final live = liveTasksFilterFor(pageState);
  final effective = live.selectedTaskStatuses.isEmpty
      ? live.copyWith(selectedTaskStatuses: {...allTaskStatuses})
      : live;

  invalidateOnTaskNotifications(ref);

  final repo = ref.watch(savedTaskFilterCountRepositoryProvider);
  return repo.count(effective);
}
