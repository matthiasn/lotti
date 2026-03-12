import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/skill_seeding_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockAiConfigRepository mockRepo;
  late SkillSeedingService service;

  setUpAll(() {
    registerFallbackValue(
      AiConfig.skill(
        id: 'fallback',
        name: 'Fallback',
        skillType: SkillType.transcription,
        requiredInputModalities: [Modality.audio],
        systemInstructions: '',
        userInstructions: '',
        createdAt: DateTime(2024),
      ),
    );
  });

  setUp(() {
    mockRepo = MockAiConfigRepository();
    service = SkillSeedingService(aiConfigRepository: mockRepo);

    when(() => mockRepo.getConfigById(any())).thenAnswer((_) async => null);
    when(() => mockRepo.saveConfig(any())).thenAnswer((_) async {});
  });

  group('SkillSeedingService', () {
    test('seeds all 7 preconfigured skills when none exist', () async {
      await service.seedDefaults();

      verify(() => mockRepo.saveConfig(any())).called(7);
    });

    test('skips skills that already exist', () async {
      when(() => mockRepo.getConfigById(skillTranscribeId)).thenAnswer(
        (_) async => AiConfig.skill(
          id: skillTranscribeId,
          name: 'Transcribe Audio',
          skillType: SkillType.transcription,
          requiredInputModalities: [Modality.audio],
          systemInstructions: 'existing',
          userInstructions: 'existing',
          createdAt: DateTime(2026),
        ),
      );

      await service.seedDefaults();

      verify(() => mockRepo.saveConfig(any())).called(6);
    });

    test('is fully idempotent — no saves when all exist', () async {
      when(() => mockRepo.getConfigById(any())).thenAnswer(
        (_) async => AiConfig.skill(
          id: 'existing',
          name: 'Existing',
          skillType: SkillType.transcription,
          requiredInputModalities: [Modality.audio],
          systemInstructions: '',
          userInstructions: '',
          createdAt: DateTime(2026),
        ),
      );

      await service.seedDefaults();

      verifyNever(() => mockRepo.saveConfig(any()));
    });

    test('seeds skills with correct well-known IDs', () async {
      await service.seedDefaults();

      for (final id in [
        skillTranscribeId,
        skillTranscribeContextId,
        skillImageAnalysisId,
        skillImageAnalysisContextId,
        skillImageGenId,
        skillPromptGenId,
        skillImagePromptGenId,
      ]) {
        verify(() => mockRepo.getConfigById(id)).called(1);
      }
    });

    test('all skills are marked as isPreconfigured', () async {
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
        final skill = config as AiConfigSkill;
        expect(
          skill.isPreconfigured,
          isTrue,
          reason: '${skill.name} isPreconfigured',
        );
      }
    });

    test(
      'transcription skills have correct skill type and modalities',
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

        final transcriptionSkills = capturedConfigs
            .whereType<AiConfigSkill>()
            .where((s) => s.skillType == SkillType.transcription)
            .toList();

        expect(transcriptionSkills, hasLength(2));
        for (final skill in transcriptionSkills) {
          expect(skill.requiredInputModalities, contains(Modality.audio));
          expect(skill.useReasoning, isFalse);
        }
      },
    );

    test('context policies are set correctly', () async {
      final capturedConfigs = <AiConfig>[];
      when(
        () => mockRepo.saveConfig(captureAny(that: isA<AiConfig>())),
      ).thenAnswer((invocation) async {
        capturedConfigs.add(
          invocation.positionalArguments.first as AiConfig,
        );
      });

      await service.seedDefaults();

      final skills = capturedConfigs.whereType<AiConfigSkill>().toList();
      final byId = {for (final s in skills) s.id: s};

      expect(
        byId[skillTranscribeId]!.contextPolicy,
        ContextPolicy.dictionaryOnly,
      );
      expect(
        byId[skillTranscribeContextId]!.contextPolicy,
        ContextPolicy.fullTask,
      );
      expect(
        byId[skillImageAnalysisId]!.contextPolicy,
        ContextPolicy.none,
      );
      expect(
        byId[skillImageAnalysisContextId]!.contextPolicy,
        ContextPolicy.fullTask,
      );
      expect(
        byId[skillImageGenId]!.contextPolicy,
        ContextPolicy.fullTask,
      );
    });

    test('prompt generation skills have useReasoning enabled', () async {
      final capturedConfigs = <AiConfig>[];
      when(
        () => mockRepo.saveConfig(captureAny(that: isA<AiConfig>())),
      ).thenAnswer((invocation) async {
        capturedConfigs.add(
          invocation.positionalArguments.first as AiConfig,
        );
      });

      await service.seedDefaults();

      final skills = capturedConfigs.whereType<AiConfigSkill>().toList();
      final byId = {for (final s in skills) s.id: s};

      expect(byId[skillPromptGenId]!.useReasoning, isTrue);
      expect(byId[skillImagePromptGenId]!.useReasoning, isTrue);
    });

    test('all skills have non-empty instructions', () async {
      for (final skill in SkillSeedingService.defaultSkills) {
        expect(
          skill.systemInstructions,
          isNotEmpty,
          reason: '${skill.name} systemInstructions',
        );
        expect(
          skill.userInstructions,
          isNotEmpty,
          reason: '${skill.name} userInstructions',
        );
      }
    });
  });
}
