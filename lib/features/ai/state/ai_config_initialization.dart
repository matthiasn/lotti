import 'dart:developer' as developer;

import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/util/model_prepopulation_service.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ai_config_initialization.g.dart';

/// Seeds default inference profiles and backfills known models on startup.
///
/// This runs independently of the agents feature flag so that all users
/// get up-to-date local model configs and seeded profiles.
@Riverpod(keepAlive: true)
Future<void> aiConfigInitialization(Ref ref) async {
  final aiConfigRepo = ref.watch(aiConfigRepositoryProvider);
  final profileService = ProfileSeedingService(
    aiConfigRepository: aiConfigRepo,
  );

  // Backfill known models before seeding so that new default profiles can
  // resolve their model slots to existing `AiConfigModel` rows right away.
  final modelService = ModelPrepopulationService(repository: aiConfigRepo);
  try {
    await modelService.backfillNewModels();
  } catch (error, stackTrace) {
    developer.log(
      'Failed to backfill known models: $error',
      name: 'aiConfigInitialization',
      stackTrace: stackTrace,
    );
  }

  await profileService.seedDefaults();

  // Isolated from the backfill try/catch so a flaky backfill never skips
  // the profile upgrade pass.
  try {
    await profileService.upgradeExisting();
  } catch (error, stackTrace) {
    developer.log(
      'Failed to upgrade inference profiles: $error',
      name: 'aiConfigInitialization',
      stackTrace: stackTrace,
    );
  }
}
