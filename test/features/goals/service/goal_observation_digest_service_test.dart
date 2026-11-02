import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/agents/workflow/agent_observations.dart';
import 'package:lotti/features/goals/model/goal_checkin_weight.dart';
import 'package:lotti/features/goals/service/goal_checkin_digest_service.dart';
import 'package:lotti/features/goals/service/goal_observation_digest_service.dart';
import 'package:lotti/features/goals/workflow/goal_facts_renderer.dart';
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
  late List<String?> systemMessages;
  late List<String> scripted;
  late List<AgentDomainEntity> written;
  late List<GoalObservationDigest> stored;

  final provider = testInferenceProvider(apiKey: 'k-123');
  const agentId = 'goal-agent-1';
  // Local times throughout: months are the person's calendar months.
  final now = DateTime(2026, 8, 27, 12);

  RecalledObservation note(
    String id,
    DateTime at, {
    bool critical = false,
  }) => (
    id: id,
    at: at,
    text: 'Note $id.',
    priority: critical
        ? ObservationPriority.critical
        : ObservationPriority.routine,
    category: ObservationCategory.operational,
  );

  Stream<CreateChatCompletionStreamResponse> streamOf(String body) =>
      Stream.value(
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
      );

  setUp(() {
    inference = MockCloudInferenceRepository();
    repository = MockAgentRepository();
    sync = MockAgentSyncService();
    logger = MockDomainLogger();
    prompts = [];
    systemMessages = [];
    scripted = [];
    written = [];
    stored = [];
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
      systemMessages.add(invocation.namedArguments[#systemMessage] as String?);
      final body = scripted.removeAt(0);
      if (body == 'FAIL') return Stream.error(StateError('provider down'));
      return streamOf(body);
    });
    when(() => sync.upsertEntity(any())).thenAnswer((invocation) async {
      written.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
    when(
      () => repository.getMessagesByKindAndToolName(
        agentId,
        AgentMessageKind.action,
        goalObservationDigestToolName,
      ),
    ).thenAnswer(
      (_) async => [
        for (final digest in stored)
          AgentDomainEntity.agentMessage(
                id: goalObservationDigestId(agentId, digest.month),
                agentId: agentId,
                threadId: goalObservationDigestId(agentId, digest.month),
                kind: AgentMessageKind.action,
                createdAt: digest.writtenAt,
                vectorClock: null,
                metadata: const AgentMessageMetadata(
                  toolName: goalObservationDigestToolName,
                ),
                contentEntryId:
                    '${goalObservationDigestId(agentId, digest.month)}:payload',
              )
              as AgentMessageEntity,
      ],
    );
    when(() => repository.getEntity(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.first as String;
      for (final digest in stored) {
        if ('${goalObservationDigestId(agentId, digest.month)}:payload' == id) {
          return AgentDomainEntity.agentMessagePayload(
            id: id,
            agentId: agentId,
            createdAt: digest.writtenAt,
            vectorClock: null,
            content: digest.toContent(),
          );
        }
      }
      return null;
    });
  });

  Future<List<GoalObservationDigestFact>> digests(
    List<RecalledObservation> recalled, {
    Set<String> shownVerbatim = const {},
    bool allowInference = true,
    GoalCheckInWeight weight = GoalCheckInWeight.context,
    int tokenBudget = goalObservationDigestTokenBudget,
  }) => withClock(
    Clock.fixed(now),
    () =>
        GoalObservationDigestService(
          inferenceRepository: inference,
          repository: repository,
          syncService: sync,
          domainLogger: logger,
        ).digests(
          agentId: agentId,
          recalled: recalled,
          shownVerbatim: shownVerbatim,
          goalStatement: 'Journal ten minutes a day about the colony move.',
          model: 'glm-5.2',
          provider: provider,
          allowInference: allowInference,
          weight: weight,
          tokenBudget: tokenBudget,
        ),
  );

  test('a finished month is digested from its notes, oldest first, and '
      'stored as an action the retention sweep keeps', () async {
    scripted.add('  July: the ridge, then the shelf.  ');
    final recalled = [
      note('aug-1', DateTime(2026, 8, 20)),
      note('jul-2', DateTime(2026, 7, 21), critical: true),
      note('jul-1', DateTime(2026, 7, 3)),
    ];

    final result = await digests(recalled);

    // August is still being written: only July is digested.
    expect(result, [
      (month: '2026-07', notes: 2, text: 'July: the ridge, then the shelf.'),
    ]);
    expect(prompts.single, contains('Month: 2026-07, 2 notes, oldest first.'));
    expect(
      prompts.single.indexOf('2026-07-03: Note jul-1.'),
      lessThan(prompts.single.indexOf('2026-07-21 (critical): Note jul-2.')),
    );
    expect(prompts.single, isNot(contains('aug-1')));
    expect(systemMessages.single, contains("coach's private notes"));

    final message = written.whereType<AgentMessageEntity>().single;
    expect(message.id, goalObservationDigestId(agentId, '2026-07'));
    expect(message.kind, AgentMessageKind.action);
    expect(message.metadata.toolName, goalObservationDigestToolName);
    final payload = written.whereType<AgentMessagePayloadEntity>().single;
    final digest = GoalObservationDigest.fromContent(payload.content)!;
    expect(digest.noteIds, ['jul-1', 'jul-2']);
    expect(digest.text, 'July: the ridge, then the shelf.');
  });

  test('a journal goal digests under the substance prompt', () async {
    scripted.add('Themes: the move.');
    await digests([
      note('jul-1', DateTime(2026, 7, 3)),
    ], weight: GoalCheckInWeight.substance);

    expect(systemMessages.single, contains('their check-ins ARE'));
    expect(
      systemMessages.single,
      goalObservationDigestSystemMessage(GoalCheckInWeight.substance),
    );
  });

  test(
    'a stored digest that covers its notes is read, not rewritten',
    () async {
      stored.add(
        GoalObservationDigest(
          month: '2026-07',
          noteIds: const ['jul-1'],
          text: 'July, digested.',
          writtenAt: DateTime(2026, 8, 2),
        ),
      );

      final result = await digests([note('jul-1', DateTime(2026, 7, 3))]);

      expect(result.single.text, 'July, digested.');
      expect(prompts, isEmpty);
      expect(written, isEmpty);
    },
  );

  test('a note that syncs in late folds the earlier digest in, and pruned '
      'notes stay counted', () async {
    stored.add(
      GoalObservationDigest(
        month: '2026-07',
        // jul-0 has since been pruned from the store.
        noteIds: const ['jul-0', 'jul-1'],
        text: 'July: an injury on the 1st.',
        writtenAt: DateTime(2026, 8, 2),
      ),
    );
    scripted.add('July: an injury on the 1st, then a late walk.');

    final result = await digests([
      note('jul-late', DateTime(2026, 7, 30)),
      note('jul-1', DateTime(2026, 7, 3)),
    ]);

    expect(prompts.single, contains('July: an injury on the 1st.'));
    expect(prompts.single, contains('keep what it says'));
    final digest = GoalObservationDigest.fromContent(
      written.whereType<AgentMessagePayloadEntity>().single.content,
    )!;
    expect(digest.noteIds, unorderedEquals(['jul-0', 'jul-1', 'jul-late']));
    expect(result.single.notes, 3);
  });

  test('a month whose notes are all pruned keeps its digest in view', () async {
    stored.add(
      GoalObservationDigest(
        month: '2025-11',
        noteIds: const ['nov-1', 'nov-2'],
        text: 'November, long gone from the store.',
        writtenAt: DateTime(2025, 12, 2),
      ),
    );

    final result = await digests(const []);

    expect(result, [
      (month: '2025-11', notes: 2, text: 'November, long gone from the store.'),
    ]);
    expect(prompts, isEmpty);
  });

  test(
    'a month shown verbatim is digested for later, not shown twice',
    () async {
      scripted.add('July, for when it scrolls away.');

      final result = await digests(
        [note('jul-1', DateTime(2026, 7, 3))],
        shownVerbatim: {'jul-1'},
      );

      expect(result, isEmpty);
      expect(written.whereType<AgentMessageEntity>(), hasLength(1));
    },
  );

  test('without inference a missing month is a placeholder and an outdated '
      'one keeps its stale text', () async {
    stored.add(
      GoalObservationDigest(
        month: '2026-06',
        noteIds: const ['jun-1'],
        text: 'June, before the late note.',
        writtenAt: DateTime(2026, 7, 2),
      ),
    );

    final result = await digests([
      note('jul-1', DateTime(2026, 7, 3)),
      note('jun-late', DateTime(2026, 6, 28)),
      note('jun-1', DateTime(2026, 6, 3)),
    ], allowInference: false);

    expect(result.map((d) => d.text), [
      goalObservationDigestPlaceholder(1),
      'June, before the late note.',
    ]);
    expect(prompts, isEmpty);
  });

  test('a wake writes at most its share of months, newest first', () async {
    scripted.addAll(['July.', 'June.']);

    final result = await digests([
      note('jul', DateTime(2026, 7, 3)),
      note('jun', DateTime(2026, 6, 3)),
      note('may', DateTime(2026, 5, 3)),
    ]);

    expect(prompts, hasLength(goalObservationDigestsPerWake));
    expect(result.map((d) => d.text), [
      'July.',
      'June.',
      goalObservationDigestPlaceholder(1),
    ]);
  });

  test('digests that do not fit the budget are left out', () async {
    scripted.addAll(['July.${' word' * 40}', 'June.']);

    final result = await digests([
      note('jul', DateTime(2026, 7, 3)),
      note('jun', DateTime(2026, 6, 3)),
    ], tokenBudget: 20);

    expect(result.map((d) => d.month), ['2026-06']);
  });

  test('a failed write logs and falls back; a failed read costs only the '
      'digests', () async {
    scripted.add('FAIL');
    final fallback = await digests([note('jul', DateTime(2026, 7, 3))]);
    expect(fallback.single.text, goalObservationDigestPlaceholder(1));
    expect(written, isEmpty);

    when(
      () => repository.getMessagesByKindAndToolName(
        agentId,
        AgentMessageKind.action,
        goalObservationDigestToolName,
      ),
    ).thenThrow(StateError('db gone'));
    expect(await digests([note('jul', DateTime(2026, 7, 3))]), isEmpty);
    verify(
      () => logger.error(
        LogDomain.agentWorkflow,
        any<Object>(),
        subDomain: 'goalObservationDigest',
        message: any(named: 'message'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).called(2);
  });

  test('a malformed stored digest is ignored', () {
    expect(GoalObservationDigest.fromContent(const {}), isNull);
    expect(
      GoalObservationDigest.fromContent({
        'month': '2026-07',
        'noteIds': const <Object?>['a', 3],
        'text': ' ',
        'writtenAt': '2026-08-02T00:00:00.000Z',
      }),
      isNull,
    );
    final digest = GoalObservationDigest.fromContent({
      'month': '2026-07',
      'noteIds': const <Object?>['a', 3],
      'text': ' July. ',
      'writtenAt': '2026-08-02T00:00:00.000Z',
    })!;
    expect(digest.noteIds, ['a']);
    expect(digest.text, 'July.');
  });

  test('the check-in digest service carries the observation digests', () {
    final service = GoalCheckInDigestService(
      inferenceRepository: inference,
      repository: repository,
      syncService: sync,
    );
    expect(service.observationDigests, same(service.observationDigests));
  });

  test('months are local calendar months', () {
    expect(goalObservationMonth(DateTime(2026, 3, 31, 23)), '2026-03');
    expect(goalObservationMonth(DateTime(987, 12)), '0987-12');
  });
}
