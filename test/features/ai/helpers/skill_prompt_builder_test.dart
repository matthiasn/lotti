import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/helpers/skill_prompt_builder.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';

void main() {
  const builder = SkillPromptBuilder();

  AiConfigSkill makeSkill({
    SkillType skillType = SkillType.transcription,
    ContextPolicy contextPolicy = ContextPolicy.none,
    String systemInstructions = 'System instructions here.',
    String userInstructions = 'User instructions here.',
  }) {
    return AiConfigSkill(
      id: 'test-skill',
      name: 'Test Skill',
      skillType: skillType,
      requiredInputModalities: [Modality.audio],
      systemInstructions: systemInstructions,
      userInstructions: userInstructions,
      contextPolicy: contextPolicy,
      createdAt: DateTime(2026),
    );
  }

  group('SkillPromptBuilder', () {
    group('system message', () {
      test('returns skill system instructions as-is for basic skills', () {
        final skill = makeSkill();
        final result = builder.build(skill: skill);

        expect(result.systemMessage, 'System instructions here.');
      });

      test('appends related tasks context for fullTask image analysis', () {
        final skill = makeSkill(
          skillType: SkillType.imageAnalysis,
          contextPolicy: ContextPolicy.fullTask,
        );
        final result = builder.build(
          skill: skill,
          taskContext: '{"id": "task-1"}',
        );

        expect(result.systemMessage, contains('System instructions here.'));
        expect(result.systemMessage, contains('RELATED TASKS CONTEXT'));
      });

      test('does not append related tasks context for non-fullTask', () {
        final skill = makeSkill(
          skillType: SkillType.imageAnalysis,
        );
        final result = builder.build(skill: skill);

        expect(result.systemMessage, isNot(contains('RELATED TASKS CONTEXT')));
      });
    });

    group('user message — transcription', () {
      test('includes speaker identification rules', () {
        final skill = makeSkill();
        final result = builder.build(skill: skill);

        expect(
          result.userMessage,
          contains('SPEAKER IDENTIFICATION RULES'),
        );
      });

      test('includes speech dictionary when provided', () {
        final skill = makeSkill();
        final result = builder.build(
          skill: skill,
          speechDictionary: 'Required spellings: ["macOS", "iPhone"]',
        );

        expect(result.userMessage, contains('macOS'));
        expect(result.userMessage, contains('iPhone'));
      });

      test('omits speech dictionary when empty', () {
        final skill = makeSkill();
        final result = builder.build(skill: skill, speechDictionary: '');

        // Should only have instructions + speaker rules, no dictionary block.
        expect(
          result.userMessage,
          isNot(contains('Required spellings')),
        );
      });

      test('includes task summary for fullTask transcription', () {
        final skill = makeSkill(contextPolicy: ContextPolicy.fullTask);
        final result = builder.build(
          skill: skill,
          currentTaskSummary: 'Working on database migration',
        );

        expect(
          result.userMessage,
          contains('for terminology only'),
        );
        expect(
          result.userMessage,
          contains('Working on database migration'),
        );
      });

      test('includes correction examples when provided', () {
        final skill = makeSkill();
        final result = builder.build(
          skill: skill,
          correctionExamples: '"mac OS" → "macOS"',
        );

        expect(result.userMessage, contains('"mac OS" → "macOS"'));
      });
    });

    group('user message — image analysis', () {
      test('includes URL formatting rules', () {
        final skill = makeSkill(skillType: SkillType.imageAnalysis);
        final result = builder.build(skill: skill);

        expect(result.userMessage, contains('URL FORMATTING RULES'));
      });

      test('prepends language code for non-fullTask', () {
        final skill = makeSkill(skillType: SkillType.imageAnalysis);
        final result = builder.build(skill: skill, languageCode: 'de');

        expect(result.userMessage, startsWith('de\n'));
      });

      test('does not prepend language code for fullTask', () {
        final skill = makeSkill(
          skillType: SkillType.imageAnalysis,
          contextPolicy: ContextPolicy.fullTask,
        );
        final result = builder.build(skill: skill, languageCode: 'de');

        expect(result.userMessage, isNot(startsWith('de\n')));
      });

      test('includes task context and linked tasks for fullTask', () {
        final skill = makeSkill(
          skillType: SkillType.imageAnalysis,
          contextPolicy: ContextPolicy.fullTask,
        );
        final result = builder.build(
          skill: skill,
          taskContext: '{"id": "task-1"}',
          linkedTasks: '{"linked_from": []}',
        );

        expect(result.userMessage, contains('Task Context'));
        expect(result.userMessage, contains('task-1'));
        expect(result.userMessage, contains('Related Tasks'));
      });

      test('does not include speaker identification rules', () {
        final skill = makeSkill(skillType: SkillType.imageAnalysis);
        final result = builder.build(skill: skill);

        expect(
          result.userMessage,
          isNot(contains('SPEAKER IDENTIFICATION RULES')),
        );
      });
    });

    group('user message — prompt generation', () {
      test('includes audio transcript', () {
        final skill = makeSkill(
          skillType: SkillType.promptGeneration,
          contextPolicy: ContextPolicy.fullTask,
        );
        final result = builder.build(
          skill: skill,
          audioTranscript: 'I need to fix the login bug',
          taskContext: '{"id": "task-1"}',
        );

        expect(result.userMessage, contains('Audio Transcription'));
        expect(
          result.userMessage,
          contains('I need to fix the login bug'),
        );
      });

      test('includes task context for fullTask policy', () {
        final skill = makeSkill(
          skillType: SkillType.promptGeneration,
          contextPolicy: ContextPolicy.fullTask,
        );
        final result = builder.build(
          skill: skill,
          taskContext: '{"id": "task-1"}',
        );

        expect(result.userMessage, contains('Task Context'));
      });

      test('omits audio transcript when empty', () {
        final skill = makeSkill(
          skillType: SkillType.promptGeneration,
          contextPolicy: ContextPolicy.fullTask,
        );
        final result = builder.build(skill: skill, audioTranscript: '');

        expect(
          result.userMessage,
          isNot(contains('Audio Transcription')),
        );
      });
    });

    group('user message — image generation', () {
      test('includes task summary for fullTask', () {
        final skill = makeSkill(
          skillType: SkillType.imageGeneration,
          contextPolicy: ContextPolicy.fullTask,
        );
        final result = builder.build(
          skill: skill,
          taskContext: '{"id": "task-1"}',
          currentTaskSummary: 'Summary with learnings',
        );

        expect(
          result.userMessage,
          contains('Task Summary (includes learnings and annoyances)'),
        );
        expect(
          result.userMessage,
          contains('Summary with learnings'),
        );
      });

      test('includes audio transcript', () {
        final skill = makeSkill(
          skillType: SkillType.imageGeneration,
          contextPolicy: ContextPolicy.fullTask,
        );
        final result = builder.build(
          skill: skill,
          audioTranscript: 'Make it blue and modern',
        );

        expect(
          result.userMessage,
          contains('Make it blue and modern'),
        );
      });
    });

    group('user message — dictionaryOnly policy', () {
      test('includes speech dictionary without task context', () {
        final skill = makeSkill(
          contextPolicy: ContextPolicy.dictionaryOnly,
        );
        final result = builder.build(
          skill: skill,
          speechDictionary: 'Required spellings: ["Flutter"]',
          taskContext: '{"id": "task-1"}',
        );

        expect(result.userMessage, contains('Flutter'));
        expect(
          result.userMessage,
          isNot(contains('Task Context')),
        );
      });
    });

    group('SkillPromptResult', () {
      test('holds both system and user messages', () {
        const result = SkillPromptResult(
          systemMessage: 'system',
          userMessage: 'user',
        );

        expect(result.systemMessage, 'system');
        expect(result.userMessage, 'user');
      });
    });
  });
}
