import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/state/consts.dart';

part 'ai_config.freezed.dart';
part 'ai_config.g.dart';

enum InferenceProviderType {
  alibaba,
  anthropic,
  gemini,
  genericOpenAi,
  mistral,
  mlxAudio,
  nebiusAiStudio,
  openAi,
  openRouter,
  ollama,
  voxtral,
  whisper,
}

enum Modality {
  text,
  audio,
  image,
}

/// User-facing reasoning effort levels for Gemini model rows.
///
/// Gemini 3 accepts these values directly as `thinkingLevel`; non-Gemini-3
/// request builders map them to the closest `thinkingBudget` value.
enum GeminiThinkingMode {
  minimal,
  low,
  medium,
  high,
}

/// Defines the types of additional input data a prompt might require.
enum InputDataType {
  task,
  tasksList,
  audioFiles,
  images,
}

@Freezed(toStringOverride: false)
sealed class AiConfig with _$AiConfig {
  const factory AiConfig.inferenceProvider({
    required String id,
    required String baseUrl,
    required String apiKey,
    required String name,
    required DateTime createdAt,
    required InferenceProviderType inferenceProviderType,
    DateTime? updatedAt,
    String? description,
  }) = AiConfigInferenceProvider;

  const factory AiConfig.model({
    required String id,
    required String name,
    required String providerModelId,
    required String inferenceProviderId,
    required DateTime createdAt,
    required List<Modality> inputModalities,
    required List<Modality> outputModalities,
    required bool isReasoningModel,
    @Default(false) bool supportsFunctionCalling,
    @Default(GeminiThinkingMode.low) GeminiThinkingMode geminiThinkingMode,
    DateTime? updatedAt,
    String? description,
    int? maxCompletionTokens,
  }) = AiConfigModel;

  const factory AiConfig.prompt({
    required String id,
    required String name,
    required String systemMessage,
    required String userMessage,
    required String defaultModelId,
    required List<String> modelIds,
    required DateTime createdAt,
    required bool useReasoning,
    required List<InputDataType> requiredInputData,
    required AiResponseType aiResponseType,
    String? comment,
    DateTime? updatedAt,
    String? description,
    Map<String, String>? defaultVariables,
    String? category,
    @Default(false) bool archived,
    @Default(false) bool trackPreconfigured,
    String? preconfiguredPromptId,
  }) = AiConfigPrompt;

  /// Inference profile — named bundle of model assignments per capability slot.
  ///
  /// Each slot stores an `AiConfigModel.id` for new writes so profiles can
  /// target a specific saved model row even when multiple rows share the same
  /// provider-native `providerModelId` but differ in settings.
  ///
  /// Legacy profiles may still carry provider-native model ids. Runtime
  /// resolution first treats a slot as `AiConfigModel.id`, then falls back to
  /// the legacy `providerModelId → AiConfigModel → AiConfigInferenceProvider`
  /// chain.
  const factory AiConfig.inferenceProfile({
    required String id,
    required String name,
    required DateTime createdAt,

    /// Model config id for agentic thinking (tool calling, reasoning).
    required String thinkingModelId,

    /// Model config id for high-end thinking tasks (e.g. coding prompt
    /// generation) where quality matters more than speed/cost.
    /// Falls back to the regular thinking model when not set.
    String? thinkingHighEndModelId,

    /// Model config id for image recognition / vision tasks.
    String? imageRecognitionModelId,

    /// Model config id for audio transcription.
    String? transcriptionModelId,

    /// Model config id for image generation.
    String? imageGenerationModelId,

    /// Whether this is a system-seeded default (non-deletable).
    @Default(false) bool isDefault,

    /// Whether this profile requires a desktop environment (e.g. Ollama).
    @Default(false) bool desktopOnly,

    /// Skills assigned to this profile.
    @Default([]) List<SkillAssignment> skillAssignments,

    /// Vector-clock host UUID of the device this profile is pinned to.
    ///
    /// When set, the auto-trigger pipeline runs this profile's inference only
    /// on the device whose `VectorClockService.getHost()` matches. Other
    /// devices receiving a synced audio entry that references this profile
    /// skip auto-triggering — preventing duplicate inference races between
    /// multiple capable desktops.
    ///
    /// Null means "no pin" — the auto-trigger does not claim entries for this
    /// profile on any device. Manual inference is unaffected.
    String? pinnedHostId,
    DateTime? updatedAt,
    String? description,
  }) = AiConfigInferenceProfile;

  /// A skill — a named capability (e.g. transcription, image analysis) that
  /// defines how to perform a specific AI task, decoupled from which model
  /// to use. The model is assigned by the profile's model slot matching the
  /// skill's type.
  const factory AiConfig.skill({
    required String id,
    required String name,
    required DateTime createdAt,
    required SkillType skillType,
    required List<Modality> requiredInputModalities,

    /// User-editable prose instructions for the system role.
    /// Does NOT contain placeholders — the prompt builder wraps these
    /// with the appropriate context based on `skillType` and
    /// `contextPolicy` at runtime.
    required String systemInstructions,

    /// User-editable prose instructions for the user message.
    /// Same rule: no placeholders, prompt builder handles injection.
    required String userInstructions,

    /// How much task context the prompt builder should inject.
    @Default(ContextPolicy.none) ContextPolicy contextPolicy,

    /// Whether this is a system-seeded skill (non-deletable).
    @Default(false) bool isPreconfigured,

    /// Whether the skill uses reasoning/extended thinking.
    @Default(false) bool useReasoning,
    DateTime? updatedAt,
    String? description,
  }) = AiConfigSkill;

  factory AiConfig.fromJson(Map<String, dynamic> json) =>
      _$AiConfigFromJson(json);
}

enum AiConfigType {
  inferenceProvider,
  prompt,
  model,
  inferenceProfile,
  skill,
}
