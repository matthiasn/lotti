import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/ai_chat_message.dart';
import 'package:lotti/features/ai/model/ai_chat_message_json.dart';

extension _AnyAiTypes on glados.Any {
  glados.Generator<AiMessageRole> get aiMessageRole =>
      glados.AnyUtils(this).choose(AiMessageRole.values);

  glados.Generator<AiAudioFormat> get aiAudioFormat =>
      glados.AnyUtils(this).choose(AiAudioFormat.values);

  glados.Generator<AiToolCall> get aiToolCall =>
      glados.CombinableAny(this).combine3(
        glados.any.letterOrDigits,
        glados.any.letterOrDigits,
        glados.any.letterOrDigits,
        (id, name, args) => AiToolCall(id: id, name: name, arguments: args),
      );

  glados.Generator<AiToolChoice> get aiToolChoice =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, 4),
        glados.any.letterOrDigits,
        (choiceIndex, name) {
          return switch (choiceIndex) {
            0 => const AiToolChoiceAuto(),
            1 => const AiToolChoiceNone(),
            2 => const AiToolChoiceRequired(),
            _ => AiToolChoiceFunction(name),
          };
        },
      );

  /// Generates an optional non-negative int via a presence toggle so we
  /// exercise both null and populated paths.
  glados.Generator<int?> get optionalTokenCount =>
      glados.CombinableAny(this).combine2(
        glados.BoolAny(this).bool,
        glados.IntAnys(this).intInRange(0, 9999),
        (present, value) => present ? value : null,
      );

  glados.Generator<AiUsage> get aiUsage => glados.CombinableAny(this).combine5(
    optionalTokenCount,
    optionalTokenCount,
    optionalTokenCount,
    optionalTokenCount,
    optionalTokenCount,
    (prompt, completion, total, reasoning, cached) => AiUsage(
      promptTokens: prompt,
      completionTokens: completion,
      totalTokens: total,
      reasoningTokens: reasoning,
      cachedInputTokens: cached,
    ),
  );
}

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

  // ===========================================================================
  // Property-based (glados) coverage — complements the example-based groups
  // above with invariants that should hold for any valid input.
  // ===========================================================================

  group('AiMessageRole.tryParse property', () {
    glados.Glados<AiMessageRole>(glados.any.aiMessageRole).test(
      'tryParse(role.wire) returns the same role for every enum value',
      (role) {
        expect(AiMessageRole.tryParse(role.wire), role);
      },
    );
  });

  group('AiAudioFormat.wire property', () {
    glados.Glados<AiAudioFormat>(glados.any.aiAudioFormat).test(
      'wire is the enum name and is stable',
      (format) {
        expect(format.wire, format.name);
      },
    );
  });

  group('AiSystemMessage.toJson property', () {
    glados.Glados<String>(glados.any.letterOrDigits).test(
      'always emits role=system and the original content',
      (content) {
        final json = AiSystemMessage(content).toJson();
        expect(json['role'], 'system');
        expect(json['content'], content);
      },
    );
  });

  group('AiUserMessage.toJson property', () {
    glados.Glados<String>(glados.any.letterOrDigits).test(
      'text content always emits role=user with the original string',
      (text) {
        final json = AiUserMessage(AiUserTextContent(text)).toJson();
        expect(json['role'], 'user');
        expect(json['content'], text);
      },
    );
  });

  group('AiAssistantMessage.toJson property', () {
    glados.Glados<AiToolCall>(glados.any.aiToolCall).test(
      'omits tool_calls when the list is empty and includes it otherwise',
      (tc) {
        final emptyJson = const AiAssistantMessage(
          content: 'hi',
          toolCalls: [],
        ).toJson();
        expect(emptyJson.containsKey('tool_calls'), isFalse);

        final withCallsJson = AiAssistantMessage(toolCalls: [tc]).toJson();
        expect(withCallsJson['role'], 'assistant');
        final calls = withCallsJson['tool_calls'] as List<dynamic>;
        expect(calls, hasLength(1));
        final first = calls.first as Map<String, dynamic>;
        expect(first['id'], tc.id);
        expect(first['type'], 'function');
        final fn = first['function'] as Map<String, dynamic>;
        expect(fn['name'], tc.name);
        expect(fn['arguments'], tc.arguments);
      },
    );
  });

  group('AiToolResultMessage.toJson property', () {
    glados.Glados2<String, String>(
      glados.any.letterOrDigits,
      glados.any.letterOrDigits,
    ).test('emits role=tool with the supplied id and content', (
      id,
      content,
    ) {
      final json = AiToolResultMessage(
        toolCallId: id,
        content: content,
      ).toJson();
      expect(json['role'], 'tool');
      expect(json['tool_call_id'], id);
      expect(json['content'], content);
    });
  });

  group('AiToolChoice.toJson property', () {
    glados.Glados<AiToolChoice>(glados.any.aiToolChoice).test(
      'auto/none/required encode as strings; function encodes as typed object',
      (choice) {
        final encoded = choice.toJson();
        switch (choice) {
          case AiToolChoiceAuto():
            expect(encoded, 'auto');
          case AiToolChoiceNone():
            expect(encoded, 'none');
          case AiToolChoiceRequired():
            expect(encoded, 'required');
          case AiToolChoiceFunction(:final name):
            expect(encoded, isA<Map<String, dynamic>>());
            final map = encoded as Map<String, dynamic>;
            expect(map['type'], 'function');
            final fn = map['function'] as Map<String, dynamic>;
            expect(fn['name'], name);
        }
      },
    );
  });

  group('aiStreamChunkFromJson — null-shape property', () {
    test('returns null when both choices and usage are absent', () {
      expect(aiStreamChunkFromJson(<String, dynamic>{}), isNull);
    });

    test('returns null when choices is empty and usage is null', () {
      expect(
        aiStreamChunkFromJson({'id': 'x', 'choices': <dynamic>[]}),
        isNull,
      );
    });
  });

  group('aiStreamChunkFromJson — usage-only round-trip', () {
    glados.Glados<AiUsage>(glados.any.aiUsage).test(
      'usage fields propagate through the decoder when usage-only event',
      (usage) {
        final wire = <String, dynamic>{
          'id': 'cmpl-usage-only',
          'usage': <String, dynamic>{
            if (usage.promptTokens != null) 'prompt_tokens': usage.promptTokens,
            if (usage.completionTokens != null)
              'completion_tokens': usage.completionTokens,
            if (usage.totalTokens != null) 'total_tokens': usage.totalTokens,
            if (usage.reasoningTokens != null)
              'completion_tokens_details': <String, dynamic>{
                'reasoning_tokens': usage.reasoningTokens,
              },
            if (usage.cachedInputTokens != null)
              'prompt_tokens_details': <String, dynamic>{
                'cached_tokens': usage.cachedInputTokens,
              },
          },
        };

        final chunk = aiStreamChunkFromJson(wire);
        expect(chunk, isNotNull);
        expect(chunk!.choices, isEmpty);
        final decoded = chunk.usage!;
        expect(decoded.promptTokens, usage.promptTokens);
        expect(decoded.completionTokens, usage.completionTokens);
        expect(decoded.totalTokens, usage.totalTokens);
        expect(decoded.reasoningTokens, usage.reasoningTokens);
        expect(decoded.cachedInputTokens, usage.cachedInputTokens);
      },
    );
  });
}
