import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_wake_progress.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_tracing_inference_repository.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_wake_trace.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';

const _dayId = 'dayplan-2026-11-04';

CreateChatCompletionStreamResponse _chunk({CompletionUsage? usage}) =>
    CreateChatCompletionStreamResponse(
      id: 'c',
      created: 0,
      object: 'chat.completion.chunk',
      choices: const [],
      usage: usage,
    );

void main() {
  setUpAll(registerAllFallbackValues);

  late DayAgentWakeProgressBus bus;
  late DayAgentWakeTrace trace;
  late MockInferenceRepositoryInterface delegate;
  late DayAgentTracingInferenceRepository repo;
  final provider =
      AiConfig.inferenceProvider(
            id: 'p',
            baseUrl: 'https://example.invalid',
            apiKey: 'k',
            name: 'p',
            createdAt: DateTime(2026, 11, 3),
            inferenceProviderType: InferenceProviderType.mistral,
          )
          as AiConfigInferenceProvider;

  setUp(() {
    bus = DayAgentWakeProgressBus();
    trace = DayAgentWakeTrace(dayId: _dayId, runKey: 'run-1', bus: bus);
    delegate = MockInferenceRepositoryInterface();
    repo = DayAgentTracingInferenceRepository(delegate: delegate, trace: trace);
  });
  tearDown(() => bus.dispose());

  void stubMessages(Stream<CreateChatCompletionStreamResponse> stream) => when(
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
  ).thenAnswer((_) => stream);

  Stream<CreateChatCompletionStreamResponse> send() =>
      repo.generateTextWithMessages(
        messages: const [],
        model: 'deepseek-v4-1-flash-1017',
        temperature: 0.3,
        provider: provider,
        maxCompletionTokens: 8192,
        turnIndex: 2,
      );

  test('forwards every chunk and records the turn with its usage', () async {
    stubMessages(
      Stream.fromIterable([
        _chunk(),
        _chunk(
          usage: const CompletionUsage(
            promptTokens: 4926,
            completionTokens: 1217,
            totalTokens: 6143,
            completionTokensDetails: CompletionTokensDetails(
              reasoningTokens: 200,
            ),
          ),
        ),
      ]),
    );

    final chunks = await send().toList();

    expect(chunks, hasLength(2));
    final turn = bus.statusFor(_dayId).wake!.turns.single;
    expect(turn.timeToFirstChunk, isNotNull);
    expect(turn.isRunning, isFalse);
    expect(turn.failed, isFalse);
    expect(
      (turn.inputTokens, turn.outputTokens, turn.reasoningTokens),
      (
        4926,
        1217,
        200,
      ),
    );
    verify(
      () => delegate.generateTextWithMessages(
        messages: const [],
        model: 'deepseek-v4-1-flash-1017',
        temperature: 0.3,
        provider: provider,
        maxCompletionTokens: 8192,
        turnIndex: 2,
      ),
    ).called(1);
  });

  test('a stream error marks the turn failed and is rethrown', () async {
    stubMessages(Stream.error(TimeoutException('deadline')));

    await expectLater(send().toList(), throwsA(isA<TimeoutException>()));

    final turn = bus.statusFor(_dayId).wake!.turns.single;
    expect(turn.failed, isTrue);
    expect(turn.timeToFirstChunk, isNull);
  });

  test('the turn starts only when the stream is listened to', () async {
    stubMessages(Stream.fromIterable([_chunk()]));

    final stream = send();
    expect(bus.statusFor(_dayId).wake!.turns, isEmpty);

    await stream.drain<void>();
    expect(bus.statusFor(_dayId).wake!.turns, hasLength(1));
  });

  test('generateText is traced as a turn too', () async {
    when(
      () => delegate.generateText(
        prompt: any(named: 'prompt'),
        model: any(named: 'model'),
        temperature: any(named: 'temperature'),
        systemMessage: any(named: 'systemMessage'),
        provider: any(named: 'provider'),
        maxCompletionTokens: any(named: 'maxCompletionTokens'),
        tools: any(named: 'tools'),
        toolChoice: any(named: 'toolChoice'),
      ),
    ).thenAnswer((_) => Stream.fromIterable([_chunk()]));

    await repo
        .generateText(
          prompt: 'p',
          model: 'm',
          temperature: 0,
          systemMessage: null,
          provider: provider,
        )
        .drain<void>();

    expect(bus.statusFor(_dayId).wake!.turns.single.isRunning, isFalse);
  });
}
