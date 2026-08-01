import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/ai/util/seed_tombstone_migration.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import 'seed_tombstone_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAiConfigRepository repo;
  late SettingsDb settingsDb;
  late SeedTombstoneMigration migration;

  setUp(() {
    repo = MockAiConfigRepository();
    settingsDb = SettingsDb(inMemoryDatabase: true);
    addTearDown(settingsDb.close);
    migration = SeedTombstoneMigration(
      aiConfigRepository: repo,
      settingsDb: settingsDb,
    );

    when(() => repo.saveConfig(any())).thenAnswer((_) async {});
    when(
      () => repo.deleteConfig(any(), fromSync: any(named: 'fromSync')),
    ).thenAnswer((_) async {});
    when(
      () => repo.getConfigById(
        any(),
        includeDeleted: any(named: 'includeDeleted'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => repo.getConfigsByType(
        any(),
        includeDeleted: any(named: 'includeDeleted'),
      ),
    ).thenAnswer((_) async => const <AiConfig>[]);
  });

  Future<void> seedLedger(List<String> identities) {
    return settingsDb.saveSettingsItem(
      legacySeedTombstonesSettingsKey,
      jsonEncode(identities),
    );
  }

  group('SeedTombstoneMigration', () {
    // The old releases hard-deleted the config and recorded the identity in a
    // settings row, so after upgrading the row is absent — indistinguishable
    // from "never seeded" — and seeding would recreate it.
    test('writes a tombstone row for a deleted bundled profile', () async {
      await seedLedger([
        TestSeedTombstoneIdentities.profile(profileGeminiFlashId),
      ]);

      await migration.migrate();

      final saved =
          verify(() => repo.saveConfig(captureAny())).captured.single
              as AiConfigInferenceProfile;
      expect(saved.id, profileGeminiFlashId);
      expect(saved.deletedAt, isNotNull);
    });

    test('reconstructs a deleted known model from the catalog', () async {
      const providerId = 'provider-1';
      final known = knownModelsByProvider[InferenceProviderType.gemini]!.first;
      when(
        () => repo.getConfigById(
          providerId,
          includeDeleted: any(named: 'includeDeleted'),
        ),
      ).thenAnswer(
        (_) async => AiConfig.inferenceProvider(
          id: providerId,
          baseUrl: 'https://example.com',
          apiKey: 'key',
          name: 'Gemini',
          createdAt: DateTime(2026),
          inferenceProviderType: InferenceProviderType.gemini,
        ),
      );
      await seedLedger([
        TestSeedTombstoneIdentities.model(
          inferenceProviderId: providerId,
          providerModelId: known.providerModelId,
        ),
      ]);

      await migration.migrate();

      final saved =
          verify(() => repo.saveConfig(captureAny())).captured.single
              as AiConfigModel;
      expect(saved.providerModelId, known.providerModelId);
      expect(saved.inferenceProviderId, providerId);
      expect(saved.deletedAt, isNotNull);
    });

    // The row can be back — a re-seed the ledger failed to prevent, or a sync
    // from a peer. Stamp it rather than writing a duplicate.
    test('stamps a live row instead of writing a second one', () async {
      when(
        () => repo.getConfigById(
          profileGeminiFlashId,
          includeDeleted: any(named: 'includeDeleted'),
        ),
      ).thenAnswer(
        (_) async => ProfileSeedingService.defaultProfiles.firstWhere(
          (profile) => profile.id == profileGeminiFlashId,
        ),
      );
      await seedLedger([
        TestSeedTombstoneIdentities.profile(profileGeminiFlashId),
      ]);

      await migration.migrate();

      verify(() => repo.deleteConfig(profileGeminiFlashId)).called(1);
      verifyNever(() => repo.saveConfig(any()));
    });

    test('leaves an already-deleted row alone', () async {
      when(
        () => repo.getConfigById(
          profileGeminiFlashId,
          includeDeleted: any(named: 'includeDeleted'),
        ),
      ).thenAnswer(
        (_) async => ProfileSeedingService.defaultProfiles
            .firstWhere((profile) => profile.id == profileGeminiFlashId)
            .copyWith(deletedAt: DateTime(2026, 7, 25)),
      );
      await seedLedger([
        TestSeedTombstoneIdentities.profile(profileGeminiFlashId),
      ]);

      await migration.migrate();

      verifyNever(() => repo.saveConfig(any()));
      verifyNever(
        () => repo.deleteConfig(any(), fromSync: any(named: 'fromSync')),
      );
    });

    // Same two states as the profile path, for models: the row can be back
    // (re-seed or peer sync) and must be stamped rather than duplicated.
    test('stamps a live model row instead of writing a second one', () async {
      const providerId = 'provider-1';
      final known = knownModelsByProvider[InferenceProviderType.gemini]!.first;
      final liveRow = known.toAiConfigModel(
        id: 'row-uuid',
        inferenceProviderId: providerId,
      );
      when(
        () => repo.getConfigsByType(
          AiConfigType.model,
          includeDeleted: any(named: 'includeDeleted'),
        ),
      ).thenAnswer((_) async => [liveRow]);
      await seedLedger([
        TestSeedTombstoneIdentities.model(
          inferenceProviderId: providerId,
          providerModelId: known.providerModelId,
        ),
      ]);

      await migration.migrate();

      verify(() => repo.deleteConfig('row-uuid')).called(1);
      verifyNever(() => repo.saveConfig(any()));
    });

    test('leaves an already-deleted model row alone', () async {
      const providerId = 'provider-1';
      final known = knownModelsByProvider[InferenceProviderType.gemini]!.first;
      final deletedRow = known
          .toAiConfigModel(id: 'row-uuid', inferenceProviderId: providerId)
          .copyWith(deletedAt: DateTime(2026, 7, 25));
      when(
        () => repo.getConfigsByType(
          AiConfigType.model,
          includeDeleted: any(named: 'includeDeleted'),
        ),
      ).thenAnswer((_) async => [deletedRow]);
      await seedLedger([
        TestSeedTombstoneIdentities.model(
          inferenceProviderId: providerId,
          providerModelId: known.providerModelId,
        ),
      ]);

      await migration.migrate();

      verifyNever(() => repo.saveConfig(any()));
      verifyNever(
        () => repo.deleteConfig(any(), fromSync: any(named: 'fromSync')),
      );
      // The lookup must ask for deleted rows, or the migration reads a
      // tombstoned row as absent and writes a duplicate.
      verify(
        () => repo.getConfigsByType(
          AiConfigType.model,
          includeDeleted: true,
        ),
      ).called(1);
    });

    // FTUE writes UUID row ids while backfill writes deterministic ones, so
    // sync can leave two live rows for the same provider and provider-native
    // model. Tombstoning one and clearing the ledger would leave the duplicate
    // visible and syncing.
    test('tombstones every duplicate row for one legacy identity', () async {
      const providerId = 'provider-1';
      final known = knownModelsByProvider[InferenceProviderType.gemini]!.first;
      AiConfigModel row(String id) => known.toAiConfigModel(
        id: id,
        inferenceProviderId: providerId,
      );
      when(
        () => repo.getConfigsByType(
          AiConfigType.model,
          includeDeleted: any(named: 'includeDeleted'),
        ),
      ).thenAnswer((_) async => [row('uuid-row'), row('deterministic-row')]);
      await seedLedger([
        TestSeedTombstoneIdentities.model(
          inferenceProviderId: providerId,
          providerModelId: known.providerModelId,
        ),
      ]);

      await migration.migrate();

      final deleted = verify(
        () => repo.deleteConfig(captureAny()),
      ).captured.cast<String>();
      expect(deleted, containsAll(['uuid-row', 'deterministic-row']));
    });

    // Clearing the key is what stops this running on every launch.
    test('clears the legacy key when done', () async {
      await seedLedger([
        TestSeedTombstoneIdentities.profile(profileGeminiFlashId),
      ]);

      await migration.migrate();

      expect(
        await settingsDb.itemByKey(legacySeedTombstonesSettingsKey),
        isNull,
      );
    });

    test('does nothing when there is no ledger', () async {
      await migration.migrate();

      verifyNever(() => repo.saveConfig(any()));
      expect(
        await settingsDb.itemByKey(legacySeedTombstonesSettingsKey),
        isNull,
      );
    });

    // A corrupt value must not wedge startup, and an identity naming something
    // no longer in the catalog is dropped rather than blocking the rest.
    test('survives an unreadable ledger', () async {
      await settingsDb.saveSettingsItem(
        legacySeedTombstonesSettingsKey,
        'not json',
      );

      await migration.migrate();

      verifyNever(() => repo.saveConfig(any()));
    });

    test('drops identities it cannot reconstruct but keeps the rest', () async {
      await seedLedger([
        'profile:no-such-profile',
        'model:missing-provider:some-model',
        'garbage',
        TestSeedTombstoneIdentities.profile(profileGeminiProId),
      ]);

      await migration.migrate();

      final saved = verify(
        () => repo.saveConfig(captureAny()),
      ).captured.cast<AiConfigInferenceProfile>();
      expect(saved.map((profile) => profile.id), [profileGeminiProId]);
    });
  });
}
