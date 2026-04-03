import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';

// ── AI config factories (for inference provider resolution tests) ────────────

/// Creates a test [AiConfigInferenceProvider] for use in provider resolution
/// tests.
AiConfigInferenceProvider testInferenceProvider({
  String id = 'provider-1',
  String apiKey = 'test-key',
}) {
  return AiConfig.inferenceProvider(
        id: id,
        baseUrl: 'https://generativelanguage.googleapis.com',
        name: 'Gemini',
        inferenceProviderType: InferenceProviderType.gemini,
        apiKey: apiKey,
        createdAt: DateTime(2024),
      )
      as AiConfigInferenceProvider;
}

/// Creates a test [AiConfigInferenceProvider] for a local provider (no API key
/// required).
AiConfigInferenceProvider testLocalInferenceProvider({
  String id = 'provider-local',
  String apiKey = '',
}) {
  return AiConfig.inferenceProvider(
        id: id,
        baseUrl: 'http://localhost:11434',
        name: 'Ollama',
        inferenceProviderType: InferenceProviderType.ollama,
        apiKey: apiKey,
        createdAt: DateTime(2024),
      )
      as AiConfigInferenceProvider;
}

/// Creates a test [AiConfigInferenceProfile].
AiConfigInferenceProfile testInferenceProfile({
  String id = 'profile-001',
  String name = 'Test Profile',
  String thinkingModelId = 'models/gemini-3-flash-preview',
  String? thinkingHighEndModelId,
  String? imageRecognitionModelId,
  String? transcriptionModelId,
  String? imageGenerationModelId,
  List<SkillAssignment> skillAssignments = const [],
  bool isDefault = false,
  bool desktopOnly = false,
}) {
  return AiConfig.inferenceProfile(
        id: id,
        name: name,
        thinkingModelId: thinkingModelId,
        thinkingHighEndModelId: thinkingHighEndModelId,
        imageRecognitionModelId: imageRecognitionModelId,
        transcriptionModelId: transcriptionModelId,
        imageGenerationModelId: imageGenerationModelId,
        skillAssignments: skillAssignments,
        isDefault: isDefault,
        desktopOnly: desktopOnly,
        createdAt: DateTime(2024),
      )
      as AiConfigInferenceProfile;
}

/// Creates a test [AiConfigModel] for use in provider resolution tests.
AiConfigModel testAiModel({
  String id = 'model-1',
  String providerModelId = 'models/gemini-3-flash-preview',
  String inferenceProviderId = 'provider-1',
}) {
  return AiConfig.model(
        id: id,
        name: 'Test Model',
        providerModelId: providerModelId,
        inferenceProviderId: inferenceProviderId,
        createdAt: DateTime(2024),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      )
      as AiConfigModel;
}
