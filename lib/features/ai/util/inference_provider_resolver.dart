import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/services/domain_logging.dart';

typedef ResolvedInferenceProvider = ({
  AiConfigModel model,
  AiConfigInferenceProvider provider,
});

/// Resolves the configured model row and provider for a provider-native
/// [modelId].
///
/// This keeps callers that need model-row settings (for example Gemini
/// thinking mode) from performing a second providerModelId lookup after
/// provider resolution.
Future<ResolvedInferenceProvider?> resolveInferenceProviderWithModel({
  required String modelId,
  required AiConfigRepository aiConfigRepository,
  required DomainLogger domainLogger,
  String logTag = 'InferenceProviderResolver',
}) async {
  final models = await aiConfigRepository.getConfigsByType(AiConfigType.model);

  // Find configured models matching the requested provider model ID.
  final matchingModels = models
      .whereType<AiConfigModel>()
      .where((m) => m.providerModelId == modelId)
      .toList(growable: false);

  if (matchingModels.isEmpty) {
    domainLogger.log(
      LogDomain.ai,
      'Requested model not found in configured models '
      '(modelIdLength=${modelId.length})',
      subDomain: logTag,
      level: InsightLevel.warn,
    );
    return null;
  }

  final preferredProviderTypes = _providerTypesForKnownModel(modelId);
  ResolvedInferenceProvider? usableFallback;

  for (final model in matchingModels) {
    final providerId = model.inferenceProviderId;
    final provider = await aiConfigRepository.getConfigById(providerId);

    if (provider is! AiConfigInferenceProvider) {
      domainLogger.log(
        LogDomain.ai,
        'Skipping provider ${DomainLogger.sanitizeId(providerId)}: '
        'not an inference provider',
        subDomain: logTag,
        level: InsightLevel.warn,
      );
      continue;
    }

    if (!provider.isUsable) {
      domainLogger.log(
        LogDomain.ai,
        'Skipping provider ${DomainLogger.sanitizeId(providerId)}: '
        'API key is not configured',
        subDomain: logTag,
        level: InsightLevel.warn,
      );
      continue;
    }

    if (preferredProviderTypes.isEmpty ||
        preferredProviderTypes.contains(provider.inferenceProviderType)) {
      return (model: model, provider: provider);
    }

    usableFallback ??= (model: model, provider: provider);
    domainLogger.log(
      LogDomain.ai,
      'Skipping provider ${DomainLogger.sanitizeId(providerId)}: '
      'provider type ${provider.inferenceProviderType.name} does not match '
      'known model provider type(s) '
      '${preferredProviderTypes.map((type) => type.name).join(', ')}',
      subDomain: logTag,
    );
  }

  if (usableFallback != null) {
    domainLogger.log(
      LogDomain.ai,
      'No provider with a known matching type configured; '
      'falling back to usable provider '
      '${DomainLogger.sanitizeId(usableFallback.provider.id)}',
      subDomain: logTag,
    );
    return usableFallback;
  }

  domainLogger.log(
    LogDomain.ai,
    'No usable provider configured across '
    '${matchingModels.length} configured model row(s)',
    subDomain: logTag,
    level: InsightLevel.warn,
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
  required DomainLogger domainLogger,
  String logTag = 'InferenceProviderResolver',
}) async {
  final config = await aiConfigRepository.getConfigById(modelConfigId);
  if (config is! AiConfigModel) {
    domainLogger.log(
      LogDomain.ai,
      'Requested model config not found or wrong type '
      '(modelConfigIdLength=${modelConfigId.length})',
      subDomain: logTag,
      level: InsightLevel.warn,
    );
    return null;
  }

  return _resolveProviderForModel(
    config,
    aiConfigRepository: aiConfigRepository,
    domainLogger: domainLogger,
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
  required DomainLogger domainLogger,
  String logTag = 'InferenceProviderResolver',
}) async {
  final models = await aiConfigRepository.getConfigsByType(AiConfigType.model);
  for (final config in models.whereType<AiConfigModel>()) {
    if (config.id == modelId) {
      return _resolveProviderForModel(
        config,
        aiConfigRepository: aiConfigRepository,
        domainLogger: domainLogger,
        logTag: logTag,
      );
    }
  }

  return resolveInferenceProviderWithModel(
    modelId: modelId,
    aiConfigRepository: aiConfigRepository,
    domainLogger: domainLogger,
    logTag: logTag,
  );
}

Future<ResolvedInferenceProvider?> _resolveProviderForModel(
  AiConfigModel model, {
  required AiConfigRepository aiConfigRepository,
  required DomainLogger domainLogger,
  required String logTag,
}) async {
  final providerId = model.inferenceProviderId;
  final provider = await aiConfigRepository.getConfigById(providerId);

  if (provider is! AiConfigInferenceProvider) {
    domainLogger.log(
      LogDomain.ai,
      'Skipping provider ${DomainLogger.sanitizeId(providerId)}: '
      'not an inference provider',
      subDomain: logTag,
      level: InsightLevel.warn,
    );
    return null;
  }

  if (!provider.isUsable) {
    domainLogger.log(
      LogDomain.ai,
      'Skipping provider ${DomainLogger.sanitizeId(providerId)}: '
      'API key is not configured',
      subDomain: logTag,
      level: InsightLevel.warn,
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
