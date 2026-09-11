import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference.dart';
import 'package:lotti/features/ai/repository/cloud_inference_request_helpers.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  const helpers = CloudInferenceRequestHelpers();

  LottiInferenceChunk chunk(String content) {
    return LottiInferenceChunk(
      id: 'response-id',
      created: DateTime(2024, 3, 15).millisecondsSinceEpoch ~/ 1000,
      choices: [
        LottiChunkChoice(index: 0, delta: LottiDelta(content: content)),
      ],
    );
  }

  group('createBaseRequest tool-choice resolution', () {
    test('explicit toolChoice is forwarded verbatim', () {
      const explicit = LottiToolChoice.none();
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
          LottiTool(name: 'do_thing'),
        ],
      );
      expect(
        request.toolChoice,
        const LottiToolChoice.auto(),
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
        reasoningEffort: LottiReasoningEffort.high,
      );
      expect(request.model, contains('gpt-4o'));
      expect(request.temperature, 0.3);
      expect(request.maxCompletionTokens, 128);
      expect(request.maxTokens, 256);
      expect(request.reasoningEffort, LottiReasoningEffort.high);
    });
  });

  group('geminiReasoningEffort', () {
    test('maps modes directly for Gemini 3 Flash (no collapsing)', () {
      const flash = 'models/gemini-3-flash-preview';
      expect(
        helpers.geminiReasoningEffort(flash, GeminiThinkingMode.minimal),
        LottiReasoningEffort.minimal,
      );
      expect(
        helpers.geminiReasoningEffort(flash, GeminiThinkingMode.medium),
        LottiReasoningEffort.medium,
      );
    });

    test('collapses unsupported modes for non-Flash Gemini 3 Pro', () {
      const pro = 'models/gemini-3.1-pro-preview';
      // Pro only accepts low/high; minimal collapses to low, medium to high.
      expect(
        helpers.geminiReasoningEffort(pro, GeminiThinkingMode.minimal),
        LottiReasoningEffort.low,
      );
      expect(
        helpers.geminiReasoningEffort(pro, GeminiThinkingMode.medium),
        LottiReasoningEffort.high,
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
      final source = Stream<LottiInferenceChunk>.multi((c) {
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

    test(
      "swallows the current client's parse failure for a ping frame",
      () async {
        // The pre-1.0 client threw a raw cast error here; the current one
        // raises a typed parse failure. Matching only the old spelling would
        // have let this protection lapse silently across the upgrade.
        final source = Stream<LottiInferenceChunk>.multi((c) {
          c
            ..add(chunk('first'))
            ..addError(
              const ParseException(message: 'Failed to parse streaming chunk'),
            )
            ..add(chunk('second'))
            ..close();
        });

        final result = await helpers.filterAnthropicPings(source).toList();

        expect(result, hasLength(2));
        expect(result[0].choices?.first.delta?.content, 'first');
        expect(result[1].choices?.first.delta?.content, 'second');
      },
    );

    test('propagates non-Anthropic errors downstream', () {
      final source = Stream<LottiInferenceChunk>.multi((c) {
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
