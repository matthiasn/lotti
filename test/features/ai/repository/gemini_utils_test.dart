import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/repository/gemini_utils.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  group('GeminiUtils.build* URIs', () {
    test('stream URI ignores baseUrl path and preserves port', () {
      final uri = GeminiUtils.buildStreamGenerateContentUri(
        baseUrl: 'http://localhost:8080/openai/v1beta',
        model: 'gemini-2.0-pro-exp-02-05',
        apiKey: 'abc',
      );
      expect(uri.scheme, 'http');
      expect(uri.host, 'localhost');
      expect(uri.port, 8080);
      expect(
        uri.path,
        '/v1beta/models/gemini-2.0-pro-exp-02-05:streamGenerateContent',
      );
      expect(uri.queryParameters['key'], 'abc');
    });

    test('non-stream URI handles models/ prefix and trailing slash', () {
      final uri = GeminiUtils.buildGenerateContentUri(
        baseUrl: 'https://generativelanguage.googleapis.com',
        model: 'models/gemini-2.0-flash/ ',
        apiKey: 'xyz',
      );
      expect(
        uri.path,
        '/v1beta/models/gemini-2.0-flash:generateContent',
      );
      expect(uri.queryParameters['key'], 'xyz');
    });
  });

  group('GeminiUtils.buildRequestBody', () {
    test('includes prompt, temperature, thinking and optional fields', () {
      final body = GeminiUtils.buildRequestBody(
        prompt: 'Hello',
        temperature: 0.2,
        thinkingConfig: const GeminiThinkingConfig(
          thinkingBudget: 256,
          includeThoughts: true,
        ),
        systemMessage: 'System prompt',
        maxTokens: 123,
      );
      expect(body['contents'], isA<List<dynamic>>());
      final contents = (body['contents'] as List).cast<Map<String, dynamic>>();
      final firstParts =
          (contents.first['parts'] as List).cast<Map<String, dynamic>>();
      expect(firstParts[0]['text'], 'Hello');

      final generationConfig = body['generationConfig'] as Map<String, dynamic>;
      expect(generationConfig['temperature'], 0.2);
      expect(generationConfig['maxOutputTokens'], 123);
      expect(generationConfig['thinkingConfig'], isA<Map<String, dynamic>>());

      final systemInstruction =
          body['systemInstruction'] as Map<String, dynamic>;
      final systemParts =
          (systemInstruction['parts'] as List).cast<Map<String, dynamic>>();
      expect(systemParts[0]['text'], 'System prompt');
      expect(body.containsKey('tools'), isFalse);
    });

    test('maps ChatCompletionTool list to functionDeclarations', () {
      const tools = [
        ChatCompletionTool(
          type: ChatCompletionToolType.function,
          function: FunctionObject(
            name: 'lookup',
            description: 'lookup something',
          ),
        ),
        ChatCompletionTool(
          type: ChatCompletionToolType.function,
          function: FunctionObject(
            name: 'search',
          ),
        ),
      ];

      final body = GeminiUtils.buildRequestBody(
        prompt: 'Hello',
        temperature: 1,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 64),
        tools: tools,
      );

      expect(body['tools'], isA<List<dynamic>>());
      final toolsArr = (body['tools'] as List).cast<Map<String, dynamic>>();
      final toolsList = toolsArr.first;
      final fns = toolsList['functionDeclarations'] as List<dynamic>;
      expect(fns.length, 2);
      final fn0 = fns[0] as Map<String, dynamic>;
      final fn1 = fns[1] as Map<String, dynamic>;
      expect(fn0['name'], 'lookup');
      expect(fn0['description'], 'lookup something');
      expect(fn1['name'], 'search');
      // parameters omitted when null
      expect(fn0.containsKey('parameters'), isFalse);
    });
  });

  group('GeminiUtils.buildMultiTurnRequestBody', () {
    test('handles malformed JSON in tool call arguments gracefully', () {
      // Tool call with invalid JSON arguments
      final messages = [
        const ChatCompletionMessage.assistant(
          toolCalls: [
            ChatCompletionMessageToolCall(
              id: 'tool-1',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'test_function',
                arguments: 'not valid json {{{',
              ),
            ),
          ],
        ),
      ];

      // Should not throw, should use empty object as fallback
      final body = GeminiUtils.buildMultiTurnRequestBody(
        messages: messages,
        temperature: 0.7,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 256),
      );

      expect(body['contents'], isA<List<dynamic>>());
      final contents = (body['contents'] as List).cast<Map<String, dynamic>>();
      expect(contents.length, 1);

      final parts =
          (contents.first['parts'] as List).cast<Map<String, dynamic>>();
      expect(parts.length, 1);

      final functionCall = parts.first['functionCall'] as Map<String, dynamic>;
      expect(functionCall['name'], 'test_function');
      // Should have empty object as fallback for malformed JSON
      expect(functionCall['args'], <String, dynamic>{});
    });

    test('includes thought signatures in function calls', () {
      final messages = [
        const ChatCompletionMessage.assistant(
          toolCalls: [
            ChatCompletionMessageToolCall(
              id: 'tool-1',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'test_function',
                arguments: '{"key": "value"}',
              ),
            ),
          ],
        ),
      ];

      final body = GeminiUtils.buildMultiTurnRequestBody(
        messages: messages,
        temperature: 0.7,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 256),
        thoughtSignatures: {'tool-1': 'signature-abc123'},
      );

      final contents = (body['contents'] as List).cast<Map<String, dynamic>>();
      final parts =
          (contents.first['parts'] as List).cast<Map<String, dynamic>>();
      final functionCall = parts.first['functionCall'] as Map<String, dynamic>;

      expect(functionCall['thoughtSignature'], 'signature-abc123');
    });

    test('omits thought signature when not in map', () {
      final messages = [
        const ChatCompletionMessage.assistant(
          toolCalls: [
            ChatCompletionMessageToolCall(
              id: 'tool-1',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'test_function',
                arguments: '{"key": "value"}',
              ),
            ),
          ],
        ),
      ];

      final body = GeminiUtils.buildMultiTurnRequestBody(
        messages: messages,
        temperature: 0.7,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 256),
        thoughtSignatures: {'tool-2': 'different-id'}, // Different ID
      );

      final contents = (body['contents'] as List).cast<Map<String, dynamic>>();
      final parts =
          (contents.first['parts'] as List).cast<Map<String, dynamic>>();
      final functionCall = parts.first['functionCall'] as Map<String, dynamic>;

      expect(functionCall.containsKey('thoughtSignature'), isFalse);
    });

    test('handles multiple tool calls with mixed signatures', () {
      final messages = [
        const ChatCompletionMessage.assistant(
          toolCalls: [
            ChatCompletionMessageToolCall(
              id: 'tool-0',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'func_a',
                arguments: '{}',
              ),
            ),
            ChatCompletionMessageToolCall(
              id: 'tool-1',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'func_b',
                arguments: '{}',
              ),
            ),
          ],
        ),
      ];

      // Only first tool call has signature (as per Gemini docs)
      final body = GeminiUtils.buildMultiTurnRequestBody(
        messages: messages,
        temperature: 0.7,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 256),
        thoughtSignatures: {'tool-0': 'sig-first-only'},
      );

      final contents = (body['contents'] as List).cast<Map<String, dynamic>>();
      final parts =
          (contents.first['parts'] as List).cast<Map<String, dynamic>>();

      expect(parts.length, 2);
      expect(
        (parts[0]['functionCall'] as Map)['thoughtSignature'],
        'sig-first-only',
      );
      expect(
        (parts[1]['functionCall'] as Map).containsKey('thoughtSignature'),
        isFalse,
      );
    });

    test('converts user message with string content', () {
      final messages = [
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string('Hello, world!'),
        ),
      ];

      final body = GeminiUtils.buildMultiTurnRequestBody(
        messages: messages,
        temperature: 0.7,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 256),
      );

      final contents = (body['contents'] as List).cast<Map<String, dynamic>>();
      expect(contents.length, 1);
      expect(contents.first['role'], 'user');
      final parts =
          (contents.first['parts'] as List).cast<Map<String, dynamic>>();
      expect(parts.first['text'], 'Hello, world!');
    });

    test('converts assistant message with text content', () {
      final messages = [
        const ChatCompletionMessage.assistant(
          content: 'I am an assistant response',
        ),
      ];

      final body = GeminiUtils.buildMultiTurnRequestBody(
        messages: messages,
        temperature: 0.7,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 256),
      );

      final contents = (body['contents'] as List).cast<Map<String, dynamic>>();
      expect(contents.length, 1);
      expect(contents.first['role'], 'model');
      final parts =
          (contents.first['parts'] as List).cast<Map<String, dynamic>>();
      expect(parts.first['text'], 'I am an assistant response');
    });

    test('converts tool response message', () {
      final messages = [
        const ChatCompletionMessage.tool(
          toolCallId: 'call-123',
          content: 'Tool result data',
        ),
      ];

      final body = GeminiUtils.buildMultiTurnRequestBody(
        messages: messages,
        temperature: 0.7,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 256),
      );

      final contents = (body['contents'] as List).cast<Map<String, dynamic>>();
      expect(contents.length, 1);
      expect(contents.first['role'], 'function');
      final parts =
          (contents.first['parts'] as List).cast<Map<String, dynamic>>();
      final funcResponse = parts.first['functionResponse'] as Map;
      expect(funcResponse['name'], 'call-123');
      expect((funcResponse['response'] as Map)['result'], 'Tool result data');
    });

    test('converts function message (legacy format)', () {
      final messages = [
        const ChatCompletionMessage.function(
          name: 'my_function',
          content: 'Function result',
        ),
      ];

      final body = GeminiUtils.buildMultiTurnRequestBody(
        messages: messages,
        temperature: 0.7,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 256),
      );

      final contents = (body['contents'] as List).cast<Map<String, dynamic>>();
      expect(contents.length, 1);
      expect(contents.first['role'], 'function');
      final parts =
          (contents.first['parts'] as List).cast<Map<String, dynamic>>();
      final funcResponse = parts.first['functionResponse'] as Map;
      expect(funcResponse['name'], 'my_function');
      expect((funcResponse['response'] as Map)['result'], 'Function result');
    });

    test('skips system messages (handled separately)', () {
      final messages = [
        const ChatCompletionMessage.system(content: 'You are a helper'),
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string('Hello'),
        ),
      ];

      final body = GeminiUtils.buildMultiTurnRequestBody(
        messages: messages,
        temperature: 0.7,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 256),
        systemMessage: 'You are a helper',
      );

      final contents = (body['contents'] as List).cast<Map<String, dynamic>>();
      // Should only have user message, system is handled via systemInstruction
      expect(contents.length, 1);
      expect(contents.first['role'], 'user');
      // System instruction should be present
      expect(body.containsKey('systemInstruction'), isTrue);
    });

    test('includes tools in request body', () {
      final messages = [
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string('Call a function'),
        ),
      ];

      const tools = [
        ChatCompletionTool(
          type: ChatCompletionToolType.function,
          function: FunctionObject(
            name: 'my_tool',
            description: 'Does something',
            parameters: {'type': 'object', 'properties': <String, dynamic>{}},
          ),
        ),
      ];

      final body = GeminiUtils.buildMultiTurnRequestBody(
        messages: messages,
        temperature: 0.5,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 128),
        tools: tools,
      );

      expect(body.containsKey('tools'), isTrue);
      final toolsArr = (body['tools'] as List).cast<Map<String, dynamic>>();
      final funcDeclarations =
          toolsArr.first['functionDeclarations'] as List<dynamic>;
      expect(funcDeclarations.length, 1);
      expect((funcDeclarations.first as Map)['name'], 'my_tool');
      expect((funcDeclarations.first as Map)['description'], 'Does something');
      expect((funcDeclarations.first as Map).containsKey('parameters'), isTrue);
    });

    test('skips assistant message with no content or tool calls', () {
      final messages = [
        const ChatCompletionMessage.assistant(),
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string('Hello'),
        ),
      ];

      final body = GeminiUtils.buildMultiTurnRequestBody(
        messages: messages,
        temperature: 0.7,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 256),
      );

      final contents = (body['contents'] as List).cast<Map<String, dynamic>>();
      // Should only have user message, empty assistant skipped
      expect(contents.length, 1);
      expect(contents.first['role'], 'user');
    });

    test('handles empty string system message', () {
      final messages = [
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string('Hello'),
        ),
      ];

      final body = GeminiUtils.buildMultiTurnRequestBody(
        messages: messages,
        temperature: 0.7,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 256),
        systemMessage: '   ', // Whitespace only
      );

      // Should not include systemInstruction for empty/whitespace
      expect(body.containsKey('systemInstruction'), isFalse);
    });

    test('includes maxTokens in generation config', () {
      final messages = [
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string('Hello'),
        ),
      ];

      final body = GeminiUtils.buildMultiTurnRequestBody(
        messages: messages,
        temperature: 0.7,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 256),
        maxTokens: 500,
      );

      final generationConfig = body['generationConfig'] as Map<String, dynamic>;
      expect(generationConfig['maxOutputTokens'], 500);
    });
  });

  group('GeminiUtils.stripLeadingFraming', () {
    test('removes SSE data: lines and JSON array wrappers', () {
      const input = 'data: test\n  data: ignore\n [ {"a":1} , {"b":2}]';
      final out = GeminiUtils.stripLeadingFraming(input);
      expect(out.startsWith('{'), isTrue);
      // Verify we stripped at least one opening bracket
      expect(out, startsWith('{"a"'));
    });

    test('returns partial data unchanged when no newline', () {
      const input = 'data: partial line without newline';
      final out = GeminiUtils.stripLeadingFraming(input);
      expect(out, input.trimLeft());
    });
  });
}
