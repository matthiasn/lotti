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

  // Track the original category to detect changes
  CategoryDefinition? _originalCategory;

  // Track form field values
  String? _currentName;
  String? _currentColor;

  // Track current values that can be changed without saving
  CategoryDefinition? _pendingCategory;

  void _loadCategory() {
    _subscription = _repository.watchCategory(_categoryId).listen(
      (category) {
        if (mounted) {
          // Store original category when first loaded
          if (_originalCategory == null && category != null) {
            _originalCategory = category;
            _pendingCategory = category;
            _currentName = category.name;
            _currentColor = category.color;
          }
          state = state.copyWith(
            category: category,
            isLoading: false,
            hasChanges: _hasChanges(category),
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

  bool _hasChanges(CategoryDefinition? current) {
    if (current == null ||
        _originalCategory == null ||
        _pendingCategory == null) return false;

    // Check if any fields have changed from the original
    return _currentName != _originalCategory!.name ||
        _currentColor != _originalCategory!.color ||
        _pendingCategory!.private != _originalCategory!.private ||
        _pendingCategory!.active != _originalCategory!.active ||
        _pendingCategory!.favorite != _originalCategory!.favorite ||
        _pendingCategory!.defaultLanguageCode !=
            _originalCategory!.defaultLanguageCode ||
        _hasListChanges(_pendingCategory!.allowedPromptIds,
            _originalCategory!.allowedPromptIds) ||
        _hasMapChanges(_pendingCategory!.automaticPrompts,
            _originalCategory!.automaticPrompts);
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
  }) {
    if (name != null) _currentName = name;
    if (color != null) _currentColor = color;

    final current = state.category;
    if (current != null && _pendingCategory != null) {
      // Update pending category with new values
      _pendingCategory = _pendingCategory!.copyWith(
        private: private ?? _pendingCategory!.private,
        active: active ?? _pendingCategory!.active,
        favorite: favorite ?? _pendingCategory!.favorite,
        defaultLanguageCode:
            defaultLanguageCode ?? _pendingCategory!.defaultLanguageCode,
      );

      // Also update the displayed category so UI reflects changes
      final displayCategory = current.copyWith(
        name: _currentName ?? current.name,
        color: _currentColor ?? current.color,
        private: private ?? current.private,
        active: active ?? current.active,
        favorite: favorite ?? current.favorite,
        defaultLanguageCode: defaultLanguageCode ?? current.defaultLanguageCode,
      );

      state = state.copyWith(
        category: displayCategory,
        hasChanges: _hasChanges(current),
      );
    }
  }

  Future<void> saveChanges() async {
    if (_pendingCategory == null || !state.hasChanges) return;

    // Validate name
    if (_currentName == null || _currentName!.trim().isEmpty) {
      state = state.copyWith(
        errorMessage: 'Category name cannot be empty',
        isSaving: false,
      );
      return;
    }

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      final updated = _pendingCategory!.copyWith(
        name: _currentName!,
        color: _currentColor,
      );

      await _repository.updateCategory(updated);
      // Reset the original category and form values after successful save
      _originalCategory = updated;
      _pendingCategory = updated;
      _currentName = updated.name;
      _currentColor = updated.color;
      state = state.copyWith(isSaving: false, hasChanges: false);
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to update category. Please try again.',
      );
    }
  }

  Future<void> updateBasicSettings({
    String? name,
    String? color,
    bool? private,
    bool? active,
    bool? favorite,
  }) async {
    // This method is kept for backward compatibility but now just updates form fields
    updateFormField(
      name: name,
      color: color,
      private: private,
      active: active,
      favorite: favorite,
    );
  }

  Future<void> updateDefaultLanguage(String? languageCode) async {
    // This method is kept for backward compatibility but now just updates form fields
    updateFormField(defaultLanguageCode: languageCode);
  }

  void updateAllowedPromptIds(List<String> promptIds) {
    final current = state.category;
    if (current != null && _pendingCategory != null) {
      _pendingCategory = _pendingCategory!.copyWith(
        allowedPromptIds: promptIds.isEmpty ? null : promptIds,
      );

      // Update displayed category
      final displayCategory = current.copyWith(
        allowedPromptIds: promptIds.isEmpty ? null : promptIds,
      );

      state = state.copyWith(
        category: displayCategory,
        hasChanges: _hasChanges(current),
      );
    }
  }

  void updateAutomaticPrompts(
    AiResponseType responseType,
    List<String> promptIds,
  ) {
    final current = state.category;
    if (current != null && _pendingCategory != null) {
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

      // Update displayed category
      final displayCategory = current.copyWith(
        automaticPrompts: updatedPrompts.isEmpty ? null : updatedPrompts,
      );

      state = state.copyWith(
        category: displayCategory,
        hasChanges: _hasChanges(current),
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
