import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/front_agent/workflow/front_inference_stall_guard.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

CreateChatCompletionStreamResponse _chunk(String id) =>
    CreateChatCompletionStreamResponse(
      id: id,
      created: 0,
      object: 'chat.completion.chunk',
      choices: const [],
    );

void main() {
  setUpAll(registerAllFallbackValues);

  late MockInferenceRepositoryInterface delegate;

  /// One factory per call, run in the fake zone the call is made in.
  late List<Stream<CreateChatCompletionStreamResponse> Function()> attempts;
  late int retries;
  late int calls;
  late int cancelled;
  final provider =
      AiConfig.inferenceProvider(
            id: 'p',
            baseUrl: 'https://example.invalid',
            apiKey: 'k',
            name: 'p',
            createdAt: DateTime(2026, 11, 9),
            inferenceProviderType: InferenceProviderType.mistral,
          )
          as AiConfigInferenceProvider;

  setUp(() {
    delegate = MockInferenceRepositoryInterface();
    attempts = [];
    retries = 0;
    calls = 0;
    cancelled = 0;
    when(
      () => delegate.generateTextWithMessages(
        messages: any(named: 'messages'),
        model: any(named: 'model'),
        temperature: any(named: 'temperature'),
        provider: any(named: 'provider'),
        maxCompletionTokens: any(named: 'maxCompletionTokens'),
        tools: any(named: 'tools'),
        toolChoice: any(named: 'toolChoice'),
        thoughtSignatures: any(named: 'thoughtSignatures'),
        signatureCollector: any(named: 'signatureCollector'),
        turnIndex: any(named: 'turnIndex'),
        impactCollector: any(named: 'impactCollector'),
      ),
    ).thenAnswer((_) {
      calls++;
      return attempts.removeAt(0)();
    });
  });

  /// Sends one call through the guard and lets [elapse] pass on the fake
  /// clock; what arrived and how it ended.
  ({List<String> ids, Object? error, bool done}) send(Duration elapse) {
    final ids = <String>[];
    Object? error;
    var done = false;
    fakeAsync((async) {
      FrontInferenceStallGuard(delegate, onRetry: () => retries++)
          .generateTextWithMessages(
            messages: const [],
            model: 'deepseek-v4-1-flash-1017',
            temperature: 0,
            provider: provider,
          )
          .listen(
            (chunk) => ids.add(chunk.id!),
            onError: (Object e) => error = e,
            onDone: () => done = true,
          );
      async.elapse(elapse);
    });
    return (ids: ids, error: error, done: done);
  }

  /// An open call, sending [ids] and then nothing more; counts its
  /// cancellation, which completes in the fake zone it was made in.
  Stream<CreateChatCompletionStreamResponse> open([
    List<String> ids = const [],
  ]) {
    final controller = StreamController<CreateChatCompletionStreamResponse>(
      onCancel: () {
        cancelled++;
        return Future<void>.value();
      },
    );
    ids.map(_chunk).forEach(controller.add);
    return controller.stream;
  }

  /// A call that never sends a thing.
  Stream<CreateChatCompletionStreamResponse> silent() => open();

  Stream<CreateChatCompletionStreamResponse> answer(List<String> ids) =>
      Stream.fromIterable([for (final id in ids) _chunk(id)]);

  test('an answering call goes through untouched, once', () {
    attempts = [
      () => answer(['a', 'b']),
    ];

    final result = send(const Duration(seconds: 1));

    expect(result.ids, ['a', 'b']);
    expect(result.error, isNull);
    expect(result.done, isTrue);
    expect(calls, 1);
    expect(retries, 0);
    expect(cancelled, 0);
  });

  test('a call silent past the stall limit is sent once more, and the '
      'answer of the second goes through', () {
    attempts = [
      silent,
      () => answer(['retried']),
    ];

    final result = send(
      frontInferenceStallTimeout + const Duration(seconds: 1),
    );

    expect(result.ids, ['retried']);
    expect(result.error, isNull);
    expect(result.done, isTrue);
    expect(calls, 2);
    expect(retries, 1);
    // The stalled request is dropped, not left running.
    expect(cancelled, 1);
  });

  test('a call still silent just under the limit is waited for', () {
    attempts = [silent];

    final result = send(
      frontInferenceStallTimeout - const Duration(seconds: 1),
    );

    expect(result.error, isNull);
    expect(result.done, isFalse);
    expect(calls, 1);
  });

  test('a second stall fails the turn with a timeout', () {
    attempts = [silent, silent];

    final result = send(
      frontInferenceStallTimeout * 2 + const Duration(seconds: 1),
    );

    expect(result.ids, isEmpty);
    expect(result.error, isA<TimeoutException>());
    expect(calls, 2);
    expect(retries, 1);
    expect(cancelled, 2);
  });

  test('a stall after the first chunk fails at once — what arrived is '
      'never sent twice', () {
    attempts = [
      () => open(['partial']),
    ];

    final result = send(
      frontInferenceStallTimeout + const Duration(seconds: 1),
    );

    expect(result.ids, ['partial']);
    expect(result.error, isA<TimeoutException>());
    expect(calls, 1);
    expect(retries, 0);
    expect(cancelled, 1);
  });
}
