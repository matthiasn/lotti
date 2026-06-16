// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/constants/label_color_presets.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/utils/color.dart';

const _sentinel = Object();

/// Immutable form state for the label create/edit flow.
///
/// Mirrors the editable fields of a [LabelDefinition] plus transient UI flags:
/// [isSaving] gates the save button/spinner, [hasChanges] tracks dirtiness
/// against the initial baseline (drives Save enablement), and [errorMessage]
/// surfaces validation/persistence failures. [colorHex] is kept upper-cased so
/// dirty comparisons against the stored definition are case-stable.
class LabelEditorState {
  const LabelEditorState({
    required this.name,
    required this.colorHex,
    required this.isPrivate,
    required this.selectedCategoryIds,
    this.description,
    this.isSaving = false,
    this.hasChanges = false,
    this.errorMessage,
  });

  /// Seeds the form from an existing [label] (edit) or a blank create form.
  ///
  /// In create mode [initialName] pre-fills the name field (e.g. typed in the
  /// picker's search box) and the color defaults to the first preset. Category
  /// IDs are copied into a mutable set so the editor can toggle them.
  factory LabelEditorState.initial({
    LabelDefinition? label,
    String? initialName,
  }) {
    return LabelEditorState(
      name: label?.name ?? initialName ?? '',
      colorHex: (label?.color ?? labelColorPresets.first.hex).toUpperCase(),
      isPrivate: label?.private ?? false,
      description: label?.description,
      selectedCategoryIds: {
        ...(label?.applicableCategoryIds ?? const <String>[]),
      },
    );
  }

  final String name;
  final String colorHex;
  final bool isPrivate;
  final String? description;
  final Set<String> selectedCategoryIds;
  final bool isSaving;
  final bool hasChanges;
  final String? errorMessage;

