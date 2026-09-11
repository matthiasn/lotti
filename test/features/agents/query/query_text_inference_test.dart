import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/query/query_text_inference.dart';
import 'package:lotti/features/ai/model/inference.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../ai_consumption/test_utils.dart';
import '../test_data/ai_config_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);
  test(
    'owned resources cancel immediately and can detach after completion',
    () {
      final token = QueryCancellation();
      var closed = 0;
      final detach = token.onCancel(() => closed++);
      detach();
      token
        ..onCancel(() => closed += 10)
        ..cancel();
      expect(closed, 10);
      token.onCancel(() => closed += 100);
      expect(closed, 110);
    },
  );
  test(
    'each sub-query sends only its supplied context and parses streamed JSON',
    () async {
      final inputs = <Map<String, dynamic>>[];
      final inference = QueryTextInference(
        generate: (system, prompt) {
          inputs.add(jsonDecode(prompt) as Map<String, dynamic>);
          return Stream.fromIterable([
            '<think>checking</think>```json\n',
            '{"quote":',
            '"Keep the feeder."}',
            '\n```',
          ]);
        },
      );
      final first = await inference.complete(
        system: 'inspect',
        input: {'source': 'first'},
        cancellation: QueryCancellation(),
      );
      await inference.complete(
        system: 'inspect',
        input: {'source': 'second'},
        cancellation: QueryCancellation(),
      );
      expect(first['quote'], 'Keep the feeder.');
      expect(inputs, [
        {'source': 'first'},
        {'source': 'second'},
      ]);
    },
  );

  test(
    'cancellation stops an idle stream without affecting another request',
    () async {
      var stopped = false;
      final controller = StreamController<String>(
        onCancel: () {
          stopped = true;
        },
      );
      final token = QueryCancellation();
      final response = token.collect(controller.stream);
      final assertion = expectLater(response, throwsA(isA<QueryCancelled>()));
      token.cancel();
      await assertion;
      await controller.close();
      expect(stopped, isTrue);
      expect(token.isCancelled, isTrue);
      expect(
        await QueryCancellation().collect(Stream.value('other chat')),
        'other chat',
      );
    },
  );

  test('cancellation before sending prevents the backend call', () async {
    var calls = 0;
    final inference = QueryTextInference(
      generate: (_, _) {
        calls++;
        return Stream.value('{}');
      },
    );
    final token = QueryCancellation()..cancel();
    await expectLater(
      inference.complete(system: 'inspect', input: {}, cancellation: token),
      throwsA(isA<QueryCancelled>()),
    );
    expect(calls, 0);
  });

  test(
    'malformed output fails instead of becoming an unverified answer',
    () async {
      final inference = QueryTextInference(
        generate: (_, _) => Stream.value('probably yes'),
      );
      await expectLater(
        inference.complete(
          system: 'inspect',
          input: {},
          cancellation: QueryCancellation(),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'profile routing records per-chat usage while retaining isolated prompts',
    () async {
      final cloud = MockCloudInferenceRepository();
      final provider = testInferenceProvider();
      final attribution = AiInteractionCaptureTestBench.create();
      final prompts = <String>[];
      when(
        () => cloud.generate(
          any(),
          model: 'query-model',
          temperature: 0.2,
          baseUrl: provider.baseUrl,
          apiKey: provider.apiKey,
          provider: provider,
          systemMessage: 'inspect',
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          geminiThinkingMode: any(named: 'geminiThinkingMode'),
          impactCollector: any(named: 'impactCollector'),
        ),
      ).thenAnswer((call) {
        prompts.add(call.positionalArguments.first as String);
        return Stream.fromIterable([
          const LottiInferenceChunk(
            id: 'chunk',
            created: 0,
            choices: [
              LottiChunkChoice(
                index: 0,
                delta: LottiDelta(content: '{"passages":[]}'),
              ),
            ],
          ),
          const LottiInferenceChunk(
            id: 'usage',
            created: 0,
            choices: [],
            usage: LottiUsage(
              promptTokens: 60,
              completionTokens: 15,
              totalTokens: 75,
              cachedInputTokens: 10,
              reasoningTokens: 4,
            ),
          ),
        ]);
      });
      final inference = QueryTextInference.forProfile(
        cloud: cloud,
        profile: ResolvedProfile(
          thinkingModelId: 'query-model',
          thinkingProvider: provider,
          thinkingModel: testAiModel(id: 'query-config'),
        ),
        agentId: 'agent',
        chatId: 'chat',
        taskId: 'task',
        categoryId: 'category',
        capture: attribution.capture,
      );
      expect(
        await inference.complete(
          system: 'inspect',
          input: {'source': 'Only this meeting'},
          cancellation: QueryCancellation(),
        ),
        {'passages': <Object>[]},
      );
      expect(prompts, [
        jsonEncode({'source': 'Only this meeting'}),
      ]);
      final event = attribution.recordedInteractions.single;
      expect(event.providerModelId, 'query-model');
      expect(event.configId, provider.id);
      expect(event.modelId, 'query-config');
      expect(event.agentId, 'agent');
      expect(event.threadId, 'chat');
      expect(event.inputTokens, 60);
      expect(event.outputTokens, 15);
      expect(event.cachedInputTokens, 10);
      expect(event.thoughtsTokens, 4);
    },
  );

  test(
    'oversized and failed streams reject the response and release subscriptions',
    () async {
      await expectLater(
        QueryCancellation().collect(Stream.value('x' * 64001)),
        throwsFormatException,
      );
      final error = StateError('inference disconnected');
      await expectLater(
        QueryCancellation().collect(Stream.error(error)),
        throwsA(same(error)),
      );
      await expectLater(
        QueryTextInference(generate: (_, _) => Stream.value('[]')).complete(
          system: 'inspect',
          input: {},
          cancellation: QueryCancellation(),
        ),
        throwsFormatException,
      );
    },
  );

  test('a silent backend times out and cancels its subscription', () {
    fakeAsync((async) {
      var cancelled = false;
      final cleanup = Completer<void>();
      final stream = StreamController<String>(
        onCancel: () {
          cancelled = true;
          return cleanup.future;
        },
      );
      Object? failure;
      QueryCancellation()
          .collect(stream.stream)
          .then<void>(
            (_) => fail('A silent backend must not produce a reply'),
            onError: (Object error) {
              failure = error;
            },
          );
      async
        ..flushMicrotasks()
        ..elapse(const Duration(minutes: 2))
        ..flushMicrotasks();
      expect(cancelled, isTrue);
      expect(failure, isNull, reason: 'The request awaits stream cleanup');
      cleanup.complete();
      async.flushMicrotasks();
      expect(failure, isA<TimeoutException>());
      unawaited(stream.close());
      async.flushMicrotasks();
    });
  });
}
