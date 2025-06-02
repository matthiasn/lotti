import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';

void main() {
  group('PreconfiguredPrompts', () {
    test('should have exactly 4 preconfigured prompts', () {
      expect(preconfiguredPrompts.length, equals(4));
    });

    test('should contain all expected prompt types', () {
      final promptTypes =
          preconfiguredPrompts.map((p) => p.aiResponseType).toSet();
      expect(
        promptTypes,
        containsAll([
          AiResponseType.taskSummary,
          AiResponseType.actionItemSuggestions,
          AiResponseType.imageAnalysis,
          AiResponseType.audioTranscription,
        ]),
      );
    });

    group('Task Summary Prompt', () {
      test('should have correct configuration', () {
        expect(taskSummaryPrompt.aiResponseType,
            equals(AiResponseType.taskSummary));
        expect(taskSummaryPrompt.name, equals('Task Summary'));
        expect(
            taskSummaryPrompt.requiredInputData, equals([InputDataType.task]));
        expect(taskSummaryPrompt.aiResponseType,
            equals(AiResponseType.taskSummary));
        expect(taskSummaryPrompt.useReasoning, isFalse);
      });

      test('should have non-empty messages', () {
        expect(taskSummaryPrompt.systemMessage, isNotEmpty);
        expect(taskSummaryPrompt.userMessage, isNotEmpty);
        expect(taskSummaryPrompt.description, isNotEmpty);
      });

      test('should have user message with task placeholder', () {
        expect(taskSummaryPrompt.userMessage, contains('{{task}}'));
      });

      test('should include emoji instructions in user message', () {
        expect(taskSummaryPrompt.userMessage, contains('✅'));
        expect(taskSummaryPrompt.userMessage, contains('💡'));
        expect(taskSummaryPrompt.userMessage, contains('🤯'));
      });
    });

    group('Action Item Suggestions Prompt', () {
      test('should have correct configuration', () {
        expect(actionItemSuggestionsPrompt.aiResponseType,
            equals(AiResponseType.actionItemSuggestions));
        expect(actionItemSuggestionsPrompt.name,
            equals('Action Item Suggestions'));
        expect(actionItemSuggestionsPrompt.requiredInputData,
            equals([InputDataType.task]));
        expect(actionItemSuggestionsPrompt.aiResponseType,
            equals(AiResponseType.actionItemSuggestions));
        expect(actionItemSuggestionsPrompt.useReasoning, isTrue);
      });

      test('should have non-empty messages', () {
        expect(actionItemSuggestionsPrompt.systemMessage, isNotEmpty);
        expect(actionItemSuggestionsPrompt.userMessage, isNotEmpty);
        expect(actionItemSuggestionsPrompt.description, isNotEmpty);
      });

      test('should have user message with task placeholder', () {
        expect(actionItemSuggestionsPrompt.userMessage, contains('{{task}}'));
      });

      test('should include JSON example in user message', () {
        expect(actionItemSuggestionsPrompt.userMessage, contains('```json'));
        expect(actionItemSuggestionsPrompt.userMessage, contains('"title"'));
        expect(
            actionItemSuggestionsPrompt.userMessage, contains('"completed"'));
      });
    });

    group('Image Analysis Prompt', () {
      test('should have correct configuration', () {
        expect(imageAnalysisPrompt.aiResponseType,
            equals(AiResponseType.imageAnalysis));
        expect(imageAnalysisPrompt.name, equals('Image Analysis'));
        expect(imageAnalysisPrompt.requiredInputData,
            equals([InputDataType.images]));
        expect(imageAnalysisPrompt.aiResponseType,
            equals(AiResponseType.imageAnalysis));
        expect(imageAnalysisPrompt.useReasoning, isFalse);
      });

      test('should have non-empty messages', () {
        expect(imageAnalysisPrompt.systemMessage, isNotEmpty);
        expect(imageAnalysisPrompt.userMessage, isNotEmpty);
        expect(imageAnalysisPrompt.description, isNotEmpty);
      });

      test('should have user message with images placeholder', () {
        expect(imageAnalysisPrompt.userMessage, contains('{{#images}}'));
        expect(imageAnalysisPrompt.userMessage, contains('{{/images}}'));
        expect(imageAnalysisPrompt.userMessage, contains('{{index}}'));
      });

      test('should include analysis instructions', () {
        expect(imageAnalysisPrompt.userMessage, contains('Main subjects'));
        expect(imageAnalysisPrompt.userMessage, contains('Colors, lighting'));
        expect(imageAnalysisPrompt.userMessage, contains('Context or setting'));
      });
    });

    group('Audio Transcription Prompt', () {
      test('should have correct configuration', () {
        expect(audioTranscriptionPrompt.aiResponseType,
            equals(AiResponseType.audioTranscription));
        expect(audioTranscriptionPrompt.name, equals('Audio Transcription'));
        expect(audioTranscriptionPrompt.requiredInputData,
            equals([InputDataType.audioFiles]));
        expect(audioTranscriptionPrompt.aiResponseType,
            equals(AiResponseType.audioTranscription));
        expect(audioTranscriptionPrompt.useReasoning, isFalse);
      });

      test('should have non-empty messages', () {
        expect(audioTranscriptionPrompt.systemMessage, isNotEmpty);
        expect(audioTranscriptionPrompt.userMessage, isNotEmpty);
        expect(audioTranscriptionPrompt.description, isNotEmpty);
      });

      test('should have user message with audio files placeholder', () {
        expect(
            audioTranscriptionPrompt.userMessage, contains('{{#audioFiles}}'));
        expect(
            audioTranscriptionPrompt.userMessage, contains('{{/audioFiles}}'));
        expect(audioTranscriptionPrompt.userMessage, contains('{{index}}'));
      });

      test('should include transcription instructions', () {
        expect(audioTranscriptionPrompt.userMessage,
            contains('proper punctuation'));
        expect(
            audioTranscriptionPrompt.userMessage, contains('speaker changes'));
        expect(audioTranscriptionPrompt.userMessage, contains('[in brackets]'));
      });
    });

    group('PreconfiguredPrompt Class', () {
      test('should create instance with all required fields', () {
        const testPrompt = PreconfiguredPrompt(
          name: 'Test Prompt',
          systemMessage: 'System message',
          userMessage: 'User message',
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.taskSummary,
          useReasoning: true,
          description: 'Test description',
        );

        expect(testPrompt.name, equals('Test Prompt'));
        expect(testPrompt.systemMessage, equals('System message'));
        expect(testPrompt.userMessage, equals('User message'));
        expect(testPrompt.requiredInputData, equals([InputDataType.task]));
        expect(testPrompt.aiResponseType, equals(AiResponseType.taskSummary));
        expect(testPrompt.useReasoning, isTrue);
        expect(testPrompt.description, equals('Test description'));
        expect(testPrompt.defaultVariables, isNull);
      });

      test('should create instance with optional defaultVariables', () {
        const testPrompt = PreconfiguredPrompt(
          name: 'Test Prompt',
          systemMessage: 'System message',
          userMessage: 'User message',
          requiredInputData: [],
          aiResponseType: AiResponseType.taskSummary,
          useReasoning: false,
          description: 'Test description',
          defaultVariables: {'key': 'value'},
        );

        expect(testPrompt.defaultVariables, equals({'key': 'value'}));
      });
    });

    group('Prompt Content Validation', () {
      test('all prompts should have unique types', () {
        final types =
            preconfiguredPrompts.map((p) => p.aiResponseType).toList();
        expect(types.length, equals(types.toSet().length));
      });

      test('all prompts should have unique names', () {
        final names = preconfiguredPrompts.map((p) => p.name).toList();
        expect(names.length, equals(names.toSet().length));
      });

      test('all prompts should have descriptive system messages', () {
        for (final prompt in preconfiguredPrompts) {
          expect(prompt.systemMessage.length, greaterThan(50));
          expect(prompt.systemMessage, contains('AI assistant'));
        }
      });

      test('all prompts should have appropriate response types', () {
        expect(
          taskSummaryPrompt.aiResponseType,
          equals(AiResponseType.taskSummary),
        );
        expect(
          actionItemSuggestionsPrompt.aiResponseType,
          equals(AiResponseType.actionItemSuggestions),
        );
        expect(
          imageAnalysisPrompt.aiResponseType,
          equals(AiResponseType.imageAnalysis),
        );
        expect(
          audioTranscriptionPrompt.aiResponseType,
          equals(AiResponseType.audioTranscription),
        );
      });
    });
  });
}
