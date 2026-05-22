import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_chat_message.dart';
import 'package:lotti/features/ai/model/ai_chat_message_json.dart';

void main() {
  group('AiChatMessage.toJson', () {
    test('system message', () {
      const msg = AiSystemMessage('You are a helpful assistant.');
      expect(msg.toJson(), {
        'role': 'system',
        'content': 'You are a helpful assistant.',
      });
    });

    test('user message with plain text', () {
      const msg = AiUserMessage(AiUserTextContent('hello'));
      expect(msg.toJson(), {
        'role': 'user',
        'content': 'hello',
      });
    });

    test('user message with multi-modal parts', () {
      const msg = AiUserMessage(
        AiUserPartsContent([
          AiTextPart('describe this'),
          AiImagePart('data:image/jpeg;base64,abc'),
          AiAudioPart(data: 'b64audio', format: AiAudioFormat.mp3),
        ]),
      );
      expect(msg.toJson(), {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': 'describe this'},
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,abc'},
          },
          {
            'type': 'input_audio',
            'input_audio': {'data': 'b64audio', 'format': 'mp3'},
          },
        ],
      });
    });

    test('assistant message with content only', () {
      const msg = AiAssistantMessage(content: 'sure!');
      expect(msg.toJson(), {'role': 'assistant', 'content': 'sure!'});
    });

    test('assistant message with tool calls only', () {
      const msg = AiAssistantMessage(
        toolCalls: [
          AiToolCall(
            id: 'call_1',
            name: 'get_weather',
            arguments: '{"city":"Berlin"}',
          ),
        ],
      );
      expect(msg.toJson(), {
        'role': 'assistant',
        'tool_calls': [
          {
            'id': 'call_1',
            'type': 'function',
            'function': {
              'name': 'get_weather',
              'arguments': '{"city":"Berlin"}',
            },
          },
        ],
      });
    });

    test('assistant message with both content and tool calls', () {
      const msg = AiAssistantMessage(
        content: 'looking up',
        toolCalls: [
          AiToolCall(id: 'call_1', name: 'lookup', arguments: '{}'),
        ],
      );
      final json = msg.toJson();
      expect(json['role'], 'assistant');
      expect(json['content'], 'looking up');
      expect(json['tool_calls'], isA<List<dynamic>>());
    });

    test('assistant message with empty tool calls omits the field', () {
      const msg = AiAssistantMessage(content: 'hi', toolCalls: []);
      final json = msg.toJson();
      expect(json.containsKey('tool_calls'), isFalse);
    });

    test('tool result message', () {
      const msg = AiToolResultMessage(
        toolCallId: 'call_1',
        content: '{"temp":12}',
      );
      expect(msg.toJson(), {
        'role': 'tool',
        'tool_call_id': 'call_1',
        'content': '{"temp":12}',
      });
    });
  });

  group('AiTool.toJson', () {
    test('serializes function definition', () {
      const tool = AiTool(
        name: 'get_weather',
        description: 'Get current weather',
        parameters: {
          'type': 'object',
          'properties': {
            'city': {'type': 'string'},
          },
          'required': ['city'],
        },
      );
      expect(tool.toJson(), {
        'type': 'function',
        'function': {
          'name': 'get_weather',
          'description': 'Get current weather',
          'parameters': {
            'type': 'object',
            'properties': {
              'city': {'type': 'string'},
            },
            'required': ['city'],
          },
        },
      });
    });
  });

  group('AiToolChoice.toJson', () {
    test('auto → "auto"', () {
      expect(const AiToolChoiceAuto().toJson(), 'auto');
    });
    test('none → "none"', () {
      expect(const AiToolChoiceNone().toJson(), 'none');
    });
    test('required → "required"', () {
      expect(const AiToolChoiceRequired().toJson(), 'required');
    });
    test('function(name) → typed object', () {
      expect(const AiToolChoiceFunction('update_report').toJson(), {
        'type': 'function',
        'function': {'name': 'update_report'},
      });
    });
  });

  group('aiStreamChunkFromJson', () {
    test('parses content delta', () {
      final chunk = aiStreamChunkFromJson({
        'id': 'cmpl-1',
        'object': 'chat.completion.chunk',
        'created': 100,
        'model': 'gpt-4',
        'choices': [
          {
            'index': 0,
            'delta': {'role': 'assistant', 'content': 'Hello'},
            'finish_reason': null,
          },
        ],
      });
      expect(chunk, isNotNull);
      expect(chunk!.id, 'cmpl-1');
      expect(chunk.model, 'gpt-4');
      expect(chunk.created, 100);
      expect(chunk.choices, hasLength(1));
      final choice = chunk.choices.first;
      expect(choice.index, 0);
      expect(choice.delta.content, 'Hello');
      expect(choice.delta.role, AiMessageRole.assistant);
      expect(choice.finishReason, isNull);
    });

    test('returns null for empty choices (Anthropic ping shape)', () {
      final chunk = aiStreamChunkFromJson({
        'id': 'ping',
        'object': 'ping',
      });
      expect(chunk, isNull);
    });

    test('returns null when choices list is present but empty', () {
      final chunk = aiStreamChunkFromJson({'id': 'x', 'choices': <dynamic>[]});
      expect(chunk, isNull);
    });

    test('flattens Mistral-style array content into a string', () {
      final chunk = aiStreamChunkFromJson({
        'id': '1',
        'choices': [
          {
            'index': 0,
            'delta': {
              'content': [
                {'type': 'text', 'text': 'Hel'},
                {'type': 'text', 'text': 'lo'},
              ],
            },
          },
        ],
      });
      expect(chunk!.choices.first.delta.content, 'Hello');
    });

    test('parses tool call chunks with id, name, arguments delta', () {
      final chunk = aiStreamChunkFromJson({
        'id': '1',
        'choices': [
          {
            'index': 0,
            'delta': {
              'tool_calls': [
                {
                  'index': 0,
                  'id': 'call_a',
                  'function': {'name': 'get_weather', 'arguments': '{"ci'},
                },
              ],
            },
          },
        ],
      });
      final toolCalls = chunk!.choices.first.delta.toolCalls!;
      expect(toolCalls, hasLength(1));
      expect(toolCalls.first.id, 'call_a');
      expect(toolCalls.first.index, 0);
      expect(toolCalls.first.name, 'get_weather');
      expect(toolCalls.first.arguments, '{"ci');
    });

    test('parses finish_reason and preserves raw provider value', () {
      final chunk = aiStreamChunkFromJson({
        'id': '1',
        'choices': [
          {
            'index': 0,
            'delta': <String, dynamic>{},
            'finish_reason': 'tool_calls',
          },
        ],
      });
      expect(chunk!.choices.first.finishReason, 'tool_calls');
    });

    test('parses usage when present, with null-tolerant fields', () {
      final chunk = aiStreamChunkFromJson({
        'id': '1',
        'choices': [
          {
            'index': 0,
            'delta': {'content': ''},
          },
        ],
        'usage': {
          'prompt_tokens': 10,
          'completion_tokens': 5,
          // total_tokens intentionally omitted
        },
      });
      expect(chunk!.usage, isNotNull);
      expect(chunk.usage!.promptTokens, 10);
      expect(chunk.usage!.completionTokens, 5);
      expect(chunk.usage!.totalTokens, isNull);
    });

    test('falls back to default index when delta lacks index', () {
      final chunk = aiStreamChunkFromJson({
        'id': '1',
        'choices': [
          {
            'delta': {'content': 'x'},
          },
        ],
      });
      expect(chunk!.choices.first.index, 0);
    });
  });

  group('AiMessageRole.tryParse', () {
    test('parses known wire values', () {
      expect(AiMessageRole.tryParse('system'), AiMessageRole.system);
      expect(AiMessageRole.tryParse('user'), AiMessageRole.user);
      expect(AiMessageRole.tryParse('assistant'), AiMessageRole.assistant);
      expect(AiMessageRole.tryParse('tool'), AiMessageRole.tool);
      expect(AiMessageRole.tryParse('function'), AiMessageRole.function);
      expect(AiMessageRole.tryParse('developer'), AiMessageRole.developer);
    });

    test('returns null for unknown values', () {
      expect(AiMessageRole.tryParse('robot'), isNull);
      expect(AiMessageRole.tryParse(''), isNull);
    });
  });
}
