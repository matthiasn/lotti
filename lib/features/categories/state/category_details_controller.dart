// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';

part 'category_details_controller.freezed.dart';

/// View state for the category details/edit form.
///
/// [hasChanges] gates the Save button and reflects whether the in-flight edits
/// differ from the loaded category. [isLoading] is true until the first value
/// arrives from the watch stream; [isSaving] guards a write in flight.
/// [errorMessage] holds a load/save/validation failure for the UI to surface.
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

/// Per-category-id details controller, family-keyed by category id and
/// auto-disposed when the details page is no longer mounted.
final categoryDetailsControllerProvider = NotifierProvider.autoDispose
    .family<CategoryDetailsController, CategoryDetailsState, String>(
      CategoryDetailsController.new,
    );

/// Drives the category details/edit form.
///
/// Holds two snapshots: `_originalCategory` (the last loaded/saved baseline)
/// and `_pendingCategory` (the working copy with the user's edits). Field
/// edits only mutate `_pendingCategory` and recompute [CategoryDetailsState]
/// `hasChanges`; nothing is persisted until [saveChanges].
///
/// The controller subscribes to [CategoryRepository.watchCategory], so it also
/// receives background updates (e.g. correction examples captured by the AI
/// pipeline while the user has the form open). While the user has unsaved
/// edits (`hasChanges`), the displayed category stays the pending copy so a
/// background update never clobbers in-progress input; [saveChanges] then
/// reconciles the two so neither side's changes are lost.
class CategoryDetailsController extends Notifier<CategoryDetailsState> {
  CategoryDetailsController(this._categoryId);

  final String _categoryId;
  late final CategoryRepository _repository;
  StreamSubscription<CategoryDefinition?>? _subscription;

  CategoryDefinition? _originalCategory;
  CategoryDefinition? _pendingCategory;

