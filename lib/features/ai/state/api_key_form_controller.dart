import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/api_key_form_state.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'api_key_form_controller.g.dart';

@riverpod
class ApiKeyFormController extends _$ApiKeyFormController {
  final nameController = TextEditingController();
  final apiKeyController = TextEditingController();
  final baseUrlController = TextEditingController();
  final commentController = TextEditingController();

  AiConfigApiKey? _config;

  @override
  Future<ApiKeyFormState?> build({required String? configId}) async {
    _config = configId != null
        ? (await ref.read(aiConfigRepositoryProvider).getConfigById(configId)
            as AiConfigApiKey?)
        : null;

    nameController.text = _config?.name ?? '';
    apiKeyController.text = _config?.apiKey ?? '';
    baseUrlController.text = _config?.baseUrl ?? '';
    commentController.text = _config?.comment ?? '';

    ref.onDispose(() {
      nameController.dispose();
      apiKeyController.dispose();
      baseUrlController.dispose();
      commentController.dispose();
    });

    return ApiKeyFormState(
      inferenceProviderType:
          _config?.inferenceProviderType ?? InferenceProviderType.genericOpenAi,
    );
  }

  void _setAllFields({
    String? comment,
    String? name,
    String? apiKey,
    String? baseUrl,
    InferenceProviderType? inferenceProviderType,
  }) {
    final prev = state.valueOrNull;
    state = AsyncData(
      (prev ?? ApiKeyFormState()).copyWith(
        name: ApiKeyName.dirty(name ?? nameController.text),
        apiKey: ApiKeyValue.dirty(apiKey ?? apiKeyController.text),
        baseUrl: BaseUrl.dirty(baseUrl ?? baseUrlController.text),
        comment: CommentValue.dirty(comment ?? commentController.text),
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

  void commentChanged(String value) {
    if (commentController.text != value) {
      commentController.text = value;
    }
    _setAllFields(comment: value);
  }

  void inferenceProviderTypeChanged(InferenceProviderType value) {
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
    commentController.clear();
    state = AsyncData(ApiKeyFormState());
  }
}
