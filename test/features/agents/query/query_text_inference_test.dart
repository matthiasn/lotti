import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/query/query_text_inference.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../ai_consumption/test_utils.dart';
import '../test_data/ai_config_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);
  for (final (minutes, offset) in [
    (120, '+02:00'),
    (345, '+05:45'),
    (-210, '-03:30'),
  ]) {
    test(
      'current clock preserves device wall date and offset $offset',
      () async {
        final location = tz.Location('test', [], [], [
          tz.TimeZone(
            Duration(minutes: minutes),
            isDst: false,
            abbreviation: 'test',
          ),
        ]);
        final now = tz.TZDateTime(location, 2026, 9, 13, 0, 5, 6);
        await withClock(Clock.fixed(now), () async {
          final input = <String, Object?>{
            'sources': [
              {'date': '2025-01-01', 'text': 'Old 🐧 report'},
            ],
            'currentTime': {'localDate': '2024-01-01'},
          };
          final original = jsonEncode(input);
          final measured = QueryTextInference.requestBytes('Inspect', input);
          final inference = QueryTextInference(
            generate: (system, prompt) {
              final supplied = jsonDecode(prompt) as Map<String, dynamic>;
              expect(supplied['currentTime'], {
                'localDate': '2026-09-13',
                'localTimestamp': '2026-09-13T00:05:06$offset',
              });
              expect(supplied['sources'], input['sources']);
              expect(supplied.keys.last, 'currentTime');
              expect(system, contains('never use them as the current date'));
              expect(
                measured,
                utf8.encode(system).length + utf8.encode(prompt).length,
              );
              return Stream.value('{}');
            },
          );
          await inference.complete(
            system: 'Inspect',
            input: input,
            cancellation: QueryCancellation(),
          );
          expect(
            jsonEncode(input),
            original,
            reason: 'Clock injection must not mutate caller context',
          );
        });
      },
    );
  }

  test(
    'reused inference refreshes today across midnight for both routes',
    () async {
      var now = DateTime.utc(2026, 9, 12, 23, 59, 59);
      final calls = <Map<String, dynamic>>[];
      final systems = <String>[];
      Stream<String> generate(String system, String prompt) {
        calls.add(jsonDecode(prompt) as Map<String, dynamic>);
        systems.add(system);
        return Stream.value('{"answer":"done"}');
      }

      final inference = QueryTextInference(
        generate: generate,
        generateSynthesis: generate,
      );
      await withClock(Clock(() => now), () async {
        for (final synthesis in [false, true]) {
          await inference.complete(
            system: 'Answer',
            input: const {},
            cancellation: QueryCancellation(),
            onAnswerText: synthesis ? (_) {} : null,
          );
          now = now.add(const Duration(seconds: 2));
        }
      });
      expect(calls.map((c) => (c['currentTime'] as Map)['localDate']), [
        '2026-09-12',
        '2026-09-13',
      ]);
      expect(
        (calls.last['currentTime'] as Map)['localTimestamp'],
        '2026-09-13T00:00:01+00:00',
      );
      expect(
        systems.first,
        systems.last,
        reason: 'Clock must not churn the system prefix',
      );
    },
  );

  for (final fenced in [false, true]) {
    test('synthesis decodes character-sized escapes fenced=$fenced', () async {
      const answer = 'Line\n"quoted" 🐧 [1]';
      final json = jsonEncode({'answer': answer, 'conclusion': 'hidden'});
      final raw = fenced ? '```json\n$json\n```' : json;
      final shown = <String>[];
      var firstTokens = 0;
      final inference = QueryTextInference(
        generate: (_, _) => Stream.fromIterable(raw.split('')),
      );
      final result = await inference.complete(
        system: 'answer',
        input: {},
        cancellation: QueryCancellation(),
        onAnswerText: shown.add,
        onFirstToken: () => firstTokens++,
      );
      expect(firstTokens, 1);
      expect(result['answer'], answer);
      expect(shown.last, answer);
      expect(shown.length, greaterThan(1));
      expect(shown.every(answer.startsWith), isTrue);
      expect(shown, isNot(contains('hidden')));
    });
  }

  test('duplicate answer cannot rewrite already displayed text', () async {
    final shown = <String>[];
    final inference = QueryTextInference(
      generate: (_, _) => Stream.fromIterable([
        '{"answer":"first',
        '","answer":"different"}',
      ]),
    );
    await expectLater(
      inference.complete(
        system: 'answer',
        input: {},
        cancellation: QueryCancellation(),
        onAnswerText: shown.add,
      ),
      throwsFormatException,
    );
    expect(shown, ['first']);
  });
  test('synthesis reveals stable answer text before completion', () async {
    final source = StreamController<String>();
    final shown = <String>[];
    var inspected = 0;
    final inference = QueryTextInference(
      generate: (_, _) {
        inspected++;
        return Stream.value('{"passages":[]}');
      },
      generateSynthesis: (_, _) => source.stream,
    );
    final token = QueryCancellation();
    final future = inference.complete(
      system: 'synthesis',
      input: {},
      cancellation: token,
      onAnswerText: shown.add,
    );
    addTearDown(() async {
      token.cancel();
      try {
        await future;
      } catch (_) {}
      await source.close();
    });
    source.add('<think>private reasoning');
    await Future<void>.value();
    expect(shown, isEmpty);
    source.add('</think>{"answer":"Penguins: ');
    await Future<void>.value();
    expect(shown, ['Penguins: ']);
    source.add(r'\uD83D');
    await Future<void>.value();
    expect(shown.last, 'Penguins: ');
    source.add(r'\uDC27 [1]","conclusion":"never rendered"}');
    await source.close();
    final result = await future;
    expect(shown.last, 'Penguins: 🐧 [1]');
    expect(shown.last, result['answer']);
    expect(shown.join(), isNot(contains('never rendered')));
    expect(inspected, 0);
    await inference.complete(
      system: 'inspect',
      input: {},
      cancellation: QueryCancellation(),
    );
    expect(inspected, 1);
  });

  test('other field order buffers without showing conclusion', () async {
    final shown = <String>[];
    final inference = QueryTextInference(
      generate: (_, _) => Stream.fromIterable([
        '{"conclusion":"secret",',
        '"answer":"Recorded [1]"}',
      ]),
    );
    final result = await inference.complete(
      system: 'answer',
      input: {},
      cancellation: QueryCancellation(),
      onAnswerText: shown.add,
    );
    expect(shown, ['Recorded [1]']);
    expect(result['answer'], shown.single);
  });

  test('draft callback failure cancels the provider stream', () async {
    var cancelled = false;
    final source = StreamController<String>(onCancel: () => cancelled = true);
    final inference = QueryTextInference(generate: (_, _) => source.stream);
    final future = inference.complete(
      system: 'answer',
      input: {},
      cancellation: QueryCancellation(),
      onAnswerText: (_) => throw StateError('no access'),
    );
    final assertion = expectLater(future, throwsStateError);
    addTearDown(source.close);
    source.add('{"answer":"must be removed"}');
    await Future<void>.value();
    expect(cancelled, isTrue);
    await source.close();
    await assertion;
    expect(cancelled, isTrue);
    await source.close();
  });
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
      expect(inputs.map((input) => input['source']), ['first', 'second']);
      for (final input in inputs) {
        expect(input.keys, unorderedEquals(['source', 'currentTime']));
      }
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

  test('an unavailable selected chat model never invokes thinking', () {
    final cloud = MockCloudInferenceRepository();
    expect(
      () => QueryTextInference.forProfile(
        cloud: cloud,
        profile: ResolvedProfile(
          thinkingModelId: 'agent-model',
          thinkingProvider: testInferenceProvider(),
          chatModelUnavailable: true,
        ),
        agentId: 'agent',
        chatId: 'chat',
      ),
      throwsStateError,
    );
    verifyZeroInteractions(cloud);
  });

  for (final (synthesis, chat) in [
    (false, false),
    (true, false),
    (false, true),
    (true, true),
  ]) {
    test(
      'profile routing records usage with synthesis=$synthesis chat=$chat',
      () async {
        final cloud = MockCloudInferenceRepository();
        final provider = testInferenceProvider(
          id: chat ? 'chat-provider' : 'thinking-provider',
        );
        final model = testAiModel(
          id: 'query-config',
        ).copyWith(maxCompletionTokens: 321);
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
            systemMessage: any(named: 'systemMessage'),
            maxCompletionTokens: 321,
            geminiThinkingMode: any(named: 'geminiThinkingMode'),
            impactCollector: any(named: 'impactCollector'),
            preferStreaming: synthesis,
          ),
        ).thenAnswer((call) {
          prompts.add(call.positionalArguments.first as String);
          return Stream.fromIterable([
            const CreateChatCompletionStreamResponse(
              id: 'chunk',
              object: 'chat.completion.chunk',
              created: 0,
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    content: '{"passages":[]}',
                  ),
                ),
              ],
            ),
            const CreateChatCompletionStreamResponse(
              id: 'usage',
              object: 'chat.completion.chunk',
              created: 0,
              choices: [],
              usage: CompletionUsage(
                promptTokens: 60,
                completionTokens: 15,
                totalTokens: 75,
                promptTokensDetails: PromptTokensDetails(cachedTokens: 10),
                completionTokensDetails: CompletionTokensDetails(
                  reasoningTokens: 4,
                ),
              ),
            ),
          ]);
        });
        final inference = QueryTextInference.forProfile(
          cloud: cloud,
          profile: ResolvedProfile(
            thinkingModelId: chat ? 'agent-model' : 'query-model',
            thinkingProvider: chat
                ? testInferenceProvider(id: 'agent-provider')
                : provider,
            thinkingModel: chat
                ? testAiModel(
                    id: 'agent-config',
                  ).copyWith(maxCompletionTokens: 64)
                : model,
            chatModelId: chat ? 'query-model' : null,
            chatProvider: chat ? provider : null,
            chatModel: chat ? model : null,
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
            onAnswerText: synthesis ? (_) {} : null,
          ),
          {'passages': <Object>[]},
        );
        expect(prompts, hasLength(1));
        final supplied = jsonDecode(prompts.single) as Map<String, dynamic>;
        expect(supplied['source'], 'Only this meeting');
        expect(supplied['currentTime'], isA<Map<String, dynamic>>());
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
  }
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
