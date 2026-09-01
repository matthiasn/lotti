import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';

/// Streams the list of categories for the settings list and any consumer
/// that needs to react to category changes. Backed by
/// [CategoryRepository.watchCategories], so it re-emits on category and
/// private-mode-toggle notifications.
///
/// Scoped by lockdown: while a lockdown is active only the locked categories
/// are emitted, so every picker built on this stream (goal creation, the
/// logo menu) stays inside the lockdown without checking for itself.
final categoriesStreamProvider = StreamProvider<List<CategoryDefinition>>((
  ref,
) {
  final repository = ref.watch(categoryRepositoryProvider);
  final lockdown = ref.watch(lockdownControllerProvider);
  return repository.watchCategories().map(
    (categories) => lockdown.isActive
        ? categories.where((c) => lockdown.allows(c.id)).toList()
        : categories,
  );
});
