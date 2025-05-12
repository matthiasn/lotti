import 'package:formz/formz.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/utils/file_utils.dart';

// Input validation classes
class ModelName extends FormzInput<String, String> {
  const ModelName.pure() : super.pure('');
  const ModelName.dirty([super.value = '']) : super.dirty();

  @override
  String? validator(String value) {
    return value.length < 3 ? 'Name must be at least 3 characters' : null;
  }
}

class ProviderModelId extends FormzInput<String, String> {
  const ProviderModelId.pure() : super.pure('');
  const ProviderModelId.dirty([super.value = '']) : super.dirty();

  @override
  String? validator(String value) {
    return value.length < 3
        ? 'ProviderModelId must be at least 3 characters'
        : null;
  }
}

class ModelDescription extends FormzInput<String, String> {
  const ModelDescription.pure() : super.pure('');
  const ModelDescription.dirty([super.value = '']) : super.dirty();

  @override
  String? validator(String value) {
    return null; // Optional field
  }
}

// Form state class
class InferenceModelFormState with FormzMixin {
  InferenceModelFormState({
    this.id,
    this.name = const ModelName.pure(),
    this.providerModelId = const ProviderModelId.pure(),
    this.description = const ModelDescription.pure(),
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
    );
  }
}
