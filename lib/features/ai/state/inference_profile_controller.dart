import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';

/// Streams all inference profiles for the profile management UI.
final StreamNotifierProvider<InferenceProfileController, List<AiConfig>>
inferenceProfileControllerProvider =
    StreamNotifierProvider.autoDispose<
      InferenceProfileController,
      List<AiConfig>
    >(
      InferenceProfileController.new,
      name: 'inferenceProfileControllerProvider',
    );

class InferenceProfileController extends StreamNotifier<List<AiConfig>> {
  @override
  Stream<List<AiConfig>> build() {
    final repository = ref.watch(aiConfigRepositoryProvider);
    return repository.watchProfiles();
  }

  /// Save a new or updated profile.
  Future<void> saveProfile(AiConfigInferenceProfile profile) async {
    final repository = ref.read(aiConfigRepositoryProvider);
    await repository.saveConfig(profile);
  }
}
