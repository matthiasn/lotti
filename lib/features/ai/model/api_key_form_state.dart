import 'package:formz/formz.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

// Input validation classes
class ApiKeyName extends FormzInput<String, String> {
  const ApiKeyName.pure() : super.pure('');
  const ApiKeyName.dirty([super.value = '']) : super.dirty();

  @override
  String? validator(String value) {
    return value.length < 3 ? 'Name must be at least 3 characters' : null;
  }
}

class ApiKeyValue extends FormzInput<String, String> {
  const ApiKeyValue.pure() : super.pure('');
  const ApiKeyValue.dirty([super.value = '']) : super.dirty();

  @override
  String? validator(String value) {
    return value.isEmpty ? 'API key cannot be empty' : null;
  }
}

class CommentValue extends FormzInput<String, String> {
  const CommentValue.pure() : super.pure('');
  const CommentValue.dirty([super.value = '']) : super.dirty();

  @override
  String? validator(String value) {
    return null;
  }
}

class BaseUrl extends FormzInput<String, String> {
  const BaseUrl.pure() : super.pure('');
  const BaseUrl.dirty([super.value = '']) : super.dirty();

  @override
  String? validator(String value) {
    // Simple URL validation
    try {
      final uri = Uri.parse(value);
      if (!uri.isAbsolute ||
          (!uri.scheme.startsWith('http') && !uri.scheme.startsWith('https'))) {
        return 'Please enter a valid URL';
      }
      return null;
    } catch (_) {
      return 'Please enter a valid URL';
    }
  }
}

// Form state class
class ApiKeyFormState with FormzMixin {
  ApiKeyFormState({
    this.id,
    this.name = const ApiKeyName.pure(),
    this.apiKey = const ApiKeyValue.pure(),
    this.baseUrl = const BaseUrl.pure(),
    this.comment = const CommentValue.pure(),
    this.isSubmitting = false,
    this.submitFailed = false,
    this.inferenceProviderType = InferenceProviderType.genericOpenAi,
  });

  final String? id; // null for new API keys
  final ApiKeyName name;
  final ApiKeyValue apiKey;
  final BaseUrl baseUrl;
  final CommentValue comment;
  final bool isSubmitting;
  final bool submitFailed;
  final InferenceProviderType inferenceProviderType;

  ApiKeyFormState copyWith({
    String? id,
    ApiKeyName? name,
    ApiKeyValue? apiKey,
    BaseUrl? baseUrl,
    CommentValue? comment,
    bool? isSubmitting,
    bool? submitFailed,
    InferenceProviderType? inferenceProviderType,
  }) {
    return ApiKeyFormState(
      id: id ?? this.id,
      name: name ?? this.name,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      comment: comment ?? this.comment,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitFailed: submitFailed ?? this.submitFailed,
      inferenceProviderType:
          inferenceProviderType ?? this.inferenceProviderType,
    );
  }

  @override
  List<FormzInput<String, dynamic>> get inputs => [
        name,
        apiKey,
        baseUrl,
        comment,
      ];

  // Convert form state to AiConfig model
  AiConfig toAiConfig() {
    return AiConfig.inferenceProvider(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.value,
      apiKey: apiKey.value,
      baseUrl: baseUrl.value,
      description: comment.value,
      createdAt: DateTime.now(),
      inferenceProviderType: inferenceProviderType,
    );
  }
}
