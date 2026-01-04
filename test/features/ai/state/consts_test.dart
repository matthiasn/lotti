import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

import '../../../test_helper.dart';

void main() {
  group('AiResponseType', () {
    test('should have all expected enum values', () {
      expect(AiResponseType.values.length, equals(7));
      expect(AiResponseType.values, contains(AiResponseType.taskSummary));
      expect(AiResponseType.values, contains(AiResponseType.imageAnalysis));
      expect(
          AiResponseType.values, contains(AiResponseType.audioTranscription));
      expect(AiResponseType.values, contains(AiResponseType.checklistUpdates));
      expect(AiResponseType.values, contains(AiResponseType.promptGeneration));
      expect(AiResponseType.values,
          contains(AiResponseType.imagePromptGeneration));
      expect(AiResponseType.values, contains(AiResponseType.imageGeneration));
    });

    test('localizedName returns correct localized strings', () {
      // Use English localization directly for testing
      final l10n = AppLocalizationsEn();

      expect(
        l10n.aiResponseTypeTaskSummary,
        equals('Task Summary'),
      );
      expect(
        l10n.aiResponseTypeImageAnalysis,
        equals('Image Analysis'),
      );
      expect(
        l10n.aiResponseTypeAudioTranscription,
        equals('Audio Transcription'),
      );
      expect(
        l10n.aiResponseTypeChecklistUpdates,
        equals('Checklist Updates'),
      );
      expect(
        l10n.aiResponseTypePromptGeneration,
        equals('Generated Prompt'),
      );
      expect(
        l10n.aiResponseTypeImagePromptGeneration,
        equals('Image Prompt'),
      );
      expect(
        l10n.generateCoverArt,
        equals('Generate Cover Art'),
      );
    });

    test('icon returns correct icons for each type', () {
      expect(AiResponseType.taskSummary.icon, equals(Icons.summarize_outlined));
      expect(AiResponseType.imageAnalysis.icon, equals(Icons.image_outlined));
      expect(
          AiResponseType.audioTranscription.icon, equals(Icons.mic_outlined));
      expect(AiResponseType.checklistUpdates.icon,
          equals(Icons.checklist_rtl_outlined));
      expect(AiResponseType.promptGeneration.icon,
          equals(Icons.auto_fix_high_outlined));
      expect(AiResponseType.imagePromptGeneration.icon,
          equals(Icons.palette_outlined));
      expect(AiResponseType.imageGeneration.icon,
          equals(Icons.auto_awesome_outlined));
    });

    test('const values are correctly defined', () {
      expect(taskSummaryConst, equals('TaskSummary'));
      expect(imageAnalysisConst, equals('ImageAnalysis'));
      expect(audioTranscriptionConst, equals('AudioTranscription'));
      expect(checklistUpdatesConst, equals('ChecklistUpdates'));
      expect(promptGenerationConst, equals('PromptGeneration'));
      expect(imagePromptGenerationConst, equals('ImagePromptGeneration'));
      expect(imageGenerationConst, equals('ImageGeneration'));
    });

    testWidgets('localizedName returns correct strings with BuildContext',
        (tester) async {
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

      // Test all enum values with actual BuildContext
      expect(
        AiResponseType.taskSummary.localizedName(capturedContext),
        equals('Task Summary'),
      );
      expect(
        AiResponseType.imageAnalysis.localizedName(capturedContext),
        equals('Image Analysis'),
      );
      expect(
        AiResponseType.audioTranscription.localizedName(capturedContext),
        equals('Audio Transcription'),
      );
      expect(
        AiResponseType.checklistUpdates.localizedName(capturedContext),
        equals('Checklist Updates'),
      );
      expect(
        AiResponseType.promptGeneration.localizedName(capturedContext),
        equals('Generated Prompt'),
      );
      expect(
        AiResponseType.imagePromptGeneration.localizedName(capturedContext),
        equals('Image Prompt'),
      );
      expect(
        AiResponseType.imageGeneration.localizedName(capturedContext),
        equals('Generate Cover Art'),
      );
    });

    test('isPromptGenerationType returns true for prompt generation types', () {
      expect(AiResponseType.promptGeneration.isPromptGenerationType, true);
      expect(AiResponseType.imagePromptGeneration.isPromptGenerationType, true);
    });

    test('isPromptGenerationType returns false for non-prompt types', () {
      expect(AiResponseType.taskSummary.isPromptGenerationType, false);
      expect(AiResponseType.imageAnalysis.isPromptGenerationType, false);
      expect(AiResponseType.audioTranscription.isPromptGenerationType, false);
      expect(AiResponseType.checklistUpdates.isPromptGenerationType, false);
      expect(AiResponseType.imageGeneration.isPromptGenerationType, false);
    });
  });
}
