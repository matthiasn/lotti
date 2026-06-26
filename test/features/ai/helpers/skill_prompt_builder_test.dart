import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/helpers/skill_prompt_builder.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';

// ---------------------------------------------------------------------------
// Top-level generators for SkillPromptBuilder Glados property tests.
// ---------------------------------------------------------------------------

/// Generators for the discrete input space of SkillPromptBuilder.
extension _AnySkillPromptBuilder on glados.Any {
  glados.Generator<SkillType> get skillType =>
      glados.AnyUtils(this).choose(SkillType.values);

  glados.Generator<ContextPolicy> get contextPolicy =>
      glados.AnyUtils(this).choose(ContextPolicy.values);
}

/// Builds an [AiConfigSkill] with all fields set to stable test values except
/// the two variant inputs under test.
AiConfigSkill _makeGladosSkill({
  required SkillType skillType,
  required ContextPolicy contextPolicy,
}) {
  return AiConfigSkill(
    id: 'glados-skill',
    name: 'Glados Skill',
    skillType: skillType,
    requiredInputModalities: const [Modality.audio],
    systemInstructions: 'System.',
    userInstructions: 'User.',
    contextPolicy: contextPolicy,
    createdAt: DateTime(2026),
  );
}

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
          entryContent: 'I need to fix the login bug',
          taskContext: '{"id": "task-1"}',
        );

        expect(result.userMessage, contains('Entry Notes'));
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
        final result = builder.build(skill: skill, entryContent: '');

        expect(
          result.userMessage,
          isNot(contains('Entry Notes')),
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
          entryContent: 'Make it blue and modern',
        );

        expect(
          result.userMessage,
          contains('Make it blue and modern'),
        );
      });

      test('taskSummary image generation builds compact scene prompt', () {
        final skill = makeSkill(
          skillType: SkillType.imageGeneration,
          contextPolicy: ContextPolicy.taskSummary,
          userInstructions: 'Compact Flux cover art.',
        );
        final result = builder.build(
          skill: skill,
          entryContent: '''
Cats in suits in a steampunk laboratory working at a whiteboard with brass machinery and warm workshop lighting.
''',
          taskContext: '{"id": "task-1", "title": "Should not leak"}',
          linkedTasks: '{"linked_from": ["task-2"]}',
          currentTaskSummary: 'Creative planning task with a playful mood.',
        );

        expect(result.userMessage, contains('Compact Flux cover art.'));
        expect(result.userMessage, contains('Scene: Cats in suits'));
        expect(
          result.userMessage,
          contains('Mood and task clues: Creative planning task'),
        );
        expect(result.userMessage, contains('Render this as an image story'));
        expect(result.userMessage, isNot(contains('**Task Context:**')));
        expect(result.userMessage, isNot(contains('**Task Summary:**')));
        expect(result.userMessage, isNot(contains('**Entry Notes:**')));
        expect(result.userMessage, isNot(contains('Should not leak')));
        expect(result.userMessage, isNot(contains('linked_from')));
      });

      test('taskSummary image generation truncates long inputs', () {
        final skill = makeSkill(
          skillType: SkillType.imageGeneration,
          contextPolicy: ContextPolicy.taskSummary,
        );
        final result = builder.build(
          skill: skill,
          entryContent: 'a' * 900,
          currentTaskSummary: 'b' * 650,
        );

        expect(result.userMessage, contains('Scene: ${'a' * 700}...'));
        expect(
          result.userMessage,
          contains('Mood and task clues: ${'b' * 500}...'),
        );
        expect(result.userMessage, isNot(contains('a' * 701)));
        expect(result.userMessage, isNot(contains('b' * 501)));
      });
    });

    group('user message — taskSummary policy', () {
      test('includes only task summary, not full task JSON', () {
        final skill = makeSkill(
          skillType: SkillType.imageAnalysis,
          contextPolicy: ContextPolicy.taskSummary,
        );
        final result = builder.build(
          skill: skill,
          taskContext: '{"id": "task-1", "title": "Fix bug"}',
          linkedTasks: '{"linked_from": []}',
          currentTaskSummary: 'Working on database migration',
        );

        expect(result.userMessage, contains('Task Summary'));
        expect(
          result.userMessage,
          contains('Working on database migration'),
        );
        // Should NOT include full task JSON or linked tasks.
        expect(result.userMessage, isNot(contains('Task Context')));
        expect(result.userMessage, isNot(contains('Related Tasks')));
      });

      test('omits task summary when empty', () {
        final skill = makeSkill(
          skillType: SkillType.imageAnalysis,
          contextPolicy: ContextPolicy.taskSummary,
        );
        final result = builder.build(
          skill: skill,
          currentTaskSummary: '',
        );

        expect(result.userMessage, isNot(contains('Task Summary')));
      });
    });

    group('user message — imagePromptGeneration', () {
      test(
        'fullTask policy injects full task JSON + linked tasks (the '
        '"other skills" branch of _appendTaskContext)',
        () {
          final skill = makeSkill(
            skillType: SkillType.imagePromptGeneration,
            contextPolicy: ContextPolicy.fullTask,
          );
          final result = builder.build(
            skill: skill,
            taskContext: '{"id": "task-1", "title": "Fix bug"}',
            linkedTasks: '{"linked_from": ["task-2"]}',
            currentTaskSummary: 'Should not appear as a summary block',
            entryContent: 'Sketch of the fix',
          );

          // imagePromptGeneration is neither transcription nor
          // taskSummary-policy, so it takes the full-JSON branch.
          expect(result.userMessage, contains('**Task Context:**'));
          expect(
            result.userMessage,
            contains('{"id": "task-1", "title": "Fix bug"}'),
          );
          expect(result.userMessage, contains('**Related Tasks:**'));
          expect(
            result.userMessage,
            contains('{"linked_from": ["task-2"]}'),
          );
          expect(result.userMessage, isNot(contains('**Task Summary:**')));
          // Entry content still rides along for this skill type.
          expect(result.userMessage, contains('Sketch of the fix'));
        },
      );

      test('includes audio transcript', () {
        final skill = makeSkill(
          skillType: SkillType.imagePromptGeneration,
          contextPolicy: ContextPolicy.fullTask,
        );
        final result = builder.build(
          skill: skill,
          entryContent: 'Create a sunset scene',
        );

        expect(result.userMessage, contains('Entry Notes'));
        expect(result.userMessage, contains('Create a sunset scene'));
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

  // ---------------------------------------------------------------------------
  // Glados property tests — structural invariants for SkillPromptBuilder.build
  // ---------------------------------------------------------------------------

  group('SkillPromptBuilder — Glados structural invariants', () {
    // Property 1: speaker rules appear iff skillType == transcription
    glados.Glados2(
      glados.any.skillType,
      glados.any.contextPolicy,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'speaker rules appear exactly when skillType is transcription',
      (skillType, contextPolicy) {
        final skill = _makeGladosSkill(
          skillType: skillType,
          contextPolicy: contextPolicy,
        );
        final result = const SkillPromptBuilder().build(skill: skill);

        if (skillType == SkillType.transcription) {
          expect(
            result.userMessage,
            contains('SPEAKER IDENTIFICATION RULES'),
            reason: 'transcription skill must have speaker rules',
          );
        } else {
          expect(
            result.userMessage,
            isNot(contains('SPEAKER IDENTIFICATION RULES')),
            reason: 'non-transcription skill must not have speaker rules',
          );
        }
      },
      tags: 'glados',
    );

    // Property 2: URL rules appear iff skillType == imageAnalysis
    glados.Glados2(
      glados.any.skillType,
      glados.any.contextPolicy,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'URL formatting rules appear exactly when skillType is imageAnalysis',
      (skillType, contextPolicy) {
        final skill = _makeGladosSkill(
          skillType: skillType,
          contextPolicy: contextPolicy,
        );
        final result = const SkillPromptBuilder().build(skill: skill);

        if (skillType == SkillType.imageAnalysis) {
          expect(
            result.userMessage,
            contains('URL FORMATTING RULES'),
            reason: 'imageAnalysis skill must have URL rules',
          );
        } else {
          expect(
            result.userMessage,
            isNot(contains('URL FORMATTING RULES')),
            reason: 'non-imageAnalysis skill must not have URL rules',
          );
        }
      },
      tags: 'glados',
    );

    // Property 3: RELATED TASKS CONTEXT in system message appears exactly for
    // imageAnalysis + fullTask when taskContext is provided.
    glados.Glados2(
      glados.any.skillType,
      glados.any.contextPolicy,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'RELATED TASKS CONTEXT in system message iff imageAnalysis + fullTask + taskContext',
      (skillType, contextPolicy) {
        final skill = _makeGladosSkill(
          skillType: skillType,
          contextPolicy: contextPolicy,
        );
        final result = const SkillPromptBuilder().build(
          skill: skill,
          taskContext: '{"id": "t1"}',
        );

        final expectContext =
            skillType == SkillType.imageAnalysis &&
            contextPolicy == ContextPolicy.fullTask;

        if (expectContext) {
          expect(
            result.systemMessage,
            contains('RELATED TASKS CONTEXT'),
            reason:
                'imageAnalysis+fullTask+taskContext must have context block',
          );
        } else {
          expect(
            result.systemMessage,
            isNot(contains('RELATED TASKS CONTEXT')),
            reason:
                'other skill/policy combinations must not have context block',
          );
        }
      },
      tags: 'glados',
    );

    // Property 4: systemMessage always starts with the skill's systemInstructions.
    glados.Glados2(
      glados.any.skillType,
      glados.any.contextPolicy,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'systemMessage always begins with skill systemInstructions',
      (skillType, contextPolicy) {
        final skill = _makeGladosSkill(
          skillType: skillType,
          contextPolicy: contextPolicy,
        );
        final result = const SkillPromptBuilder().build(
          skill: skill,
          taskContext: '{"id":"t1"}',
        );

        expect(
          result.systemMessage.startsWith('System.'),
          isTrue,
          reason: 'systemMessage must start with systemInstructions',
        );
      },
      tags: 'glados',
    );

    // Property 5: userMessage always contains skill userInstructions.
    glados.Glados2(
      glados.any.skillType,
      glados.any.contextPolicy,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'userMessage always contains the skill userInstructions verbatim',
      (skillType, contextPolicy) {
        final skill = _makeGladosSkill(
          skillType: skillType,
          contextPolicy: contextPolicy,
        );
        final result = const SkillPromptBuilder().build(skill: skill);

        expect(
          result.userMessage,
          contains('User.'),
          reason: 'userMessage must contain userInstructions',
        );
      },
      tags: 'glados',
    );

    // Property 6: non-empty speechDictionary appears in userMessage only for
    // transcription skills or dictionaryOnly policy.
    glados.Glados2(
      glados.any.skillType,
      glados.any.contextPolicy,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'speechDictionary injected iff transcription or dictionaryOnly policy',
      (skillType, contextPolicy) {
        final skill = _makeGladosSkill(
          skillType: skillType,
          contextPolicy: contextPolicy,
        );
        const dict = 'Required spellings: ["macOS"]';
        final result = const SkillPromptBuilder().build(
          skill: skill,
          speechDictionary: dict,
        );

        final shouldInject =
            skillType == SkillType.transcription ||
            contextPolicy == ContextPolicy.dictionaryOnly;

        if (shouldInject) {
          expect(
            result.userMessage,
            contains(dict),
            reason: 'speech dictionary must be injected for this skill/policy',
          );
        } else {
          expect(
            result.userMessage,
            isNot(contains(dict)),
            reason:
                'speech dictionary must not appear for non-transcription, '
                'non-dictionaryOnly combinations',
          );
        }
      },
      tags: 'glados',
    );
  });
}
