import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_answer_builder.dart';
import 'package:lotti/features/agents/query/query_chat_projection.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/query/query_text_inference.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/service/front_door_walker.dart';
import 'package:lotti/features/front_agent/service/front_owner_titles.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

class _MockTitles extends Mock implements FrontOwnerTitles {}

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(const QueryScope(kind: QueryScopeKind.task, id: ''));
    registerFallbackValue(
      QueryChatHistory(
        id: '',
        scope: const QueryScope(kind: QueryScopeKind.task, id: ''),
        title: '',
        private: false,
        archived: false,
        lastActivity: DateTime(2026),
        events: const [],
        unread: false,
      ),
    );
    registerFallbackValue(QueryCancellation());
    registerFallbackValue(FrontDestinationKind.task);
    void progress(int checked, {required bool expanded}) {}
    registerFallbackValue(progress);
    registerFallbackValue(
      AgentDomainEntity.queryChatEvent(
        id: '',
        agentId: '',
        chatId: '',
        data: const QueryChatEventData.question(text: ''),
        createdAt: DateTime(2026),
        vectorClock: null,
      ),
    );
  });

  const messageId = 'msg-1';
  const dispatchId = 'dispatch-1';
  const input = 'How is the garden? Swim? Pip? Buy hose. Learn accordion.';
  //             0         1         2         3         4         5
  //             0123456789012345678901234567890123456789012345678901234567
  final now = DateTime(2026, 10, 24, 9);

  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late MockQueryAnswerBuilder builder;
  late MockGoalChatService goalChat;
  late MockRelationshipChatService personChat;
  late _MockTitles titles;
  late List<AgentDomainEntity> upserts;
  late List<(QueryScope, String, String)> factoryCalls;
  late Exception? factoryError;
  late Map<String, AgentIdentityEntity?> taskAgents;
  late Map<String, AgentIdentityEntity?> projectAgents;
  late FrontDoorWalker walker;

  FrontDispatchSegment segment({
    required int start,
    required int end,
    required FrontDestinationKind kind,
    String? id,
    FrontSegmentIntent intent = FrontSegmentIntent.question,
    FrontNewKind? newKind,
  }) => FrontDispatchSegment(
    start: start,
    end: end,
    text: input.substring(start, end),
    intent: intent,
    kind: kind,
    destinationId: id,
    newKind: newKind,
    confidence: 0.9,
  );

  /// The dispatch record and payload the workflow would have written.
  void seedDispatch(List<FrontDispatchSegment> segments) {
    final payload = makeTestMessagePayload(
      id: '$dispatchId-payload',
      agentId: frontAgentId,
      content: {
        'input': input,
        ...FrontDispatch(segments: segments).toJson(),
      },
    );
    final record = makeTestMessage(
      id: dispatchId,
      agentId: frontAgentId,
      threadId: 'thread-1',
      kind: AgentMessageKind.action,
      metadata: const AgentMessageMetadata(
        runKey: 'run-1',
        toolName: FrontAgentToolNames.dispatch,
        operationId: messageId,
      ),
      contentEntryId: payload.id,
    );
    when(
      () => repository.getAgentMessages(frontAgentId),
    ).thenAnswer((_) async => [record]);
    when(
      () => repository.getEntity(payload.id),
    ).thenAnswer((_) async => payload);
  }

  /// The door records written so far, by segment index.
  Map<int, FrontDoorRecord> doors() {
    final result = <int, FrontDoorRecord>{};
    for (final p in upserts.whereType<AgentMessagePayloadEntity>()) {
      if (!p.id.contains(':door:')) continue;
      final record = FrontDoorRecord.fromJson(p.content);
      if (record != null) result[record.segmentIndex] = record;
    }
    return result;
  }

  setUp(() {
    repository = MockAgentRepository();
    syncService = MockAgentSyncService();
    builder = MockQueryAnswerBuilder();
    goalChat = MockGoalChatService();
    personChat = MockRelationshipChatService();
    titles = _MockTitles();
    upserts = [];
    factoryCalls = [];
    factoryError = null;
    taskAgents = {};
    projectAgents = {};
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
    // Nothing exists yet; a test about an existing claim overrides this.
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
    when(
      () => titles.titleFor(any(), any()),
    ).thenAnswer(
      (invocation) async => 'Title of ${invocation.positionalArguments[1]}',
    );
    walker = FrontDoorWalker(
      repository: repository,
      syncService: syncService,
      queryBuilderFactory: (scope, agentId, chatId) async {
        factoryCalls.add((scope, agentId, chatId));
        if (factoryError case final error?) throw error;
        return builder;
      },
      taskAgentFor: (id) async => taskAgents[id],
      projectAgentFor: (id) async => projectAgents[id],
      goalChat: goalChat,
      personChat: personChat,
      ownerTitles: titles,
      domainLogger: MockDomainLogger(),
    );
  });

  test('a turn without a dispatch — a question or a reply — has nothing to '
      'walk', () async {
    when(
      () => repository.getAgentMessages(frontAgentId),
    ).thenAnswer((_) async => const []);
    await walker.walk(messageId);
    expect(upserts, isEmpty);
  });

  group('a task question', () {
    final garden = makeTestIdentity(
      id: 'agent-garden',
      agentId: 'agent-garden',
    );

    test("is answered by the owner's query pipeline, headless, and the "
        'answer recorded attributed to the owner', () async {
      seedDispatch([
        segment(
          start: 0,
          end: 18,
          kind: FrontDestinationKind.task,
          id: 'garden',
        ),
      ]);
      taskAgents['garden'] = garden;
      when(
        () => builder.build(
          chat: any(named: 'chat'),
          question: any(named: 'question'),
          memories: any(named: 'memories'),
          cancellation: any(named: 'cancellation'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((invocation) async {
        final chat = invocation.namedArguments[#chat] as QueryChatHistory;
        final question =
            invocation.namedArguments[#question] as AgentQueryChatEventEntity;
        expect(
          chat.scope,
          const QueryScope(kind: QueryScopeKind.task, id: 'garden'),
        );
        expect(chat.id, messageId);
        expect((question.data as QueryChatQuestion).text, 'How is the garden?');
        expect(question.agentId, 'agent-garden');
        expect(chat.events, [question]);
        return const QueryBuiltAnswer(
          answer: QueryChatAnswer(
            questionId: 'q',
            text: 'The seam walk is next.',
            coverage: QueryCoverage(incomplete: true),
            summaryBased: true,
            summaryOwnerIds: ['garden'],
          ),
        );
      });

      await withClock(Clock.fixed(now), () => walker.walk(messageId));

      expect(factoryCalls, [
        (
          const QueryScope(kind: QueryScopeKind.task, id: 'garden'),
          'agent-garden',
          messageId,
        ),
      ]);
      final door = doors()[0]!;
      expect(door.status, FrontDoorStatus.done);
      expect(door.ownerTitle, 'Title of garden');
      expect(door.claimedAt, now.toUtc());
      final outcome = door.outcome! as FrontDoorAnswer;
      expect(outcome.text, 'The seam walk is next.');
      expect(outcome.summaryBased, isTrue);
      expect(outcome.incomplete, isTrue);
      expect(outcome.ownerIds, ['garden']);
      // The record is an action row of the front thread, keyed to the
      // source turn and the dispatch's run, under the deterministic id:
      // written once as the claim and once more as the outcome.
      final rows = upserts.whereType<AgentMessageEntity>().where(
        (m) =>
            m.id == frontDoorRecordId(dispatchId, 0) &&
            m.metadata.toolName == frontDoorToolName,
      );
      expect(rows, hasLength(2));
      final row = rows.last;
      expect(row.metadata.operationId, messageId);
      expect(row.metadata.runKey, 'run-1');
      expect(row.threadId, 'thread-1');
    });

    test('with no agent on the task, or a retired one, is skipped', () async {
      seedDispatch([
        segment(
          start: 0,
          end: 18,
          kind: FrontDestinationKind.task,
          id: 'garden',
        ),
      ]);
      taskAgents['garden'] = makeTestIdentity(
        id: 'agent-garden',
        agentId: 'agent-garden',
        lifecycle: AgentLifecycle.destroyed,
      );

      await walker.walk(messageId);

      expect(
        (doors()[0]!.outcome! as FrontDoorSkipped).reason,
        FrontDoorSkipReason.noAgent,
      );
      expect(factoryCalls, isEmpty);
    });

    test('whose owner has no usable inference setup is skipped', () async {
      seedDispatch([
        segment(
          start: 0,
          end: 18,
          kind: FrontDestinationKind.task,
          id: 'garden',
        ),
      ]);
      taskAgents['garden'] = garden;
      factoryError = const QueryInferenceUnavailable();

      await walker.walk(messageId);

      expect(
        (doors()[0]!.outcome! as FrontDoorSkipped).reason,
        FrontDoorSkipReason.inferenceUnavailable,
      );
    });

    test('a door that throws is recorded by its error type and the walk '
        'goes on to the next segment', () async {
      seedDispatch([
        segment(
          start: 0,
          end: 18,
          kind: FrontDestinationKind.task,
          id: 'garden',
        ),
        segment(
          start: 19,
          end: 24,
          kind: FrontDestinationKind.goal,
          id: 'goal-swim',
        ),
      ]);
      taskAgents['garden'] = garden;
      factoryError = const FormatException('scope gone');
      when(() => repository.getEntity('goal-swim')).thenAnswer(
        (_) async => makeTestIdentity(
          id: 'goal-swim',
          agentId: 'goal-swim',
          kind: AgentKinds.goalAgent,
        ),
      );
      when(
        () => goalChat.appendMessage(agentId: 'goal-swim', text: 'Swim?'),
      ).thenAnswer((_) async => 'gm-1');
      when(
        () => goalChat.enqueueMessage(agentId: 'goal-swim', messageId: 'gm-1'),
      ).thenReturn('run-g');

      await walker.walk(messageId);

      expect(
        (doors()[0]!.outcome! as FrontDoorFailed).errorType,
        'FormatException',
      );
      expect(doors()[1]!.outcome, isA<FrontDoorChatTurn>());
    });
  });

  test("a project question goes to the project agent's query scope", () async {
    seedDispatch([
      segment(
        start: 0,
        end: 18,
        kind: FrontDestinationKind.project,
        id: 'reloc',
      ),
    ]);
    projectAgents['reloc'] = makeTestIdentity(id: 'pa', agentId: 'pa');
    when(
      () => builder.build(
        chat: any(named: 'chat'),
        question: any(named: 'question'),
        memories: any(named: 'memories'),
        cancellation: any(named: 'cancellation'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer(
      (_) async => const QueryBuiltAnswer(
        answer: QueryChatAnswer(
          questionId: 'q',
          text: 'Surveys first.',
          coverage: QueryCoverage(),
        ),
      ),
    );

    await walker.walk(messageId);

    expect(factoryCalls.single.$1.kind, QueryScopeKind.project);
    expect(factoryCalls.single.$2, 'pa');
    expect((doors()[0]!.outcome! as FrontDoorAnswer).text, 'Surveys first.');
  });

  group('a goal or person question', () {
    test("is appended to the specialist's thread and its wake enqueued, "
        'never awaited', () async {
      seedDispatch([
        segment(
          start: 19,
          end: 24,
          kind: FrontDestinationKind.goal,
          id: 'goal-swim',
        ),
        segment(
          start: 25,
          end: 29,
          kind: FrontDestinationKind.person,
          id: 'pip',
        ),
      ]);
      when(() => repository.getEntity('goal-swim')).thenAnswer(
        (_) async => makeTestIdentity(
          id: 'goal-swim',
          agentId: 'goal-swim',
          kind: AgentKinds.goalAgent,
        ),
      );
      when(
        () => repository.getEntity(relationshipAgentIdFor('pip')),
      ).thenAnswer(
        (_) async => makeTestIdentity(
          id: relationshipAgentIdFor('pip'),
          agentId: relationshipAgentIdFor('pip'),
          kind: AgentKinds.relationshipAgent,
        ),
      );
      when(
        () => goalChat.appendMessage(agentId: 'goal-swim', text: 'Swim?'),
      ).thenAnswer((_) async => 'gm-1');
      when(
        () => goalChat.enqueueMessage(agentId: 'goal-swim', messageId: 'gm-1'),
      ).thenReturn('run-g');
      when(
        () => personChat.appendMessage(
          agentId: relationshipAgentIdFor('pip'),
          text: 'Pip?',
        ),
      ).thenAnswer((_) async => 'pm-1');
      when(
        () => personChat.enqueueMessage(
          agentId: relationshipAgentIdFor('pip'),
          messageId: 'pm-1',
        ),
      ).thenReturn('run-p');

      await walker.walk(messageId);

      final goal = doors()[0]!.outcome! as FrontDoorChatTurn;
      expect(goal.specialistAgentId, 'goal-swim');
      expect(goal.specialistMessageId, 'gm-1');
      final person = doors()[1]!.outcome! as FrontDoorChatTurn;
      expect(person.specialistAgentId, relationshipAgentIdFor('pip'));
      expect(person.specialistMessageId, 'pm-1');
      verifyNever(
        () => goalChat.retryMessage(
          agentId: any(named: 'agentId'),
          messageId: any(named: 'messageId'),
        ),
      );
      verifyNever(
        () => personChat.retryMessage(
          agentId: any(named: 'agentId'),
          messageId: any(named: 'messageId'),
        ),
      );
    });

    test('with a retired specialist is skipped', () async {
      seedDispatch([
        segment(
          start: 19,
          end: 24,
          kind: FrontDestinationKind.goal,
          id: 'goal-swim',
        ),
        segment(
          start: 25,
          end: 29,
          kind: FrontDestinationKind.person,
          id: 'pip',
        ),
      ]);
      when(() => repository.getEntity('goal-swim')).thenAnswer(
        (_) async => makeTestIdentity(
          id: 'goal-swim',
          agentId: 'goal-swim',
          kind: AgentKinds.goalAgent,
          lifecycle: AgentLifecycle.dormant,
        ),
      );

      await walker.walk(messageId);

      for (final index in [0, 1]) {
        expect(
          (doors()[index]!.outcome! as FrontDoorSkipped).reason,
          FrontDoorSkipReason.noAgent,
        );
      }
    });
  });

  test('statements wait for the filing slice; new, journal, day and unrouted '
      'segments have no door yet', () async {
    seedDispatch([
      segment(
        start: 30,
        end: 39,
        kind: FrontDestinationKind.task,
        id: 'garden',
        intent: FrontSegmentIntent.instruction,
      ),
      segment(
        start: 40,
        end: 56,
        kind: FrontDestinationKind.newThing,
        intent: FrontSegmentIntent.statement,
        newKind: FrontNewKind.goal,
      ),
    ]);

    await walker.walk(messageId);

    expect(
      (doors()[0]!.outcome! as FrontDoorSkipped).reason,
      FrontDoorSkipReason.statementsLater,
    );
    expect(
      (doors()[1]!.outcome! as FrontDoorSkipped).reason,
      FrontDoorSkipReason.noDoor,
    );
    // Only owners get a title looked up.
    verify(
      () => titles.titleFor(FrontDestinationKind.task, 'garden'),
    ).called(1);
    verifyNever(() => titles.titleFor(FrontDestinationKind.newThing, any()));
  });

  group('claims', () {
    AgentMessageEntity existingDoor(FrontDoorRecord record) {
      final payloadId = '${frontDoorRecordId(dispatchId, 0)}:payload';
      when(() => repository.getEntity(payloadId)).thenAnswer(
        (_) async => makeTestMessagePayload(
          id: payloadId,
          agentId: frontAgentId,
          content: record.toJson(),
        ),
      );
      return makeTestMessage(
        id: frontDoorRecordId(dispatchId, 0),
        agentId: frontAgentId,
        kind: AgentMessageKind.action,
        contentEntryId: payloadId,
      );
    }

    test('a segment already done, or freshly claimed by another walker, is '
        'left alone', () async {
      seedDispatch([
        segment(
          start: 25,
          end: 29,
          kind: FrontDestinationKind.person,
          id: 'pip',
        ),
      ]);
      final fresh = FrontDoorRecord(
        segmentIndex: 0,
        text: 'Pip?',
        kind: FrontDestinationKind.person,
        destinationId: 'pip',
        status: FrontDoorStatus.claimed,
        claimedAt: now.toUtc().subtract(const Duration(minutes: 5)),
      );
      when(
        () => repository.getEntity(frontDoorRecordId(dispatchId, 0)),
      ).thenAnswer((_) async => existingDoor(fresh));

      await withClock(Clock.fixed(now), () => walker.walk(messageId));

      expect(upserts, isEmpty);
      verifyNever(
        () => personChat.appendMessage(
          agentId: any(named: 'agentId'),
          text: any(named: 'text'),
        ),
      );
    });

    test('a claim older than the grace belongs to a dead walker and is '
        'taken over', () async {
      seedDispatch([
        segment(
          start: 25,
          end: 29,
          kind: FrontDestinationKind.person,
          id: 'pip',
        ),
      ]);
      final stale = FrontDoorRecord(
        segmentIndex: 0,
        text: 'Pip?',
        kind: FrontDestinationKind.person,
        destinationId: 'pip',
        status: FrontDoorStatus.claimed,
        claimedAt: now.toUtc().subtract(frontDoorClaimGrace),
      );
      when(
        () => repository.getEntity(frontDoorRecordId(dispatchId, 0)),
      ).thenAnswer((_) async => existingDoor(stale));
      when(
        () => repository.getEntity(relationshipAgentIdFor('pip')),
      ).thenAnswer(
        (_) async => makeTestIdentity(
          id: relationshipAgentIdFor('pip'),
          agentId: relationshipAgentIdFor('pip'),
          kind: AgentKinds.relationshipAgent,
        ),
      );
      when(
        () => personChat.appendMessage(
          agentId: relationshipAgentIdFor('pip'),
          text: 'Pip?',
        ),
      ).thenAnswer((_) async => 'pm-1');
      when(
        () => personChat.enqueueMessage(
          agentId: relationshipAgentIdFor('pip'),
          messageId: 'pm-1',
        ),
      ).thenReturn('run-p');

      await withClock(Clock.fixed(now), () => walker.walk(messageId));

      expect(doors()[0]!.status, FrontDoorStatus.done);
      expect(doors()[0]!.outcome, isA<FrontDoorChatTurn>());
    });

    test('the newest dispatch for a turn is the one walked', () async {
      final older = makeTestMessage(
        id: 'dispatch-old',
        agentId: frontAgentId,
        kind: AgentMessageKind.action,
        metadata: const AgentMessageMetadata(
          runKey: 'run-0',
          toolName: FrontAgentToolNames.dispatch,
          operationId: messageId,
        ),
        contentEntryId: 'old-payload',
        createdAt: DateTime(2000),
      );
      seedDispatch([
        segment(
          start: 40,
          end: 56,
          kind: FrontDestinationKind.unrouted,
          intent: FrontSegmentIntent.statement,
        ),
      ]);
      final newest = (await repository.getAgentMessages(frontAgentId)).single;
      when(
        () => repository.getAgentMessages(frontAgentId),
      ).thenAnswer((_) async => [older, newest]);

      await walker.walk(messageId);

      expect(doors()[0]!.kind, FrontDestinationKind.unrouted);
      verifyNever(() => repository.getEntity('old-payload'));
    });
  });
}
