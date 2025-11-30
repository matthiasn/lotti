import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';

part 'category_details_controller.freezed.dart';

@freezed
abstract class CategoryDetailsState with _$CategoryDetailsState {
  const factory CategoryDetailsState({
    required CategoryDefinition? category,
    required bool isLoading,
    required bool isSaving,
    required bool hasChanges,
    String? errorMessage,
  }) = _CategoryDetailsState;

  factory CategoryDetailsState.initial() => const CategoryDetailsState(
        category: null,
        isLoading: true,
        isSaving: false,
        hasChanges: false,
      );
}

final AutoDisposeNotifierProviderFamily<CategoryDetailsController,
        CategoryDetailsState, String> categoryDetailsControllerProvider =
    AutoDisposeNotifierProvider.family<CategoryDetailsController,
        CategoryDetailsState, String>(
  CategoryDetailsController.new,
);

class CategoryDetailsController
    extends AutoDisposeFamilyNotifier<CategoryDetailsState, String> {
  CategoryDetailsController();

  late final CategoryRepository _repository;
  late String _categoryId;
  StreamSubscription<CategoryDefinition?>? _subscription;

  CategoryDefinition? _originalCategory;
  CategoryDefinition? _pendingCategory;

  @override
  CategoryDetailsState build(String categoryId) {
    _repository = ref.watch(categoryRepositoryProvider);
    _categoryId = categoryId;

    _originalCategory = null;
    _pendingCategory = null;

    _subscription?.cancel();
    _subscription = _repository.watchCategory(categoryId).listen(
      (category) {
        if (_originalCategory == null && category != null) {
          _originalCategory = category;
          _pendingCategory = category;
        }

        state = state.copyWith(
          category: state.hasChanges ? _pendingCategory : category,
          isLoading: false,
          hasChanges: _hasChanges(_pendingCategory),
          errorMessage: null,
        );
      },
      onError: (Object error) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load category data.',
        );
      },
    );

    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });

    return CategoryDetailsState.initial();
  }

  bool _hasChanges(CategoryDefinition? current) {
    if (current == null ||
        _originalCategory == null ||
        _pendingCategory == null) {
      return false;
    }

    // Check if any fields have changed from the original
    return _pendingCategory!.name != _originalCategory!.name ||
        _pendingCategory!.color != _originalCategory!.color ||
        _pendingCategory!.private != _originalCategory!.private ||
        _pendingCategory!.active != _originalCategory!.active ||
        _pendingCategory!.favorite != _originalCategory!.favorite ||
        _pendingCategory!.icon != _originalCategory!.icon ||
        _pendingCategory!.defaultLanguageCode !=
            _originalCategory!.defaultLanguageCode ||
        _hasListChanges(_pendingCategory!.allowedPromptIds,
            _originalCategory!.allowedPromptIds) ||
        _hasListChanges(_pendingCategory!.speechDictionary,
            _originalCategory!.speechDictionary) ||
        _hasCorrectionExamplesChanges(_pendingCategory!.correctionExamples,
            _originalCategory!.correctionExamples) ||
        _hasMapChanges(_pendingCategory!.automaticPrompts,
            _originalCategory!.automaticPrompts);
  }

  bool _hasCorrectionExamplesChanges(
    List<ChecklistCorrectionExample>? current,
    List<ChecklistCorrectionExample>? original,
  ) {
    if (current == null && original == null) return false;
    if (current == null || original == null) return true;
    if (current.length != original.length) return true;

    // Compare each example (order matters for this comparison)
    for (var i = 0; i < current.length; i++) {
      if (current[i].before != original[i].before ||
          current[i].after != original[i].after) {
        return true;
      }
    }
    return false;
  }

  bool _hasListChanges(List<String>? current, List<String>? original) {
    if (current == null && original == null) return false;
    if (current == null || original == null) return true;
    if (current.length != original.length) return true;

    final currentSet = current.toSet();
    final originalSet = original.toSet();
    return !currentSet.containsAll(originalSet) ||
        !originalSet.containsAll(currentSet);
  }

  bool _hasMapChanges(
    Map<AiResponseType, List<String>>? current,
    Map<AiResponseType, List<String>>? original,
  ) {
    if (current == null && original == null) return false;
    if (current == null || original == null) return true;
    if (current.length != original.length) return true;

    for (final key in current.keys) {
      if (!original.containsKey(key)) return true;
      if (_hasListChanges(current[key], original[key])) return true;
    }

    return false;
  }

  void updateFormField({
    String? name,
    String? color,
    bool? private,
    bool? active,
    bool? favorite,
    String? defaultLanguageCode,
    CategoryIcon? icon,
  }) {
    if (_pendingCategory == null) return;

    // Update pending category with all new values
    _pendingCategory = _pendingCategory!.copyWith(
      name: name ?? _pendingCategory!.name,
      color: color ?? _pendingCategory!.color,
      private: private ?? _pendingCategory!.private,
      active: active ?? _pendingCategory!.active,
      favorite: favorite ?? _pendingCategory!.favorite,
      defaultLanguageCode:
          defaultLanguageCode ?? _pendingCategory!.defaultLanguageCode,
      icon: icon ?? _pendingCategory!.icon,
    );

    // Update the displayed category to reflect pending changes
    state = state.copyWith(
      category: _pendingCategory,
      hasChanges: _hasChanges(_pendingCategory),
    );
  }

  Future<void> saveChanges() async {
    if (_pendingCategory == null || !state.hasChanges) return;

    // Validate name
    if (_pendingCategory!.name.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'Category name cannot be empty',
        isSaving: false,
      );
      return;
    }

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      await _repository.updateCategory(_pendingCategory!);
      // Reset the original category after successful save
      _originalCategory = _pendingCategory;
      state = state.copyWith(isSaving: false, hasChanges: false);
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to update category. Please try again.',
      );
    }
  }

  void updateBasicSettings({
    String? name,
    String? color,
    bool? private,
    bool? active,
    bool? favorite,
  }) {
    // This method is kept for backward compatibility but now just updates form fields
    updateFormField(
      name: name,
      color: color,
      private: private,
      active: active,
      favorite: favorite,
    );
  }

  void updateDefaultLanguage(String? languageCode) {
    // This method is kept for backward compatibility but now just updates form fields
    updateFormField(defaultLanguageCode: languageCode);
  }

  void updateAllowedPromptIds(List<String> promptIds) {
    if (_pendingCategory == null) return;

    _pendingCategory = _pendingCategory!.copyWith(
      allowedPromptIds: promptIds.isEmpty ? null : promptIds,
    );

    state = state.copyWith(
      category: _pendingCategory,
      hasChanges: _hasChanges(_pendingCategory),
    );
  }

  void updateAutomaticPrompts(
    AiResponseType responseType,
    List<String> promptIds,
  ) {
    if (_pendingCategory == null) return;

    final currentPrompts = _pendingCategory!.automaticPrompts ?? {};
    final updatedPrompts =
        Map<AiResponseType, List<String>>.from(currentPrompts);

    if (promptIds.isEmpty) {
      updatedPrompts.remove(responseType);
    } else {
      updatedPrompts[responseType] = promptIds;
    }

    _pendingCategory = _pendingCategory!.copyWith(
      automaticPrompts: updatedPrompts.isEmpty ? null : updatedPrompts,
    );

    state = state.copyWith(
      category: _pendingCategory,
      hasChanges: _hasChanges(_pendingCategory),
    );
  }

  void updateSpeechDictionary(List<String> terms) {
    if (_pendingCategory == null) return;

    _pendingCategory = _pendingCategory!.copyWith(
      speechDictionary: terms.isEmpty ? null : terms,
    );

    state = state.copyWith(
      category: _pendingCategory,
      hasChanges: _hasChanges(_pendingCategory),
    );
  }

  /// Deletes a correction example from the pending category.
  ///
  /// Note: Deletions update `_pendingCategory` but are NOT auto-persisted.
  /// The user must tap the Save button to persist changes. This matches
  /// the speech dictionary and other category settings behavior.
  void deleteCorrectionExample(ChecklistCorrectionExample example) {
    if (_pendingCategory == null) return;

    final currentExamples = _pendingCategory!.correctionExamples ?? [];
    final updatedExamples = currentExamples
        .where((e) => e.before != example.before || e.after != example.after)
        .toList();

    _pendingCategory = _pendingCategory!.copyWith(
      correctionExamples: updatedExamples.isEmpty ? null : updatedExamples,
    );

    state = state.copyWith(
      category: _pendingCategory,
      hasChanges: _hasChanges(_pendingCategory),
    );
  }

  Future<void> deleteCategory() async {
    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      await _repository.deleteCategory(_categoryId);
      state = state.copyWith(isSaving: false);
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to delete category. Please try again.',
      );
    }
  }
}
