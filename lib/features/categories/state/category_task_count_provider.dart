import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';

/// Provider that returns task counts for all categories in a single query.
///
/// Returns a [Map] from category ID to task count. Categories with zero tasks
/// are omitted from the map.
///
/// Auto-rebuilds when task or category notifications fire.
// ignore: specify_nonobvious_property_types
final categoryTaskCountsProvider = FutureProvider.autoDispose<Map<String, int>>(
  (ref) async {
    final repository = ref.watch(categoryRepositoryProvider);
    final notifications = getIt<UpdateNotifications>();

    final sub = notifications.updateStream
        .where(
          (ids) =>
              ids.contains(categoriesNotification) ||
              ids.contains(taskNotification),
        )
        .listen((_) => ref.invalidateSelf());
    ref.onDispose(sub.cancel);

    return repository.getTaskCountsByCategory();
  },
);

/// Provider that returns the task count for a single category.
///
/// Reads from the batch [categoryTaskCountsProvider] so that all tiles
/// share a single database query.
// ignore: specify_nonobvious_property_types
final categoryTaskCountProvider = FutureProvider.autoDispose
    .family<int, String>((ref, categoryId) async {
      final counts = await ref.watch(categoryTaskCountsProvider.future);
      return counts[categoryId] ?? 0;
    });
