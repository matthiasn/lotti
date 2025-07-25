import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';

void main() {
  group('PreconfiguredPrompts', () {
    test('should have exactly 5 preconfigured prompts', () {
      expect(preconfiguredPrompts.length, equals(5));
    });

    test('should contain all expected prompt types', () {
      final promptTypes =
          preconfiguredPrompts.map((p) => p.aiResponseType).toSet();
      expect(
        promptTypes,
        containsAll([
          AiResponseType.taskSummary,
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
        expect(taskSummaryPrompt.useReasoning, isTrue);
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

      test('should NOT have task context placeholder', () {
        expect(imageAnalysisPrompt.userMessage, isNot(contains('{{task}}')));
        expect(imageAnalysisPrompt.userMessage,
            contains('Analyze the provided image'));
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

      test('should have user message with transcription instructions', () {
        expect(audioTranscriptionPrompt.userMessage, contains('transcribe'));
        expect(audioTranscriptionPrompt.userMessage, contains('audio'));
      });

      test('should include transcription instructions', () {
        expect(audioTranscriptionPrompt.userMessage,
            contains('proper punctuation'));
        expect(
            audioTranscriptionPrompt.userMessage, contains('speaker changes'));
        expect(audioTranscriptionPrompt.userMessage, contains('[in brackets]'));
      });
    });

    group('Image Analysis in Task Context Prompt', () {
      test('should have correct configuration', () {
        expect(imageAnalysisInTaskContextPrompt.aiResponseType,
            equals(AiResponseType.imageAnalysis));
        expect(imageAnalysisInTaskContextPrompt.name,
            equals('Image Analysis in Task Context'));
        expect(imageAnalysisInTaskContextPrompt.requiredInputData,
            equals([InputDataType.images, InputDataType.task]));
        expect(imageAnalysisInTaskContextPrompt.useReasoning, isFalse);
      });

      test('should have non-empty messages', () {
        expect(imageAnalysisInTaskContextPrompt.systemMessage, isNotEmpty);
        expect(imageAnalysisInTaskContextPrompt.userMessage, isNotEmpty);
        expect(imageAnalysisInTaskContextPrompt.description, isNotEmpty);
      });

      test('should have user message with task context placeholder', () {
        expect(
            imageAnalysisInTaskContextPrompt.userMessage, contains('{{task}}'));
        expect(imageAnalysisInTaskContextPrompt.userMessage,
            contains('Task Context:'));
      });

      test('should include task-aware analysis instructions', () {
        expect(
            imageAnalysisInTaskContextPrompt.userMessage,
            contains(
                'Extract ONLY information from the image that is relevant to this task'));
        expect(imageAnalysisInTaskContextPrompt.userMessage,
            contains('If the image is NOT relevant to the task'));
        expect(imageAnalysisInTaskContextPrompt.userMessage,
            contains('ducks by a lake'));
      });
    });

    group('Audio Transcription with Task Context Prompt', () {
      test('should have correct configuration', () {
        expect(audioTranscriptionWithTaskContextPrompt.aiResponseType,
            equals(AiResponseType.audioTranscription));
        expect(audioTranscriptionWithTaskContextPrompt.name,
            equals('Audio Transcription with Task Context'));
        expect(audioTranscriptionWithTaskContextPrompt.requiredInputData,
            equals([InputDataType.audioFiles, InputDataType.task]));
        expect(audioTranscriptionWithTaskContextPrompt.useReasoning, isFalse);
      });

      test('should have non-empty messages', () {
        expect(
            audioTranscriptionWithTaskContextPrompt.systemMessage, isNotEmpty);
        expect(audioTranscriptionWithTaskContextPrompt.userMessage, isNotEmpty);
        expect(audioTranscriptionWithTaskContextPrompt.description, isNotEmpty);
      });

      test('should have user message with task context placeholder', () {
        expect(audioTranscriptionWithTaskContextPrompt.userMessage,
            contains('{{task}}'));
        expect(audioTranscriptionWithTaskContextPrompt.userMessage,
            contains('Task Context:'));
      });

      test('should include task context instructions', () {
        expect(audioTranscriptionWithTaskContextPrompt.userMessage,
            contains('task context will provide additional information'));
        expect(audioTranscriptionWithTaskContextPrompt.userMessage,
            contains('names of people or places'));
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
      test('prompts can have duplicate types for different contexts', () {
        final types =
            preconfiguredPrompts.map((p) => p.aiResponseType).toList();
        // We now have multiple prompts with same type but different contexts
        expect(types.where((t) => t == AiResponseType.imageAnalysis).length,
            equals(2));
        expect(
            types.where((t) => t == AiResponseType.audioTranscription).length,
            equals(2));
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
