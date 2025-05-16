import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'prompt_form_controller.g.dart';

@riverpod
class PromptFormController extends _$PromptFormController {
  final nameController = TextEditingController();
  final templateController = TextEditingController();
  final descriptionController = TextEditingController();

  AiConfigPrompt? _config;

  @override
  Future<PromptFormState?> build({required String? configId}) async {
    _config = configId != null
        ? (await ref.read(aiConfigRepositoryProvider).getConfigById(configId)
            as AiConfigPrompt?)
        : null;

    nameController.text = _config?.name ?? '';
    templateController.text = _config?.template ?? '';
    descriptionController.text = _config?.description ?? '';

    ref.onDispose(() {
      nameController.dispose();
      templateController.dispose();
      descriptionController.dispose();
    });

    if (_config != null) {
      return PromptFormState(
        id: _config!.id,
        name: PromptName.dirty(_config!.name),
        template: PromptTemplate.dirty(_config!.template),
        defaultModelId: _config!.defaultModelId,
        modelIds: _config!.modelIds,
        useReasoning: _config!.useReasoning,
        requiredInputData: _config!.requiredInputData,
        comment: PromptComment.dirty(_config!.comment ?? ''),
        description: PromptDescription.dirty(_config!.description ?? ''),
        category: PromptCategory.dirty(_config!.category ?? ''),
        defaultVariables: _config!.defaultVariables ?? {},
      );
    }

    return PromptFormState();
  }

  void _setAllFields({
    String? name,
    String? template,
    String? defaultModelId,
    List<String>? modelIds,
    bool? useReasoning,
    List<InputDataType>? requiredInputData,
    String? comment,
    String? description,
    String? category,
    Map<String, String>? defaultVariables,
  }) {
    final prev = state.valueOrNull;
    if (prev == null) return;

    state = AsyncData(
      prev.copyWith(
        name: name != null ? PromptName.dirty(name) : prev.name,
        template:
            template != null ? PromptTemplate.dirty(template) : prev.template,
        defaultModelId: defaultModelId,
        modelIds: modelIds ?? prev.modelIds,
        useReasoning: useReasoning,
        requiredInputData: requiredInputData,
        comment: comment != null ? PromptComment.dirty(comment) : prev.comment,
        description: description != null
            ? PromptDescription.dirty(description)
            : prev.description,
        category:
            category != null ? PromptCategory.dirty(category) : prev.category,
        defaultVariables: defaultVariables,
      ),
    );
  }

  void nameChanged(String value) {
    if (nameController.text != value) {
      nameController.text = value;
    }
    _setAllFields(name: value);
  }

  void templateChanged(String value) {
    if (templateController.text != value) {
      templateController.text = value;
    }
    _setAllFields(template: value);
  }

  void defaultModelIdChanged(String value) {
    _setAllFields(defaultModelId: value);
  }

  // ignore: avoid_positional_boolean_parameters
  void useReasoningChanged(bool value) {
    _setAllFields(useReasoning: value);
  }

  void requiredInputDataChanged(List<InputDataType> inputData) {
    _setAllFields(requiredInputData: inputData);
  }

  void modelIdsChanged(List<String> newModelIds) {
    final currentFormState = state.valueOrNull;
    if (currentFormState == null) return;

    var newDefaultModelId = currentFormState.defaultModelId;

    if (newModelIds.isEmpty) {
      // If the new list of model IDs is empty, clear the default model ID.
      newDefaultModelId = '';
    } else if (!newModelIds.contains(currentFormState.defaultModelId)) {
      // If the current default model ID is not in the new list (or was empty),
      // set the default to the first model in the new list.
      newDefaultModelId = newModelIds.first;
    } else {
      // Default model ID is still valid within the new list, keep it.
      newDefaultModelId = currentFormState.defaultModelId;
    }

    _setAllFields(modelIds: newModelIds, defaultModelId: newDefaultModelId);
  }

  void descriptionChanged(String value) {
    if (descriptionController.text != value) {
      descriptionController.text = value;
    }
    _setAllFields(description: value);
  }

  void defaultVariablesChanged(Map<String, String> value) {
    _setAllFields(defaultVariables: value);
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
    templateController.clear();
    descriptionController.clear();
    state = AsyncData(PromptFormState());
  }
}
