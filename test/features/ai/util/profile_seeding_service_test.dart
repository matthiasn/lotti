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
    test('seeds all 6 default profiles when none exist', () async {
      await service.seedDefaults();

      verify(() => mockRepo.saveConfig(any())).called(6);
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

      // Only 5 profiles should be saved (Gemini Flash skipped).
      verify(() => mockRepo.saveConfig(any())).called(5);
    });

    test('is fully idempotent — no saves when all exist', () async {
      // All profiles already exist.
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
      ]) {
        verify(() => mockRepo.getConfigById(id)).called(1);
      }
    });

    test('local profile is marked as desktopOnly', () async {
      final capturedConfigs = <AiConfig>[];
      when(() => mockRepo.saveConfig(captureAny(that: isA<AiConfig>())))
          .thenAnswer((invocation) async {
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
      expect(localProfile.thinkingModelId, 'qwen3:8b');
    });

    test('all default profiles are marked as isDefault', () async {
      final capturedConfigs = <AiConfig>[];
      when(() => mockRepo.saveConfig(captureAny(that: isA<AiConfig>())))
          .thenAnswer((invocation) async {
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
