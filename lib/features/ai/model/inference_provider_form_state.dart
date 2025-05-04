import 'package:formz/formz.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/utils/file_utils.dart';

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

class DescriptionValue extends FormzInput<String, String> {
  const DescriptionValue.pure() : super.pure('');
  const DescriptionValue.dirty([super.value = '']) : super.dirty();

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
class InferenceProviderFormState with FormzMixin {
  InferenceProviderFormState({
    this.id,
    this.name = const ApiKeyName.pure(),
    this.apiKey = const ApiKeyValue.pure(),
    this.baseUrl = const BaseUrl.pure(),
    this.description = const DescriptionValue.pure(),
    this.isSubmitting = false,
    this.submitFailed = false,
    this.inferenceProviderType = InferenceProviderType.genericOpenAi,
  });

  final String? id; // null for new API keys
  final ApiKeyName name;
  final ApiKeyValue apiKey;
  final BaseUrl baseUrl;
  final DescriptionValue description;
  final bool isSubmitting;
  final bool submitFailed;
  final InferenceProviderType inferenceProviderType;

  InferenceProviderFormState copyWith({
    String? id,
    ApiKeyName? name,
    ApiKeyValue? apiKey,
    BaseUrl? baseUrl,
    DescriptionValue? description,
    bool? isSubmitting,
    bool? submitFailed,
    InferenceProviderType? inferenceProviderType,
  }) {
    return InferenceProviderFormState(
      id: id ?? this.id,
      name: name ?? this.name,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      description: description ?? this.description,
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
        description,
      ];

  // Convert form state to AiConfig model
  AiConfig toAiConfig() {
    return AiConfig.inferenceProvider(
      id: id ?? uuid.v1(),
      name: name.value,
      apiKey: apiKey.value,
      baseUrl: baseUrl.value,
      description: description.value,
      createdAt: DateTime.now(),
      inferenceProviderType: inferenceProviderType,
    );
  }
}
