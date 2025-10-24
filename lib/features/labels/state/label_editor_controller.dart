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
    this.description,
    this.isSaving = false,
    this.hasChanges = false,
    this.errorMessage,
  });

  factory LabelEditorState.initial({LabelDefinition? label}) {
    return LabelEditorState(
      name: label?.name ?? '',
      colorHex: (label?.color ?? labelColorPresets.first.hex).toUpperCase(),
      isPrivate: label?.private ?? false,
      description: label?.description,
    );
  }

  final String name;
  final String colorHex;
  final bool isPrivate;
  final String? description;
  final bool isSaving;
  final bool hasChanges;
  final String? errorMessage;

  LabelEditorState copyWith({
    String? name,
    String? colorHex,
    bool? isPrivate,
    String? description,
    bool? isSaving,
    bool? hasChanges,
    Object? errorMessage = _sentinel,
  }) {
    return LabelEditorState(
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      isPrivate: isPrivate ?? this.isPrivate,
      description: description ?? this.description,
      isSaving: isSaving ?? this.isSaving,
      hasChanges: hasChanges ?? this.hasChanges,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

final labelEditorControllerProvider = AutoDisposeNotifierProviderFamily<
    LabelEditorController, LabelEditorState, LabelDefinition?>(
  LabelEditorController.new,
);

class LabelEditorController
    extends AutoDisposeFamilyNotifier<LabelEditorState, LabelDefinition?> {
  static const int _nameMinLength = 1;

  late final LabelsRepository _repository;
  LabelDefinition? _initialLabel;

  @override
  LabelEditorState build(LabelDefinition? label) {
    _repository = ref.watch(labelsRepositoryProvider);
    _initialLabel = label;
    return LabelEditorState.initial(label: _initialLabel);
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
    final trimmed = value?.trim();
    final normalized = trimmed?.isEmpty ?? true ? null : trimmed;
    final updated = state.copyWith(
      description: normalized,
      errorMessage: null,
    );
    state = updated.copyWith(
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

  bool _hasChanges({
    String? name,
    String? description,
    String? colorHex,
    bool? isPrivate,
  }) {
    final effectiveName = (name ?? state.name).trim();
    final effectiveDescription = (description ?? state.description)?.trim();
    final effectiveColor = (colorHex ?? state.colorHex).toUpperCase();
    final effectivePrivate = isPrivate ?? state.isPrivate;

    if (_initialLabel == null) {
      return effectiveName.isNotEmpty ||
          (effectiveDescription != null && effectiveDescription.isNotEmpty) ||
          effectiveColor != labelColorPresets.first.hex.toUpperCase() ||
          effectivePrivate;
    }

    return effectiveName != _initialLabel!.name ||
        effectiveColor != _initialLabel!.color.toUpperCase() ||
        effectivePrivate != (_initialLabel!.private ?? false) ||
        (effectiveDescription ?? '') != (_initialLabel!.description ?? '');
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
        final result = await _repository.createLabel(
          name: trimmedName,
          color: state.colorHex,
          description: state.description,
          private: state.isPrivate,
        );
        _initialLabel = result;
        state = state.copyWith(isSaving: false, hasChanges: false);
        return result;
      } else {
        final updated = await _repository.updateLabel(
          _initialLabel!,
          name: trimmedName,
          color: state.colorHex,
          description: state.description,
          private: state.isPrivate,
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
