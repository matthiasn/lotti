import 'package:formz/formz.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/utils/file_utils.dart';

/// Validation failures surfaced by the inference-model edit form. Mapped to
/// user-facing copy by `ModelFormErrorExtension.displayMessage`.
enum ModelFormError {
  tooShort,
  invalidNumber,
}

// Input validation classes

/// The model's display name. Must be at least 3 characters.
class ModelName extends FormzInput<String, ModelFormError> {
  const ModelName.pure([super.value = '']) : super.pure();
  const ModelName.dirty([super.value = '']) : super.dirty();

  @override
  ModelFormError? validator(String value) {
    return value.length < 3 ? ModelFormError.tooShort : null;
  }
}

/// The provider-side model identifier sent on the wire (e.g.
/// `gemini-2.5-flash`). Must be at least 3 characters.
class ProviderModelId extends FormzInput<String, ModelFormError> {
  const ProviderModelId.pure([super.value = '']) : super.pure();
  const ProviderModelId.dirty([super.value = '']) : super.dirty();

  @override
  ModelFormError? validator(String value) {
    return value.length < 3 ? ModelFormError.tooShort : null;
  }
}

/// The model's optional free-text description. Always valid.
class ModelDescription extends FormzInput<String, String> {
  const ModelDescription.pure([super.value = '']) : super.pure();
  const ModelDescription.dirty([super.value = '']) : super.dirty();

  @override
  String? validator(String value) {
    return null; // Optional field
  }
}

/// Optional cap on completion tokens, entered as text. Empty is valid; any
/// non-empty value must parse to a positive integer.
class MaxCompletionTokens extends FormzInput<String, ModelFormError> {
  const MaxCompletionTokens.pure([super.value = '']) : super.pure();
  const MaxCompletionTokens.dirty([super.value = '']) : super.dirty();

  @override
  ModelFormError? validator(String value) {
    if (value.isEmpty) return null; // Optional field
    final intValue = int.tryParse(value);
    if (intValue == null || intValue <= 0) return ModelFormError.invalidNumber;
    return null;
  }
}

/// Formz-backed state for the inference-model edit form.
///
/// Holds the validated text inputs plus the model's capability flags
/// (modalities, reasoning, function-calling, Gemini thinking mode) and the
/// owning [inferenceProviderId]. Convert to the persisted entity with
/// [toAiConfig].
// Form state class
class InferenceModelFormState with FormzMixin {
  InferenceModelFormState({
    this.id,
    this.name = const ModelName.pure(),
    this.providerModelId = const ProviderModelId.pure(),
    this.description = const ModelDescription.pure(),
    this.maxCompletionTokens = const MaxCompletionTokens.pure(),
    this.inferenceProviderId = '',
    this.inputModalities = const [Modality.text],
    this.outputModalities = const [Modality.text],
    this.isReasoningModel = false,
    this.supportsFunctionCalling = false,
    this.geminiThinkingMode = GeminiThinkingMode.low,
  });

  final String? id; // null for new models
  final ModelName name;
  final ProviderModelId providerModelId;
  final ModelDescription description;
  final MaxCompletionTokens maxCompletionTokens;
  final String inferenceProviderId;
  final List<Modality> inputModalities;
  final List<Modality> outputModalities;
  final bool isReasoningModel;
  final bool supportsFunctionCalling;
  final GeminiThinkingMode geminiThinkingMode;

  InferenceModelFormState copyWith({
    String? id,
    ModelName? name,
    ProviderModelId? providerModelId,
    ModelDescription? description,
    MaxCompletionTokens? maxCompletionTokens,
    String? inferenceProviderId,
    List<Modality>? inputModalities,
    List<Modality>? outputModalities,
    bool? isReasoningModel,
    bool? supportsFunctionCalling,
    GeminiThinkingMode? geminiThinkingMode,
  }) {
    return InferenceModelFormState(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      maxCompletionTokens: maxCompletionTokens ?? this.maxCompletionTokens,
      providerModelId: providerModelId ?? this.providerModelId,
      inferenceProviderId: inferenceProviderId ?? this.inferenceProviderId,
      inputModalities: inputModalities ?? this.inputModalities,
      outputModalities: outputModalities ?? this.outputModalities,
      isReasoningModel: isReasoningModel ?? this.isReasoningModel,
      supportsFunctionCalling:
          supportsFunctionCalling ?? this.supportsFunctionCalling,
      geminiThinkingMode: geminiThinkingMode ?? this.geminiThinkingMode,
    );
  }

  @override
  List<FormzInput<String, dynamic>> get inputs => [
    name,
    providerModelId,
    description,
    maxCompletionTokens,
  ];

  /// Materializes the form into an [AiConfigModel]. Generates a fresh UUID when
  /// [id] is null (new model), stamps `createdAt` to now, and parses
  /// [maxCompletionTokens] to an int (null when left blank).
  // Convert form state to AiConfig model
  AiConfig toAiConfig() {
    return AiConfig.model(
      id: id ?? uuid.v1(),
      name: name.value,
      providerModelId: providerModelId.value,
      description: description.value,
      inferenceProviderId: inferenceProviderId,
      createdAt: DateTime.now(),
      inputModalities: inputModalities,
      outputModalities: outputModalities,
      isReasoningModel: isReasoningModel,
      supportsFunctionCalling: supportsFunctionCalling,
      geminiThinkingMode: geminiThinkingMode,
      maxCompletionTokens: maxCompletionTokens.value.isEmpty
          ? null
          : int.tryParse(maxCompletionTokens.value),
    );
  }
}
