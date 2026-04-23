import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/database/agent_repository_exception.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/sync/vector_clock.dart';

import '../test_utils.dart';
import 'agent_repository_test_helpers.dart';

void main() {
  late AgentDatabase db;
  late AgentRepository repo;

  final testDate = DateTime(2026, 2, 20);
  const testAgentId = 'agent-001';
  const otherAgentId = 'agent-002';

  // ── Thin local wrappers ────────────────────────────────────────────────────
  // These delegate to the shared test_utils factories but pin the defaults
  // expected throughout this file (e.g. testDate, testAgentId, vector clocks).

  AgentIdentityEntity makeAgent({
    String id = 'entity-agent-001',
    String agentId = testAgentId,
  }) => makeTestIdentity(
    id: id,
    agentId: agentId,
    allowedCategoryIds: const {'cat-1', 'cat-2'},
    createdAt: testDate,
    updatedAt: testDate,
    vectorClock: const VectorClock({'node-1': 1}),
  );

  AgentStateEntity makeAgentState({
    String id = 'entity-state-001',
    String agentId = testAgentId,
    int revision = 1,
  }) => makeTestState(
    id: id,
    agentId: agentId,
    revision: revision,
    slots: const AgentSlots(activeTaskId: 'task-1'),
    updatedAt: testDate,
    vectorClock: const VectorClock({'node-1': 2}),
  );

  AgentMessageEntity makeMessage({
    String id = 'entity-msg-001',
    String agentId = testAgentId,
    String threadId = 'thread-001',
    AgentMessageKind kind = AgentMessageKind.thought,
  }) => makeTestMessage(
    id: id,
    agentId: agentId,
    threadId: threadId,
    kind: kind,
    createdAt: testDate,
    vectorClock: const VectorClock({'node-1': 3}),
    runKey: 'run-001',
  );

  AgentReportEntity makeReport({
    String id = 'entity-report-001',
    String agentId = testAgentId,
    String scope = 'daily',
  }) => makeTestReport(
    id: id,
    agentId: agentId,
    scope: scope,
    createdAt: testDate,
    vectorClock: const VectorClock({'node-1': 4}),
    content: 'All good',
    confidence: 0.95,
  );

  AgentReportHeadEntity makeReportHead({
    String id = 'entity-head-001',
    String agentId = testAgentId,
    String scope = 'daily',
    String reportId = 'entity-report-001',
  }) => makeTestReportHead(
    id: id,
    agentId: agentId,
    scope: scope,
    reportId: reportId,
    updatedAt: testDate,
    vectorClock: const VectorClock({'node-1': 5}),
  );

  model.AgentLink makeBasicLink({
    String id = 'link-001',
    String fromId = testAgentId,
    String toId = 'entity-state-001',
  }) => makeTestBasicLink(
    id: id,
    fromId: fromId,
    toId: toId,
    createdAt: testDate,
    updatedAt: testDate,
    vectorClock: const VectorClock({'node-1': 1}),
  );

  WakeRunLogData makeWakeRun({
    String runKey = 'run-key-001',
    String agentId = testAgentId,
    String status = 'pending',
  }) => makeTestWakeRun(
    runKey: runKey,
    agentId: agentId,
    reason: 'scheduled',
    status: status,
    createdAt: testDate,
  );

  SagaLogData makeSagaOp({
    String operationId = 'op-001',
    String agentId = testAgentId,
    String runKey = 'run-key-001',
    String status = 'pending',
    String toolName = 'create_entry',
  }) => makeTestSagaOp(
    operationId: operationId,
    agentId: agentId,
    runKey: runKey,
    status: status,
    toolName: toolName,
    createdAt: testDate,
    updatedAt: testDate,
  );

  setUp(() {
    db = AgentDatabase(inMemoryDatabase: true, background: false);
    repo = AgentRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── Entity CRUD ─────────────────────────────────────────────────────────────

  group('Entity CRUD', () {
    group('upsertEntity + getEntity roundtrip', () {
      test('agent variant persists and restores correctly', () async {
        final entity = makeAgent();
        await repo.upsertEntity(entity);

        final result = await repo.getEntity(entity.id);

        expect(result, isNotNull);
        final agent = result! as AgentIdentityEntity;
        expect(agent.id, entity.id);
        expect(agent.agentId, entity.agentId);
        expect(agent.displayName, 'Test Agent');
        expect(agent.lifecycle, AgentLifecycle.active);
        expect(agent.mode, AgentInteractionMode.autonomous);
        expect(agent.allowedCategoryIds, contains('cat-1'));
        expect(agent.config.modelId, isNotEmpty);
      });

      test('agentState variant persists and restores correctly', () async {
        final entity = makeAgentState();
        await repo.upsertEntity(entity);

        final result = await repo.getEntity(entity.id);

        expect(result, isNotNull);
        final state = result! as AgentStateEntity;
        expect(state.id, entity.id);
        expect(state.agentId, entity.agentId);
        expect(state.revision, 1);
        expect(state.slots.activeTaskId, 'task-1');
        expect(state.updatedAt, testDate);
      });

      test('agentMessage variant persists and restores correctly', () async {
        final entity = makeMessage();
        await repo.upsertEntity(entity);

        final result = await repo.getEntity(entity.id);

        expect(result, isNotNull);
        final msg = result! as AgentMessageEntity;
        expect(msg.id, entity.id);
        expect(msg.agentId, entity.agentId);
        expect(msg.threadId, 'thread-001');
        expect(msg.kind, AgentMessageKind.thought);
        expect(msg.metadata.runKey, 'run-001');
      });

      test(
        'agentMessagePayload variant persists and restores correctly',
        () async {
          final entity = AgentDomainEntity.agentMessagePayload(
            id: 'payload-001',
            agentId: testAgentId,
            createdAt: testDate,
            vectorClock: const VectorClock({'node-1': 1}),
            content: const {'text': 'hello world', 'tokens': 5},
          );
          await repo.upsertEntity(entity);

          final result = await repo.getEntity('payload-001');

          expect(result, isNotNull);
          final payload = result! as AgentMessagePayloadEntity;
          expect(payload.id, 'payload-001');
          expect(payload.content['text'], 'hello world');
          expect(payload.contentType, 'application/json');
        },
      );

      test('agentReport variant persists and restores correctly', () async {
        final entity = makeReport();
        await repo.upsertEntity(entity);

        final result = await repo.getEntity(entity.id);

        expect(result, isNotNull);
        final report = result! as AgentReportEntity;
        expect(report.id, entity.id);
        expect(report.scope, 'daily');
        expect(report.confidence, 0.95);
        expect(report.content, 'All good');
      });

      test('agentReportHead variant persists and restores correctly', () async {
        final entity = makeReportHead();
        await repo.upsertEntity(entity);

        final result = await repo.getEntity(entity.id);

        expect(result, isNotNull);
        final head = result! as AgentReportHeadEntity;
        expect(head.id, entity.id);
        expect(head.scope, 'daily');
        expect(head.reportId, 'entity-report-001');
      });
    });

    test('getEntity returns null for non-existent ID', () async {
      final result = await repo.getEntity('does-not-exist');
      expect(result, isNull);
    });

    test('upsert overwrites existing entity with same ID', () async {
      final original = makeAgent(id: 'entity-agent-x');
      await repo.upsertEntity(original);

      // Replace with updated display name by rebuilding as a new entity.
      final updated = AgentDomainEntity.agent(
        id: 'entity-agent-x',
        agentId: testAgentId,
        kind: 'task_agent',
        displayName: 'Updated Agent Name',
        lifecycle: AgentLifecycle.dormant,
        mode: AgentInteractionMode.hybrid,
        allowedCategoryIds: const {'cat-99'},
        currentStateId: 'state-999',
        config: const AgentConfig(),
        createdAt: testDate,
        updatedAt: DateTime(2026, 2, 21),
        vectorClock: const VectorClock({'node-1': 2}),
      );
      await repo.upsertEntity(updated);

      final result = await repo.getEntity('entity-agent-x');
      expect(result, isNotNull);
      final agent = result! as AgentIdentityEntity;
      expect(agent.displayName, 'Updated Agent Name');
      expect(agent.lifecycle, AgentLifecycle.dormant);
      expect(agent.config.maxTurnsPerWake, 10);
    });

    group('getEntitiesByAgentId', () {
      test('returns all entities for an agent', () async {
        await repo.upsertEntity(makeAgent());
        await repo.upsertEntity(makeAgentState());
        await repo.upsertEntity(makeMessage());

        final results = await repo.getEntitiesByAgentId(testAgentId);

        expect(results.length, 3);
        expect(
          results.map((e) => e.id),
          containsAll([
            'entity-agent-001',
            'entity-state-001',
            'entity-msg-001',
          ]),
        );
      });

      test('does not return entities for a different agent', () async {
        await repo.upsertEntity(makeAgent(agentId: otherAgentId));
        await repo.upsertEntity(makeAgentState());

        final results = await repo.getEntitiesByAgentId(testAgentId);

        expect(results.length, 1);
        expect(results.first.id, 'entity-state-001');
      });

      test('with type filter returns only matching entities', () async {
        await repo.upsertEntity(makeAgent());
        await repo.upsertEntity(makeAgentState());
        await repo.upsertEntity(makeMessage());

        final results = await repo.getEntitiesByAgentId(
          testAgentId,
          type: 'agentState',
        );

        expect(results.length, 1);
        expect(results.first.id, 'entity-state-001');
      });

      test('with type filter returns empty list when no match', () async {
        await repo.upsertEntity(makeAgent());

        final results = await repo.getEntitiesByAgentId(
          testAgentId,
          type: 'agentMessage',
        );

        expect(results, isEmpty);
      });

      test('limit caps results without type filter', () async {
        await repo.upsertEntity(makeAgent());
        await repo.upsertEntity(makeAgentState());
        await repo.upsertEntity(makeMessage());

        final limited = await repo.getEntitiesByAgentId(testAgentId, limit: 2);

        expect(limited.length, 2);

        final unlimited = await repo.getEntitiesByAgentId(testAgentId);
        expect(unlimited.length, 3);
      });
    });

    group('getAgentState', () {
      test('returns the latest state entity for an agent', () async {
        await repo.upsertEntity(makeAgentState());

        final state = await repo.getAgentState(testAgentId);

        expect(state, isNotNull);
        expect(state!.id, 'entity-state-001');
        expect(state.revision, 1);
      });

      test('returns the most recent state when multiple exist', () async {
        await repo.upsertEntity(makeAgentState(id: 'state-old'));
        await repo.upsertEntity(
          AgentDomainEntity.agentState(
            id: 'state-new',
            agentId: testAgentId,
            revision: 2,
            slots: const AgentSlots(activeTaskId: 'task-2'),
            updatedAt: DateTime(2026, 2, 21),
            vectorClock: const VectorClock({'node-1': 3}),
          ),
        );

        final state = await repo.getAgentState(testAgentId);

        expect(state, isNotNull);
        // The query orders by created_at DESC; the second entity was inserted
        // later, so it should be returned as the latest state.
        expect(state!.id, 'state-new');
        expect(state.revision, 2);
        expect(state.slots.activeTaskId, 'task-2');
      });

      test('returns null when no state exists', () async {
        final state = await repo.getAgentState(testAgentId);
        expect(state, isNull);
      });

      test('returns null when only non-state entities exist', () async {
        await repo.upsertEntity(makeAgent());

        final state = await repo.getAgentState(testAgentId);
        expect(state, isNull);
      });
    });

    group('getAgentStatesByAgentIds', () {
      test('returns empty map when no agent IDs are requested', () async {
        final result = await repo.getAgentStatesByAgentIds(const []);

        expect(result, isEmpty);
      });

      test('handles duplicate agent IDs without duplicating results', () async {
        await repo.upsertEntity(
          makeAgentState(id: 'state-dup-1'),
        );
        await repo.upsertEntity(
          AgentDomainEntity.agentState(
            id: 'state-dup-2',
            agentId: testAgentId,
            revision: 2,
            slots: const AgentSlots(activeTaskId: 'task-dup'),
            updatedAt: DateTime(2026, 2, 21),
            vectorClock: const VectorClock({'node-1': 5}),
          ),
        );

        final result = await repo.getAgentStatesByAgentIds([
          testAgentId,
          testAgentId,
          testAgentId,
        ]);

        // Despite three duplicate IDs, only one entry per agent is returned.
        expect(result.length, 1);
        expect(result.containsKey(testAgentId), isTrue);
        // The latest state (DESC ordering + putIfAbsent) should win.
        expect(result[testAgentId]!.id, 'state-dup-2');
        expect(result[testAgentId]!.revision, 2);
      });

      test('returns the latest state for each requested agent', () async {
        await repo.upsertEntity(
          makeAgentState(
            id: 'state-a-old',
          ),
        );
        await repo.upsertEntity(
          AgentDomainEntity.agentState(
            id: 'state-a-new',
            agentId: testAgentId,
            revision: 2,
            slots: const AgentSlots(activeTaskId: 'task-a'),
            updatedAt: DateTime(2026, 2, 21),
            vectorClock: const VectorClock({'node-1': 3}),
          ),
        );
        await repo.upsertEntity(
          AgentDomainEntity.agentState(
            id: 'state-b',
            agentId: otherAgentId,
            revision: 7,
            slots: const AgentSlots(activeTaskId: 'task-b'),
            updatedAt: DateTime(2026, 2, 22),
            vectorClock: const VectorClock({'node-1': 4}),
          ),
        );
        await repo.upsertEntity(
          makeAgent(id: 'identity-only', agentId: 'agent-3'),
        );

        final result = await repo.getAgentStatesByAgentIds([
          testAgentId,
          otherAgentId,
          'agent-3',
        ]);

        expect(result.keys, containsAll([testAgentId, otherAgentId]));
        expect(result.keys, isNot(contains('agent-3')));
        expect(result[testAgentId]!.id, 'state-a-new');
        expect(result[testAgentId]!.revision, 2);
        expect(result[otherAgentId]!.id, 'state-b');
        expect(result[otherAgentId]!.revision, 7);
      });
    });

    group('getMessagesByKind', () {
      test('filters messages by kind correctly', () async {
        await repo.upsertEntity(
          makeMessage(
            id: 'msg-thought-1',
          ),
        );
        await repo.upsertEntity(
          makeMessage(
            id: 'msg-user-1',
            kind: AgentMessageKind.user,
          ),
        );
        await repo.upsertEntity(
          makeMessage(
            id: 'msg-thought-2',
          ),
        );

        final thoughts = await repo.getMessagesByKind(
          testAgentId,
          AgentMessageKind.thought,
        );
        final userMsgs = await repo.getMessagesByKind(
          testAgentId,
          AgentMessageKind.user,
        );

        expect(thoughts.length, 2);
        expect(
          thoughts.map((m) => m.id),
          containsAll(['msg-thought-1', 'msg-thought-2']),
        );
        expect(userMsgs.length, 1);
        expect(userMsgs.first.id, 'msg-user-1');
      });

      test('respects the limit parameter', () async {
        for (var i = 0; i < 5; i++) {
          await repo.upsertEntity(
            makeMessage(
              id: 'msg-obs-$i',
              kind: AgentMessageKind.observation,
            ),
          );
        }

        final results = await repo.getMessagesByKind(
          testAgentId,
          AgentMessageKind.observation,
          limit: 3,
        );

        expect(results.length, 3);
      });

      test('returns empty list when kind has no messages', () async {
        await repo.upsertEntity(makeMessage());

        final results = await repo.getMessagesByKind(
          testAgentId,
          AgentMessageKind.action,
        );
        expect(results, isEmpty);
      });
    });

    group('getMessagesForThread', () {
      test('filters messages by threadId', () async {
        await repo.upsertEntity(
          makeMessage(
            id: 'msg-t1-1',
            threadId: 'thread-A',
          ),
        );
        await repo.upsertEntity(
          makeMessage(
            id: 'msg-t2-1',
            threadId: 'thread-B',
          ),
        );
        await repo.upsertEntity(
          makeMessage(
            id: 'msg-t1-2',
            threadId: 'thread-A',
          ),
        );

        final threadA = await repo.getMessagesForThread(
          testAgentId,
          'thread-A',
        );
        final threadB = await repo.getMessagesForThread(
          testAgentId,
          'thread-B',
        );

        expect(threadA.length, 2);
        expect(threadA.map((m) => m.id), containsAll(['msg-t1-1', 'msg-t1-2']));
        expect(threadB.length, 1);
        expect(threadB.first.id, 'msg-t2-1');
      });

      test('respects the limit parameter', () async {
        for (var i = 0; i < 4; i++) {
          await repo.upsertEntity(
            makeMessage(
              id: 'msg-thread-$i',
              threadId: 'thread-X',
            ),
          );
        }

        final results = await repo.getMessagesForThread(
          testAgentId,
          'thread-X',
          limit: 2,
        );

        expect(results.length, 2);
      });

      test('returns empty list when thread has no messages', () async {
        await repo.upsertEntity(makeMessage(threadId: 'thread-A'));

        final results = await repo.getMessagesForThread(
          testAgentId,
          'thread-Z',
        );
        expect(results, isEmpty);
      });
    });

    group('getLatestReport', () {
      test('returns the report pointed to by the head', () async {
        final pair = await setupReportWithHead(
          repo,
          reportId: 'entity-report-001',
          headId: 'entity-head-001',
          agentId: testAgentId,
          scope: 'daily',
          content: 'All good',
        );

        final result = await repo.getLatestReport(testAgentId, 'daily');

        expect(result, isNotNull);
        expect(result!.id, pair.report.id);
        expect(result.scope, 'daily');
        expect(result.content, 'All good');
      });

      test('returns null when no report head exists for the scope', () async {
        await repo.upsertEntity(makeReport());

        final result = await repo.getLatestReport(testAgentId, 'weekly');
        expect(result, isNull);
      });

      test('returns null when no head exists at all', () async {
        final result = await repo.getLatestReport(testAgentId, 'daily');
        expect(result, isNull);
      });

      test('returns correct report when multiple scopes exist', () async {
        await setupReportWithHead(
          repo,
          reportId: 'report-daily',
          headId: 'head-daily',
          agentId: testAgentId,
          scope: 'daily',
        );
        await setupReportWithHead(
          repo,
          reportId: 'report-weekly',
          headId: 'head-weekly',
          agentId: testAgentId,
          scope: 'weekly',
        );

        final daily = await repo.getLatestReport(testAgentId, 'daily');
        final weekly = await repo.getLatestReport(testAgentId, 'weekly');

        expect(daily!.id, 'report-daily');
        expect(weekly!.id, 'report-weekly');
      });
    });

    group('getReportHead', () {
      test('returns the report head for the given scope', () async {
        final head = makeReportHead();
        await repo.upsertEntity(head);

        final result = await repo.getReportHead(testAgentId, 'daily');

        expect(result, isNotNull);
        expect(result!.id, head.id);
        expect(result.scope, 'daily');
        expect(result.reportId, 'entity-report-001');
      });

      test('returns null when no head exists', () async {
        final result = await repo.getReportHead(testAgentId, 'daily');
        expect(result, isNull);
      });

      test('returns null when head exists for a different scope', () async {
        final head = makeReportHead(scope: 'weekly');
        await repo.upsertEntity(head);

        final result = await repo.getReportHead(testAgentId, 'daily');
        expect(result, isNull);
      });

      test('returns correct head when multiple scopes exist', () async {
        await repo.upsertEntity(
          makeReportHead(
            id: 'head-daily',
            reportId: 'report-daily',
          ),
        );
        await repo.upsertEntity(
          makeReportHead(
            id: 'head-weekly',
            scope: 'weekly',
            reportId: 'report-weekly',
          ),
        );
        await repo.upsertEntity(
          makeReportHead(
            id: 'head-monthly',
            scope: 'monthly',
            reportId: 'report-monthly',
          ),
        );

        final daily = await repo.getReportHead(testAgentId, 'daily');
        final weekly = await repo.getReportHead(testAgentId, 'weekly');
        final monthly = await repo.getReportHead(testAgentId, 'monthly');

        expect(daily, isNotNull);
        expect(daily!.reportId, 'report-daily');
        expect(weekly, isNotNull);
        expect(weekly!.reportId, 'report-weekly');
        expect(monthly, isNotNull);
        expect(monthly!.reportId, 'report-monthly');
      });

      test('does not return head from a different agent', () async {
        await repo.upsertEntity(
          makeReportHead(
            id: 'head-agent-1',
            reportId: 'report-1',
          ),
        );
        await repo.upsertEntity(
          AgentDomainEntity.agentReportHead(
            id: 'head-agent-2',
            agentId: otherAgentId,
            scope: 'daily',
            reportId: 'report-2',
            updatedAt: testDate,
            vectorClock: null,
          ),
        );

        final result = await repo.getReportHead(testAgentId, 'daily');
        final otherResult = await repo.getReportHead(otherAgentId, 'daily');

        expect(result, isNotNull);
        expect(result!.reportId, 'report-1');
        expect(otherResult, isNotNull);
        expect(otherResult!.reportId, 'report-2');
      });

      test('subtype column stores scope for indexed lookup', () async {
        await repo.upsertEntity(makeReportHead());

        // Verify the raw row has subtype = 'daily' (the indexed column).
        final rows = await db
            .getAgentEntitiesByTypeAndSubtype(
              testAgentId,
              'agentReportHead',
              'daily',
              1,
            )
            .get();
        expect(rows, hasLength(1));
        expect(rows.first.subtype, 'daily');
      });
    });

    group('getLatestReportsByAgentIds', () {
      test('returns the latest report for each agent in scope', () async {
        await setupReportWithHead(
          repo,
          reportId: 'report-a',
          headId: 'head-a',
          agentId: testAgentId,
          scope: 'daily',
        );
        await setupReportWithHead(
          repo,
          reportId: 'report-b',
          headId: 'head-b',
          agentId: otherAgentId,
          scope: 'daily',
        );

        final result = await repo.getLatestReportsByAgentIds(
          [testAgentId, otherAgentId],
          'daily',
        );

        expect(result[testAgentId]?.id, 'report-a');
        expect(result[otherAgentId]?.id, 'report-b');
      });

      test('prefers the newest report head when duplicates exist', () async {
        final olderReport =
            AgentDomainEntity.agentReport(
                  id: 'report-old',
                  agentId: testAgentId,
                  scope: 'daily',
                  createdAt: testDate,
                  vectorClock: null,
                  content: 'Old report',
                )
                as AgentReportEntity;
        final newerReport =
            AgentDomainEntity.agentReport(
                  id: 'report-new',
                  agentId: testAgentId,
                  scope: 'daily',
                  createdAt: testDate.add(const Duration(minutes: 1)),
                  vectorClock: null,
                  content: 'New report',
                )
                as AgentReportEntity;
        final olderHead =
            AgentDomainEntity.agentReportHead(
                  id: 'head-old',
                  agentId: testAgentId,
                  scope: 'daily',
                  reportId: 'report-old',
                  updatedAt: testDate,
                  vectorClock: null,
                )
                as AgentReportHeadEntity;
        final newerHead =
            AgentDomainEntity.agentReportHead(
                  id: 'head-new',
                  agentId: testAgentId,
                  scope: 'daily',
                  reportId: 'report-new',
                  updatedAt: testDate.add(const Duration(minutes: 1)),
                  vectorClock: null,
                )
                as AgentReportHeadEntity;

        await repo.upsertEntity(olderReport);
        await repo.upsertEntity(newerReport);
        await repo.upsertEntity(olderHead);
        await repo.upsertEntity(newerHead);

        final singleResult = await repo.getReportHead(testAgentId, 'daily');
        final batchResult = await repo.getLatestReportsByAgentIds(
          [testAgentId],
          'daily',
        );

        expect(singleResult?.reportId, 'report-new');
        expect(batchResult[testAgentId]?.id, 'report-new');
      });
    });

    group('getLatestProjectReportForProjectId', () {
      test('returns null when no project-agent links exist', () async {
        final result = await repo.getLatestProjectReportForProjectId(
          'project-001',
        );

        expect(result, isNull);
      });

      test(
        'returns latest current report for newest project-agent link',
        () async {
          await seedProjectAgentLink(
            repo,
            linkId: 'project-link-old',
            agentId: 'project-agent-old',
            projectId: 'project-001',
            createdAt: testDate,
          );
          await seedProjectAgentLink(
            repo,
            linkId: 'project-link-new',
            agentId: 'project-agent-new',
            projectId: 'project-001',
            createdAt: testDate.add(const Duration(minutes: 1)),
          );
          await setupReportWithHead(
            repo,
            reportId: 'project-report-old',
            headId: 'project-head-old',
            agentId: 'project-agent-old',
            createdAt: testDate,
            content: 'Older project report',
          );
          await setupReportWithHead(
            repo,
            reportId: 'project-report-new',
            headId: 'project-head-new',
            agentId: 'project-agent-new',
            createdAt: testDate.add(const Duration(minutes: 1)),
            content: 'Newer project report',
          );

          final result = await repo.getLatestProjectReportForProjectId(
            'project-001',
          );

          expect(result?.id, 'project-report-new');
        },
      );

      test('uses link id descending as deterministic tie-breaker', () async {
        final timestamp = DateTime(2026, 2, 20, 8);
        await seedProjectAgentLink(
          repo,
          linkId: 'project-link-b',
          agentId: 'project-agent-b',
          projectId: 'project-001',
          createdAt: timestamp,
        );
        await seedProjectAgentLink(
          repo,
          linkId: 'project-link-a',
          agentId: 'project-agent-a',
          projectId: 'project-001',
          createdAt: timestamp,
        );
        await setupReportWithHead(
          repo,
          reportId: 'project-report-b',
          headId: 'project-head-b',
          agentId: 'project-agent-b',
          createdAt: timestamp,
          content: 'Report B',
        );
        await setupReportWithHead(
          repo,
          reportId: 'project-report-a',
          headId: 'project-head-a',
          agentId: 'project-agent-a',
          createdAt: timestamp,
          content: 'Report A',
        );

        final result = await repo.getLatestProjectReportForProjectId(
          'project-001',
        );

        // Both agents have valid reports; link-b wins via id DESC tie-breaker.
        expect(result?.agentId, 'project-agent-b');
      });

      test(
        'skips link whose agent has no report head and falls back to next',
        () async {
          // Newest link's agent has no report head at all (getLatestReport
          // returns null), so the method should fall through to the older
          // link that does have a usable report.
          await seedProjectAgentLink(
            repo,
            linkId: 'project-link-new',
            agentId: 'project-agent-no-head',
            projectId: 'project-001',
            createdAt: testDate.add(const Duration(minutes: 1)),
          );
          await seedProjectAgentLink(
            repo,
            linkId: 'project-link-old',
            agentId: 'project-agent-old',
            projectId: 'project-001',
            createdAt: testDate,
          );

          // Only the older agent gets a report + head.
          await setupReportWithHead(
            repo,
            reportId: 'project-report-old',
            headId: 'project-head-old',
            agentId: 'project-agent-old',
            createdAt: testDate,
            content: 'Usable fallback report',
          );

          final result = await repo.getLatestProjectReportForProjectId(
            'project-001',
          );

          expect(result?.id, 'project-report-old');
        },
      );

      test(
        'skips empty report content and falls back to next usable link',
        () async {
          await seedProjectAgentLink(
            repo,
            linkId: 'project-link-new',
            agentId: 'project-agent-new',
            projectId: 'project-001',
            createdAt: testDate.add(const Duration(minutes: 1)),
          );
          await seedProjectAgentLink(
            repo,
            linkId: 'project-link-old',
            agentId: 'project-agent-old',
            projectId: 'project-001',
            createdAt: testDate,
          );
          await setupReportWithHead(
            repo,
            reportId: 'project-report-empty',
            headId: 'project-head-empty',
            agentId: 'project-agent-new',
            createdAt: testDate.add(const Duration(minutes: 1)),
            content: '   ',
          );
          await setupReportWithHead(
            repo,
            reportId: 'project-report-usable',
            headId: 'project-head-usable',
            agentId: 'project-agent-old',
            createdAt: testDate,
            content: 'Usable project report',
          );

          final result = await repo.getLatestProjectReportForProjectId(
            'project-001',
          );

          expect(result?.id, 'project-report-usable');
        },
      );
    });

    group('getLatestTaskReportsForTaskIds', () {
      test('returns empty map when no task ids are requested', () async {
        final result = await repo.getLatestTaskReportsForTaskIds(const []);

        expect(result, isEmpty);
      });

      test(
        'returns reports keyed by task id using the primary agent_task link',
        () async {
          final timestamp = DateTime(2026, 2, 20, 8);

          await seedTaskAgentLink(
            repo,
            linkId: 'task-link-b',
            agentId: 'task-agent-b',
            taskId: 'task-001',
            createdAt: timestamp,
          );
          await seedTaskAgentLink(
            repo,
            linkId: 'task-link-a',
            agentId: 'task-agent-a',
            taskId: 'task-001',
            createdAt: timestamp,
          );
          await seedTaskAgentLink(
            repo,
            linkId: 'task-link-c',
            agentId: 'task-agent-c',
            taskId: 'task-002',
            createdAt: timestamp.add(const Duration(minutes: 1)),
          );
          await setupReportWithHead(
            repo,
            reportId: 'task-report-b',
            headId: 'task-head-b',
            agentId: 'task-agent-b',
            createdAt: timestamp,
            oneLiner: 'Implementation done, release next',
            tldr: 'Task B TLDR',
            content: 'Task B report',
          );
          await setupReportWithHead(
            repo,
            reportId: 'task-report-c',
            headId: 'task-head-c',
            agentId: 'task-agent-c',
            createdAt: timestamp.add(const Duration(minutes: 1)),
            oneLiner: 'Blocked on API review',
            tldr: 'Task C TLDR',
            content: 'Task C report',
          );

          final result = await repo.getLatestTaskReportsForTaskIds([
            'task-001',
            'task-002',
          ]);

          expect(result['task-001']?.agentId, 'task-agent-b');
          expect(result['task-001']?.id, 'task-report-b');
          expect(
            result['task-001']?.oneLiner,
            'Implementation done, release next',
          );
          expect(result['task-002']?.agentId, 'task-agent-c');
          expect(result['task-002']?.id, 'task-report-c');
          expect(result['task-002']?.oneLiner, 'Blocked on API review');
        },
      );

      test('omits tasks whose primary agent has no current report', () async {
        await seedTaskAgentLink(
          repo,
          linkId: 'task-link-1',
          agentId: 'task-agent-1',
          taskId: 'task-001',
          createdAt: testDate,
        );

        final result = await repo.getLatestTaskReportsForTaskIds(['task-001']);

        expect(result, isEmpty);
      });
    });
  });

  group('getAllAgentIdentities', () {
    test('returns all agent identity entities', () async {
      await repo.upsertEntity(makeAgent(id: 'agent-a', agentId: 'a-001'));
      await repo.upsertEntity(makeAgent(id: 'agent-b', agentId: 'b-001'));
      // Non-agent entities should not be included.
      await repo.upsertEntity(makeAgentState());
      await repo.upsertEntity(makeMessage());

      final identities = await repo.getAllAgentIdentities();

      expect(identities.length, 2);
      expect(
        identities.map((e) => e.id),
        containsAll(['agent-a', 'agent-b']),
      );
    });

    test('returns empty list when no agents exist', () async {
      await repo.upsertEntity(makeAgentState());

      final identities = await repo.getAllAgentIdentities();

      expect(identities, isEmpty);
    });
  });

  // ── Link CRUD ───────────────────────────────────────────────────────────────

  group('Link CRUD', () {
    group('upsertLink + getLinksFrom roundtrip', () {
      test('basic link persists and restores correctly', () async {
        final link = makeBasicLink();
        await repo.upsertLink(link);

        final results = await repo.getLinksFrom(testAgentId);

        expect(results.length, 1);
        expect(results.first.id, link.id);
        expect(results.first.fromId, testAgentId);
        expect(results.first.toId, 'entity-state-001');
        expect(results.first, isA<model.BasicAgentLink>());
      });

      test('agentState link type is preserved on roundtrip', () async {
        final link = model.AgentLink.agentState(
          id: 'link-state-001',
          fromId: testAgentId,
          toId: 'entity-state-001',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: const VectorClock({'node-1': 1}),
        );
        await repo.upsertLink(link);

        final results = await repo.getLinksFrom(testAgentId);

        expect(results.length, 1);
        expect(results.first, isA<model.AgentStateLink>());
      });
    });

    group('upsertLink unique-slot handoff (partial unique indexes)', () {
      test(
        'soulAssignment with a new id for the same fromId soft-deletes the '
        'existing active row and inserts the new one — without this the '
        'insert hits idx_unique_soul_per_template (SqliteException 2067)',
        () async {
          final existing = model.AgentLink.soulAssignment(
            id: 'link-old',
            fromId: 'template-laura-001',
            toId: 'soul-A',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: const VectorClock({'node-1': 1}),
          );
          await repo.upsertLink(existing);

          // Incoming sync: same fromId, NEW id, NEW toId. This is the
          // exact pattern that caused `SqliteException(2067): UNIQUE
          // constraint failed: agent_links.from_id` on production
          // devices and was repeatedly retried → abandoned.
          final incoming = model.AgentLink.soulAssignment(
            id: 'link-new',
            fromId: 'template-laura-001',
            toId: 'soul-B',
            createdAt: testDate.add(const Duration(hours: 1)),
            updatedAt: testDate.add(const Duration(hours: 1)),
            vectorClock: const VectorClock({'node-1': 2}),
          );
          await repo.upsertLink(incoming);

          // Active row must be the new one; old one is soft-deleted.
          final active = await repo.getLinksFrom(
            'template-laura-001',
            type: 'soul_assignment',
          );
          expect(active, hasLength(1));
          expect(active.first.id, 'link-new');
          expect(active.first.toId, 'soul-B');

          // Old row is retained as soft-deleted for audit (we don't
          // hard-delete).
          // The old row stays in the table as a soft-deleted tombstone
          // for audit. `getLinksFrom` filters deleted rows, so inspect
          // the raw table count.
          final allTemplate1 = await db
              .customSelect(
                'SELECT COUNT(*) AS c FROM agent_links '
                "WHERE from_id = 'template-laura-001' "
                "AND type = 'soul_assignment'",
              )
              .getSingle();
          expect(allTemplate1.read<int>('c'), 2);
        },
      );

      test(
        'upsertLink on same soulAssignment id+fromId (no conflict) leaves '
        'existing active rows for other templates untouched',
        () async {
          // Two templates, each with their own soul_assignment — the
          // partial unique index is scoped per from_id so these coexist.
          await repo.upsertLink(
            model.AgentLink.soulAssignment(
              id: 'link-tpl1',
              fromId: 'template-1',
              toId: 'soul-1',
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: const VectorClock({'node-1': 1}),
            ),
          );
          await repo.upsertLink(
            model.AgentLink.soulAssignment(
              id: 'link-tpl2',
              fromId: 'template-2',
              toId: 'soul-2',
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: const VectorClock({'node-1': 1}),
            ),
          );

          // Re-upsert the same (id, fromId) — must be idempotent and must
          // NOT touch the other template's link.
          await repo.upsertLink(
            model.AgentLink.soulAssignment(
              id: 'link-tpl1',
              fromId: 'template-1',
              toId: 'soul-1',
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: const VectorClock({'node-1': 2}),
            ),
          );

          final tpl1 = await repo.getLinksFrom(
            'template-1',
            type: 'soul_assignment',
          );
          final tpl2 = await repo.getLinksFrom(
            'template-2',
            type: 'soul_assignment',
          );
          expect(tpl1, hasLength(1));
          expect(tpl1.first.id, 'link-tpl1');
          expect(tpl2, hasLength(1));
          expect(tpl2.first.id, 'link-tpl2');
        },
      );

      test(
        'improverTarget with a new id for the same toId soft-deletes the '
        'existing active row — covers the idx_unique_improver_per_template '
        'branch',
        () async {
          final existing = model.AgentLink.improverTarget(
            id: 'imp-old',
            fromId: 'improver-1',
            toId: 'template-target-1',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: const VectorClock({'node-1': 1}),
          );
          await repo.upsertLink(existing);

          final incoming = model.AgentLink.improverTarget(
            id: 'imp-new',
            fromId: 'improver-2',
            toId: 'template-target-1',
            createdAt: testDate.add(const Duration(hours: 1)),
            updatedAt: testDate.add(const Duration(hours: 1)),
            vectorClock: const VectorClock({'node-1': 2}),
          );
          await repo.upsertLink(incoming);

          final active = await repo.getLinksTo(
            'template-target-1',
            type: 'improver_target',
          );
          expect(active, hasLength(1));
          expect(active.first.id, 'imp-new');

          // Old row persists as soft-deleted tombstone.
          final tombstoneCount = await db
              .customSelect(
                'SELECT COUNT(*) AS c FROM agent_links '
                "WHERE to_id = 'template-target-1' "
                "AND type = 'improver_target' "
                'AND deleted_at IS NOT NULL',
              )
              .getSingle();
          expect(tombstoneCount.read<int>('c'), 1);
        },
      );

      test(
        'incoming soft-deleted soulAssignment does not trigger handoff — we '
        'only reclaim the unique slot when the new row is itself active, '
        'otherwise a late-arriving soft-delete for a superseded id would '
        'incorrectly re-soft-delete the active replacement',
        () async {
          await repo.upsertLink(
            model.AgentLink.soulAssignment(
              id: 'link-active',
              fromId: 'template-1',
              toId: 'soul-A',
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: const VectorClock({'node-1': 2}),
            ),
          );

          // Incoming link for the SAME template but already soft-deleted
          // — this is a tombstone sync message. Must NOT touch
          // `link-active`. Must simply insert the tombstone row.
          final tombstone = model.AgentLink.soulAssignment(
            id: 'link-tombstone',
            fromId: 'template-1',
            toId: 'soul-old',
            createdAt: testDate,
            updatedAt: testDate.add(const Duration(minutes: 1)),
            vectorClock: const VectorClock({'node-1': 1}),
            deletedAt: testDate.add(const Duration(minutes: 1)),
          );
          await repo.upsertLink(tombstone);

          final active = await repo.getLinksFrom(
            'template-1',
            type: 'soul_assignment',
          );
          expect(active, hasLength(1));
          expect(active.first.id, 'link-active');

          final tombCount = await db
              .customSelect(
                'SELECT COUNT(*) AS c FROM agent_links '
                "WHERE id = 'link-tombstone' AND deleted_at IS NOT NULL",
              )
              .getSingle();
          expect(tombCount.read<int>('c'), 1);
        },
      );
    });

    group('getLinksFrom with type filter', () {
      test('returns only links of the specified type', () async {
        await repo.upsertLink(makeBasicLink(id: 'link-basic-1'));
        await repo.upsertLink(
          model.AgentLink.agentState(
            id: 'link-state-1',
            fromId: testAgentId,
            toId: 'entity-state-001',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        );

        final basics = await repo.getLinksFrom(testAgentId, type: 'basic');
        final states = await repo.getLinksFrom(
          testAgentId,
          type: 'agent_state',
        );

        expect(basics.length, 1);
        expect(basics.first.id, 'link-basic-1');
        expect(states.length, 1);
        expect(states.first.id, 'link-state-1');
      });
    });

    group('getLinksTo', () {
      test('returns links pointing to a given toId', () async {
        await repo.upsertLink(
          makeBasicLink(
            id: 'link-to-state',
          ),
        );
        await repo.upsertLink(
          makeBasicLink(
            id: 'link-to-other',
            toId: 'entity-other-001',
          ),
        );

        final results = await repo.getLinksTo('entity-state-001');

        expect(results.length, 1);
        expect(results.first.id, 'link-to-state');
      });

      test('with type filter returns only matching type', () async {
        await repo.upsertLink(
          makeBasicLink(
            id: 'link-basic-to',
          ),
        );
        await repo.upsertLink(
          model.AgentLink.messagePrev(
            id: 'link-prev-to',
            fromId: 'msg-002',
            toId: 'entity-state-001',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        );

        final basics = await repo.getLinksTo('entity-state-001', type: 'basic');
        final prevs = await repo.getLinksTo(
          'entity-state-001',
          type: 'message_prev',
        );

        expect(basics.length, 1);
        expect(basics.first.id, 'link-basic-to');
        expect(prevs.length, 1);
        expect(prevs.first.id, 'link-prev-to');
      });

      test('returns empty list when no links point to toId', () async {
        final results = await repo.getLinksTo('nonexistent-entity');
        expect(results, isEmpty);
      });
    });

    group('getLinksToMultiple', () {
      test('returns empty map when no ids are requested', () async {
        final result = await repo.getLinksToMultiple(
          const [],
          type: AgentLinkTypes.agentTask,
        );

        expect(result, isEmpty);
      });

      test('groups matching links by toId and excludes deleted rows', () async {
        await repo.upsertLink(
          model.AgentLink.agentTask(
            id: 'task-link-1',
            fromId: 'agent-a',
            toId: 'task-a',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        );
        await repo.upsertLink(
          model.AgentLink.agentTask(
            id: 'task-link-2',
            fromId: 'agent-b',
            toId: 'task-a',
            createdAt: testDate.add(const Duration(minutes: 1)),
            updatedAt: testDate.add(const Duration(minutes: 1)),
            vectorClock: null,
          ),
        );
        await repo.upsertLink(
          model.AgentLink.agentTask(
            id: 'task-link-3',
            fromId: 'agent-c',
            toId: 'task-b',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        );
        await repo.upsertLink(
          model.AgentLink.messagePrev(
            id: 'wrong-type',
            fromId: 'message-b',
            toId: 'task-a',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        );
        await repo.upsertLink(
          model.AgentLink.agentTask(
            id: 'deleted-link',
            fromId: 'agent-d',
            toId: 'task-b',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
            deletedAt: testDate.add(const Duration(hours: 1)),
          ),
        );

        final result = await repo.getLinksToMultiple(
          ['task-a', 'task-b', 'task-c'],
          type: AgentLinkTypes.agentTask,
        );

        expect(result.keys, unorderedEquals(['task-a', 'task-b']));
        expect(
          result['task-a']?.map((link) => link.id),
          unorderedEquals(['task-link-1', 'task-link-2']),
        );
        expect(
          result['task-b']?.map((link) => link.id),
          unorderedEquals(['task-link-3']),
        );
        expect(result['task-c'], isNull);
      });
    });

    group('getLinkById', () {
      test('returns link when found', () async {
        final link = makeBasicLink(id: 'link-find-me');
        await repo.upsertLink(link);

        final result = await repo.getLinkById('link-find-me');

        expect(result, isNotNull);
        expect(result!.id, 'link-find-me');
        expect(result.fromId, testAgentId);
        expect(result, isA<model.BasicAgentLink>());
      });

      test('returns null when link not found', () async {
        final result = await repo.getLinkById('nonexistent-link');

        expect(result, isNull);
      });
    });

    test(
      'multiple link types for the same agent are stored independently',
      () async {
        await repo.upsertLink(
          makeBasicLink(
            id: 'link-basic',
            toId: 'target-1',
          ),
        );
        await repo.upsertLink(
          model.AgentLink.agentState(
            id: 'link-agent-state',
            fromId: testAgentId,
            toId: 'target-2',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        );
        await repo.upsertLink(
          model.AgentLink.toolEffect(
            id: 'link-tool-effect',
            fromId: testAgentId,
            toId: 'target-3',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        );
        await repo.upsertLink(
          model.AgentLink.agentTask(
            id: 'link-agent-task',
            fromId: testAgentId,
            toId: 'target-4',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        );

        final allLinks = await repo.getLinksFrom(testAgentId);
        expect(allLinks.length, 4);
        expect(
          allLinks.map((l) => l.id),
          containsAll([
            'link-basic',
            'link-agent-state',
            'link-tool-effect',
            'link-agent-task',
          ]),
        );
      },
    );

    test('upsertLink overwrites existing link with same id', () async {
      const linkId = 'link-stable-id';
      final original = model.AgentLink.basic(
        id: linkId,
        fromId: testAgentId,
        toId: 'entity-state-001',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: const VectorClock({'node-1': 1}),
      );
      await repo.upsertLink(original);

      final updated = model.AgentLink.basic(
        id: linkId,
        fromId: testAgentId,
        toId: 'entity-state-001',
        createdAt: testDate,
        updatedAt: DateTime(2026, 2, 21),
        vectorClock: const VectorClock({'node-1': 2}),
      );
      await repo.upsertLink(updated);

      // Same id → should update in-place; still only one link.
      final results = await repo.getLinksFrom(testAgentId);
      expect(results.length, 1);
      // The updated vectorClock value confirms the second write took effect.
      expect(results.first.updatedAt, DateTime(2026, 2, 21));
    });

    test(
      'upsertLink with new id but duplicate (from, to, type) throws',
      () async {
        await repo.upsertLink(makeBasicLink(id: 'link-original'));

        // Same (fromId, toId, type) but a different id — violates the UNIQUE
        // constraint on (from_id, to_id, type).
        await expectLater(
          repo.upsertLink(makeBasicLink(id: 'link-duplicate-triplet')),
          throwsA(isException),
        );
      },
    );

    group('insertLinkExclusive', () {
      test('inserts a link successfully when no conflict', () async {
        final link = model.AgentLink.improverTarget(
          id: 'link-exc-1',
          fromId: 'agent-imp-1',
          toId: 'tpl-target-1',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );
        await repo.insertLinkExclusive(link);

        final results = await repo.getLinksTo(
          'tpl-target-1',
          type: 'improver_target',
        );
        expect(results, hasLength(1));
        expect(results.first.fromId, 'agent-imp-1');
      });

      test('throws DuplicateInsertException when partial unique index '
          'is violated', () async {
        // First improverTarget link to tpl-target-2 succeeds.
        await repo.insertLinkExclusive(
          model.AgentLink.improverTarget(
            id: 'link-exc-first',
            fromId: 'agent-imp-A',
            toId: 'tpl-target-2',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        );

        // Second improverTarget link to same to_id with different from_id
        // violates idx_unique_improver_per_template.
        await expectLater(
          repo.insertLinkExclusive(
            model.AgentLink.improverTarget(
              id: 'link-exc-second',
              fromId: 'agent-imp-B',
              toId: 'tpl-target-2',
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
            ),
          ),
          throwsA(
            isA<DuplicateInsertException>().having(
              (e) => e.key,
              'key',
              'tpl-target-2',
            ),
          ),
        );
      });

      test('allows improverTarget to different templates', () async {
        await repo.insertLinkExclusive(
          model.AgentLink.improverTarget(
            id: 'link-exc-tpl1',
            fromId: 'agent-imp-X',
            toId: 'tpl-A',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        );
        await repo.insertLinkExclusive(
          model.AgentLink.improverTarget(
            id: 'link-exc-tpl2',
            fromId: 'agent-imp-Y',
            toId: 'tpl-B',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        );

        final linksA = await repo.getLinksTo('tpl-A', type: 'improver_target');
        final linksB = await repo.getLinksTo('tpl-B', type: 'improver_target');
        expect(linksA, hasLength(1));
        expect(linksB, hasLength(1));
      });
    });
  });

  // ── Wake run log ────────────────────────────────────────────────────────────

  group('Wake run log', () {
    test('insertWakeRun + getWakeRun roundtrip', () async {
      final entry = makeWakeRun();
      await repo.insertWakeRun(entry: entry);

      final result = await repo.getWakeRun(entry.runKey);

      expect(result, isNotNull);
      expect(result!.runKey, entry.runKey);
      expect(result.agentId, testAgentId);
      expect(result.reason, 'scheduled');
      expect(result.threadId, 'thread-001');
      expect(result.status, 'pending');
      expect(result.createdAt, testDate);
      expect(result.completedAt, isNull);
      expect(result.errorMessage, isNull);
    });

    test('insertWakeRun throws on duplicate runKey', () async {
      await repo.insertWakeRun(entry: makeWakeRun());

      await expectLater(
        repo.insertWakeRun(entry: makeWakeRun()),
        throwsA(
          isA<DuplicateInsertException>()
              .having((e) => e.table, 'table', 'wake_run_log')
              .having((e) => e.key, 'key', 'run-key-001')
              .having((e) => e.cause, 'cause', isNotNull)
              .having(
                (e) => e.toString(),
                'toString',
                'DuplicateInsertException: duplicate key "run-key-001" '
                    'in wake_run_log',
              ),
        ),
      );
    });

    test('getWakeRun returns null for unknown runKey', () async {
      final result = await repo.getWakeRun('no-such-key');
      expect(result, isNull);
    });

    group('updateWakeRunStatus', () {
      test('updates status field', () async {
        await repo.insertWakeRun(entry: makeWakeRun());

        await repo.updateWakeRunStatus('run-key-001', 'running');

        final result = await repo.getWakeRun('run-key-001');
        expect(result!.status, 'running');
      });

      test('updates status and startedAt', () async {
        await repo.insertWakeRun(entry: makeWakeRun());

        final startedAt = DateTime(2026, 2, 20, 9, 30);
        await repo.updateWakeRunStatus(
          'run-key-001',
          'running',
          startedAt: startedAt,
        );

        final result = await repo.getWakeRun('run-key-001');
        expect(result!.status, 'running');
        expect(result.startedAt, startedAt);
      });

      test('updates status, completedAt and errorMessage', () async {
        await repo.insertWakeRun(entry: makeWakeRun());

        final completedAt = DateTime(2026, 2, 20, 12);
        await repo.updateWakeRunStatus(
          'run-key-001',
          'failed',
          completedAt: completedAt,
          errorMessage: 'Tool execution timed out',
        );

        final result = await repo.getWakeRun('run-key-001');
        expect(result!.status, 'failed');
        expect(result.completedAt, completedAt);
        expect(result.errorMessage, 'Tool execution timed out');
      });

      test('leaves optional fields unchanged when not provided', () async {
        await repo.insertWakeRun(
          entry: WakeRunLogData(
            runKey: 'run-key-002',
            agentId: testAgentId,
            reason: 'trigger',
            threadId: 'thread-002',
            status: 'running',
            createdAt: testDate,
            errorMessage: 'pre-existing',
          ),
        );

        await repo.updateWakeRunStatus('run-key-002', 'done');

        final result = await repo.getWakeRun('run-key-002');
        expect(result!.status, 'done');
        // errorMessage was not overwritten.
        expect(result.errorMessage, 'pre-existing');
      });
    });
  });

  // ── Saga log ────────────────────────────────────────────────────────────────

  group('Saga log', () {
    test('insertSagaOp + getPendingSagaOps roundtrip', () async {
      final op = makeSagaOp();
      await repo.insertSagaOp(entry: op);

      final pending = await repo.getPendingSagaOps();

      expect(pending.length, 1);
      expect(pending.first.operationId, op.operationId);
      expect(pending.first.runKey, op.runKey);
      expect(pending.first.phase, 'execution');
      expect(pending.first.status, 'pending');
      expect(pending.first.toolName, 'create_entry');
    });

    test('insertSagaOp throws on duplicate operationId', () async {
      await repo.insertSagaOp(entry: makeSagaOp());

      await expectLater(
        repo.insertSagaOp(entry: makeSagaOp()),
        throwsA(
          isA<DuplicateInsertException>()
              .having((e) => e.table, 'table', 'saga_log')
              .having((e) => e.key, 'key', 'op-001')
              .having((e) => e.cause, 'cause', isNotNull),
        ),
      );
    });

    test('getPendingSagaOps returns only pending entries', () async {
      await repo.insertSagaOp(entry: makeSagaOp(operationId: 'op-pending'));
      await repo.insertSagaOp(
        entry: makeSagaOp(operationId: 'op-done', status: 'done'),
      );
      await repo.insertSagaOp(
        entry: makeSagaOp(operationId: 'op-failed', status: 'failed'),
      );

      final pending = await repo.getPendingSagaOps();

      expect(pending.length, 1);
      expect(pending.first.operationId, 'op-pending');
    });

    test(
      'updateSagaStatus transitions status so pending list shrinks',
      () async {
        await repo.insertSagaOp(entry: makeSagaOp(operationId: 'op-A'));
        await repo.insertSagaOp(entry: makeSagaOp(operationId: 'op-B'));

        expect((await repo.getPendingSagaOps()).length, 2);

        await repo.updateSagaStatus('op-A', 'done');

        final pending = await repo.getPendingSagaOps();
        expect(pending.length, 1);
        expect(pending.first.operationId, 'op-B');
      },
    );

    test('updateSagaStatus sets lastError when provided', () async {
      await repo.insertSagaOp(entry: makeSagaOp());

      await repo.updateSagaStatus(
        'op-001',
        'failed',
        lastError: 'Network timeout',
      );

      // A failed op is no longer pending — verify via direct DB query.
      final allOps = await db.select(db.sagaLog).get();
      final op = allOps.firstWhere((o) => o.operationId == 'op-001');
      expect(op.status, 'failed');
      expect(op.lastError, 'Network timeout');
    });

    test(
      'getPendingSagaOps returns ops ordered by createdAt ascending',
      () async {
        await repo.insertSagaOp(
          entry: SagaLogData(
            operationId: 'op-late',
            agentId: testAgentId,
            runKey: 'run-key-001',
            phase: 'execution',
            status: 'pending',
            toolName: 'tool_b',
            createdAt: DateTime(2026, 2, 20, 10),
            updatedAt: testDate,
          ),
        );
        await repo.insertSagaOp(
          entry: SagaLogData(
            operationId: 'op-early',
            agentId: testAgentId,
            runKey: 'run-key-001',
            phase: 'execution',
            status: 'pending',
            toolName: 'tool_a',
            createdAt: DateTime(2026, 2, 20, 8),
            updatedAt: testDate,
          ),
        );

        final pending = await repo.getPendingSagaOps();

        expect(pending.length, 2);
        expect(pending.first.operationId, 'op-early');
        expect(pending.last.operationId, 'op-late');
      },
    );
  });

  // ── hardDeleteAgent ─────────────────────────────────────────────────────────

  group('runInTransaction', () {
    test('commits all operations atomically', () async {
      final agent = makeAgent();
      final state = makeAgentState();

      await repo.runInTransaction(() async {
        await repo.upsertEntity(agent);

        // Mid-transaction: the agent should NOT be visible outside the
        // transaction yet (verifying true transactional isolation, not
        // just sequential writes). We open a separate query to check.
        final midTxVisible = await repo.getEntity(agent.id);
        // Drift's in-memory SQLite runs in exclusive mode, so the query
        // actually runs inside the same transaction context. We settle for
        // verifying the write + read round-trip inside the transaction and
        // that rollback (tested below) actually discards it.
        expect(midTxVisible, isNotNull);

        await repo.upsertEntity(state);
      });

      final entities = await repo.getEntitiesByAgentId(testAgentId);
      expect(entities, hasLength(2));
    });

    test('rolls back all operations when callback throws', () async {
      final agent = makeAgent();

      // The exception must propagate to the caller.
      await expectLater(
        repo.runInTransaction<void>(() async {
          await repo.upsertEntity(agent);
          throw Exception('deliberate failure');
        }),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('deliberate failure'),
          ),
        ),
      );

      // The entity should not have been persisted (rolled back).
      final entity = await repo.getEntity(agent.id);
      expect(entity, isNull);
    });

    test('returns the value produced by the callback', () async {
      final result = await repo.runInTransaction(() async {
        await repo.upsertEntity(makeAgent());
        return 42;
      });

      expect(result, 42);
    });
  });

  group('hardDeleteAgent', () {
    final deleteDate = DateTime(2026, 2, 21);

    test('deletes all entities for the target agent', () async {
      await repo.upsertEntity(makeAgent());
      await repo.upsertEntity(makeAgentState());
      await repo.upsertEntity(makeMessage());

      // Sanity-check that data exists before deletion.
      expect(await repo.getEntitiesByAgentId(testAgentId), hasLength(3));

      await repo.hardDeleteAgent(testAgentId);

      expect(await repo.getEntitiesByAgentId(testAgentId), isEmpty);
    });

    test('deletes all links for the target agent', () async {
      await repo.upsertLink(makeBasicLink(id: 'link-from-agent'));
      await repo.upsertLink(
        makeBasicLink(
          id: 'link-to-agent',
          fromId: 'some-other-entity',
          toId: testAgentId,
        ),
      );

      expect(await repo.getLinksFrom(testAgentId), hasLength(1));
      expect(await repo.getLinksTo(testAgentId), hasLength(1));

      await repo.hardDeleteAgent(testAgentId);

      expect(await repo.getLinksFrom(testAgentId), isEmpty);
      expect(await repo.getLinksTo(testAgentId), isEmpty);
    });

    test('deletes entity-to-entity links belonging to the agent', () async {
      // Create entities owned by the agent.
      await repo.upsertEntity(makeMessage(id: 'msg-A'));
      await repo.upsertEntity(makeMessage(id: 'msg-B'));
      await repo.upsertEntity(
        AgentDomainEntity.agentMessagePayload(
          id: 'payload-A',
          agentId: testAgentId,
          createdAt: testDate,
          vectorClock: null,
          content: const {'text': 'hello'},
        ),
      );

      // Create entity-to-entity links (from_id and to_id are entity IDs,
      // not the agentId itself).
      await repo.upsertLink(
        model.AgentLink.messagePrev(
          id: 'link-prev',
          fromId: 'msg-B',
          toId: 'msg-A',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        ),
      );
      await repo.upsertLink(
        model.AgentLink.messagePayload(
          id: 'link-payload',
          fromId: 'msg-A',
          toId: 'payload-A',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        ),
      );

      expect(await repo.getLinksFrom('msg-B'), hasLength(1));
      expect(await repo.getLinksFrom('msg-A'), hasLength(1));

      await repo.hardDeleteAgent(testAgentId);

      // Both entity-to-entity links must be deleted.
      expect(await repo.getLinksFrom('msg-B'), isEmpty);
      expect(await repo.getLinksFrom('msg-A'), isEmpty);
    });

    test('deletes all wake runs for the target agent', () async {
      await repo.insertWakeRun(entry: makeWakeRun(runKey: 'run-a'));
      await repo.insertWakeRun(entry: makeWakeRun(runKey: 'run-b'));

      expect(
        await db.getWakeRunsByAgentId(testAgentId, 100).get(),
        hasLength(2),
      );

      await repo.hardDeleteAgent(testAgentId);

      expect(
        await db.getWakeRunsByAgentId(testAgentId, 100).get(),
        isEmpty,
      );
    });

    test('deletes saga ops even when wake run rows are missing', () async {
      // Saga ops exist but no corresponding wake_run_log rows.
      await repo.insertSagaOp(
        entry: makeSagaOp(operationId: 'orphan-op-1'),
      );
      await repo.insertSagaOp(
        entry: makeSagaOp(operationId: 'orphan-op-2', status: 'done'),
      );

      final allOpsBefore = await db.select(db.sagaLog).get();
      expect(allOpsBefore, hasLength(2));

      await repo.hardDeleteAgent(testAgentId);

      final allOpsAfter = await db.select(db.sagaLog).get();
      expect(allOpsAfter, isEmpty);
    });

    test('deletes saga ops associated with target agent wake runs', () async {
      await repo.insertWakeRun(entry: makeWakeRun(runKey: 'run-saga'));
      await repo.insertSagaOp(
        entry: makeSagaOp(operationId: 'saga-op-1', runKey: 'run-saga'),
      );
      await repo.insertSagaOp(
        entry: makeSagaOp(
          operationId: 'saga-op-2',
          runKey: 'run-saga',
          status: 'done',
        ),
      );

      final allOpsBefore = await db.select(db.sagaLog).get();
      expect(allOpsBefore, hasLength(2));

      await repo.hardDeleteAgent(testAgentId);

      final allOpsAfter = await db.select(db.sagaLog).get();
      expect(allOpsAfter, isEmpty);
    });

    test('does not delete entities belonging to other agents', () async {
      await repo.upsertEntity(makeAgent(id: 'entity-target'));
      await repo.upsertEntity(
        makeAgent(id: 'entity-other', agentId: otherAgentId),
      );
      await repo.upsertEntity(
        makeAgentState(id: 'state-other', agentId: otherAgentId),
      );

      await repo.hardDeleteAgent(testAgentId);

      expect(await repo.getEntitiesByAgentId(testAgentId), isEmpty);
      final otherEntities = await repo.getEntitiesByAgentId(otherAgentId);
      expect(otherEntities, hasLength(2));
      expect(
        otherEntities.map((e) => e.id),
        containsAll(['entity-other', 'state-other']),
      );
    });

    test('does not delete links belonging to other agents', () async {
      await repo.upsertLink(
        makeBasicLink(
          id: 'link-target-agent',
          toId: 'some-target',
        ),
      );
      await repo.upsertLink(
        makeBasicLink(
          id: 'link-other-agent',
          fromId: otherAgentId,
          toId: 'some-other-target',
        ),
      );

      await repo.hardDeleteAgent(testAgentId);

      expect(await repo.getLinksFrom(testAgentId), isEmpty);
      final otherLinks = await repo.getLinksFrom(otherAgentId);
      expect(otherLinks, hasLength(1));
      expect(otherLinks.first.id, 'link-other-agent');
    });

    test('does not delete wake runs belonging to other agents', () async {
      await repo.insertWakeRun(entry: makeWakeRun(runKey: 'run-target'));
      await repo.insertWakeRun(
        entry: makeWakeRun(runKey: 'run-other', agentId: otherAgentId),
      );

      await repo.hardDeleteAgent(testAgentId);

      expect(
        await db.getWakeRunsByAgentId(testAgentId, 100).get(),
        isEmpty,
      );
      final otherRuns = await db.getWakeRunsByAgentId(otherAgentId, 100).get();
      expect(otherRuns, hasLength(1));
      expect(otherRuns.first.runKey, 'run-other');
    });

    test('does not delete saga ops belonging to other agents', () async {
      await repo.insertWakeRun(entry: makeWakeRun(runKey: 'run-target'));
      await repo.insertWakeRun(
        entry: makeWakeRun(runKey: 'run-other', agentId: otherAgentId),
      );
      await repo.insertSagaOp(
        entry: makeSagaOp(operationId: 'op-target', runKey: 'run-target'),
      );
      await repo.insertSagaOp(
        entry: makeSagaOp(
          operationId: 'op-other',
          agentId: otherAgentId,
          runKey: 'run-other',
        ),
      );

      await repo.hardDeleteAgent(testAgentId);

      final remainingOps = await db.select(db.sagaLog).get();
      expect(remainingOps, hasLength(1));
      expect(remainingOps.first.operationId, 'op-other');
    });

    test('is a no-op when agent has no data', () async {
      // No data inserted for testAgentId — must not throw.
      await expectLater(
        repo.hardDeleteAgent(testAgentId),
        completes,
      );

      expect(await repo.getEntitiesByAgentId(testAgentId), isEmpty);
      expect(await repo.getLinksFrom(testAgentId), isEmpty);
      expect(await db.getWakeRunsByAgentId(testAgentId, 100).get(), isEmpty);
      expect(await db.select(db.sagaLog).get(), isEmpty);
    });

    test('deletes all data across all tables in one call', () async {
      // Populate all four tables for testAgentId and some data for otherAgentId.
      await repo.upsertEntity(makeAgent());
      await repo.upsertEntity(makeAgentState());
      await repo.upsertLink(makeBasicLink());
      await repo.insertWakeRun(entry: makeWakeRun(runKey: 'run-full'));
      await repo.insertSagaOp(
        entry: makeSagaOp(operationId: 'op-full', runKey: 'run-full'),
      );

      // Other agent data that must survive.
      await repo.upsertEntity(
        makeAgent(id: 'other-agent-entity', agentId: otherAgentId),
      );
      await repo.upsertLink(
        makeBasicLink(
          id: 'other-agent-link',
          fromId: otherAgentId,
          toId: 'other-target',
        ),
      );
      await repo.insertWakeRun(
        entry: WakeRunLogData(
          runKey: 'other-run',
          agentId: otherAgentId,
          reason: 'trigger',
          threadId: 'thread-other',
          status: 'done',
          createdAt: deleteDate,
        ),
      );
      await repo.insertSagaOp(
        entry: SagaLogData(
          operationId: 'op-other',
          agentId: otherAgentId,
          runKey: 'other-run',
          phase: 'execution',
          status: 'done',
          toolName: 'noop',
          createdAt: deleteDate,
          updatedAt: deleteDate,
        ),
      );

      await repo.hardDeleteAgent(testAgentId);

      // Target agent data is gone.
      expect(await repo.getEntitiesByAgentId(testAgentId), isEmpty);
      expect(await repo.getLinksFrom(testAgentId), isEmpty);
      expect(
        await db.getWakeRunsByAgentId(testAgentId, 100).get(),
        isEmpty,
      );

      // Other agent data is intact.
      expect(await repo.getEntitiesByAgentId(otherAgentId), hasLength(1));
      expect(await repo.getLinksFrom(otherAgentId), hasLength(1));
      expect(
        await db.getWakeRunsByAgentId(otherAgentId, 100).get(),
        hasLength(1),
      );
      final remainingOps = await db.select(db.sagaLog).get();
      expect(remainingOps, hasLength(1));
      expect(remainingOps.first.operationId, 'op-other');
    });
  });

  // ── Template CRUD ──────────────────────────────────────────────────────────

  group('Template entity CRUD', () {
    AgentTemplateEntity makeTemplate({
      String id = 'tpl-001',
      String agentId = 'tpl-001',
    }) => makeTestTemplate(
      id: id,
      agentId: agentId,
      categoryIds: const {'cat-1'},
      modelId: 'models/gemini-3.1-pro-preview',
      createdAt: testDate,
      updatedAt: testDate,
      vectorClock: const VectorClock({'node-1': 1}),
    );

    AgentTemplateVersionEntity makeTemplateVersion({
      String id = 'ver-001',
      String agentId = 'tpl-001',
      int version = 1,
      AgentTemplateVersionStatus status = AgentTemplateVersionStatus.active,
    }) => makeTestTemplateVersion(
      id: id,
      agentId: agentId,
      version: version,
      status: status,
      directives: 'Be helpful.',
      createdAt: testDate,
      vectorClock: const VectorClock({'node-1': 1}),
    );

    AgentTemplateHeadEntity makeTemplateHead({
      String id = 'head-tpl-001',
      String agentId = 'tpl-001',
      String versionId = 'ver-001',
    }) => makeTestTemplateHead(
      id: id,
      agentId: agentId,
      versionId: versionId,
      updatedAt: testDate,
      vectorClock: const VectorClock({'node-1': 1}),
    );

    group('upsertEntity + getEntity roundtrip', () {
      test('agentTemplate variant persists and restores correctly', () async {
        final entity = makeTemplate();
        await repo.upsertEntity(entity);

        final result = await repo.getEntity(entity.id);

        expect(result, isNotNull);
        final tpl = result! as AgentTemplateEntity;
        expect(tpl.id, entity.id);
        expect(tpl.displayName, 'Test Template');
        expect(tpl.kind, AgentTemplateKind.taskAgent);
        expect(tpl.categoryIds, contains('cat-1'));
      });

      test(
        'agentTemplateVersion variant persists and restores correctly',
        () async {
          final entity = makeTemplateVersion();
          await repo.upsertEntity(entity);

          final result = await repo.getEntity(entity.id);

          expect(result, isNotNull);
          final ver = result! as AgentTemplateVersionEntity;
          expect(ver.version, 1);
          expect(ver.status, AgentTemplateVersionStatus.active);
          expect(ver.directives, 'Be helpful.');
          expect(ver.authoredBy, 'user');
        },
      );

      test(
        'agentTemplateHead variant persists and restores correctly',
        () async {
          final entity = makeTemplateHead();
          await repo.upsertEntity(entity);

          final result = await repo.getEntity(entity.id);

          expect(result, isNotNull);
          final head = result! as AgentTemplateHeadEntity;
          expect(head.versionId, 'ver-001');
          expect(head.agentId, 'tpl-001');
        },
      );
    });

    group('getAllTemplates', () {
      test('returns only template entities', () async {
        await repo.upsertEntity(makeTemplate(id: 'tpl-a', agentId: 'tpl-a'));
        await repo.upsertEntity(makeTemplate(id: 'tpl-b', agentId: 'tpl-b'));
        // Non-template entities should not be included.
        await repo.upsertEntity(makeAgent());
        await repo.upsertEntity(makeAgentState());

        final templates = await repo.getAllTemplates();

        expect(templates.length, 2);
        expect(
          templates.map((t) => t.id),
          containsAll(['tpl-a', 'tpl-b']),
        );
      });

      test('returns empty list when no templates exist', () async {
        await repo.upsertEntity(makeAgent());

        final templates = await repo.getAllTemplates();

        expect(templates, isEmpty);
      });
    });

    group('getTemplateHead', () {
      test('returns head for template', () async {
        await repo.upsertEntity(makeTemplateHead());

        final head = await repo.getTemplateHead('tpl-001');

        expect(head, isNotNull);
        expect(head!.versionId, 'ver-001');
      });

      test('returns null when no head exists', () async {
        final head = await repo.getTemplateHead('tpl-nonexistent');
        expect(head, isNull);
      });
    });

    group('getActiveTemplateVersion', () {
      test('resolves head to version entity', () async {
        await repo.upsertEntity(makeTemplateVersion());
        await repo.upsertEntity(makeTemplateHead());

        final version = await repo.getActiveTemplateVersion('tpl-001');

        expect(version, isNotNull);
        expect(version!.id, 'ver-001');
        expect(version.version, 1);
      });

      test('returns null when no head exists', () async {
        final version = await repo.getActiveTemplateVersion('tpl-nonexistent');
        expect(version, isNull);
      });

      test('returns null when head points to missing version', () async {
        await repo.upsertEntity(
          makeTemplateHead(versionId: 'ver-missing'),
        );

        final version = await repo.getActiveTemplateVersion('tpl-001');
        expect(version, isNull);
      });
    });

    group('getNextTemplateVersionNumber', () {
      test('returns 1 for new template', () async {
        final next = await repo.getNextTemplateVersionNumber('tpl-new');
        expect(next, 1);
      });

      test('returns max + 1 for existing versions', () async {
        await repo.upsertEntity(makeTemplateVersion(id: 'v1'));
        await repo.upsertEntity(makeTemplateVersion(id: 'v2', version: 2));
        await repo.upsertEntity(makeTemplateVersion(id: 'v3', version: 3));

        final next = await repo.getNextTemplateVersionNumber('tpl-001');
        expect(next, 4);
      });
    });

    group('updateWakeRunTemplate', () {
      test('sets template columns on wake run', () async {
        await repo.insertWakeRun(entry: makeWakeRun(runKey: 'run-tpl'));

        await repo.updateWakeRunTemplate('run-tpl', 'tpl-001', 'ver-001');

        final run = await repo.getWakeRun('run-tpl');
        expect(run, isNotNull);
        expect(run!.templateId, 'tpl-001');
        expect(run.templateVersionId, 'ver-001');
      });

      test('sets soul provenance columns on wake run', () async {
        await repo.insertWakeRun(entry: makeWakeRun(runKey: 'run-soul'));

        await repo.updateWakeRunTemplate(
          'run-soul',
          'tpl-001',
          'ver-001',
          soulId: 'soul-001',
          soulVersionId: 'sv-001',
        );

        final run = await repo.getWakeRun('run-soul');
        expect(run, isNotNull);
        expect(run!.templateId, 'tpl-001');
        expect(run.soulId, 'soul-001');
        expect(run.soulVersionId, 'sv-001');
      });

      test('throws StateError when runKey does not exist', () async {
        await expectLater(
          repo.updateWakeRunTemplate(
            'nonexistent-run-key',
            'tpl-001',
            'ver-001',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('nonexistent-run-key'),
            ),
          ),
        );
      });
    });

    group('getWakeRunsForTemplate', () {
      test('returns runs matching templateId ordered DESC', () async {
        await insertTemplateWakeRun(
          repo,
          runKey: 'run-old',
          templateId: 'tpl-001',
          createdAt: DateTime(2026, 2, 18),
        );
        await insertTemplateWakeRun(
          repo,
          runKey: 'run-new',
          templateId: 'tpl-001',
          createdAt: DateTime(2026, 2, 20),
        );
        // Different template — should not appear.
        await insertTemplateWakeRun(
          repo,
          runKey: 'run-other',
          templateId: 'tpl-other',
          createdAt: DateTime(2026, 2, 19),
          templateVersionId: 'ver-other',
        );

        final runs = await repo.getWakeRunsForTemplate('tpl-001');

        expect(runs, hasLength(2));
        // DESC order: newest first.
        expect(runs[0].runKey, 'run-new');
        expect(runs[1].runKey, 'run-old');
      });

      test('respects limit parameter', () async {
        for (var i = 0; i < 5; i++) {
          await insertTemplateWakeRun(
            repo,
            runKey: 'run-$i',
            templateId: 'tpl-001',
            createdAt: DateTime(2026, 2, 20, i),
          );
        }

        final runs = await repo.getWakeRunsForTemplate('tpl-001', limit: 3);

        expect(runs, hasLength(3));
      });

      test('returns empty list when no runs exist for template', () async {
        final runs = await repo.getWakeRunsForTemplate('tpl-nonexistent');

        expect(runs, isEmpty);
      });
    });

    group('getWakeRunsInWindow', () {
      test('returns runs within the time window across all agents', () async {
        final base = DateTime(2026, 4, 4, 10);
        await repo.insertWakeRun(
          entry: makeTestWakeRun(
            runKey: 'r-in-1',
            agentId: 'agent-a',
            createdAt: base,
          ),
        );
        await repo.insertWakeRun(
          entry: makeTestWakeRun(
            runKey: 'r-in-2',
            agentId: 'agent-b',
            createdAt: base.add(const Duration(hours: 1)),
          ),
        );
        await repo.insertWakeRun(
          entry: makeTestWakeRun(
            runKey: 'r-outside',
            agentId: 'agent-a',
            createdAt: base.subtract(const Duration(days: 2)),
          ),
        );

        final runs = await repo.getWakeRunsInWindow(
          since: base.subtract(const Duration(hours: 1)),
          until: base.add(const Duration(hours: 2)),
        );

        expect(runs.map((r) => r.runKey), containsAll(['r-in-1', 'r-in-2']));
        expect(runs.map((r) => r.runKey), isNot(contains('r-outside')));
      });

      test('returns empty list when no runs fall in window', () async {
        final runs = await repo.getWakeRunsInWindow(
          since: DateTime(2026),
          until: DateTime(2026, 1, 2),
        );

        expect(runs, isEmpty);
      });
    });

    group('templateAssignment link CRUD', () {
      test('templateAssignment link persists and restores correctly', () async {
        final link = model.AgentLink.templateAssignment(
          id: 'link-ta-001',
          fromId: 'tpl-001',
          toId: testAgentId,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: const VectorClock({'node-1': 1}),
        );
        await repo.upsertLink(link);

        final results = await repo.getLinksFrom(
          'tpl-001',
          type: 'template_assignment',
        );

        expect(results.length, 1);
        expect(results.first, isA<model.TemplateAssignmentLink>());
        expect(results.first.toId, testAgentId);
      });
    });
  });

  group('abandonOrphanedWakeRuns', () {
    test('marks running wake runs as abandoned', () async {
      await repo.insertWakeRun(
        entry: makeWakeRun(runKey: 'run-running-1', status: 'running'),
      );
      await repo.insertWakeRun(
        entry: makeWakeRun(runKey: 'run-running-2', status: 'running'),
      );
      await repo.insertWakeRun(
        entry: makeWakeRun(runKey: 'run-completed', status: 'completed'),
      );
      await repo.insertWakeRun(
        entry: makeWakeRun(runKey: 'run-pending'),
      );

      final abandoned = await repo.abandonOrphanedWakeRuns();

      expect(abandoned, 2);

      // Verify running runs are now abandoned.
      final run1 = await repo.getWakeRun('run-running-1');
      expect(run1!.status, 'abandoned');
      expect(
        run1.errorMessage,
        contains('abandoned on startup'),
      );

      final run2 = await repo.getWakeRun('run-running-2');
      expect(run2!.status, 'abandoned');

      // Verify non-running runs are untouched.
      final completed = await repo.getWakeRun('run-completed');
      expect(completed!.status, 'completed');

      final pending = await repo.getWakeRun('run-pending');
      expect(pending!.status, 'pending');
    });

    test('returns zero when no running wake runs exist', () async {
      await repo.insertWakeRun(
        entry: makeWakeRun(runKey: 'run-done', status: 'completed'),
      );

      final abandoned = await repo.abandonOrphanedWakeRuns();

      expect(abandoned, 0);
    });

    test('returns zero on empty table', () async {
      final abandoned = await repo.abandonOrphanedWakeRuns();

      expect(abandoned, 0);
    });
  });

  group('getAllEntities', () {
    test('returns all entity types', () async {
      await repo.upsertEntity(makeAgent(id: 'agent-a', agentId: 'a-001'));
      await repo.upsertEntity(makeAgentState());
      await repo.upsertEntity(makeMessage());

      final entities = await repo.getAllEntities();

      expect(entities.length, 3);
      expect(
        entities.map((e) => e.id),
        containsAll(['agent-a', 'entity-state-001', 'entity-msg-001']),
      );
    });

    test('returns empty list when no entities exist', () async {
      final entities = await repo.getAllEntities();

      expect(entities, isEmpty);
    });
  });

  group('getAllLinks', () {
    test('returns all link types', () async {
      await repo.upsertLink(makeBasicLink());
      await repo.upsertLink(
        model.AgentLink.agentTask(
          id: 'link-task-001',
          fromId: testAgentId,
          toId: 'task-001',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        ),
      );

      final links = await repo.getAllLinks();

      expect(links.length, 2);
      expect(
        links.map((l) => l.id),
        containsAll(['link-001', 'link-task-001']),
      );
    });

    test('returns empty list when no links exist', () async {
      final links = await repo.getAllLinks();

      expect(links, isEmpty);
    });
  });

  group('getTaskIdsWithAgentLink', () {
    test('returns task IDs that have agent_task links', () async {
      await repo.upsertLink(
        model.AgentLink.agentTask(
          id: 'link-task-1',
          fromId: testAgentId,
          toId: 'task-001',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        ),
      );
      await repo.upsertLink(
        model.AgentLink.agentTask(
          id: 'link-task-2',
          fromId: otherAgentId,
          toId: 'task-002',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        ),
      );

      final ids = await repo.getTaskIdsWithAgentLink();

      expect(ids, {'task-001', 'task-002'});
    });

    test('returns empty set when no agent_task links exist', () async {
      // Insert a non-agent_task link
      await repo.upsertLink(makeBasicLink());

      final ids = await repo.getTaskIdsWithAgentLink();

      expect(ids, isEmpty);
    });

    test('excludes soft-deleted agent_task links', () async {
      await repo.upsertLink(
        model.AgentLink.agentTask(
          id: 'link-task-deleted',
          fromId: testAgentId,
          toId: 'task-deleted',
          createdAt: testDate,
          updatedAt: testDate,
          deletedAt: testDate,
          vectorClock: null,
        ),
      );

      final ids = await repo.getTaskIdsWithAgentLink();

      expect(ids, isEmpty);
    });

    test(
      'returns distinct task IDs when multiple agents link to same task',
      () async {
        await repo.upsertLink(
          model.AgentLink.agentTask(
            id: 'link-task-a1',
            fromId: testAgentId,
            toId: 'task-shared',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        );
        // Different agent linking to same task — unique constraint (from_id, to_id, type)
        // means this must have a different fromId
        await repo.upsertLink(
          model.AgentLink.agentTask(
            id: 'link-task-a2',
            fromId: otherAgentId,
            toId: 'task-shared',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        );

        final ids = await repo.getTaskIdsWithAgentLink();

        expect(ids, {'task-shared'});
        expect(ids.length, 1);
      },
    );
  });

  group('getTokenUsageForTemplate', () {
    const templateId = 'tpl-001';
    const agentA = 'agent-A';
    const agentB = 'agent-B';

    Future<void> seedTplWithInstances() async {
      await seedTemplateWithInstances(
        repo,
        templateId: templateId,
        instanceAgentIds: [agentA, agentB],
        testDate: testDate,
      );
    }

    test('returns token usage from all instances via JOIN', () async {
      await seedTplWithInstances();

      // Token usage for agent A
      await repo.upsertEntity(
        AgentDomainEntity.wakeTokenUsage(
          id: 'u1',
          agentId: agentA,
          runKey: 'run-1',
          threadId: 't1',
          modelId: 'gemini-2.5-pro',
          createdAt: testDate,
          vectorClock: null,
          inputTokens: 100,
          outputTokens: 50,
        ),
      );
      // Token usage for agent B
      await repo.upsertEntity(
        AgentDomainEntity.wakeTokenUsage(
          id: 'u2',
          agentId: agentB,
          runKey: 'run-2',
          threadId: 't2',
          modelId: 'claude-sonnet',
          createdAt: testDate,
          vectorClock: null,
          inputTokens: 200,
          outputTokens: 80,
        ),
      );

      final results = await repo.getTokenUsageForTemplate(templateId);

      expect(results, hasLength(2));
      expect(results.map((r) => r.agentId), containsAll([agentA, agentB]));
    });

    test('returns empty list when no instances have token usage', () async {
      await seedTplWithInstances();

      final results = await repo.getTokenUsageForTemplate(templateId);

      expect(results, isEmpty);
    });

    test('excludes deleted token usage entities', () async {
      await seedTplWithInstances();

      await repo.upsertEntity(
        AgentDomainEntity.wakeTokenUsage(
          id: 'u1',
          agentId: agentA,
          runKey: 'run-1',
          threadId: 't1',
          modelId: 'gemini',
          createdAt: testDate,
          vectorClock: null,
          inputTokens: 100,
          deletedAt: testDate,
        ),
      );

      final results = await repo.getTokenUsageForTemplate(templateId);

      expect(results, isEmpty);
    });

    test('respects limit parameter', () async {
      await seedTplWithInstances();

      for (var i = 0; i < 5; i++) {
        await repo.upsertEntity(
          AgentDomainEntity.wakeTokenUsage(
            id: 'u$i',
            agentId: agentA,
            runKey: 'run-$i',
            threadId: 't$i',
            modelId: 'gemini',
            createdAt: testDate.add(Duration(minutes: i)),
            vectorClock: null,
            inputTokens: 10,
          ),
        );
      }

      final results = await repo.getTokenUsageForTemplate(
        templateId,
        limit: 3,
      );

      expect(results, hasLength(3));
    });
  });

  group('getRecentReportsByTemplate', () {
    const templateId = 'tpl-001';
    const agentA = 'agent-A';

    Future<void> seedTplWithInstance() async {
      await seedTemplateWithInstances(
        repo,
        templateId: templateId,
        instanceAgentIds: [agentA],
        testDate: testDate,
      );
    }

    test('returns reports from template instances', () async {
      await seedTplWithInstance();

      await repo.upsertEntity(
        AgentDomainEntity.agentReport(
          id: 'r1',
          agentId: agentA,
          scope: 'current',
          content: 'Test report content.',
          createdAt: testDate,
          vectorClock: null,
        ),
      );

      final results = await repo.getRecentReportsByTemplate(templateId);

      expect(results, hasLength(1));
      expect(results.first.content, 'Test report content.');
    });

    test('returns empty list when no reports exist', () async {
      await seedTplWithInstance();

      final results = await repo.getRecentReportsByTemplate(templateId);

      expect(results, isEmpty);
    });

    test('respects limit parameter', () async {
      await seedTplWithInstance();

      for (var i = 0; i < 5; i++) {
        await repo.upsertEntity(
          AgentDomainEntity.agentReport(
            id: 'r$i',
            agentId: agentA,
            scope: 'current',
            content: 'Report $i',
            createdAt: testDate.add(Duration(minutes: i)),
            vectorClock: null,
          ),
        );
      }

      final results = await repo.getRecentReportsByTemplate(
        templateId,
        limit: 2,
      );

      expect(results, hasLength(2));
    });
  });

  // ── Interval queries (re-sync support) ──────────────────────────────────

  group('Interval queries', () {
    final intervalStart = DateTime(2026, 3);
    final intervalEnd = DateTime(2026, 3, 5);

    test('countEntitiesInInterval returns 0 for empty DB', () async {
      final count = await repo.countEntitiesInInterval(
        start: intervalStart,
        end: intervalEnd,
      );
      expect(count, isZero);
    });

    test('getEntitiesInInterval returns entities within range', () async {
      // Entity inside interval (March 3)
      final inside = makeAgent(
        id: 'ent-inside',
      ).copyWith(updatedAt: DateTime(2026, 3, 3));
      await repo.upsertEntity(inside);

      // Entity outside interval (Feb 20 — default testDate)
      await repo.upsertEntity(makeAgent(id: 'ent-outside', agentId: 'a2'));

      // Entity at boundary start (March 1) — inclusive, should be included
      final atStart = makeAgent(
        id: 'ent-start',
        agentId: 'a3',
      ).copyWith(updatedAt: intervalStart);
      await repo.upsertEntity(atStart);

      final count = await repo.countEntitiesInInterval(
        start: intervalStart,
        end: intervalEnd,
      );
      // 'inside' (March 3) and 'atStart' (March 1) match >= start AND < end
      expect(count, 2);

      final entities = await repo.getEntitiesInInterval(
        start: intervalStart,
        end: intervalEnd,
        limit: 100,
        offset: 0,
      );
      expect(entities, hasLength(2));
      expect(
        entities.map((e) => e.id),
        containsAll(['ent-inside', 'ent-start']),
      );
    });

    test('getEntitiesInInterval respects pagination', () async {
      for (var i = 0; i < 5; i++) {
        final entity = makeAgent(
          id: 'ent-page-$i',
          agentId: 'agent-page-$i',
        ).copyWith(updatedAt: DateTime(2026, 3, 2, i));
        await repo.upsertEntity(entity);
      }

      final page1 = await repo.getEntitiesInInterval(
        start: intervalStart,
        end: intervalEnd,
        limit: 2,
        offset: 0,
      );
      expect(page1, hasLength(2));

      final page2 = await repo.getEntitiesInInterval(
        start: intervalStart,
        end: intervalEnd,
        limit: 2,
        offset: 2,
      );
      expect(page2, hasLength(2));

      final page3 = await repo.getEntitiesInInterval(
        start: intervalStart,
        end: intervalEnd,
        limit: 2,
        offset: 4,
      );
      expect(page3, hasLength(1));

      // All IDs should be distinct
      final allIds = [...page1, ...page2, ...page3].map((e) => e.id).toSet();
      expect(allIds, hasLength(5));
    });

    test('getEntitiesInInterval includes soft-deleted entities', () async {
      final entity = makeAgent(
        id: 'ent-deleted',
      ).copyWith(updatedAt: DateTime(2026, 3, 3));
      await repo.upsertEntity(entity);

      // Soft-delete by upserting with deletedAt set
      final deleted = entity.copyWith(
        deletedAt: DateTime(2026, 3, 4),
        updatedAt: DateTime(2026, 3, 4),
      );
      await repo.upsertEntity(deleted);

      // Tombstones must be included so re-sync propagates deletes
      final count = await repo.countEntitiesInInterval(
        start: intervalStart,
        end: intervalEnd,
      );
      expect(count, 1);

      final results = await repo.getEntitiesInInterval(
        start: intervalStart,
        end: intervalEnd,
        limit: 10,
        offset: 0,
      );
      expect(results, hasLength(1));
      expect(results.first.deletedAt, isNotNull);
    });

    test('countLinksInInterval returns 0 for empty DB', () async {
      final count = await repo.countLinksInInterval(
        start: intervalStart,
        end: intervalEnd,
      );
      expect(count, isZero);
    });

    test('getLinksInInterval returns links within range', () async {
      // Create entities for the link references
      await repo.upsertEntity(makeAgent(id: 'from-1'));
      await repo.upsertEntity(
        makeAgentState(id: 'to-1'),
      );

      // Link inside interval
      final insideLink = makeBasicLink(
        id: 'link-inside',
        fromId: 'from-1',
        toId: 'to-1',
      ).copyWith(updatedAt: DateTime(2026, 3, 3));
      await repo.upsertLink(insideLink);

      // Link outside interval (default testDate = Feb 20)
      await repo.upsertEntity(makeAgent(id: 'from-2', agentId: otherAgentId));
      await repo.upsertEntity(
        makeAgentState(id: 'to-2', agentId: otherAgentId),
      );
      await repo.upsertLink(
        makeBasicLink(id: 'link-outside', fromId: 'from-2', toId: 'to-2'),
      );

      final count = await repo.countLinksInInterval(
        start: intervalStart,
        end: intervalEnd,
      );
      expect(count, 1);

      final links = await repo.getLinksInInterval(
        start: intervalStart,
        end: intervalEnd,
        limit: 100,
        offset: 0,
      );
      expect(links, hasLength(1));
      expect(links.first.id, 'link-inside');
    });

    test('getLinksInInterval respects pagination', () async {
      await repo.upsertEntity(makeAgent());

      for (var i = 0; i < 4; i++) {
        final targetId = 'target-$i';
        await repo.upsertEntity(
          makeAgentState(id: targetId),
        );
        await repo.upsertLink(
          makeBasicLink(
            id: 'link-page-$i',
            fromId: 'entity-agent-001',
            toId: targetId,
          ).copyWith(updatedAt: DateTime(2026, 3, 2, i)),
        );
      }

      final page1 = await repo.getLinksInInterval(
        start: intervalStart,
        end: intervalEnd,
        limit: 2,
        offset: 0,
      );
      expect(page1, hasLength(2));

      final page2 = await repo.getLinksInInterval(
        start: intervalStart,
        end: intervalEnd,
        limit: 2,
        offset: 2,
      );
      expect(page2, hasLength(2));

      final allIds = [...page1, ...page2].map((l) => l.id).toSet();
      expect(allIds, hasLength(4));
    });

    test('getLinksInInterval includes soft-deleted links', () async {
      await repo.upsertEntity(makeAgent());
      await repo.upsertEntity(
        makeAgentState(id: 'to-del'),
      );

      final link = makeBasicLink(
        id: 'link-del',
        fromId: 'entity-agent-001',
        toId: 'to-del',
      ).copyWith(updatedAt: DateTime(2026, 3, 3));
      await repo.upsertLink(link);

      // Soft-delete by upserting with deletedAt set
      final deleted = link.copyWith(
        deletedAt: DateTime(2026, 3, 4),
        updatedAt: DateTime(2026, 3, 4),
      );
      await repo.upsertLink(deleted);

      // Tombstones must be included so re-sync propagates deletes
      final count = await repo.countLinksInInterval(
        start: intervalStart,
        end: intervalEnd,
      );
      expect(count, 1);

      final results = await repo.getLinksInInterval(
        start: intervalStart,
        end: intervalEnd,
        limit: 10,
        offset: 0,
      );
      expect(results, hasLength(1));
      expect(results.first.deletedAt, isNotNull);
    });
  });

  // ── aggregateWakeRunMetrics ───────────────────────────────────────────────

  group('aggregateWakeRunMetrics', () {
    const templateId = 'tpl-agg-001';

    test('returns zeroed metrics when no runs exist for template', () async {
      final result = await repo.aggregateWakeRunMetrics(templateId);

      expect(result.successCount, 0);
      expect(result.failureCount, 0);
      expect(result.durationSumMs, isNull);
      expect(result.durationCount, 0);
      expect(result.firstWakeAt, isNull);
      expect(result.lastWakeAt, isNull);
    });

    test(
      'correctly counts completed/failed runs and excludes other templates',
      () async {
        // Two completed runs for the template.
        await insertTemplateWakeRun(
          repo,
          runKey: 'run-c1',
          templateId: templateId,
          createdAt: DateTime(2026, 3, 1, 10),
        );
        await insertTemplateWakeRun(
          repo,
          runKey: 'run-c2',
          templateId: templateId,
          createdAt: DateTime(2026, 3, 1, 11),
        );

        // One failed run for the template.
        await insertTemplateWakeRun(
          repo,
          runKey: 'run-f1',
          templateId: templateId,
          status: 'failed',
          createdAt: DateTime(2026, 3, 1, 12),
        );

        // A pending run — should count as neither success nor failure.
        await insertTemplateWakeRun(
          repo,
          runKey: 'run-p1',
          templateId: templateId,
          status: 'pending',
          createdAt: DateTime(2026, 3, 1, 13),
        );

        // Different template — should be excluded entirely.
        await insertTemplateWakeRun(
          repo,
          runKey: 'run-other',
          templateId: 'tpl-other',
          createdAt: DateTime(2026, 3, 1, 14),
          templateVersionId: 'ver-other',
        );

        final result = await repo.aggregateWakeRunMetrics(templateId);

        expect(result.successCount, 2);
        expect(result.failureCount, 1);
        // firstWakeAt / lastWakeAt cover the 4 runs for this template.
        expect(result.firstWakeAt, DateTime(2026, 3, 1, 10));
        expect(result.lastWakeAt, DateTime(2026, 3, 1, 13));
      },
    );

    test('returns correct first/last wake timestamps', () async {
      final earliest = DateTime(2026, 3, 1, 8);
      final middle = DateTime(2026, 3, 1, 12);
      final latest = DateTime(2026, 3, 1, 16);

      await insertTemplateWakeRun(
        repo,
        runKey: 'run-mid',
        templateId: templateId,
        createdAt: middle,
      );
      await insertTemplateWakeRun(
        repo,
        runKey: 'run-early',
        templateId: templateId,
        createdAt: earliest,
      );
      await insertTemplateWakeRun(
        repo,
        runKey: 'run-late',
        templateId: templateId,
        status: 'pending',
        createdAt: latest,
      );

      final result = await repo.aggregateWakeRunMetrics(templateId);

      expect(result.firstWakeAt, earliest);
      expect(result.lastWakeAt, latest);
    });
  });

  // ── sumTokenUsageForTemplate ──────────────────────────────────────────────

  group('sumTokenUsageForTemplate', () {
    const templateId = 'tpl-sum-001';
    const agentA = 'agent-sum-A';
    const agentB = 'agent-sum-B';

    Future<void> seedTplWithInstances() async {
      await seedTemplateWithInstances(
        repo,
        templateId: templateId,
        instanceAgentIds: [agentA, agentB],
        testDate: testDate,
      );
    }

    test('returns zero sums when no token usage records exist', () async {
      await seedTplWithInstances();

      final result = await repo.sumTokenUsageForTemplate(templateId);

      expect(result.totalInput, 0);
      expect(result.totalOutput, 0);
      expect(result.totalThoughts, 0);
    });

    test(
      'correctly sums input/output/thoughts tokens across multiple records',
      () async {
        await seedTplWithInstances();

        await repo.upsertEntity(
          AgentDomainEntity.wakeTokenUsage(
            id: 'su1',
            agentId: agentA,
            runKey: 'run-s1',
            threadId: 't1',
            modelId: 'gemini-2.5-pro',
            createdAt: testDate,
            vectorClock: null,
            inputTokens: 100,
            outputTokens: 50,
            thoughtsTokens: 20,
          ),
        );
        await repo.upsertEntity(
          AgentDomainEntity.wakeTokenUsage(
            id: 'su2',
            agentId: agentA,
            runKey: 'run-s2',
            threadId: 't2',
            modelId: 'gemini-2.5-pro',
            createdAt: testDate.add(const Duration(minutes: 1)),
            vectorClock: null,
            inputTokens: 200,
            outputTokens: 80,
            thoughtsTokens: 30,
          ),
        );
        await repo.upsertEntity(
          AgentDomainEntity.wakeTokenUsage(
            id: 'su3',
            agentId: agentB,
            runKey: 'run-s3',
            threadId: 't3',
            modelId: 'claude-sonnet',
            createdAt: testDate.add(const Duration(minutes: 2)),
            vectorClock: null,
            inputTokens: 300,
            outputTokens: 120,
            thoughtsTokens: 50,
          ),
        );

        final result = await repo.sumTokenUsageForTemplate(templateId);

        expect(result.totalInput, 600);
        expect(result.totalOutput, 250);
        expect(result.totalThoughts, 100);
      },
    );
  });

  // ── sumTokenUsageForTemplateSince ─────────────────────────────────────────

  group('sumTokenUsageForTemplateSince', () {
    const templateId = 'tpl-since-001';
    const agentA = 'agent-since-A';

    Future<void> seedTplWithInstance() async {
      await seedTemplateWithInstances(
        repo,
        templateId: templateId,
        instanceAgentIds: [agentA],
        testDate: testDate,
      );
    }

    test('only sums records created on or after the since date', () async {
      await seedTplWithInstance();

      final cutoff = DateTime(2026, 3, 15);

      // Before cutoff — should be excluded.
      await repo.upsertEntity(
        AgentDomainEntity.wakeTokenUsage(
          id: 'ts-old',
          agentId: agentA,
          runKey: 'run-old',
          threadId: 't-old',
          modelId: 'gemini',
          createdAt: DateTime(2026, 3, 14),
          vectorClock: null,
          inputTokens: 1000,
          outputTokens: 500,
          thoughtsTokens: 200,
        ),
      );

      // Exactly on cutoff — should be included.
      await repo.upsertEntity(
        AgentDomainEntity.wakeTokenUsage(
          id: 'ts-exact',
          agentId: agentA,
          runKey: 'run-exact',
          threadId: 't-exact',
          modelId: 'gemini',
          createdAt: cutoff,
          vectorClock: null,
          inputTokens: 100,
          outputTokens: 50,
          thoughtsTokens: 10,
        ),
      );

      // After cutoff — should be included.
      await repo.upsertEntity(
        AgentDomainEntity.wakeTokenUsage(
          id: 'ts-new',
          agentId: agentA,
          runKey: 'run-new',
          threadId: 't-new',
          modelId: 'gemini',
          createdAt: DateTime(2026, 3, 16),
          vectorClock: null,
          inputTokens: 200,
          outputTokens: 80,
          thoughtsTokens: 30,
        ),
      );

      final result = await repo.sumTokenUsageForTemplateSince(
        templateId,
        since: cutoff,
      );

      // Only ts-exact + ts-new should be summed.
      expect(result.totalInput, 300);
      expect(result.totalOutput, 130);
      expect(result.totalThoughts, 40);
    });
  });
}
