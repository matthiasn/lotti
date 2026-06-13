import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_request_helpers.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  const helpers = CloudInferenceRequestHelpers();

  CreateChatCompletionStreamResponse chunk(String content) {
    return CreateChatCompletionStreamResponse(
      id: 'response-id',
      choices: [
        ChatCompletionStreamResponseChoice(
          delta: ChatCompletionStreamResponseDelta(content: content),
          index: 0,
        ),
      ],
      object: 'chat.completion.chunk',
      created: DateTime(2024, 3, 15).millisecondsSinceEpoch ~/ 1000,
    );
  }

  group('createBaseRequest tool-choice resolution', () {
    test('explicit toolChoice is forwarded verbatim', () {
      const explicit = ChatCompletionToolChoiceOption.mode(
        ChatCompletionToolChoiceMode.none,
      );
      final request = helpers.createBaseRequest(
        messages: const [],
        model: 'gpt-4',
        toolChoice: explicit,
      );
      expect(request.toolChoice, explicit);
    });

    test('non-empty tools without explicit choice defaults to auto', () {
      final request = helpers.createBaseRequest(
        messages: const [],
        model: 'gpt-4',
        tools: const [
          ChatCompletionTool(
            type: ChatCompletionToolType.function,
            function: FunctionObject(name: 'do_thing'),
          ),
        ],
      );
      expect(
        request.toolChoice,
        const ChatCompletionToolChoiceOption.mode(
          ChatCompletionToolChoiceMode.auto,
        ),
      );
    });

    test('empty tools list leaves toolChoice null', () {
      final request = helpers.createBaseRequest(
        messages: const [],
        model: 'gpt-4',
        tools: const [],
      );
      expect(request.toolChoice, isNull);
    });

    test('forwards scalar request fields and default stream flag', () {
      final request = helpers.createBaseRequest(
        messages: const [],
        model: 'gpt-4o',
        temperature: 0.3,
        maxCompletionTokens: 128,
        maxTokens: 256,
        reasoningEffort: ReasoningEffort.high,
      );
      expect(request.model.toString(), contains('gpt-4o'));
      expect(request.temperature, 0.3);
      expect(request.maxCompletionTokens, 128);
      expect(request.maxTokens, 256);
      expect(request.reasoningEffort, ReasoningEffort.high);
      expect(request.stream, isTrue);
    });
  });

  group('geminiReasoningEffort', () {
    test('maps modes directly for Gemini 3 Flash (no collapsing)', () {
      const flash = 'models/gemini-3-flash-preview';
      expect(
        helpers.geminiReasoningEffort(flash, GeminiThinkingMode.minimal),
        ReasoningEffort.minimal,
      );
      expect(
        helpers.geminiReasoningEffort(flash, GeminiThinkingMode.medium),
        ReasoningEffort.medium,
      );
    });

    test('collapses unsupported modes for non-Flash Gemini 3 Pro', () {
      const pro = 'models/gemini-3.1-pro-preview';
      // Pro only accepts low/high; minimal collapses to low, medium to high.
      expect(
        helpers.geminiReasoningEffort(pro, GeminiThinkingMode.minimal),
        ReasoningEffort.low,
      );
      expect(
        helpers.geminiReasoningEffort(pro, GeminiThinkingMode.medium),
        ReasoningEffort.high,
      );
    });
  });

  group('resolveGeminiThinkingConfig', () {
    test('captures thoughts when the resolved budget is non-zero', () {
      final config = helpers.resolveGeminiThinkingConfig(
        mode: GeminiThinkingMode.high,
      );
      expect(config.thinkingBudget, isNot(0));
      expect(config.includeThoughts, isTrue);
    });

    test('does not capture thoughts when budget is zero (minimal mode)', () {
      final config = helpers.resolveGeminiThinkingConfig(
        mode: GeminiThinkingMode.minimal,
      );
      // minimal maps to a zero thinking budget, which disables thought capture.
      expect(config.thinkingBudget, 0);
      expect(config.includeThoughts, isFalse);
    });
  });

  group('filterAnthropicPings', () {
    test('swallows Anthropic ping errors and keeps valid chunks', () async {
      final source = Stream<CreateChatCompletionStreamResponse>.multi((c) {
        c
          ..add(chunk('first'))
          ..addError(
            "type 'Null' is not a subtype of type 'List<dynamic>' "
            'in type cast (choices)',
          )
          ..add(chunk('second'))
          ..close();
      });

      final result = await helpers.filterAnthropicPings(source).toList();

      expect(result, hasLength(2));
      expect(result[0].choices?.first.delta?.content, 'first');
      expect(result[1].choices?.first.delta?.content, 'second');
    });

    test('propagates non-Anthropic errors downstream', () {
      final source = Stream<CreateChatCompletionStreamResponse>.multi((c) {
        c
          ..add(chunk('only'))
          ..addError('Network error: Connection refused')
          ..close();
      });

      expect(
        helpers.filterAnthropicPings(source).toList(),
        throwsA(equals('Network error: Connection refused')),
      );
    });
  });
}
