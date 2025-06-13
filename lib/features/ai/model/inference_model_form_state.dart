import 'package:formz/formz.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/utils/file_utils.dart';

enum ModelFormError {
  tooShort,
  invalidNumber,
}

// Input validation classes
class ModelName extends FormzInput<String, ModelFormError> {
  const ModelName.pure([super.value = '']) : super.pure();
  const ModelName.dirty([super.value = '']) : super.dirty();

  @override
  ModelFormError? validator(String value) {
    return value.length < 3 ? ModelFormError.tooShort : null;
  }
}

class ProviderModelId extends FormzInput<String, ModelFormError> {
  const ProviderModelId.pure([super.value = '']) : super.pure();
  const ProviderModelId.dirty([super.value = '']) : super.dirty();

  @override
  ModelFormError? validator(String value) {
    return value.length < 3 ? ModelFormError.tooShort : null;
  }
}

class ModelDescription extends FormzInput<String, String> {
  const ModelDescription.pure([super.value = '']) : super.pure();
  const ModelDescription.dirty([super.value = '']) : super.dirty();

  @override
  String? validator(String value) {
    return null; // Optional field
  }
}

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
    this.isSubmitting = false,
    this.submitFailed = false,
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
  final bool isSubmitting;
  final bool submitFailed;

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
    bool? isSubmitting,
    bool? submitFailed,
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
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitFailed: submitFailed ?? this.submitFailed,
    );
  }

  @override
  List<FormzInput<String, dynamic>> get inputs => [
        name,
        providerModelId,
        description,
        maxCompletionTokens,
      ];

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
      maxCompletionTokens: maxCompletionTokens.value.isEmpty
          ? null
          : int.tryParse(maxCompletionTokens.value),
    );
  }
}
