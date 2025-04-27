import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_config.freezed.dart';
part 'ai_config.g.dart';

enum InferenceProviderType {
  genericOpenAi,
  gemini,
}

@freezed
class AiConfig with _$AiConfig {
  const factory AiConfig.apiKey({
    required String id,
    required String baseUrl,
    required String apiKey,
    required String name,
    required DateTime createdAt,
    DateTime? updatedAt,
    String? comment,
  }) = _AiConfigApiKey;

  const factory AiConfig.promptTemplate({
    required String id,
    required String name,
    required String template,
    required DateTime createdAt,
    DateTime? updatedAt,
    String? description,
    Map<String, String>? defaultVariables,
    String? category,
  }) = _AiConfigPromptTemplate;

  factory AiConfig.fromJson(Map<String, dynamic> json) =>
      _$AiConfigFromJson(json);
}
