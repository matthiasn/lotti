import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/projection/compaction_summary.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';
import 'package:lotti/features/agents/service/agent_log_llm_summarizer.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../ai_consumption/test_utils.dart';
import '../test_data/ai_config_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockCloudInferenceRepository inference;
  late List<String> prompts;
  late List<List<String>> scriptedOutputs;

  final provider = testInferenceProvider(apiKey: 'k-123');

  Stream<CreateChatCompletionStreamResponse> streamOf(List<String> parts) =>
      Stream.fromIterable([
        // An empty-choices chunk first — the collector must tolerate it.
        const CreateChatCompletionStreamResponse(
          id: 'keepalive',
          object: 'chat.completion.chunk',
          created: 0,
          choices: [],
        ),
        for (final part in parts)
          CreateChatCompletionStreamResponse(
            id: 'chunk',
            object: 'chat.completion.chunk',
            created: 0,
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(content: part),
              ),
            ],
          ),
      ]);

  setUp(() {
    inference = MockCloudInferenceRepository();
    prompts = [];
    scriptedOutputs = [];
    when(
      () => inference.generate(
        any(),
        model: any(named: 'model'),
        temperature: any(named: 'temperature'),
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
        systemMessage: any(named: 'systemMessage'),
        maxCompletionTokens: any(named: 'maxCompletionTokens'),
        provider: any(named: 'provider'),
      ),
    ).thenAnswer((invocation) {
      prompts.add(invocation.positionalArguments.first as String);
      return streamOf(scriptedOutputs.removeAt(0));
    });
  });

  AgentLogLlmSummarizer summarizer({int maxInputTokensPerCall = 12000}) =>
      AgentLogLlmSummarizer(
        inferenceRepository: inference,
        maxInputTokensPerCall: maxInputTokensPerCall,
      );

  RenderedSource src(String entryId, String text, {int day = 10}) =>
      RenderedSource(
        contentEntryId: entryId,
        sourceCreatedAt: DateTime.utc(2024, 3, day),
        content: {'entryType': 'text', 'text': text},
      );

  test(
    'distills sources with the wake model + provider, oldest first',
    () async {
      scriptedOutputs = [
        ['Distilled', ' summary.'],
      ];
      final sources = [src('e1', 'first note'), src('e2', 'second note')];

      final result = await summarizer().summarize(
        sources: sources,
        model: 'models/test-flash',
        provider: provider,
      );

      expect(result, 'Distilled summary.');
      // The fold input is byte-identical to the prompt's own tail rendering.
      for (final source in sources) {
        expect(prompts.single, contains(renderCompactedSourceLine(source)));
      }
      expect(prompts.single, contains('(none yet)'));
      verify(
        () => inference.generate(
          any(),
          model: 'models/test-flash',
          temperature: any(named: 'temperature'),
          baseUrl: provider.baseUrl,
          apiKey: 'k-123',
          systemMessage: any(
            named: 'systemMessage',
            that: contains('working memory'),
          ),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          provider: provider,
        ),
      ).called(1);
    },
  );

  test('folds the prior summary into the prompt (rolling)', () async {
    scriptedOutputs = [
      ['Updated.'],
    ];
    await summarizer().summarize(
      sources: [src('e1', 'note')],
      model: 'm',
      provider: provider,
      priorSummary: 'EARLIER WORK',
    );
    expect(prompts.single, contains('Running summary so far:\nEARLIER WORK'));
    expect(prompts.single, isNot(contains('(none yet)')));
  });

  test('chunks an oversized fold set and rolls the summary through', () async {
    scriptedOutputs = [
      ['S1'],
      ['S2'],
    ];
    // A 1-token budget forces one source per chunk (entries are never split).
    final result = await summarizer(maxInputTokensPerCall: 1).summarize(
      sources: [src('e1', 'alpha'), src('e2', 'beta', day: 11)],
      model: 'm',
      provider: provider,
    );

    expect(result, 'S2');
    expect(prompts, hasLength(2));
    expect(prompts.first, contains('alpha'));
    expect(prompts.first, isNot(contains('beta')));
    // The second call folds the first chunk's output as the running summary.
    expect(prompts.last, contains('Running summary so far:\nS1'));
    expect(prompts.last, contains('beta'));
  });

  test(
    'automatic compaction records its owner and detailed token usage',
    () async {
      final attribution = AiInteractionCaptureTestBench.create()..register();
      addTearDown(attribution.unregister);
      when(
        () => inference.generate(
          any(),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          baseUrl: any(named: 'baseUrl'),
          apiKey: any(named: 'apiKey'),
          systemMessage: any(named: 'systemMessage'),
          maxCompletionTokens: any(named: 'maxCompletionTokens'),
          provider: any(named: 'provider'),
          impactCollector: any(named: 'impactCollector'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          const CreateChatCompletionStreamResponse(
            id: 'content',
            object: 'chat.completion.chunk',
            created: 0,
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Compacted memory',
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
        ]),
      );

      final result = await summarizer().summarize(
        sources: [src('e1', 'important note')],
        model: 'models/test-flash',
        provider: provider,
      );

      expect(result, 'Compacted memory');
      final start =
          verify(
                () => attribution.service.begin(captureAny()),
              ).captured.single
              as AiAttributionStart;
      expect(start.initiator.type, AiActorType.automation);
      expect(start.initiator.id, 'automation:agent-log-compaction');
      final event =
          verify(
                () => attribution.service.recordInteraction(
                  attributionId: any(named: 'attributionId'),
                  event: captureAny(named: 'event'),
                ),
              ).captured.single
              as AiConsumptionEvent;
      expect(event.inputTokens, 60);
      expect(event.outputTokens, 15);
      expect(event.cachedInputTokens, 10);
      expect(event.thoughtsTokens, 4);
      expect(event.totalTokens, 75);
    },
  );

  test('throws on an empty model response instead of erasing memory', () async {
    scriptedOutputs = [
      ['   '],
    ];
    expect(
      () => summarizer().summarize(
        sources: [src('e1', 'note')],
        model: 'm',
        provider: provider,
      ),
      throwsStateError,
    );
  });

  test('an empty fold set with no prior summary throws', () async {
    expect(
      () => summarizer().summarize(
        sources: const [],
        model: 'm',
        provider: provider,
      ),
      throwsStateError,
    );
    verifyNever(
      () => inference.generate(
        any(),
        model: any(named: 'model'),
        temperature: any(named: 'temperature'),
        baseUrl: any(named: 'baseUrl'),
        apiKey: any(named: 'apiKey'),
        systemMessage: any(named: 'systemMessage'),
        maxCompletionTokens: any(named: 'maxCompletionTokens'),
        provider: any(named: 'provider'),
      ),
    );
  });
}
