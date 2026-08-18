import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/util/model_prepopulation_service.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/ai/util/seed_tombstone_migration.dart';
import 'package:lotti/get_it.dart';

/// Seeds default inference profiles and backfills known models on startup.
///
/// This runs independently of the agents feature flag so that all users
/// get up-to-date local model configs and seeded profiles.
final aiConfigInitializationProvider = FutureProvider<void>(
  aiConfigInitialization,
  name: 'aiConfigInitializationProvider',
);
Future<void> aiConfigInitialization(Ref ref) async {
  final aiConfigRepo = ref.watch(aiConfigRepositoryProvider);
  final profileService = ProfileSeedingService(
    aiConfigRepository: aiConfigRepo,
  );

  // Convert the 0.9.1067/0.9.1068 settings-row tombstone ledger into
  // soft-deleted rows *before* anything seeds. Those releases hard-deleted the
  // config, so on upgrade a deleted seed is simply absent — and backfill or
  // seeding would recreate it, undoing the user's deletion.
  var tombstonesMigrated = true;
  try {
    await SeedTombstoneMigration(
      aiConfigRepository: aiConfigRepo,
      settingsDb: getIt<SettingsDb>(),
    ).migrate();
  } catch (error, stackTrace) {
    tombstonesMigrated = false;
    developer.log(
      'Failed to migrate legacy seed tombstones: $error',
      name: 'aiConfigInitialization',
      stackTrace: stackTrace,
    );
  }

  // Every pass below recreates rows it finds missing, and an unconverted
  // ledger is exactly the state where "missing" means "the user deleted it".
  // Skipping this launch leaves the ledger intact to retry, which is strictly
  // better than resurrecting — and syncing — deleted seeds.
  if (!tombstonesMigrated) {
    developer.log(
      'Skipping model backfill and profile seeding: legacy seed tombstones '
      'are not migrated, so deleted seeds would be recreated',
      name: 'aiConfigInitialization',
    );
    return;
  }

  // Backfill known models before seeding so that new default profiles can
  // resolve their model slots to existing `AiConfigModel` rows right away.
  final modelService = ModelPrepopulationService(repository: aiConfigRepo);
  // Before the backfill, so a repaired row already owns the new id when the
  // backfill decides whether that model still needs creating.
  try {
    await modelService.migrateRenamedModelIds();
  } catch (error, stackTrace) {
    developer.log(
      'Failed to migrate renamed model ids: $error',
      name: 'aiConfigInitialization',
      stackTrace: stackTrace,
    );
  }

  try {
    await modelService.backfillNewModels();
  } catch (error, stackTrace) {
    developer.log(
      'Failed to backfill known models: $error',
      name: 'aiConfigInitialization',
      stackTrace: stackTrace,
    );
  }

  // Seeding now reads provider rows for its usable-provider gate, so it gets
  // its own guard: a failed read must not take down the rest of the app's
  // startup sequence riding on this provider.
  try {
    await profileService.seedDefaults();
  } catch (error, stackTrace) {
    developer.log(
      'Failed to seed inference profiles: $error',
      name: 'aiConfigInitialization',
      stackTrace: stackTrace,
    );
  }

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

  // After upgrades, shed default seeds whose provider type has no usable
  // provider — installs that seeded the full catalog before seeding was
  // gated on provider setup, and providers deleted since the last launch.
  try {
    await profileService.removeOrphanedDefaultSeeds();
  } catch (error, stackTrace) {
    developer.log(
      'Failed to remove orphaned default profiles: $error',
      name: 'aiConfigInitialization',
      stackTrace: stackTrace,
    );
  }
}
