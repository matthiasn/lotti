import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:mocktail/mocktail.dart';

import '../test_utils.dart';

List<AiConfig> _meliousDefaultModelRows({
  bool includeLegacyFlux = false,
  bool includeGlmAndVoxtral = false,
}) {
  return [
    if (includeGlmAndVoxtral) ...[
      AiTestDataFactory.createTestModel(
        id: 'model-melious-glm-5-2',
        providerModelId: meliousGlm52ModelId,
      ),
      AiTestDataFactory.createTestModel(
        id: 'model-melious-voxtral',
        providerModelId: meliousVoxtralSmall24B2507ModelId,
      ),
    ],
    AiTestDataFactory.createTestModel(
      id: 'model-melious-mistral',
      providerModelId: meliousMistralSmall4119BInstructModelId,
    ),
    AiTestDataFactory.createTestModel(
      id: 'model-melious-qwen',
      providerModelId: meliousQwen35122BA10BModelId,
    ),
    AiTestDataFactory.createTestModel(
      id: 'model-melious-deepseek',
      providerModelId: meliousDeepseekV4ProModelId,
    ),
    AiTestDataFactory.createTestModel(
      id: 'model-melious-whisper',
      providerModelId: meliousWhisperLargeV3ModelId,
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
        expect(upgraded.transcriptionModelId, 'model-melious-whisper');
        expect(upgraded.imageGenerationModelId, 'model-melious-flux-klein-9b');
      },
    );

    test(
      'moves untouched Melious profiles from Whisper Turbo to Whisper v3',
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
              imageGenerationModelId: meliousFlux2Klein9BModelId,
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
        expect(upgraded.transcriptionModelId, 'model-melious-whisper');
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
        expect(upgraded.transcriptionModelId, 'model-melious-whisper');
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
        expect(upgraded.transcriptionModelId, 'model-melious-whisper');
        expect(upgraded.imageGenerationModelId, 'model-melious-flux-klein-9b');
      },
    );

    test(
      'heals dangling default-profile slots after the owning provider was '
      'deleted and a fresh one recreated the model rows',
      () async {
        // The provider that owned the profile's model rows was deleted
        // (cascade-deleting the rows); a reconnected provider recreated the
        // catalog under new row IDs. Every slot must be re-pointed.
        when(
          () => mockRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) async => _meliousDefaultModelRows(includeGlmAndVoxtral: true),
        );
        when(
          () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer(
          (_) async => [
            AiConfig.inferenceProfile(
              id: profileMeliousId,
              name: 'Melious.ai',
              thinkingModelId: 'dead-provider_mistral_small_4_119b_instruct',
              thinkingHighEndModelId: 'dead-provider_deepseek_v4_pro',
              imageRecognitionModelId:
                  'dead-provider_mistral_small_4_119b_instruct',
              transcriptionModelId: 'dead-provider_whisper_large_v3',
              imageGenerationModelId: 'dead-provider_flux_2_klein_9b',
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
        final healed = captured.single as AiConfigInferenceProfile;

        expect(healed.id, profileMeliousId);
        expect(healed.thinkingModelId, 'model-melious-qwen');
        expect(healed.imageRecognitionModelId, 'model-melious-mistral');
        // Dangling slots heal straight to the *current* seed defaults.
        expect(healed.thinkingHighEndModelId, 'model-melious-glm-5-2');
        expect(healed.transcriptionModelId, 'model-melious-voxtral');
        expect(healed.imageGenerationModelId, 'model-melious-flux-klein-9b');
      },
    );

    test(
      'never heals user-authored slots that still resolve to a live row',
      () async {
        final rows = [
          ..._meliousDefaultModelRows(includeGlmAndVoxtral: true),
          AiTestDataFactory.createTestModel(
            id: 'my-custom-row',
            providerModelId: 'my-custom-model',
          ),
        ];
        when(
          () => mockRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => rows);
        when(
          () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer(
          (_) async => [
            AiConfig.inferenceProfile(
              id: profileMeliousId,
              name: 'Melious.ai',
              thinkingModelId: 'my-custom-row',
              thinkingHighEndModelId: 'model-melious-glm-5-2',
              imageRecognitionModelId: 'model-melious-mistral',
              transcriptionModelId: 'model-melious-voxtral',
              imageGenerationModelId: 'model-melious-flux-klein-9b',
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

        expect(upgraded.thinkingModelId, 'my-custom-row');
        expect(upgraded.thinkingHighEndModelId, 'model-melious-glm-5-2');
        expect(upgraded.transcriptionModelId, 'model-melious-voxtral');
        expect(upgraded.seedGeneration, meliousProfileSeedGeneration);
      },
    );

    test(
      'leaves catalog-known provider-native slots alone when their provider '
      'has no model rows yet',
      () async {
        // Pending, not dangling: the OpenAI profile's provider-native IDs
        // resolve at runtime once an OpenAI provider exists. Healing them
        // would be a pointless rewrite of identical or equivalent values.
        when(
          () => mockRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) async => _meliousDefaultModelRows(includeGlmAndVoxtral: true),
        );
        when(
          () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer(
          (_) async => [
            AiConfig.inferenceProfile(
              id: profileOpenAiId,
              name: 'OpenAI',
              thinkingModelId: 'gpt-5.2',
              imageRecognitionModelId: 'gpt-5-nano',
              transcriptionModelId: 'gpt-4o-transcribe',
              imageGenerationModelId: 'gpt-image-1.5',
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

        verifyNever(() => mockRepo.saveConfig(any()));
      },
    );

    test(
      'does not heal dangling slots on profiles that are not seeded defaults',
      () async {
        when(
          () => mockRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) async => _meliousDefaultModelRows(includeGlmAndVoxtral: true),
        );
        when(
          () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer(
          (_) async => [
            AiConfig.inferenceProfile(
              id: 'my-own-profile-001',
              name: 'My Profile',
              thinkingModelId: 'dead-provider_some_model',
              createdAt: DateTime(2026),
            ),
          ],
        );

        await service.upgradeExisting();

        verifyNever(() => mockRepo.saveConfig(any()));
      },
    );

    test(
      'moves untouched Melious profiles to Qwen thinking, GLM 5.2 high-end, '
      'and Voxtral transcription once their model rows exist',
      () async {
        when(
          () => mockRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) async => _meliousDefaultModelRows(includeGlmAndVoxtral: true),
        );
        when(
          () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer(
          (_) async => [
            AiConfig.inferenceProfile(
              id: profileMeliousId,
              name: 'Melious.ai',
              thinkingModelId: 'model-melious-mistral',
              thinkingHighEndModelId: 'model-melious-deepseek',
              imageRecognitionModelId: 'model-melious-mistral',
              transcriptionModelId: 'model-melious-whisper',
              imageGenerationModelId: 'model-melious-flux-klein-9b',
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
        expect(upgraded.thinkingModelId, 'model-melious-qwen');
        expect(upgraded.thinkingHighEndModelId, 'model-melious-glm-5-2');
        expect(upgraded.transcriptionModelId, 'model-melious-voxtral');
        // The text-only Qwen default does not replace Mistral vision.
        expect(upgraded.imageRecognitionModelId, 'model-melious-mistral');
        expect(upgraded.imageGenerationModelId, 'model-melious-flux-klein-9b');
        expect(upgraded.seedGeneration, meliousProfileSeedGeneration);
      },
    );

    test(
      'chains a legacy Melious profile through Qwen, Whisper, Flux, GLM, and '
      'Voxtral in a single upgrade pass',
      () async {
        when(
          () => mockRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) async => _meliousDefaultModelRows(includeGlmAndVoxtral: true),
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
        expect(upgraded.thinkingModelId, 'model-melious-qwen');
        expect(upgraded.thinkingHighEndModelId, 'model-melious-glm-5-2');
        expect(upgraded.transcriptionModelId, 'model-melious-voxtral');
        expect(upgraded.imageGenerationModelId, 'model-melious-flux-klein-9b');
        expect(upgraded.seedGeneration, meliousProfileSeedGeneration);
      },
    );

    test(
      'moves untouched Melious thinking to Qwen while GLM and Voxtral rows '
      'are missing',
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
              thinkingModelId: 'model-melious-mistral',
              thinkingHighEndModelId: 'model-melious-deepseek',
              imageRecognitionModelId: 'model-melious-mistral',
              transcriptionModelId: 'model-melious-whisper',
              imageGenerationModelId: 'model-melious-flux-klein-9b',
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

        expect(upgraded.thinkingModelId, 'model-melious-qwen');
        expect(upgraded.thinkingHighEndModelId, 'model-melious-deepseek');
        expect(upgraded.transcriptionModelId, 'model-melious-whisper');
      },
    );

    test('leaves the current Melious defaults unchanged', () async {
      when(
        () => mockRepo.getConfigsByType(AiConfigType.model),
      ).thenAnswer(
        (_) async => _meliousDefaultModelRows(includeGlmAndVoxtral: true),
      );
      when(
        () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
      ).thenAnswer(
        (_) async => [
          AiConfig.inferenceProfile(
            id: profileMeliousId,
            name: 'Melious.ai',
            thinkingModelId: 'model-melious-qwen',
            thinkingHighEndModelId: 'model-melious-glm-5-2',
            imageRecognitionModelId: 'model-melious-mistral',
            transcriptionModelId: 'model-melious-voxtral',
            imageGenerationModelId: 'model-melious-flux-klein-9b',
            seedGeneration: meliousProfileSeedGeneration,
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

      verifyNever(() => mockRepo.saveConfig(any()));
    });

    test(
      'preserves a deliberate Mistral selection after Melious migration',
      () async {
        when(
          () => mockRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) async => _meliousDefaultModelRows(includeGlmAndVoxtral: true),
        );
        when(
          () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer(
          (_) async => [
            AiConfig.inferenceProfile(
              id: profileMeliousId,
              name: 'Melious.ai',
              thinkingModelId: 'model-melious-mistral',
              thinkingHighEndModelId: 'model-melious-glm-5-2',
              imageRecognitionModelId: 'model-melious-mistral',
              transcriptionModelId: 'model-melious-voxtral',
              imageGenerationModelId: 'model-melious-flux-klein-9b',
              seedGeneration: meliousProfileSeedGeneration,
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

        verifyNever(() => mockRepo.saveConfig(any()));
      },
    );

    test(
      'does not use a foreign Qwen row for the Melious migration',
      () async {
        final meliousRows =
            _meliousDefaultModelRows(
              includeGlmAndVoxtral: true,
            ).whereType<AiConfigModel>().where(
              (model) => model.providerModelId != meliousQwen35122BA10BModelId,
            );
        when(
          () => mockRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) async => [
            ...meliousRows,
            AiTestDataFactory.createTestModel(
              id: 'foreign-qwen',
              inferenceProviderId: 'foreign-provider',
              providerModelId: meliousQwen35122BA10BModelId,
            ),
          ],
        );
        when(
          () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer(
          (_) async => [
            AiConfig.inferenceProfile(
              id: profileMeliousId,
              name: 'Melious.ai',
              thinkingModelId: 'model-melious-mistral',
              thinkingHighEndModelId: 'model-melious-deepseek',
              imageRecognitionModelId: 'model-melious-mistral',
              transcriptionModelId: 'model-melious-whisper',
              imageGenerationModelId: 'model-melious-flux-klein-9b',
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

        expect(upgraded.thinkingModelId, 'model-melious-mistral');
        expect(upgraded.thinkingHighEndModelId, 'model-melious-glm-5-2');
        expect(upgraded.transcriptionModelId, 'model-melious-voxtral');
        expect(upgraded.seedGeneration, 0);
      },
    );

    test(
      'preserves a user-edited Melious high-end slot during the GLM and '
      'Voxtral upgrade',
      () async {
        when(
          () => mockRepo.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) async => [
            ..._meliousDefaultModelRows(includeGlmAndVoxtral: true),
            AiTestDataFactory.createTestModel(
              id: 'my-custom-row',
              providerModelId: 'my-custom-model',
            ),
          ],
        );
        when(
          () => mockRepo.getConfigsByType(AiConfigType.inferenceProfile),
        ).thenAnswer(
          (_) async => [
            AiConfig.inferenceProfile(
              id: profileMeliousId,
              name: 'Melious.ai',
              thinkingModelId: 'model-melious-mistral',
              // The user pointed the high-end slot at their own live model
              // row — the profile no longer counts as untouched, so neither
              // slot moves (and the resolvable slot is not "dangling").
              thinkingHighEndModelId: 'my-custom-row',
              imageRecognitionModelId: 'model-melious-mistral',
              transcriptionModelId: 'model-melious-whisper',
              imageGenerationModelId: 'model-melious-flux-klein-9b',
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

        expect(upgraded.thinkingModelId, 'model-melious-mistral');
        expect(upgraded.thinkingHighEndModelId, 'my-custom-row');
        expect(upgraded.transcriptionModelId, 'model-melious-whisper');
        expect(upgraded.seedGeneration, meliousProfileSeedGeneration);
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

        final captured = verify(
          () => mockRepo.saveConfig(captureAny(that: isA<AiConfig>())),
        ).captured;
        final upgraded = captured.single as AiConfigInferenceProfile;

        expect(upgraded.name, 'My Melious Profile');
        expect(
          upgraded.thinkingModelId,
          meliousMistralSmall4119BInstructModelId,
        );
        expect(upgraded.imageGenerationModelId, isNull);
        expect(upgraded.seedGeneration, meliousProfileSeedGeneration);
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
