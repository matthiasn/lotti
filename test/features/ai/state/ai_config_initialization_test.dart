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
    when(() => repo.deleteConfig(any())).thenAnswer((_) async {});
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
    test('seeds no profiles on first run when no providers exist', () async {
      when(() => repo.getConfigById(any())).thenAnswer((_) async => null);
      // No providers configured -> backfill saves no models and the
      // usable-provider gate keeps every default profile unseeded.
      when(() => repo.getConfigsByType(any())).thenAnswer((_) async => []);

      final container = createContainer();
      await container.read(aiConfigInitializationProvider.future);

      verifyNever(() => repo.saveConfig(any()));
      verifyNever(() => repo.deleteConfig(any()));
    });

    test(
      'seeds only the profiles of an existing usable provider and '
      'backfills its known models',
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
        when(
          () => repo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer((_) async => []);

        final container = createContainer();
        await container.read(aiConfigInitializationProvider.future);

        final saved = savedConfigs();
        final seededProfiles = saved
            .whereType<AiConfigInferenceProfile>()
            .toList();
        final backfilledModels = saved.whereType<AiConfigModel>().toList();

        // The default anthropic test provider gates in exactly the Anthropic
        // profile; the rest of the catalog stays unseeded.
        expect(
          seededProfiles.map((p) => p.id),
          [profileAnthropicId],
        );
        expect(backfilledModels, isNotEmpty);
        expect(
          backfilledModels.every((m) => m.inferenceProviderId == provider.id),
          isTrue,
        );
      },
    );

    test('skips seeding when the gated profile already exists', () async {
      // The Anthropic profile ID already resolves to an existing config.
      when(() => repo.getConfigById(any())).thenAnswer((invocation) async {
        final id = invocation.positionalArguments.first as String;
        return AiTestDataFactory.createTestProfile(id: id);
      });
      when(() => repo.getConfigsByType(any())).thenAnswer((_) async => []);
      when(
        () => repo.getConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) async => [AiTestDataFactory.createTestProvider()]);

      final container = createContainer();
      await container.read(aiConfigInitializationProvider.future);

      // No profile is written — seed-on-create leaves the existing row alone
      // (model backfill still writes the provider's known models).
      expect(savedConfigs().whereType<AiConfigInferenceProfile>(), isEmpty);
    });

    test(
      'removes an orphaned untouched default seed when its provider '
      'type has no usable provider',
      () async {
        when(() => repo.getConfigById(any())).thenAnswer((_) async => null);
        when(() => repo.getConfigsByType(any())).thenAnswer((_) async => []);
        final meliousSeed = ProfileSeedingService.defaultProfiles.firstWhere(
          (p) => p.id == profileMeliousId,
        );
        when(
          () => repo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer((_) async => [meliousSeed]);

        final container = createContainer();
        await container.read(aiConfigInitializationProvider.future);

        verify(() => repo.deleteConfig(profileMeliousId)).called(1);
      },
    );

    test('completes normally and attempts every phase when provider reads '
        'throw', () async {
      when(() => repo.getConfigById(any())).thenAnswer((_) async => null);
      when(() => repo.getConfigsByType(any())).thenAnswer((_) async => []);
      // Every initialization phase reads the inference-provider configs.
      // Make that shared dependency throw so the test can verify that each
      // guarded phase is still attempted.
      when(
        () => repo.getConfigsByType(AiConfigType.inferenceProvider),
      ).thenThrow(Exception('db unavailable'));

      final container = createContainer();

      // The provider future resolves without surfacing the errors
      // (they are caught and logged step by step).
      await expectLater(
        container.read(aiConfigInitializationProvider.future),
        completes,
      );

      verifyNever(() => repo.saveConfig(any()));

      // Backfill, seeding, upgrade, and orphan cleanup each reached their
      // provider read instead of an earlier failure aborting initialization.
      verify(
        () => repo.getConfigsByType(AiConfigType.inferenceProvider),
      ).called(4);
    });

    test('completes normally and still seeds profiles when the profile '
        'upgrade throws', () async {
      when(() => repo.getConfigById(any())).thenAnswer((_) async => null);
      when(() => repo.getConfigsByType(any())).thenAnswer((_) async => []);
      when(
        () => repo.getConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) async => [AiTestDataFactory.createTestProvider()]);
      // upgradeExisting() and the orphan cleanup read inference profiles.
      when(
        () => repo.getConfigsByType(AiConfigType.inferenceProfile),
      ).thenThrow(Exception('db unavailable'));

      final container = createContainer();

      await expectLater(
        container.read(aiConfigInitializationProvider.future),
        completes,
      );

      // Backfill and gated seeding both completed before the upgrade failure.
      expect(
        savedConfigs().whereType<AiConfigInferenceProfile>().map((p) => p.id),
        [profileAnthropicId],
      );
    });
  });
}
