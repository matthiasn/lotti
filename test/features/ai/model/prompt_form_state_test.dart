import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';
import 'package:lotti/features/ai/state/consts.dart';

void main() {
  group('PromptFormState Tests', () {
    group('Input Validation Classes', () {
      test('PromptName validation', () {
        const validName = PromptName.dirty('Valid Name');
        const shortName = PromptName.dirty('V');
        const emptyName = PromptName.dirty();

        expect(validName.isValid, isTrue);
        expect(shortName.error, PromptFormError.tooShort);
        expect(emptyName.error, PromptFormError.tooShort);
      });

      test('PromptUserMessage validation', () {
        const validMessage = PromptUserMessage.dirty('Valid user message');
        const emptyMessage = PromptUserMessage.dirty();

        expect(validMessage.isValid, isTrue);
        expect(emptyMessage.error, PromptFormError.empty);
      });

      test('PromptSystemMessage validation', () {
        const validMessage = PromptSystemMessage.dirty('Valid system message');
        const emptyMessage = PromptSystemMessage.dirty();

        expect(validMessage.isValid, isTrue);
        expect(emptyMessage.error, PromptFormError.empty);
      });

      test('PromptDescription validation', () {
        const description = PromptDescription.dirty('Some description');
        const emptyDescription = PromptDescription.dirty();
        expect(description.isValid, isTrue);
        expect(emptyDescription.isValid, isTrue); // Optional
      });

      test('PromptComment validation', () {
        const comment = PromptComment.dirty('Some comment');
        const emptyComment = PromptComment.dirty();
        expect(comment.isValid, isTrue);
        expect(emptyComment.isValid, isTrue); // Optional
      });

      test('PromptCategory validation', () {
        const category = PromptCategory.dirty('Some category');
        const emptyCategory = PromptCategory.dirty();
        expect(category.isValid, isTrue);
        expect(emptyCategory.isValid, isTrue); // Optional
      });
    });

    group('PromptFormState', () {
      test('Initial state is pure and valid by default for optional fields',
          () {
        final formState = PromptFormState();
        expect(formState.name.isPure, isTrue);
        expect(formState.userMessage.isPure, isTrue);
        expect(formState.systemMessage.isPure, isTrue);
        expect(formState.comment.isPure, isTrue);
        expect(formState.description.isPure, isTrue);
        expect(formState.category.isPure, isTrue);
        expect(formState.aiResponseType.isPure, isTrue);
        expect(
          formState.isValid,
          isFalse,
        ); // name, userMessage, systemMessage, aiResponseType are required
      });

      test('Form is valid when required fields are valid', () {
        final formState = PromptFormState(
          name: const PromptName.dirty('Test Name'),
          userMessage: const PromptUserMessage.dirty('User message'),
          systemMessage: const PromptSystemMessage.dirty('System message'),
          aiResponseType:
              const PromptAiResponseType.dirty(AiResponseType.taskSummary),
        );
        expect(formState.isValid, isTrue);
      });

      test('Form is invalid if any required field is invalid', () {
        final formState = PromptFormState(
          name: const PromptName.dirty(), // Invalid
          userMessage: const PromptUserMessage.dirty('User message'),
          systemMessage: const PromptSystemMessage.dirty('System message'),
          aiResponseType:
              const PromptAiResponseType.dirty(AiResponseType.taskSummary),
        );
        expect(formState.isValid, isFalse);
      });

      test('copyWith creates a new instance with updated values', () {
        final initialState = PromptFormState();
        final updatedState = initialState.copyWith(
          name: const PromptName.dirty('New Name'),
          defaultModelId: 'gpt-4',
          useReasoning: true,
          aiResponseType: const PromptAiResponseType.dirty(
            AiResponseType.actionItemSuggestions,
          ),
        );

        expect(updatedState.name.value, 'New Name');
        expect(updatedState.defaultModelId, 'gpt-4');
        expect(updatedState.useReasoning, isTrue);
        expect(
          updatedState.aiResponseType.value,
          AiResponseType.actionItemSuggestions,
        );
        expect(updatedState.id, initialState.id);
        expect(updatedState.userMessage, initialState.userMessage);
      });

      test('toAiConfig converts form state to AiConfig model correctly', () {
        final formState = PromptFormState(
          id: 'test-id',
          name: const PromptName.dirty('Test Prompt'),
          systemMessage: const PromptSystemMessage.dirty('System instructions'),
          userMessage: const PromptUserMessage.dirty('User query {{input}}'),
          defaultModelId: 'model-123',
          modelIds: ['model-123', 'model-456'],
          useReasoning: true,
          requiredInputData: [InputDataType.task],
          comment: const PromptComment.dirty('This is a test comment.'),
          description:
              const PromptDescription.dirty('Detailed description here.'),
          category: const PromptCategory.dirty('Testing'),
          defaultVariables: {'input': 'default_value'},
          aiResponseType:
              const PromptAiResponseType.dirty(AiResponseType.taskSummary),
        );

        final aiConfig = formState.toAiConfig() as AiConfigPrompt;

        expect(aiConfig.id, 'test-id');
        expect(aiConfig.name, 'Test Prompt');
        expect(aiConfig.systemMessage, 'System instructions');
        expect(aiConfig.userMessage, 'User query {{input}}');
        expect(aiConfig.defaultModelId, 'model-123');
        expect(aiConfig.modelIds, ['model-123', 'model-456']);
        expect(aiConfig.useReasoning, isTrue);
        expect(aiConfig.requiredInputData, [InputDataType.task]);
        expect(aiConfig.comment, 'This is a test comment.');
        expect(aiConfig.description, 'Detailed description here.');
        expect(aiConfig.category, 'Testing');
        expect(aiConfig.defaultVariables, {'input': 'default_value'});
        expect(aiConfig.aiResponseType, AiResponseType.taskSummary);
        expect(aiConfig.createdAt, isA<DateTime>());
      });

      test('toAiConfig handles empty optional fields', () {
        final formState = PromptFormState(
          name: const PromptName.dirty('Test Prompt'),
          systemMessage: const PromptSystemMessage.dirty('System instructions'),
          userMessage: const PromptUserMessage.dirty('User query'),
          defaultModelId: 'model-123',
          aiResponseType:
              const PromptAiResponseType.dirty(AiResponseType.imageAnalysis),
        );

        final aiConfig = formState.toAiConfig() as AiConfigPrompt;
        expect(aiConfig.id, isNotNull); // Should generate a new UUID
        expect(aiConfig.name, 'Test Prompt');
        expect(aiConfig.aiResponseType, AiResponseType.imageAnalysis);
        expect(aiConfig.comment, isNull);
        expect(aiConfig.description, isNull);
        expect(aiConfig.category, isNull);
        expect(aiConfig.defaultVariables, isNull);
      });

      test('inputs list contains all form inputs', () {
        final formState = PromptFormState();
        final inputs = formState.inputs;
        expect(inputs, contains(formState.name));
        expect(inputs, contains(formState.userMessage));
        expect(inputs, contains(formState.systemMessage));
        expect(inputs, contains(formState.comment));
        expect(inputs, contains(formState.description));
        expect(inputs, contains(formState.category));
        expect(inputs, contains(formState.aiResponseType));
        expect(inputs.length, 7);
      });
    });
  });
}
