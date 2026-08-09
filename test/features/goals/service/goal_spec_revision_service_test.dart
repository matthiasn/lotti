import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/goals/service/goal_spec_revision_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const agentId = 'goal-1';
  final now = DateTime(2026, 8, 10, 9);
  final fixedClock = Clock.fixed(now);

  const criteria = GoalCriterion.metric(
    criterionId: 'steps',
    dataType: 'cumulative_step_count',
    window: GoalWindow.rollingDays(count: 7),
    aggregation: GoalAggregation.dailySumThenAverage,
    target: 10000,
  );

  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late List<AgentDomainEntity> upserts;
  late GoalSpecRevisionService service;

  setUp(() {
    repository = MockAgentRepository();
    syncService = MockAgentSyncService();
    upserts = [];
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
    service = GoalSpecRevisionService(
      repository: repository,
      syncService: syncService,
    );
  });

  void stubSpec({int version = 1}) {
    when(() => repository.getEntity(goalSpecHeadId(agentId))).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecHead(
        id: goalSpecHeadId(agentId),
        agentId: agentId,
        versionId: '$agentId:spec-v$version',
        updatedAt: DateTime(2026, 8),
        vectorClock: null,
      ),
    );
    when(() => repository.getEntity('$agentId:spec-v$version')).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecVersion(
        id: '$agentId:spec-v$version',
        agentId: agentId,
        version: version,
        status: GoalSpecVersionStatus.active,
        authoredBy: 'user',
        title: 'Steps',
        statement: 'Average 10,000 steps per day.',
        criteria: criteria,
        createdAt: DateTime(2026, 8),
        vectorClock: null,
        startDate: DateTime(2026, 8),
      ),
    );
  }

  test('an approved proposal supersedes v1, mints v2 with provenance, and '
      'moves the head — in one transaction', () async {
    stubSpec();
    final outcome = await withClock(
      fixedClock,
      () => service.reviseFromProposal(
        agentId: agentId,
        changes: {'targetValue': 8000},
        rationale: 'user asked to ease off after the injury',
      ),
    );

    expect(outcome, isA<GoalSpecRevisionMinted>());
    final minted = (outcome as GoalSpecRevisionMinted).version;
    expect(minted.id, '$agentId:spec-v2');
    expect(minted.version, 2);
    expect(minted.status, GoalSpecVersionStatus.active);
    expect(minted.authoredBy, AgentKinds.goalAgent);
    expect(minted.diffFromVersionId, '$agentId:spec-v1');
    expect(minted.rationale, 'user asked to ease off after the injury');
    expect((minted.criteria as GoalCriterionMetric).target, 8000);
    expect(
      minted.startDate,
      DateTime(2026, 8),
      reason: 'dates carry over — a revision is not a restart',
    );
    expect(outcome.changeSummaries, ['target: 10000 → 8000']);

    final superseded = upserts.whereType<GoalSpecVersionEntity>().singleWhere(
      (v) => v.id == '$agentId:spec-v1',
    );
    expect(superseded.status, GoalSpecVersionStatus.superseded);
    final head = upserts.whereType<GoalSpecHeadEntity>().single;
    expect(head.id, goalSpecHeadId(agentId));
    expect(head.versionId, '$agentId:spec-v2');
    expect(head.updatedAt, now);
  });

  test('refusals: missing head, dangling head, inapplicable changes — '
      'nothing is written', () async {
    // No head at all.
    var outcome = await service.reviseFromProposal(
      agentId: agentId,
      changes: {'targetValue': 8000},
      rationale: 'r',
    );
    expect(
      (outcome as GoalSpecRevisionRefused).reason,
      contains('no spec head'),
    );

    // Dangling head.
    when(() => repository.getEntity(goalSpecHeadId(agentId))).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecHead(
        id: goalSpecHeadId(agentId),
        agentId: agentId,
        versionId: 'missing',
        updatedAt: DateTime(2026, 8),
        vectorClock: null,
      ),
    );
    outcome = await service.reviseFromProposal(
      agentId: agentId,
      changes: {'targetValue': 8000},
      rationale: 'r',
    );
    expect(
      (outcome as GoalSpecRevisionRefused).reason,
      contains('points at nothing'),
    );

    // Inapplicable proposal.
    stubSpec();
    outcome = await service.reviseFromProposal(
      agentId: agentId,
      changes: {'successCriteria': 'be happier'},
      rationale: 'r',
    );
    expect(
      (outcome as GoalSpecRevisionRefused).reason,
      contains('no applicable structural change'),
    );

    expect(upserts, isEmpty, reason: 'a refusal must write nothing');
  });

  test('a revision over an already-corrupt tree fails validation and '
      'refuses to mint', () async {
    // Duplicate criterionIds on two OTHER leaves (e.g. a bad sync from an
    // old peer): the target change on the unique steps leaf is a REAL
    // structural change, so the apply step succeeds — proving it is the
    // validator, not an apply no-op, that vetoes the mint.
    when(() => repository.getEntity(goalSpecHeadId(agentId))).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecHead(
        id: goalSpecHeadId(agentId),
        agentId: agentId,
        versionId: '$agentId:spec-v1',
        updatedAt: DateTime(2026, 8),
        vectorClock: null,
      ),
    );
    when(() => repository.getEntity('$agentId:spec-v1')).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecVersion(
        id: '$agentId:spec-v1',
        agentId: agentId,
        version: 1,
        status: GoalSpecVersionStatus.active,
        authoredBy: 'user',
        title: 'Steps',
        statement: 'x',
        criteria: const GoalCriterion.allOf(
          criterionId: 'root',
          criteria: [
            criteria,
            GoalCriterion.habit(
              criterionId: 'dup',
              habitId: 'gym-a',
              window: GoalWindow.calendarWeek(),
              targetCount: 3,
            ),
            GoalCriterion.habit(
              criterionId: 'dup',
              habitId: 'gym-b',
              window: GoalWindow.calendarWeek(),
              targetCount: 2,
            ),
          ],
        ),
        createdAt: DateTime(2026, 8),
        vectorClock: null,
      ),
    );
    final outcome = await service.reviseFromProposal(
      agentId: agentId,
      changes: {'metric': 'steps', 'targetValue': 8000},
      rationale: 'r',
    );
    expect(
      (outcome as GoalSpecRevisionRefused).reason,
      contains('fail validation'),
    );
    expect(upserts, isEmpty);
  });

  test('version numbers keep counting past v2', () async {
    stubSpec(version: 4);
    final outcome = await withClock(
      fixedClock,
      () => service.reviseFromProposal(
        agentId: agentId,
        changes: {'period': 'rolling 14 days'},
        rationale: 'longer horizon',
      ),
    );
    expect(
      (outcome as GoalSpecRevisionMinted).version.id,
      '$agentId:spec-v5',
    );
  });

  test('reads happen INSIDE the transaction, and a successor id that '
      'already exists refuses instead of overwriting provenance', () async {
    final order = <String>[];
    final txnSyncService = _OrderRecordingSyncService(order);
    when(() => txnSyncService.upsertEntity(any())).thenAnswer((
      invocation,
    ) async {
      upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
    final txnService = GoalSpecRevisionService(
      repository: repository,
      syncService: txnSyncService,
    );
    stubSpec();
    when(() => repository.getEntity(goalSpecHeadId(agentId))).thenAnswer((
      _,
    ) async {
      order.add('read-head');
      return AgentDomainEntity.goalSpecHead(
        id: goalSpecHeadId(agentId),
        agentId: agentId,
        versionId: '$agentId:spec-v1',
        updatedAt: DateTime(2026, 8),
        vectorClock: null,
      );
    });
    // The successor already exists: a concurrent acceptance won.
    when(() => repository.getEntity('$agentId:spec-v2')).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecVersion(
        id: '$agentId:spec-v2',
        agentId: agentId,
        version: 2,
        status: GoalSpecVersionStatus.active,
        authoredBy: AgentKinds.goalAgent,
        title: 'Steps',
        statement: 'x',
        criteria: criteria,
        createdAt: DateTime(2026, 8, 10, 8),
        vectorClock: null,
      ),
    );

    final outcome = await txnService.reviseFromProposal(
      agentId: agentId,
      changes: {'targetValue': 8000},
      rationale: 'r',
    );
    expect(
      (outcome as GoalSpecRevisionRefused).reason,
      contains('concurrent revision already minted'),
    );
    expect(upserts, isEmpty);
    expect(
      order.first,
      'transaction',
      reason: 'the head read must be serialized by the transaction',
    );
  });

  test('a post-commit sync failure is reconciled: the head already moved '
      'to the minted version, so the approval is reported as committed — '
      'a retry must not mint twice', () async {
    stubSpec();
    final failing = _CommitThenThrowSyncService();
    when(() => failing.upsertEntity(any())).thenAnswer((invocation) async {
      upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
    final service = GoalSpecRevisionService(
      repository: repository,
      syncService: failing,
    );
    // After the (durable) writes, the repository serves the moved head.
    when(() => repository.getEntity(goalSpecHeadId(agentId))).thenAnswer(
      (_) async =>
          upserts.whereType<GoalSpecHeadEntity>().lastOrNull ??
          AgentDomainEntity.goalSpecHead(
                id: goalSpecHeadId(agentId),
                agentId: agentId,
                versionId: '$agentId:spec-v1',
                updatedAt: DateTime(2026, 8),
                vectorClock: null,
              )
              as GoalSpecHeadEntity,
    );
    when(() => repository.getEntity('$agentId:spec-v2')).thenAnswer(
      (_) async => upserts
          .whereType<GoalSpecVersionEntity>()
          .where((v) => v.id == '$agentId:spec-v2')
          .lastOrNull,
    );

    final outcome = await withClock(
      fixedClock,
      () => service.reviseFromProposal(
        agentId: agentId,
        changes: {'targetValue': 8000},
        rationale: 'r',
      ),
    );
    expect(outcome, isA<GoalSpecRevisionMinted>());
    expect(
      (outcome as GoalSpecRevisionMinted).version.id,
      '$agentId:spec-v2',
    );
  });
}

class _OrderRecordingSyncService extends MockAgentSyncService {
  _OrderRecordingSyncService(this.order);

  final List<String> order;

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) {
    order.add('transaction');
    return action();
  }
}

/// Runs the transaction body (writes land) and THEN throws — the durable
/// commit + failed outbox flush shape.
class _CommitThenThrowSyncService extends MockAgentSyncService {
  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) async {
    await action();
    throw StateError('outbox flush failed');
  }
}
