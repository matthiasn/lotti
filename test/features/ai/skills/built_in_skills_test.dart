import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/consts.dart';

void main() {
  group('built_in_skills', () {
    test('every skill has a unique, non-empty ID', () {
      final ids = builtInSkills.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate skill IDs');
      for (final id in ids) {
        expect(id, isNotEmpty);
      }
    });

    test('every skill has non-empty name and instructions', () {
      for (final s in builtInSkills) {
        expect(s.name, isNotEmpty, reason: '${s.id} has empty name');
        expect(
          s.systemInstructions,
          isNotEmpty,
          reason: '${s.id} has empty systemInstructions',
        );
        expect(
          s.userInstructions,
          isNotEmpty,
          reason: '${s.id} has empty userInstructions',
        );
      }
    });

    test('every skill is marked preconfigured', () {
      for (final s in builtInSkills) {
        expect(
          s.isPreconfigured,
          isTrue,
          reason: '${s.id} should be preconfigured',
        );
      }
    });

    test('findBuiltInSkill returns the matching skill', () {
      for (final s in builtInSkills) {
        // same() checks non-null and identity in one assertion.
        expect(findBuiltInSkill(s.id), same(s));
      }
    });

    test('the registry contains exactly the expected skills', () {
      // One row per built-in skill: a silent deletion or a type/modality
      // drift fails here by id.
      const registry = <String, (SkillType, List<Modality>)>{
        skillTranscribeId: (SkillType.transcription, [Modality.audio]),
        skillTranscribeContextId: (
          SkillType.transcription,
          [Modality.audio],
        ),
        skillImageAnalysisId: (SkillType.imageAnalysis, [Modality.image]),
        skillImageAnalysisContextId: (
          SkillType.imageAnalysis,
          [Modality.image],
        ),
        skillImageGenId: (SkillType.imageGeneration, [Modality.text]),
        skillPromptGenId: (SkillType.promptGeneration, [Modality.text]),
        skillImagePromptGenId: (
          SkillType.imagePromptGeneration,
          [Modality.text],
        ),
        skillDesignPromptId: (SkillType.promptGeneration, [Modality.text]),
        skillResearchPromptId: (SkillType.promptGeneration, [Modality.text]),
      };

      expect(
        builtInSkills.map((s) => s.id).toSet(),
        registry.keys.toSet(),
      );
      for (final skill in builtInSkills) {
        final (type, modalities) = registry[skill.id]!;
        expect(skill.skillType, type, reason: skill.id);
        expect(skill.requiredInputModalities, modalities, reason: skill.id);
      }
    });

    test('findBuiltInSkill returns null for unknown ID', () {
      expect(findBuiltInSkill('skill-does-not-exist-xyz'), isNull);
    });

    group('design prompt skill', () {
      late AiConfigSkill skill;

      setUp(() {
        final found = findBuiltInSkill(skillDesignPromptId);
        expect(found, isNotNull, reason: 'design prompt skill missing');
        skill = found!;
      });

      test('is a promptGeneration skill on text modality', () {
        expect(skill.skillType, SkillType.promptGeneration);
        expect(skill.requiredInputModalities, [Modality.text]);
      });

      test('uses fullTask context and reasoning', () {
        expect(skill.contextPolicy, ContextPolicy.fullTask);
        expect(skill.useReasoning, isTrue);
      });

      // The substring checks below are intentional content contracts: these
      // two skills ship curated prompt text, and the pinned phrases are the
      // load-bearing parts of that contract (scope, output structure,
      // clarifying-question behavior). Rewording them is a product decision
      // that SHOULD touch these tests.
      test('instructions reference the default 5-prototype scope', () {
        expect(skill.systemInstructions, contains('5 functional prototypes'));
        expect(skill.systemInstructions, contains('Override only if'));
      });

      test('instructions require clarifying questions', () {
        expect(skill.systemInstructions.toLowerCase(), contains('clarifying'));
        expect(
          skill.userInstructions.toLowerCase(),
          contains('clarifying questions'),
        );
      });

      test('instructions handle design system alignment', () {
        expect(
          skill.systemInstructions.toLowerCase(),
          contains('design system'),
        );
      });
    });

    group('research prompt skill', () {
      late AiConfigSkill skill;

      setUp(() {
        final found = findBuiltInSkill(skillResearchPromptId);
        expect(found, isNotNull, reason: 'research prompt skill missing');
        skill = found!;
      });

      test('is a promptGeneration skill on text modality', () {
        expect(skill.skillType, SkillType.promptGeneration);
        expect(skill.requiredInputModalities, [Modality.text]);
      });

      test('uses fullTask context and reasoning', () {
        expect(skill.contextPolicy, ContextPolicy.fullTask);
        expect(skill.useReasoning, isTrue);
      });

      test('instructions specify Markdown output structure', () {
        expect(skill.systemInstructions, contains('## Summary'));
        expect(skill.systemInstructions, contains('## Research Brief'));
        expect(skill.systemInstructions, contains('### Background'));
        expect(skill.systemInstructions, contains('### Research Questions'));
        expect(skill.systemInstructions, contains('### Scope and Constraints'));
        expect(skill.systemInstructions, contains('### Required Deliverables'));
        expect(skill.systemInstructions, contains('### Source Preferences'));
      });

      test('instructions name the deep-research target tools', () {
        final lower = skill.systemInstructions.toLowerCase();
        expect(lower, contains('claude'));
        expect(lower, contains('chatgpt'));
      });
    });

    test(
      'prompt-generation skills require text modality (not audio-only)',
      () {
        final promptSkills = builtInSkills.where(
          (s) => s.skillType == SkillType.promptGeneration,
        );
        for (final s in promptSkills) {
          expect(
            s.requiredInputModalities,
            [Modality.text],
            reason: '${s.id} should accept text-bearing entries',
          );
        }
      },
    );

    test('image generation skill requires text modality', () {
      final s = findBuiltInSkill(skillImageGenId);
      expect(s, isNotNull);
      expect(s!.requiredInputModalities, [Modality.text]);
    });

    test('transcription skills still require audio modality', () {
      final transcribeSkills = builtInSkills.where(
        (s) => s.skillType == SkillType.transcription,
      );
      for (final s in transcribeSkills) {
        expect(s.requiredInputModalities, [Modality.audio]);
      }
    });
  });

  group('skillRegistryProvider', () {
    test('defaults to the built-in skill set', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(skillRegistryProvider), same(builtInSkills));
    });

    test('can be overridden with a custom skill list', () {
      final custom = [builtInSkills.first];
      final container = ProviderContainer(
        overrides: [skillRegistryProvider.overrideWithValue(custom)],
      );
      addTearDown(container.dispose);

      expect(container.read(skillRegistryProvider), same(custom));
    });
  });
}
