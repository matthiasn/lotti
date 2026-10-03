import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/one_shot_text_generation.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/ai_config_factories.dart';
import '../../ai_consumption/test_utils.dart';

CreateChatCompletionStreamResponse _chunk(
  String? content, {
  CompletionUsage? usage,
}) => CreateChatCompletionStreamResponse(
  id: 'chunk',
  object: 'chat.completion.chunk',
  created: 0,
  choices: [
    if (content != null)
      ChatCompletionStreamResponseChoice(
        index: 0,
        delta: ChatCompletionStreamResponseDelta(content: content),
      ),
  ],
  usage: usage,
);

void main() {
  setUpAll(registerAllFallbackValues);

  late MockCloudInferenceRepository inference;
  final provider = testInferenceProvider(apiKey: 'k-1');

  When<Stream<CreateChatCompletionStreamResponse>> stubGenerate() => when(
    () => inference.generate(
      any(),
      model: any(named: 'model'),
      temperature: any(named: 'temperature'),
      baseUrl: any(named: 'baseUrl'),
      apiKey: any(named: 'apiKey'),
      systemMessage: any(named: 'systemMessage'),
      maxCompletionTokens: any(named: 'maxCompletionTokens'),
      provider: any(named: 'provider'),
      geminiThinkingMode: any(named: 'geminiThinkingMode'),
      reasoningEffort: any(named: 'reasoningEffort'),
      impactCollector: any(named: 'impactCollector'),
    ),
  );

  const automation = OneShotGenerationAttribution(
    workType: AiWorkType.textGeneration,
    triggerType: AiTriggerType.automatic,
    automationId: 'automation:test',
    automationDisplayName: 'Test',
    interactionContext: AiCapturedContext(agentId: 'agent-1'),
  );

  Future<String> run({
    GeminiThinkingMode? geminiThinkingMode,
    ReasoningEffort? reasoningEffort,
    int? maxCompletionTokens = 64,
    OneShotGenerationAttribution attribution = automation,
  }) => inference.generateText(
    prompt: 'facts',
    systemMessage: 'be brief',
    model: 'model-a',
    provider: provider,
    temperature: 0.2,
    maxCompletionTokens: maxCompletionTokens,
    attribution: attribution,
    geminiThinkingMode: geminiThinkingMode,
    reasoningEffort: reasoningEffort,
  );

  setUp(() => inference = MockCloudInferenceRepository());

  test(
    'joins the streamed text, skipping empty chunks, and trims it',
    () async {
      stubGenerate().thenAnswer(
        (_) => Stream.fromIterable([
          _chunk(null),
          _chunk('  Start '),
          _chunk('here.  '),
        ]),
      );

      expect(await run(), 'Start here.');
      verify(
        () => inference.generate(
          'facts',
          model: 'model-a',
          temperature: 0.2,
          baseUrl: provider.baseUrl,
          apiKey: 'k-1',
          systemMessage: 'be brief',
          maxCompletionTokens: 64,
          provider: provider,
          // Without the capture there is nothing to collect impact for.
          // ignore: avoid_redundant_argument_values
          impactCollector: null,
        ),
      ).called(1);
    },
  );

  test('forwards the thinking controls to the provider call', () async {
    stubGenerate().thenAnswer((_) => Stream.value(_chunk('ok')));

    await run(
      geminiThinkingMode: GeminiThinkingMode.minimal,
      reasoningEffort: ReasoningEffort.minimal,
    );

    verify(
      () => inference.generate(
        any(),
        model: any(named: 'model'),
        temperature: any(named: 'temperature'),
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
        systemMessage: any(named: 'systemMessage'),
        maxCompletionTokens: any(named: 'maxCompletionTokens'),
        provider: any(named: 'provider'),
        geminiThinkingMode: GeminiThinkingMode.minimal,
        reasoningEffort: ReasoningEffort.minimal,
        impactCollector: any(named: 'impactCollector'),
      ),
    ).called(1);
  });

  test('records the call and its usage under the given attribution', () async {
    final capture = AiInteractionCaptureTestBench.create()..register();
    addTearDown(capture.unregister);
    stubGenerate().thenAnswer(
      (_) => Stream.fromIterable([
        _chunk('Note'),
        _chunk(
          null,
          usage: const CompletionUsage(
            promptTokens: 40,
            completionTokens: 8,
            totalTokens: 48,
            promptTokensDetails: PromptTokensDetails(cachedTokens: 5),
            completionTokensDetails: CompletionTokensDetails(
              reasoningTokens: 2,
            ),
          ),
        ),
      ]),
    );

    expect(await run(), 'Note');

    final start =
        verify(() => capture.service.begin(captureAny())).captured.single
            as AiAttributionStart;
    expect(start.initiator.type, AiActorType.automation);
    expect(start.initiator.id, 'automation:test');
    final event =
        verify(
              () => capture.service.recordInteraction(
                attributionId: any(named: 'attributionId'),
                event: captureAny(named: 'event'),
              ),
            ).captured.single
            as AiConsumptionEvent;
    expect(event.inputTokens, 40);
    expect(event.outputTokens, 8);
    expect(event.cachedInputTokens, 5);
    expect(event.thoughtsTokens, 2);
    expect(event.totalTokens, 48);
  });

  test('attributes the call to the category and task it works for', () async {
    final capture = AiInteractionCaptureTestBench.create()..register();
    addTearDown(capture.unregister);
    stubGenerate().thenAnswer((_) => Stream.value(_chunk('{}')));

    await run(
      attribution: const OneShotGenerationAttribution(
        workType: AiWorkType.textGeneration,
        categoryId: 'category-1',
        taskId: 'task-1',
      ),
    );

    final event =
        verify(
              () => capture.service.recordInteraction(
                attributionId: any(named: 'attributionId'),
                event: captureAny(named: 'event'),
              ),
            ).captured.single
            as AiConsumptionEvent;
    expect(event.categoryId, 'category-1');
    expect(event.taskId, 'task-1');
  });

  test('a model without a token limit leaves it to the provider', () async {
    stubGenerate().thenAnswer((_) => Stream.value(_chunk('ok')));

    await run(maxCompletionTokens: null);

    final named = verify(
      () => inference.generate(
        any(),
        model: any(named: 'model'),
        temperature: any(named: 'temperature'),
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
        systemMessage: any(named: 'systemMessage'),
        maxCompletionTokens: captureAny(named: 'maxCompletionTokens'),
        provider: any(named: 'provider'),
        impactCollector: any(named: 'impactCollector'),
      ),
    ).captured;
    expect(named, [null]);
  });
}
