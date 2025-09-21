import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';

final categoriesListControllerProvider = NotifierProvider<
    CategoriesListController, AsyncValue<List<CategoryDefinition>>>(
  CategoriesListController.new,
);

final categoriesStreamProvider =
    StreamProvider<List<CategoryDefinition>>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.watchCategories();
});

class CategoriesListController
    extends Notifier<AsyncValue<List<CategoryDefinition>>> {
  late final CategoryRepository _repository;
  StreamSubscription<List<CategoryDefinition>>? _subscription;

  @override
  AsyncValue<List<CategoryDefinition>> build() {
    _repository = ref.watch(categoryRepositoryProvider);
    _subscription?.cancel();
    _subscription = _repository.watchCategories().listen(
      (categories) {
        state = AsyncValue.data(categories);
      },
      onError: (Object error, StackTrace stackTrace) {
        state = AsyncValue.error(error, stackTrace);
      },
    );

    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });

    return const AsyncValue<List<CategoryDefinition>>.loading();
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _repository.deleteCategory(id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
