import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
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

  AgentIdentityEntity goalIdentity(AgentLifecycle lifecycle) =>
      AgentDomainEntity.agent(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.goalAgent,
            displayName: 'Steps',
            lifecycle: lifecycle,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: '$agentId:state',
            config: const AgentConfig(),
            createdAt: DateTime(2026, 8),
            updatedAt: DateTime(2026, 8),
            vectorClock: null,
          )
          as AgentIdentityEntity;

  setUp(() {
    repository = MockAgentRepository();
    syncService = MockAgentSyncService();
    upserts = [];
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
    when(
      () => repository.getEntity(agentId),
    ).thenAnswer((_) async => goalIdentity(AgentLifecycle.active));
    when(
      () => repository.getEntitiesByAgentId(
        any(),
        type: any(named: 'type'),
      ),
    ).thenAnswer((_) async => []);
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

  test('an inactive goal refuses a revision before writing anything', () async {
    stubSpec();
    when(
      () => repository.getEntity(agentId),
    ).thenAnswer((_) async => goalIdentity(AgentLifecycle.dormant));

    final outcome = await service.reviseFromProposal(
      agentId: agentId,
      changes: {'targetValue': 8000},
      rationale: 'change it',
    );

    expect(outcome, isA<GoalSpecRevisionRefused>());
    expect(
      (outcome as GoalSpecRevisionRefused).reason,
      'goal agent is not active',
    );
    expect(upserts, isEmpty);
  });

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
    expect(minted.id, startsWith('$agentId:spec-v2-'));
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
    expect(head.versionId, minted.id);
    expect(head.updatedAt, now);
  });

  test('an owner edit mints a user-authored version, updates the persona, '
      'and preserves independently authored habit targets', () async {
    stubSpec(version: 3);
    const revisedCriteria = GoalCriterion.allOf(
      criterionId: 'routine',
      criteria: [
        GoalCriterion.habit(
          criterionId: 'habit-gym',
          habitId: 'gym',
          window: GoalWindow.rollingDays(count: 7),
          targetCount: 2,
        ),
        GoalCriterion.habit(
          criterionId: 'habit-run',
          habitId: 'run',
          window: GoalWindow.rollingDays(count: 7),
          targetCount: 5,
        ),
      ],
    );

    final outcome = await withClock(
      fixedClock,
      () => service.reviseFromOwner(
        agentId: agentId,
        baseVersionId: '$agentId:spec-v3',
        displayName: 'Juno',
        title: 'Expedition fitness',
        statement: 'Gym twice and run five times each rolling week.',
        criteria: revisedCriteria,
      ),
    );

    expect(outcome, isA<GoalSpecRevisionMinted>());
    final minted = (outcome as GoalSpecRevisionMinted).version;
    expect(minted.version, 4);
    expect(minted.authoredBy, 'user');
    expect(minted.title, 'Expedition fitness');
    expect(
      minted.statement,
      'Gym twice and run five times each rolling week.',
    );
    expect(minted.criteria, revisedCriteria);
    expect(minted.diffFromVersionId, '$agentId:spec-v3');
    expect(
      upserts.whereType<AgentIdentityEntity>().single.displayName,
      'Juno',
    );
    expect(outcome.changeSummaries, contains('goal criteria updated'));
  });

  test('an owner edit that changes nothing is refused without resetting '
      'goal history', () async {
    stubSpec();

    final outcome = await service.reviseFromOwner(
      agentId: agentId,
      baseVersionId: '$agentId:spec-v1',
      displayName: 'Steps',
      title: 'Steps',
      statement: 'Average 10,000 steps per day.',
      criteria: criteria,
    );

    expect(outcome, isA<GoalSpecRevisionRefused>());
    expect(
      (outcome as GoalSpecRevisionRefused).reason,
      'the owner edit does not change the goal',
    );
    expect(upserts, isEmpty);
  });

  test('an owner edit based on a stale version is refused', () async {
    stubSpec(version: 4);

    final outcome = await service.reviseFromOwner(
      agentId: agentId,
      baseVersionId: '$agentId:spec-v3',
      displayName: 'Juno',
      title: 'Movement',
      statement: 'Move consistently.',
      criteria: criteria,
    );

    expect(outcome, isA<GoalSpecRevisionRefused>());
    expect(
      (outcome as GoalSpecRevisionRefused).reason,
      GoalSpecRevisionService.ownerStaleVersionReason,
    );
    expect(upserts, isEmpty);
  });

  test(
    'an owner edit refuses invalid criteria and a dangling spec head',
    () async {
      const invalid = GoalCriterion.allOf(
        criterionId: 'root',
        criteria: [
          GoalCriterion.habit(
            criterionId: 'duplicate',
            habitId: 'gym',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 2,
          ),
          GoalCriterion.habit(
            criterionId: 'duplicate',
            habitId: 'run',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 3,
          ),
        ],
      );
      var outcome = await service.reviseFromOwner(
        agentId: agentId,
        baseVersionId: '$agentId:spec-v1',
        displayName: 'Juno',
        title: 'Movement',
        statement: 'Move consistently.',
        criteria: invalid,
      );
      expect(
        (outcome as GoalSpecRevisionRefused).reason,
        contains('fail validation'),
      );

      when(() => repository.getEntity(goalSpecHeadId(agentId))).thenAnswer(
        (_) async => AgentDomainEntity.goalSpecHead(
          id: goalSpecHeadId(agentId),
          agentId: agentId,
          versionId: 'missing',
          updatedAt: DateTime(2026, 8),
          vectorClock: null,
        ),
      );
      outcome = await service.reviseFromOwner(
        agentId: agentId,
        baseVersionId: '$agentId:spec-v1',
        displayName: 'Juno',
        title: 'Movement',
        statement: 'Move consistently.',
        criteria: criteria,
      );
      expect(
        (outcome as GoalSpecRevisionRefused).reason,
        contains('points at nothing'),
      );
      expect(upserts, isEmpty);
    },
  );

  test(
    'an owner edit reconciles a revision committed before sync failed',
    () async {
      stubSpec();
      final failing = _CommitThenThrowSyncService();
      when(() => failing.upsertEntity(any())).thenAnswer((invocation) async {
        upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
      });
      final ownerService = GoalSpecRevisionService(
        repository: repository,
        syncService: failing,
      );
      when(() => repository.getEntity(goalSpecHeadId(agentId))).thenAnswer(
        (_) async =>
            upserts.whereType<GoalSpecHeadEntity>().lastOrNull ??
            AgentDomainEntity.goalSpecHead(
              id: goalSpecHeadId(agentId),
              agentId: agentId,
              versionId: '$agentId:spec-v1',
              updatedAt: DateTime(2026, 8),
              vectorClock: null,
            ),
      );
      when(
        () => repository.getEntity(any(that: startsWith('$agentId:spec-v2'))),
      ).thenAnswer(
        (invocation) async => upserts
            .whereType<GoalSpecVersionEntity>()
            .where(
              (version) => version.id == invocation.positionalArguments.first,
            )
            .lastOrNull,
      );

      final outcome = await withClock(
        fixedClock,
        () => ownerService.reviseFromOwner(
          agentId: agentId,
          baseVersionId: '$agentId:spec-v1',
          displayName: 'Juno',
          title: 'Move daily',
          statement: 'Average 10,000 steps every day.',
          criteria: criteria,
        ),
      );

      expect(outcome, isA<GoalSpecRevisionMinted>());
      expect(
        (outcome as GoalSpecRevisionMinted).changeSummaries,
        ['(committed before a sync error)'],
      );
      expect(outcome.version.authoredBy, 'user');
    },
  );

  test("a minted revision supersedes the old spec's live nudges — the "
      'revised goal never runs beside advice for the superseded one', () async {
    stubSpec();
    GoalNudgeEntity nudgeRow(String id, GoalNudgeStatus status) =>
        AgentDomainEntity.goalNudge(
              id: id,
              agentId: agentId,
              status: status,
              brief: const GoalNudgeBrief(
                headline: 'h',
                tone: GoalNudgeTone.nudge,
                animation: GoalBannerAnimation.steady,
              ),
              briefDigest: 'd-$id',
              createdAt: DateTime(2026, 8, 9),
              updatedAt: DateTime(2026, 8, 9),
              vectorClock: null,
            )
            as GoalNudgeEntity;
    when(
      () => repository.getEntitiesByAgentId(agentId, type: 'goalNudge'),
    ).thenAnswer(
      (_) async => [
        nudgeRow('ad-active', GoalNudgeStatus.active),
        nudgeRow('ad-ready', GoalNudgeStatus.ready),
        nudgeRow('ad-dismissed', GoalNudgeStatus.dismissed),
        nudgeRow('ad-retired', GoalNudgeStatus.retired),
      ],
    );

    final outcome = await withClock(
      fixedClock,
      () => service.reviseFromProposal(
        agentId: agentId,
        changes: {'targetValue': 8000},
        rationale: 'ease off',
      ),
    );
    expect(outcome, isA<GoalSpecRevisionMinted>());

    final nudgeWrites = upserts.whereType<GoalNudgeEntity>().toList();
    expect(
      {for (final n in nudgeWrites) n.id: n.status},
      {
        'ad-active': GoalNudgeStatus.superseded,
        'ad-ready': GoalNudgeStatus.superseded,
        // Retired rows are the reuse library — a top-rated old-goal ad
        // must not be re-activated beside the revised statement.
        'ad-retired': GoalNudgeStatus.superseded,
      },
      reason:
          'live and reusable nudges move with the spec; the user '
          'verdict (dismissed) stays history',
    );
  });

  test('approval consumes pending old-spec escalations — a stale wake '
      'must not later spend inference against the revised register', () async {
    stubSpec();
    when(
      () => repository.getEntitiesByAgentId(agentId, type: 'scheduledWake'),
    ).thenAnswer(
      (_) async => [
        AgentDomainEntity.scheduledWake(
              id: 'scheduled_wake:$agentId:goal-escalation:2026-08-10',
              agentId: agentId,
              scheduledAt: DateTime(2026, 8, 10, 9),
              status: ScheduledWakeStatus.pending,
              reason: 'scheduled',
              updatedAt: DateTime(2026, 8, 10),
              vectorClock: null,
              workspaceKey: 'goal-escalation:2026-08-10',
            )
            as ScheduledWakeEntity,
        AgentDomainEntity.scheduledWake(
              id: 'scheduled_wake:$agentId:goal-cadence',
              agentId: agentId,
              scheduledAt: DateTime(2026, 8, 11, 6),
              status: ScheduledWakeStatus.pending,
              reason: 'scheduled',
              updatedAt: DateTime(2026, 8, 10),
              vectorClock: null,
              workspaceKey: 'goal-cadence',
            )
            as ScheduledWakeEntity,
      ],
    );
    final outcome = await withClock(
      fixedClock,
      () => service.reviseFromProposal(
        agentId: agentId,
        changes: {'targetValue': 8000},
        rationale: 'ease off',
      ),
    );
    expect(outcome, isA<GoalSpecRevisionMinted>());
    final consumed = upserts.whereType<ScheduledWakeEntity>().toList();
    expect(consumed, hasLength(1));
    expect(consumed.single.workspaceKey, 'goal-escalation:2026-08-10');
    expect(consumed.single.status, ScheduledWakeStatus.consumed);
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
      startsWith('$agentId:spec-v5-'),
    );
    expect(outcome.version.version, 5);
  });

  test('reads happen INSIDE the transaction, and successor ids carry a '
      'collision-proof suffix', () async {
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
    final outcome = await txnService.reviseFromProposal(
      agentId: agentId,
      changes: {'targetValue': 8000},
      rationale: 'r',
    );
    expect(outcome, isA<GoalSpecRevisionMinted>());
    expect(
      order.first,
      'transaction',
      reason: 'the head read must be serialized by the transaction',
    );
    // Successor ids carry a random suffix: two disconnected replicas
    // minting the same version NUMBER can never collide on the row id,
    // so neither user-approved revision is swallowed by LWW.
    expect(
      (outcome as GoalSpecRevisionMinted).version.id,
      startsWith('$agentId:spec-v2-'),
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
    when(
      () => repository.getEntity(
        any(that: startsWith('$agentId:spec-v2')),
      ),
    ).thenAnswer(
      (invocation) async => upserts
          .whereType<GoalSpecVersionEntity>()
          .where((v) => v.id == invocation.positionalArguments.first)
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
      startsWith('$agentId:spec-v2-'),
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
