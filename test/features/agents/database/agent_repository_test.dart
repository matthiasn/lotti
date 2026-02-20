import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/sync/vector_clock.dart';

void main() {
  late AgentDatabase db;
  late AgentRepository repo;

  final testDate = DateTime(2026, 2, 20);
  const testAgentId = 'agent-001';
  const otherAgentId = 'agent-002';

  setUp(() {
    db = AgentDatabase(inMemoryDatabase: true, background: false);
    repo = AgentRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── Shared test factories ───────────────────────────────────────────────────

  AgentIdentityEntity makeAgent({
    String id = 'entity-agent-001',
    String agentId = testAgentId,
  }) {
    return AgentDomainEntity.agent(
      id: id,
      agentId: agentId,
      kind: 'task_agent',
      displayName: 'Test Agent',
      lifecycle: AgentLifecycle.active,
      mode: AgentInteractionMode.autonomous,
      allowedCategoryIds: const {'cat-1', 'cat-2'},
      currentStateId: 'state-001',
      config: const AgentConfig(),
      createdAt: testDate,
      updatedAt: testDate,
      vectorClock: const VectorClock({'node-1': 1}),
    ) as AgentIdentityEntity;
  }

  AgentStateEntity makeAgentState({
    String id = 'entity-state-001',
    String agentId = testAgentId,
    int revision = 1,
  }) {
    return AgentDomainEntity.agentState(
      id: id,
      agentId: agentId,
      revision: revision,
      slots: const AgentSlots(activeTaskId: 'task-1'),
      updatedAt: testDate,
      vectorClock: const VectorClock({'node-1': 2}),
    ) as AgentStateEntity;
  }

  AgentMessageEntity makeMessage({
    String id = 'entity-msg-001',
    String agentId = testAgentId,
    String threadId = 'thread-001',
    AgentMessageKind kind = AgentMessageKind.thought,
  }) {
    return AgentDomainEntity.agentMessage(
      id: id,
      agentId: agentId,
      threadId: threadId,
      kind: kind,
      createdAt: testDate,
      vectorClock: const VectorClock({'node-1': 3}),
      metadata: const AgentMessageMetadata(runKey: 'run-001'),
    ) as AgentMessageEntity;
  }

  AgentReportEntity makeReport({
    String id = 'entity-report-001',
    String agentId = testAgentId,
    String scope = 'daily',
  }) {
    return AgentDomainEntity.agentReport(
      id: id,
      agentId: agentId,
      scope: scope,
      createdAt: testDate,
      vectorClock: const VectorClock({'node-1': 4}),
      content: const {'summary': 'All good'},
      confidence: 0.95,
    ) as AgentReportEntity;
  }

  AgentReportHeadEntity makeReportHead({
    String id = 'entity-head-001',
    String agentId = testAgentId,
    String scope = 'daily',
    String reportId = 'entity-report-001',
  }) {
    return AgentDomainEntity.agentReportHead(
      id: id,
      agentId: agentId,
      scope: scope,
      reportId: reportId,
      updatedAt: testDate,
      vectorClock: const VectorClock({'node-1': 5}),
    ) as AgentReportHeadEntity;
  }

  model.AgentLink makeBasicLink({
    String id = 'link-001',
    String fromId = testAgentId,
    String toId = 'entity-state-001',
  }) {
    return model.AgentLink.basic(
      id: id,
      fromId: fromId,
      toId: toId,
      createdAt: testDate,
      updatedAt: testDate,
      vectorClock: const VectorClock({'node-1': 1}),
    );
  }

  WakeRunLogData makeWakeRun({
    String runKey = 'run-key-001',
    String agentId = testAgentId,
    String status = 'pending',
  }) {
    return WakeRunLogData(
      runKey: runKey,
      agentId: agentId,
      reason: 'scheduled',
      threadId: 'thread-001',
      status: status,
      createdAt: testDate,
    );
  }

  SagaLogData makeSagaOp({
    String operationId = 'op-001',
    String runKey = 'run-key-001',
    String status = 'pending',
    String toolName = 'create_entry',
  }) {
    return SagaLogData(
      operationId: operationId,
      runKey: runKey,
      phase: 'execution',
      status: status,
      toolName: toolName,
      createdAt: testDate,
      updatedAt: testDate,
    );
  }

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

      test('agentMessagePayload variant persists and restores correctly',
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
      });

      test('agentReport variant persists and restores correctly', () async {
        final entity = makeReport();
        await repo.upsertEntity(entity);

        final result = await repo.getEntity(entity.id);

        expect(result, isNotNull);
        final report = result! as AgentReportEntity;
        expect(report.id, entity.id);
        expect(report.scope, 'daily');
        expect(report.confidence, 0.95);
        expect(report.content['summary'], 'All good');
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
        config: const AgentConfig(maxTurnsPerWake: 10),
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
            containsAll(
                ['entity-agent-001', 'entity-state-001', 'entity-msg-001']));
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

        final results =
            await repo.getEntitiesByAgentId(testAgentId, type: 'agentState');

        expect(results.length, 1);
        expect(results.first.id, 'entity-state-001');
      });

      test('with type filter returns empty list when no match', () async {
        await repo.upsertEntity(makeAgent());

        final results =
            await repo.getEntitiesByAgentId(testAgentId, type: 'agentMessage');

        expect(results, isEmpty);
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

    group('getMessagesByKind', () {
      test('filters messages by kind correctly', () async {
        await repo.upsertEntity(makeMessage(
          id: 'msg-thought-1',
        ));
        await repo.upsertEntity(makeMessage(
          id: 'msg-user-1',
          kind: AgentMessageKind.user,
        ));
        await repo.upsertEntity(makeMessage(
          id: 'msg-thought-2',
        ));

        final thoughts =
            await repo.getMessagesByKind(testAgentId, AgentMessageKind.thought);
        final userMsgs =
            await repo.getMessagesByKind(testAgentId, AgentMessageKind.user);

        expect(thoughts.length, 2);
        expect(thoughts.map((m) => m.id),
            containsAll(['msg-thought-1', 'msg-thought-2']));
        expect(userMsgs.length, 1);
        expect(userMsgs.first.id, 'msg-user-1');
      });

      test('respects the limit parameter', () async {
        for (var i = 0; i < 5; i++) {
          await repo.upsertEntity(makeMessage(
            id: 'msg-obs-$i',
            kind: AgentMessageKind.observation,
          ));
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

        final results =
            await repo.getMessagesByKind(testAgentId, AgentMessageKind.action);
        expect(results, isEmpty);
      });
    });

    group('getMessagesForThread', () {
      test('filters messages by threadId', () async {
        await repo.upsertEntity(makeMessage(
          id: 'msg-t1-1',
          threadId: 'thread-A',
        ));
        await repo.upsertEntity(makeMessage(
          id: 'msg-t2-1',
          threadId: 'thread-B',
        ));
        await repo.upsertEntity(makeMessage(
          id: 'msg-t1-2',
          threadId: 'thread-A',
        ));

        final threadA =
            await repo.getMessagesForThread(testAgentId, 'thread-A');
        final threadB =
            await repo.getMessagesForThread(testAgentId, 'thread-B');

        expect(threadA.length, 2);
        expect(threadA.map((m) => m.id), containsAll(['msg-t1-1', 'msg-t1-2']));
        expect(threadB.length, 1);
        expect(threadB.first.id, 'msg-t2-1');
      });

      test('respects the limit parameter', () async {
        for (var i = 0; i < 4; i++) {
          await repo.upsertEntity(makeMessage(
            id: 'msg-thread-$i',
            threadId: 'thread-X',
          ));
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

        final results =
            await repo.getMessagesForThread(testAgentId, 'thread-Z');
        expect(results, isEmpty);
      });
    });

    group('getLatestReport', () {
      test('returns the report pointed to by the head', () async {
        final report = makeReport();
        final head = makeReportHead(reportId: report.id);
        await repo.upsertEntity(report);
        await repo.upsertEntity(head);

        final result = await repo.getLatestReport(testAgentId, 'daily');

        expect(result, isNotNull);
        expect(result!.id, report.id);
        expect(result.scope, 'daily');
        expect(result.content['summary'], 'All good');
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
        final dailyReport = makeReport(id: 'report-daily');
        final weeklyReport = makeReport(id: 'report-weekly', scope: 'weekly');
        final dailyHead = makeReportHead(
          id: 'head-daily',
          reportId: 'report-daily',
        );
        final weeklyHead = makeReportHead(
          id: 'head-weekly',
          scope: 'weekly',
          reportId: 'report-weekly',
        );

        await repo.upsertEntity(dailyReport);
        await repo.upsertEntity(weeklyReport);
        await repo.upsertEntity(dailyHead);
        await repo.upsertEntity(weeklyHead);

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
        final states =
            await repo.getLinksFrom(testAgentId, type: 'agent_state');

        expect(basics.length, 1);
        expect(basics.first.id, 'link-basic-1');
        expect(states.length, 1);
        expect(states.first.id, 'link-state-1');
      });
    });

    group('getLinksTo', () {
      test('returns links pointing to a given toId', () async {
        await repo.upsertLink(makeBasicLink(
          id: 'link-to-state',
        ));
        await repo.upsertLink(makeBasicLink(
          id: 'link-to-other',
          toId: 'entity-other-001',
        ));

        final results = await repo.getLinksTo('entity-state-001');

        expect(results.length, 1);
        expect(results.first.id, 'link-to-state');
      });

      test('with type filter returns only matching type', () async {
        await repo.upsertLink(makeBasicLink(
          id: 'link-basic-to',
        ));
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
        final prevs =
            await repo.getLinksTo('entity-state-001', type: 'message_prev');

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

    test('multiple link types for the same agent are stored independently',
        () async {
      await repo.upsertLink(makeBasicLink(
        id: 'link-basic',
        toId: 'target-1',
      ));
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
          ]));
    });

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

    test('updateSagaStatus transitions status so pending list shrinks',
        () async {
      await repo.insertSagaOp(entry: makeSagaOp(operationId: 'op-A'));
      await repo.insertSagaOp(entry: makeSagaOp(operationId: 'op-B'));

      expect((await repo.getPendingSagaOps()).length, 2);

      await repo.updateSagaStatus('op-A', 'done');

      final pending = await repo.getPendingSagaOps();
      expect(pending.length, 1);
      expect(pending.first.operationId, 'op-B');
    });

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

    test('getPendingSagaOps returns ops ordered by createdAt ascending',
        () async {
      await repo.insertSagaOp(
        entry: SagaLogData(
          operationId: 'op-late',
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
    });
  });
}
