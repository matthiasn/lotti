import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';

/// Streams the full list of categories for the settings list and any consumer
/// that needs to react to category changes. Backed by
/// [CategoryRepository.watchCategories], so it re-emits on category and
/// private-mode-toggle notifications.
final categoriesStreamProvider = StreamProvider<List<CategoryDefinition>>((
  ref,
) {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.watchCategories();
});