  @override
  CategoryDetailsState build() {
    _repository = ref.watch(categoryRepositoryProvider);
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });
    _init();
    return CategoryDetailsState.initial();
  }

  void _init() {
    _subscription = _repository
        .watchCategory(_categoryId)
        .listen(
          (category) {
            if (_originalCategory == null && category != null) {
              _originalCategory = category;
              _pendingCategory = category;
            }

            if (ref.mounted) {
              state = state.copyWith(
                category: state.hasChanges ? _pendingCategory : category,
                isLoading: false,
                hasChanges: _hasChanges(_pendingCategory),
                errorMessage: null,
              );
            }
          },
          onError: (Object error) {
            if (ref.mounted) {
              state = state.copyWith(
                isLoading: false,
                errorMessage: 'Failed to load category data.',
              );
            }
          },
        );
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
        _pendingCategory!.isAvailableForDayPlan !=
            _originalCategory!.isAvailableForDayPlan ||
        _pendingCategory!.icon != _originalCategory!.icon ||
        _pendingCategory!.defaultLanguageCode !=
            _originalCategory!.defaultLanguageCode ||
        _pendingCategory!.defaultProfileId !=
            _originalCategory!.defaultProfileId ||
        _pendingCategory!.defaultTemplateId !=
            _originalCategory!.defaultTemplateId ||
        _hasListChanges(
          _pendingCategory!.speechDictionary,
          _originalCategory!.speechDictionary,
        ) ||
        _hasCorrectionExamplesChanges(
          _pendingCategory!.correctionExamples,
          _originalCategory!.correctionExamples,
        );
  }

  bool _hasCorrectionExamplesChanges(
    List<ChecklistCorrectionExample>? current,
    List<ChecklistCorrectionExample>? original,
  ) {
    // Uses freezed-generated equality which considers all fields
    return !const DeepCollectionEquality().equals(current, original);
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

  /// Applies the supplied scalar/flag edits to the pending category and
  /// recomputes [CategoryDetailsState] `hasChanges`. Every argument is
  /// optional; `null` means "leave unchanged" (the current pending value is
  /// retained), so there is no way to clear a value to `null` through this
  /// method. Does not persist — call [saveChanges] for that.
  void updateFormField({
    String? name,
    String? color,
    bool? private,
    bool? active,
    bool? favorite,
    bool? isAvailableForDayPlan,
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
      isAvailableForDayPlan:
          isAvailableForDayPlan ?? _pendingCategory!.isAvailableForDayPlan,
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

  /// Updates the default inference profile for new tasks in this category.
  /// Pass `null` to clear the default.
  void setDefaultProfileId(String? profileId) {
    _updatePendingCategory(
      (c) => c.copyWith(defaultProfileId: profileId),
    );
  }

  /// Updates the default agent template for new tasks in this category.
  /// Pass `null` to clear the default.
  void setDefaultTemplateId(String? templateId) {
    _updatePendingCategory(
      (c) => c.copyWith(defaultTemplateId: templateId),
    );
  }

  /// Applies [updater] to `_pendingCategory` and refreshes state.
  void _updatePendingCategory(
    CategoryDefinition Function(CategoryDefinition) updater,
  ) {
    if (_pendingCategory == null) return;

    _pendingCategory = updater(_pendingCategory!);
    state = state.copyWith(
      category: _pendingCategory,
      hasChanges: _hasChanges(_pendingCategory),
    );
  }

  /// Persists the pending edits, reconciling correction examples against the
  /// latest DB copy to avoid data loss in either direction.
  ///
  /// No-op when there is nothing to save. Rejects an empty name with an
  /// `errorMessage` instead of writing.
  ///
  /// Correction examples are special: the AI pipeline can append new examples
  /// to the same category in the background while the form is open. So before
  /// writing, this re-reads the latest examples from the DB and starts from
  /// those (keeping background additions), then removes only the examples the
  /// user explicitly deleted in the UI (the set difference of original minus
  /// pending). All other fields are taken verbatim from the pending copy. On
  /// success the baseline (`_originalCategory`) is advanced and `hasChanges`
  /// clears; on failure an `errorMessage` is set and the edits remain pending.
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
      // Merge correction examples: preserve background additions while respecting
      // user's explicit deletions. This prevents data loss in both directions:
      // - Background captures are not lost when user saves other changes
      // - User's deletions are not overwritten by background captures
      final latestCategory = await _repository.getCategoryById(_categoryId);
      if (latestCategory != null && _originalCategory != null) {
        final originalExamples = _originalCategory!.correctionExamples ?? [];
        final pendingExamples = _pendingCategory!.correctionExamples ?? [];
        final latestExamples = latestCategory.correctionExamples ?? [];

        // Identify examples deleted by the user in the UI
        final originalSet = originalExamples.toSet();
        final pendingSet = pendingExamples.toSet();
        final deletedByUser = originalSet.difference(pendingSet);

        // Start with the latest examples from DB (includes background additions)
        // and remove the ones the user explicitly deleted
        final finalExamples = latestExamples
            .where((ex) => !deletedByUser.contains(ex))
            .toList();

        _pendingCategory = _pendingCategory!.copyWith(
          correctionExamples: finalExamples.isEmpty ? null : finalExamples,
        );
      }

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

  /// Replaces the pending speech-dictionary terms (empty list stored as
  /// `null`). Not persisted until [saveChanges].
  void updateSpeechDictionary(List<String> terms) {
    _updatePendingCategory(
      (c) => c.copyWith(speechDictionary: terms.isEmpty ? null : terms),
    );
  }

  /// Deletes a correction example at the given index from the pending category.
  ///
  /// Uses index-based deletion to correctly handle duplicates - only the
  /// specific item the user swiped is removed, not all matching examples.
  ///
  /// Note: Deletions update `_pendingCategory` but are NOT auto-persisted.
  /// The user must tap the Save button to persist changes. This matches
  /// the speech dictionary and other category settings behavior.
  void deleteCorrectionExampleAt(int index) {
    if (_pendingCategory == null) return;

    final currentExamples = _pendingCategory!.correctionExamples ?? [];
    if (index < 0 || index >= currentExamples.length) return;

    final updatedExamples = [...currentExamples]..removeAt(index);

    _updatePendingCategory(
      (c) => c.copyWith(
        correctionExamples: updatedExamples.isEmpty ? null : updatedExamples,
      ),
    );
  }

  /// Soft-deletes this category via the repository (see
  /// [CategoryRepository.deleteCategory]). Sets an `errorMessage` on failure;
  /// the caller is responsible for navigating away on success.
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
