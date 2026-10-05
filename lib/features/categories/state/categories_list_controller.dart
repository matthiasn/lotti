import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/state/category_scope_provider.dart';

/// Streams the list of categories for the settings list and any consumer
/// that needs to react to category changes. Backed by
/// [CategoryRepository.watchCategories], so it re-emits on category and
/// private-mode-toggle notifications.
///
/// Scoped by [categoryScopeProvider]: while a lockdown is active only the
/// locked categories are emitted, so every picker built on this stream (goal
/// creation, the logo menu) stays inside the lockdown without checking for
/// itself.
final categoriesStreamProvider = StreamProvider<List<CategoryDefinition>>((
  ref,
) {
  final repository = ref.watch(categoryRepositoryProvider);
  final allows = ref.watch(categoryScopeProvider);
  return repository.watchCategories().map(
    (categories) => allows == null
        ? categories
        : categories.where((c) => allows(c.id)).toList(),
  );
});
