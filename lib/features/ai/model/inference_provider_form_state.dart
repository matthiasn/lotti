import 'package:formz/formz.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/utils/file_utils.dart';

/// Validation failures surfaced by the inference-provider edit form. Mapped to
/// user-facing copy by `ProviderFormErrorExtension.displayMessage`.
enum ProviderFormError {
  tooShort,
  empty,
  invalidUrl,
}

// Input validation classes

/// The provider's display name. Must be at least 3 characters.
class ApiKeyName extends FormzInput<String, ProviderFormError> {
  const ApiKeyName.pure([super.value = '']) : super.pure();
  const ApiKeyName.dirty([super.value = '']) : super.dirty();

  @override
  ProviderFormError? validator(String value) {
    return value.length < 3 ? ProviderFormError.tooShort : null;
  }
}

/// The provider's API key. Required (non-empty) for cloud providers, but
/// exempt for local providers in `ProviderConfig.noApiKeyRequired` (Ollama,
/// FastWhisper, Whisper) — hence the [providerType] is carried alongside the
/// value so the validator knows whether to enforce the requirement.
class ApiKeyValue extends FormzInput<String, ProviderFormError> {
  const ApiKeyValue.pure([super.value = '', this.providerType]) : super.pure();
  const ApiKeyValue.dirty([super.value = '', this.providerType])
    : super.dirty();

  final InferenceProviderType? providerType;

  @override
  ProviderFormError? validator(String value) {
    // API key is not required for local providers (Ollama, FastWhisper, and Whisper)
    if (ProviderConfig.noApiKeyRequired.contains(providerType)) {
      return null;
    }
    return value.isEmpty ? ProviderFormError.empty : null;
  }
}

/// The provider's optional free-text description. Always valid.
class DescriptionValue extends FormzInput<String, ProviderFormError> {
  const DescriptionValue.pure([super.value = '']) : super.pure();
  const DescriptionValue.dirty([super.value = '']) : super.dirty();

  @override
  ProviderFormError? validator(String value) {
    return null;
  }
}

/// The provider's API base URL. Optional (empty is valid); when set it must
/// parse to an absolute http/https URI.
class BaseUrl extends FormzInput<String, ProviderFormError> {
  const BaseUrl.pure([super.value = '']) : super.pure();
  const BaseUrl.dirty([super.value = '']) : super.dirty();

  @override
  ProviderFormError? validator(String value) {
    // Empty URLs are valid (field is optional)
    if (value.isEmpty) {
      return null;
    }

    // Simple URL validation
    try {
      final uri = Uri.parse(value);
      if (!uri.isAbsolute ||
          (!uri.scheme.startsWith('http') && !uri.scheme.startsWith('https'))) {
        return ProviderFormError.invalidUrl;
      }
      return null;
    } catch (_) {
      return ProviderFormError.invalidUrl;
    }
  }
}

/// Formz-backed state for the inference-provider edit form.
///
/// Aggregates the four validated inputs plus submission flags and the selected
/// [inferenceProviderType]. [lastUpdated] is bumped on every [copyWith] (even
/// when no field value changes) so Riverpod always sees a new state object and
/// rebuilds. Convert to the persisted entity with [toAiConfig].
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
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  final String? id; // null for new API keys
  final ApiKeyName name;
  final ApiKeyValue apiKey;
  final BaseUrl baseUrl;
  final DescriptionValue description;
  final bool isSubmitting;
  final bool submitFailed;
  final InferenceProviderType inferenceProviderType;
  final DateTime lastUpdated;

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
      lastUpdated: DateTime.now(),
    );
  }

  @override
  List<FormzInput<String, dynamic>> get inputs => [
    name,
    apiKey,
    baseUrl,
    description,
  ];

  /// Materializes the form into an [AiConfigInferenceProvider]. Generates a
  /// fresh UUID when [id] is null (new provider) and stamps `createdAt` to now.
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
