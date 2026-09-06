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
