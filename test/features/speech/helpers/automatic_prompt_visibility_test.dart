import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_visibility.dart';

void main() {
  group('deriveAutomaticPromptVisibility', () {
    test('returns all false when automaticPrompts is null', () {
      final v = deriveAutomaticPromptVisibility(
        automaticPrompts: null,
        hasLinkedTask: false,
      );

      expect(v.speech, isFalse);
      expect(v.checklist, isFalse);
      expect(v.summary, isFalse);
      expect(v.none, isTrue);
    });

    test('speech visible only when transcription prompts exist', () {
      final v = deriveAutomaticPromptVisibility(
        automaticPrompts: {
          AiResponseType.audioTranscription: ['p1'],
        },
        hasLinkedTask: false,
      );

      expect(v.speech, isTrue);
      expect(v.checklist, isFalse);
      expect(v.summary, isFalse);
    });

    test('checklist/summary hidden without transcription prompts', () {
      final v = deriveAutomaticPromptVisibility(
        automaticPrompts: {
          AiResponseType.checklistUpdates: ['c1'],
          AiResponseType.taskSummary: ['s1'],
        },
        hasLinkedTask: true,
        userSpeechPreference: true,
      );

      // Speech not available -> dependent toggles hidden
      expect(v.speech, isFalse);
      expect(v.checklist, isFalse);
      expect(v.summary, isFalse);
    });

    test('all visible when prompts exist, linked to task, and speech enabled',
        () {
      final v = deriveAutomaticPromptVisibility(
        automaticPrompts: {
          AiResponseType.audioTranscription: ['p1'],
          AiResponseType.checklistUpdates: ['c1'],
          AiResponseType.taskSummary: ['s1'],
        },
        hasLinkedTask: true,
        userSpeechPreference: true,
      );

      expect(v.speech, isTrue);
      expect(v.checklist, isTrue);
      expect(v.summary, isTrue);
    });

    test('dependent checkboxes hidden when user disabled speech', () {
      final v = deriveAutomaticPromptVisibility(
        automaticPrompts: {
          AiResponseType.audioTranscription: ['p1'],
          AiResponseType.checklistUpdates: ['c1'],
          AiResponseType.taskSummary: ['s1'],
        },
        hasLinkedTask: true,
        userSpeechPreference: false,
      );

      expect(v.speech, isTrue); // still visible to allow toggling back on
      expect(v.checklist, isFalse);
      expect(v.summary, isFalse);
    });

    test('returns false for types with empty prompt lists', () {
      final v = deriveAutomaticPromptVisibility(
        automaticPrompts: {
          AiResponseType.audioTranscription: [], // empty list should not count
          AiResponseType.checklistUpdates: ['c1'],
        },
        hasLinkedTask: true,
        userSpeechPreference: true,
      );

      // speech should be false because transcription list is empty
      expect(v.speech, isFalse);
      // checklist depends on speech being effectively enabled, so it's false too
      expect(v.checklist, isFalse);
      expect(v.summary, isFalse);
    });
  });
}
