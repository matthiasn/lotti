import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:mocktail/mocktail.dart';

import '../test_utils.dart';

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
    when(
      () => mockRepo.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => const <AiConfig>[]);
    when(
      () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
    ).thenAnswer((_) async => const <AiConfig>[]);
    when(() => mockRepo.saveConfig(any())).thenAnswer((_) async {});
  });

  group('ProfileSeedingService', () {
    test('seeds all 10 default profiles when none exist', () async {
      await service.seedDefaults();

      verify(() => mockRepo.saveConfig(any())).called(10);
    });

    test('skips profiles that already exist', () async {
      // Gemini Flash already exists with all fields matching the seed target.
      when(() => mockRepo.getConfigById(profileGeminiFlashId)).thenAnswer(
        (_) async => AiConfig.inferenceProfile(
          id: profileGeminiFlashId,
          name: 'Gemini Flash',
          thinkingModelId: 'models/gemini-3-flash-preview',
          imageRecognitionModelId: 'models/gemini-3-flash-preview',
          transcriptionModelId: 'models/gemini-3-flash-preview',
          imageGenerationModelId: 'models/gemini-3-pro-image-preview',
          skillAssignments: const [
            SkillAssignment(
              skillId: skillTranscribeContextId,
              automate: true,
            ),
            SkillAssignment(
              skillId: skillImageAnalysisContextId,
              automate: true,
            ),
          ],
          isDefault: true,
          createdAt: DateTime(2026),
        ),
      );

      await service.seedDefaults();

      // Only 9 profiles should be saved (Gemini Flash skipped).
      verify(() => mockRepo.saveConfig(any())).called(9);
    });

    test(
      'is fully idempotent — no saves when all profiles already exist',
      () async {
        // Any non-null result from getConfigById short-circuits the seed.
        // The seeder is strictly seed-on-create; existing rows are never
        // touched regardless of their contents.
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
      },
    );

    test(
      'preserves user-edited model IDs on existing default profile — '
      'seed-on-create only, never overwrites',
      () async {
        // Local profile exists with a user-swapped thinking model that
        // does NOT match the seed target. Pre-change, this would have
        // been clobbered back to the bundled default on every restart.
        when(() => mockRepo.getConfigById(profileLocalId)).thenAnswer(
          (_) async => AiConfig.inferenceProfile(
            id: profileLocalId,
            name: 'Local (Ollama)',
            thinkingModelId: 'qwen3:8b', // user-edited, drifts from seed
            imageRecognitionModelId: 'qwen3.5:9b',
            isDefault: true,
            desktopOnly: true,
            createdAt: DateTime(2026),
          ),
        );

        await service.seedDefaults();

        // Only the 9 missing profiles get written. The existing Local
        // profile is left untouched — user edit survives.
        verify(() => mockRepo.saveConfig(any())).called(9);
        verifyNever(
          () => mockRepo.saveConfig(
            any(
              that: isA<AiConfigInferenceProfile>().having(
                (p) => p.id,
                'id',
                profileLocalId,
              ),
            ),
          ),
        );
      },
    );

    test(
      'preserves user-toggled isDefault flag on existing profile',
      () async {
        // User flipped isDefault off on the Local profile. Seed target
        // has isDefault: true — must not be re-asserted.
        when(() => mockRepo.getConfigById(profileLocalId)).thenAnswer(
          (_) async => AiConfig.inferenceProfile(
            id: profileLocalId,
            name: 'Local (Ollama)',
            thinkingModelId: 'qwen3.5:9b',
            imageRecognitionModelId: 'qwen3.5:9b',
            desktopOnly: true,
            createdAt: DateTime(2026),
            // isDefault defaults to false.
          ),
        );

        await service.seedDefaults();

        // 9 new profiles only — the Local profile is not re-asserted to
        // isDefault: true.
        verify(() => mockRepo.saveConfig(any())).called(9);
      },
    );

    test('seeds profiles with correct IDs', () async {
      await service.seedDefaults();

      // Verify each well-known ID was checked.
      for (final id in [
        profileGeminiFlashId,
        profileGeminiProId,
        profileOpenAiId,
        profileMistralEuId,
        profileAlibabaId,
        profileAnthropicId,
        profileLocalId,
        profileLocalPowerId,
        profileLocalGemmaId,
        profileLocalGemmaPowerId,
      ]) {
        verify(() => mockRepo.getConfigById(id)).called(1);
      }
    });

    test(
      'does not touch existing default profile, drift or no drift',
      () async {
        // Existing profile drifts on imageRecognitionModelId — pre-change
        // this would have been reconciled. Now: left alone.
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

        // 9 new profiles only — Local profile preserved as-is.
        verify(() => mockRepo.saveConfig(any())).called(9);
      },
    );

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
      expect(powerProfile.name, 'Local Power (oMLX)');
      expect(powerProfile.thinkingModelId, omlxRecommendedMultimodalModelId);
      expect(
        powerProfile.imageRecognitionModelId,
        omlxRecommendedMultimodalModelId,
      );
      expect(powerProfile.isDefault, isFalse);
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

    test(
      'all default profiles are marked as isDefault except opt-in ones',
      () async {
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
          if (profile.id == profileLocalPowerId ||
              profile.id == profileLocalGemmaPowerId) {
            // Power profiles are opt-in (require large models).
            expect(
              profile.isDefault,
              isFalse,
              reason: '${profile.name} should be opt-in',
            );
          } else {
            expect(
              profile.isDefault,
              isTrue,
              reason: '${profile.name} isDefault',
            );
          }
        }
      },
    );

    test('all default profiles have skillAssignments', () async {
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
        // Power profiles have no skill assignments (opt-in profiles).
        if (profile.id == profileLocalPowerId) continue;
        if (profile.id == profileLocalGemmaPowerId) continue;
        expect(
          profile.skillAssignments,
          isNotEmpty,
          reason: '${profile.name} skillAssignments',
        );
      }
    });

    test(
      'Gemini Flash has transcription and image analysis assignments',
      () async {
        final capturedConfigs = <AiConfig>[];
        when(
          () => mockRepo.saveConfig(captureAny(that: isA<AiConfig>())),
        ).thenAnswer((invocation) async {
          capturedConfigs.add(
            invocation.positionalArguments.first as AiConfig,
          );
        });

        await service.seedDefaults();

        final geminiFlash = capturedConfigs
            .whereType<AiConfigInferenceProfile>()
            .firstWhere((p) => p.id == profileGeminiFlashId);

        final skillIds = geminiFlash.skillAssignments
            .map((a) => a.skillId)
            .toSet();
        expect(skillIds, contains(skillTranscribeContextId));
        expect(skillIds, contains(skillImageAnalysisContextId));
      },
    );

    test('Local (Ollama) has only image analysis assignment', () async {
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
          .firstWhere((p) => p.id == profileLocalId);

      expect(localProfile.skillAssignments, hasLength(1));
      expect(
        localProfile.skillAssignments.first.skillId,
        skillImageAnalysisContextId,
      );
    });
  });

  group('hasSlotForSkillType (slot matrix)', () {
    // Model rows backing every slot value used below, so the matrix tests
    // slot *presence* while the resolution-specific cases live in the
    // 'ProfileSeedingService.hasSlotForSkillType' group.
    final slotModels = [
      for (final id in ['thinking-model', 'tm', 'irm', 'igm'])
        AiTestDataFactory.createTestModel(id: id, providerModelId: 'w-$id'),
    ];

    AiConfigInferenceProfile buildProfile({
      String? transcriptionModelId,
      String? imageRecognitionModelId,
      String? imageGenerationModelId,
    }) =>
        AiConfig.inferenceProfile(
              id: 'profile-slots',
              name: 'Slots',
              thinkingModelId: 'thinking-model',
              transcriptionModelId: transcriptionModelId,
              imageRecognitionModelId: imageRecognitionModelId,
              imageGenerationModelId: imageGenerationModelId,
              createdAt: DateTime(2026),
            )
            as AiConfigInferenceProfile;

    test('every skill type maps to exactly its required model slot', () {
      final empty = buildProfile();
      final full = buildProfile(
        transcriptionModelId: 'tm',
        imageRecognitionModelId: 'irm',
        imageGenerationModelId: 'igm',
      );

      const expectedWithEmpty = {
        SkillType.transcription: false,
        SkillType.imageAnalysis: false,
        SkillType.imageGeneration: false,
        // Thinking-model-backed skills are always available.
        SkillType.promptGeneration: true,
        SkillType.imagePromptGeneration: true,
      };
      for (final skillType in SkillType.values) {
        expect(
          ProfileSeedingService.hasSlotForSkillType(
            empty,
            skillType,
            slotModels,
          ),
          expectedWithEmpty[skillType],
          reason: 'empty profile, $skillType',
        );
        expect(
          ProfileSeedingService.hasSlotForSkillType(
            full,
            skillType,
            slotModels,
          ),
          isTrue,
          reason: 'fully-slotted profile, $skillType',
        );
      }

      // Each slot gates only its own skill type.
      expect(
        ProfileSeedingService.hasSlotForSkillType(
          buildProfile(imageGenerationModelId: 'igm'),
          SkillType.imageGeneration,
          slotModels,
        ),
        isTrue,
      );
      expect(
        ProfileSeedingService.hasSlotForSkillType(
          buildProfile(imageGenerationModelId: 'igm'),
          SkillType.transcription,
          slotModels,
        ),
        isFalse,
      );
    });
  });
}
