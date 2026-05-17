import 'package:lotti/features/ai/helpers/prompt_capability_filter.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';

/// True iff every populated model id on [profile] resolves to a local
/// inference provider (`ollama`, `voxtral`, `whisper`, `mlxAudio`).
///
/// Operates on the raw [AiConfigInferenceProfile] (not on a `ResolvedProfile`)
/// because `ProfileResolver` silently drops optional slots whose provider
/// configs can't be resolved — a profile referencing Gemini for transcription
/// whose Gemini provider has been deleted would appear "local" through a
/// resolved-profile check, even though the user clearly configured a cloud
/// model. This function fails closed instead: a referenced model whose model
/// or provider config can't be looked up is treated as **not local**.
///
/// Profile slots store the `providerModelId` string (see `ai_config.dart`
/// docstring on `inferenceProfile`). The lookup chain therefore matches the
/// same pattern as `resolveInferenceProvider`: scan all `AiConfigModel` rows
/// for a `providerModelId` match, then `getConfigById` on the model's
/// `inferenceProviderId`. We must not assume the stored slot value equals a
/// row's primary key.
///
/// Used by the synced-audio dispatcher to refuse running an entry against a
/// profile that could route any slot through a cloud provider. A profile with
/// only the (mandatory) thinking slot is local when that slot's provider is
/// local; optional unfilled slots don't drag the result false (vacuously
/// local).
Future<bool> profileIsLocal(
  AiConfigInferenceProfile profile,
  AiConfigRepository repository,
) async {
  // Deduplicate via Set so a profile that reuses the same model id across
  // slots (e.g. the same Ollama thinking model in both the standard and
  // high-end slot) doesn't hit the lookup maps twice.
  final referencedModelIds = <String>{
    profile.thinkingModelId,
    if (profile.thinkingHighEndModelId != null) profile.thinkingHighEndModelId!,
    if (profile.imageRecognitionModelId != null)
      profile.imageRecognitionModelId!,
    if (profile.transcriptionModelId != null) profile.transcriptionModelId!,
    if (profile.imageGenerationModelId != null) profile.imageGenerationModelId!,
  };

  if (referencedModelIds.isEmpty) return true;

  // Load every model + provider row once; profile slots reference
  // `providerModelId`, not the row's primary key, so a single scan is the
  // load-bearing lookup. Providers are batch-fetched too so we don't hit
  // the repository per slot inside the loop below.
  final modelRows = await repository.getConfigsByType(AiConfigType.model);
  final modelsByProviderModelId = <String, AiConfigModel>{
    for (final config in modelRows.whereType<AiConfigModel>())
      config.providerModelId: config,
  };
  final providerRows = await repository.getConfigsByType(
    AiConfigType.inferenceProvider,
  );
  final providersById = <String, AiConfigInferenceProvider>{
    for (final config in providerRows.whereType<AiConfigInferenceProvider>())
      config.id: config,
  };

  for (final providerModelId in referencedModelIds) {
    final modelConfig = modelsByProviderModelId[providerModelId];
    if (modelConfig == null) {
      // Referenced-but-unresolved model id. Fail closed.
      return false;
    }
    final providerConfig = providersById[modelConfig.inferenceProviderId];
    if (providerConfig == null) {
      // Referenced-but-unresolved provider config. Fail closed.
      return false;
    }
    if (!PromptCapabilityFilter.isLocalOnlyProviderType(
      providerConfig.inferenceProviderType,
    )) {
      return false;
    }
  }

  return true;
}
