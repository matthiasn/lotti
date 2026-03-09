import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockAiConfigRepository mockRepo;
  late ProfileSeedingService service;

  setUpAll(() {
    registerFallbackValue(
      AiConfig.inferenceProfile(
        id: 'fallback',
        name: 'Fallback',
        thinkingModelId: 'fallback-model',
        createdAt: DateTime(2024),
      ),
    );
  });

  setUp(() {
    mockRepo = MockAiConfigRepository();
    service = ProfileSeedingService(aiConfigRepository: mockRepo);

    // Default: all profiles missing (return null for any ID lookup).
    when(() => mockRepo.getConfigById(any())).thenAnswer((_) async => null);
    when(() => mockRepo.saveConfig(any())).thenAnswer((_) async {});
  });

  group('ProfileSeedingService', () {
    test('seeds all 7 default profiles when none exist', () async {
      await service.seedDefaults();

      verify(() => mockRepo.saveConfig(any())).called(7);
    });

    test('skips profiles that already exist', () async {
      // Gemini Flash already exists.
      when(() => mockRepo.getConfigById(profileGeminiFlashId)).thenAnswer(
        (_) async => AiConfig.inferenceProfile(
          id: profileGeminiFlashId,
          name: 'Gemini Flash',
          thinkingModelId: 'models/gemini-3-flash-preview',
          createdAt: DateTime(2026),
        ),
      );

      await service.seedDefaults();

      // Only 6 profiles should be saved (Gemini Flash skipped).
      verify(() => mockRepo.saveConfig(any())).called(6);
    });

    test('is fully idempotent — no saves when all exist and match', () async {
      // All profiles already exist with non-default flag, so no drift check.
      when(() => mockRepo.getConfigById(any())).thenAnswer(
        (_) async => AiConfig.inferenceProfile(
          id: 'existing',
          name: 'Existing',
          thinkingModelId: 'some-model',
          createdAt: DateTime(2026),
        ),
      );

      await service.seedDefaults();

      verifyNever(() => mockRepo.saveConfig(any()));
    });

    test('updates existing default profile when model IDs drift', () async {
      // Local profile exists but has old model ID.
      when(() => mockRepo.getConfigById(profileLocalId)).thenAnswer(
        (_) async => AiConfig.inferenceProfile(
          id: profileLocalId,
          name: 'Local (Ollama)',
          thinkingModelId: 'qwen3:8b', // old model
          imageRecognitionModelId: 'gemma3:4b',
          isDefault: true,
          desktopOnly: true,
          createdAt: DateTime(2026),
        ),
      );

      await service.seedDefaults();

      // Should save the updated local profile (+ 6 new ones).
      verify(() => mockRepo.saveConfig(any())).called(7);
    });

    test(
      'does not update user-modified default profile even if drifted',
      () async {
        // Profile exists with old model but updatedAt is set (user edited it).
        when(() => mockRepo.getConfigById(profileLocalId)).thenAnswer(
          (_) async => AiConfig.inferenceProfile(
            id: profileLocalId,
            name: 'Local (Ollama)',
            thinkingModelId: 'qwen3:8b', // old model, drifted
            imageRecognitionModelId: 'gemma3:4b',
            isDefault: true,
            desktopOnly: true,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026, 3), // user edited
          ),
        );

        await service.seedDefaults();

        // 6 new profiles saved (local skipped — user modified).
        verify(() => mockRepo.saveConfig(any())).called(6);
      },
    );

    test('does not update non-default profiles even if drifted', () async {
      // Profile exists with different model but isDefault is false.
      when(() => mockRepo.getConfigById(profileLocalId)).thenAnswer(
        (_) async => AiConfig.inferenceProfile(
          id: profileLocalId,
          name: 'Local (Ollama)',
          thinkingModelId: 'old-model',
          createdAt: DateTime(2026),
          // isDefault defaults to false
        ),
      );

      await service.seedDefaults();

      // 6 new profiles saved (local skipped because it exists and isn't default).
      verify(() => mockRepo.saveConfig(any())).called(6);
    });

    test('seeds profiles with correct IDs', () async {
      await service.seedDefaults();

      // Verify each well-known ID was checked.
      for (final id in [
        profileGeminiFlashId,
        profileGeminiProId,
        profileOpenAiId,
        profileMistralEuId,
        profileAlibabaId,
        profileLocalId,
        profileLocalPowerId,
      ]) {
        verify(() => mockRepo.getConfigById(id)).called(1);
      }
    });

    test('does not update default profile when all slots match', () async {
      // Local profile exists with matching model IDs.
      when(() => mockRepo.getConfigById(profileLocalId)).thenAnswer(
        (_) async => AiConfig.inferenceProfile(
          id: profileLocalId,
          name: 'Local (Ollama)',
          thinkingModelId: 'qwen3.5:9b',
          imageRecognitionModelId: 'gemma3:4b',
          isDefault: true,
          desktopOnly: true,
          createdAt: DateTime(2026),
        ),
      );

      await service.seedDefaults();

      // 6 new profiles saved (local skipped — no drift).
      verify(() => mockRepo.saveConfig(any())).called(6);
    });

    test('detects drift on imageRecognitionModelId', () async {
      when(() => mockRepo.getConfigById(profileLocalId)).thenAnswer(
        (_) async => AiConfig.inferenceProfile(
          id: profileLocalId,
          name: 'Local (Ollama)',
          thinkingModelId: 'qwen3.5:9b',
          imageRecognitionModelId: 'old-vision-model', // drifted
          isDefault: true,
          desktopOnly: true,
          createdAt: DateTime(2026),
        ),
      );

      await service.seedDefaults();

      // 7 saves: 6 new + 1 updated local profile.
      verify(() => mockRepo.saveConfig(any())).called(7);
    });

    test('local power profile has correct configuration', () async {
      final capturedConfigs = <AiConfig>[];
      when(
        () => mockRepo.saveConfig(captureAny(that: isA<AiConfig>())),
      ).thenAnswer((invocation) async {
        capturedConfigs.add(
          invocation.positionalArguments.first as AiConfig,
        );
      });

      await service.seedDefaults();

      final powerProfile = capturedConfigs
          .whereType<AiConfigInferenceProfile>()
          .where((p) => p.id == profileLocalPowerId)
          .first;

      expect(powerProfile.desktopOnly, isTrue);
      expect(powerProfile.name, 'Local Power (Ollama)');
      expect(powerProfile.thinkingModelId, 'qwen3.5:27b');
      expect(powerProfile.imageRecognitionModelId, 'gemma3:12b');
      expect(powerProfile.isDefault, isTrue);
    });

    test('local profile is marked as desktopOnly', () async {
      final capturedConfigs = <AiConfig>[];
      when(
        () => mockRepo.saveConfig(captureAny(that: isA<AiConfig>())),
      ).thenAnswer((invocation) async {
        capturedConfigs.add(
          invocation.positionalArguments.first as AiConfig,
        );
      });

      await service.seedDefaults();

      final localProfile = capturedConfigs
          .whereType<AiConfigInferenceProfile>()
          .where((p) => p.id == profileLocalId)
          .first;

      expect(localProfile.desktopOnly, isTrue);
      expect(localProfile.name, 'Local (Ollama)');
      expect(localProfile.thinkingModelId, 'qwen3.5:9b');
    });

    test('all default profiles are marked as isDefault', () async {
      final capturedConfigs = <AiConfig>[];
      when(
        () => mockRepo.saveConfig(captureAny(that: isA<AiConfig>())),
      ).thenAnswer((invocation) async {
        capturedConfigs.add(
          invocation.positionalArguments.first as AiConfig,
        );
      });

      await service.seedDefaults();

      for (final config in capturedConfigs) {
        final profile = config as AiConfigInferenceProfile;
        expect(profile.isDefault, isTrue, reason: '${profile.name} isDefault');
      }
    });
  });
}
