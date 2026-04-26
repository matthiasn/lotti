import 'dart:async';

import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_repository.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'saved_task_filter_count_provider.g.dart';

/// Override hook so widget tests can provide a fake repository without going
/// through GetIt.
@riverpod
SavedTaskFilterCountRepository savedTaskFilterCountRepository(Ref ref) {
  return SavedTaskFilterCountRepository(
    db: getIt<JournalDb>(),
    cache: getIt<EntitiesCacheService>(),
    agentRepository: AgentRepository(getIt<AgentDatabase>()),
  );
}

/// Live `{savedFilterId → matching task count}` for every persisted saved
/// filter, recomputed when the filter list changes or when a task-shaped
/// notification arrives.
///
/// `UpdateNotifications.updateStream` multiplexes both locally-originated
/// notifications and sync-originated ones (the latter are debounced by
/// `UpdateNotifications` and flushed onto the same controller), so counts
/// stay in sync when tasks arrive from another device.
@riverpod
Future<Map<String, int>> savedTaskFilterCounts(Ref ref) async {
  final saved =
      ref.watch(savedTaskFiltersControllerProvider).value ??
      const <SavedTaskFilter>[];

  final sub = getIt<UpdateNotifications>().updateStream.listen((affectedIds) {
    if (affectedIds.contains(taskNotification)) ref.invalidateSelf();
  });
  ref.onDispose(sub.cancel);

  if (saved.isEmpty) return const <String, int>{};

  final repo = ref.read(savedTaskFilterCountRepositoryProvider);
  final counts = await Future.wait(
    saved.map((view) => repo.count(view.filter)),
  );

  return {
    for (var i = 0; i < saved.length; i++) saved[i].id: counts[i],
  };
}

/// Convenience family — reads a single saved filter's count from the
/// aggregated map. Returns 0 when the id no longer resolves (concurrent
/// delete) so the sidebar doesn't show a stale number.
@riverpod
Future<int> savedTaskFilterCount(Ref ref, String savedFilterId) async {
  final all = await ref.watch(savedTaskFilterCountsProvider.future);
  return all[savedFilterId] ?? 0;
}
