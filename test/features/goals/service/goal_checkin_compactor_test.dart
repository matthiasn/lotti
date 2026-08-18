import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/goals/model/goal_checkin_summary.dart';
import 'package:lotti/features/goals/service/goal_checkin_compactor.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/ai_config_factories.dart';
import '../../ai_consumption/test_utils.dart';

/// One model response filling every slot. Held as a constant so the JSON stays
/// on one logical line — split across adjacent string literals it trips the
/// whitespace lints, and escaping it inline hurts readability more than it
/// helps.
const _fullSlotResponse =
    '{"whatHappened":"Skipped the lunch walk because calls ran over.","committedTo":"take the long route home","blockers":"back-to-back calls","mood":"a bit flat","asks":null}';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockCloudInferenceRepository inference;
  late MockAgentRepository repository;
  late MockAgentSyncService sync;
  late MockDomainLogger logger;
  late List<String> prompts;
  late List<String> scripted;
  late List<AgentDomainEntity> written;

  final provider = testInferenceProvider(apiKey: 'k-123');
  final recordedAt = DateTime.utc(2026, 8, 18, 14, 20);

  Stream<CreateChatCompletionStreamResponse> streamOf(String body) =>
      Stream.fromIterable([
        CreateChatCompletionStreamResponse(
          id: 'chunk',
          object: 'chat.completion.chunk',
          created: 0,
          choices: [
            ChatCompletionStreamResponseChoice(
              index: 0,
              delta: ChatCompletionStreamResponseDelta(content: body),
            ),
          ],
        ),
        // A usage chunk, so the token accounting the pills read is exercised
        // rather than assumed.
        const CreateChatCompletionStreamResponse(
          id: 'usage',
          object: 'chat.completion.chunk',
          created: 0,
          choices: [],
          usage: CompletionUsage(
            promptTokens: 120,
            completionTokens: 40,
            totalTokens: 160,
            promptTokensDetails: PromptTokensDetails(cachedTokens: 20),
            completionTokensDetails: CompletionTokensDetails(
              reasoningTokens: 8,
            ),
          ),
        ),
      ]);

  setUp(() {
    inference = MockCloudInferenceRepository();
    repository = MockAgentRepository();
    sync = MockAgentSyncService();
    logger = MockDomainLogger();
    prompts = [];
    scripted = [];
    written = [];

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
        geminiThinkingMode: GeminiThinkingMode.minimal,
        reasoningEffort: ReasoningEffort.minimal,
        impactCollector: any(named: 'impactCollector'),
      ),
    ).thenAnswer((invocation) {
      prompts.add(invocation.positionalArguments.first as String);
      return streamOf(scripted.removeAt(0));
    });

    when(() => sync.upsertEntity(any())).thenAnswer((invocation) async {
      written.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
  });

  GoalCheckInCompactor compactor() => GoalCheckInCompactor(
    inferenceRepository: inference,
    repository: repository,
    syncService: sync,
    domainLogger: logger,
  );

  Future<GoalCheckInSummary?> compact({String entryId = 'audio-1'}) =>
      compactor().compact(
        agentId: 'goal-1',
        entryId: entryId,
        recordedAt: recordedAt,
        transcript:
            'Skipped the lunch walk, calls ran over. I will take the long '
            'route home instead.',
        goalStatement: 'Walk on five days a week.',
        model: 'test-model',
        provider: provider,
      );

  test('distills the structured slots the coaching turns on', () async {
    scripted = [
      _fullSlotResponse,
    ];

    final summary = await compact();

    expect(summary, isNotNull);
    expect(summary!.committedTo, 'take the long route home');
    expect(summary.blockers, 'back-to-back calls');
    expect(summary.mood, 'a bit flat');
    expect(summary.asks, isNull, reason: 'an explicit null is not a value');
    // The goal is in the prompt: the same recording summarised for two goals
    // should keep different things.
    expect(prompts.single, contains('Walk on five days a week.'));
    expect(prompts.single, contains('Skipped the lunch walk'));
  });

  test('is keyed by (agent, entry) so a retry converges', () async {
    // Actually retry: comparing the id helper with itself held for any
    // implementation and proved nothing, while the name promised convergence.
    scripted = ['{"whatHappened":"Walked."}', '{"whatHappened":"Walked."}'];
    final first = await compact();
    final second = await compact();

    expect(first!.id, goalCheckInSummaryId('goal-1', 'audio-1'));
    expect(second!.id, first.id);

    // Both runs wrote the SAME row, so a regression that appended a second
    // summary of the same words fails here.
    final messageIds = written
        .whereType<AgentMessageEntity>()
        .map((message) => message.id)
        .toSet();
    expect(messageIds, hasLength(1));
    expect(
      written.whereType<AgentMessagePayloadEntity>().map((p) => p.id).toSet(),
      hasLength(1),
    );

    // A different recording is a different row.
    expect(
      goalCheckInSummaryId('goal-1', 'audio-2'),
      isNot(goalCheckInSummaryId('goal-1', 'audio-1')),
    );
  });

  test('stores the summary against the moment it was recorded', () async {
    scripted = ['{"whatHappened":"Walked."}'];
    await compact();

    final payload = written.whereType<AgentMessagePayloadEntity>().single;
    // Not the moment it was compacted: the agent quotes dates back, so this
    // has to be when the user actually spoke.
    expect(payload.content['recordedAt'], recordedAt.toIso8601String());
    expect(payload.content['sourceEntryId'], 'audio-1');

    final message = written.whereType<AgentMessageEntity>().single;
    expect(message.metadata.toolName, goalCheckInSummaryToolName);
    expect(message.contentEntryId, payload.id);
  });

  test('tolerates a fenced JSON response', () async {
    scripted = ['```json\n{"whatHappened":"Walked the long way."}\n```'];

    final summary = await compact();
    expect(summary!.whatHappened, 'Walked the long way.');
  });

  test(
    'an unreadable response writes a durable backoff, not a guess',
    () async {
      scripted = ['I think they went for a walk?'];

      expect(await compact(), isNull);
      final failure = written.whereType<AgentMessageEntity>().single;
      expect(failure.metadata.toolName, goalCheckInCompactionFailureToolName);
      final payload = written.whereType<AgentMessagePayloadEntity>().single;
      expect(payload.content['attempts'], 1);
      expect(payload.content['sourceDigest'], isA<String>());
      verify(
        () => logger.error(
          LogDomain.agentWorkflow,
          any(),
          subDomain: 'goalCheckInCompaction',
          message: 'goal check-in compaction failed for audio-1',
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    },
  );

  test('a matching failure blocks only until its retry instant', () {
    final retryAfter = recordedAt.add(const Duration(hours: 6));
    final failure = GoalCheckInCompactionFailure(
      sourceEntryId: 'audio-1',
      sourceDigest: 'digest',
      attempts: 1,
      retryAfter: retryAfter,
    );

    expect(failure.blocks('digest', recordedAt), isTrue);
    expect(failure.blocks('digest', retryAfter), isFalse);
    expect(failure.blocks('changed-digest', recordedAt), isFalse);
  });

  test('repeated failures retain and increment the durable marker', () async {
    final sourceDigest = goalCheckInSourceDigest(
      'Skipped the lunch walk, calls ran over. I will take the long '
      'route home instead.',
    );
    final failureId = goalCheckInCompactionFailureId('goal-1', 'audio-1');
    final payloadId = '$failureId:payload';
    final previousFailure = GoalCheckInCompactionFailure(
      sourceEntryId: 'audio-1',
      sourceDigest: sourceDigest,
      attempts: 1,
      retryAfter: recordedAt,
    );
    final existingPayload = AgentDomainEntity.agentMessagePayload(
      id: payloadId,
      agentId: 'goal-1',
      createdAt: recordedAt,
      vectorClock: null,
      content: previousFailure.toContent(),
    );
    final existingMessage = AgentDomainEntity.agentMessage(
      id: failureId,
      agentId: 'goal-1',
      threadId: failureId,
      kind: AgentMessageKind.action,
      createdAt: recordedAt,
      vectorClock: null,
      contentEntryId: payloadId,
      metadata: const AgentMessageMetadata(
        toolName: goalCheckInCompactionFailureToolName,
      ),
    );
    when(() => repository.getEntity(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.first as String;
      return switch (id) {
        final value when value == failureId => existingMessage,
        final value when value == payloadId => existingPayload,
        _ => null,
      };
    });
    scripted = ['not json'];

    await withClock(Clock.fixed(recordedAt), compact);

    final updated = written.whereType<AgentMessagePayloadEntity>().single;
    expect(updated.content['attempts'], 2);
    expect(
      updated.content['retryAfter'],
      recordedAt.add(const Duration(hours: 12)).toIso8601String(),
    );
  });

  test('a backoff persistence failure is logged and contained', () async {
    scripted = ['not json'];
    when(() => sync.upsertEntity(any())).thenThrow(StateError('disk full'));

    expect(await compact(), isNull);

    verify(
      () => logger.error(
        LogDomain.agentWorkflow,
        any(),
        subDomain: 'goalCheckInCompaction',
        message: 'failed to persist check-in compaction backoff for audio-1',
        stackTrace: any(named: 'stackTrace'),
      ),
    ).called(1);
  });

  test('a response with no whatHappened is refused', () async {
    scripted = ['{"committedTo":"walk tomorrow"}'];

    // The slot is the record; a summary without it is not a record of
    // anything.
    expect(await compact(), isNull);
    expect(
      written.whereType<AgentMessageEntity>().single.metadata.toolName,
      goalCheckInCompactionFailureToolName,
    );
  });

  test('an empty transcript is never sent for inference', () async {
    final summary = await compactor().compact(
      agentId: 'goal-1',
      entryId: 'audio-1',
      recordedAt: recordedAt,
      transcript: '   ',
      goalStatement: 'Walk more.',
      model: 'test-model',
      provider: provider,
    );

    expect(summary, isNull);
    expect(prompts, isEmpty);
  });

  test('malformed durable failure markers are ignored', () {
    expect(
      GoalCheckInCompactionFailure.fromContent({
        'sourceEntryId': 'audio-1',
        'sourceDigest': 'digest',
        'attempts': 0,
        'retryAfter': 42,
      }),
      isNull,
    );
  });

  test('compaction is attributed to the goal that paid for it', () async {
    final attribution = AiInteractionCaptureTestBench.create()..register();
    addTearDown(attribution.unregister);
    scripted = ['{"whatHappened":"Walked the long way."}'];

    await compact();

    final start =
        verify(
              () => attribution.service.begin(captureAny()),
            ).captured.single
            as AiAttributionStart;
    expect(start.initiator.type, AiActorType.automation);
    expect(start.initiator.id, 'automation:goal-check-in-compaction');

    final event =
        verify(
              () => attribution.service.recordInteraction(
                attributionId: any(named: 'attributionId'),
                event: captureAny(named: 'event'),
              ),
            ).captured.single
            as AiConsumptionEvent;
    // Without the agent id the row lands with a null agent, and the goal's
    // lifetime cost pills — which total by agent — never show what compaction
    // actually spent.
    expect(event.agentId, 'goal-1');
    expect(event.entryId, 'audio-1');
    expect(event.inputTokens, 120);
    expect(event.outputTokens, 40);
    expect(event.cachedInputTokens, 20);
    expect(event.thoughtsTokens, 8);
    expect(event.totalTokens, 160);
  });

  test('a failing model never throws at the caller', () async {
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
        geminiThinkingMode: GeminiThinkingMode.minimal,
        reasoningEffort: ReasoningEffort.minimal,
        impactCollector: any(named: 'impactCollector'),
      ),
    ).thenThrow(Exception('provider is down'));

    // A check-in that failed to compact is still a check-in the user can play
    // back; the failure must not take the wake down with it.
    expect(await compact(), isNull);
    final payload = written.whereType<AgentMessagePayloadEntity>().single;
    expect(payload.content['attempts'], 1);
  });
}
