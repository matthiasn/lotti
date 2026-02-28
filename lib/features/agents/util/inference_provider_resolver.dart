import 'dart:developer' as developer;

import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';

/// Resolves the inference provider for a given [modelId].
///
/// Looks up the configured [AiConfigModel] whose `providerModelId` matches
/// [modelId], then resolves the associated inference provider. This ensures
/// the caller uses the correct provider even when multiple providers are
/// configured.
///
/// Returns `null` if the model is not configured, the provider is missing,
/// or the provider has no API key set.
Future<AiConfigInferenceProvider?> resolveInferenceProvider({
  required String modelId,
  required AiConfigRepository aiConfigRepository,
  String logTag = 'InferenceProviderResolver',
}) async {
  final models = await aiConfigRepository.getConfigsByType(AiConfigType.model);

  // Find the configured model matching the requested model ID.
  final matchingModel = models.whereType<AiConfigModel>().where(
        (m) => m.providerModelId == modelId,
      );

  if (matchingModel.isEmpty) {
    developer.log(
      'Model $modelId not found in configured models',
      name: logTag,
    );
    return null;
  }

  // Resolve the inference provider associated with this model.
  final providerId = matchingModel.first.inferenceProviderId;
  final provider = await aiConfigRepository.getConfigById(providerId);

  if (provider is! AiConfigInferenceProvider) {
    developer.log(
      'Provider $providerId for model $modelId is not an inference provider',
      name: logTag,
    );
    return null;
  }

  if (provider.apiKey.trim().isEmpty &&
      ProviderConfig.requiresApiKey(provider.inferenceProviderType)) {
    developer.log(
      'Provider $providerId has no API key configured',
      name: logTag,
    );
    return null;
  }

  return provider;
}
