import 'package:flutter/material.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_provider_form_state.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/util/model_prepopulation_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'inference_provider_form_controller.g.dart';

@riverpod
class InferenceProviderFormController
    extends _$InferenceProviderFormController {
  final nameController = TextEditingController();
  final apiKeyController = TextEditingController();
  final baseUrlController = TextEditingController();
  final descriptionController = TextEditingController();

  AiConfigInferenceProvider? _config;

  @override
  Future<InferenceProviderFormState?> build({required String? configId}) async {
    _config = configId != null
        ? (await ref.read(aiConfigRepositoryProvider).getConfigById(configId)
            as AiConfigInferenceProvider?)
        : null;

    nameController.text = _config?.name ?? '';
    apiKeyController.text = _config?.apiKey ?? '';
    baseUrlController.text = _config?.baseUrl ?? '';
    descriptionController.text = _config?.description ?? '';

    ref.onDispose(() {
      nameController.dispose();
      apiKeyController.dispose();
      baseUrlController.dispose();
      descriptionController.dispose();
    });

    if (_config != null) {
      return InferenceProviderFormState(
        id: _config!.id,
        name: ApiKeyName.pure(_config!.name),
        apiKey:
            ApiKeyValue.pure(_config!.apiKey, _config!.inferenceProviderType),
        baseUrl: BaseUrl.pure(_config!.baseUrl),
        description: DescriptionValue.pure(_config!.description ?? ''),
        inferenceProviderType: _config!.inferenceProviderType,
      );
    }

    return InferenceProviderFormState(
      apiKey: const ApiKeyValue.pure('', InferenceProviderType.genericOpenAi),
      lastUpdated: DateTime.now(),
    );
  }

  void _setAllFields({
    String? description,
    String? name,
    String? apiKey,
    String? baseUrl,
    InferenceProviderType? inferenceProviderType,
  }) {
    final prev = state.valueOrNull;
    if (prev == null) return;

    // Check if any non-FormzInput field is being changed
    final isNonFormzFieldChanging = inferenceProviderType != null &&
        inferenceProviderType != prev.inferenceProviderType;

    // Create a completely new state object to force Riverpod to detect the change
    final newState = InferenceProviderFormState(
      id: prev.id,
      name: name != null ? ApiKeyName.dirty(name) : prev.name,
      apiKey: apiKey != null
          ? ApiKeyValue.dirty(
              apiKey, inferenceProviderType ?? prev.inferenceProviderType)
          : (inferenceProviderType != null &&
                  inferenceProviderType != prev.inferenceProviderType
              ? ApiKeyValue.dirty(prev.apiKey.value, inferenceProviderType)
              : prev.apiKey),
      baseUrl: baseUrl != null ? BaseUrl.dirty(baseUrl) : prev.baseUrl,
      description: description != null
          ? DescriptionValue.dirty(description)
          : (isNonFormzFieldChanging && prev.description.isPure
              ? DescriptionValue.dirty(prev.description.value)
              : prev.description),
      isSubmitting: prev.isSubmitting,
      submitFailed: prev.submitFailed,
      inferenceProviderType:
          inferenceProviderType ?? prev.inferenceProviderType,
    );

    state = AsyncData(newState);
  }

  void nameChanged(String value) {
    if (nameController.text != value) {
      nameController.text = value;
    }
    _setAllFields(name: value);
  }

  void apiKeyChanged(String value) {
    if (apiKeyController.text != value) {
      apiKeyController.text = value;
    }
    _setAllFields(apiKey: value);
  }

  void baseUrlChanged(String value) {
    if (baseUrlController.text != value) {
      baseUrlController.text = value;
    }
    _setAllFields(baseUrl: value);
  }

  void descriptionChanged(String value) {
    if (descriptionController.text != value) {
      descriptionController.text = value;
    }
    _setAllFields(description: value);
  }

  void inferenceProviderTypeChanged(InferenceProviderType value) {
    final prev = state.valueOrNull;

    // If we have a previous state and the provider type hasn't changed, don't do anything
    if (prev != null && prev.inferenceProviderType == value) {
      return;
    }

    String? newBaseUrl;
    String? newName;
    String? newApiKey;

    // Get default configuration from constants
    final defaultBaseUrl = ProviderConfig.getDefaultBaseUrl(value);

    // For new configs (when ID is null) or when the default is different from current
    // Always set the base URL for new configs, or when it would actually change
    if (defaultBaseUrl.isNotEmpty &&
        (prev?.id == null || baseUrlController.text != defaultBaseUrl)) {
      newBaseUrl = defaultBaseUrl;
      baseUrlController.text = newBaseUrl;
    }

    // Only update name if it's empty and we have a default name
    if (nameController.text.isEmpty) {
      final defaultName = ProviderConfig.getDefaultName(value);
      if (defaultName.isNotEmpty) {
        newName = defaultName;
        nameController.text = newName;
      }
    }

    // Clear API key for providers that don't require it
    if (!ProviderConfig.requiresApiKey(value)) {
      newApiKey = '';
      apiKeyController.text = '';
    }

    // If we don't have a previous state yet, create initial state with the new provider type
    if (prev == null) {
      state = AsyncData(InferenceProviderFormState(
        apiKey: ApiKeyValue.pure(newApiKey ?? '', value),
        baseUrl: BaseUrl.pure(newBaseUrl ?? ''),
        name: ApiKeyName.pure(newName ?? ''),
        inferenceProviderType: value,
        lastUpdated: DateTime.now(),
      ));
    } else {
      _setAllFields(
        inferenceProviderType: value,
        baseUrl: newBaseUrl,
        name: newName,
        apiKey: newApiKey,
      );
    }
  }

  /// Add a new configuration
  Future<void> addConfig(AiConfig config) async {
    final repository = ref.read(aiConfigRepositoryProvider);
    await repository.saveConfig(config);

    // Pre-populate known models for this provider
    if (config is AiConfigInferenceProvider) {
      final prepopulationService = ModelPrepopulationService(
        repository: repository,
      );
      final modelsCreated =
          await prepopulationService.prepopulateModelsForProvider(config);

      // Log the number of models created for debugging
      if (modelsCreated > 0) {
        debugPrint(
            'Pre-populated $modelsCreated models for provider ${config.name}');
      }
    }
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
  Future<CascadeDeletionResult> deleteConfig(String id) async {
    final repository = ref.read(aiConfigRepositoryProvider);
    return repository.deleteInferenceProviderWithModels(id);
  }
}
