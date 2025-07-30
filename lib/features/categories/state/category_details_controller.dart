import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';

part 'category_details_controller.freezed.dart';

@freezed
class CategoryDetailsState with _$CategoryDetailsState {
  const factory CategoryDetailsState({
    required CategoryDefinition? category,
    required bool isLoading,
    required bool isSaving,
    String? errorMessage,
  }) = _CategoryDetailsState;

  factory CategoryDetailsState.initial() => const CategoryDetailsState(
        category: null,
        isLoading: true,
        isSaving: false,
        errorMessage: null,
      );
}

final categoryDetailsControllerProvider = StateNotifierProvider.family<
    CategoryDetailsController, CategoryDetailsState, String>(
  (ref, categoryId) => CategoryDetailsController(
    ref.watch(categoryRepositoryProvider),
    categoryId,
  ),
);

class CategoryDetailsController extends StateNotifier<CategoryDetailsState> {
  CategoryDetailsController(
    this._repository,
    this._categoryId,
  ) : super(CategoryDetailsState.initial()) {
    _loadCategory();
  }

  final CategoryRepository _repository;
  final String _categoryId;

  void _loadCategory() {
    _repository.watchCategory(_categoryId).listen(
      (category) {
        if (mounted) {
          state = state.copyWith(
            category: category,
            isLoading: false,
          );
        }
      },
      onError: (error) {
        if (mounted) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: error.toString(),
          );
        }
      },
    );
  }

  Future<void> updateBasicSettings({
    String? name,
    String? color,
    bool? private,
    bool? active,
    bool? favorite,
  }) async {
    final category = state.category;
    if (category == null) return;

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      final updated = category.copyWith(
        name: name ?? category.name,
        color: color ?? category.color,
        private: private ?? category.private,
        active: active ?? category.active,
        favorite: favorite ?? category.favorite,
      );

      await _repository.updateCategory(updated);
      state = state.copyWith(isSaving: false);
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> updateDefaultLanguage(String? languageCode) async {
    final category = state.category;
    if (category == null) return;

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      final updated = category.copyWith(
        defaultLanguageCode: languageCode,
      );

      await _repository.updateCategory(updated);
      state = state.copyWith(isSaving: false);
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> updateAllowedPromptIds(List<String> promptIds) async {
    final category = state.category;
    if (category == null) return;

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      final updated = category.copyWith(
        allowedPromptIds: promptIds.isEmpty ? null : promptIds,
      );

      await _repository.updateCategory(updated);
      state = state.copyWith(isSaving: false);
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> updateAutomaticPrompts(
    AiResponseType responseType,
    List<String> promptIds,
  ) async {
    final category = state.category;
    if (category == null) return;

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      final currentPrompts = category.automaticPrompts ?? {};
      final updatedPrompts =
          Map<AiResponseType, List<String>>.from(currentPrompts);

      if (promptIds.isEmpty) {
        updatedPrompts.remove(responseType);
      } else {
        updatedPrompts[responseType] = promptIds;
      }

      final updated = category.copyWith(
        automaticPrompts: updatedPrompts.isEmpty ? null : updatedPrompts,
      );

      await _repository.updateCategory(updated);
      state = state.copyWith(isSaving: false);
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> deleteCategory() async {
    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      await _repository.deleteCategory(_categoryId);
      state = state.copyWith(isSaving: false);
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString(),
      );
    }
  }
}
