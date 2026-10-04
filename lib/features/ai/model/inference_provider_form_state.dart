import 'package:formz/formz.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
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

/// Whether [value] is usable as an inference provider's base URL: exactly the
/// `http` or `https` scheme, a host, and no credentials in the URL — a base URL
/// is stored, shown and synced, so a password in it would travel with it.
///
/// Plain `http` stays allowed: self-hosted servers on a LAN name (`ollama.lan`,
/// a single-label host) cannot be told apart from public ones by spelling. A
/// synced change of endpoint never inherits this device's API key, so a
/// remote device cannot point a stored key at a host of its choosing
/// (`AiConfigRepository`).
bool isWellFormedInferenceBaseUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

/// The provider's API base URL. Optional (empty is valid); when set it must
/// satisfy [isWellFormedInferenceBaseUrl].
class BaseUrl extends FormzInput<String, ProviderFormError> {
  const BaseUrl.pure([super.value = '']) : super.pure();
  const BaseUrl.dirty([super.value = '']) : super.dirty();

  @override
  ProviderFormError? validator(String value) {
    if (value.isEmpty) return null;
    return isWellFormedInferenceBaseUrl(value)
        ? null
        : ProviderFormError.invalidUrl;
  }
}

/// Formz-backed state for the inference-provider edit form.
///
/// Aggregates the four validated inputs plus submission flags and the selected
/// [inferenceProviderType]. Convert to the persisted entity with [toAiConfig].
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

  @override
  List<FormzInput<String, dynamic>> get inputs => [
    name,
    apiKey,
    baseUrl,
    description,
  ];

  /// Materializes the form into an [AiConfigInferenceProvider]. Generates a
  /// fresh UUID when [id] is null (new provider) and stamps `createdAt` to now.
  /// The base URL is stored trimmed, as [isWellFormedInferenceBaseUrl] judged
  /// it: clients append paths to it verbatim.
  // Convert form state to AiConfig model
  AiConfig toAiConfig() {
    return AiConfig.inferenceProvider(
      id: id ?? uuid.v1(),
      name: name.value,
      apiKey: apiKey.value,
      baseUrl: baseUrl.value.trim(),
      description: description.value,
      createdAt: DateTime.now(),
      inferenceProviderType: inferenceProviderType,
    );
  }
}
