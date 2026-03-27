import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/functions/function_handler.dart';
import 'package:openai_dart/openai_dart.dart';

/// Minimal concrete implementation of [FunctionHandler] for testing the
/// abstract interface contract and [FunctionCallResult] data class.
///
/// Mimics the priority-handler pattern: parses a JSON `{"priority": "P1"}`
/// argument, tracks seen priorities for duplicate detection, and provides
/// human-readable descriptions and tool responses.
class _TestPriorityHandler extends FunctionHandler {
  _TestPriorityHandler();

  final Set<String> _seenPriorities = {};

  @override
  String get functionName => 'set_priority';

  @override
  FunctionCallResult processFunctionCall(ChatCompletionMessageToolCall call) {
    try {
      final args = jsonDecode(call.function.arguments) as Map<String, dynamic>;
      final priority = args['priority'] as String?;

      if (priority == null || priority.isEmpty) {
        return FunctionCallResult(
          success: false,
          functionName: functionName,
          arguments: call.function.arguments,
          data: {'toolCallId': call.id},
          error: 'Missing required field "priority"',
        );
      }

      return FunctionCallResult(
        success: true,
        functionName: functionName,
        arguments: call.function.arguments,
        data: {
          'priority': priority,
          'toolCallId': call.id,
        },
      );
    } catch (e) {
      return FunctionCallResult(
        success: false,
        functionName: functionName,
        arguments: call.function.arguments,
        data: {'toolCallId': call.id},
        error: 'Invalid JSON: $e',
      );
    }
  }

  @override
  bool isDuplicate(FunctionCallResult result) {
    if (!result.success) return false;

    final priority = result.data['priority'] as String?;
    if (priority == null) return false;

    final normalized = priority.toLowerCase().trim();
    if (_seenPriorities.contains(normalized)) {
      return true;
    }

    _seenPriorities.add(normalized);
    return false;
  }

  @override
  String? getDescription(FunctionCallResult result) {
    if (result.success) {
      return 'Priority: ${result.data['priority']}';
    }
    return null;
  }

  @override
  String createToolResponse(FunctionCallResult result) {
    if (result.success) {
      return 'Priority set to ${result.data['priority']}';
    }
    return 'Error: ${result.error}';
  }

  @override
  String getRetryPrompt({
    required List<FunctionCallResult> failedItems,
    required List<String> successfulDescriptions,
  }) {
    final errors = failedItems.map((item) => '- ${item.error}').join('\n');
    return 'Failed items:\n$errors\n'
        'Already succeeded: ${successfulDescriptions.join(', ')}';
  }
}

ChatCompletionMessageToolCall _makeToolCall({
  required String arguments,
  String name = 'set_priority',
  String id = 'call-1',
}) {
  return ChatCompletionMessageToolCall(
    id: id,
    type: ChatCompletionMessageToolCallType.function,
    function: ChatCompletionMessageFunctionCall(
      name: name,
      arguments: arguments,
    ),
  );
}

