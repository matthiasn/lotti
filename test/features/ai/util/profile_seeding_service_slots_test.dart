import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
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

  setUp(() async {
    mockRepo = MockAiConfigRepository();
    service = ProfileSeedingService(
      aiConfigRepository: mockRepo,
      tombstoneStore: await createTombstoneStore(),
    );

    // Default: all profiles missing (return null for any ID lookup).
    when(() => mockRepo.getConfigById(any())).thenAnswer((_) async => null);
    when(
      () => mockRepo.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => const <AiConfig>[]);
    when(
      () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
    ).thenAnswer((_) async => const <AiConfig>[]);
    when(
      () => mockRepo.getConfigsByType(AiConfigType.inferenceProvider),
    ).thenAnswer(
      (_) async => [
        AiTestDataFactory.createTestProvider(
          type: InferenceProviderType.melious,
        ),
      ],
    );
    when(() => mockRepo.saveConfig(any())).thenAnswer((_) async {});
  });

  group('ProfileSeedingService.upgradeExisting', () {
    // Regression guard: `upgradeExisting` used to re-add the template's
    // `automate: true` assignments whenever a default profile's list was
    // empty — so clearing every assignment, the obvious way to say "stop
    // running things automatically", was exactly what restored them on the
    // next launch.
    test('does not restore skill assignments the user cleared', () async {
      when(() => mockRepo.getConfigsByType(AiConfigType.model)).thenAnswer(
        (_) async => [
          AiTestDataFactory.createTestModel(
            id: 'model-gemini-flash',
            providerModelId: 'models/gemini-3-flash-preview',
          ),
        ],
      );
      when(
        () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
      ).thenAnswer(
        (_) async => [
          AiConfig.inferenceProfile(
            id: profileGeminiFlashId,
            name: 'Gemini Flash',
            // Slots resolve, so the only thing that could change this profile
            // is the assignment backfill.
            thinkingModelId: 'model-gemini-flash',
            imageRecognitionModelId: 'model-gemini-flash',
            transcriptionModelId: 'model-gemini-flash',
            isDefault: true,
            createdAt: DateTime(2026),
          ),
        ],
      );

      await service.upgradeExisting();

      // Nothing to upgrade: the profile is written back unchanged, or not at
      // all. Either way it must not regain automated assignments.
      verifyNever(() => mockRepo.saveConfig(any()));
    });
    test('skips profiles that already have skillAssignments', () async {
      when(
        () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
      ).thenAnswer(
        (_) async => [
          AiConfig.inferenceProfile(
            id: profileGeminiFlashId,
            name: 'Gemini Flash',
            thinkingModelId: 'models/gemini-3-flash-preview',
            isDefault: true,
            skillAssignments: [
              const SkillAssignment(skillId: 'existing-skill', automate: true),
            ],
            createdAt: DateTime(2026),
          ),
        ],
      );

      await service.upgradeExisting();

      // Should not save — profile already has assignments.
      verifyNever(() => mockRepo.saveConfig(any()));
    });

    test('skips non-default profiles', () async {
      when(
        () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
      ).thenAnswer(
        (_) async => [
          AiConfig.inferenceProfile(
            id: profileGeminiFlashId,
            name: 'Gemini Flash',
            thinkingModelId: 'models/gemini-3-flash-preview',
            createdAt: DateTime(2026),
            // isDefault defaults to false.
          ),
        ],
      );

      await service.upgradeExisting();

      verifyNever(() => mockRepo.saveConfig(any()));
    });

    test(
      'does not re-enable skills when slots have no backing model row',
      () async {
        // Slots are non-null but point at models that are not configured
        // (empty model table). Backfilling skills would auto-enable broken
        // automation, so the profile must be left untouched.
        when(
          () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer(
          (_) async => [
            AiConfig.inferenceProfile(
              id: profileGeminiFlashId,
              name: 'Gemini Flash',
              thinkingModelId: 'models/gemini-3-flash-preview',
              imageRecognitionModelId: 'models/gemini-3-flash-preview',
              transcriptionModelId: 'models/gemini-3-flash-preview',
              isDefault: true,
              createdAt: DateTime(2026),
            ),
          ],
        );

        await service.upgradeExisting();

        verifyNever(() => mockRepo.saveConfig(any()));
      },
    );

    test(
      'rewrites legacy provider-native slots to model row ids on upgrade',
      () async {
        when(
          () => mockRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) async => [
            AiTestDataFactory.createTestModel(
              id: 'model-gemini-flash',
              providerModelId: 'models/gemini-3-flash-preview',
            ),
          ],
        );
        when(
          () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer(
          (_) async => [
            AiConfig.inferenceProfile(
              id: profileGeminiFlashId,
              name: 'Gemini Flash',
              thinkingModelId: 'models/gemini-3-flash-preview',
              transcriptionModelId: 'models/gemini-3-flash-preview',
              isDefault: true,
              createdAt: DateTime(2026),
            ),
          ],
        );

        await service.upgradeExisting();

        final captured = verify(
          () => mockRepo.saveConfig(captureAny(that: isA<AiConfig>())),
        ).captured;
        final upgraded = captured.single as AiConfigInferenceProfile;
        expect(upgraded.thinkingModelId, 'model-gemini-flash');
        expect(upgraded.transcriptionModelId, 'model-gemini-flash');
      },
    );

    test(
      'keeps ambiguous legacy slot values unchanged on upgrade',
      () async {
        // Two model rows share the same providerModelId — rewriting would
        // pick an arbitrary row, so the legacy value must be preserved.
        when(() => mockRepo.getConfigsByType(AiConfigType.model)).thenAnswer(
          (_) async => [
            AiTestDataFactory.createTestModel(
              id: 'model-gemini-flash-a',
              providerModelId: 'models/gemini-3-flash-preview',
            ),
            AiTestDataFactory.createTestModel(
              id: 'model-gemini-flash-b',
              providerModelId: 'models/gemini-3-flash-preview',
            ),
          ],
        );
        when(
          () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer(
          (_) async => [
            AiConfig.inferenceProfile(
              id: profileGeminiFlashId,
              name: 'Gemini Flash',
              thinkingModelId: 'models/gemini-3-flash-preview',
              transcriptionModelId: 'models/gemini-3-flash-preview',
              isDefault: true,
              createdAt: DateTime(2026),
            ),
          ],
        );

        await service.upgradeExisting();

        // The ambiguous slots are left alone, so the profile is unchanged and
        // nothing is written.
        verifyNever(() => mockRepo.saveConfig(any()));
      },
    );
  });

  group('ProfileSeedingService.hasSlotForSkillType', () {
    // The bundled default templates only carry transcription and
    // image-analysis assignments, so the remaining skill types are pinned
    // down directly: each one must require its slot to resolve to a real
    // configured model row.
    final models = [
      AiTestDataFactory.createTestModel(
        id: 'row-1',
        providerModelId: 'wire-1',
      ),
    ];

    AiConfigInferenceProfile profileWith({
      String thinkingModelId = 'missing',
      String? imageGenerationModelId,
    }) {
      return AiConfig.inferenceProfile(
            id: 'p',
            name: 'P',
            thinkingModelId: thinkingModelId,
            imageGenerationModelId: imageGenerationModelId,
            createdAt: DateTime(2026),
          )
          as AiConfigInferenceProfile;
    }

    test('imageGeneration requires a resolvable image-generation slot', () {
      expect(
        ProfileSeedingService.hasSlotForSkillType(
          profileWith(imageGenerationModelId: 'row-1'),
          SkillType.imageGeneration,
          models,
        ),
        isTrue,
      );
      expect(
        ProfileSeedingService.hasSlotForSkillType(
          profileWith(imageGenerationModelId: 'unknown'),
          SkillType.imageGeneration,
          models,
        ),
        isFalse,
      );
      expect(
        ProfileSeedingService.hasSlotForSkillType(
          profileWith(),
          SkillType.imageGeneration,
          models,
        ),
        isFalse,
      );
    });

    test(
      'prompt-generation skill types require a resolvable thinking slot, '
      'accepting both row ids and legacy providerModelIds',
      () {
        for (final skillType in [
          SkillType.promptGeneration,
          SkillType.imagePromptGeneration,
        ]) {
          expect(
            ProfileSeedingService.hasSlotForSkillType(
              profileWith(thinkingModelId: 'row-1'),
              skillType,
              models,
            ),
            isTrue,
            reason: '$skillType with exact row id',
          );
          expect(
            ProfileSeedingService.hasSlotForSkillType(
              profileWith(thinkingModelId: 'wire-1'),
              skillType,
              models,
            ),
            isTrue,
            reason: '$skillType with legacy providerModelId',
          );
          expect(
            ProfileSeedingService.hasSlotForSkillType(
              profileWith(),
              skillType,
              models,
            ),
            isFalse,
            reason: '$skillType with unresolvable slot',
          );
        }
      },
    );
  });
}
