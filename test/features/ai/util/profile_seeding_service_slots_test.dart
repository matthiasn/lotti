import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:mocktail/mocktail.dart';

import '../test_utils.dart';

List<AiConfig> _meliousDefaultModelRows({bool includeLegacyFlux = false}) {
  return [
    AiTestDataFactory.createTestModel(
      id: 'model-melious-mistral',
      providerModelId: meliousMistralSmall4119BInstructModelId,
    ),
    AiTestDataFactory.createTestModel(
      id: 'model-melious-deepseek',
      providerModelId: meliousDeepseekV4ProModelId,
    ),
    AiTestDataFactory.createTestModel(
      id: 'model-melious-whisper-turbo',
      providerModelId: meliousWhisperLargeV3TurboModelId,
    ),
    if (includeLegacyFlux)
      AiTestDataFactory.createTestModel(
        id: 'model-melious-flux-dev',
        providerModelId: 'black-forest-labs/flux-2-dev',
        outputModalities: const [Modality.image],
      ),
    AiTestDataFactory.createTestModel(
      id: 'model-melious-flux-klein-9b',
      providerModelId: meliousFlux2Klein9BModelId,
      outputModalities: const [Modality.image],
    ),
  ];
}

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

  group('ProfileSeedingService.upgradeExisting', () {
    test('upgrades default profiles with empty skillAssignments', () async {
      // Existing profile has empty skill assignments but has the model
      // slots required by the template's skill assignments, and a model
      // row exists for those slots (skills are only re-enabled when the
      // slot resolves to a real configured model).
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
            imageRecognitionModelId: 'models/gemini-3-flash-preview',
            transcriptionModelId: 'models/gemini-3-flash-preview',
            isDefault: true,
            createdAt: DateTime(2026),
          ),
        ],
      );

      await service.upgradeExisting();

      // Should save the upgraded profile with skill assignments.
      final captured = verify(
        () => mockRepo.saveConfig(captureAny(that: isA<AiConfig>())),
      ).captured;

      expect(captured, hasLength(1));
      final upgraded = captured.first as AiConfigInferenceProfile;
      expect(upgraded.id, profileGeminiFlashId);
      expect(upgraded.skillAssignments, isNotEmpty);
      expect(
        upgraded.skillAssignments.every((a) => a.automate),
        isTrue,
        reason: 'All seeded assignments should have automate: true',
      );
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

    test('filters skill assignments by slot availability', () async {
      // Profile has transcription but no image recognition model.
      // Template has both transcription and image analysis skills.
      // Only transcription skill should survive filtering.
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
            // No imageRecognitionModelId — image analysis skill should
            // be filtered out.
            isDefault: true,
            createdAt: DateTime(2026),
          ),
        ],
      );

      await service.upgradeExisting();

      final captured = verify(
        () => mockRepo.saveConfig(captureAny(that: isA<AiConfig>())),
      ).captured;

      expect(captured, hasLength(1));
      final upgraded = captured.first as AiConfigInferenceProfile;
      expect(upgraded.id, profileGeminiFlashId);
      // Should only contain the transcription skill, since image
      // recognition model slot is missing.
      final skillIds = upgraded.skillAssignments.map((a) => a.skillId).toSet();
      expect(skillIds, contains(skillTranscribeContextId));
      expect(skillIds, isNot(contains(skillImageAnalysisContextId)));
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
        when(
          () => mockRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
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

        // Slots stay legacy (ambiguous), but skill backfill still runs:
        // the runtime resolver can walk the candidate rows.
        final captured = verify(
          () => mockRepo.saveConfig(captureAny(that: isA<AiConfig>())),
        ).captured;
        final upgraded = captured.single as AiConfigInferenceProfile;
        expect(
          upgraded.thinkingModelId,
          'models/gemini-3-flash-preview',
        );
        expect(
          upgraded.transcriptionModelId,
          'models/gemini-3-flash-preview',
        );
        expect(
          upgraded.skillAssignments.map((a) => a.skillId),
          contains(skillTranscribeContextId),
        );
      },
    );

    test(
      'migrates untouched legacy Local Power seed values to oMLX',
      () async {
        when(
          () => mockRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) async => [
            AiTestDataFactory.createTestModel(
              id: 'model-omlx-qwen36',
              providerModelId: omlxRecommendedMultimodalModelId,
            ),
          ],
        );
        when(
          () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer(
          (_) async => [
            AiConfig.inferenceProfile(
              id: profileLocalPowerId,
              name: 'Local Power (Ollama)',
              thinkingModelId: 'qwen3.6:35b-a3b-coding-nvfp4',
              imageRecognitionModelId: 'qwen3.5:27b',
              desktopOnly: true,
              createdAt: DateTime(2026),
            ),
          ],
        );

        await service.upgradeExisting();

        final captured = verify(
          () => mockRepo.saveConfig(captureAny(that: isA<AiConfig>())),
        ).captured;
        final upgraded = captured.single as AiConfigInferenceProfile;

        expect(upgraded.id, profileLocalPowerId);
        expect(upgraded.name, 'Local Power (oMLX)');
        expect(upgraded.thinkingModelId, 'model-omlx-qwen36');
        expect(upgraded.imageRecognitionModelId, 'model-omlx-qwen36');
        expect(upgraded.desktopOnly, isTrue);
        expect(upgraded.isDefault, isFalse);
      },
    );

    test(
      'migrates previously resolved legacy Local Power slots to oMLX',
      () async {
        when(
          () => mockRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) async => [
            AiTestDataFactory.createTestModel(
              id: 'model-old-qwen36',
              providerModelId: 'qwen3.6:35b-a3b-coding-nvfp4',
            ),
            AiTestDataFactory.createTestModel(
              id: 'model-old-qwen35',
              providerModelId: 'qwen3.5:27b',
            ),
            AiTestDataFactory.createTestModel(
              id: 'model-omlx-qwen36',
              providerModelId: omlxRecommendedMultimodalModelId,
            ),
          ],
        );
        when(
          () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer(
          (_) async => [
            AiConfig.inferenceProfile(
              id: profileLocalPowerId,
              name: 'Local Power (Ollama)',
              thinkingModelId: 'model-old-qwen36',
              imageRecognitionModelId: 'model-old-qwen35',
              desktopOnly: true,
              createdAt: DateTime(2026),
            ),
          ],
        );

        await service.upgradeExisting();

        final captured = verify(
          () => mockRepo.saveConfig(captureAny(that: isA<AiConfig>())),
        ).captured;
        final upgraded = captured.single as AiConfigInferenceProfile;

        expect(upgraded.name, 'Local Power (oMLX)');
        expect(upgraded.thinkingModelId, 'model-omlx-qwen36');
        expect(upgraded.imageRecognitionModelId, 'model-omlx-qwen36');
      },
    );

    test(
      'adds oMLX Whisper Turbo to untouched local oMLX profiles',
      () async {
        when(
          () => mockRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) async => [
            AiTestDataFactory.createTestModel(
              id: 'model-omlx-qwen36',
              providerModelId: omlxRecommendedMultimodalModelId,
            ),
            AiTestDataFactory.createTestModel(
              id: 'model-omlx-gemma4',
              providerModelId: omlxGemma426BA4BItQatMlx4BitModelId,
            ),
            AiTestDataFactory.createTestModel(
              id: 'model-omlx-whisper-turbo',
              providerModelId: omlxWhisperLargeV3TurboModelId,
            ),
          ],
        );
        when(
          () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer(
          (_) async => [
            AiConfig.inferenceProfile(
              id: profileLocalPowerId,
              name: 'Local Power (oMLX)',
              thinkingModelId: 'model-omlx-qwen36',
              imageRecognitionModelId: 'model-omlx-qwen36',
              desktopOnly: true,
              createdAt: DateTime(2026),
            ),
            AiConfig.inferenceProfile(
              id: profileLocalGemmaOmlxId,
              name: 'Local Gemma 4 (oMLX)',
              thinkingModelId: 'model-omlx-gemma4',
              imageRecognitionModelId: 'model-omlx-gemma4',
              desktopOnly: true,
              createdAt: DateTime(2026),
            ),
          ],
        );

        await service.upgradeExisting();

        final captured = verify(
          () => mockRepo.saveConfig(captureAny(that: isA<AiConfig>())),
        ).captured;
        expect(captured, hasLength(2));

        for (final config in captured) {
          final upgraded = config as AiConfigInferenceProfile;
          expect(
            upgraded.transcriptionModelId,
            'model-omlx-whisper-turbo',
          );
          expect(
            upgraded.skillAssignments.map((a) => a.skillId),
            containsAll([
              skillTranscribeContextId,
              skillImageAnalysisContextId,
            ]),
          );
        }
      },
    );

    test(
      'does not enable oMLX transcription skill without Whisper model row',
      () async {
        when(
          () => mockRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) async => [
            AiTestDataFactory.createTestModel(
              id: 'model-omlx-qwen36',
              providerModelId: omlxRecommendedMultimodalModelId,
            ),
          ],
        );
        when(
          () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer(
          (_) async => [
            AiConfig.inferenceProfile(
              id: profileLocalPowerId,
              name: 'Local Power (oMLX)',
              thinkingModelId: 'model-omlx-qwen36',
              imageRecognitionModelId: 'model-omlx-qwen36',
              desktopOnly: true,
              createdAt: DateTime(2026),
            ),
          ],
        );

        await service.upgradeExisting();

        final captured = verify(
          () => mockRepo.saveConfig(captureAny(that: isA<AiConfig>())),
        ).captured;
        final upgraded = captured.single as AiConfigInferenceProfile;
        final skillIds = upgraded.skillAssignments.map((a) => a.skillId);

        expect(
          upgraded.transcriptionModelId,
          omlxWhisperLargeV3TurboModelId,
        );
        expect(skillIds, contains(skillImageAnalysisContextId));
        expect(skillIds, isNot(contains(skillTranscribeContextId)));
      },
    );

    test(
      'adds Flux 2 Klein 9B image generation to untouched Melious profiles',
      () async {
        when(
          () => mockRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => _meliousDefaultModelRows());
        when(
          () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer(
          (_) async => [
            AiConfig.inferenceProfile(
              id: profileMeliousId,
              name: 'Melious.ai',
              thinkingModelId: meliousMistralSmall4119BInstructModelId,
              thinkingHighEndModelId: meliousDeepseekV4ProModelId,
              imageRecognitionModelId: meliousMistralSmall4119BInstructModelId,
              transcriptionModelId: meliousWhisperLargeV3TurboModelId,
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
          ],
        );

        await service.upgradeExisting();

        final captured = verify(
          () => mockRepo.saveConfig(captureAny(that: isA<AiConfig>())),
        ).captured;
        final upgraded = captured.single as AiConfigInferenceProfile;

        expect(upgraded.id, profileMeliousId);
        expect(upgraded.imageGenerationModelId, 'model-melious-flux-klein-9b');
      },
    );

    test(
      'moves untouched Melious profiles from legacy Flux provider ID to Klein',
      () async {
        when(
          () => mockRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => _meliousDefaultModelRows());
        when(
          () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer(
          (_) async => [
            AiConfig.inferenceProfile(
              id: profileMeliousId,
              name: 'Melious.ai',
              thinkingModelId: meliousMistralSmall4119BInstructModelId,
              thinkingHighEndModelId: meliousDeepseekV4ProModelId,
              imageRecognitionModelId: meliousMistralSmall4119BInstructModelId,
              transcriptionModelId: meliousWhisperLargeV3TurboModelId,
              imageGenerationModelId: 'black-forest-labs/flux-2-dev',
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

        expect(upgraded.id, profileMeliousId);
        expect(upgraded.imageGenerationModelId, 'model-melious-flux-klein-9b');
      },
    );

    test(
      'moves untouched Melious profiles from legacy Flux model row to Klein',
      () async {
        when(
          () => mockRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) async => _meliousDefaultModelRows(includeLegacyFlux: true),
        );
        when(
          () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer(
          (_) async => [
            AiConfig.inferenceProfile(
              id: profileMeliousId,
              name: 'Melious.ai',
              thinkingModelId: meliousMistralSmall4119BInstructModelId,
              thinkingHighEndModelId: meliousDeepseekV4ProModelId,
              imageRecognitionModelId: meliousMistralSmall4119BInstructModelId,
              transcriptionModelId: meliousWhisperLargeV3TurboModelId,
              imageGenerationModelId: 'model-melious-flux-dev',
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

        expect(upgraded.id, profileMeliousId);
        expect(upgraded.imageGenerationModelId, 'model-melious-flux-klein-9b');
      },
    );

    test(
      'preserves user-edited Melious profiles during Flux image upgrade',
      () async {
        when(
          () => mockRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) async => [
            AiTestDataFactory.createTestModel(
              id: 'model-melious-flux-klein-9b',
              providerModelId: meliousFlux2Klein9BModelId,
              outputModalities: const [Modality.image],
            ),
          ],
        );
        when(
          () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer(
          (_) async => [
            AiConfig.inferenceProfile(
              id: profileMeliousId,
              name: 'My Melious Profile',
              thinkingModelId: meliousMistralSmall4119BInstructModelId,
              thinkingHighEndModelId: meliousDeepseekV4ProModelId,
              imageRecognitionModelId: meliousMistralSmall4119BInstructModelId,
              transcriptionModelId: meliousWhisperLargeV3TurboModelId,
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
      'preserves user-edited Local Power profiles during oMLX migration',
      () async {
        when(
          () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer(
          (_) async => [
            AiConfig.inferenceProfile(
              id: profileLocalPowerId,
              name: 'Local Power (Ollama)',
              thinkingModelId: 'custom-local-model',
              imageRecognitionModelId: 'qwen3.5:27b',
              desktopOnly: true,
              createdAt: DateTime(2026),
            ),
          ],
        );

        await service.upgradeExisting();

        verifyNever(() => mockRepo.saveConfig(any()));
      },
    );

    test('does nothing when profiles do not exist', () async {
      await service.upgradeExisting();

      verifyNever(() => mockRepo.saveConfig(any()));
    });
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
