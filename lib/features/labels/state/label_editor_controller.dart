import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/labels/constants/label_color_presets.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/utils/color.dart';

const _sentinel = Object();

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
        ...(label?.applicableCategoryIds ?? const <String>[])
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

class LabelEditorArgs {
  const LabelEditorArgs({this.label, this.initialName});

  final LabelDefinition? label;
  final String? initialName;
}

final labelEditorControllerProvider = AutoDisposeNotifierProviderFamily<
    LabelEditorController, LabelEditorState, LabelEditorArgs>(
  LabelEditorController.new,
);

class LabelEditorController
    extends AutoDisposeFamilyNotifier<LabelEditorState, LabelEditorArgs> {
  static const int _nameMinLength = 1;

  late final LabelsRepository _repository;
  LabelDefinition? _initialLabel;
  String? _initialName;

  @override
  LabelEditorState build(LabelEditorArgs args) {
    _repository = ref.watch(labelsRepositoryProvider);
    _initialLabel = args.label;
    _initialName = args.initialName?.trim().isEmpty ?? true
        ? null
        : args.initialName!.trim();
    return LabelEditorState.initial(
      label: _initialLabel,
      initialName: _initialName,
    );
  }

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
    final updated =
        state.copyWith(isPrivate: isPrivateValue, errorMessage: null);
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
      ...(_initialLabel!.applicableCategoryIds ?? const <String>[])
    };
    return effectiveName != _initialLabel!.name ||
        effectiveColor != _initialLabel!.color.toUpperCase() ||
        effectivePrivate != (_initialLabel!.private ?? false) ||
        (effectiveDescription ?? '') != (_initialLabel!.description ?? '') ||
        !setEquals(effectiveCategories, initialCats);
  }

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
