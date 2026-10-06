import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/util/model_prepopulation_service.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/ai/util/seed_tombstone_migration.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';

const _subDomain = 'aiConfigInitialization';

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
  final logger = ref.watch(domainLoggerProvider);
  final profileService = ProfileSeedingService(
    aiConfigRepository: aiConfigRepo,
    domainLogger: logger,
  );

  // Convert the 0.9.1067/0.9.1068 settings-row tombstone ledger into
  // soft-deleted rows *before* anything seeds. Those releases hard-deleted the
  // config, so on upgrade a deleted seed is simply absent — and backfill or
  // seeding would recreate it, undoing the user's deletion.
  var tombstonesMigrated = true;
  try {
    await SeedTombstoneMigration(
      aiConfigRepository: aiConfigRepo,
      settingsDb: ref.read(settingsDbProvider),
      domainLogger: logger,
    ).migrate();
  } catch (error, stackTrace) {
    tombstonesMigrated = false;
    logger.error(
      LogDomain.ai,
      error,
      stackTrace: stackTrace,
      subDomain: _subDomain,
      message: 'Failed to migrate legacy seed tombstones',
    );
  }

  // Every pass below recreates rows it finds missing, and an unconverted
  // ledger is exactly the state where "missing" means "the user deleted it".
  // Skipping this launch leaves the ledger intact to retry, which is strictly
  // better than resurrecting — and syncing — deleted seeds.
  if (!tombstonesMigrated) {
    logger.log(
      LogDomain.ai,
      'Skipping model backfill and profile seeding: legacy seed tombstones '
      'are not migrated, so deleted seeds would be recreated',
      subDomain: _subDomain,
      level: InsightLevel.warn,
    );
    return;
  }

  // Backfill known models before seeding so that new default profiles can
  // resolve their model slots to existing `AiConfigModel` rows right away.
  final modelService = ModelPrepopulationService(
    repository: aiConfigRepo,
    domainLogger: logger,
  );
  // Before the backfill, so a repaired row already owns the new id when the
  // backfill decides whether that model still needs creating.
  try {
    await modelService.migrateRenamedModelIds();
  } catch (error, stackTrace) {
    logger.error(
      LogDomain.ai,
      error,
      stackTrace: stackTrace,
      subDomain: _subDomain,
      message: 'Failed to migrate renamed model ids',
    );
  }

  try {
    await modelService.backfillNewModels();
  } catch (error, stackTrace) {
    logger.error(
      LogDomain.ai,
      error,
      stackTrace: stackTrace,
      subDomain: _subDomain,
      message: 'Failed to backfill known models',
    );
  }

  // Seeding now reads provider rows for its usable-provider gate, so it gets
  // its own guard: a failed read must not take down the rest of the app's
  // startup sequence riding on this provider.
  try {
    await profileService.seedDefaults();
  } catch (error, stackTrace) {
    logger.error(
      LogDomain.ai,
      error,
      stackTrace: stackTrace,
      subDomain: _subDomain,
      message: 'Failed to seed inference profiles',
    );
  }

  // Isolated from the backfill try/catch so a flaky backfill never skips
  // the profile upgrade pass.
  try {
    await profileService.upgradeExisting();
  } catch (error, stackTrace) {
    logger.error(
      LogDomain.ai,
      error,
      stackTrace: stackTrace,
      subDomain: _subDomain,
      message: 'Failed to upgrade inference profiles',
    );
  }

  // After upgrades, shed default seeds whose provider type has no usable
  // provider — installs that seeded the full catalog before seeding was
  // gated on provider setup, and providers deleted since the last launch.
  try {
    await profileService.removeOrphanedDefaultSeeds();
  } catch (error, stackTrace) {
    logger.error(
      LogDomain.ai,
      error,
      stackTrace: stackTrace,
      subDomain: _subDomain,
      message: 'Failed to remove orphaned default profiles',
    );
  }
}
