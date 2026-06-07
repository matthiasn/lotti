import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/ai_config_initialization.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAiConfigRepository repo;

  setUp(() {
    repo = MockAiConfigRepository();
    when(() => repo.saveConfig(any())).thenAnswer((_) async {});
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// All saved configs captured from `saveConfig` calls.
  List<AiConfig> savedConfigs() {
    final captured = verify(() => repo.saveConfig(captureAny())).captured;
    return captured.cast<AiConfig>();
  }

  group('aiConfigInitialization', () {
    test('seeds every default profile on first run and queries providers '
        'for model backfill', () async {
      // First run: nothing exists yet, so every profile is missing.
      when(() => repo.getConfigById(any())).thenAnswer((_) async => null);
      // No providers configured -> backfill saves no models.
      when(() => repo.getConfigsByType(any())).thenAnswer((_) async => []);

      final container = createContainer();
      await container.read(aiConfigInitializationProvider.future);

      // Each default profile was looked up by ID...
      for (final profile in ProfileSeedingService.defaultProfiles) {
        verify(() => repo.getConfigById(profile.id)).called(1);
      }

      // ...and persisted exactly once, with no extra writes (no providers
      // means model backfill creates nothing).
      final saved = savedConfigs();
      expect(saved, hasLength(ProfileSeedingService.defaultProfiles.length));
      final savedIds = saved.map((c) => c.id).toSet();
      expect(
        savedIds,
        equals(ProfileSeedingService.defaultProfiles.map((p) => p.id).toSet()),
      );

      // Backfill consulted the inference-provider configs.
      verify(
        () => repo.getConfigsByType(AiConfigType.inferenceProvider),
      ).called(1);
    });

    test('skips seeding when every default profile already exists', () async {
      // Every profile ID already resolves to an existing config.
      when(() => repo.getConfigById(any())).thenAnswer((invocation) async {
        final id = invocation.positionalArguments.first as String;
        return AiTestDataFactory.createTestProfile(id: id);
      });
      when(() => repo.getConfigsByType(any())).thenAnswer((_) async => []);

      final container = createContainer();
      await container.read(aiConfigInitializationProvider.future);

      // No profile is overwritten — saveConfig is never called by seeding,
      // and with no providers the backfill writes nothing either.
      verifyNever(() => repo.saveConfig(any()));
    });

    test(
      'backfills models for an existing provider with known models',
      () async {
        when(() => repo.getConfigById(any())).thenAnswer((_) async => null);

        final provider = AiTestDataFactory.createTestProvider();
        when(
          () => repo.getConfigsByType(AiConfigType.inferenceProvider),
        ).thenAnswer((_) async => [provider]);
        // No models exist yet -> every known model for the provider is created.
        when(
          () => repo.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => []);

        final container = createContainer();
        await container.read(aiConfigInitializationProvider.future);

        final saved = savedConfigs();
        final seededProfiles = saved
            .whereType<AiConfigInferenceProfile>()
            .length;
        final backfilledModels = saved.whereType<AiConfigModel>().toList();

        // All default profiles seeded plus newly created models, all attached
        // to the existing provider.
        expect(
          seededProfiles,
          ProfileSeedingService.defaultProfiles.length,
        );
        expect(backfilledModels, isNotEmpty);
        expect(
          backfilledModels.every((m) => m.inferenceProviderId == provider.id),
          isTrue,
        );
      },
    );

    test('completes normally and still seeds profiles when model backfill '
        'throws', () async {
      when(() => repo.getConfigById(any())).thenAnswer((_) async => null);
      when(() => repo.getConfigsByType(any())).thenAnswer((_) async => []);
      // Backfill reads inference-provider configs first; make that throw.
      // Seeding and upgrading read model/profile configs, which stay stubbed
      // above, so they must still run after the backfill failure.
      when(
        () => repo.getConfigsByType(AiConfigType.inferenceProvider),
      ).thenThrow(Exception('db unavailable'));

      final container = createContainer();

      // The provider future resolves without surfacing the backfill error
      // (it is caught and logged).
      await expectLater(
        container.read(aiConfigInitializationProvider.future),
        completes,
      );

      // Profile seeding ran to completion despite the backfill failure.
      expect(
        savedConfigs(),
        hasLength(ProfileSeedingService.defaultProfiles.length),
      );

      // The upgrade pass also ran: it reads the existing inference profiles.
      verify(
        () => repo.getConfigsByType(AiConfigType.inferenceProfile),
      ).called(1);
    });

    test('completes normally and still backfills models when profile '
        'upgrade throws', () async {
      when(() => repo.getConfigById(any())).thenAnswer((_) async => null);
      when(() => repo.getConfigsByType(any())).thenAnswer((_) async => []);
      // upgradeExisting() is the only step reading inference profiles.
      when(
        () => repo.getConfigsByType(AiConfigType.inferenceProfile),
      ).thenThrow(Exception('db unavailable'));

      final container = createContainer();

      await expectLater(
        container.read(aiConfigInitializationProvider.future),
        completes,
      );

      // Backfill and seeding both completed before the upgrade failure.
      verify(
        () => repo.getConfigsByType(AiConfigType.inferenceProvider),
      ).called(1);
      expect(
        savedConfigs(),
        hasLength(ProfileSeedingService.defaultProfiles.length),
      );
    });
  });
}
