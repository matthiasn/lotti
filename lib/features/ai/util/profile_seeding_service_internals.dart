part of 'profile_seeding_service.dart';

/// Private helpers of [ProfileSeedingService] that hold no state of their own; kept beside the class as an extension so the library stays readable.
extension _ProfileSeedingServiceInternals on ProfileSeedingService {
  Future<List<AiConfigModel>> _fetchModelRows() async {
    final configs = await _repo.getConfigsByType(AiConfigType.model);
    return configs.whereType<AiConfigModel>().toList(growable: false);
  }

  Future<List<AiConfigInferenceProvider>> _fetchProviderRows() async {
    final configs = await _repo.getConfigsByType(
      AiConfigType.inferenceProvider,
    );
    return configs.whereType<AiConfigInferenceProvider>().toList(
      growable: false,
    );
  }
}
