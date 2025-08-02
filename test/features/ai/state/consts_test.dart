import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

void main() {
  group('AiResponseType', () {
    test('should have all expected enum values', () {
      expect(AiResponseType.values.length, equals(5));
      expect(AiResponseType.values, contains(AiResponseType.taskSummary));
      expect(AiResponseType.values, contains(AiResponseType.imageAnalysis));
      expect(
          AiResponseType.values, contains(AiResponseType.audioTranscription));
      expect(AiResponseType.values, contains(AiResponseType.checklistUpdates));
      expect(
          AiResponseType.values,
          contains(
            // ignore: deprecated_member_use_from_same_package
            AiResponseType.actionItemSuggestions,
          ));
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
    });

    test('icon returns correct icons for each type', () {
      expect(AiResponseType.taskSummary.icon, equals(Icons.summarize_outlined));
      expect(AiResponseType.imageAnalysis.icon, equals(Icons.image_outlined));
      expect(
          AiResponseType.audioTranscription.icon, equals(Icons.mic_outlined));
      expect(AiResponseType.checklistUpdates.icon,
          equals(Icons.checklist_rtl_outlined));
      // ignore: deprecated_member_use_from_same_package
      expect(AiResponseType.actionItemSuggestions.icon,
          equals(Icons.checklist_outlined));
    });

    test('const values are correctly defined', () {
      expect(taskSummaryConst, equals('TaskSummary'));
      expect(imageAnalysisConst, equals('ImageAnalysis'));
      expect(audioTranscriptionConst, equals('AudioTranscription'));
      expect(checklistUpdatesConst, equals('ChecklistUpdates'));
      expect(actionItemSuggestionsConst, equals('ActionItemSuggestions'));
    });
  });
}
