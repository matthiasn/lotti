import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/functions/function_handler.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  group('ChecklistItemHandler', () {
    late ChecklistItemHandler handler;

    setUp(() {
      handler = ChecklistItemHandler();
    });

    group('processFunctionCall', () {
      test('should reject function call with mismatched name', () {
        const call = ChatCompletionMessageToolCall(
          id: 'test-1',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'wrongFunctionName',
            arguments: '{"actionItemDescription": "test item"}',
          ),
        );

        final result = handler.processFunctionCall(call);

        expect(result.success, false);
        expect(result.error, contains('Function name mismatch'));
        expect(result.error, contains('expected "createChecklistItem"'));
        expect(result.error, contains('got "wrongFunctionName"'));
        expect(result.data['toolCallId'], 'test-1');
      });

      test('should accept function call with correct name', () {
        const call = ChatCompletionMessageToolCall(
          id: 'test-2',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'createChecklistItem',
            arguments: '{"actionItemDescription": "Buy milk"}',
          ),
        );

        final result = handler.processFunctionCall(call);

        expect(result.success, true);
        expect(result.functionName, 'createChecklistItem');
        expect(result.data['description'], 'Buy milk');
        expect(result.data['toolCallId'], 'test-2');
      });

      test('should reject empty or whitespace-only descriptions', () {
        const testCases = [
          '',
          ' ',
          '   ',
          '\t',
          '\n',
          ' \t\n ',
        ];

        for (final testDescription in testCases) {
          final call = ChatCompletionMessageToolCall(
            id: 'test-empty',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'createChecklistItem',
              arguments: '{"actionItemDescription": "$testDescription"}',
            ),
          );

          final result = handler.processFunctionCall(call);

          expect(result.success, false,
              reason:
                  'Should reject description: "${testDescription.replaceAll('\n', r'\n').replaceAll('\t', r'\t')}"');
        }
      });

      test('should handle missing actionItemDescription field', () {
        const call = ChatCompletionMessageToolCall(
          id: 'test-3',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'createChecklistItem',
            arguments: '{"wrongField": "test item"}',
          ),
        );

        final result = handler.processFunctionCall(call);

        expect(result.success, false);
        expect(result.error,
            contains('Found "wrongField" instead of "actionItemDescription"'));
        expect(result.data['attemptedItem'], 'test item');
        expect(result.data['wrongFieldName'], 'wrongField');
      });

      test('should handle null description', () {
        const call = ChatCompletionMessageToolCall(
          id: 'test-4',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'createChecklistItem',
            arguments: '{"actionItemDescription": null}',
          ),
        );

        final result = handler.processFunctionCall(call);

        expect(result.success, false);
        expect(result.error,
            contains('Missing required field "actionItemDescription"'));
      });

      test('should handle invalid JSON', () {
        const call = ChatCompletionMessageToolCall(
          id: 'test-5',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'createChecklistItem',
            arguments: 'invalid json',
          ),
        );

        final result = handler.processFunctionCall(call);

        expect(result.success, false);
        expect(result.error, contains('Invalid JSON'));
        expect(result.data['toolCallId'], 'test-5');
      });
    });

    group('isDuplicate', () {
      test('should detect duplicate descriptions', () {
        const call1 = ChatCompletionMessageToolCall(
          id: 'test-1',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'createChecklistItem',
            arguments: '{"actionItemDescription": "Buy Milk"}',
          ),
        );

        const call2 = ChatCompletionMessageToolCall(
          id: 'test-2',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'createChecklistItem',
            arguments: '{"actionItemDescription": "buy milk"}',
          ),
        );

        final result1 = handler.processFunctionCall(call1);
        expect(handler.isDuplicate(result1), false);

        final result2 = handler.processFunctionCall(call2);
        expect(handler.isDuplicate(result2), true);
      });

      test('should handle whitespace in duplicate detection', () {
        const call1 = ChatCompletionMessageToolCall(
          id: 'test-1',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'createChecklistItem',
            arguments: '{"actionItemDescription": "  Buy Milk  "}',
          ),
        );

        const call2 = ChatCompletionMessageToolCall(
          id: 'test-2',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'createChecklistItem',
            arguments: '{"actionItemDescription": "buy milk"}',
          ),
        );

        final result1 = handler.processFunctionCall(call1);
        expect(handler.isDuplicate(result1), false);

        final result2 = handler.processFunctionCall(call2);
        expect(handler.isDuplicate(result2), true);
      });
    });

    group('getRetryPrompt', () {
      test('should generate proper retry prompt for failed items', () {
        const failedResult = FunctionCallResult(
          success: false,
          functionName: 'createChecklistItem',
          arguments: '{"wrongField": "Buy milk"}',
          data: {
            'attemptedItem': 'Buy milk',
            'wrongFieldName': 'wrongField',
          },
          error: 'Found "wrongField" instead of "actionItemDescription"',
        );

        final prompt = handler.getRetryPrompt(
          failedItems: [failedResult],
          successfulDescriptions: ['Buy bread', 'Buy eggs'],
        );

        expect(prompt, contains('I noticed an error in your function call'));
        expect(prompt,
            contains('Found "wrongField" instead of "actionItemDescription"'));
        expect(prompt, contains('for "Buy milk"'));
        expect(
            prompt,
            contains(
                'already successfully created these items: Buy bread, Buy eggs'));
        expect(
            prompt, contains('{"actionItemDescription": "item description"}'));
        expect(prompt, contains('Do NOT recreate'));
      });

      test('should pluralize correctly for multiple errors', () {
        final failedResults = [
          const FunctionCallResult(
            success: false,
            functionName: 'createChecklistItem',
            arguments: '',
            data: {'attemptedItem': 'Item 1'},
            error: 'Error 1',
          ),
          const FunctionCallResult(
            success: false,
            functionName: 'createChecklistItem',
            arguments: '',
            data: {'attemptedItem': 'Item 2'},
            error: 'Error 2',
          ),
        ];

        final prompt = handler.getRetryPrompt(
          failedItems: failedResults,
          successfulDescriptions: [],
        );

        expect(prompt, contains('errors in your function calls'));
        expect(prompt, contains('failed items'));
      });
    });

    group('reset', () {
      test('should clear created descriptions', () {
        const call1 = ChatCompletionMessageToolCall(
          id: 'test-1',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'createChecklistItem',
            arguments: '{"actionItemDescription": "Test item"}',
          ),
        );

        const call2 = ChatCompletionMessageToolCall(
          id: 'test-2',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'createChecklistItem',
            arguments: '{"actionItemDescription": "test item"}',
          ),
        );

        // First call should succeed
        final result1 = handler.processFunctionCall(call1);
        expect(handler.isDuplicate(result1), false);

        // Reset handler
        handler.reset();

        // Same item should not be considered duplicate after reset
        final result2 = handler.processFunctionCall(call2);
        expect(handler.isDuplicate(result2), false);
      });
    });
  });
}
