import 'package:lotti/features/ai/model/ai_config.dart';

AiConfigInferenceProvider hProvider({
  required InferenceProviderType type,
  String name = 'My Provider',
  String apiKey = 'sk-test',
  String baseUrl = 'https://api.example.com',
  String id = 'provider-1',
}) {
  return AiConfigInferenceProvider(
    id: id,
    name: name,
    inferenceProviderType: type,
    apiKey: apiKey,
    baseUrl: baseUrl,
    createdAt: DateTime(2024, 3, 15),
  );
}

AiConfigModel hModel({
  required String providerId,
  String id = 'model-1',
  String name = 'Test Model',
  String providerModelId = 'test-model-id',
  bool isReasoning = true,
  List<Modality> inputModalities = const [Modality.text, Modality.image],
  List<Modality> outputModalities = const [Modality.text],
}) {
  return AiConfigModel(
    id: id,
    name: name,
    providerModelId: providerModelId,
    inferenceProviderId: providerId,
    createdAt: DateTime(2024, 3, 15),
    inputModalities: inputModalities,
    outputModalities: outputModalities,
    isReasoningModel: isReasoning,
  );
}

AiConfigInferenceProfile hProfile({
  String id = 'profile-1',
  String name = 'Test Profile',
  String? description = 'A test profile',
  bool isDefault = false,
  String thinking = 'test-model-id',
  String? imageRecognition,
  String? transcription,
  String? imageGeneration,
}) {
  return AiConfigInferenceProfile(
    id: id,
    name: name,
    description: description,
    thinkingModelId: thinking,
    imageRecognitionModelId: imageRecognition,
    transcriptionModelId: transcription,
    imageGenerationModelId: imageGeneration,
    isDefault: isDefault,
    createdAt: DateTime(2024, 3, 15),
  );
}
