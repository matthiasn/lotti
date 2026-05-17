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
/// Used by the synced-audio dispatcher to refuse running an entry against a
/// profile that could route any slot through a cloud provider. A profile with
/// only the (mandatory) thinking slot is local when that slot's provider is
/// local; optional unfilled slots don't drag the result false (vacuously
/// local).
Future<bool> profileIsLocal(
  AiConfigInferenceProfile profile,
  AiConfigRepository repository,
) async {
  final referencedModelIds = <String>[
    profile.thinkingModelId,
    if (profile.thinkingHighEndModelId != null) profile.thinkingHighEndModelId!,
    if (profile.imageRecognitionModelId != null)
      profile.imageRecognitionModelId!,
    if (profile.transcriptionModelId != null) profile.transcriptionModelId!,
    if (profile.imageGenerationModelId != null) profile.imageGenerationModelId!,
  ];

  for (final modelId in referencedModelIds) {
    final modelConfig = await repository.getConfigById(modelId);
    if (modelConfig is! AiConfigModel) {
      // Referenced-but-unresolved model id. Fail closed.
      return false;
    }
    final providerConfig = await repository.getConfigById(
      modelConfig.inferenceProviderId,
    );
    if (providerConfig is! AiConfigInferenceProvider) {
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
