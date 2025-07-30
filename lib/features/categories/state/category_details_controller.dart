import 'dart:async';

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
      );
}

final AutoDisposeStateNotifierProviderFamily<CategoryDetailsController,
        CategoryDetailsState, String> categoryDetailsControllerProvider =
    StateNotifierProvider.autoDispose
        .family<CategoryDetailsController, CategoryDetailsState, String>(
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
  StreamSubscription<CategoryDefinition?>? _subscription;

  void _loadCategory() {
    _subscription = _repository.watchCategory(_categoryId).listen(
      (category) {
        if (mounted) {
          state = state.copyWith(
            category: category,
            isLoading: false,
          );
        }
      },
      onError: (Object error) {
        if (mounted) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to load category data.',
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
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

    // Validate name if provided
    if (name != null && name.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'Category name cannot be empty',
        isSaving: false,
      );
      return;
    }

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
        errorMessage: 'Failed to update category. Please try again.',
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
        errorMessage: 'Failed to update category. Please try again.',
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
        errorMessage: 'Failed to update category. Please try again.',
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
        errorMessage: 'Failed to update category. Please try again.',
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
        errorMessage: 'Failed to update category. Please try again.',
      );
    }
  }
}
