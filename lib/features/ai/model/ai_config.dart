import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_config.freezed.dart';
part 'ai_config.g.dart';

enum InferenceProviderType {
  anthropic,
  gemini,
  genericOpenAi,
  openAi,
  nebiusAiStudio,
}

@freezed
class AiConfig with _$AiConfig {
  const factory AiConfig.apiKey({
    required String id,
    required String baseUrl,
    required String apiKey,
    required String name,
    required DateTime createdAt,
    required InferenceProviderType inferenceProviderType,
    DateTime? updatedAt,
    String? comment,
  }) = AiConfigApiKey;

  const factory AiConfig.promptTemplate({
    required String id,
    required String name,
    required String template,
    required DateTime createdAt,
    DateTime? updatedAt,
    String? description,
    Map<String, String>? defaultVariables,
    String? category,
  }) = AiConfigPromptTemplate;

  factory AiConfig.fromJson(Map<String, dynamic> json) =>
      _$AiConfigFromJson(json);
}
