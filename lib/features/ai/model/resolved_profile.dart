import 'package:collection/collection.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
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
    this.thinkingHighEndModelId,
    this.thinkingHighEndProvider,
    this.imageRecognitionModelId,
    this.imageRecognitionProvider,
    this.transcriptionModelId,
    this.transcriptionProvider,
    this.imageGenerationModelId,
    this.imageGenerationProvider,
    this.skillAssignments = const [],
  });

  /// The providerModelId string for the thinking slot.
  final String thinkingModelId;

  /// The resolved inference provider for thinking.
  final AiConfigInferenceProvider thinkingProvider;

  /// The providerModelId string for high-end thinking (nullable).
  /// Falls back to [thinkingModelId] when not set.
  final String? thinkingHighEndModelId;

  /// The resolved inference provider for high-end thinking (nullable).
  /// Falls back to [thinkingProvider] when not set.
  final AiConfigInferenceProvider? thinkingHighEndProvider;

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

  /// Skill assignments from the profile, for downstream automation lookup.
  final List<SkillAssignment> skillAssignments;

  /// Returns the high-end thinking model ID, falling back to the regular
  /// thinking model ID when the high-end slot is not configured.
  String get effectiveHighEndModelId =>
      thinkingHighEndModelId ?? thinkingModelId;

  /// Returns the high-end thinking provider, falling back to the regular
  /// thinking provider when the high-end slot is not configured.
  AiConfigInferenceProvider get effectiveHighEndProvider =>
      thinkingHighEndProvider ?? thinkingProvider;

  static const _listEquals = ListEquality<SkillAssignment>();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedProfile &&
          runtimeType == other.runtimeType &&
          thinkingModelId == other.thinkingModelId &&
          thinkingProvider == other.thinkingProvider &&
          thinkingHighEndModelId == other.thinkingHighEndModelId &&
          thinkingHighEndProvider == other.thinkingHighEndProvider &&
          imageRecognitionModelId == other.imageRecognitionModelId &&
          imageRecognitionProvider == other.imageRecognitionProvider &&
          transcriptionModelId == other.transcriptionModelId &&
          transcriptionProvider == other.transcriptionProvider &&
          imageGenerationModelId == other.imageGenerationModelId &&
          imageGenerationProvider == other.imageGenerationProvider &&
          _listEquals.equals(skillAssignments, other.skillAssignments);

  @override
  int get hashCode => Object.hash(
    thinkingModelId,
    thinkingProvider,
    thinkingHighEndModelId,
    thinkingHighEndProvider,
    imageRecognitionModelId,
    imageRecognitionProvider,
    transcriptionModelId,
    transcriptionProvider,
    imageGenerationModelId,
    imageGenerationProvider,
    _listEquals.hash(skillAssignments),
  );
}
