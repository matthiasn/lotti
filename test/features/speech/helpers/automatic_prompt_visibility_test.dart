import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_visibility.dart';

void main() {
  group('deriveAutomaticPromptVisibility', () {
    test('returns all false when automaticPrompts is null', () {
      final v = deriveAutomaticPromptVisibility(
        automaticPrompts: null,
      );

      expect(v.speech, isFalse);
      expect(v.none, isTrue);
    });

    test('speech visible only when transcription prompts exist', () {
      final v = deriveAutomaticPromptVisibility(
        automaticPrompts: {
          AiResponseType.audioTranscription: ['p1'],
        },
      );

      expect(v.speech, isTrue);
    });

    test('speech hidden when no transcription prompts', () {
      final v = deriveAutomaticPromptVisibility(
        automaticPrompts: {
          AiResponseType.checklistUpdates: ['c1'],
          AiResponseType.taskSummary: ['s1'],
        },
      );

      expect(v.speech, isFalse);
    });

    test('returns false for types with empty prompt lists', () {
      final v = deriveAutomaticPromptVisibility(
        automaticPrompts: {
          AiResponseType.audioTranscription: [], // empty list should not count
          AiResponseType.checklistUpdates: ['c1'],
        },
      );

      expect(v.speech, isFalse);
    });
  });
}
