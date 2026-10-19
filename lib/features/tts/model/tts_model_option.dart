import 'package:flutter/foundation.dart';

/// One file of a TTS model as published upstream, with its size so the app
/// can tell the user what the download costs before starting it.
@immutable
class TtsModelFile {
  const TtsModelFile(this.name, this.bytes);

  /// File name inside the repository's `onnx/` directory.
  final String name;

  /// Size in bytes at the model's pinned revision.
  final int bytes;

  @override
  bool operator ==(Object other) =>
      other is TtsModelFile && other.name == name && other.bytes == bytes;

  @override
  int get hashCode => Object.hash(name, bytes);
}

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
    required this.revision,
    required this.files,
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

  /// Commit the files are fetched at. Pinned, so [files] — and the size the
  /// download prompt shows — are exactly what arrives, whatever the
  /// repository's default branch does later.
  final String revision;

  /// The files that make up the model, with their sizes at [revision].
  final List<TtsModelFile> files;

  /// What downloading the whole model costs, in bytes.
  int get totalBytes => files.fold(0, (sum, file) => sum + file.bytes);

  /// Marks the default / fastest recommended model.
  final bool recommended;

  @override
  bool operator ==(Object other) =>
      other is TtsModelOption &&
      other.id == id &&
      other.displayName == displayName &&
      other.huggingFaceRepoId == huggingFaceRepoId &&
      other.revision == revision &&
      listEquals(other.files, files) &&
      other.recommended == recommended;

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    huggingFaceRepoId,
    revision,
    Object.hashAll(files),
    recommended,
  );

  @override
  String toString() => 'TtsModelOption($id, $huggingFaceRepoId)';
}

/// Hugging Face repo for the shipped Supertonic 3 ONNX assets.
const String kSupertonic3RepoId = 'Supertone/supertonic-3';

/// The Supertonic 3 commit the app downloads. Moving it means re-measuring
/// [kSupertonic3Files] at the new commit.
const String kSupertonic3Revision = '3cadd1ee6394adea1bd021217a0e650ede09a323';

/// The Supertonic 3 files in the repository's `onnx/` directory, with their
/// sizes at [kSupertonic3Revision] — the two JSON configs live alongside the
/// ONNX graphs upstream.
const List<TtsModelFile> kSupertonic3Files = <TtsModelFile>[
  TtsModelFile('duration_predictor.onnx', 3700147),
  TtsModelFile('text_encoder.onnx', 36416150),
  TtsModelFile('vector_estimator.onnx', 256534781),
  TtsModelFile('vocoder.onnx', 101424195),
  TtsModelFile('tts.json', 8253),
  TtsModelFile('unicode_indexer.json', 277676),
];

/// The selectable TTS models.
const List<TtsModelOption> kTtsModels = <TtsModelOption>[
  TtsModelOption(
    id: 'supertonic-3',
    displayName: 'Supertonic 3',
    huggingFaceRepoId: kSupertonic3RepoId,
    revision: kSupertonic3Revision,
    files: kSupertonic3Files,
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
