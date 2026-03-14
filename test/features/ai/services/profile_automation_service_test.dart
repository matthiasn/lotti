import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/test_utils.dart';

void main() {
  late MockProfileAutomationResolver mockResolver;
  late MockAiConfigRepository mockAiConfig;
  late ProfileAutomationService service;

  setUp(() {
    mockResolver = MockProfileAutomationResolver();
    mockAiConfig = MockAiConfigRepository();
    service = ProfileAutomationService(
      resolver: mockResolver,
      aiConfigRepository: mockAiConfig,
    );
  });

  /// Creates a resolved profile with optional transcription/image providers.
  ResolvedProfile makeProfile({
    List<SkillAssignment> skillAssignments = const [],
    bool withTranscription = false,
    bool withImageRecognition = false,
    bool withImageGeneration = false,
  }) {
    return ResolvedProfile(
      thinkingModelId: 'models/gemini-3-flash-preview',
      thinkingProvider: testInferenceProvider(),
      transcriptionModelId: withTranscription ? 'whisper-1' : null,
      transcriptionProvider: withTranscription
          ? testInferenceProvider(id: 'p-audio')
          : null,
      imageRecognitionModelId: withImageRecognition ? 'vision-model' : null,
      imageRecognitionProvider: withImageRecognition
          ? testInferenceProvider(id: 'p-vision')
          : null,
      imageGenerationModelId: withImageGeneration ? 'image-gen' : null,
      imageGenerationProvider: withImageGeneration
          ? testInferenceProvider(id: 'p-image')
          : null,
      skillAssignments: skillAssignments,
    );
  }

  /// Creates a test skill config with type-appropriate modalities and
  /// instructions.
  AiConfigSkill makeSkill({
    String id = 'skill-001',
    String name = 'Test Skill',
    SkillType skillType = SkillType.transcription,
  }) {
    final (modalities, sysInstr, userInstr) = switch (skillType) {
      SkillType.transcription => (
        const [Modality.audio],
        'Transcribe the audio.',
        'Audio attached.',
      ),
      SkillType.imageAnalysis => (
        const [Modality.image],
        'Analyze the image.',
        'Image attached.',
      ),
      SkillType.imageGeneration => (
        const <Modality>[],
        'Generate an image.',
        'Generate based on description.',
      ),
      SkillType.promptGeneration => (
        const [Modality.audio],
        'Generate a prompt from audio.',
        'Audio attached.',
      ),
      SkillType.imagePromptGeneration => (
        const [Modality.audio],
        'Generate an image prompt from audio.',
        'Audio attached.',
      ),
    };

    return AiConfig.skill(
          id: id,
          name: name,
          skillType: skillType,
          requiredInputModalities: modalities,
          systemInstructions: sysInstr,
          userInstructions: userInstr,
          createdAt: DateTime(2024),
        )
        as AiConfigSkill;
  }

  group('ProfileAutomationService', () {
    group('tryTranscribe', () {
      test(
        'returns handled when transcription skill with automate found',
        () async {
          const assignment = SkillAssignment(
            skillId: 'skill-transcribe',
            automate: true,
          );
          final profile = makeProfile(
            skillAssignments: [assignment],
            withTranscription: true,
          );
          final skill = makeSkill(id: 'skill-transcribe');

          when(
            () => mockResolver.resolveForTask('task-1'),
          ).thenAnswer((_) async => profile);
          when(
            () => mockAiConfig.getConfigById('skill-transcribe'),
          ).thenAnswer((_) async => skill);

          final result = await service.tryTranscribe(taskId: 'task-1');

          expect(result.handled, isTrue);
          expect(result.resolvedProfile, equals(profile));
          expect(result.skill, equals(skill));
          expect(result.skillAssignment, equals(assignment));
        },
      );

      test(
        'returns not-handled when user opted out of speech recognition',
        () async {
          final result = await service.tryTranscribe(
            taskId: 'task-1',
            enableSpeechRecognition: false,
          );

          expect(result.handled, isFalse);
          verifyNever(() => mockResolver.resolveForTask(any()));
        },
      );

      test('proceeds when enableSpeechRecognition is null '
          '(profile-driven default)', () async {
        const assignment = SkillAssignment(
          skillId: 'skill-transcribe',
          automate: true,
        );
        final profile = makeProfile(
          skillAssignments: [assignment],
          withTranscription: true,
        );
        final skill = makeSkill(id: 'skill-transcribe');

        when(
          () => mockResolver.resolveForTask('task-1'),
        ).thenAnswer((_) async => profile);
        when(
          () => mockAiConfig.getConfigById('skill-transcribe'),
        ).thenAnswer((_) async => skill);

        final result = await service.tryTranscribe(
          taskId: 'task-1',
        );

        expect(result.handled, isTrue);
      });

      test('returns not-handled when no profile resolved', () async {
        when(
          () => mockResolver.resolveForTask('task-1'),
        ).thenAnswer((_) async => null);

        final result = await service.tryTranscribe(taskId: 'task-1');

        expect(result.handled, isFalse);
      });

      test('returns not-handled when no matching skill type', () async {
        const assignment = SkillAssignment(
          skillId: 'skill-image',
          automate: true,
        );
        final profile = makeProfile(
          skillAssignments: [assignment],
          withTranscription: true,
        );
        final imageSkill = makeSkill(
          id: 'skill-image',
          skillType: SkillType.imageAnalysis,
        );

        when(
          () => mockResolver.resolveForTask('task-1'),
        ).thenAnswer((_) async => profile);
        when(
          () => mockAiConfig.getConfigById('skill-image'),
        ).thenAnswer((_) async => imageSkill);

        final result = await service.tryTranscribe(taskId: 'task-1');

        expect(result.handled, isFalse);
      });

      test('skips skill assignments with automate: false', () async {
        const assignment = SkillAssignment(
          skillId: 'skill-transcribe',
          // automate defaults to false
        );
        final profile = makeProfile(
          skillAssignments: [assignment],
          withTranscription: true,
        );

        when(
          () => mockResolver.resolveForTask('task-1'),
        ).thenAnswer((_) async => profile);

        final result = await service.tryTranscribe(taskId: 'task-1');

        expect(result.handled, isFalse);
        // Should not even look up the skill config.
        verifyNever(() => mockAiConfig.getConfigById(any()));
      });

      test('skips skill when model slot not populated', () async {
        const assignment = SkillAssignment(
          skillId: 'skill-transcribe',
          automate: true,
        );
        // No transcription provider on profile.
        final profile = makeProfile(
          skillAssignments: [assignment],
        );
        final skill = makeSkill(id: 'skill-transcribe');

        when(
          () => mockResolver.resolveForTask('task-1'),
        ).thenAnswer((_) async => profile);
        when(
          () => mockAiConfig.getConfigById('skill-transcribe'),
        ).thenAnswer((_) async => skill);

        final result = await service.tryTranscribe(taskId: 'task-1');

        expect(result.handled, isFalse);
      });

      test('skips skill when config not found', () async {
        const assignment = SkillAssignment(
          skillId: 'skill-missing',
          automate: true,
        );
        final profile = makeProfile(
          skillAssignments: [assignment],
          withTranscription: true,
        );

        when(
          () => mockResolver.resolveForTask('task-1'),
        ).thenAnswer((_) async => profile);
        when(
          () => mockAiConfig.getConfigById('skill-missing'),
        ).thenAnswer((_) async => null);

        final result = await service.tryTranscribe(taskId: 'task-1');

        expect(result.handled, isFalse);
      });
    });

    group('tryAnalyzeImage', () {
      test(
        'returns handled when image analysis skill with automate found',
        () async {
          const assignment = SkillAssignment(
            skillId: 'skill-vision',
            automate: true,
          );
          final profile = makeProfile(
            skillAssignments: [assignment],
            withImageRecognition: true,
          );
          final skill = makeSkill(
            id: 'skill-vision',
            name: 'Image Analysis',
            skillType: SkillType.imageAnalysis,
          );

          when(
            () => mockResolver.resolveForTask('task-1'),
          ).thenAnswer((_) async => profile);
          when(
            () => mockAiConfig.getConfigById('skill-vision'),
          ).thenAnswer((_) async => skill);

          final result = await service.tryAnalyzeImage(taskId: 'task-1');

          expect(result.handled, isTrue);
          expect(result.skill!.skillType, SkillType.imageAnalysis);
        },
      );

      test('returns not-handled when no image recognition provider', () async {
        const assignment = SkillAssignment(
          skillId: 'skill-vision',
          automate: true,
        );
        // No image recognition provider.
        final profile = makeProfile(
          skillAssignments: [assignment],
        );
        final skill = makeSkill(
          id: 'skill-vision',
          skillType: SkillType.imageAnalysis,
        );

        when(
          () => mockResolver.resolveForTask('task-1'),
        ).thenAnswer((_) async => profile);
        when(
          () => mockAiConfig.getConfigById('skill-vision'),
        ).thenAnswer((_) async => skill);

        final result = await service.tryAnalyzeImage(taskId: 'task-1');

        expect(result.handled, isFalse);
      });
    });

    group('AutomationResult', () {
      test('notHandled has correct defaults', () {
        const result = AutomationResult.notHandled;

        expect(result.handled, isFalse);
        expect(result.resolvedProfile, isNull);
        expect(result.skill, isNull);
        expect(result.skillAssignment, isNull);
      });

      test(
        'uses first matching skill when multiple assignments exist',
        () async {
          const assignments = [
            // ignore: avoid_redundant_argument_values
            SkillAssignment(skillId: 'skill-non-auto', automate: false),
            SkillAssignment(skillId: 'skill-image', automate: true),
            SkillAssignment(skillId: 'skill-transcribe', automate: true),
          ];
          final profile = makeProfile(
            skillAssignments: assignments,
            withTranscription: true,
            withImageRecognition: true,
          );
          final transcribeSkill = makeSkill(
            id: 'skill-transcribe',
            // ignore: avoid_redundant_argument_values
            skillType: SkillType.transcription,
          );
          // skill-image is an image analysis skill, not transcription.
          final imageSkill = makeSkill(
            id: 'skill-image',
            skillType: SkillType.imageAnalysis,
          );

          when(
            () => mockResolver.resolveForTask('task-1'),
          ).thenAnswer((_) async => profile);
          when(
            () => mockAiConfig.getConfigById('skill-image'),
          ).thenAnswer((_) async => imageSkill);
          when(
            () => mockAiConfig.getConfigById('skill-transcribe'),
          ).thenAnswer((_) async => transcribeSkill);

          final result = await service.tryTranscribe(taskId: 'task-1');

          expect(result.handled, isTrue);
          expect(result.skill!.id, 'skill-transcribe');
          expect(result.skillAssignment!.skillId, 'skill-transcribe');
        },
      );
    });

    group('ambiguous profiles', () {
      test(
        'returns not-handled when multiple automated skills of same type',
        () async {
          const assignments = [
            SkillAssignment(skillId: 'skill-t1', automate: true),
            SkillAssignment(skillId: 'skill-t2', automate: true),
          ];
          final profile = makeProfile(
            skillAssignments: assignments,
            withTranscription: true,
          );
          final skill1 = makeSkill(id: 'skill-t1');
          final skill2 = makeSkill(id: 'skill-t2');

          when(
            () => mockResolver.resolveForTask('task-1'),
          ).thenAnswer((_) async => profile);
          when(
            () => mockAiConfig.getConfigById('skill-t1'),
          ).thenAnswer((_) async => skill1);
          when(
            () => mockAiConfig.getConfigById('skill-t2'),
          ).thenAnswer((_) async => skill2);

          final result = await service.tryTranscribe(taskId: 'task-1');

          expect(result.handled, isFalse);
        },
      );

      test(
        'returns handled when only one of multiple skills matches type',
        () async {
          const assignments = [
            SkillAssignment(skillId: 'skill-transcribe', automate: true),
            SkillAssignment(skillId: 'skill-image', automate: true),
          ];
          final profile = makeProfile(
            skillAssignments: assignments,
            withTranscription: true,
            withImageRecognition: true,
          );
          final transcribeSkill = makeSkill(id: 'skill-transcribe');
          final imageSkill = makeSkill(
            id: 'skill-image',
            skillType: SkillType.imageAnalysis,
          );

          when(
            () => mockResolver.resolveForTask('task-1'),
          ).thenAnswer((_) async => profile);
          when(
            () => mockAiConfig.getConfigById('skill-transcribe'),
          ).thenAnswer((_) async => transcribeSkill);
          when(
            () => mockAiConfig.getConfigById('skill-image'),
          ).thenAnswer((_) async => imageSkill);

          final result = await service.tryTranscribe(taskId: 'task-1');

          expect(result.handled, isTrue);
          expect(result.skill!.id, 'skill-transcribe');
        },
      );
    });

    group('hasAutomatedSkillType', () {
      test('returns true when skill type is available', () async {
        const assignment = SkillAssignment(
          skillId: 'skill-transcribe',
          automate: true,
        );
        final profile = makeProfile(
          skillAssignments: [assignment],
          withTranscription: true,
        );
        final skill = makeSkill(id: 'skill-transcribe');

        when(
          () => mockResolver.resolveForTask('task-1'),
        ).thenAnswer((_) async => profile);
        when(
          () => mockAiConfig.getConfigById('skill-transcribe'),
        ).thenAnswer((_) async => skill);

        final result = await service.hasAutomatedSkillType(
          taskId: 'task-1',
          skillType: SkillType.transcription,
        );

        expect(result, isTrue);
      });

      test('returns false when no profile resolved', () async {
        when(
          () => mockResolver.resolveForTask('task-1'),
        ).thenAnswer((_) async => null);

        final result = await service.hasAutomatedSkillType(
          taskId: 'task-1',
          skillType: SkillType.transcription,
        );

        expect(result, isFalse);
      });

      test('returns false for mismatched skill type', () async {
        const assignment = SkillAssignment(
          skillId: 'skill-vision',
          automate: true,
        );
        final profile = makeProfile(
          skillAssignments: [assignment],
          withImageRecognition: true,
        );
        final skill = makeSkill(
          id: 'skill-vision',
          skillType: SkillType.imageAnalysis,
        );

        when(
          () => mockResolver.resolveForTask('task-1'),
        ).thenAnswer((_) async => profile);
        when(
          () => mockAiConfig.getConfigById('skill-vision'),
        ).thenAnswer((_) async => skill);

        final result = await service.hasAutomatedSkillType(
          taskId: 'task-1',
          skillType: SkillType.transcription,
        );

        expect(result, isFalse);
      });
    });
  });
}
