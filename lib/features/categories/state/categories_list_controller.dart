import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';

final categoriesStreamProvider = StreamProvider<List<CategoryDefinition>>((
  ref,
) {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.watchCategories();
});
