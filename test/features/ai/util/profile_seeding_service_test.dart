import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/ai/util/skill_seeding_service.dart';
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
    test('seeds all 9 default profiles when none exist', () async {
      await service.seedDefaults();

      verify(() => mockRepo.saveConfig(any())).called(9);
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

      // Only 8 profiles should be saved (Gemini Flash skipped).
      verify(() => mockRepo.saveConfig(any())).called(8);
    });

    test('is fully idempotent — no saves when all exist and match', () async {
      // Return a profile that matches the seed target for each ID so no
      // drift is detected. Use updatedAt != null to simulate user ownership
      // which also blocks updates.
      when(() => mockRepo.getConfigById(any())).thenAnswer(
        (_) async => AiConfig.inferenceProfile(
          id: 'existing',
          name: 'Existing',
          thinkingModelId: 'some-model',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026, 2), // user-edited → never overwritten
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
          imageRecognitionModelId: 'qwen3.5:9b', // matches current
          isDefault: true,
          desktopOnly: true,
          createdAt: DateTime(2026),
        ),
      );

      await service.seedDefaults();

      // Should save the updated local profile (+ 8 new ones).
      verify(() => mockRepo.saveConfig(any())).called(9);
    });

    test(
      'updates default profile even if updatedAt is set',
      () async {
        // Default profiles are always reconciled when drifted, regardless
        // of updatedAt — since saveConfig always sets updatedAt, the old
        // updatedAt == null gate was unreachable.
        when(() => mockRepo.getConfigById(profileLocalId)).thenAnswer(
          (_) async => AiConfig.inferenceProfile(
            id: profileLocalId,
            name: 'Local (Ollama)',
            thinkingModelId: 'qwen3:8b', // old model, drifted
            imageRecognitionModelId: 'qwen3.5:9b',
            isDefault: true,
            desktopOnly: true,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026, 3),
          ),
        );

        await service.seedDefaults();

        // 8 new profiles + 1 updated (drifted local profile).
        verify(() => mockRepo.saveConfig(any())).called(9);
      },
    );

    test('does not update non-default profile even if drifted', () async {
      // Non-default profiles are user-created and never touched by seeding.
      when(() => mockRepo.getConfigById(profileLocalId)).thenAnswer(
        (_) async => AiConfig.inferenceProfile(
          id: profileLocalId,
          name: 'Local (Ollama)',
          thinkingModelId: 'qwen3.5:9b',
          imageRecognitionModelId: 'qwen3.5:9b',
          desktopOnly: true,
          createdAt: DateTime(2026),
          // isDefault defaults to false — seed target has isDefault true,
          // but existing is not default so it should not be updated.
        ),
      );

      await service.seedDefaults();

      // 8 new profiles only (local not updated — not isDefault).
      verify(() => mockRepo.saveConfig(any())).called(8);
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
        profileLocalGemmaId,
        profileLocalGemmaPowerId,
      ]) {
        verify(() => mockRepo.getConfigById(id)).called(1);
      }
    });

    test('does not update default profile when all slots match', () async {
      // Local profile exists with matching model IDs and skill assignments.
      when(() => mockRepo.getConfigById(profileLocalId)).thenAnswer(
        (_) async => AiConfig.inferenceProfile(
          id: profileLocalId,
          name: 'Local (Ollama)',
          thinkingModelId: 'qwen3.5:9b',
          imageRecognitionModelId: 'qwen3.5:9b',
          skillAssignments: const [
            SkillAssignment(
              skillId: skillImageAnalysisContextId,
              automate: true,
            ),
          ],
          isDefault: true,
          desktopOnly: true,
          createdAt: DateTime(2026),
        ),
      );

      await service.seedDefaults();

      // 8 new profiles saved (local skipped — no drift).
      verify(() => mockRepo.saveConfig(any())).called(8);
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

      // 9 saves: 8 new + 1 updated local profile.
      verify(() => mockRepo.saveConfig(any())).called(9);
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
      expect(powerProfile.imageRecognitionModelId, 'qwen3.5:27b');
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

  group('ProfileSeedingService.upgradeExisting', () {
    test('upgrades default profiles with empty skillAssignments', () async {
      // Existing profile has empty skill assignments but has the model
      // slots required by the template's skill assignments.
      when(() => mockRepo.getConfigById(any())).thenAnswer((_) async => null);
      when(
        () => mockRepo.getConfigById(profileGeminiFlashId),
      ).thenAnswer(
        (_) async => AiConfig.inferenceProfile(
          id: profileGeminiFlashId,
          name: 'Gemini Flash',
          thinkingModelId: 'models/gemini-3-flash-preview',
          imageRecognitionModelId: 'models/gemini-3-flash-preview',
          transcriptionModelId: 'models/gemini-3-flash-preview',
          isDefault: true,
          createdAt: DateTime(2026),
        ),
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
      when(() => mockRepo.getConfigById(any())).thenAnswer((_) async => null);
      when(
        () => mockRepo.getConfigById(profileGeminiFlashId),
      ).thenAnswer(
        (_) async => AiConfig.inferenceProfile(
          id: profileGeminiFlashId,
          name: 'Gemini Flash',
          thinkingModelId: 'models/gemini-3-flash-preview',
          isDefault: true,
          skillAssignments: [
            const SkillAssignment(skillId: 'existing-skill', automate: true),
          ],
          createdAt: DateTime(2026),
        ),
      );

      await service.upgradeExisting();

      // Should not save — profile already has assignments.
      verifyNever(() => mockRepo.saveConfig(any()));
    });

    test('skips non-default profiles', () async {
      when(() => mockRepo.getConfigById(any())).thenAnswer((_) async => null);
      when(
        () => mockRepo.getConfigById(profileGeminiFlashId),
      ).thenAnswer(
        (_) async => AiConfig.inferenceProfile(
          id: profileGeminiFlashId,
          name: 'Gemini Flash',
          thinkingModelId: 'models/gemini-3-flash-preview',
          createdAt: DateTime(2026),
          // isDefault defaults to false.
        ),
      );

      await service.upgradeExisting();

      verifyNever(() => mockRepo.saveConfig(any()));
    });

    test('filters skill assignments by slot availability', () async {
      // Profile has transcription but no image recognition model.
      // Template has both transcription and image analysis skills.
      // Only transcription skill should survive filtering.
      when(() => mockRepo.getConfigById(any())).thenAnswer((_) async => null);
      when(
        () => mockRepo.getConfigById(profileGeminiFlashId),
      ).thenAnswer(
        (_) async => AiConfig.inferenceProfile(
          id: profileGeminiFlashId,
          name: 'Gemini Flash',
          thinkingModelId: 'models/gemini-3-flash-preview',
          transcriptionModelId: 'models/gemini-3-flash-preview',
          // No imageRecognitionModelId — image analysis skill should
          // be filtered out.
          isDefault: true,
          createdAt: DateTime(2026),
        ),
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

    test('does nothing when profiles do not exist', () async {
      when(() => mockRepo.getConfigById(any())).thenAnswer((_) async => null);

      await service.upgradeExisting();

      verifyNever(() => mockRepo.saveConfig(any()));
    });
  });
}
