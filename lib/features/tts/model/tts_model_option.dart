import 'package:flutter/foundation.dart';

/// A selectable on-device TTS model.
///
/// Today there is a single shipped model — Supertonic 3, the ~99M-parameter
/// ONNX model published at [huggingFaceRepoId]. The catalog is a list rather
/// than a lone constant so future variants (a higher-fidelity model, a v4)
/// can be offered from the same selector without reshaping callers.
@immutable
class TtsModelOption {
  const TtsModelOption({
    required this.id,
    required this.displayName,
    required this.huggingFaceRepoId,
    this.recommended = false,
  });

  /// Stable id persisted in settings and used to resolve the active model.
  final String id;

  /// Name shown in the selector. Intentionally not localized — these are
  /// product proper nouns ("Supertonic 3") that stay constant across locales,
  /// matching how AI model names are stored elsewhere in the app.
  final String displayName;

  /// Hugging Face repository the ONNX assets are fetched from on first use.
  final String huggingFaceRepoId;

  /// Marks the default / fastest recommended model.
  final bool recommended;

  @override
  bool operator ==(Object other) =>
      other is TtsModelOption &&
      other.id == id &&
      other.displayName == displayName &&
      other.huggingFaceRepoId == huggingFaceRepoId &&
      other.recommended == recommended;

  @override
  int get hashCode =>
      Object.hash(id, displayName, huggingFaceRepoId, recommended);

  @override
  String toString() => 'TtsModelOption($id, $huggingFaceRepoId)';
}

/// Hugging Face repo for the shipped Supertonic 3 ONNX assets.
const String kSupertonic3RepoId = 'Supertone/supertonic-3';

/// The selectable TTS models.
const List<TtsModelOption> kTtsModels = <TtsModelOption>[
  TtsModelOption(
    id: 'supertonic-3',
    displayName: 'Supertonic 3',
    huggingFaceRepoId: kSupertonic3RepoId,
    recommended: true,
  ),
];

/// Default model id — the fastest recommended local model.
const String kDefaultTtsModelId = 'supertonic-3';

/// Resolves [modelId] to a catalog model, falling back to the default model
/// when the id is unknown or `null`. Never returns `null` so callers always
/// have a usable model.
TtsModelOption ttsModelByIdOrDefault(String? modelId) {
  for (final model in kTtsModels) {
    if (model.id == modelId) return model;
  }
  return kTtsModels.firstWhere((m) => m.id == kDefaultTtsModelId);
}
