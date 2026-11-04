import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/tts/cloud/cloud_speech_synthesizer.dart';
import 'package:lotti/features/tts/cloud/cloud_voice_catalog.dart';
import 'package:lotti/features/tts/cloud/cloud_voice_catalog_repository.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';

/// One cloud voice service a profile reads aloud with: the read-aloud model
/// and the provider it runs on.
typedef CloudVoiceService = ({
  AiConfigInferenceProvider provider,
  AiConfigModel model,
});

/// The cloud voice services named by any profile's read-aloud slot, one per
/// voice catalog, for Speech settings to offer voices from: one per provider
/// for Mistral, whose catalog is the account's, and one per provider and
/// model for ElevenLabs, whose model decides the languages its voices speak —
/// so no profile's languages go missing behind another's model. Empty when
/// every profile reads aloud on the device.
///
/// A slot holds a model config id, or a provider-native id on profiles
/// written before ids were normalized; both are matched. Only providers with
/// a speech client count, as in `TtsCloudRoute.fromProfile`.
final FutureProvider<List<CloudVoiceService>> cloudVoiceServicesProvider =
    FutureProvider.autoDispose<List<CloudVoiceService>>((ref) async {
      Future<Iterable<T>> configs<T>(AiConfigType type) async =>
          (await ref.watch(
            aiConfigByTypeControllerProvider(type).future,
          )).whereType<T>();

      final slots = {
        for (final profile in await configs<AiConfigInferenceProfile>(
          AiConfigType.inferenceProfile,
        ))
          ?profile.speechModelId,
      };
      final providersById = {
        for (final provider in await configs<AiConfigInferenceProvider>(
          AiConfigType.inferenceProvider,
        ))
          if (cloudSpeechProviderTypes.contains(
            provider.inferenceProviderType,
          ))
            provider.id: provider,
      };
      final services = <String, CloudVoiceService>{};
      for (final model in await configs<AiConfigModel>(AiConfigType.model)) {
        final provider = providersById[model.inferenceProviderId];
        if (provider == null ||
            !(slots.contains(model.id) ||
                slots.contains(model.providerModelId))) {
          continue;
        }
        services.putIfAbsent(
          CloudVoiceCatalogRepository.cacheKey(provider, model),
          () => (provider: provider, model: model),
        );
      }
      return services.values.toList(growable: false);
    }, name: 'cloudVoiceServicesProvider');

/// A cloud voice service's catalog — its provider's voices for its model —
/// from the device cache when it is fresh.
final FutureProviderFamily<CloudVoiceCatalog, CloudVoiceService>
cloudVoiceCatalogProvider = FutureProvider.autoDispose
    .family<CloudVoiceCatalog, CloudVoiceService>(
      (ref, service) => ref
          .watch(cloudVoiceCatalogRepositoryProvider)
          .catalogFor(service.provider, service.model),
      name: 'cloudVoiceCatalogProvider',
    );
