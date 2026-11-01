import 'package:collection/collection.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/ai/skill_assignment.dart';
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
    this.thinkingModel,
    this.chatModelId,
    this.chatProvider,
    this.chatModel,
    this.chatModelUnavailable = false,
    this.thinkingHighEndModelId,
    this.thinkingHighEndProvider,
    this.thinkingHighEndModel,
    this.imageRecognitionModelId,
    this.imageRecognitionProvider,
    this.imageRecognitionModel,
    this.transcriptionModelId,
    this.transcriptionProvider,
    this.transcriptionModel,
    this.audioPostProcessingModelId,
    this.audioPostProcessingProvider,
    this.audioPostProcessingModel,
    this.audioPostProcessingModelUnavailable = false,
    this.imageGenerationModelId,
    this.imageGenerationProvider,
    this.imageGenerationModel,
    this.speechModelId,
    this.speechProvider,
    this.speechModel,
    this.skillAssignments = const [],
    this.profileId,
    this.profileName,
    this.agentId,
    this.agentName,
  });

  /// Id of the `AiConfigInferenceProfile` this route was built from; null for
  /// a bare legacy model route and for the ephemeral direct-transcription
  /// stand-in, which come from no profile at all.
  final String? profileId;

  /// The profile's name when this route was resolved, copied so a record of
  /// what ran survives a later rename or deletion of the profile.
  final String? profileName;

  /// Id of the agent whose configuration selected this profile; null when the
  /// profile came from the subject or its category rather than from an agent.
  final String? agentId;

  /// That agent's display name, copied for the same reason as [profileName].
  final String? agentName;

  /// The provider-native model id for the thinking slot.
  final String thinkingModelId;

  /// The resolved inference provider for thinking.
  final AiConfigInferenceProvider thinkingProvider;

  /// The configured model row used for thinking, when resolved from a profile.
  final AiConfigModel? thinkingModel;

  /// Provider-native model id and configured route for interactive query chat.
  /// Unset slots use the resolved thinking route, including agent overrides.
  final String? chatModelId;
  final AiConfigInferenceProvider? chatProvider;
  final AiConfigModel? chatModel;

  /// An explicitly configured chat slot could not resolve. Agent work can
  /// continue, but chat must surface the unavailable setup rather than switch.
  final bool chatModelUnavailable;

  String get effectiveChatModelId => chatModelId ?? thinkingModelId;
  AiConfigInferenceProvider get effectiveChatProvider =>
      chatProvider ?? thinkingProvider;
  AiConfigModel? get effectiveChatModel => chatModel ?? thinkingModel;

  /// The provider-native model id for high-end thinking (nullable).
  /// Falls back to [thinkingModelId] when not set.
  final String? thinkingHighEndModelId;

  /// The resolved inference provider for high-end thinking (nullable).
  /// Falls back to [thinkingProvider] when not set.
  final AiConfigInferenceProvider? thinkingHighEndProvider;

  /// The configured model row used for high-end thinking, when set.
  final AiConfigModel? thinkingHighEndModel;

  /// The provider-native model id for image recognition (nullable).
  final String? imageRecognitionModelId;

  /// The resolved inference provider for image recognition (nullable).
  final AiConfigInferenceProvider? imageRecognitionProvider;

  /// The configured model row used for image recognition, when set.
  final AiConfigModel? imageRecognitionModel;

  /// The provider-native model id for transcription (nullable).
  final String? transcriptionModelId;

  /// The resolved inference provider for transcription (nullable).
  final AiConfigInferenceProvider? transcriptionProvider;

  /// The configured model row used for transcription, when set.
  final AiConfigModel? transcriptionModel;

  /// Provider-native model id and configured route for audio post-processing:
  /// correcting a transcript against the speech dictionary and summarizing
  /// the recording. Unset slots use the resolved thinking route.
  final String? audioPostProcessingModelId;
  final AiConfigInferenceProvider? audioPostProcessingProvider;
  final AiConfigModel? audioPostProcessingModel;

  /// An explicitly configured audio post-processing slot could not resolve.
  /// The step fails rather than quietly running on the thinking model the
  /// user chose it over.
  final bool audioPostProcessingModelUnavailable;

  String get effectiveAudioPostProcessingModelId =>
      audioPostProcessingModelId ?? thinkingModelId;
  AiConfigInferenceProvider get effectiveAudioPostProcessingProvider =>
      audioPostProcessingProvider ?? thinkingProvider;
  AiConfigModel? get effectiveAudioPostProcessingModel =>
      audioPostProcessingModel ?? thinkingModel;

  /// The route that corrects a transcript against the speech dictionary —
  /// the post-processing slot, or the thinking model it falls back to — when
  /// that model can call the correction tool. Null when its configured slot
  /// does not resolve on this device, or when the model cannot call tools.
  ({AiConfigInferenceProvider provider, AiConfigModel model})?
  get transcriptCorrectionRoute {
    if (audioPostProcessingModelUnavailable) return null;
    final model = effectiveAudioPostProcessingModel;
    if (model == null || !model.supportsFunctionCalling) return null;
    return (provider: effectiveAudioPostProcessingProvider, model: model);
  }

  /// The provider-native model id for image generation (nullable).
  final String? imageGenerationModelId;

  /// The resolved inference provider for image generation (nullable).
  final AiConfigInferenceProvider? imageGenerationProvider;

  /// The configured model row used for image generation, when set.
  final AiConfigModel? imageGenerationModel;

  /// Provider-native model id and configured route for speech synthesis.
  /// Unset when the profile names no speech model, or names one that no
  /// longer resolves; read-aloud then uses the on-device voice, which sends
  /// nothing anywhere.
  final String? speechModelId;
  final AiConfigInferenceProvider? speechProvider;
  final AiConfigModel? speechModel;

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

  /// Returns the high-end thinking model config, falling back to the regular
  /// thinking model config when the high-end slot is not configured.
  AiConfigModel? get effectiveHighEndModel =>
      thinkingHighEndModel ?? thinkingModel;

  /// Returns this profile with only its thinking route replaced.
  ResolvedProfile withThinkingRoute({
    required AiConfigModel model,
    required AiConfigInferenceProvider provider,
  }) => _copyWith(
    thinkingModelId: model.providerModelId,
    thinkingProvider: provider,
    thinkingModel: model,
  );

  /// Returns this profile as selected by the agent [agentId], named
  /// [agentName].
  ResolvedProfile forAgent({
    required String agentId,
    required String agentName,
  }) => _copyWith(agentId: agentId, agentName: agentName);

  ResolvedProfile _copyWith({
    String? thinkingModelId,
    AiConfigInferenceProvider? thinkingProvider,
    AiConfigModel? thinkingModel,
    String? agentId,
    String? agentName,
  }) {
    return ResolvedProfile(
      thinkingModelId: thinkingModelId ?? this.thinkingModelId,
      thinkingProvider: thinkingProvider ?? this.thinkingProvider,
      thinkingModel: thinkingModel ?? this.thinkingModel,
      chatModelId: chatModelId,
      chatProvider: chatProvider,
      chatModel: chatModel,
      chatModelUnavailable: chatModelUnavailable,
      thinkingHighEndModelId: thinkingHighEndModelId,
      thinkingHighEndProvider: thinkingHighEndProvider,
      thinkingHighEndModel: thinkingHighEndModel,
      imageRecognitionModelId: imageRecognitionModelId,
      imageRecognitionProvider: imageRecognitionProvider,
      imageRecognitionModel: imageRecognitionModel,
      transcriptionModelId: transcriptionModelId,
      transcriptionProvider: transcriptionProvider,
      transcriptionModel: transcriptionModel,
      audioPostProcessingModelId: audioPostProcessingModelId,
      audioPostProcessingProvider: audioPostProcessingProvider,
      audioPostProcessingModel: audioPostProcessingModel,
      audioPostProcessingModelUnavailable: audioPostProcessingModelUnavailable,
      imageGenerationModelId: imageGenerationModelId,
      imageGenerationProvider: imageGenerationProvider,
      imageGenerationModel: imageGenerationModel,
      speechModelId: speechModelId,
      speechProvider: speechProvider,
      speechModel: speechModel,
      skillAssignments: skillAssignments,
      profileId: profileId,
      profileName: profileName,
      agentId: agentId ?? this.agentId,
      agentName: agentName ?? this.agentName,
    );
  }

  static const _listEquals = ListEquality<SkillAssignment>();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedProfile &&
          runtimeType == other.runtimeType &&
          thinkingModelId == other.thinkingModelId &&
          thinkingProvider == other.thinkingProvider &&
          thinkingModel == other.thinkingModel &&
          chatModelId == other.chatModelId &&
          chatProvider == other.chatProvider &&
          chatModel == other.chatModel &&
          chatModelUnavailable == other.chatModelUnavailable &&
          thinkingHighEndModelId == other.thinkingHighEndModelId &&
          thinkingHighEndProvider == other.thinkingHighEndProvider &&
          thinkingHighEndModel == other.thinkingHighEndModel &&
          imageRecognitionModelId == other.imageRecognitionModelId &&
          imageRecognitionProvider == other.imageRecognitionProvider &&
          imageRecognitionModel == other.imageRecognitionModel &&
          transcriptionModelId == other.transcriptionModelId &&
          transcriptionProvider == other.transcriptionProvider &&
          transcriptionModel == other.transcriptionModel &&
          audioPostProcessingModelId == other.audioPostProcessingModelId &&
          audioPostProcessingProvider == other.audioPostProcessingProvider &&
          audioPostProcessingModel == other.audioPostProcessingModel &&
          audioPostProcessingModelUnavailable ==
              other.audioPostProcessingModelUnavailable &&
          imageGenerationModelId == other.imageGenerationModelId &&
          imageGenerationProvider == other.imageGenerationProvider &&
          imageGenerationModel == other.imageGenerationModel &&
          speechModelId == other.speechModelId &&
          speechProvider == other.speechProvider &&
          speechModel == other.speechModel &&
          _listEquals.equals(skillAssignments, other.skillAssignments) &&
          profileId == other.profileId &&
          profileName == other.profileName &&
          agentId == other.agentId &&
          agentName == other.agentName;

  @override
  int get hashCode => Object.hashAll([
    thinkingModelId,
    thinkingProvider,
    thinkingModel,
    chatModelId,
    chatProvider,
    chatModel,
    chatModelUnavailable,
    thinkingHighEndModelId,
    thinkingHighEndProvider,
    thinkingHighEndModel,
    imageRecognitionModelId,
    imageRecognitionProvider,
    imageRecognitionModel,
    transcriptionModelId,
    transcriptionProvider,
    transcriptionModel,
    audioPostProcessingModelId,
    audioPostProcessingProvider,
    audioPostProcessingModel,
    audioPostProcessingModelUnavailable,
    imageGenerationModelId,
    imageGenerationProvider,
    imageGenerationModel,
    speechModelId,
    speechProvider,
    speechModel,
    _listEquals.hash(skillAssignments),
    profileId,
    profileName,
    agentId,
    agentName,
  ]);
}

