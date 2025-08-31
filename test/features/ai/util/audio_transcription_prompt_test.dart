import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';

void main() {
  group('Audio Transcription Prompts', () {
    test(
        'audio transcription prompts do not include non-speech event instructions',
        () {
      // Regular audio transcription
      expect(
        audioTranscriptionPrompt.userMessage,
        isNot(contains('non-speech')),
      );
      expect(
        audioTranscriptionPrompt.userMessage,
        isNot(contains('[in brackets]')),
      );
      expect(
        audioTranscriptionPrompt.userMessage,
        isNot(contains('audio events')),
      );

      // Audio transcription with task context
      expect(
        audioTranscriptionWithTaskContextPrompt.userMessage,
        isNot(contains('non-speech')),
      );
      expect(
        audioTranscriptionWithTaskContextPrompt.userMessage,
        isNot(contains('[in brackets]')),
      );
      expect(
        audioTranscriptionWithTaskContextPrompt.userMessage,
        isNot(contains('audio events')),
      );
    });

    test(
        'audio transcription prompts still include other important instructions',
        () {
      // Regular audio transcription
      expect(
        audioTranscriptionPrompt.userMessage,
        contains('Remove filler words'),
      );
      expect(
        audioTranscriptionPrompt.userMessage,
        contains('speaker changes'),
      );
      expect(
        audioTranscriptionPrompt.userMessage,
        contains('punctuation and paragraph breaks'),
      );

      // Audio transcription with task context
      expect(
        audioTranscriptionWithTaskContextPrompt.userMessage,
        contains('Remove filler words'),
      );
      expect(
        audioTranscriptionWithTaskContextPrompt.userMessage,
        contains('speaker changes'),
      );
      expect(
        audioTranscriptionWithTaskContextPrompt.userMessage,
        contains('punctuation and paragraph breaks'),
      );
    });

    test(
        'audio transcription with task context includes task-specific instructions',
        () {
      expect(
        audioTranscriptionWithTaskContextPrompt.userMessage,
        contains('Task Context'),
      );
      expect(
        audioTranscriptionWithTaskContextPrompt.userMessage,
        contains('{{task}}'),
      );
      expect(
        audioTranscriptionWithTaskContextPrompt.systemMessage,
        contains('completed checklist items'),
      );
      expect(
        audioTranscriptionWithTaskContextPrompt.systemMessage,
        contains('new action items'),
      );
    });
  });
}
