import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/database/agent_repository_exception.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/agents/model/agent_link.dart'
    show AgentLinkSelection;
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';
import 'agent_repository_test_generators.dart';
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

  AttentionRequestEntity makeAttentionClaim({
    String id = 'attention-claim-001',
    String agentId = testAgentId,
    String title = 'Focus block',
    AttentionClaimScopeKind scopeKind = AttentionClaimScopeKind.dateRange,
    AttentionRequestStatus status = AttentionRequestStatus.pending,
    DateTime? rangeStart,
    DateTime? rangeEnd,
    DateTime? earliestStart,
    DateTime? latestEnd,
    DateTime? deadline,
    DateTime? nextReviewAt,
    String? targetId = 'task-1',
    String? targetKind = 'task',
    DateTime? createdAt,
    DateTime? deletedAt,
  }) {
    return AgentDomainEntity.attentionRequest(
          id: id,
          agentId: agentId,
          kind: AttentionRequestKind.task,
          title: title,
          categoryId: 'work',
          requestedMinutes: 45,
          impact: 4,
          urgency: 3,
          energyFit: AttentionEnergyFit.high,
          evidenceRefs: const [
            AttentionEvidenceRef(
              kind: AttentionEvidenceKind.task,
              id: 'task-1',
              label: 'Task 1',
            ),
          ],
          scopeKind: scopeKind,
          status: status,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          earliestStart: earliestStart,
          latestEnd: latestEnd,
          deadline: deadline,
          nextReviewAt: nextReviewAt,
          targetId: targetId,
          targetKind: targetKind,
          createdAt: createdAt ?? testDate,
          vectorClock: const VectorClock({'node-1': 10}),
          deletedAt: deletedAt,
        )
        as AttentionRequestEntity;
  }

  AttentionClaimDispositionEntity makeAttentionDisposition({
    required String id,
    required String requestId,
    AttentionClaimStatus status = AttentionClaimStatus.deferred,
    DateTime? createdAt,
    DateTime? nextReviewAt,
    String? awardId,
    String? planId,
    String? changeSetId,
    String? reason,
  }) {
    return AgentDomainEntity.attentionClaimDisposition(
          id: id,
          agentId: 'planner-agent-001',
          requestId: requestId,
          status: status,
          awardId: awardId,
          planId: planId,
          changeSetId: changeSetId,
          reason: reason,
          nextReviewAt: nextReviewAt,
          createdAt: createdAt ?? testDate,
          vectorClock: const VectorClock({'node-1': 11}),
        )
        as AttentionClaimDispositionEntity;
  }

  StandingAgreementEntity makeStandingAgreement({
    String id = 'standing-agreement-001',
    String agentId = 'fitness-agent-001',
    String title = 'Exercise three times per week',
    StandingAgreementScope scope = StandingAgreementScope.fitness,
    StandingAgreementCadence cadence = StandingAgreementCadence.weekly,
    StandingAgreementStatus status = StandingAgreementStatus.active,
    StandingAgreementEnforcement enforcement =
        StandingAgreementEnforcement.target,
    StandingAgreementApprovalMode approvalMode =
        StandingAgreementApprovalMode.ask,
    String? categoryId = 'health',
    String? targetId = 'habit-strength',
    String? targetKind = 'habit',
    int? minCount = 3,
    int? minMinutes = 135,
    int? maxMinutes,
    int? preferredSessionMinutes = 45,
    int priority = 10,
    bool canPreempt = false,
    DateTime? activeFrom,
    DateTime? activeUntil,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return AgentDomainEntity.standingAgreement(
          id: id,
          agentId: agentId,
          title: title,
          scope: scope,
          cadence: cadence,
          status: status,
          enforcement: enforcement,
          approvalMode: approvalMode,
          categoryId: categoryId,
          targetId: targetId,
          targetKind: targetKind,
          minCount: minCount,
          minMinutes: minMinutes,
          maxMinutes: maxMinutes,
          preferredSessionMinutes: preferredSessionMinutes,
          priority: priority,
          canPreempt: canPreempt,
          activeFrom: activeFrom,
          activeUntil: activeUntil,
          createdAt: createdAt ?? testDate,
          updatedAt: updatedAt ?? testDate,
          vectorClock: const VectorClock({'node-1': 12}),
          deletedAt: deletedAt,
        )
        as StandingAgreementEntity;
  }

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

    group('getEntitiesByIds', () {
      test(
        'returns empty map on empty input without touching the database',
        () async {
          final result = await repo.getEntitiesByIds(<String>[]);
          expect(result, isEmpty);
        },
      );

      test(
        'batches a request set of ids into a single IN-list query, '
        'returning matched entities keyed by id and silently dropping '
        'ids with no row',
        () async {
          await repo.upsertEntity(makeAgent(id: 'bulk-agent-1'));
          await repo.upsertEntity(makeAgent(id: 'bulk-agent-2'));
          await repo.upsertEntity(makeAgent(id: 'bulk-agent-3'));

          final result = await repo.getEntitiesByIds([
            'bulk-agent-1',
            'bulk-agent-3',
            'missing-id',
          ]);

          expect(
            result.keys,
            unorderedEquals(['bulk-agent-1', 'bulk-agent-3']),
          );
          expect(result['bulk-agent-1'], isA<AgentIdentityEntity>());
          expect(result['bulk-agent-3'], isA<AgentIdentityEntity>());
          expect(result.containsKey('missing-id'), isFalse);
        },
      );

      test(
        'excludes soft-deleted rows (deleted_at IS NOT NULL) — matches '
        'the per-id getEntity contract so callers see the same '
        'visibility behaviour after the batch rewrite',
        () async {
          final live = makeAgent(id: 'bulk-live');
          final softDeleted = makeAgent(id: 'bulk-soft').copyWith(
            deletedAt: DateTime(2026, 5, 12),
          );
          await repo.upsertEntity(live);
          await repo.upsertEntity(softDeleted);

          final result = await repo.getEntitiesByIds([
            'bulk-live',
            'bulk-soft',
          ]);
          expect(result.keys, ['bulk-live']);
        },
      );

      test(
        'deduplicates incoming ids before SQL so a caller passing the '
        'same id twice never expands the IN-list redundantly',
        () async {
          await repo.upsertEntity(makeAgent(id: 'bulk-dup'));

          final result = await repo.getEntitiesByIds([
            'bulk-dup',
            'bulk-dup',
            'bulk-dup',
          ]);

          expect(result.keys, ['bulk-dup']);
        },
      );

      test(
        'chunks the IN-list past 900 entries so a caller passing many '
        'ids never trips SQLite SQLITE_MAX_VARIABLE_NUMBER (default '
        '999) — guards `_collectObservationPayloads` on a project '
        'agent with thousands of pending observations',
        () async {
          // 1 800 = two full chunks at the 900-id cut-off.
          const total = 1800;
          const matchedSpan = 5;
          for (var i = 0; i < matchedSpan; i++) {
            await repo.upsertEntity(makeAgent(id: 'chunk-real-$i'));
          }
          final requestedIds = <String>[
            for (var i = 0; i < total; i++) 'chunk-synthetic-$i',
            for (var i = 0; i < matchedSpan; i++) 'chunk-real-$i',
          ];

          final result = await repo.getEntitiesByIds(requestedIds);

          // Only the rows that actually exist come back, regardless of
          // how big the input set was. The crucial check is that the
          // call completes without a `SqliteException` from the
          // host-variable cap.
          expect(
            result.keys.toSet(),
            {for (var i = 0; i < matchedSpan; i++) 'chunk-real-$i'},
          );
        },
      );

      // `_sqliteInClauseChunks` is the pure dedup-and-chunk iterator behind
      // every batched IN-list query; the example test above only exercises the
      // 1 800-id case. This property locks down the invariants across the whole
      // size space (including the empty, exactly-900 and 901 edges produced by
      // shrinking) without any database I/O.
      glados.Glados(
        glados.IntAnys(glados.any).intInRange(0, 2100), // requested-id count
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'chunking dedups its input and never exceeds the host-var cap',
        (
          count,
        ) {
          // Half the ids are duplicated to exercise the dedup step.
          final input = <String>[
            for (var i = 0; i < count; i++) 'id-$i',
            for (var i = 0; i < count ~/ 2; i++) 'id-$i',
          ];
          final deduped = input.toSet();

          final chunks = AgentRepository.debugSqliteInClauseChunks(
            input,
          ).toList();
          final flattened = chunks.expand((chunk) => chunk).toList();

          // No chunk exceeds the SQLite host-variable cut-off.
          for (final chunk in chunks) {
            expect(
              chunk.length,
              lessThanOrEqualTo(AgentRepository.debugInClauseChunkSize),
              reason: 'count=$count',
            );
          }
          // Every distinct input id appears exactly once across all chunks ...
          expect(flattened.toSet(), deduped, reason: 'count=$count');
          expect(flattened, hasLength(deduped.length), reason: 'count=$count');
          // ... and an empty input yields no chunks at all.
          if (deduped.isEmpty) {
            expect(chunks, isEmpty, reason: 'count=$count');
          } else {
            expect(chunks, isNotEmpty, reason: 'count=$count');
          }
        },
        tags: 'glados',
      );
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

      test(
        'chunks large agent-id lists without losing later matches',
        () async {
          const total = 1005;
          final requestedIds = [
            for (var i = 0; i < total; i++) 'state-agent-$i',
          ];

          for (final index in [0, 901, 1004]) {
            await repo.upsertEntity(
              makeAgentState(
                id: 'state-chunk-$index',
                agentId: requestedIds[index],
                revision: index,
              ),
            );
          }

          final result = await repo.getAgentStatesByAgentIds(requestedIds);

          expect(
            result.keys,
            unorderedEquals([
              requestedIds[0],
              requestedIds[901],
              requestedIds[1004],
            ]),
          );
          expect(result[requestedIds[901]]?.id, 'state-chunk-901');
          expect(result[requestedIds[1004]]?.revision, 1004);
        },
      );
    });

    group('getActiveAgentByKindAndActiveDayId', () {
      AgentIdentityEntity identityForLookup({
        required String agentId,
        String kind = AgentKinds.dayAgent,
        AgentLifecycle lifecycle = AgentLifecycle.active,
        DateTime? createdAt,
      }) {
        final timestamp = createdAt ?? testDate;
        return makeTestIdentity(
          id: 'identity-$agentId',
          agentId: agentId,
          kind: kind,
          displayName: agentId,
          lifecycle: lifecycle,
          currentStateId: 'state-$agentId',
          createdAt: timestamp,
          updatedAt: timestamp,
        );
      }

      AgentStateEntity stateForLookup({
        required String agentId,
        required String activeDayId,
        DateTime? updatedAt,
      }) {
        return makeTestState(
          id: 'state-$agentId-${updatedAt?.microsecondsSinceEpoch ?? 0}',
          agentId: agentId,
          slots: AgentSlots(activeDayId: activeDayId),
          updatedAt: updatedAt ?? testDate,
        );
      }

      test(
        'returns the newest active agent whose latest state matches',
        () async {
          const dayId = 'dayplan-2026-05-25';
          await repo.upsertEntity(
            identityForLookup(
              agentId: 'older-day-agent',
              createdAt: DateTime(2026, 5, 24),
            ),
          );
          await repo.upsertEntity(
            stateForLookup(agentId: 'older-day-agent', activeDayId: dayId),
          );
          await repo.upsertEntity(
            identityForLookup(
              agentId: 'newer-day-agent',
              createdAt: DateTime(2026, 5, 25),
            ),
          );
          await repo.upsertEntity(
            stateForLookup(agentId: 'newer-day-agent', activeDayId: dayId),
          );
          await repo.upsertEntity(
            identityForLookup(
              agentId: 'task-agent',
              kind: AgentKinds.taskAgent,
              createdAt: DateTime(2026, 5, 26),
            ),
          );
          await repo.upsertEntity(
            stateForLookup(agentId: 'task-agent', activeDayId: dayId),
          );
          await repo.upsertEntity(
            identityForLookup(
              agentId: 'dormant-day-agent',
              lifecycle: AgentLifecycle.dormant,
              createdAt: DateTime(2026, 5, 27),
            ),
          );
          await repo.upsertEntity(
            stateForLookup(agentId: 'dormant-day-agent', activeDayId: dayId),
          );

          final result = await repo.getActiveAgentByKindAndActiveDayId(
            kind: AgentKinds.dayAgent,
            activeDayId: dayId,
          );

          expect(result?.agentId, 'newer-day-agent');
        },
      );

      test(
        'breaks created_at ties by agent_id DESC',
        () async {
          const dayId = 'dayplan-2026-05-25';
          final sharedCreatedAt = DateTime(2026, 5, 25);
          for (final agentId in ['tie-agent-a', 'tie-agent-b']) {
            await repo.upsertEntity(
              identityForLookup(agentId: agentId, createdAt: sharedCreatedAt),
            );
            await repo.upsertEntity(
              stateForLookup(agentId: agentId, activeDayId: dayId),
            );
          }

          final result = await repo.getActiveAgentByKindAndActiveDayId(
            kind: AgentKinds.dayAgent,
            activeDayId: dayId,
          );

          // Equal created_at -> the lexicographically larger agent_id wins.
          expect(result?.agentId, 'tie-agent-b');
        },
      );

      test(
        'ignores an older matching state when the latest state moved days',
        () async {
          const dayId = 'dayplan-2026-05-25';
          await repo.upsertEntity(
            identityForLookup(agentId: 'moved-day-agent'),
          );
          await repo.upsertEntity(
            stateForLookup(
              agentId: 'moved-day-agent',
              activeDayId: dayId,
              updatedAt: DateTime(2026, 5, 24),
            ),
          );
          await repo.upsertEntity(
            stateForLookup(
              agentId: 'moved-day-agent',
              activeDayId: 'dayplan-2026-05-26',
              updatedAt: DateTime(2026, 5, 25),
            ),
          );

          final result = await repo.getActiveAgentByKindAndActiveDayId(
            kind: AgentKinds.dayAgent,
            activeDayId: dayId,
          );

          expect(result, isNull);
        },
      );
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

    group('getAgentMessages', () {
      test("returns all of the agent's messages across threads, excluding "
          'non-message entities and other agents', () async {
        await repo.upsertEntity(makeMessage(id: 'msg-a', threadId: 'thread-A'));
        await repo.upsertEntity(makeMessage(id: 'msg-b', threadId: 'thread-B'));
        // A non-message entity for the same agent — must be excluded.
        await repo.upsertEntity(makeReport());
        // A message for a different agent — must be excluded.
        await repo.upsertEntity(
          makeMessage(id: 'msg-other', agentId: 'other-agent'),
        );

        final messages = await repo.getAgentMessages(testAgentId);

        expect(messages.map((m) => m.id), unorderedEquals(['msg-a', 'msg-b']));
      });

      test('returns an empty list when the agent has no messages', () async {
        await repo.upsertEntity(makeReport()); // agent exists, but no messages
        expect(await repo.getAgentMessages(testAgentId), isEmpty);
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

      test(
        'chunks large agent-id lists without losing later report heads',
        () async {
          const total = 1005;
          final requestedIds = [
            for (var i = 0; i < total; i++) 'report-agent-$i',
          ];

          for (final index in [0, 901, 1004]) {
            await setupReportWithHead(
              repo,
              reportId: 'report-chunk-$index',
              headId: 'head-chunk-$index',
              agentId: requestedIds[index],
              createdAt: testDate.add(Duration(minutes: index)),
              content: 'chunk report $index',
            );
          }

          final result = await repo.getLatestReportsByAgentIds(
            requestedIds,
            AgentReportScopes.current,
          );

          expect(
            result.keys,
            unorderedEquals([
              requestedIds[0],
              requestedIds[901],
              requestedIds[1004],
            ]),
          );
          expect(result[requestedIds[901]]?.id, 'report-chunk-901');
          expect(result[requestedIds[1004]]?.content, 'chunk report 1004');
        },
      );
    });

    glados.Glados(
      glados.any.reportResolutionScenario,
      glados.ExploreConfig(numRuns: 80),
    ).test(
      'matches generated report head/latest-report resolution semantics',
      (scenario) async {
        final localDb = AgentDatabase(
          inMemoryDatabase: true,
          background: false,
        );
        final localRepo = AgentRepository(localDb);

        try {
          for (var index = 0; index < scenario.reports.length; index++) {
            final spec = scenario.reports[index];
            await localRepo.upsertEntity(
              makeTestReport(
                id: spec.idAt(index),
                agentId: spec.agentId,
                scope: spec.scope,
                createdAt: spec.createdAt(index),
                content: spec.contentAt(index),
                vectorClock: const VectorClock({'node-1': 1}),
              ).copyWith(deletedAt: spec.deletedAt(index)),
            );
          }

          for (var index = 0; index < scenario.heads.length; index++) {
            final spec = scenario.heads[index];
            await localRepo.upsertEntity(
              makeTestReportHead(
                id: spec.idAt(index),
                agentId: spec.agentId,
                scope: spec.scope,
                reportId: spec.reportIdFor(scenario),
                updatedAt: spec.updatedAt(index),
                vectorClock: const VectorClock({'node-1': 2}),
              ).copyWith(deletedAt: spec.deletedAt(index)),
            );
          }

          for (final agentSlot in GeneratedReportAgentSlot.values) {
            for (final scopeSlot in GeneratedReportScopeSlot.values) {
              final agentId = switch (agentSlot) {
                GeneratedReportAgentSlot.target => generatedReportTargetAgentId,
                GeneratedReportAgentSlot.other => generatedReportOtherAgentId,
              };
              final scope = switch (scopeSlot) {
                GeneratedReportScopeSlot.target => generatedReportTargetScope,
                GeneratedReportScopeSlot.other => generatedReportOtherScope,
              };

              final head = await localRepo.getReportHead(agentId, scope);
              expect(
                head?.id,
                scenario.expectedHeadIdFor(agentSlot, scopeSlot),
                reason: '$scenario',
              );
              expect(
                head?.reportId,
                scenario.expectedHeadReportIdFor(agentSlot, scopeSlot),
                reason: '$scenario',
              );

              final report = await localRepo.getLatestReport(agentId, scope);
              expect(
                report?.id,
                scenario.expectedLatestReportIdFor(agentSlot, scopeSlot),
                reason: '$scenario',
              );
              if (report != null) {
                expect(report.agentId, agentId, reason: '$scenario');
                expect(report.scope, scope, reason: '$scenario');
              }
            }
          }

          final batch = await localRepo.getLatestReportsByAgentIds(
            [
              generatedReportTargetAgentId,
              generatedReportOtherAgentId,
              generatedReportTargetAgentId,
            ],
            generatedReportTargetScope,
          );
          final batchReportIdsByAgentId = batch.map(
            (agentId, report) => MapEntry(agentId, report.id),
          );
          expect(
            batchReportIdsByAgentId,
            scenario.expectedBatchReportIdsForTargetScope,
            reason: '$scenario',
          );
        } finally {
          await localDb.close();
        }
      },
      tags: 'glados',
    );

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

    glados.Glados(
      glados.any.primaryLinkSelectionScenario,
      glados.ExploreConfig(numRuns: 80),
    ).test(
      'matches generated primary link selection for project and task reports',
      (scenario) async {
        final localDb = AgentDatabase(
          inMemoryDatabase: true,
          background: false,
        );
        final localRepo = AgentRepository(localDb);

        try {
          for (final spec in scenario.reports) {
            if (spec.writesReport) {
              await localRepo.upsertEntity(
                makeTestReport(
                  id: spec.reportId,
                  agentId: spec.agentId,
                  scope: spec.scope,
                  createdAt: spec.updatedAt,
                  content: spec.content,
                  vectorClock: const VectorClock({'node-1': 1}),
                ).copyWith(deletedAt: spec.reportDeletedAt),
              );
            }

            await localRepo.upsertEntity(
              makeTestReportHead(
                id: spec.headId,
                agentId: spec.agentId,
                scope: spec.scope,
                reportId: spec.headReportId,
                updatedAt: spec.updatedAt,
                vectorClock: const VectorClock({'node-1': 2}),
              ).copyWith(deletedAt: spec.headDeletedAt),
            );
          }

          for (final spec in scenario.projectLinks) {
            await localRepo.upsertLink(
              model.AgentLink.agentProject(
                id: spec.id,
                fromId: spec.agentId,
                toId: spec.projectId,
                createdAt: spec.createdAt,
                updatedAt: spec.createdAt,
                vectorClock: const VectorClock({'node-1': 3}),
                deletedAt: spec.deletedAt,
              ),
            );
          }

          for (final spec in scenario.taskLinks) {
            await localRepo.upsertLink(
              model.AgentLink.agentTask(
                id: spec.id,
                fromId: spec.agentId,
                toId: spec.taskId,
                createdAt: spec.createdAt,
                updatedAt: spec.createdAt,
                vectorClock: const VectorClock({'node-1': 4}),
                deletedAt: spec.deletedAt,
              ),
            );
          }

          final projectReport = await localRepo
              .getLatestProjectReportForProjectId(
                generatedPrimaryTargetProjectId,
              );
          expect(
            projectReport?.id,
            scenario.expectedProjectReportId,
            reason: '$scenario',
          );
          if (projectReport != null) {
            expect(
              projectReport.content.trim(),
              isNotEmpty,
              reason: '$scenario',
            );
          }

          final taskReports = await localRepo.getLatestTaskReportsForTaskIds([
            generatedPrimaryFirstTaskId,
            generatedPrimarySecondTaskId,
            generatedPrimaryFirstTaskId,
          ]);
          final taskReportIdsByTaskId = taskReports.map(
            (taskId, report) => MapEntry(taskId, report.id),
          );
          expect(
            taskReportIdsByTaskId,
            scenario.expectedTaskReportIds,
            reason: '$scenario',
          );
        } finally {
          await localDb.close();
        }
      },
      tags: 'glados',
    );
  });

  group('getAttentionClaimsForWindow', () {
    test('returns claims whose flexible visibility window overlaps', () async {
      final visibleClaim = makeAttentionClaim(
        id: 'attention-claim-visible',
        title: 'Prepare tax packet',
        rangeStart: DateTime(2026, 5, 26),
        rangeEnd: DateTime(2026, 5, 28),
        deadline: DateTime(2026, 5, 28, 17),
        nextReviewAt: DateTime(2026, 5, 25, 8),
      );
      final outsideClaim = makeAttentionClaim(
        id: 'attention-claim-outside',
        title: 'Later review',
        rangeStart: DateTime(2026, 5, 29),
        rangeEnd: DateTime(2026, 5, 30),
      );

      await repo.upsertEntity(outsideClaim);
      await repo.upsertEntity(visibleClaim);

      final claims = await repo.getAttentionClaimsForWindow(
        start: DateTime(2026, 5, 27),
        end: DateTime(2026, 5, 28),
      );

      expect(claims.map((claim) => claim.id), ['attention-claim-visible']);
      expect(claims.single.rangeStart, DateTime(2026, 5, 26));
      expect(claims.single.rangeEnd, DateTime(2026, 5, 28));
    });

    test('projects latest disposition status for planner discovery', () async {
      final claim = makeAttentionClaim(
        id: 'attention-claim-status',
        rangeStart: DateTime(2026, 5, 26),
        rangeEnd: DateTime(2026, 5, 28),
      );
      await repo.upsertEntity(claim);
      await repo.upsertEntity(
        makeAttentionDisposition(
          id: 'attention-disposition-declined',
          requestId: claim.id,
          status: AttentionClaimStatus.declined,
          createdAt: testDate.add(const Duration(minutes: 1)),
          reason: 'Not worth scheduling.',
        ),
      );

      final defaultClaims = await repo.getAttentionClaimsForWindow(
        start: DateTime(2026, 5, 27),
        end: DateTime(2026, 5, 28),
      );
      expect(defaultClaims, isEmpty);

      final declinedClaims = await repo.getAttentionClaimsForWindow(
        start: DateTime(2026, 5, 27),
        end: DateTime(2026, 5, 28),
        statuses: const {AttentionClaimStatus.declined},
      );
      expect(declinedClaims.map((item) => item.id), [claim.id]);

      await repo.upsertEntity(
        makeAttentionDisposition(
          id: 'attention-disposition-deferred',
          requestId: claim.id,
          createdAt: testDate.add(const Duration(minutes: 2)),
          nextReviewAt: DateTime(2026, 5, 27, 8),
          reason: 'Reconsider in tomorrow planning.',
        ),
      );

      final deferredClaims = await repo.getAttentionClaimsForWindow(
        start: DateTime(2026, 5, 27),
        end: DateTime(2026, 5, 28),
      );
      expect(deferredClaims.map((item) => item.id), [claim.id]);
    });

    test(
      'surfaces awarded claims until a disposition satisfies them',
      () async {
        final claim = makeAttentionClaim(
          id: 'attention-claim-awarded',
          status: AttentionRequestStatus.awarded,
          rangeStart: DateTime(2026, 5, 26),
          rangeEnd: DateTime(2026, 5, 28),
        );
        await repo.upsertEntity(claim);

        final proposedClaims = await repo.getAttentionClaimsForWindow(
          start: DateTime(2026, 5, 27),
          end: DateTime(2026, 5, 28),
        );
        expect(proposedClaims.map((item) => item.id), [claim.id]);

        final satisfiedClaims = await repo.getAttentionClaimsForWindow(
          start: DateTime(2026, 5, 27),
          end: DateTime(2026, 5, 28),
          statuses: const {AttentionClaimStatus.satisfied},
        );
        expect(satisfiedClaims, isEmpty);

        await repo.upsertEntity(
          makeAttentionDisposition(
            id: 'attention-disposition-satisfied',
            requestId: claim.id,
            status: AttentionClaimStatus.satisfied,
            createdAt: testDate.add(const Duration(minutes: 1)),
            reason: 'Accepted through the human gate.',
          ),
        );

        final defaultClaims = await repo.getAttentionClaimsForWindow(
          start: DateTime(2026, 5, 27),
          end: DateTime(2026, 5, 28),
        );
        expect(defaultClaims, isEmpty);

        final acceptedClaims = await repo.getAttentionClaimsForWindow(
          start: DateTime(2026, 5, 27),
          end: DateTime(2026, 5, 28),
          statuses: const {AttentionClaimStatus.satisfied},
        );
        expect(acceptedClaims.map((item) => item.id), [claim.id]);
      },
    );

    test('projects request-side rejected claims as declined', () async {
      final claim = makeAttentionClaim(
        id: 'attention-claim-rejected',
        status: AttentionRequestStatus.rejected,
        rangeStart: DateTime(2026, 5, 26),
        rangeEnd: DateTime(2026, 5, 28),
      );
      await repo.upsertEntity(claim);

      final defaultClaims = await repo.getAttentionClaimsForWindow(
        start: DateTime(2026, 5, 27),
        end: DateTime(2026, 5, 28),
      );
      expect(defaultClaims, isEmpty);

      final declinedClaims = await repo.getAttentionClaimsForWindow(
        start: DateTime(2026, 5, 27),
        end: DateTime(2026, 5, 28),
        statuses: const {AttentionClaimStatus.declined},
      );
      expect(declinedClaims.map((item) => item.id), [claim.id]);
    });

    test(
      'uses fallback visibility windows for latestEnd, deadline, and invalid '
      'ranges',
      () async {
        final latestEndClaim = makeAttentionClaim(
          id: 'attention-claim-latest-end',
          earliestStart: DateTime(2026, 5, 27, 9),
          latestEnd: DateTime(2026, 5, 27, 11),
        );
        final deadlineClaim = makeAttentionClaim(
          id: 'attention-claim-deadline',
          createdAt: DateTime(2026, 5, 28, 8),
          rangeStart: DateTime(2026, 5, 28, 9),
          deadline: DateTime(2026, 5, 28, 12),
        );
        final normalizedClaim = makeAttentionClaim(
          id: 'attention-claim-normalized',
          rangeStart: DateTime(2026, 5, 29, 13),
          rangeEnd: DateTime(2026, 5, 29, 12),
        );

        await repo.upsertEntity(latestEndClaim);
        await repo.upsertEntity(deadlineClaim);
        await repo.upsertEntity(normalizedClaim);

        final latestEndClaims = await repo.getAttentionClaimsForWindow(
          start: DateTime(2026, 5, 27, 10),
          end: DateTime(2026, 5, 27, 10, 30),
        );
        expect(latestEndClaims.map((item) => item.id), [
          latestEndClaim.id,
        ]);

        final deadlineClaims = await repo.getAttentionClaimsForWindow(
          start: DateTime(2026, 5, 28, 11),
          end: DateTime(2026, 5, 28, 11, 30),
        );
        expect(deadlineClaims.map((item) => item.id), [deadlineClaim.id]);

        final normalizedClaims = await repo.getAttentionClaimsForWindow(
          start: DateTime(2026, 5, 29, 13),
          end: DateTime(2026, 5, 29, 13, 1),
        );
        expect(normalizedClaims.map((item) => item.id), [
          normalizedClaim.id,
        ]);
      },
    );

    test(
      'removes claim projection when the source request is soft-deleted',
      () async {
        final claim = makeAttentionClaim(
          id: 'attention-claim-soft-delete',
          rangeStart: DateTime(2026, 5, 26),
          rangeEnd: DateTime(2026, 5, 28),
        );
        await repo.upsertEntity(claim);

        final beforeDelete = await repo.getAttentionClaimsForWindow(
          start: DateTime(2026, 5, 27),
          end: DateTime(2026, 5, 28),
        );
        expect(beforeDelete.map((item) => item.id), [claim.id]);

        await repo.upsertEntity(
          makeAttentionClaim(
            id: claim.id,
            rangeStart: DateTime(2026, 5, 26),
            rangeEnd: DateTime(2026, 5, 28),
            deletedAt: testDate.add(const Duration(minutes: 1)),
          ),
        );

        final afterDelete = await repo.getAttentionClaimsForWindow(
          start: DateTime(2026, 5, 27),
          end: DateTime(2026, 5, 28),
        );
        expect(afterDelete, isEmpty);
      },
    );

    test(
      'returns active claims for a concrete target without scanning sources',
      () async {
        final matchingClaim = makeAttentionClaim(
          id: 'attention-claim-target',
          targetId: 'task-target',
          nextReviewAt: DateTime(2026, 5, 27, 8),
        );
        final otherTaskClaim = makeAttentionClaim(
          id: 'attention-claim-other-task',
          targetId: 'task-other',
        );
        final untargetedClaim = makeAttentionClaim(
          id: 'attention-claim-untargeted',
          targetId: null,
          targetKind: null,
        );
        final declinedClaim = makeAttentionClaim(
          id: 'attention-claim-target-declined',
          targetId: 'task-target',
          createdAt: testDate.add(const Duration(minutes: 1)),
        );

        await repo.upsertEntity(otherTaskClaim);
        await repo.upsertEntity(untargetedClaim);
        await repo.upsertEntity(matchingClaim);
        await repo.upsertEntity(declinedClaim);
        await repo.upsertEntity(
          makeAttentionDisposition(
            id: 'attention-disposition-target-declined',
            requestId: declinedClaim.id,
            status: AttentionClaimStatus.declined,
            createdAt: testDate.add(const Duration(minutes: 2)),
          ),
        );

        final activeClaims = await repo.getAttentionClaimsForTarget(
          targetKind: 'task',
          targetId: 'task-target',
        );
        expect(activeClaims.map((item) => item.id), [matchingClaim.id]);

        final declinedClaims = await repo.getAttentionClaimsForTarget(
          targetKind: 'task',
          targetId: 'task-target',
          statuses: const {AttentionClaimStatus.declined},
        );
        expect(declinedClaims.map((item) => item.id), [declinedClaim.id]);

        final plan = await db
            .customSelect(
              '''
              EXPLAIN QUERY PLAN
              SELECT request_id
              FROM attention_claim_index
              WHERE target_kind = ?
                AND target_id = ?
                AND status IN (?)
                AND deleted_at IS NULL
              ORDER BY next_review_at IS NULL,
                next_review_at ASC,
                deadline IS NULL,
                deadline ASC,
                updated_at DESC,
                request_id ASC
              LIMIT ?
            ''',
              variables: [
                Variable.withString('task'),
                Variable.withString('task-target'),
                Variable.withString(AttentionClaimStatus.open.name),
                Variable.withInt(50),
              ],
              readsFrom: {db.attentionClaimIndex},
            )
            .get();
        final detail = plan.map((row) => row.read<String>('detail')).join('\n');
        expect(detail, contains('idx_attention_claims_active_target'));
      },
    );

    test(
      'rebuilds the local projection from source entities for repair',
      () async {
        final claim = makeAttentionClaim(
          id: 'attention-claim-rebuild',
          rangeStart: DateTime(2026, 5, 26),
          rangeEnd: DateTime(2026, 5, 28),
        );
        await repo.upsertEntity(claim);
        await repo.upsertEntity(
          makeAttentionDisposition(
            id: 'attention-disposition-rebuild',
            requestId: claim.id,
            nextReviewAt: DateTime(2026, 5, 27, 8),
            createdAt: testDate.add(const Duration(minutes: 1)),
          ),
        );
        await db.customStatement('DELETE FROM attention_claim_index');

        final missingClaims = await repo.getAttentionClaimsForWindow(
          start: DateTime(2026, 5, 27),
          end: DateTime(2026, 5, 28),
        );
        expect(missingClaims, isEmpty);

        await repo.rebuildAttentionClaimProjection();

        final rebuiltClaims = await repo.getAttentionClaimsForWindow(
          start: DateTime(2026, 5, 27),
          end: DateTime(2026, 5, 28),
        );
        expect(rebuiltClaims.map((item) => item.id), [claim.id]);
      },
    );
  });

  group('getAttentionPlanningInputsForWindow', () {
    test(
      'returns visible claims and standing agreements for planner context',
      () async {
        final claim = makeAttentionClaim(
          id: 'attention-claim-planner-context',
          targetId: 'task-planner',
          rangeStart: DateTime(2026, 5, 27),
          rangeEnd: DateTime(2026, 5, 28),
        );
        final agreement = makeStandingAgreement(
          id: 'standing-agreement-planner-context',
          activeFrom: DateTime(2026, 5),
          activeUntil: DateTime(2026, 6),
        );

        await repo.upsertEntity(claim);
        await repo.upsertEntity(agreement);

        final inputs = await repo.getAttentionPlanningInputsForWindow(
          start: DateTime(2026, 5, 27),
          end: DateTime(2026, 5, 28),
        );

        expect(inputs.isEmpty, isFalse);
        expect(inputs.claims.map((item) => item.id), [claim.id]);
        expect(inputs.standingAgreements.map((item) => item.id), [
          agreement.id,
        ]);
      },
    );
  });

  group('getStandingAgreementsForWindow', () {
    test(
      'returns active agreements whose windows overlap the planner window',
      () async {
        final lowerPriority = makeStandingAgreement(
          id: 'standing-agreement-lower',
          title: 'Keep admin bounded',
          scope: StandingAgreementScope.paperwork,
          minMinutes: null,
          maxMinutes: 180,
          activeFrom: DateTime(2026, 5),
          activeUntil: DateTime(2026, 6),
        );
        final higherPriority = makeStandingAgreement(
          id: 'standing-agreement-higher',
          title: 'Exercise three times',
          priority: 90,
          canPreempt: true,
          activeFrom: DateTime(2026, 5, 15),
          activeUntil: DateTime(2026, 5, 29),
          updatedAt: testDate.add(const Duration(minutes: 1)),
        );
        final future = makeStandingAgreement(
          id: 'standing-agreement-future',
          activeFrom: DateTime(2026, 6),
          activeUntil: DateTime(2026, 7),
          priority: 100,
        );

        await repo.upsertEntity(lowerPriority);
        await repo.upsertEntity(higherPriority);
        await repo.upsertEntity(future);

        final agreements = await repo.getStandingAgreementsForWindow(
          start: DateTime(2026, 5, 27),
          end: DateTime(2026, 5, 28),
        );

        expect(
          agreements.map((agreement) => agreement.id),
          ['standing-agreement-higher', 'standing-agreement-lower'],
        );
        expect(agreements.first.canPreempt, isTrue);
        expect(agreements.first.minCount, 3);
        expect(agreements.last.maxMinutes, 180);
      },
    );

    test('filters by status, scope, active window, and deletion', () async {
      final activeFitness = makeStandingAgreement(
        id: 'standing-agreement-active-fitness',
        activeFrom: DateTime(2026, 5),
      );
      final pausedSleep = makeStandingAgreement(
        id: 'standing-agreement-paused-sleep',
        title: 'Protect sleep',
        scope: StandingAgreementScope.sleep,
        cadence: StandingAgreementCadence.daily,
        status: StandingAgreementStatus.paused,
        activeFrom: DateTime(2026, 5),
      );
      final expiredFitness = makeStandingAgreement(
        id: 'standing-agreement-expired-fitness',
        activeFrom: DateTime(2026, 4),
        activeUntil: DateTime(2026, 5),
      );
      final deletedFitness = makeStandingAgreement(
        id: 'standing-agreement-deleted-fitness',
        activeFrom: DateTime(2026, 5),
        deletedAt: testDate.add(const Duration(minutes: 1)),
      );

      await repo.upsertEntity(activeFitness);
      await repo.upsertEntity(pausedSleep);
      await repo.upsertEntity(expiredFitness);
      await repo.upsertEntity(deletedFitness);

      final activeFitnessAgreements = await repo.getStandingAgreementsForWindow(
        start: DateTime(2026, 5, 27),
        end: DateTime(2026, 5, 28),
        scopes: const {StandingAgreementScope.fitness},
      );
      expect(
        activeFitnessAgreements.map((agreement) => agreement.id),
        ['standing-agreement-active-fitness'],
      );

      final pausedSleepAgreements = await repo.getStandingAgreementsForWindow(
        start: DateTime(2026, 5, 27),
        end: DateTime(2026, 5, 28),
        statuses: const {StandingAgreementStatus.paused},
        scopes: const {StandingAgreementScope.sleep},
      );
      expect(
        pausedSleepAgreements.map((agreement) => agreement.id),
        ['standing-agreement-paused-sleep'],
      );

      final noScopes = await repo.getStandingAgreementsForWindow(
        start: DateTime(2026, 5, 27),
        end: DateTime(2026, 5, 28),
        scopes: const {},
      );
      expect(noScopes, isEmpty);
    });

    test(
      'updates the projection when an agreement lifecycle changes',
      () async {
        final active = makeStandingAgreement(
          id: 'standing-agreement-lifecycle',
          activeFrom: DateTime(2026, 5),
        );
        await repo.upsertEntity(active);

        final beforePause = await repo.getStandingAgreementsForWindow(
          start: DateTime(2026, 5, 27),
          end: DateTime(2026, 5, 28),
        );
        expect(beforePause.map((agreement) => agreement.id), [active.id]);

        await repo.upsertEntity(
          makeStandingAgreement(
            id: active.id,
            status: StandingAgreementStatus.paused,
            activeFrom: DateTime(2026, 5),
            updatedAt: testDate.add(const Duration(minutes: 1)),
          ),
        );

        final defaultAgreements = await repo.getStandingAgreementsForWindow(
          start: DateTime(2026, 5, 27),
          end: DateTime(2026, 5, 28),
        );
        expect(defaultAgreements, isEmpty);

        final pausedAgreements = await repo.getStandingAgreementsForWindow(
          start: DateTime(2026, 5, 27),
          end: DateTime(2026, 5, 28),
          statuses: const {StandingAgreementStatus.paused},
        );
        expect(pausedAgreements.map((agreement) => agreement.id), [active.id]);
      },
    );

    test(
      'normalizes invalid active windows to a one-minute projection',
      () async {
        final agreement = makeStandingAgreement(
          id: 'standing-agreement-normalized',
          activeFrom: DateTime(2026, 5, 27, 9),
          activeUntil: DateTime(2026, 5, 27, 9),
        );
        await repo.upsertEntity(agreement);

        final agreements = await repo.getStandingAgreementsForWindow(
          start: DateTime(2026, 5, 27, 9),
          end: DateTime(2026, 5, 27, 9, 1),
        );
        expect(agreements.map((item) => item.id), [agreement.id]);
      },
    );

    test(
      'reads from the projection and rebuilds it only on explicit repair',
      () async {
        final agreement = makeStandingAgreement(
          id: 'standing-agreement-rebuild',
          activeFrom: DateTime(2026, 5),
          activeUntil: DateTime(2026, 6),
        );
        await repo.upsertEntity(agreement);
        await db.customStatement('DELETE FROM standing_agreement_index');

        final missingAgreements = await repo.getStandingAgreementsForWindow(
          start: DateTime(2026, 5, 27),
          end: DateTime(2026, 5, 28),
        );
        expect(missingAgreements, isEmpty);

        await repo.rebuildStandingAgreementProjection();

        final rebuiltAgreements = await repo.getStandingAgreementsForWindow(
          start: DateTime(2026, 5, 27),
          end: DateTime(2026, 5, 28),
        );
        expect(rebuiltAgreements.map((agreement) => agreement.id), [
          'standing-agreement-rebuild',
        ]);
      },
    );

    test(
      'skips malformed standing-agreement source rows during repair',
      () async {
        const malformedId = 'standing-agreement-malformed';
        const malformedCreatedAtIso = '2026-02-20T00:00:00.000';
        const serializedUnknown =
            '''
{"runtimeType":"futureVariantNotYetKnown","id":"$malformedId","agentId":"$testAgentId","createdAt":"$malformedCreatedAtIso","vectorClock":null,"deletedAt":null}
''';

        await db.customInsert(
          '''
          INSERT INTO agent_entities (
            id,
            agent_id,
            type,
            subtype,
            thread_id,
            created_at,
            updated_at,
            deleted_at,
            serialized,
            schema_version
          )
          VALUES (?, ?, ?, NULL, NULL, ?, ?, NULL, ?, 1)
        ''',
          variables: [
            Variable.withString(malformedId),
            Variable.withString(testAgentId),
            Variable.withString(AgentEntityTypes.standingAgreement),
            Variable.withDateTime(testDate),
            Variable.withDateTime(testDate),
            Variable.withString(serializedUnknown.trim()),
          ],
          updates: {db.agentEntities},
        );

        await repo.rebuildStandingAgreementProjection();

        final projectedRows = await db
            .customSelect(
              '''
              SELECT agreement_id
              FROM standing_agreement_index
              WHERE agreement_id = ?
            ''',
              variables: [Variable.withString(malformedId)],
              readsFrom: {db.standingAgreementIndex},
            )
            .get();
        expect(projectedRows, isEmpty);
      },
    );
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

        final single = await repo.getLinksTo(
          'task-a',
          type: AgentLinkTypes.agentTask,
        );
        expect(
          result['task-a']!.selectPrimary().id,
          single.selectPrimary().id,
        );
      });

      test('chunks large to-id lists without losing later matches', () async {
        const total = 1005;
        final requestedIds = [
          for (var i = 0; i < total; i++) 'chunk-task-$i',
        ];

        for (final index in [0, 901, 1004]) {
          await repo.upsertLink(
            model.AgentLink.agentTask(
              id: 'chunk-to-link-$index',
              fromId: 'agent-$index',
              toId: requestedIds[index],
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
            ),
          );
        }

        final result = await repo.getLinksToMultiple(
          requestedIds,
          type: AgentLinkTypes.agentTask,
        );

        expect(
          result.keys,
          unorderedEquals([
            requestedIds[0],
            requestedIds[901],
            requestedIds[1004],
          ]),
        );
        expect(result[requestedIds[901]]?.single.id, 'chunk-to-link-901');
        expect(result[requestedIds[1004]]?.single.fromId, 'agent-1004');
      });
    });

    group('getLinksFromMultiple', () {
      test('returns empty map when no ids are requested', () async {
        final result = await repo.getLinksFromMultiple(
          const [],
          type: AgentLinkTypes.agentTask,
        );

        expect(result, isEmpty);
      });

      test(
        'groups matching links by fromId and excludes deleted rows',
        () async {
          await repo.upsertLink(
            model.AgentLink.agentTask(
              id: 'agent-task-link-1',
              fromId: 'agent-a',
              toId: 'task-a',
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
            ),
          );
          await repo.upsertLink(
            model.AgentLink.agentTask(
              id: 'agent-task-link-2',
              fromId: 'agent-a',
              toId: 'task-b',
              createdAt: testDate.add(const Duration(minutes: 1)),
              updatedAt: testDate.add(const Duration(minutes: 1)),
              vectorClock: null,
            ),
          );
          await repo.upsertLink(
            model.AgentLink.agentTask(
              id: 'agent-task-link-3',
              fromId: 'agent-b',
              toId: 'task-c',
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
            ),
          );
          await repo.upsertLink(
            model.AgentLink.messagePrev(
              id: 'wrong-from-type',
              fromId: 'agent-a',
              toId: 'message-a',
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
            ),
          );
          await repo.upsertLink(
            model.AgentLink.agentTask(
              id: 'deleted-from-link',
              fromId: 'agent-b',
              toId: 'task-deleted',
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
              deletedAt: testDate.add(const Duration(hours: 1)),
            ),
          );

          final result = await repo.getLinksFromMultiple(
            ['agent-a', 'agent-b', 'agent-c'],
            type: AgentLinkTypes.agentTask,
          );

          expect(result.keys, unorderedEquals(['agent-a', 'agent-b']));
          expect(
            result['agent-a']?.map((link) => link.id),
            unorderedEquals(['agent-task-link-1', 'agent-task-link-2']),
          );
          expect(
            result['agent-b']?.map((link) => link.id),
            unorderedEquals(['agent-task-link-3']),
          );
          expect(result['agent-c'], isNull);

          final single = await repo.getLinksFrom(
            'agent-a',
            type: AgentLinkTypes.agentTask,
          );
          expect(
            result['agent-a']!.selectPrimary().id,
            single.selectPrimary().id,
          );
        },
      );

      test('chunks large from-id lists without losing later matches', () async {
        const total = 1005;
        final requestedIds = [
          for (var i = 0; i < total; i++) 'chunk-agent-$i',
        ];

        for (final index in [0, 901, 1004]) {
          await repo.upsertLink(
            model.AgentLink.agentTask(
              id: 'chunk-from-link-$index',
              fromId: requestedIds[index],
              toId: 'task-$index',
              createdAt: testDate,
              updatedAt: testDate,
              vectorClock: null,
            ),
          );
        }

        final result = await repo.getLinksFromMultiple(
          requestedIds,
          type: AgentLinkTypes.agentTask,
        );

        expect(
          result.keys,
          unorderedEquals([
            requestedIds[0],
            requestedIds[901],
            requestedIds[1004],
          ]),
        );
        expect(result[requestedIds[901]]?.single.id, 'chunk-from-link-901');
        expect(result[requestedIds[1004]]?.single.toId, 'task-1004');
      });
    });

    glados.Glados(
      glados.any.batchTaskLinkQueryScenario,
      glados.ExploreConfig(numRuns: 80),
    ).test(
      'matches generated batch task-link query semantics',
      (scenario) async {
        final localDb = AgentDatabase(
          inMemoryDatabase: true,
          background: false,
        );
        final localRepo = AgentRepository(localDb);

        try {
          for (final spec in scenario.links) {
            final link = switch (spec.kind) {
              GeneratedBatchLinkKind.agentTask => model.AgentLink.agentTask(
                id: spec.id,
                fromId: spec.agentId,
                toId: spec.taskId,
                createdAt: spec.createdAt,
                updatedAt: spec.createdAt,
                vectorClock: const VectorClock({'node-1': 1}),
                deletedAt: spec.deletedAt,
              ),
              GeneratedBatchLinkKind.basic => model.AgentLink.basic(
                id: spec.id,
                fromId: spec.agentId,
                toId: spec.taskId,
                createdAt: spec.createdAt,
                updatedAt: spec.createdAt,
                vectorClock: const VectorClock({'node-1': 2}),
                deletedAt: spec.deletedAt,
              ),
            };
            await localRepo.upsertLink(link);
          }

          final groupedLinks = await localRepo.getLinksToMultiple(
            scenario.requestedTaskIds,
            type: AgentLinkTypes.agentTask,
          );
          final groupedLinkIds = groupedLinks.map(
            (taskId, links) => MapEntry(
              taskId,
              links.map((link) => link.id).toSet(),
            ),
          );
          expect(
            groupedLinkIds,
            scenario.expectedLinksToMultipleIds,
            reason: '$scenario',
          );

          final taskIds = await localRepo.getTaskIdsWithAgentLink();
          expect(
            taskIds,
            scenario.expectedTaskIdsWithAgentLink,
            reason: '$scenario',
          );
        } finally {
          await localDb.close();
        }
      },
      tags: 'glados',
    );

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
      test(
        'silently writes zero rows for a missing runKey (fire-and-forget)',
        () async {
          // Documented contract: late status transitions racing run-log
          // cleanup must not crash the caller and must not create rows.
          await expectLater(
            repo.updateWakeRunStatus('no-such-run-key', 'completed'),
            completes,
          );
          expect(await repo.getWakeRun('no-such-run-key'), isNull);
        },
      );

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

    glados.Glados(
      glados.any.wakeLifecycleScenario,
      glados.ExploreConfig(numRuns: 80),
    ).test(
      'matches generated wake-run lifecycle query semantics',
      (scenario) async {
        final localDb = AgentDatabase(
          inMemoryDatabase: true,
          background: false,
        );
        final localRepo = AgentRepository(localDb);

        try {
          for (var index = 0; index < scenario.specs.length; index++) {
            final spec = scenario.specs[index];
            await localRepo.insertWakeRun(
              entry: WakeRunLogData(
                runKey: spec.runKeyAt(index),
                agentId: spec.agentId,
                reason: spec.reason,
                threadId: spec.threadId,
                status: WakeRunStatus.running.name,
                createdAt: spec.createdAt(index),
                startedAt: spec.startedAt(index),
              ),
            );

            final templateId = spec.templateId;
            final templateVersionId = spec.templateVersionId;
            if (templateId != null && templateVersionId != null) {
              await localRepo.updateWakeRunTemplate(
                spec.runKeyAt(index),
                templateId,
                templateVersionId,
                resolvedModelId: spec.resolvedModelId,
                soulId: spec.soulId,
                soulVersionId: spec.soulVersionId,
              );
            }

            await localRepo.updateWakeRunStatus(
              spec.runKeyAt(index),
              spec.status.name,
              completedAt: spec.completedAt(index),
              errorMessage: spec.errorMessage,
            );

            if (spec.hasRating) {
              await localRepo.updateWakeRunRating(
                spec.runKeyAt(index),
                rating: spec.rating,
                ratedAt: spec.ratedAt(index),
              );
            }

            final restored = await localRepo.getWakeRun(spec.runKeyAt(index));
            expect(restored, isNotNull, reason: '$scenario');
            expect(restored!.agentId, spec.agentId, reason: '$scenario');
            expect(restored.reason, spec.reason, reason: '$scenario');
            expect(restored.threadId, spec.threadId, reason: '$scenario');
            expect(restored.status, spec.status.name, reason: '$scenario');
            expect(
              restored.createdAt,
              spec.createdAt(index),
              reason: '$scenario',
            );
            expect(
              restored.startedAt,
              spec.startedAt(index),
              reason: '$scenario',
            );
            expect(
              restored.completedAt,
              spec.completedAt(index),
              reason: '$scenario',
            );
            expect(
              restored.errorMessage,
              spec.errorMessage,
              reason: '$scenario',
            );
            expect(restored.templateId, spec.templateId, reason: '$scenario');
            expect(
              restored.templateVersionId,
              spec.templateVersionId,
              reason: '$scenario',
            );
            expect(
              restored.resolvedModelId,
              spec.templateId == null ? null : spec.resolvedModelId,
              reason: '$scenario',
            );
            expect(
              restored.soulId,
              spec.templateId == null ? null : spec.soulId,
              reason: '$scenario',
            );
            expect(
              restored.soulVersionId,
              spec.templateId == null ? null : spec.soulVersionId,
              reason: '$scenario',
            );
            expect(
              restored.userRating,
              spec.hasRating ? spec.rating : null,
              reason: '$scenario',
            );
            expect(
              restored.ratedAt,
              spec.hasRating ? spec.ratedAt(index) : null,
              reason: '$scenario',
            );
          }

          final latestThreadRun = await localRepo.getWakeRunByThreadId(
            generatedWakeTargetAgentId,
            generatedWakeTargetThreadId,
          );
          expect(
            latestThreadRun?.runKey,
            scenario.latestRunKeyForThread(
              generatedWakeTargetAgentId,
              generatedWakeTargetThreadId,
            ),
            reason: '$scenario',
          );

          final templateRuns = await localRepo.getWakeRunsForTemplate(
            generatedWakeTargetTemplateId,
            limit: scenario.templateLimit,
          );
          expect(
            templateRuns.map((run) => run.runKey).toList(),
            scenario.expectedTemplateRunKeys(limit: scenario.templateLimit),
            reason: '$scenario',
          );

          final templateCount = await localRepo.countWakeRunsForTemplate(
            generatedWakeTargetTemplateId,
          );
          expect(
            templateCount,
            scenario.targetTemplateCount,
            reason: '$scenario',
          );

          final targetWindowRuns = await localRepo
              .getWakeRunsForTemplateInWindow(
                generatedWakeTargetTemplateId,
                since: generatedWakeWindowStart,
                until: generatedWakeWindowEnd,
              );
          expect(
            targetWindowRuns.map((run) => run.runKey).toList(),
            scenario.expectedTargetTemplateWindowRunKeys(
              generatedWakeWindowStart,
              generatedWakeWindowEnd,
            ),
            reason: '$scenario',
          );

          final globalWindowRuns = await localRepo.getWakeRunsInWindow(
            since: generatedWakeWindowStart,
            until: generatedWakeWindowEnd,
          );
          expect(
            globalWindowRuns.map((run) => run.runKey).toList(),
            scenario.expectedGlobalWindowRunKeys(
              generatedWakeWindowStart,
              generatedWakeWindowEnd,
            ),
            reason: '$scenario',
          );

          final metrics = await localRepo.aggregateWakeRunMetrics(
            generatedWakeTargetTemplateId,
          );
          expect(
            metrics.successCount,
            scenario.targetTemplateSuccessCount,
            reason: '$scenario',
          );
          expect(
            metrics.failureCount,
            scenario.targetTemplateFailureCount,
            reason: '$scenario',
          );
          expect(
            metrics.durationCount,
            scenario.targetTemplateDurationCount,
            reason: '$scenario',
          );
          expect(
            metrics.durationSumMs,
            scenario.targetTemplateDurationSumMs,
            reason: '$scenario',
          );
          expect(
            metrics.firstWakeAt,
            scenario.firstWakeAt,
            reason: '$scenario',
          );
          expect(metrics.lastWakeAt, scenario.lastWakeAt, reason: '$scenario');

          final abandoned = await localRepo.abandonOrphanedWakeRuns();
          expect(abandoned, scenario.runningCount, reason: '$scenario');

          for (var index = 0; index < scenario.specs.length; index++) {
            final spec = scenario.specs[index];
            final restored = await localRepo.getWakeRun(spec.runKeyAt(index));
            expect(restored, isNotNull, reason: '$scenario');
            if (spec.status == WakeRunStatus.running) {
              expect(
                restored!.status,
                WakeRunStatus.abandoned.name,
                reason: '$scenario',
              );
              expect(
                restored.errorMessage,
                contains('orphaned run'),
                reason: '$scenario',
              );
            } else {
              expect(restored!.status, spec.status.name, reason: '$scenario');
            }
          }
        } finally {
          await localDb.close();
        }
      },
      tags: 'glados',
    );
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
              .having((e) => e.key, 'key', 'op-001'),
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

    glados.Glados(
      glados.any.templateResolutionScenario,
      glados.ExploreConfig(numRuns: 80),
    ).test(
      'matches generated template head/version resolution semantics',
      (scenario) async {
        final localDb = AgentDatabase(
          inMemoryDatabase: true,
          background: false,
        );
        final localRepo = AgentRepository(localDb);

        try {
          await localRepo.upsertEntity(
            makeTestTemplate(
              id: generatedTemplateTargetId,
              agentId: generatedTemplateTargetId,
              createdAt: testDate,
              updatedAt: testDate,
            ),
          );
          await localRepo.upsertEntity(
            makeTestTemplate(
              id: generatedTemplateOtherId,
              agentId: generatedTemplateOtherId,
              createdAt: testDate,
              updatedAt: testDate,
            ),
          );

          for (var index = 0; index < scenario.versions.length; index++) {
            final spec = scenario.versions[index];
            await localRepo.upsertEntity(
              makeTestTemplateVersion(
                id: spec.idAt(index),
                agentId: spec.templateId,
                version: spec.version,
                status: spec.status,
                createdAt: spec.createdAt(index),
                vectorClock: const VectorClock({'node-1': 1}),
              ).copyWith(deletedAt: spec.deletedAt(index)),
            );
          }

          for (var index = 0; index < scenario.heads.length; index++) {
            final spec = scenario.heads[index];
            await localRepo.upsertEntity(
              makeTestTemplateHead(
                id: spec.idAt(index),
                agentId: spec.templateId,
                versionId: spec.versionIdFor(scenario),
                updatedAt: spec.updatedAt(index),
                vectorClock: const VectorClock({'node-1': 2}),
              ).copyWith(deletedAt: spec.deletedAt(index)),
            );
          }

          for (var index = 0; index < scenario.assignments.length; index++) {
            final spec = scenario.assignments[index];
            await localRepo.upsertLink(
              model.AgentLink.templateAssignment(
                id: spec.idAt(index),
                fromId: spec.templateId,
                toId: spec.agentId,
                createdAt: spec.createdAt(index),
                updatedAt: spec.createdAt(index),
                vectorClock: const VectorClock({'node-1': 3}),
                deletedAt: spec.deletedAt(index),
              ),
            );
          }

          final head = await localRepo.getTemplateHead(
            generatedTemplateTargetId,
          );
          expect(head?.id, scenario.expectedHeadId, reason: '$scenario');
          expect(
            head?.versionId,
            scenario.expectedHeadVersionId,
            reason: '$scenario',
          );

          final activeVersion = await localRepo.getActiveTemplateVersion(
            generatedTemplateTargetId,
          );
          expect(
            activeVersion?.id,
            scenario.expectedActiveVersionId,
            reason: '$scenario',
          );
          expect(
            activeVersion?.status,
            scenario.expectedActiveVersionStatus,
            reason: '$scenario',
          );

          final nextVersion = await localRepo.getNextTemplateVersionNumber(
            generatedTemplateTargetId,
          );
          expect(
            nextVersion,
            scenario.expectedNextVersionNumber,
            reason: '$scenario',
          );

          final assignmentLinks = await localRepo.getLinksFrom(
            generatedTemplateTargetId,
            type: AgentLinkTypes.templateAssignment,
          );
          expect(
            assignmentLinks.map((link) => link.id).toSet(),
            scenario.expectedTargetAssignmentIds,
            reason: '$scenario',
          );
          expect(
            assignmentLinks.map((link) => link.toId).toSet(),
            scenario.expectedTargetAssignmentAgentIds,
            reason: '$scenario',
          );
        } finally {
          await localDb.close();
        }
      },
      tags: 'glados',
    );

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

      test(
        'omitted optional args leave columns NULL and never overwrite '
        'previously set values (Value.absent semantics)',
        () async {
          await repo.insertWakeRun(entry: makeWakeRun(runKey: 'run-absent'));

          // First update without optional args: columns stay NULL.
          await repo.updateWakeRunTemplate('run-absent', 'tpl-001', 'ver-001');
          var run = await repo.getWakeRun('run-absent');
          expect(run!.resolvedModelId, isNull);
          expect(run.soulId, isNull);
          expect(run.soulVersionId, isNull);

          // Set all optional columns.
          await repo.updateWakeRunTemplate(
            'run-absent',
            'tpl-001',
            'ver-001',
            resolvedModelId: 'model-1',
            soulId: 'soul-001',
            soulVersionId: 'sv-001',
          );

          // A later update without optional args must NOT null them out.
          await repo.updateWakeRunTemplate('run-absent', 'tpl-002', 'ver-002');
          run = await repo.getWakeRun('run-absent');
          expect(run!.templateId, 'tpl-002');
          expect(run.resolvedModelId, 'model-1');
          expect(run.soulId, 'soul-001');
          expect(run.soulVersionId, 'sv-001');
        },
      );

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
      // One run in every non-running status: none of these may be touched.
      for (final status in ['completed', 'failed', 'aborted', 'abandoned']) {
        await repo.insertWakeRun(
          entry: makeWakeRun(runKey: 'run-$status', status: status),
        );
      }
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

      // Verify non-running runs are untouched (terminal states and
      // pending alike).
      for (final status in ['completed', 'failed', 'aborted', 'abandoned']) {
        final run = await repo.getWakeRun('run-$status');
        expect(run!.status, status, reason: 'status $status must not change');
      }

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

  glados.Glados(
    glados.any.templateInstanceQueryScenario,
    glados.ExploreConfig(numRuns: 80),
  ).test(
    'matches generated template instance token/report query semantics',
    (scenario) async {
      final localDb = AgentDatabase(
        inMemoryDatabase: true,
        background: false,
      );
      final localRepo = AgentRepository(localDb);

      try {
        for (final assignment in scenario.assignments) {
          await localRepo.upsertLink(
            model.AgentLink.templateAssignment(
              id: assignment.id,
              fromId: assignment.templateId,
              toId: assignment.agentId,
              createdAt: assignment.createdAt,
              updatedAt: assignment.createdAt,
              vectorClock: const VectorClock({'node-1': 1}),
              deletedAt: assignment.deletedAt,
            ),
          );
        }

        for (var index = 0; index < scenario.tokenUsages.length; index++) {
          final usage = scenario.tokenUsages[index];
          await localRepo.upsertEntity(
            AgentDomainEntity.wakeTokenUsage(
              id: usage.idAt(index),
              agentId: usage.agentId,
              runKey: usage.runKeyAt(index),
              threadId: usage.threadIdAt(index),
              modelId: usage.modelId,
              createdAt: usage.createdAt(index),
              vectorClock: const VectorClock({'node-1': 2}),
              inputTokens: usage.inputTokens,
              outputTokens: usage.outputTokens,
              thoughtsTokens: usage.thoughtsTokens,
              deletedAt: usage.deletedAt(index),
            ),
          );
        }

        for (var index = 0; index < scenario.reports.length; index++) {
          final report = scenario.reports[index];
          await localRepo.upsertEntity(
            AgentDomainEntity.agentReport(
              id: report.idAt(index),
              agentId: report.agentId,
              scope: report.scope,
              content: report.contentAt(index),
              createdAt: report.createdAt(index),
              vectorClock: const VectorClock({'node-1': 3}),
              deletedAt: report.deletedAt(index),
            ),
          );
        }

        final usage = await localRepo.getTokenUsageForTemplate(
          generatedInstanceTargetTemplateId,
          limit: scenario.usageLimit,
        );
        expect(
          usage.map((entry) => entry.id).toList(),
          scenario.expectedTokenUsageIds(limit: scenario.usageLimit),
          reason: '$scenario',
        );

        final usageSince = await localRepo.getTokenUsageForTemplateSince(
          generatedInstanceTargetTemplateId,
          since: generatedTemplateInstanceSince,
        );
        expect(
          usageSince.map((entry) => entry.id).toList(),
          scenario.expectedTokenUsageIdsSince(generatedTemplateInstanceSince),
          reason: '$scenario',
        );

        final sums = scenario.expectedTokenSums();
        final result = await localRepo.sumTokenUsageForTemplate(
          generatedInstanceTargetTemplateId,
        );
        expect(result.totalInput, sums.input, reason: '$scenario');
        expect(result.totalOutput, sums.output, reason: '$scenario');
        expect(result.totalThoughts, sums.thoughts, reason: '$scenario');

        final sumsSince = scenario.expectedTokenSums(
          since: generatedTemplateInstanceSince,
        );
        final resultSince = await localRepo.sumTokenUsageForTemplateSince(
          generatedInstanceTargetTemplateId,
          since: generatedTemplateInstanceSince,
        );
        expect(resultSince.totalInput, sumsSince.input, reason: '$scenario');
        expect(resultSince.totalOutput, sumsSince.output, reason: '$scenario');
        expect(
          resultSince.totalThoughts,
          sumsSince.thoughts,
          reason: '$scenario',
        );

        final reports = await localRepo.getRecentReportsByTemplate(
          generatedInstanceTargetTemplateId,
          limit: scenario.reportLimit,
        );
        expect(
          reports.map((report) => report.id).toList(),
          scenario.expectedReportIds(limit: scenario.reportLimit),
          reason: '$scenario',
        );
      } finally {
        await localDb.close();
      }
    },
    tags: 'glados',
  );

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

    glados.Glados(
      glados.any.intervalQueryScenario,
      glados.ExploreConfig(numRuns: 60),
    ).test(
      'matches generated entity interval query and pagination semantics',
      (scenario) async {
        final localDb = AgentDatabase(
          inMemoryDatabase: true,
          background: false,
        );
        final localRepo = AgentRepository(localDb);
        try {
          for (var index = 0; index < scenario.specs.length; index++) {
            final spec = scenario.specs[index];
            final deletedAt = spec.deleted ? spec.updatedAt : null;
            final entity = switch (spec.kind) {
              GeneratedIntervalEntityKind.agent =>
                makeAgent(
                  id: spec.idAt(index),
                  agentId: spec.agentId,
                ).copyWith(
                  updatedAt: spec.updatedAt,
                  deletedAt: deletedAt,
                ),
              GeneratedIntervalEntityKind.state =>
                makeAgentState(
                  id: spec.idAt(index),
                  agentId: spec.agentId,
                ).copyWith(
                  updatedAt: spec.updatedAt,
                  deletedAt: deletedAt,
                ),
            };
            await localRepo.upsertEntity(entity);
          }

          final expectedIds = scenario.expectedIds(
            intervalStart,
            intervalEnd,
          );
          final count = await localRepo.countEntitiesInInterval(
            start: intervalStart,
            end: intervalEnd,
          );
          expect(count, expectedIds.length, reason: '$scenario');

          final paged = <AgentDomainEntity>[];
          for (
            var offset = 0;
            offset < expectedIds.length + scenario.pageSize;
            offset += scenario.pageSize
          ) {
            paged.addAll(
              await localRepo.getEntitiesInInterval(
                start: intervalStart,
                end: intervalEnd,
                limit: scenario.pageSize,
                offset: offset,
              ),
            );
          }

          expect(paged, hasLength(expectedIds.length), reason: '$scenario');
          expect(paged.map((entity) => entity.id).toSet(), expectedIds.toSet());
          expect(
            paged
                .where((entity) => entity.deletedAt != null)
                .map((entity) => entity.id)
                .toSet(),
            scenario.expectedDeletedIds(intervalStart, intervalEnd).toSet(),
            reason: '$scenario',
          );
        } finally {
          await localDb.close();
        }
      },
      tags: 'glados',
    );

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

    test('sums positive run duration in milliseconds', () async {
      final startedAt = DateTime(2026, 3, 1, 8);
      final completedAt = startedAt.add(const Duration(minutes: 1));
      await insertTemplateWakeRun(
        repo,
        runKey: 'run-duration',
        templateId: templateId,
        status: WakeRunStatus.completed.name,
        createdAt: startedAt,
      );
      await repo.updateWakeRunStatus(
        'run-duration',
        WakeRunStatus.completed.name,
        startedAt: startedAt,
        completedAt: completedAt,
      );

      final result = await repo.aggregateWakeRunMetrics(templateId);

      expect(result.durationCount, 1);
      expect(result.durationSumMs, const Duration(minutes: 1).inMilliseconds);
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

  // ── getDueScheduledAgentStates ────────────────────────────────────────────

  group('getDueScheduledAgentStates', () {
    test(
      'returns states whose scheduledWakeAt is before or equal to now',
      () async {
        final now = DateTime(2026, 4, 1, 12);

        await repo.upsertEntity(
          makeTestState(
            id: 'state-due-1',
            agentId: 'agent-due-1',
            scheduledWakeAt: DateTime(2026, 4, 1, 11),
          ),
        );
        await repo.upsertEntity(
          makeTestState(
            id: 'state-due-2',
            agentId: 'agent-due-2',
            scheduledWakeAt: now,
          ),
        );
        // Future — must not be returned.
        await repo.upsertEntity(
          makeTestState(
            id: 'state-future',
            agentId: 'agent-future',
            scheduledWakeAt: DateTime(2026, 4, 1, 13),
          ),
        );

        final result = await repo.getDueScheduledAgentStates(now);

        expect(
          result.map((s) => s.id),
          containsAll(['state-due-1', 'state-due-2']),
        );
        expect(result.map((s) => s.id), isNot(contains('state-future')));
      },
    );

    test('returns empty list when no due states exist', () async {
      await repo.upsertEntity(
        makeTestState(
          id: 'state-future-only',
          agentId: 'agent-future-only',
          scheduledWakeAt: DateTime(2026, 5),
        ),
      );

      final result = await repo.getDueScheduledAgentStates(DateTime(2026, 4));

      expect(result, isEmpty);
    });

    test('ignores states with no scheduledWakeAt', () async {
      // State without scheduledWakeAt — must not appear.
      await repo.upsertEntity(
        makeTestState(id: 'state-no-schedule', agentId: 'agent-no-sched'),
      );

      final result = await repo.getDueScheduledAgentStates(
        DateTime(2026, 12, 31),
      );

      expect(result, isEmpty);
    });
  });

  // ── getDueScheduledWakeRecords ─────────────────────────────────────────────

  group('getDueScheduledWakeRecords', () {
    ScheduledWakeEntity makeScheduledWake({
      required String id,
      required DateTime scheduledAt,
      ScheduledWakeStatus status = ScheduledWakeStatus.pending,
      String agentId = testAgentId,
      String workspaceKey = 'day:dayplan-2026-04-01',
      List<String> triggerTokens = const ['planning_day:dayplan-2026-04-01'],
      DateTime? deletedAt,
    }) {
      return AgentDomainEntity.scheduledWake(
            id: id,
            agentId: agentId,
            scheduledAt: scheduledAt,
            status: status,
            reason: WakeReason.scheduled.name,
            updatedAt: testDate,
            vectorClock: const VectorClock({'node-1': 7}),
            triggerTokens: triggerTokens,
            workspaceKey: workspaceKey,
            deletedAt: deletedAt,
          )
          as ScheduledWakeEntity;
    }

    test(
      'returns pending records whose scheduledAt is before or equal to now, '
      'mapped with their day context',
      () async {
        final now = DateTime(2026, 4, 1, 12);

        await repo.upsertEntity(
          makeScheduledWake(
            id: 'wake-past',
            scheduledAt: DateTime(2026, 4, 1, 11),
          ),
        );
        await repo.upsertEntity(
          makeScheduledWake(id: 'wake-now', scheduledAt: now),
        );
        // Future — must not be returned.
        await repo.upsertEntity(
          makeScheduledWake(
            id: 'wake-future',
            scheduledAt: DateTime(2026, 4, 1, 13),
          ),
        );

        final result = await repo.getDueScheduledWakeRecords(now);

        expect(result.map((r) => r.id), containsAll(['wake-past', 'wake-now']));
        expect(result.map((r) => r.id), isNot(contains('wake-future')));
        final past = result.firstWhere((r) => r.id == 'wake-past');
        expect(past.workspaceKey, 'day:dayplan-2026-04-01');
        expect(past.triggerTokens, ['planning_day:dayplan-2026-04-01']);
        expect(past.status, ScheduledWakeStatus.pending);
      },
    );

    test('excludes records that are no longer pending', () async {
      final now = DateTime(2026, 4, 1, 12);
      await repo.upsertEntity(
        makeScheduledWake(
          id: 'wake-consumed',
          scheduledAt: DateTime(2026, 4, 1, 11),
          status: ScheduledWakeStatus.consumed,
        ),
      );

      final result = await repo.getDueScheduledWakeRecords(now);

      expect(result, isEmpty);
    });

    test('excludes soft-deleted records', () async {
      final now = DateTime(2026, 4, 1, 12);
      await repo.upsertEntity(
        makeScheduledWake(
          id: 'wake-deleted',
          scheduledAt: DateTime(2026, 4, 1, 11),
          deletedAt: DateTime(2026, 4, 1, 11, 30),
        ),
      );

      final result = await repo.getDueScheduledWakeRecords(now);

      expect(result, isEmpty);
    });

    test('returns empty list when nothing is due', () async {
      await repo.upsertEntity(
        makeScheduledWake(
          id: 'wake-future-only',
          scheduledAt: DateTime(2026, 5),
        ),
      );

      final result = await repo.getDueScheduledWakeRecords(DateTime(2026, 4));

      expect(result, isEmpty);
    });
  });

  // ── getEntitiesWithNullVectorClock / countEntitiesWithNullVectorClock ──────

  group('getEntitiesWithNullVectorClock', () {
    test('returns entities whose vectorClock is null', () async {
      // Null-clock entity.
      await repo.upsertEntity(
        makeTestIdentity(
          id: 'agent-null-vc',
          agentId: 'agent-null-vc',
          // ignore: avoid_redundant_argument_values
          vectorClock: null,
        ),
      );
      // Non-null-clock entity — must not appear.
      await repo.upsertEntity(
        makeTestIdentity(
          id: 'agent-has-vc',
          agentId: 'agent-has-vc',
          vectorClock: const VectorClock({'node-1': 1}),
        ),
      );

      final result = await repo.getEntitiesWithNullVectorClock();

      expect(result.map((e) => e.id), contains('agent-null-vc'));
      expect(result.map((e) => e.id), isNot(contains('agent-has-vc')));
    });

    test('returns empty list when all entities have clocks', () async {
      await repo.upsertEntity(
        makeTestIdentity(
          id: 'agent-clocked',
          agentId: 'agent-clocked',
          vectorClock: const VectorClock({'node-1': 5}),
        ),
      );

      final result = await repo.getEntitiesWithNullVectorClock();

      expect(result, isEmpty);
    });
  });

  group('countEntitiesWithNullVectorClock', () {
    test('counts only entities with null vectorClock', () async {
      await repo.upsertEntity(
        makeTestIdentity(
          id: 'agent-nvc-1',
          agentId: 'agent-nvc-1',
          // ignore: avoid_redundant_argument_values
          vectorClock: null,
        ),
      );
      await repo.upsertEntity(
        makeTestIdentity(
          id: 'agent-nvc-2',
          agentId: 'agent-nvc-2',
          // ignore: avoid_redundant_argument_values
          vectorClock: null,
        ),
      );
      await repo.upsertEntity(
        makeTestIdentity(
          id: 'agent-vc',
          agentId: 'agent-vc',
          vectorClock: const VectorClock({'node-1': 1}),
        ),
      );

      final count = await repo.countEntitiesWithNullVectorClock();

      expect(count, 2);
    });

    test('returns zero when all entities have clocks', () async {
      await repo.upsertEntity(
        makeTestIdentity(
          id: 'agent-has-vc',
          agentId: 'agent-has-vc',
          vectorClock: const VectorClock({'h': 3}),
        ),
      );

      final count = await repo.countEntitiesWithNullVectorClock();

      expect(count, 0);
    });
  });

  // ── getEvolutionSessionRecaps / getEvolutionSessionRecap ──────────────────

  group('getEvolutionSessionRecaps', () {
    const templateId = 'tpl-recap-001';

    test('returns recaps for the given templateId', () async {
      await repo.upsertEntity(
        makeTestEvolutionSessionRecap(
          id: evolutionSessionRecapId('session-A'),
          agentId: templateId,
          sessionId: 'session-A',
          tldr: 'Recap A',
          createdAt: DateTime(2026, 3),
        ),
      );
      await repo.upsertEntity(
        makeTestEvolutionSessionRecap(
          id: evolutionSessionRecapId('session-B'),
          agentId: templateId,
          sessionId: 'session-B',
          tldr: 'Recap B',
          createdAt: DateTime(2026, 3, 2),
        ),
      );
      // Different template — must not appear.
      await repo.upsertEntity(
        makeTestEvolutionSessionRecap(
          id: evolutionSessionRecapId('session-other'),
          agentId: 'tpl-other',
          sessionId: 'session-other',
          tldr: 'Other',
          createdAt: DateTime(2026, 3, 3),
        ),
      );

      final recaps = await repo.getEvolutionSessionRecaps(templateId);

      expect(
        recaps.map((r) => r.sessionId),
        containsAll(['session-A', 'session-B']),
      );
      expect(recaps.map((r) => r.sessionId), isNot(contains('session-other')));
    });

    test('returns empty list when no recaps exist for template', () async {
      final recaps = await repo.getEvolutionSessionRecaps('tpl-empty');

      expect(recaps, isEmpty);
    });

    test('respects the limit parameter', () async {
      for (var i = 0; i < 5; i++) {
        await repo.upsertEntity(
          makeTestEvolutionSessionRecap(
            id: evolutionSessionRecapId('session-lim-$i'),
            agentId: templateId,
            sessionId: 'session-lim-$i',
            tldr: 'Recap $i',
            createdAt: DateTime(2026, 3, i + 1),
          ),
        );
      }

      final recaps = await repo.getEvolutionSessionRecaps(templateId, limit: 3);

      expect(recaps.length, 3);
    });
  });

  group('getEvolutionSessionRecap', () {
    test('returns the recap entity for the given sessionId', () async {
      const sessionId = 'session-recap-fetch';
      await repo.upsertEntity(
        makeTestEvolutionSessionRecap(
          id: evolutionSessionRecapId(sessionId),
          agentId: 'tpl-recap-fetch',
          sessionId: sessionId,
          tldr: 'Found it',
        ),
      );

      final recap = await repo.getEvolutionSessionRecap(sessionId);

      expect(recap, isNotNull);
      expect(recap!.sessionId, sessionId);
      expect(recap.tldr, 'Found it');
    });

    test('returns null when no recap exists for sessionId', () async {
      final recap = await repo.getEvolutionSessionRecap('session-missing');

      expect(recap, isNull);
    });
  });

  // ── getLinksWithNullVectorClock / countLinksWithNullVectorClock ───────────

  group('getLinksWithNullVectorClock', () {
    test('returns links whose vectorClock is null', () async {
      await repo.upsertLink(
        makeTestBasicLink(
          id: 'link-null-vc',
          fromId: 'agent-A',
          toId: 'agent-B',
          // ignore: avoid_redundant_argument_values
          vectorClock: null,
        ),
      );
      await repo.upsertLink(
        makeTestBasicLink(
          id: 'link-has-vc',
          fromId: 'agent-C',
          toId: 'agent-D',
          vectorClock: const VectorClock({'node-1': 2}),
        ),
      );

      final result = await repo.getLinksWithNullVectorClock();

      expect(result.map((l) => l.id), contains('link-null-vc'));
      expect(result.map((l) => l.id), isNot(contains('link-has-vc')));
    });

    test('returns empty list when all links have clocks', () async {
      await repo.upsertLink(
        makeTestBasicLink(
          id: 'link-clocked',
          fromId: 'ag-X',
          toId: 'ag-Y',
          vectorClock: const VectorClock({'h': 1}),
        ),
      );

      final result = await repo.getLinksWithNullVectorClock();

      expect(result, isEmpty);
    });
  });

  group('countLinksWithNullVectorClock', () {
    test('counts links with null vectorClock', () async {
      await repo.upsertLink(
        makeTestBasicLink(
          id: 'link-nvc-1',
          fromId: 'from-1',
          toId: 'to-1',
          // ignore: avoid_redundant_argument_values
          vectorClock: null,
        ),
      );
      await repo.upsertLink(
        makeTestBasicLink(
          id: 'link-nvc-2',
          fromId: 'from-2',
          toId: 'to-2',
          // ignore: avoid_redundant_argument_values
          vectorClock: null,
        ),
      );
      await repo.upsertLink(
        makeTestBasicLink(
          id: 'link-vc',
          fromId: 'from-3',
          toId: 'to-3',
          vectorClock: const VectorClock({'n': 7}),
        ),
      );

      final count = await repo.countLinksWithNullVectorClock();

      expect(count, 2);
    });

    test('returns zero when all links have clocks', () async {
      await repo.upsertLink(
        makeTestBasicLink(
          id: 'link-only-clocked',
          fromId: 'f',
          toId: 't',
          vectorClock: const VectorClock({'h': 1}),
        ),
      );

      final count = await repo.countLinksWithNullVectorClock();

      expect(count, 0);
    });
  });

  // ── getTokenUsageForAgent ─────────────────────────────────────────────────

  group('getTokenUsageForAgent', () {
    const agentId = 'agent-token-001';
    const otherAgent = 'agent-token-002';

    test('returns token usage entities for the given agentId', () async {
      await repo.upsertEntity(
        makeTestWakeTokenUsage(
          id: 'tu-1',
          agentId: agentId,
          runKey: 'run-tu-1',
          createdAt: DateTime(2026, 4),
        ),
      );
      await repo.upsertEntity(
        makeTestWakeTokenUsage(
          id: 'tu-2',
          agentId: agentId,
          runKey: 'run-tu-2',
          inputTokens: 200,
          outputTokens: 120,
          createdAt: DateTime(2026, 4, 2),
        ),
      );
      // Different agent — must not appear.
      await repo.upsertEntity(
        makeTestWakeTokenUsage(
          id: 'tu-other',
          agentId: otherAgent,
          runKey: 'run-tu-other',
          inputTokens: 999,
          createdAt: DateTime(2026, 4, 3),
        ),
      );

      final result = await repo.getTokenUsageForAgent(agentId);

      expect(result.map((r) => r.id), containsAll(['tu-1', 'tu-2']));
      expect(result.map((r) => r.id), isNot(contains('tu-other')));
      expect(result.every((r) => r.agentId == agentId), isTrue);
    });

    test('returns empty list when no token usage exists for agent', () async {
      final result = await repo.getTokenUsageForAgent('agent-no-usage');

      expect(result, isEmpty);
    });

    test('respects the limit parameter', () async {
      for (var i = 0; i < 5; i++) {
        await repo.upsertEntity(
          makeTestWakeTokenUsage(
            id: 'tu-lim-$i',
            agentId: agentId,
            runKey: 'run-lim-$i',
            createdAt: DateTime(2026, 4, i + 1),
          ),
        );
      }

      final result = await repo.getTokenUsageForAgent(agentId, limit: 2);

      expect(result.length, 2);
    });
  });

  // ── getGlobalTokenUsageSince ──────────────────────────────────────────────

  group('getGlobalTokenUsageSince', () {
    test(
      'returns token usage records on or after since across all agents',
      () async {
        final cutoff = DateTime(2026, 4, 10);

        await repo.upsertEntity(
          makeTestWakeTokenUsage(
            id: 'gtu-before',
            agentId: 'agent-global-A',
            runKey: 'run-gb',
            inputTokens: 500,
            createdAt: DateTime(2026, 4, 9),
          ),
        );
        await repo.upsertEntity(
          makeTestWakeTokenUsage(
            id: 'gtu-on',
            agentId: 'agent-global-B',
            runKey: 'run-go',
            createdAt: cutoff,
          ),
        );
        await repo.upsertEntity(
          makeTestWakeTokenUsage(
            id: 'gtu-after',
            agentId: 'agent-global-C',
            runKey: 'run-ga',
            inputTokens: 200,
            createdAt: DateTime(2026, 4, 11),
          ),
        );

        final result = await repo.getGlobalTokenUsageSince(since: cutoff);

        expect(result.map((r) => r.id), containsAll(['gtu-on', 'gtu-after']));
        expect(result.map((r) => r.id), isNot(contains('gtu-before')));
      },
    );

    test('returns empty list when no records are on or after since', () async {
      await repo.upsertEntity(
        makeTestWakeTokenUsage(
          id: 'gtu-old',
          agentId: 'agent-old',
          runKey: 'run-old',
          createdAt: DateTime(2026),
        ),
      );

      final result = await repo.getGlobalTokenUsageSince(
        since: DateTime(2026, 6),
      );

      expect(result, isEmpty);
    });

    test('aggregates across agents without template filter', () async {
      final since = DateTime(2026, 5);
      for (var i = 0; i < 3; i++) {
        await repo.upsertEntity(
          makeTestWakeTokenUsage(
            id: 'gtu-multi-$i',
            agentId: 'agent-multi-$i',
            runKey: 'run-multi-$i',
            createdAt: since.add(Duration(hours: i)),
          ),
        );
      }

      final result = await repo.getGlobalTokenUsageSince(since: since);

      expect(result.length, 3);
    });
  });

  // ── getActiveSoulDocumentVersionsBySoulIds empty branch ───────────────────

  group('getActiveSoulDocumentVersionsBySoulIds', () {
    test('returns empty map when soulIds list is empty', () async {
      final result = await repo.getActiveSoulDocumentVersionsBySoulIds([]);

      expect(result, isEmpty);
    });

    test(
      'returns empty map when no soul document heads exist for given soulIds',
      () async {
        final result = await repo.getActiveSoulDocumentVersionsBySoulIds([
          'soul-missing',
        ]);

        expect(result, isEmpty);
      },
    );
  });

  // ── DomainLogger wiring on duplicate inserts ───────────────────────────────

  group('DuplicateInsertException logging', () {
    late AgentDatabase loggedDb;
    late AgentRepository loggedRepo;
    late MockDomainLogger mockLogger;

    setUpAll(registerAllFallbackValues);

    setUp(() {
      loggedDb = AgentDatabase(inMemoryDatabase: true, background: false);
      mockLogger = MockDomainLogger();
      loggedRepo = AgentRepository(loggedDb, domainLogger: mockLogger);
    });

    tearDown(() async {
      await loggedDb.close();
    });

    test('insertLinkExclusive logs SqliteException before throwing', () async {
      const toId = 'tpl-target-logger';
      await loggedRepo.insertLinkExclusive(
        model.AgentLink.improverTarget(
          id: 'link-logger-first',
          fromId: 'agent-imp-A',
          toId: toId,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        ),
      );

      await expectLater(
        loggedRepo.insertLinkExclusive(
          model.AgentLink.improverTarget(
            id: 'link-logger-second',
            fromId: 'agent-imp-B',
            toId: toId,
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        ),
        throwsA(isA<DuplicateInsertException>()),
      );

      verify(
        () => mockLogger.error(
          LogDomain.agentRuntime,
          any(that: isA<SqliteException>()),
          message: any(named: 'message', that: contains('agent_links')),
          stackTrace: any(named: 'stackTrace', that: isNotNull),
          subDomain: 'AgentRepository.insertLinkExclusive',
        ),
      ).called(1);
    });

    test('insertWakeRun logs SqliteException before throwing', () async {
      final entry = makeWakeRun();
      await loggedRepo.insertWakeRun(entry: entry);

      await expectLater(
        loggedRepo.insertWakeRun(entry: makeWakeRun()),
        throwsA(isA<DuplicateInsertException>()),
      );

      verify(
        () => mockLogger.error(
          LogDomain.agentRuntime,
          any(that: isA<SqliteException>()),
          message: any(named: 'message', that: contains('wake_run_log')),
          stackTrace: any(named: 'stackTrace', that: isNotNull),
          subDomain: 'AgentRepository.insertWakeRun',
        ),
      ).called(1);
    });

    test('insertSagaOp logs SqliteException before throwing', () async {
      await loggedRepo.insertSagaOp(entry: makeSagaOp());

      await expectLater(
        loggedRepo.insertSagaOp(entry: makeSagaOp()),
        throwsA(isA<DuplicateInsertException>()),
      );

      verify(
        () => mockLogger.error(
          LogDomain.agentRuntime,
          any(that: isA<SqliteException>()),
          message: any(named: 'message', that: contains('saga_log')),
          stackTrace: any(named: 'stackTrace', that: isNotNull),
          subDomain: 'AgentRepository.insertSagaOp',
        ),
      ).called(1);
    });
  });
}
