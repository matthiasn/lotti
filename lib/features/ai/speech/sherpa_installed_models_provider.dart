import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/speech/sherpa_model_repository.dart';

/// Device-local readiness, refreshed after explicit model changes. Synced
/// configuration rows are not evidence that this device can transcribe.
final sherpaInstalledModelIdsProvider = FutureProvider<Set<String>>((
  ref,
) async {
  final repository = ref.watch(sherpaModelRepositoryProvider);
  final installed = <String>{};
  for (final model in repository.models) {
    if (await repository.isAvailable(model.id)) installed.add(model.id);
  }
  return installed;
});

/// Whether resolving availability for [models] needs the installed-model
/// probe at all: true only when at least one of them routes through a sherpa
/// provider.
///
/// The probe ([sherpaInstalledModelIdsProvider]) verifies every downloaded
/// speech model once per process by hashing its files, a gigabyte-scale read
/// on a device with Whisper installed. A caller whose candidates are all
/// cloud or text models must not wait on it: the answer cannot change which
/// of those models it may offer.
bool needsSherpaAvailability({
  required Iterable<AiConfigModel> models,
  required Iterable<AiConfigInferenceProvider> providers,
}) {
  final sherpaProviderIds = {
    for (final provider in providers)
      if (provider.inferenceProviderType == InferenceProviderType.sherpa)
        provider.id,
  };
  if (sherpaProviderIds.isEmpty) return false;
  return models.any(
    (model) => sherpaProviderIds.contains(model.inferenceProviderId),
  );
}

/// Models usable on this device. Synced configurations preserve profile
/// references, but only verified local files make an embedded model available.
/// Wait for provider identity before admitting a configuration: the provider
/// and model streams can resolve in either order.
List<AiConfigModel> modelsAvailableOnDevice({
  required Iterable<AiConfigModel> models,
  required Iterable<AiConfigInferenceProvider> providers,
  required Set<String> installedSherpaModelIds,
}) {
  final providerTypes = {
    for (final provider in providers)
      provider.id: provider.inferenceProviderType,
  };
  return models.where((model) {
    final type = providerTypes[model.inferenceProviderId];
    return type != null &&
        (type != InferenceProviderType.sherpa ||
            installedSherpaModelIds.contains(model.providerModelId));
  }).toList();
}
