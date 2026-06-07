import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/repository/gemini_utils.dart';
import 'package:lotti/features/ai/util/image_processing_utils.dart';
import 'package:openai_dart/openai_dart.dart';

enum _GeneratedGeminiFrame {
  spaces,
  newlineTabs,
  openingArray,
  closingArray,
  comma,
  emptyDataLine,
  blankDataLine,
  heartbeatDataLine,
}

enum _GeneratedGeminiFramedPayloadKind {
  directObject,
  arrayObject,
  sseObject,
  sseArrayObject,
}

String _generatedGeminiFrameText(_GeneratedGeminiFrame frame) {
  return switch (frame) {
    _GeneratedGeminiFrame.spaces => '   ',
    _GeneratedGeminiFrame.newlineTabs => '\n\t  ',
    _GeneratedGeminiFrame.openingArray => '[',
    _GeneratedGeminiFrame.closingArray => ']',
    _GeneratedGeminiFrame.comma => ',',
    _GeneratedGeminiFrame.emptyDataLine => 'data:\n',
    _GeneratedGeminiFrame.blankDataLine => 'data:   \n',
    _GeneratedGeminiFrame.heartbeatDataLine => 'data: heartbeat\n',
  };
}

class _GeneratedGeminiFramingScenario {
  const _GeneratedGeminiFramingScenario({
    required this.frames,
    required this.payloadKind,
    required this.value,
  });

  final List<_GeneratedGeminiFrame> frames;
  final _GeneratedGeminiFramedPayloadKind payloadKind;
  final int value;

  String get objectPayload => '{"value":$value,"marker":"generated"}';

  String get trailer => '\ntrailer:$value';

  String get input {
    final prefix = frames.map(_generatedGeminiFrameText).join();
    return '$prefix${_renderPayload()}$trailer';
  }

  String get expected {
    return switch (payloadKind) {
      _GeneratedGeminiFramedPayloadKind.directObject =>
        '$objectPayload$trailer',
      _GeneratedGeminiFramedPayloadKind.arrayObject =>
        '$objectPayload ]$trailer',
      _GeneratedGeminiFramedPayloadKind.sseObject => '$objectPayload$trailer',
      _GeneratedGeminiFramedPayloadKind.sseArrayObject =>
        '$objectPayload]$trailer',
    };
  }

  String _renderPayload() {
    return switch (payloadKind) {
      _GeneratedGeminiFramedPayloadKind.directObject => objectPayload,
      _GeneratedGeminiFramedPayloadKind.arrayObject => '[ $objectPayload ]',
      _GeneratedGeminiFramedPayloadKind.sseObject => 'data: $objectPayload\n',
      _GeneratedGeminiFramedPayloadKind.sseArrayObject =>
        'data: [$objectPayload]\n',
    };
  }

  @override
  String toString() {
    return '_GeneratedGeminiFramingScenario('
        'frames: $frames, payloadKind: $payloadKind, value: $value)';
  }
}

extension _AnyGeneratedGeminiFramingScenario on glados.Any {
  glados.Generator<_GeneratedGeminiFrame> get geminiFrame =>
      glados.AnyUtils(this).choose(_GeneratedGeminiFrame.values);

  glados.Generator<_GeneratedGeminiFramedPayloadKind>
  get geminiFramedPayloadKind =>
      glados.AnyUtils(this).choose(_GeneratedGeminiFramedPayloadKind.values);

