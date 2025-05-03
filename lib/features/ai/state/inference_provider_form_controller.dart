import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_provider_form_state.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
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

    return InferenceProviderFormState(
      inferenceProviderType:
          _config?.inferenceProviderType ?? InferenceProviderType.genericOpenAi,
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
    state = AsyncData(
      (prev ?? InferenceProviderFormState()).copyWith(
        name: ApiKeyName.dirty(name ?? nameController.text),
        apiKey: ApiKeyValue.dirty(apiKey ?? apiKeyController.text),
        baseUrl: BaseUrl.dirty(baseUrl ?? baseUrlController.text),
        description:
            DescriptionValue.dirty(description ?? descriptionController.text),
        inferenceProviderType:
            inferenceProviderType ?? prev?.inferenceProviderType,
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
    if (value == InferenceProviderType.gemini) {
      baseUrlController.text =
          'https://generativelanguage.googleapis.com/v1beta/openai';

      if (nameController.text.isEmpty) {
        nameController.text = 'Gemini';
      }
    }
    if (value == InferenceProviderType.nebiusAiStudio) {
      baseUrlController.text = 'https://api.studio.nebius.com/v1';

      if (nameController.text.isEmpty) {
        nameController.text = 'Nebius AI Studio';
      }
    }
    _setAllFields(inferenceProviderType: value);
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
    apiKeyController.clear();
    baseUrlController.clear();
    descriptionController.clear();
    state = AsyncData(InferenceProviderFormState());
  }
}
