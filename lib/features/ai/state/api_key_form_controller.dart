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

    return ApiKeyFormState();
  }

  void nameChanged(String value) {
    final name = ApiKeyName.dirty(value);
    state = AsyncData(
      state.valueOrNull!.copyWith(
        name: name,
      ),
    );
  }

  void apiKeyChanged(String value) {
    final apiKey = ApiKeyValue.dirty(value);
    state = AsyncData(
      state.valueOrNull!.copyWith(
        apiKey: apiKey,
      ),
    );
  }

  void baseUrlChanged(String value) {
    final baseUrl = BaseUrl.dirty(value);
    state = AsyncData(
      state.valueOrNull!.copyWith(
        baseUrl: baseUrl,
      ),
    );
  }

  void commentChanged(String value) {
    final comment = CommentValue.dirty(value);
    state = AsyncData(
      state.valueOrNull!.copyWith(
        comment: comment,
      ),
    );
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