/// Outcome of resolving a task-agent inference setup.
enum AgentSetupResolutionStatus { resolved, disabled, broken, legacyUnknown }

/// The configuration tier that supplied the effective thinking route.
enum AgentSetupResolutionSource {
  directModel,
  baseProfile,
  legacyAgentProfile,
  legacyVersionProfile,
  legacyTemplateProfile,
  legacyModel,
}

/// Stable identity used to compare live routing with immutable report history.
@immutable
class InferenceRouteFingerprint {
  const InferenceRouteFingerprint({
    required this.providerModelId,
    required this.providerType,
    required this.runtimeSettings,
    this.modelConfigId,
    this.providerConfigId,
  });

  final String? modelConfigId;
  final String providerModelId;
  final String? providerConfigId;
  final InferenceProviderType providerType;
  final Map<String, Object?> runtimeSettings;

  static const _mapEquals = MapEquality<String, Object?>();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InferenceRouteFingerprint &&
          modelConfigId == other.modelConfigId &&
          providerModelId == other.providerModelId &&
          providerConfigId == other.providerConfigId &&
          providerType == other.providerType &&
          _mapEquals.equals(runtimeSettings, other.runtimeSettings);

  @override
  int get hashCode => Object.hash(
    modelConfigId,
    providerModelId,
    providerConfigId,
    providerType,
    _mapEquals.hash(runtimeSettings),
  );
}

/// Detailed, shared resolution result consumed by runtime and UI.
@immutable
class ResolvedAgentSetup {
  const ResolvedAgentSetup({
    required this.status,
    this.profile,
    this.source,
    this.setupOrigin,
  });

  final AgentSetupResolutionStatus status;
  final ResolvedProfile? profile;
  final AgentSetupResolutionSource? source;
  final AgentInferenceSetupOrigin? setupOrigin;
}
