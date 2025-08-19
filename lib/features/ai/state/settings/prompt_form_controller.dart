import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'prompt_form_controller.g.dart';

@riverpod
class PromptFormController extends _$PromptFormController {
  final nameController = TextEditingController();
  final systemMessageController = TextEditingController();
  final userMessageController = TextEditingController();
  final descriptionController = TextEditingController();

  AiConfigPrompt? _config;

  @override
  Future<PromptFormState?> build({required String? configId}) async {
    _config = configId != null
        ? (await ref.read(aiConfigRepositoryProvider).getConfigById(configId)
            as AiConfigPrompt?)
        : null;

    nameController.text = _config?.name ?? '';

    userMessageController.text = _config?.userMessage ?? '';
    systemMessageController.text = _config?.systemMessage ?? '';
    descriptionController.text = _config?.description ?? '';

    ref.onDispose(() {
      nameController.dispose();
      userMessageController.dispose();
      systemMessageController.dispose();
      descriptionController.dispose();
    });

    if (_config != null) {
      // Validate that selected models still exist
      final validModelIds = <String>[];
      for (final modelId in _config!.modelIds) {
        try {
          final modelConfig =
              await ref.read(aiConfigRepositoryProvider).getConfigById(modelId);
          if (modelConfig != null && modelConfig is AiConfigModel) {
            validModelIds.add(modelId);
          }
        } catch (_) {
          // Model doesn't exist, skip it
        }
      }

      // Update default model ID if it's no longer valid
      var validDefaultModelId = _config!.defaultModelId;
      if (!validModelIds.contains(validDefaultModelId)) {
        validDefaultModelId =
            validModelIds.isNotEmpty ? validModelIds.first : '';
      }

      return PromptFormState(
        id: _config!.id,
        name: PromptName.pure(_config!.name),
        systemMessage: PromptSystemMessage.pure(_config!.systemMessage),
        userMessage: PromptUserMessage.pure(_config!.userMessage),
        defaultModelId: validDefaultModelId,
        modelIds: validModelIds,
        useReasoning: _config!.useReasoning,
        requiredInputData: _config!.requiredInputData,
        comment: PromptComment.pure(_config!.comment ?? ''),
        description: PromptDescription.pure(_config!.description ?? ''),
        category: PromptCategory.pure(_config!.category ?? ''),
        defaultVariables: _config!.defaultVariables ?? {},
        aiResponseType: PromptAiResponseType.pure(_config!.aiResponseType),
        trackPreconfigured: _config!.trackPreconfigured,
        preconfiguredPromptId: _config!.preconfiguredPromptId,
      );
    }

    return PromptFormState();
  }

  void _setAllFields({
    String? name,
    String? systemMessage,
    String? userMessage,
    String? defaultModelId,
    List<String>? modelIds,
    bool? useReasoning,
    List<InputDataType>? requiredInputData,
    String? comment,
    String? description,
    String? category,
    Map<String, String>? defaultVariables,
    AiResponseType? aiResponseType,
    bool? trackPreconfigured,
    String? preconfiguredPromptId,
  }) {
    final prev = state.valueOrNull;
    if (prev == null) return;

    // Check if any non-FormzInput field is being changed
    final isNonFormzFieldChanging =
        (defaultModelId != null && defaultModelId != prev.defaultModelId) ||
            (modelIds != null && !listEquals(modelIds, prev.modelIds)) ||
            (useReasoning != null && useReasoning != prev.useReasoning) ||
            (requiredInputData != null &&
                !listEquals(requiredInputData, prev.requiredInputData)) ||
            (defaultVariables != null &&
                !mapEquals(defaultVariables, prev.defaultVariables));

    state = AsyncData(
      prev.copyWith(
        name: name != null ? PromptName.dirty(name) : prev.name,
        systemMessage: systemMessage != null
            ? PromptSystemMessage.dirty(systemMessage)
            : prev.systemMessage,
        userMessage: userMessage != null
            ? PromptUserMessage.dirty(userMessage)
            : prev.userMessage,
        defaultModelId: defaultModelId,
        modelIds: modelIds ?? prev.modelIds,
        useReasoning: useReasoning,
        requiredInputData: requiredInputData,
        comment: comment != null ? PromptComment.dirty(comment) : prev.comment,
        description: description != null
            ? PromptDescription.dirty(description)
            : (isNonFormzFieldChanging && prev.description.isPure
                ? PromptDescription.dirty(prev.description.value)
                : prev.description),
        category:
            category != null ? PromptCategory.dirty(category) : prev.category,
        defaultVariables: defaultVariables,
        aiResponseType: aiResponseType != null
            ? PromptAiResponseType.dirty(aiResponseType)
            : prev.aiResponseType,
        trackPreconfigured: trackPreconfigured ?? prev.trackPreconfigured,
        preconfiguredPromptId:
            preconfiguredPromptId ?? prev.preconfiguredPromptId,
      ),
    );
  }

