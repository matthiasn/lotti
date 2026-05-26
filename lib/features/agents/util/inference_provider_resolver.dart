import 'dart:developer' as developer;

import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/services/domain_logging.dart';

typedef ResolvedInferenceProvider = ({
  AiConfigModel model,
  AiConfigInferenceProvider provider,
});

/// Resolves the inference provider for a given [modelId].
///
/// Looks up configured [AiConfigModel] rows whose `providerModelId` matches
/// [modelId], then resolves the first usable provider with the known matching
/// provider type. This keeps the caller resilient to stale synced model rows
/// that point at a provider deleted on another device while a newer duplicate
/// row still points at a valid provider.
///
/// Returns `null` if the model is not configured, the provider is missing,
/// or the provider has no API key set.
Future<AiConfigInferenceProvider?> resolveInferenceProvider({
  required String modelId,
  required AiConfigRepository aiConfigRepository,
  String logTag = 'InferenceProviderResolver',
}) async {
  final resolved = await resolveInferenceProviderWithModel(
    modelId: modelId,
    aiConfigRepository: aiConfigRepository,
    logTag: logTag,
  );
  return resolved?.provider;
}

/// Resolves the configured model row and provider for a provider-native
/// [modelId].
///
/// This keeps callers that need model-row settings (for example Gemini
/// thinking mode) from performing a second providerModelId lookup after
/// provider resolution.
Future<ResolvedInferenceProvider?> resolveInferenceProviderWithModel({
  required String modelId,
  required AiConfigRepository aiConfigRepository,
  String logTag = 'InferenceProviderResolver',
}) async {
  final models = await aiConfigRepository.getConfigsByType(AiConfigType.model);

  // Find configured models matching the requested provider model ID.
  final matchingModels = models
      .whereType<AiConfigModel>()
      .where((m) => m.providerModelId == modelId)
      .toList(growable: false);

  if (matchingModels.isEmpty) {
    developer.log(
      'Requested model not found in configured models '
      '(modelIdLength=${modelId.length})',
      name: logTag,
    );
    return null;
  }

  final preferredProviderTypes = _providerTypesForKnownModel(modelId);
  ResolvedInferenceProvider? usableFallback;

  for (final model in matchingModels) {
    final providerId = model.inferenceProviderId;
    final provider = await aiConfigRepository.getConfigById(providerId);

    if (provider is! AiConfigInferenceProvider) {
      developer.log(
        'Skipping provider ${DomainLogger.sanitizeId(providerId)}: '
        'not an inference provider',
        name: logTag,
      );
      continue;
    }

    if (!provider.isUsable) {
      developer.log(
        'Skipping provider ${DomainLogger.sanitizeId(providerId)}: '
        'API key is not configured',
        name: logTag,
      );
      continue;
    }

    if (preferredProviderTypes.isEmpty ||
        preferredProviderTypes.contains(provider.inferenceProviderType)) {
      return (model: model, provider: provider);
    }

    usableFallback ??= (model: model, provider: provider);
    developer.log(
      'Skipping provider ${DomainLogger.sanitizeId(providerId)}: '
      'provider type ${provider.inferenceProviderType.name} does not match '
      'known model provider type(s) '
      '${preferredProviderTypes.map((type) => type.name).join(', ')}',
      name: logTag,
    );
  }

  if (usableFallback != null) {
    developer.log(
      'No provider with a known matching type configured; '
      'falling back to usable provider '
      '${DomainLogger.sanitizeId(usableFallback.provider.id)}',
      name: logTag,
    );
    return usableFallback;
  }

  developer.log(
    'No usable provider configured across '
    '${matchingModels.length} configured model row(s)',
    name: logTag,
  );
  return null;
}

/// Resolves the configured model row and provider for an [AiConfigModel.id].
///
/// Profile slots use model config ids for new writes so they can point at a
/// specific saved model row even when several rows share the same
/// provider-native `providerModelId` but differ in settings such as reasoning
/// effort.
Future<ResolvedInferenceProvider?> resolveInferenceProviderForModelConfigId({
  required String modelConfigId,
  required AiConfigRepository aiConfigRepository,
  String logTag = 'InferenceProviderResolver',
}) async {
  final config = await aiConfigRepository.getConfigById(modelConfigId);
  if (config is! AiConfigModel) {
    developer.log(
      'Requested model config not found or wrong type '
      '(modelConfigIdLength=${modelConfigId.length})',
      name: logTag,
    );
    return null;
  }

  return _resolveProviderForModel(
    config,
    aiConfigRepository: aiConfigRepository,
    logTag: logTag,
  );
}

/// Resolves a profile slot.
///
/// New profiles store [modelId] as an [AiConfigModel.id]. Legacy profiles store
/// the provider-native `providerModelId`, so this falls back to the old lookup
/// path when direct config-id resolution fails.
Future<ResolvedInferenceProvider?> resolveInferenceProviderForProfileSlot({
  required String modelId,
  required AiConfigRepository aiConfigRepository,
  String logTag = 'InferenceProviderResolver',
}) async {
  final models = await aiConfigRepository.getConfigsByType(AiConfigType.model);
  for (final config in models.whereType<AiConfigModel>()) {
    if (config.id == modelId) {
      return _resolveProviderForModel(
        config,
        aiConfigRepository: aiConfigRepository,
        logTag: logTag,
      );
    }
  }

  return resolveInferenceProviderWithModel(
    modelId: modelId,
    aiConfigRepository: aiConfigRepository,
    logTag: logTag,
  );
}

Future<ResolvedInferenceProvider?> _resolveProviderForModel(
  AiConfigModel model, {
  required AiConfigRepository aiConfigRepository,
  required String logTag,
}) async {
  final providerId = model.inferenceProviderId;
  final provider = await aiConfigRepository.getConfigById(providerId);

  if (provider is! AiConfigInferenceProvider) {
    developer.log(
      'Skipping provider ${DomainLogger.sanitizeId(providerId)}: '
      'not an inference provider',
      name: logTag,
    );
    return null;
  }

  if (!provider.isUsable) {
    developer.log(
      'Skipping provider ${DomainLogger.sanitizeId(providerId)}: '
      'API key is not configured',
      name: logTag,
    );
    return null;
  }

  return (model: model, provider: provider);
}

Set<InferenceProviderType> _providerTypesForKnownModel(String modelId) {
  return {
    for (final entry in knownModelsByProvider.entries)
      if (entry.value.any((model) => model.providerModelId == modelId))
        entry.key,
  };
}
