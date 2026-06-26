import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_repository.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/get_it.dart';
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
    db: getIt<JournalDb>(),
    cache: getIt<EntitiesCacheService>(),
    agentRepository: AgentRepository(getIt<AgentDatabase>()),
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

  Timer? debounce;
  final sub = getIt<UpdateNotifications>().updateStream.listen((affectedIds) {
    if (!affectedIds.contains(taskNotification)) return;
    debounce?.cancel();
    debounce = Timer(_savedTaskFilterCountsDebounce, ref.invalidateSelf);
  });
  ref.onDispose(() {
    debounce?.cancel();
    sub.cancel();
  });

  final repo = ref.watch(savedTaskFilterCountRepositoryProvider);
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
final FutureProviderFamily<int, String> savedTaskFilterCountProvider =
    FutureProvider.autoDispose.family<int, String>(
      savedTaskFilterCount,
      name: 'savedTaskFilterCountProvider',
    );
Future<int> savedTaskFilterCount(Ref ref, String savedFilterId) async {
  final all = await ref.watch(savedTaskFilterCountsProvider.future);
  return all[savedFilterId] ?? 0;
}