  void nameChanged(String value) {
    if (nameController.text != value) {
      nameController.text = value;
    }
    _setAllFields(name: value);
  }

  void systemMessageChanged(String value) {
    if (systemMessageController.text != value) {
      systemMessageController.text = value;
    }
    _setAllFields(systemMessage: value);
  }

  void userMessageChanged(String value) {
    if (userMessageController.text != value) {
      userMessageController.text = value;
    }
    _setAllFields(userMessage: value);
  }

  void aiResponseTypeChanged(AiResponseType? value) {
    _setAllFields(aiResponseType: value);
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

  /// Add a new configuration
  Future<void> addConfig(AiConfig config) async {
    final repository = ref.read(aiConfigRepositoryProvider);
    await repository.saveConfig(config);
  }

  /// Update an existing configuration
  Future<void> updateConfig(AiConfig config) async {
    final repository = ref.read(aiConfigRepositoryProvider);
    var configToSave = config;

    // If it's a prompt config, validate model IDs before saving
    if (config is AiConfigPrompt) {
      final validModelIds = <String>[];
      for (final modelId in config.modelIds) {
        try {
          final modelConfig = await repository.getConfigById(modelId);
          if (modelConfig != null && modelConfig is AiConfigModel) {
            validModelIds.add(modelId);
          }
        } catch (_) {
          // Model doesn't exist, skip it
        }
      }

      // Update default model ID if it's no longer valid
      var validDefaultModelId = config.defaultModelId;
      if (!validModelIds.contains(validDefaultModelId)) {
        validDefaultModelId =
            validModelIds.isNotEmpty ? validModelIds.first : '';
      }

      configToSave = config.copyWith(
        modelIds: validModelIds,
        defaultModelId: validDefaultModelId,
      );
    }

    // Safely handle createdAt based on config type
    final createdAt = _config?.createdAt ??
        (configToSave is AiConfigPrompt ? configToSave.createdAt : null) ??
        DateTime.now();

    final finalConfig = configToSave.copyWith(
      id: _config?.id ?? configToSave.id,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );

    await repository.saveConfig(finalConfig);
  }

  /// Populate the form with a preconfigured prompt template.
  /// This method updates all form fields with the values from the template.
  void populateFromPreconfiguredPrompt(PreconfiguredPrompt template) {
    // Update the text controllers
    nameController.text = template.name;
    systemMessageController.text = template.systemMessage;
    userMessageController.text = template.userMessage;
    descriptionController.text = template.description;

    // Update all form fields through the centralized method
    _setAllFields(
      name: template.name,
      systemMessage: template.systemMessage,
      userMessage: template.userMessage,
      useReasoning: template.useReasoning,
      requiredInputData: template.requiredInputData,
      description: template.description,
      defaultVariables: template.defaultVariables,
      aiResponseType: template.aiResponseType,
      trackPreconfigured: true,
      preconfiguredPromptId: template.id,
    );
  }

  void reset() {
    nameController.clear();
    systemMessageController.clear();
    userMessageController.clear();
    descriptionController.clear();
    state = AsyncData(PromptFormState());
  }

  /// Toggle tracking of preconfigured prompt
  // ignore: avoid_positional_boolean_parameters
  void toggleTrackPreconfigured(bool track) {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    if (track) {
      // Guard against enabling tracking when preconfiguredPromptId is missing
      if (currentState.preconfiguredPromptId == null) {
        _setAllFields(trackPreconfigured: false);
        return;
      }

      // Guard against enabling tracking when lookup returns null
      final preconfiguredPrompt =
          preconfiguredPrompts[currentState.preconfiguredPromptId!];
      if (preconfiguredPrompt == null) {
        _setAllFields(trackPreconfigured: false);
        return;
      }

      // Only enable tracking after successful prompt lookup
      systemMessageController.text = preconfiguredPrompt.systemMessage;
      userMessageController.text = preconfiguredPrompt.userMessage;

      _setAllFields(
        systemMessage: preconfiguredPrompt.systemMessage,
        userMessage: preconfiguredPrompt.userMessage,
        trackPreconfigured: true,
      );
    } else {
      // Just toggle the tracking flag off, but keep the preconfiguredPromptId
      // so the toggle remains visible
      _setAllFields(trackPreconfigured: false);
    }
  }
}
