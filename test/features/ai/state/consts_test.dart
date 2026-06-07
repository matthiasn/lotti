import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/state/consts.dart';

import '../../../test_helper.dart';

extension _AnyGeneratedAiConsts on glados.Any {
  glados.Generator<SkillType> get skillType =>
      glados.AnyUtils(this).choose(SkillType.values);
}

AiResponseType _expectedResponseTypeForSkill(SkillType skillType) {
  return switch (skillType) {
    SkillType.transcription => AiResponseType.audioTranscription,
    SkillType.imageAnalysis => AiResponseType.imageAnalysis,
    SkillType.imageGeneration => AiResponseType.imageGeneration,
    SkillType.promptGeneration => AiResponseType.promptGeneration,
    SkillType.imagePromptGeneration => AiResponseType.imagePromptGeneration,
  };
}

void main() {
  group('AiResponseType', () {
    test('should have all expected enum values', () {
      expect(AiResponseType.values.length, equals(7));
      // ignore: deprecated_member_use_from_same_package
      expect(AiResponseType.values, contains(AiResponseType.taskSummary));
      expect(AiResponseType.values, contains(AiResponseType.imageAnalysis));
      expect(
        AiResponseType.values,
        contains(AiResponseType.audioTranscription),
      );
      // ignore: deprecated_member_use_from_same_package
      expect(AiResponseType.values, contains(AiResponseType.checklistUpdates));
      expect(AiResponseType.values, contains(AiResponseType.promptGeneration));
      expect(
        AiResponseType.values,
        contains(AiResponseType.imagePromptGeneration),
      );
      expect(AiResponseType.values, contains(AiResponseType.imageGeneration));
    });

    // Expected (label, icon) per enum value — one table drives both the
    // direct-l10n check and the icon mapping.
    const expectedByType = <AiResponseType, ({String label, IconData icon})>{
      // ignore: deprecated_member_use_from_same_package
      AiResponseType.taskSummary: (
        label: 'Task Summary',
        icon: Icons.summarize_outlined,
      ),
      AiResponseType.imageAnalysis: (
        label: 'Image Analysis',
        icon: Icons.image_outlined,
      ),
      AiResponseType.audioTranscription: (
        label: 'Audio Transcription',
        icon: Icons.mic_outlined,
      ),
      // ignore: deprecated_member_use_from_same_package
      AiResponseType.checklistUpdates: (
        label: 'Checklist Updates',
        icon: Icons.checklist_rtl_outlined,
      ),
      AiResponseType.promptGeneration: (
        label: 'Generated Prompt',
        icon: Icons.auto_fix_high_outlined,
      ),
      AiResponseType.imagePromptGeneration: (
        label: 'Image Prompt',
        icon: Icons.palette_outlined,
      ),
      AiResponseType.imageGeneration: (
        label: 'Generate Cover Art',
        icon: Icons.auto_awesome_outlined,
      ),
    };

    test('expectation table covers every enum value', () {
      expect(expectedByType.keys, containsAll(AiResponseType.values));
    });

    test('icon returns the mapped icon for each type', () {
      for (final entry in expectedByType.entries) {
        expect(entry.key.icon, entry.value.icon, reason: '${entry.key}');
      }
    });

    testWidgets('localizedName returns correct strings with BuildContext', (
      tester,
    ) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        WidgetTestBench(
          child: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      // Every enum value resolves its localized label through the context.
      for (final entry in expectedByType.entries) {
        expect(
          entry.key.localizedName(capturedContext),
          entry.value.label,
          reason: '${entry.key}',
        );
      }
    });

    test('isPromptGenerationType returns true for prompt generation types', () {
      expect(AiResponseType.promptGeneration.isPromptGenerationType, true);
      expect(AiResponseType.imagePromptGeneration.isPromptGenerationType, true);
    });

    test('isPromptGenerationType returns false for non-prompt types', () {
      // ignore: deprecated_member_use_from_same_package
      expect(AiResponseType.taskSummary.isPromptGenerationType, false);
      expect(AiResponseType.imageAnalysis.isPromptGenerationType, false);
      expect(AiResponseType.audioTranscription.isPromptGenerationType, false);
      // ignore: deprecated_member_use_from_same_package
      expect(AiResponseType.checklistUpdates.isPromptGenerationType, false);
      expect(AiResponseType.imageGeneration.isPromptGenerationType, false);
    });

    test('isLegacyType gates exactly the prompt-superseded types', () {
      // ignore: deprecated_member_use_from_same_package
      expect(AiResponseType.taskSummary.isLegacyType, true);
      // ignore: deprecated_member_use_from_same_package
      expect(AiResponseType.checklistUpdates.isLegacyType, true);
      // imageGeneration is intentionally legacy-for-prompts: the cover-art
      // skill (triggerSkillProvider) superseded prompt-driven execution,
      // while the enum value itself stays current for skill responses.
      expect(AiResponseType.imageGeneration.isLegacyType, true);

      expect(AiResponseType.imageAnalysis.isLegacyType, false);
      expect(AiResponseType.audioTranscription.isLegacyType, false);
      expect(AiResponseType.promptGeneration.isLegacyType, false);
      expect(AiResponseType.imagePromptGeneration.isLegacyType, false);
    });
  });

  group('SkillTypeToResponseType', () {
    glados.Glados(
      glados.any.skillType,
      glados.ExploreConfig(numRuns: 80),
    ).test('maps generated skill types to response types', (skillType) {
      expect(
        skillType.toResponseType,
        _expectedResponseTypeForSkill(skillType),
      );
    }, tags: 'glados');
  });
}
