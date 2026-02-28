import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'inference_profile_controller.g.dart';

/// Streams all inference profiles for the profile management UI.
@riverpod
class InferenceProfileController extends _$InferenceProfileController {
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
