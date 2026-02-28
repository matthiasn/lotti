import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:meta/meta.dart';

/// Runtime-resolved inference profile with provider references for each slot.
///
/// Only the [thinkingModelId] and [thinkingProvider] are required — the
/// remaining slots are optional and only populated when the profile has
/// models assigned for those capabilities.
@immutable
class ResolvedProfile {
  const ResolvedProfile({
    required this.thinkingModelId,
    required this.thinkingProvider,
    this.imageRecognitionModelId,
    this.imageRecognitionProvider,
    this.transcriptionModelId,
    this.transcriptionProvider,
    this.imageGenerationModelId,
    this.imageGenerationProvider,
  });

  /// The providerModelId string for the thinking slot.
  final String thinkingModelId;

  /// The resolved inference provider for thinking.
  final AiConfigInferenceProvider thinkingProvider;

  /// The providerModelId string for image recognition (nullable).
  final String? imageRecognitionModelId;

  /// The resolved inference provider for image recognition (nullable).
  final AiConfigInferenceProvider? imageRecognitionProvider;

  /// The providerModelId string for transcription (nullable).
  final String? transcriptionModelId;

  /// The resolved inference provider for transcription (nullable).
  final AiConfigInferenceProvider? transcriptionProvider;

  /// The providerModelId string for image generation (nullable).
  final String? imageGenerationModelId;

  /// The resolved inference provider for image generation (nullable).
  final AiConfigInferenceProvider? imageGenerationProvider;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedProfile &&
          runtimeType == other.runtimeType &&
          thinkingModelId == other.thinkingModelId &&
          thinkingProvider == other.thinkingProvider &&
          imageRecognitionModelId == other.imageRecognitionModelId &&
          imageRecognitionProvider == other.imageRecognitionProvider &&
          transcriptionModelId == other.transcriptionModelId &&
          transcriptionProvider == other.transcriptionProvider &&
          imageGenerationModelId == other.imageGenerationModelId &&
          imageGenerationProvider == other.imageGenerationProvider;

  @override
  int get hashCode => Object.hash(
        thinkingModelId,
        thinkingProvider,
        imageRecognitionModelId,
        imageRecognitionProvider,
        transcriptionModelId,
        transcriptionProvider,
        imageGenerationModelId,
        imageGenerationProvider,
      );
}