  glados.Generator<_GeneratedGeminiFramingScenario> get geminiFramingScenario =>
      glados.CombinableAny(this).combine3(
        glados.ListAnys(this).listWithLengthInRange(0, 24, geminiFrame),
        geminiFramedPayloadKind,
        glados.IntAnys(this).intInRange(-1000, 1000),
        (
          List<_GeneratedGeminiFrame> frames,
          _GeneratedGeminiFramedPayloadKind payloadKind,
          int value,
        ) => _GeneratedGeminiFramingScenario(
          frames: frames,
          payloadKind: payloadKind,
          value: value,
        ),
      );
}

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
      final firstParts = (contents.first['parts'] as List)
          .cast<Map<String, dynamic>>();
      expect(firstParts[0]['text'], 'Hello');

      final generationConfig = body['generationConfig'] as Map<String, dynamic>;
      expect(generationConfig['temperature'], 0.2);
      expect(generationConfig['maxOutputTokens'], 123);
      expect(generationConfig['thinkingConfig'], isA<Map<String, dynamic>>());

      final systemInstruction =
          body['systemInstruction'] as Map<String, dynamic>;
      final systemParts = (systemInstruction['parts'] as List)
          .cast<Map<String, dynamic>>();
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

    test('serializes forced named tool choice', () {
      const tools = [
        ChatCompletionTool(
          type: ChatCompletionToolType.function,
          function: FunctionObject(name: 'draft_day_plan'),
        ),
      ];
      const toolChoice = ChatCompletionToolChoiceOption.tool(
        ChatCompletionNamedToolChoice(
          type: ChatCompletionNamedToolChoiceType.function,
          function: ChatCompletionFunctionCallOption(name: 'draft_day_plan'),
        ),
      );

      final body = GeminiUtils.buildRequestBody(
        prompt: 'Draft the day',
        temperature: 0.2,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 64),
        tools: tools,
        toolChoice: toolChoice,
      );

      final toolConfig = body['toolConfig'] as Map<String, dynamic>;
      final functionCallingConfig =
          toolConfig['functionCallingConfig'] as Map<String, dynamic>;
      expect(functionCallingConfig['mode'], 'ANY');
      expect(
        functionCallingConfig['allowedFunctionNames'],
        ['draft_day_plan'],
      );
    });

    test('maps each tool-choice mode to a Gemini functionCallingConfig', () {
      const expected = {
        ChatCompletionToolChoiceMode.none: 'NONE',
        ChatCompletionToolChoiceMode.auto: 'AUTO',
        ChatCompletionToolChoiceMode.required: 'ANY',
      };

      for (final entry in expected.entries) {
        final body = GeminiUtils.buildRequestBody(
          prompt: 'Draft the day',
          temperature: 0.2,
          thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 64),
          toolChoice: ChatCompletionToolChoiceOption.mode(entry.key),
        );

        final functionCallingConfig =
            (body['toolConfig']
                    as Map<String, dynamic>)['functionCallingConfig']
                as Map<String, dynamic>;
        expect(functionCallingConfig['mode'], entry.value);
        // Mode-only choices never pin specific function names.
        expect(
          functionCallingConfig.containsKey('allowedFunctionNames'),
          isFalse,
        );
      }
    });

    test('omits toolConfig entirely when no tool choice is given', () {
      final body = GeminiUtils.buildRequestBody(
        prompt: 'Draft the day',
        temperature: 0.2,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 64),
      );

      expect(body.containsKey('toolConfig'), isFalse);
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

      final parts = (contents.first['parts'] as List)
          .cast<Map<String, dynamic>>();
      expect(parts.length, 1);

      final functionCall = parts.first['functionCall'] as Map<String, dynamic>;
      expect(functionCall['name'], 'test_function');
      // Should have empty object as fallback for malformed JSON
      expect(functionCall['args'], <String, dynamic>{});
    });

    test('serializes forced named tool choice', () {
      const toolChoice = ChatCompletionToolChoiceOption.tool(
        ChatCompletionNamedToolChoice(
          type: ChatCompletionNamedToolChoiceType.function,
          function: ChatCompletionFunctionCallOption(name: 'draft_day_plan'),
        ),
      );

      final body = GeminiUtils.buildMultiTurnRequestBody(
        messages: const [
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Draft the day'),
          ),
        ],
        temperature: 0.2,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 64),
        tools: const [
          ChatCompletionTool(
            type: ChatCompletionToolType.function,
            function: FunctionObject(name: 'draft_day_plan'),
          ),
        ],
        toolChoice: toolChoice,
      );

      final toolConfig = body['toolConfig'] as Map<String, dynamic>;
      final functionCallingConfig =
          toolConfig['functionCallingConfig'] as Map<String, dynamic>;
      expect(functionCallingConfig['mode'], 'ANY');
      expect(
        functionCallingConfig['allowedFunctionNames'],
        ['draft_day_plan'],
      );
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
      final parts = (contents.first['parts'] as List)
          .cast<Map<String, dynamic>>();

      // Signature is at part level, sibling of functionCall (not nested inside it)
      expect(parts.first['thoughtSignature'], 'signature-abc123');
      // functionCall should not contain the signature
      final functionCall = parts.first['functionCall'] as Map<String, dynamic>;
      expect(functionCall.containsKey('thoughtSignature'), isFalse);
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
      final parts = (contents.first['parts'] as List)
          .cast<Map<String, dynamic>>();

      // Signature should not be present at part level when ID doesn't match
      expect(parts.first.containsKey('thoughtSignature'), isFalse);
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
      final parts = (contents.first['parts'] as List)
          .cast<Map<String, dynamic>>();

      expect(parts.length, 2);
      // Signature is at part level, not inside functionCall
      expect(parts[0]['thoughtSignature'], 'sig-first-only');
      expect(parts[1].containsKey('thoughtSignature'), isFalse);
      // Verify functionCall doesn't contain signature (it's a sibling)
      expect(
        (parts[0]['functionCall'] as Map).containsKey('thoughtSignature'),
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
      final parts = (contents.first['parts'] as List)
          .cast<Map<String, dynamic>>();
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
      final parts = (contents.first['parts'] as List)
          .cast<Map<String, dynamic>>();
      expect(parts.first['text'], 'I am an assistant response');
    });

    test('converts tool response message with correct function name', () {
      // Include assistant message with tool calls to build the ID->name mapping
      final messages = [
        const ChatCompletionMessage.assistant(
          toolCalls: [
            ChatCompletionMessageToolCall(
              id: 'call-123',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'lookup_data',
                arguments: '{}',
              ),
            ),
          ],
        ),
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
      expect(contents.length, 2);
      // Second content is the tool response
      expect(contents[1]['role'], 'function');
      final parts = (contents[1]['parts'] as List).cast<Map<String, dynamic>>();
      final funcResponse = parts.first['functionResponse'] as Map;
      // Should use function name from the assistant's tool call, not the ID
      expect(funcResponse['name'], 'lookup_data');
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
      final parts = (contents.first['parts'] as List)
          .cast<Map<String, dynamic>>();
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

    test('strips additionalProperties from tool parameter schemas', () {
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
            parameters: {
              'type': 'object',
              'properties': {
                'title': {
                  'type': 'string',
                  'description': 'A title',
                },
                'items': {
                  'type': 'array',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'name': {'type': 'string'},
                    },
                    'required': ['name'],
                    'additionalProperties': false,
                  },
                },
              },
              'required': ['title'],
              'additionalProperties': false,
            },
          ),
        ),
      ];

      final body = GeminiUtils.buildMultiTurnRequestBody(
        messages: messages,
        temperature: 0.5,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 128),
        tools: tools,
      );

      final toolsArr = (body['tools'] as List).cast<Map<String, dynamic>>();
      final funcDecl =
          (toolsArr.first['functionDeclarations'] as List).first
              as Map<String, dynamic>;
      final params = funcDecl['parameters'] as Map<String, dynamic>;

      // Top-level additionalProperties should be stripped
      expect(params.containsKey('additionalProperties'), isFalse);
      expect(params['type'], 'object');
      expect(params['required'], ['title']);

      // Nested additionalProperties inside items should also be stripped
      final properties = params['properties'] as Map<String, dynamic>;
      final itemsSchema = properties['items'] as Map<String, dynamic>;
      final nestedItems = itemsSchema['items'] as Map<String, dynamic>;
      expect(nestedItems.containsKey('additionalProperties'), isFalse);
      expect(nestedItems['required'], ['name']);
    });

    test('strips additionalProperties from sub-schemas inside list values', () {
      // A schema value that is a List of Map sub-schemas (e.g. anyOf) must
      // have additionalProperties stripped recursively from each list element.
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
            parameters: {
              'type': 'object',
              'properties': {
                'value': {
                  'anyOf': [
                    {
                      'type': 'object',
                      'properties': {
                        'kind': {'type': 'string'},
                      },
                      'additionalProperties': false,
                    },
                    {
                      'type': 'number',
                      // Plain string element in the same list exercises the
                      // non-map branch (returns the element unchanged).
                    },
                    'scalar',
                  ],
                },
              },
            },
          ),
        ),
      ];

      final body = GeminiUtils.buildMultiTurnRequestBody(
        messages: messages,
        temperature: 0.5,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 128),
        tools: tools,
      );

      final toolsArr = (body['tools'] as List).cast<Map<String, dynamic>>();
      final funcDecl =
          (toolsArr.first['functionDeclarations'] as List).first
              as Map<String, dynamic>;
      final params = funcDecl['parameters'] as Map<String, dynamic>;
      final properties = params['properties'] as Map<String, dynamic>;
      final valueSchema = properties['value'] as Map<String, dynamic>;
      final anyOf = valueSchema['anyOf'] as List<dynamic>;

      // First element is a Map sub-schema: additionalProperties stripped via
      // the list-element recursion, while its other keys are preserved.
      final firstSub = anyOf[0] as Map<String, dynamic>;
      expect(firstSub.containsKey('additionalProperties'), isFalse);
      expect(firstSub['type'], 'object');
      expect(
        (firstSub['properties'] as Map<String, dynamic>)['kind'],
        {'type': 'string'},
      );

      // Second element is a Map without additionalProperties: kept intact.
      expect(anyOf[1], {'type': 'number'});

      // Third element is a non-map scalar: returned unchanged.
      expect(anyOf[2], 'scalar');
    });

    test('strips additionalProperties from buildRequestBody tools too', () {
      const tools = [
        ChatCompletionTool(
          type: ChatCompletionToolType.function,
          function: FunctionObject(
            name: 'my_tool',
            parameters: {
              'type': 'object',
              'properties': <String, dynamic>{},
              'additionalProperties': false,
            },
          ),
        ),
      ];

      final body = GeminiUtils.buildRequestBody(
        prompt: 'Hello',
        temperature: 1,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 64),
        tools: tools,
      );

      final toolsArr = (body['tools'] as List).cast<Map<String, dynamic>>();
      final funcDecl =
          (toolsArr.first['functionDeclarations'] as List).first
              as Map<String, dynamic>;
      final params = funcDecl['parameters'] as Map<String, dynamic>;
      expect(params.containsKey('additionalProperties'), isFalse);
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

    test('converts user message with content parts including image', () {
      final messages = [
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.parts([
            ChatCompletionMessageContentPart.text(text: 'Describe this: '),
            ChatCompletionMessageContentPart.image(
              imageUrl: ChatCompletionMessageImageUrl(
                url: 'data:image/png;base64,abc123',
              ),
            ),
          ]),
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
      final parts = (contents.first['parts'] as List)
          .cast<Map<String, dynamic>>();
      // Text and image placeholder should be concatenated
      expect(parts.first['text'], contains('Describe this:'));
      expect(parts.first['text'], contains('[image]'));
    });

    test('converts user message with audio content part', () {
      final messages = [
        const ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.parts([
            ChatCompletionMessageContentPart.text(text: 'Transcribe: '),
            ChatCompletionMessageContentPart.audio(
              inputAudio: ChatCompletionMessageInputAudio(
                data: 'base64audiodata',
                format: ChatCompletionMessageInputAudioFormat.wav,
              ),
            ),
          ]),
        ),
      ];

      final body = GeminiUtils.buildMultiTurnRequestBody(
        messages: messages,
        temperature: 0.7,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 256),
      );

      final contents = (body['contents'] as List).cast<Map<String, dynamic>>();
      final parts = (contents.first['parts'] as List)
          .cast<Map<String, dynamic>>();
      expect(parts.first['text'], contains('Transcribe:'));
      expect(parts.first['text'], contains('[audio]'));
    });

    test('skips developer messages (not supported by Gemini)', () {
      final messages = [
        const ChatCompletionMessage.developer(
          content: ChatCompletionDeveloperMessageContent.text(
            'Developer instructions',
          ),
        ),
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
      // Should only have user message, developer is skipped
      expect(contents.length, 1);
      expect(contents.first['role'], 'user');
    });

    test('handles function message with null content', () {
      final messages = [
        const ChatCompletionMessage.function(
          name: 'my_function',
          content: null,
        ),
      ];

      final body = GeminiUtils.buildMultiTurnRequestBody(
        messages: messages,
        temperature: 0.7,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 256),
      );

      final contents = (body['contents'] as List).cast<Map<String, dynamic>>();
      expect(contents.length, 1);
      final parts = (contents.first['parts'] as List)
          .cast<Map<String, dynamic>>();
      final funcResponse = parts.first['functionResponse'] as Map;
      expect(funcResponse['name'], 'my_function');
      // Should use empty string for null content
      expect((funcResponse['response'] as Map)['result'], '');
    });

    test('falls back to toolCallId when function name not in mapping', () {
      // Tool response without corresponding assistant message
      final messages = [
        const ChatCompletionMessage.tool(
          toolCallId: 'unknown-id',
          content: 'Result',
        ),
      ];

      final body = GeminiUtils.buildMultiTurnRequestBody(
        messages: messages,
        temperature: 0.7,
        thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 256),
      );

      final contents = (body['contents'] as List).cast<Map<String, dynamic>>();
      final parts = (contents.first['parts'] as List)
          .cast<Map<String, dynamic>>();
      final funcResponse = parts.first['functionResponse'] as Map;
      // Should fall back to toolCallId when name not in mapping
      expect(funcResponse['name'], 'unknown-id');
    });

    // ── Property: every assistant tool call surfaces as a functionCall part
    // and every tool response resolves its name through the id mapping. ────
    final toolCallCounts = [1, 2, 3, 5];
    for (final count in toolCallCounts) {
      test('all $count assistant tool calls produce functionCall parts', () {
        final toolCalls = List.generate(
          count,
          (i) => ChatCompletionMessageToolCall(
            id: 'call-$i',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'fn_$i',
              arguments: '{"n": $i}',
            ),
          ),
        );
        final messages = <ChatCompletionMessage>[
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('go'),
          ),
          ChatCompletionMessage.assistant(toolCalls: toolCalls),
          for (var i = 0; i < count; i++)
            ChatCompletionMessage.tool(
              toolCallId: 'call-$i',
              content: 'result $i',
            ),
        ];

        final body = GeminiUtils.buildMultiTurnRequestBody(
          messages: messages,
          temperature: 0.5,
          thinkingConfig: const GeminiThinkingConfig(thinkingBudget: 64),
        );

        final contents = (body['contents'] as List)
            .cast<Map<String, dynamic>>();
        final modelParts = contents
            .where((c) => c['role'] == 'model')
            .expand((c) => (c['parts'] as List).cast<Map<String, dynamic>>())
            .where((part) => part.containsKey('functionCall'))
            .map((part) => part['functionCall'] as Map<String, dynamic>)
            .toList();
        // Every tool call became a functionCall part with its name and args.
        expect(modelParts, hasLength(count));
        for (var i = 0; i < count; i++) {
          expect(
            modelParts.map((p) => p['name']),
            contains('fn_$i'),
          );
        }

        // Every tool response resolved its function name via the id mapping.
        final responseParts = contents
            .expand((c) => (c['parts'] as List).cast<Map<String, dynamic>>())
            .where((part) => part.containsKey('functionResponse'))
            .map((part) => part['functionResponse'] as Map<String, dynamic>)
            .toList();
        expect(responseParts, hasLength(count));
        for (var i = 0; i < count; i++) {
          expect(responseParts.map((p) => p['name']), contains('fn_$i'));
        }
      });
    }
  });

  group('GeminiUtils.buildImageGenerationRequestBody', () {
    test('creates request with prompt and image output modalities', () {
      final body = GeminiUtils.buildImageGenerationRequestBody(
        prompt: 'A beautiful sunset over mountains',
      );

      expect(body['contents'], isA<List<dynamic>>());
      final contents = (body['contents'] as List).cast<Map<String, dynamic>>();
      expect(contents.length, 1);
      expect(contents.first['role'], 'user');

      final parts = (contents.first['parts'] as List)
          .cast<Map<String, dynamic>>();
      expect(parts.first['text'], 'A beautiful sunset over mountains');

      final generationConfig = body['generationConfig'] as Map<String, dynamic>;
      expect(generationConfig['responseModalities'], ['IMAGE', 'TEXT']);
      final imageConfig =
          generationConfig['imageConfig'] as Map<String, dynamic>;
      expect(imageConfig['aspectRatio'], '16:9');
    });

    test('includes system instruction when provided', () {
      final body = GeminiUtils.buildImageGenerationRequestBody(
        prompt: 'Generate an image',
        systemMessage: 'You are an image generator',
      );

      expect(body.containsKey('systemInstruction'), isTrue);
      final systemInstruction =
          body['systemInstruction'] as Map<String, dynamic>;
      expect(systemInstruction['role'], 'system');

      final parts = (systemInstruction['parts'] as List)
          .cast<Map<String, dynamic>>();
      expect(parts.first['text'], 'You are an image generator');
    });

    test('omits system instruction when empty', () {
      final body = GeminiUtils.buildImageGenerationRequestBody(
        prompt: 'Generate an image',
        systemMessage: '   ',
      );

      expect(body.containsKey('systemInstruction'), isFalse);
    });

    test('omits system instruction when null', () {
      final body = GeminiUtils.buildImageGenerationRequestBody(
        prompt: 'Generate an image',
      );

      expect(body.containsKey('systemInstruction'), isFalse);
    });

    test('uses 16:9 aspect ratio for cover art in imageConfig', () {
      final body = GeminiUtils.buildImageGenerationRequestBody(
        prompt: 'Generate cover art',
      );

      final generationConfig = body['generationConfig'] as Map<String, dynamic>;
      final imageConfig =
          generationConfig['imageConfig'] as Map<String, dynamic>;
      expect(imageConfig['aspectRatio'], '16:9');
    });

    test('uses 2K resolution for Full HD quality in imageConfig', () {
      final body = GeminiUtils.buildImageGenerationRequestBody(
        prompt: 'Generate cover art',
      );

      final generationConfig = body['generationConfig'] as Map<String, dynamic>;
      final imageConfig =
          generationConfig['imageConfig'] as Map<String, dynamic>;
      expect(imageConfig['imageSize'], '2K');
    });

    test('imageConfig contains both aspectRatio and imageSize', () {
      final body = GeminiUtils.buildImageGenerationRequestBody(
        prompt: 'Generate a beautiful landscape',
      );

      final generationConfig = body['generationConfig'] as Map<String, dynamic>;
      expect(generationConfig.containsKey('imageConfig'), isTrue);

      final imageConfig =
          generationConfig['imageConfig'] as Map<String, dynamic>;
      expect(imageConfig.length, 2);
      expect(imageConfig['aspectRatio'], '16:9');
      expect(imageConfig['imageSize'], '2K');
    });

    test('includes reference images as inline_data parts', () {
      final refImages = [
        const ProcessedReferenceImage(
          base64Data: 'abc123',
          mimeType: 'image/png',
          originalId: 'img-1',
        ),
      ];
      final body = GeminiUtils.buildImageGenerationRequestBody(
        prompt: 'Generate image',
        referenceImages: refImages,
      );

      final contents = (body['contents'] as List).cast<Map<String, dynamic>>();
      final parts = (contents.first['parts'] as List)
          .cast<Map<String, dynamic>>();

      // Should have 2 parts: 1 reference image + 1 text prompt
      expect(parts.length, 2);

      // First part should be the inline_data
      expect(parts[0].containsKey('inline_data'), isTrue);
      final inlineData = parts[0]['inline_data'] as Map<String, dynamic>;
      expect(inlineData['mime_type'], 'image/png');
      expect(inlineData['data'], 'abc123');

      // Second part should be the text prompt
      expect(parts[1]['text'], 'Generate image');
    });

    test('includes multiple reference images in order', () {
      final refImages = [
        const ProcessedReferenceImage(
          base64Data: 'data1',
          mimeType: 'image/jpeg',
          originalId: 'img-1',
        ),
        const ProcessedReferenceImage(
          base64Data: 'data2',
          mimeType: 'image/png',
          originalId: 'img-2',
        ),
        const ProcessedReferenceImage(
          base64Data: 'data3',
          mimeType: 'image/webp',
          originalId: 'img-3',
        ),
      ];
      final body = GeminiUtils.buildImageGenerationRequestBody(
        prompt: 'Generate with references',
        referenceImages: refImages,
      );

      final contents = (body['contents'] as List).cast<Map<String, dynamic>>();
      final parts = (contents.first['parts'] as List)
          .cast<Map<String, dynamic>>();

      // Should have 4 parts: 3 reference images + 1 text prompt
      expect(parts.length, 4);

      // Verify images come before text and are in order
      expect(
        (parts[0]['inline_data'] as Map)['mime_type'],
        'image/jpeg',
      );
      expect(
        (parts[1]['inline_data'] as Map)['mime_type'],
        'image/png',
      );
      expect(
        (parts[2]['inline_data'] as Map)['mime_type'],
        'image/webp',
      );
      expect(parts[3]['text'], 'Generate with references');
    });

    test('works with empty reference images list', () {
      final body = GeminiUtils.buildImageGenerationRequestBody(
        prompt: 'Generate without references',
        referenceImages: [],
      );

      final contents = (body['contents'] as List).cast<Map<String, dynamic>>();
      final parts = (contents.first['parts'] as List)
          .cast<Map<String, dynamic>>();

      // Should have only text prompt
      expect(parts.length, 1);
      expect(parts[0]['text'], 'Generate without references');
    });

    test('combines reference images with system message', () {
      final refImages = [
        const ProcessedReferenceImage(
          base64Data: 'refdata',
          mimeType: 'image/png',
          originalId: 'ref-1',
        ),
      ];
      final body = GeminiUtils.buildImageGenerationRequestBody(
        prompt: 'Generate with style',
        systemMessage: 'Use artistic style',
        referenceImages: refImages,
      );

      // Verify reference images are in content
      final contents = (body['contents'] as List).cast<Map<String, dynamic>>();
      final parts = (contents.first['parts'] as List)
          .cast<Map<String, dynamic>>();
      expect(parts.length, 2);
      expect(parts[0].containsKey('inline_data'), isTrue);

      // Verify system instruction is present
      expect(body.containsKey('systemInstruction'), isTrue);
      final systemInstruction =
          body['systemInstruction'] as Map<String, dynamic>;
      final systemParts = (systemInstruction['parts'] as List)
          .cast<Map<String, dynamic>>();
      expect(systemParts.first['text'], 'Use artistic style');
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

    test('handles data: with JSON payload on same line', () {
      const input = 'data: {"result": 123}\nmore data';
      final out = GeminiUtils.stripLeadingFraming(input);
      expect(out, startsWith('{"result"'));
    });

    test('handles data: with array payload on same line', () {
      const input = 'data: [{"a":1}]\nmore';
      final out = GeminiUtils.stripLeadingFraming(input);
      expect(out, startsWith('{"a"'));
    });

    test('drops empty data: lines', () {
      const input = 'data:\ndata: \n{"result": true}';
      final out = GeminiUtils.stripLeadingFraming(input);
      expect(out, startsWith('{"result"'));
    });

    test('drops non-JSON data: lines like comments/heartbeats', () {
      const input = 'data: ping\ndata: heartbeat\n{"ok": true}';
      final out = GeminiUtils.stripLeadingFraming(input);
      expect(out, startsWith('{"ok"'));
    });

    test('strips closing bracket and comma', () {
      const input = '],{"next": 1}';
      final out = GeminiUtils.stripLeadingFraming(input);
      expect(out, startsWith('{"next"'));
    });

    test('handles multiple leading whitespace and brackets', () {
      const input = '   [  ,  {"data": "value"}';
      final out = GeminiUtils.stripLeadingFraming(input);
      expect(out, startsWith('{"data"'));
    });

    glados.Glados(
      glados.any.geminiFramingScenario,
      // 120 runs: GeminiStreamParser has a complementary property suite, so the
      // upper-bound 180 here bought little extra coverage (review speed item).
      glados.ExploreConfig(numRuns: 120),
    ).test('matches generated SSE and JSON array framing semantics', (
      scenario,
    ) {
      expect(
        GeminiUtils.stripLeadingFraming(scenario.input),
        scenario.expected,
        reason: '$scenario',
      );
    }, tags: 'glados');
  });

  group('URI builder properties', () {
    // Generated (scheme, port, model-shape) tuples assert the structural
    // invariants of _buildGeminiUri: scheme/host/port preserved (with the
    // https default), and the path always /v1beta/models/<model>:<endpoint>.
    // Schemeless base URLs are outside the contract: Uri.parse treats
    // 'example.com' as a path (empty host), so callers always pass a scheme;
    // the https default only fires for protocol-relative '//host' inputs,
    // covered by the explicit case below.
    final schemes = ['http', 'https'];
    final ports = [null, 8080];
    final models = [
      'gemini-pro',
      'models/gemini-pro',
      'gemini-pro/',
      ' gemini-pro ',
      'models/gemini-2.5-flash/',
    ];
    for (final scheme in schemes) {
      for (final port in ports) {
        for (final model in models) {
          test(
            'scheme="$scheme" port=$port model="$model" '
            'yields canonical URI shape',
            () {
              final hostPart = port == null
                  ? 'example.com'
                  : 'example.com:$port';
              final base = '$scheme://$hostPart';

              final streamUri = GeminiUtils.buildStreamGenerateContentUri(
                baseUrl: base,
                model: model,
                apiKey: 'k',
              );
              final plainUri = GeminiUtils.buildGenerateContentUri(
                baseUrl: base,
                model: model,
                apiKey: 'k',
              );

              for (final (uri, endpoint) in [
                (streamUri, 'streamGenerateContent'),
                (plainUri, 'generateContent'),
              ]) {
                expect(uri.scheme, scheme);
                expect(uri.host, 'example.com');
                if (port != null) expect(uri.port, port);
                expect(
                  uri.path,
                  matches(RegExp('^/v1beta/models/[^/]+:$endpoint\$')),
                );
                expect(uri.path, isNot(contains('models/models/')));
                expect(uri.path, isNot(endsWith('/')));
                expect(uri.queryParameters['key'], 'k');
              }
            },
          );
        }
      }
    }

    test('protocol-relative base URL defaults to https', () {
      final uri = GeminiUtils.buildGenerateContentUri(
        baseUrl: '//example.com',
        model: 'gemini-pro',
        apiKey: 'k',
      );
      expect(uri.scheme, 'https');
      expect(uri.host, 'example.com');
      expect(uri.path, '/v1beta/models/gemini-pro:generateContent');
    });
  });
}