  LabelEditorState copyWith({
    String? name,
    String? colorHex,
    bool? isPrivate,
    Object? description = _sentinel,
    Set<String>? selectedCategoryIds,
    bool? isSaving,
    bool? hasChanges,
    Object? errorMessage = _sentinel,
  }) {
    return LabelEditorState(
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      isPrivate: isPrivate ?? this.isPrivate,
      description: identical(description, _sentinel)
          ? this.description
          : description as String?,
      selectedCategoryIds: selectedCategoryIds ?? this.selectedCategoryIds,
      isSaving: isSaving ?? this.isSaving,
      hasChanges: hasChanges ?? this.hasChanges,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

/// Identity/seed for a [LabelEditorController] instance.
///
/// Pass [label] for edit mode or [initialName] for a pre-filled create form.
/// This object is also the family key, so distinct args yield distinct
/// controllers; equal args reuse the same one.
class LabelEditorArgs {
  const LabelEditorArgs({this.label, this.initialName});

  final LabelDefinition? label;
  final String? initialName;
}

final labelEditorControllerProvider = NotifierProvider.autoDispose
    .family<LabelEditorController, LabelEditorState, LabelEditorArgs>(
      LabelEditorController.new,
    );

/// Drives the label create/edit form: validation, dirty tracking, and the
/// duplicate-name-checked save against [LabelsRepository].
///
/// Field setters update [LabelEditorState] and recompute [LabelEditorState.hasChanges]
/// against the initial baseline. [save] enforces a non-empty name and rejects a
/// case-insensitive duplicate of any other label before creating or updating.
/// On a successful create the controller adopts the persisted label as its new
/// baseline so subsequent edits diff correctly.
class LabelEditorController extends Notifier<LabelEditorState> {
  LabelEditorController(this.params);

  static const int _nameMinLength = 1;

  final LabelEditorArgs params;
  late LabelsRepository _repository;
  LabelDefinition? _initialLabel;
  String? _initialName;

  @override
  LabelEditorState build() {
    _repository = ref.read(labelsRepositoryProvider);
    _initialLabel = params.label;
    _initialName = params.initialName?.trim().isEmpty ?? true
        ? null
        : params.initialName!.trim();
    return LabelEditorState.initial(
      label: params.label,
      initialName: _initialName,
    );
  }

  /// The current [LabelEditorState.colorHex] parsed into a [Color], falling
  /// back to blue when the hex is unparseable.
  Color get selectedColor =>
      colorFromCssHex(state.colorHex, substitute: Colors.blue);

  void setName(String value) {
    final trimmed = value.trim();
    final updated = state.copyWith(
      name: value,
      errorMessage: null,
    );
    state = updated.copyWith(
      hasChanges: _hasChanges(
        name: trimmed,
        description: updated.description,
        colorHex: updated.colorHex,
        isPrivate: updated.isPrivate,
      ),
    );
  }

  void setDescription(String? value) {
    // Normalize description eagerly for state (tests expect trimmed value),
    // but the UI text field is not re-seeded on rebuilds, so cursor won't jump.
    final trimmed = _sanitize(value);
    final normalized = trimmed.isEmpty ? null : trimmed;
    state = state.copyWith(
      description: normalized,
      errorMessage: null,
      hasChanges: _hasChanges(description: normalized),
    );
  }

  void setColor(Color color) {
    final hex = colorToCssHex(color).toUpperCase();
    final updated = state.copyWith(colorHex: hex, errorMessage: null);
    state = updated.copyWith(
      hasChanges: _hasChanges(colorHex: hex),
    );
  }

  void setPrivate({required bool isPrivateValue}) {
    final updated = state.copyWith(
      isPrivate: isPrivateValue,
      errorMessage: null,
    );
    state = updated.copyWith(
      hasChanges: _hasChanges(isPrivate: isPrivateValue),
    );
  }

  void addCategoryId(String id) {
    if (id.isEmpty) return;
    final next = {...state.selectedCategoryIds}..add(id);
    state = state.copyWith(
      selectedCategoryIds: next,
      hasChanges: _hasChanges(selectedCategoryIds: next),
      errorMessage: null,
    );
  }

  void removeCategoryId(String id) {
    final next = {...state.selectedCategoryIds}..remove(id);
    state = state.copyWith(
      selectedCategoryIds: next,
      hasChanges: _hasChanges(selectedCategoryIds: next),
      errorMessage: null,
    );
  }

  /// Replaces the whole applicable-category set. Used by the multi-picker,
  /// which is seeded with the current set and returns the full edited set —
  /// so additions AND removals are applied in one shot (a per-id add loop
  /// would silently keep categories the user unchecked).
  void setCategoryIds(Set<String> ids) {
    final next = {...ids};
    state = state.copyWith(
      selectedCategoryIds: next,
      hasChanges: _hasChanges(selectedCategoryIds: next),
      errorMessage: null,
    );
  }

  bool _hasChanges({
    String? name,
    String? description,
    String? colorHex,
    bool? isPrivate,
    Set<String>? selectedCategoryIds,
  }) {
    final effectiveName = (name ?? state.name).trim();
    final effectiveDescription = (description ?? state.description)?.trim();
    final effectiveColor = (colorHex ?? state.colorHex).toUpperCase();
    final effectivePrivate = isPrivate ?? state.isPrivate;
    final effectiveCategories =
        selectedCategoryIds ?? state.selectedCategoryIds;

    if (_initialLabel == null) {
      final baselineName = _initialName ?? '';
      return effectiveName != baselineName ||
          (effectiveDescription ?? '').isNotEmpty ||
          effectiveColor != labelColorPresets.first.hex.toUpperCase() ||
          effectivePrivate ||
          effectiveCategories.isNotEmpty;
    }

    final initialCats = {
      ...(_initialLabel!.applicableCategoryIds ?? const <String>[]),
    };
    return effectiveName != _initialLabel!.name ||
        effectiveColor != _initialLabel!.color.toUpperCase() ||
        effectivePrivate != (_initialLabel!.private ?? false) ||
        (effectiveDescription ?? '') != (_initialLabel!.description ?? '') ||
        !setEquals(effectiveCategories, initialCats);
  }

  /// Validates and persists the form, returning the saved [LabelDefinition] or
  /// `null` when validation/persistence failed (with [LabelEditorState.errorMessage] set).
  ///
  /// Rejects an empty name and a case-insensitive duplicate of any other label.
  /// Empty descriptions become `null` on create and `''` on update (the
  /// repository treats `''` as "clear" and `null` as "keep"). The selected
  /// category set is passed through wholesale: empty clears the scope, making
  /// the label global.
  Future<LabelDefinition?> save() async {
    final trimmedName = state.name.trim();

    if (trimmedName.length < _nameMinLength) {
      state = state.copyWith(
        errorMessage: 'Label name must not be empty.',
      );
      return null;
    }

    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      final labels = await _repository.getAllLabels();
      final hasDuplicate = labels.any(
        (label) =>
            label.id != _initialLabel?.id &&
            label.name.toLowerCase() == trimmedName.toLowerCase(),
      );

      if (hasDuplicate) {
        state = state.copyWith(
          isSaving: false,
          errorMessage: 'A label with this name already exists.',
        );
        return null;
      }

      if (_initialLabel == null) {
        final descTrim = _sanitize(state.description);
        final normalizedDesc = descTrim.isEmpty ? null : descTrim;
        final result = await _repository.createLabel(
          name: trimmedName,
          color: state.colorHex,
          description: normalizedDesc,
          private: state.isPrivate,
          applicableCategoryIds: state.selectedCategoryIds.toList(),
        );
        _initialLabel = result;
        _initialName = result.name;
        state = state.copyWith(isSaving: false, hasChanges: false);
        return result;
      } else {
        final descTrim = _sanitize(state.description);
        // For updates, pass empty string to clear description; repository treats null as "keep".
        final normalizedDesc = descTrim.isEmpty ? '' : descTrim;
        final updated = await _repository.updateLabel(
          _initialLabel!,
          name: trimmedName,
          color: state.colorHex,
          description: normalizedDesc,
          private: state.isPrivate,
          // Category update behavior:
          //  - Non-empty list replaces existing applicable categories.
          //  - Empty list clears categories (label becomes global).
          applicableCategoryIds: state.selectedCategoryIds.toList(),
        );
        _initialLabel = updated;
        state = state.copyWith(isSaving: false, hasChanges: false);
        return updated;
      }
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save label. Please try again.',
      );
      return null;
    }
  }

  /// Discards in-progress edits, restoring the form to the last saved baseline
  /// (the original label, or a blank create form if none exists yet).
  void resetToInitial() {
    state = LabelEditorState.initial(label: _initialLabel);
  }
}

String _sanitize(String? value) {
  var text = value ?? '';
  // Remove common invisible/stray characters that survive a normal trim
  // - NBSP (\u00A0), ZWSP (\u200B), BOM (\uFEFF)
  text = text.replaceAll(RegExp(r'[\u00A0\u200B\uFEFF]'), '');
  // Trim leading/trailing unicode whitespace
  text = text.trim();
  return text;
}
