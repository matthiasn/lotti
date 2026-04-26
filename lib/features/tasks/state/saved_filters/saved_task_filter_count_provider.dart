import 'dart:async';

import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_repository.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'saved_task_filter_count_provider.g.dart';

/// Override hook so widget tests can provide a [SavedTaskFilterCountRepository]
/// without going through GetIt. Production reads the live one from GetIt at
/// build time.
@riverpod
SavedTaskFilterCountRepository savedTaskFilterCountRepository(Ref ref) {
  return SavedTaskFilterCountRepository();
}

/// Live count of tasks matching the saved filter with [savedFilterId].
///
/// Resolves the saved filter from [savedTaskFiltersControllerProvider],
/// delegates the count to [SavedTaskFilterCountRepository], and invalidates
/// itself whenever a task-shaped change is broadcast on
/// [UpdateNotifications.updateStream]. The stream multiplexes both
/// locally-originated notifications and sync-originated ones (the latter are
/// debounced by `UpdateNotifications` and flushed onto the same controller),
/// so counts stay in sync when tasks arrive from another device. Returns 0
/// when the saved id no longer resolves (concurrent delete) so the sidebar
/// doesn't show a stale number.
@riverpod
Future<int> savedTaskFilterCount(Ref ref, String savedFilterId) async {
  final saved =
      ref.watch(savedTaskFiltersControllerProvider).value ??
      const <SavedTaskFilter>[];
  final view = saved.where((f) => f.id == savedFilterId).cast<SavedTaskFilter?>()
      .firstWhere((_) => true, orElse: () => null);
  if (view == null) return 0;

  // Re-run the count whenever a task notification fires. The subscription
  // lives for as long as this provider element.
  final updates = getIt<UpdateNotifications>();
  final sub = updates.updateStream.listen((affectedIds) {
    if (affectedIds.contains(taskNotification)) {
      ref.invalidateSelf();
    }
  });
  ref.onDispose(sub.cancel);

  return ref.read(savedTaskFilterCountRepositoryProvider).count(view.filter);
}
