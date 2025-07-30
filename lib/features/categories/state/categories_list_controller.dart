import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';

final categoriesListControllerProvider = StateNotifierProvider<
    CategoriesListController, AsyncValue<List<CategoryDefinition>>>(
  (ref) => CategoriesListController(ref.watch(categoryRepositoryProvider)),
);

final categoriesStreamProvider =
    StreamProvider<List<CategoryDefinition>>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.watchCategories();
});

class CategoriesListController
    extends StateNotifier<AsyncValue<List<CategoryDefinition>>> {
  CategoriesListController(this._repository)
      : super(const AsyncValue.loading()) {
    _loadCategories();
  }

  final CategoryRepository _repository;

  void _loadCategories() {
    state = const AsyncValue.loading();
    _repository.watchCategories().listen(
      (categories) {
        if (mounted) {
          state = AsyncValue.data(categories);
        }
      },
      onError: (error, stackTrace) {
        if (mounted) {
          state = AsyncValue.error(error, stackTrace);
        }
      },
    );
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _repository.deleteCategory(id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