void main() {
  group('FunctionCallResult', () {
    test('stores all fields correctly', () {
      const result = FunctionCallResult(
        success: true,
        functionName: 'set_priority',
        arguments: '{"priority": "P1"}',
        data: {'priority': 'P1', 'toolCallId': 'call-1'},
        error: 'some error',
      );

      expect(result.success, isTrue);
      expect(result.functionName, 'set_priority');
      expect(result.arguments, '{"priority": "P1"}');
      expect(result.data, {'priority': 'P1', 'toolCallId': 'call-1'});
      expect(result.error, 'some error');
    });

    test('error defaults to null when not provided', () {
      const result = FunctionCallResult(
        success: true,
        functionName: 'set_priority',
        arguments: '{}',
        data: <String, dynamic>{},
      );

      expect(result.error, isNull);
    });

    test('success result has null error', () {
      const result = FunctionCallResult(
        success: true,
        functionName: 'set_priority',
        arguments: '{"priority": "P1"}',
        data: {'priority': 'P1'},
      );

      expect(result.success, isTrue);
      expect(result.error, isNull);
    });

    test('failed result has error message', () {
      const result = FunctionCallResult(
        success: false,
        functionName: 'set_priority',
        arguments: '{"bad": "input"}',
        data: <String, dynamic>{},
        error: 'Missing required field "priority"',
      );

      expect(result.success, isFalse);
      expect(result.error, 'Missing required field "priority"');
    });
  });

  group('FunctionHandler (via _TestPriorityHandler)', () {
    late _TestPriorityHandler handler;

    setUp(() {
      handler = _TestPriorityHandler();
    });

    test('functionName returns correct name', () {
      expect(handler.functionName, 'set_priority');
    });

    test('processFunctionCall parses valid JSON and returns success', () {
      final call = _makeToolCall(arguments: '{"priority": "P1"}');

      final result = handler.processFunctionCall(call);

      expect(result.success, isTrue);
      expect(result.functionName, 'set_priority');
      expect(result.arguments, '{"priority": "P1"}');
      expect(result.data['priority'], 'P1');
      expect(result.data['toolCallId'], 'call-1');
      expect(result.error, isNull);
    });

    test('processFunctionCall returns failure for invalid JSON', () {
      final call = _makeToolCall(arguments: '{not valid json}');

      final result = handler.processFunctionCall(call);

      expect(result.success, isFalse);
      expect(result.functionName, 'set_priority');
      expect(result.error, contains('Invalid JSON'));
    });

    test('processFunctionCall returns failure for missing required field', () {
      final call = _makeToolCall(arguments: '{"unrelated": "value"}');

      final result = handler.processFunctionCall(call);

      expect(result.success, isFalse);
      expect(result.error, 'Missing required field "priority"');
    });

    test('processFunctionCall returns failure for empty priority', () {
      final call = _makeToolCall(arguments: '{"priority": ""}');

      final result = handler.processFunctionCall(call);

      expect(result.success, isFalse);
      expect(result.error, 'Missing required field "priority"');
    });

    group('isDuplicate', () {
      test('detects matching priority values', () {
        final call = _makeToolCall(arguments: '{"priority": "P1"}');
        final result = handler.processFunctionCall(call);

        // First time: not a duplicate
        expect(handler.isDuplicate(result), isFalse);
        // Second time with same value: duplicate
        expect(handler.isDuplicate(result), isTrue);
      });

      test('returns false for different values', () {
        final call1 = _makeToolCall(arguments: '{"priority": "P1"}');
        final call2 = _makeToolCall(
          arguments: '{"priority": "P2"}',
          id: 'call-2',
        );

        final result1 = handler.processFunctionCall(call1);
        final result2 = handler.processFunctionCall(call2);

        expect(handler.isDuplicate(result1), isFalse);
        expect(handler.isDuplicate(result2), isFalse);
      });

      test('returns false for failed results', () {
        const failedResult = FunctionCallResult(
          success: false,
          functionName: 'set_priority',
          arguments: '{}',
          data: <String, dynamic>{},
          error: 'some error',
        );

        expect(handler.isDuplicate(failedResult), isFalse);
      });

      test('compares case-insensitively', () {
        final callUpper = _makeToolCall(arguments: '{"priority": "P1"}');
        final callLower = _makeToolCall(
          arguments: '{"priority": "p1"}',
          id: 'call-2',
        );

        final resultUpper = handler.processFunctionCall(callUpper);
        final resultLower = handler.processFunctionCall(callLower);

        expect(handler.isDuplicate(resultUpper), isFalse);
        expect(handler.isDuplicate(resultLower), isTrue);
      });
    });

    test('getDescription returns human-readable description for success', () {
      final call = _makeToolCall(arguments: '{"priority": "P1"}');
      final result = handler.processFunctionCall(call);

      expect(handler.getDescription(result), 'Priority: P1');
    });

    test('getDescription returns null for failure', () {
      final call = _makeToolCall(arguments: '{}');
      final result = handler.processFunctionCall(call);

      expect(result.success, isFalse);
      expect(handler.getDescription(result), isNull);
    });

    group('createToolResponse', () {
      test('returns success message', () {
        final call = _makeToolCall(arguments: '{"priority": "P1"}');
        final result = handler.processFunctionCall(call);

        expect(handler.createToolResponse(result), 'Priority set to P1');
      });

      test('returns failure message', () {
        final call = _makeToolCall(arguments: '{}');
        final result = handler.processFunctionCall(call);

        expect(
          handler.createToolResponse(result),
          'Error: Missing required field "priority"',
        );
      });
    });

    test(
      'getRetryPrompt includes failed items and successful descriptions',
      () {
        const failedResult1 = FunctionCallResult(
          success: false,
          functionName: 'set_priority',
          arguments: '{}',
          data: <String, dynamic>{},
          error: 'Missing required field "priority"',
        );
        const failedResult2 = FunctionCallResult(
          success: false,
          functionName: 'set_priority',
          arguments: '{"priority": "INVALID"}',
          data: <String, dynamic>{},
          error: 'Unknown priority value',
        );

        final prompt = handler.getRetryPrompt(
          failedItems: [failedResult1, failedResult2],
          successfulDescriptions: ['Priority: P1', 'Priority: P3'],
        );

        expect(prompt, contains('Missing required field "priority"'));
        expect(prompt, contains('Unknown priority value'));
        expect(prompt, contains('Priority: P1'));
        expect(prompt, contains('Priority: P3'));
        expect(prompt, contains('Already succeeded'));
      },
    );
  });
}
