import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/goals/logic/goal_checkin_compaction_strategy.dart';
import 'package:lotti/features/goals/model/goal_checkin_summary.dart';
import 'package:lotti/features/goals/service/goal_checkin_digest_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/ai_config_factories.dart';

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
  const agentId = 'goal-agent-1';
  final now = DateTime.utc(2026, 8, 27, 12);

  GoalCheckInSummary summary(int day) => GoalCheckInSummary(
    id: 'summary-$day',
    sourceEntryId: 'entry-$day',
    recordedAt: DateTime.utc(2025, 3, day, 9),
    whatHappened: 'Walked the perimeter loop, day $day.',
    committedTo: day.isEven ? 'Loop again tomorrow.' : null,
    sourceDigest: 'digest-$day',
  );

  GoalCheckInDigestRequest request({int count = 5}) => GoalCheckInDigestRequest(
    periodLabel: '2025-Q1',
    layer: GoalCheckInDigestLayer.quarter,
    from: DateTime.utc(2025, 3),
    to: DateTime.utc(2025, 3, count),
    checkIns: [for (var d = 1; d <= count; d++) summary(d)],
  );

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

  GoalCheckInDigestService service() => GoalCheckInDigestService(
    inferenceRepository: inference,
    repository: repository,
    syncService: sync,
    domainLogger: logger,
  );

  GoalCheckInDigestWriter writer({bool allowInference = true}) =>
      service().forWake(
        agentId: agentId,
        goalStatement: 'Average 10,000 steps a day.',
        model: 'glm-5.2',
        provider: provider,
        allowInference: allowInference,
      );

  void stubStored(GoalCheckInDigest digest) {
    final id = goalCheckInDigestId(agentId, digest.periodLabel);
    when(() => repository.getEntity(id)).thenAnswer(
      (_) async => AgentDomainEntity.agentMessage(
        id: id,
        agentId: agentId,
        threadId: id,
        kind: AgentMessageKind.action,
        createdAt: digest.writtenAt,
        vectorClock: null,
        metadata: const AgentMessageMetadata(
          toolName: goalCheckInDigestToolName,
        ),
        contentEntryId: '$id:payload',
      ),
    );
    when(() => repository.getEntity('$id:payload')).thenAnswer(
      (_) async => AgentDomainEntity.agentMessagePayload(
        id: '$id:payload',
        agentId: agentId,
        createdAt: digest.writtenAt,
        vectorClock: null,
        content: digest.toContent(),
      ),
    );
  }

  test(
    'writes, persists and returns a digest for a span it has not seen',
    () async {
      scripted.add('  March 2025: five loops, two promises kept.  ');

      final text = await withClock(
        Clock.fixed(now),
        () => writer().write(request()),
      );

      expect(text, 'March 2025: five loops, two promises kept.');
      // The prompt carries the goal, the span, the layer's word limit and
      // every member with its date — the digest is written from the words,
      // not from a count.
      expect(prompts.single, contains('Goal: Average 10,000 steps a day.'));
      expect(prompts.single, contains('Span: 2025-Q1 (quarter;'));
      expect(prompts.single, contains('Word limit: 80.'));
      expect(
        prompts.single,
        contains('2025-03-04: Walked the perimeter loop, day 4.'),
      );
      expect(prompts.single, contains('committed to: Loop again tomorrow.'));

      expect(written, hasLength(2));
      final payload = written.first as AgentMessagePayloadEntity;
      final message = written.last as AgentMessageEntity;
      expect(message.id, goalCheckInDigestId(agentId, '2025-Q1'));
      expect(message.kind, AgentMessageKind.action);
      expect(message.metadata.toolName, goalCheckInDigestToolName);
      expect(message.contentEntryId, payload.id);
      final stored = GoalCheckInDigest.fromContent(payload.content)!;
      expect(stored.text, text);
      expect(stored.layer, 'quarter');
      expect(stored.checkInCount, 5);
      expect(stored.sourceKey, goalCheckInDigestSourceKey(request()));
      expect(stored.writtenAt, now);
    },
  );

  test(
    'a stored digest of the same members is reused without inference',
    () async {
      stubStored(
        GoalCheckInDigest(
          periodLabel: '2025-Q1',
          layer: 'quarter',
          sourceKey: goalCheckInDigestSourceKey(request()),
          checkInCount: 5,
          text: 'Already written.',
          writtenAt: now.subtract(const Duration(days: 30)),
        ),
      );

      final text = await writer().write(request());

      expect(text, 'Already written.');
      expect(prompts, isEmpty);
      expect(written, isEmpty);
    },
  );

  test('a span whose members changed is rewritten', () async {
    stubStored(
      GoalCheckInDigest(
        periodLabel: '2025-Q1',
        layer: 'quarter',
        sourceKey: goalCheckInDigestSourceKey(request(count: 4)),
        checkInCount: 4,
        text: 'Four check-ins.',
        writtenAt: now.subtract(const Duration(days: 30)),
      ),
    );
    scripted.add('Five check-ins now.');

    final text = await writer().write(request());

    expect(text, 'Five check-ins now.');
    expect(prompts, hasLength(1));
    expect(written, hasLength(2));
  });

  test('the source key changes with words, membership and layer', () {
    final base = goalCheckInDigestSourceKey(request());
    expect(goalCheckInDigestSourceKey(request()), base);
    expect(goalCheckInDigestSourceKey(request(count: 4)), isNot(base));
    final reworded = GoalCheckInDigestRequest(
      periodLabel: '2025-Q1',
      layer: GoalCheckInDigestLayer.quarter,
      from: DateTime.utc(2025, 3),
      to: DateTime.utc(2025, 3, 5),
      checkIns: [
        for (var d = 1; d <= 5; d++)
          if (d == 3)
            GoalCheckInSummary(
              id: 'summary-3',
              sourceEntryId: 'entry-3',
              recordedAt: DateTime.utc(2025, 3, 3, 9),
              whatHappened: 'Re-transcribed.',
              sourceDigest: 'digest-3-v2',
            )
          else
            summary(d),
      ],
    );
    expect(goalCheckInDigestSourceKey(reworded), isNot(base));
    final aged = GoalCheckInDigestRequest(
      periodLabel: '2025',
      layer: GoalCheckInDigestLayer.year,
      from: DateTime.utc(2025, 3),
      to: DateTime.utc(2025, 3, 5),
      checkIns: request().checkIns,
    );
    expect(goalCheckInDigestSourceKey(aged), isNot(base));
  });

  test(
    'an interactive wake never infers: stored text or a placeholder',
    () async {
      final text = await writer(allowInference: false).write(request());

      expect(text, '(5 check-ins from this span are not yet digested)');
      expect(prompts, isEmpty);
      expect(written, isEmpty);

      stubStored(
        GoalCheckInDigest(
          periodLabel: '2025-Q1',
          layer: 'quarter',
          sourceKey: 'stale',
          checkInCount: 4,
          text: 'Stale but real.',
          writtenAt: now.subtract(const Duration(days: 30)),
        ),
      );
      expect(
        await writer(allowInference: false).write(request()),
        'Stale but real.',
        reason: 'a stale digest beats a placeholder',
      );
      expect(prompts, isEmpty);
    },
  );

  test(
    'at most goalCheckInDigestsPerWake spans are written per wake',
    () async {
      final w = writer();
      scripted.addAll(List.filled(goalCheckInDigestsPerWake, 'Written.'));

      final texts = <String>[];
      for (var i = 0; i <= goalCheckInDigestsPerWake; i++) {
        texts.add(
          await w.write(
            GoalCheckInDigestRequest(
              periodLabel: '2025-0${i + 1}',
              layer: GoalCheckInDigestLayer.month,
              from: DateTime.utc(2025, i + 1),
              to: DateTime.utc(2025, i + 1, 20),
              checkIns: [summary(i + 1)],
            ),
          ),
        );
      }

      expect(prompts, hasLength(goalCheckInDigestsPerWake));
      expect(texts.take(goalCheckInDigestsPerWake), everyElement('Written.'));
      expect(texts.last, '(1 check-ins from this span are not yet digested)');
    },
  );

  test('an inference failure is logged and yields the placeholder', () async {
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
    ).thenAnswer((_) => Stream.error(Exception('HTTP 500')));

    final text = await writer().write(request());

    expect(text, '(5 check-ins from this span are not yet digested)');
    expect(written, isEmpty);
    verify(
      () => logger.error(
        LogDomain.agentWorkflow,
        any<Object>(),
        subDomain: 'goalCheckInDigest',
        message: 'goal check-in digest failed for 2025-Q1',
        stackTrace: any(named: 'stackTrace'),
      ),
    ).called(1);
  });

  test('a blank response is a failure, never a stored blank', () async {
    scripted.add('   ');

    final text = await writer().write(request());

    expect(text, '(5 check-ins from this span are not yet digested)');
    expect(written, isEmpty);
  });

  test('a read failure is logged and does not stop the write', () async {
    when(() => repository.getEntity(any())).thenThrow(Exception('db'));
    scripted.add('Fresh.');

    final text = await writer().write(request());

    expect(text, 'Fresh.');
    verify(
      () => logger.error(
        LogDomain.agentWorkflow,
        any<Object>(),
        subDomain: 'goalCheckInDigest',
        message: 'failed to read digest 2025-Q1',
        stackTrace: any(named: 'stackTrace'),
      ),
    ).called(1);
  });

  test('fromContent rejects malformed rows rather than guessing', () {
    expect(
      GoalCheckInDigest.fromContent({'periodLabel': '2025-Q1', 'text': ''}),
      isNull,
    );
    expect(
      GoalCheckInDigest.fromContent({
        'periodLabel': '2025-Q1',
        'layer': 'quarter',
        'sourceKey': 'k',
        'checkInCount': 'five',
        'text': 'x',
        'writtenAt': now.toIso8601String(),
      }),
      isNull,
    );
  });
}
