import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_model_form_state.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'inference_model_form_controller.g.dart';

@riverpod
class InferenceModelFormController extends _$InferenceModelFormController {
  final nameController = TextEditingController();
  final providerModelIdController = TextEditingController();
  final descriptionController = TextEditingController();

  AiConfigModel? _config;

  @override
  Future<InferenceModelFormState?> build({
    required String? configId,
  }) async {
    _config = configId != null
        ? (await ref.read(aiConfigRepositoryProvider).getConfigById(configId)
            as AiConfigModel?)
        : null;

    nameController.text = _config?.name ?? '';
    providerModelIdController.text = _config?.providerModelId ?? '';
    descriptionController.text = _config?.description ?? '';

    ref.onDispose(() {
      nameController.dispose();
      providerModelIdController.dispose();
      descriptionController.dispose();
    });

    if (_config != null) {
      return InferenceModelFormState(
        id: _config!.id,
        name: ModelName.pure(_config!.name),
        providerModelId: ProviderModelId.pure(_config!.providerModelId),
        description: ModelDescription.pure(_config!.description ?? ''),
        inferenceProviderId: _config!.inferenceProviderId,
        inputModalities: _config!.inputModalities,
        outputModalities: _config!.outputModalities,
        isReasoningModel: _config!.isReasoningModel,
      );
    }

    return InferenceModelFormState();
  }

  void _setAllFields({
    String? description,
    String? name,
    String? providerModelId,
    String? inferenceProviderId,
    List<Modality>? inputModalities,
    List<Modality>? outputModalities,
    bool? isReasoningModel,
  }) {
    final prev = state.valueOrNull;
    if (prev == null) return;

    // Check if any non-FormzInput field is being changed
    final isNonFormzFieldChanging = (inferenceProviderId != null &&
            inferenceProviderId != prev.inferenceProviderId) ||
        (inputModalities != null &&
            !listEquals(inputModalities, prev.inputModalities)) ||
        (outputModalities != null &&
            !listEquals(outputModalities, prev.outputModalities)) ||
        (isReasoningModel != null && isReasoningModel != prev.isReasoningModel);

    state = AsyncData(
      prev.copyWith(
        name: name != null ? ModelName.dirty(name) : prev.name,
        description: description != null
            ? ModelDescription.dirty(description)
            : (isNonFormzFieldChanging && prev.description.isPure
                ? ModelDescription.dirty(prev.description.value)
                : prev.description),
        providerModelId: providerModelId != null
            ? ProviderModelId.dirty(providerModelId)
            : prev.providerModelId,
        inferenceProviderId: inferenceProviderId,
        inputModalities: inputModalities,
        outputModalities: outputModalities,
        isReasoningModel: isReasoningModel,
      ),
    );
  }

  void nameChanged(String value) {
    if (nameController.text != value) {
      nameController.text = value;
    }
    _setAllFields(name: value);
  }

  void providerModelIdChanged(String value) {
    if (providerModelIdController.text != value) {
      providerModelIdController.text = value;
    }
    _setAllFields(providerModelId: value);
  }

  void descriptionChanged(String value) {
    if (descriptionController.text != value) {
      descriptionController.text = value;
    }
    _setAllFields(description: value);
  }

  void inferenceProviderIdChanged(String value) {
    _setAllFields(inferenceProviderId: value);
  }

  void inputModalitiesChanged(List<Modality> modalities) {
    _setAllFields(inputModalities: modalities);
  }

  void outputModalitiesChanged(List<Modality> modalities) {
    _setAllFields(outputModalities: modalities);
  }

  // ignore: avoid_positional_boolean_parameters
  void isReasoningModelChanged(bool value) {
    _setAllFields(isReasoningModel: value);
  }

  /// Add a new configuration
  Future<void> addConfig(AiConfig config) async {
    final repository = ref.read(aiConfigRepositoryProvider);
    await repository.saveConfig(config);
  }

  /// Update an existing configuration
  Future<void> updateConfig(AiConfig config) async {
    final repository = ref.read(aiConfigRepositoryProvider);
    await repository.saveConfig(
      config.copyWith(
        id: _config?.id ?? config.id,
        createdAt: _config?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Delete a configuration
  Future<void> deleteConfig(String id) async {
    final repository = ref.read(aiConfigRepositoryProvider);
    await repository.deleteConfig(id);
  }

  void reset() {
    nameController.clear();
    descriptionController.clear();
    state = AsyncData(InferenceModelFormState());
  }
}
