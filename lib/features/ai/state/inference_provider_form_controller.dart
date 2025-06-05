import 'package:flutter/material.dart';
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
        apiKey: ApiKeyValue.pure(_config!.apiKey),
        baseUrl: BaseUrl.pure(_config!.baseUrl),
        description: DescriptionValue.pure(_config!.description ?? ''),
        inferenceProviderType: _config!.inferenceProviderType,
      );
    }

    return InferenceProviderFormState();
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

    state = AsyncData(
      prev.copyWith(
        name: name != null ? ApiKeyName.dirty(name) : prev.name,
        apiKey: apiKey != null ? ApiKeyValue.dirty(apiKey) : prev.apiKey,
        baseUrl: baseUrl != null ? BaseUrl.dirty(baseUrl) : prev.baseUrl,
        description: description != null
            ? DescriptionValue.dirty(description)
            : (isNonFormzFieldChanging && prev.description.isPure
                ? DescriptionValue.dirty(prev.description.value)
                : prev.description),
        inferenceProviderType:
            inferenceProviderType ?? prev.inferenceProviderType,
      ),
    );
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
    String? newBaseUrl;
    String? newName;

    if (value == InferenceProviderType.gemini) {
      newBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/openai';
      if (nameController.text.isEmpty) {
        newName = 'Gemini';
      }
    }
    if (value == InferenceProviderType.nebiusAiStudio) {
      newBaseUrl = 'https://api.studio.nebius.com/v1';
      if (nameController.text.isEmpty) {
        newName = 'Nebius AI Studio';
      }
    }
    if (value == InferenceProviderType.ollama) {
      newBaseUrl = 'http://localhost:11434/v1';
      if (nameController.text.isEmpty) {
        newName = 'Ollama (local)';
      }
    }
    if (value == InferenceProviderType.openAi) {
      newBaseUrl = 'https://api.openai.com/v1';
      if (nameController.text.isEmpty) {
        newName = 'OpenAI';
      }
    }

    // Update text controllers if needed
    if (newBaseUrl != null) {
      baseUrlController.text = newBaseUrl;
    }
    if (newName != null) {
      nameController.text = newName;
    }

    _setAllFields(
      inferenceProviderType: value,
      baseUrl: newBaseUrl,
      name: newName,
    );
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

  void reset() {
    nameController.clear();
    apiKeyController.clear();
    baseUrlController.clear();
    descriptionController.clear();
    state = AsyncData(InferenceProviderFormState());
  }
}
