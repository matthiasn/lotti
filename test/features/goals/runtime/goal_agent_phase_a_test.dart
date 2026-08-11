import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_reader.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/runtime/goal_agent_phase_a.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

class _FakeSignalReader extends GoalSignalReader {
  _FakeSignalReader(this.window) : super(journalDb: MockJournalDb());

  final GoalSignalWindow window;

  @override
  Future<GoalSignalWindow> read({
    required GoalCriterion criteria,
    required DateTime reference,
    int shortTermDays = 3,
  }) async => window;
}

void main() {
  setUpAll(registerAllFallbackValues);

  // Saturday 2026-08-08, 14:30 local.
  final now = DateTime(2026, 8, 8, 14, 30);
  final fixedClock = Clock.fixed(now);
  const agentId = 'goal-agent-1';

  const criteria = GoalCriterion.metric(
    criterionId: 'steps',
    dataType: 'cumulative_step_count',
    window: GoalWindow.rollingDays(count: 7),
    aggregation: GoalAggregation.dailySumThenAverage,
    target: 10000,
  );

  final identity =
      AgentDomainEntity.agent(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.goalAgent,
            displayName: 'Daily steps',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: '$agentId:state',
            config: const AgentConfig(),
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            vectorClock: null,
          )
          as AgentIdentityEntity;

  final specVersion = AgentDomainEntity.goalSpecVersion(
    id: '$agentId:spec-v1',
    agentId: agentId,
    version: 1,
    status: GoalSpecVersionStatus.active,
    authoredBy: 'user',
    title: 'Daily steps',
    statement: 'Average 10,000 steps a day.',
    criteria: criteria,
    createdAt: DateTime(2026),
    vectorClock: null,
  );

  final specHead = AgentDomainEntity.goalSpecHead(
    id: goalSpecHeadId(agentId),
    agentId: agentId,
    versionId: '$agentId:spec-v1',
    updatedAt: DateTime(2026),
    vectorClock: null,
  );

  GoalSignalWindow onTrackSignals() => GoalSignalWindow(
    quantitativeDailySums: {
      'cumulative_step_count': {
        for (var day = 2; day <= 8; day++) DateTime.utc(2026, 8, day): 11000,
      },
    },
  );

  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late List<AgentDomainEntity> upserts;

  GoalAgentPhaseA phaseA(GoalSignalWindow signals) => GoalAgentPhaseA(
    repository: repository,
    syncService: syncService,
    signalReader: _FakeSignalReader(signals),
  );

  setUp(() {
    repository = MockAgentRepository();
    syncService = MockAgentSyncService();
    upserts = [];
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
    when(
      () => repository.getEntitiesByAgentId(
        any(),
        type: any(named: 'type'),
      ),
    ).thenAnswer((_) async => []);
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
  });

  void stubSpec() {
    when(
      () => repository.getEntity(goalSpecHeadId(agentId)),
    ).thenAnswer((_) async => specHead);
    when(
      () => repository.getEntity('$agentId:spec-v1'),
    ).thenAnswer((_) async => specVersion);
  }

  Future<WakeResult> run(GoalSignalWindow signals) => withClock(
    fixedClock,
    () => phaseA(signals).execute(
      agentIdentity: identity,
      runKey: 'run-1',
      triggerTokens: const {'cumulative_step_count'},
      threadId: 'thread-1',
    ),
  );

  GoalNudgeEntity staleNudge() =>
      AgentDomainEntity.goalNudge(
            id: 'ad-overdue',
            agentId: agentId,
            status: GoalNudgeStatus.active,
            brief: const GoalNudgeBrief(
              headline: 'Old copy',
              tone: GoalNudgeTone.nudge,
              animation: GoalBannerAnimation.steady,
            ),
            briefDigest: 'old-copy',
            createdAt: DateTime(2026, 8, 5),
            updatedAt: DateTime(2026, 8, 5),
            vectorClock: null,
            staleAt: DateTime(2026, 8, 7, 9),
          )
          as GoalNudgeEntity;

  GoalProgressEntity progressRow({
    required String periodKey,
    required GoalTrackStatus status,
    required double attainment,
  }) =>
      AgentDomainEntity.goalProgress(
            id: goalProgressId(agentId, periodKey),
            agentId: agentId,
            periodKey: periodKey,
            trackStatus: status,
            attainment: attainment,
            dataCoverage: 1,
            satisfied: status == GoalTrackStatus.onTrack,
            specVersionId: '$agentId:spec-v1',
            createdAt: DateTime.parse('${periodKey}T06:00:00'),
            updatedAt: DateTime.parse('${periodKey}T06:00:00'),
            vectorClock: null,
          )
          as GoalProgressEntity;

  test('an active ad past its staleAt is expired by the wake — the '
      "clock's verdict lands on the row, stamped with the deadline", () async {
    stubSpec();
    GoalNudgeEntity nudgeRow(String id, {DateTime? staleAt}) =>
        AgentDomainEntity.goalNudge(
              id: id,
              agentId: agentId,
              status: GoalNudgeStatus.active,
              brief: const GoalNudgeBrief(
                headline: 'h',
                tone: GoalNudgeTone.nudge,
                animation: GoalBannerAnimation.steady,
              ),
              briefDigest: 'd-$id',
              createdAt: DateTime(2026, 8, 5),
              updatedAt: DateTime(2026, 8, 5),
              vectorClock: null,
              staleAt: staleAt,
            )
            as GoalNudgeEntity;
    final deadline = DateTime(2026, 8, 7, 9);
    when(
      () => repository.getEntitiesByAgentId(agentId, type: 'goalNudge'),
    ).thenAnswer(
      (_) async => [
        nudgeRow('ad-overdue', staleAt: deadline),
        nudgeRow('ad-fresh', staleAt: DateTime(2026, 8, 20)),
        nudgeRow('ad-open-ended'),
      ],
    );

    await run(onTrackSignals());

    final expired = upserts.whereType<GoalNudgeEntity>().toList();
    expect(expired, hasLength(1));
    expect(expired.single.id, 'ad-overdue');
    expect(expired.single.status, GoalNudgeStatus.expired);
    expect(
      expired.single.expiredAt,
      deadline.toUtc(),
      reason:
          'the deadline itself, not this device wall clock — '
          'every sweeping device writes the identical verdict',
    );
  });

  test('an expired banner re-arms Phase B when an unchanged off-track goal '
      'still qualifies for automatic copy', () async {
    stubSpec();
    when(
      () => repository.getEntitiesByAgentId(agentId, type: 'goalNudge'),
    ).thenAnswer((_) async => [staleNudge()]);
    when(
      () => repository.getEntity(goalProgressId(agentId, '2026-08-08')),
    ).thenAnswer(
      (_) async => progressRow(
        periodKey: '2026-08-08',
        status: GoalTrackStatus.offTrack,
        attainment: 0.6,
      ),
    );
    when(
      () => repository.getEntity(goalProgressId(agentId, '2026-08-07')),
    ).thenAnswer(
      (_) async => progressRow(
        periodKey: '2026-08-07',
        status: GoalTrackStatus.offTrack,
        attainment: 0.6,
      ),
    );
    final badWeek = GoalSignalWindow(
      quantitativeDailySums: {
        'cumulative_step_count': {
          for (var day = 2; day <= 8; day++) DateTime.utc(2026, 8, day): 6000,
        },
      },
    );

    await run(badWeek);

    expect(
      upserts.whereType<GoalNudgeEntity>().single.status,
      GoalNudgeStatus.expired,
    );
    expect(
      upserts.whereType<ScheduledWakeEntity>().where(
        (wake) => isGoalEscalationWorkspace(wake.workspaceKey),
      ),
      hasLength(1),
      reason: 'Phase B must now create or reuse the replacement banner',
    );
  });

  test('an expired banner stays a €0 maintenance event when unchanged '
      'health no longer permits automatic copy', () async {
    stubSpec();
    when(
      () => repository.getEntitiesByAgentId(agentId, type: 'goalNudge'),
    ).thenAnswer((_) async => [staleNudge()]);
    when(
      () => repository.getEntity(goalProgressId(agentId, '2026-08-08')),
    ).thenAnswer(
      (_) async => progressRow(
        periodKey: '2026-08-08',
        status: GoalTrackStatus.onTrack,
        attainment: 1,
      ),
    );

    await run(onTrackSignals());

    expect(
      upserts.whereType<GoalNudgeEntity>().single.status,
      GoalNudgeStatus.expired,
    );
    expect(
      upserts.whereType<ScheduledWakeEntity>().where(
        (wake) => isGoalEscalationWorkspace(wake.workspaceKey),
      ),
      isEmpty,
    );
  });

  test('a revision landing mid-wake fences the register AND the '
      'escalation — no v1 row overwrites the day under v2', () async {
    stubSpec();
    // First head read (wake start) serves v1; the in-transaction
    // re-read sees the revision's v2.
    var headReads = 0;
    when(() => repository.getEntity(goalSpecHeadId(agentId))).thenAnswer((
      _,
    ) async {
      headReads++;
      return AgentDomainEntity.goalSpecHead(
        id: goalSpecHeadId(agentId),
        agentId: agentId,
        versionId: headReads == 1 ? '$agentId:spec-v1' : '$agentId:spec-v2',
        updatedAt: DateTime(2026),
        vectorClock: null,
      );
    });

    final result = await run(onTrackSignals());
    expect(result.success, isTrue);
    expect(
      upserts.whereType<GoalProgressEntity>(),
      isEmpty,
      reason: 'the fenced transaction must write neither register…',
    );
    expect(
      upserts.whereType<ScheduledWakeEntity>().where(
        (w) => w.workspaceKey?.startsWith('goal-escalation') ?? false,
      ),
      isEmpty,
      reason: '…nor escalation (the spec-agnostic cadence re-arm may stay)',
    );
  });

  test('a late-synced banner from a superseded spec is swept to '
      'superseded on the next wake — but only when its origin version is '
      'PRESENT and terminal', () async {
    stubSpec();
    when(() => repository.getEntity('$agentId:spec-v0')).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecVersion(
        id: '$agentId:spec-v0',
        agentId: agentId,
        version: 0,
        status: GoalSpecVersionStatus.superseded,
        authoredBy: 'user',
        title: 'Old',
        statement: 'x',
        criteria: const GoalCriterion.metric(
          criterionId: 'steps',
          dataType: 'cumulative_step_count',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 9000,
        ),
        createdAt: DateTime(2026, 7),
        vectorClock: null,
      ),
    );
    when(
      () => repository.getEntitiesByAgentId(agentId, type: 'goalNudge'),
    ).thenAnswer(
      (_) async => [
        AgentDomainEntity.goalNudge(
              id: 'ad-foreign-spec',
              agentId: agentId,
              status: GoalNudgeStatus.active,
              brief: const GoalNudgeBrief(
                headline: 'h',
                tone: GoalNudgeTone.nudge,
                animation: GoalBannerAnimation.steady,
              ),
              briefDigest: 'd',
              createdAt: DateTime(2026, 8, 5),
              updatedAt: DateTime(2026, 8, 5),
              vectorClock: null,
              provenance: const {'specVersionId': '$agentId:spec-v0'},
            )
            as GoalNudgeEntity,
      ],
    );

    await run(onTrackSignals());

    final swept = upserts.whereType<GoalNudgeEntity>().single;
    expect(swept.id, 'ad-foreign-spec');
    expect(swept.status, GoalNudgeStatus.superseded);

    // Partial sync: a NEW spec's banner arriving before that spec's head
    // (origin version unresolvable) is left alone, not destroyed.
    upserts.clear();
    when(
      () => repository.getEntity('$agentId:spec-v0'),
    ).thenAnswer((_) async => null);
    await run(onTrackSignals());
    expect(upserts.whereType<GoalNudgeEntity>(), isEmpty);
  });

  test('a goal without a spec head is a clean no-op', () async {
    final result = await run(onTrackSignals());
    expect(result.success, isTrue);
    expect(upserts, isEmpty);
  });

  test('a dangling head is a failed wake, not a silent one', () async {
    when(
      () => repository.getEntity(goalSpecHeadId(agentId)),
    ).thenAnswer((_) async => specHead);
    final result = await run(onTrackSignals());
    expect(result.success, isFalse);
    expect(result.error, contains('spec-v1'));
  });

  test(
    'a tick evaluates, re-arms the cadence, and writes the register',
    () async {
      stubSpec();
      final result = await run(onTrackSignals());
      expect(result.success, isTrue);

      final cadence = upserts.whereType<ScheduledWakeEntity>().singleWhere(
        (w) => w.workspaceKey == goalCadenceWorkspaceKey,
      );
      // 14:30 is past today's 06:00 tick → tomorrow 06:00.
      expect(cadence.scheduledAt, DateTime(2026, 8, 9, goalCadenceHour));
      expect(cadence.status, ScheduledWakeStatus.pending);

      final register = upserts.whereType<GoalProgressEntity>().single;
      expect(register.id, goalProgressId(agentId, '2026-08-08'));
      expect(register.periodKey, '2026-08-08');
      expect(register.trackStatus, GoalTrackStatus.onTrack);
      expect(register.attainment, 1.0);
      expect(register.satisfied, isTrue);
      expect(register.specVersionId, '$agentId:spec-v1');
      expect(register.criterionResults.single.criterionId, 'steps');
    },
  );

  test(
    'the first-ever evaluation escalates (a new fact where none was)',
    () async {
      stubSpec();
      await run(onTrackSignals());
      expect(
        upserts.whereType<ScheduledWakeEntity>().where(
          (w) => isGoalEscalationWorkspace(w.workspaceKey),
        ),
        hasLength(1),
      );
    },
  );

  test('an unchanged status is the €0 no-op: no escalation armed', () async {
    stubSpec();
    when(
      () => repository.getEntity(goalProgressId(agentId, '2026-08-07')),
    ).thenAnswer(
      (_) async => AgentDomainEntity.goalProgress(
        id: goalProgressId(agentId, '2026-08-07'),
        agentId: agentId,
        periodKey: '2026-08-07',
        trackStatus: GoalTrackStatus.onTrack,
        attainment: 1,
        dataCoverage: 1,
        satisfied: true,
        specVersionId: '$agentId:spec-v1',
        createdAt: DateTime(2026, 8, 7),
        updatedAt: DateTime(2026, 8, 7),
        vectorClock: null,
      ),
    );
    await run(onTrackSignals());
    expect(
      upserts.whereType<ScheduledWakeEntity>().where(
        (w) => isGoalEscalationWorkspace(w.workspaceKey),
      ),
      isEmpty,
    );
  });

  test('prior bad register rows feed the grace check into offTrack', () async {
    stubSpec();
    when(
      () => repository.getEntity(goalProgressId(agentId, '2026-08-07')),
    ).thenAnswer(
      (_) async => AgentDomainEntity.goalProgress(
        id: goalProgressId(agentId, '2026-08-07'),
        agentId: agentId,
        periodKey: '2026-08-07',
        trackStatus: GoalTrackStatus.atRisk,
        attainment: 0.62,
        dataCoverage: 1,
        satisfied: false,
        specVersionId: '$agentId:spec-v1',
        createdAt: DateTime(2026, 8, 7),
        updatedAt: DateTime(2026, 8, 7),
        vectorClock: null,
      ),
    );
    final badWeek = GoalSignalWindow(
      quantitativeDailySums: {
        'cumulative_step_count': {
          for (var day = 2; day <= 8; day++) DateTime.utc(2026, 8, day): 6000,
        },
      },
    );
    await run(badWeek);
    final register = upserts.whereType<GoalProgressEntity>().single;
    // 0.6 attainment with a bad prior period → grace exhausted.
    expect(register.trackStatus, GoalTrackStatus.offTrack);
  });

  test(
    'a passed target date resolves to achieved for a satisfied goal',
    () async {
      when(
        () => repository.getEntity(goalSpecHeadId(agentId)),
      ).thenAnswer((_) async => specHead);
      when(() => repository.getEntity('$agentId:spec-v1')).thenAnswer(
        (_) async => AgentDomainEntity.goalSpecVersion(
          id: '$agentId:spec-v1',
          agentId: agentId,
          version: 1,
          status: GoalSpecVersionStatus.active,
          authoredBy: 'user',
          title: 'Daily steps',
          statement: 'Average 10,000 steps a day.',
          criteria: criteria,
          createdAt: DateTime(2026),
          vectorClock: null,
          targetDate: DateTime(2026, 8),
        ),
      );
      await run(onTrackSignals());
      final register = upserts.whereType<GoalProgressEntity>().single;
      expect(register.trackStatus, GoalTrackStatus.achieved);
    },
  );

  test('re-running the SAME day with an unchanged status is a no-op — the '
      'escalation wake cannot re-arm itself forever', () async {
    stubSpec();
    when(
      () => repository.getEntity(goalProgressId(agentId, '2026-08-08')),
    ).thenAnswer(
      (_) async => AgentDomainEntity.goalProgress(
        id: goalProgressId(agentId, '2026-08-08'),
        agentId: agentId,
        periodKey: '2026-08-08',
        trackStatus: GoalTrackStatus.onTrack,
        attainment: 1,
        dataCoverage: 1,
        satisfied: true,
        specVersionId: '$agentId:spec-v1',
        createdAt: DateTime(2026, 8, 8, 6),
        updatedAt: DateTime(2026, 8, 8, 6),
        vectorClock: null,
      ),
    );
    // No yesterday row at all: without the today-row comparison this
    // would look like a first evaluation and escalate again.
    await run(onTrackSignals());
    expect(
      upserts.whereType<ScheduledWakeEntity>().where(
        (w) => isGoalEscalationWorkspace(w.workspaceKey),
      ),
      isEmpty,
    );
  });

  test('escalation wakes are period-scoped, lease-recognizable, and carry '
      'a UTC deadline', () async {
    stubSpec();
    await run(onTrackSignals());
    final escalation = upserts.whereType<ScheduledWakeEntity>().singleWhere(
      (w) => isGoalEscalationWorkspace(w.workspaceKey),
    );
    expect(escalation.workspaceKey, 'goal-escalation:2026-08-08');
    expect(escalation.scheduledAt.isUtc, isTrue);
    // Period-derived, never wall-clock: every device arming this logical
    // escalation must write the IDENTICAL deadline, or the concurrent
    // resolver's later-deadline preference resurrects consumed wakes.
    expect(escalation.scheduledAt, DateTime.utc(2026, 8, 8));
    // The wake-runner signature has no workspaceKey, so the router keys
    // Phase B entry on this token (the day agent's digest: precedent).
    // First-ever evaluation: no baseline token (nothing preceded it).
    expect(escalation.triggerTokens, ['goal-escalation:2026-08-08']);
  });

  test(
    'a transition escalation encodes the PRE-transition status as a '
    'baseline token — the register write hides it from re-derivation',
    () async {
      stubSpec();
      when(
        () => repository.getEntity(goalProgressId(agentId, '2026-08-07')),
      ).thenAnswer(
        (_) async => AgentDomainEntity.goalProgress(
          id: goalProgressId(agentId, '2026-08-07'),
          agentId: agentId,
          periodKey: '2026-08-07',
          trackStatus: GoalTrackStatus.atRisk,
          attainment: 0.62,
          dataCoverage: 1,
          satisfied: false,
          specVersionId: '$agentId:spec-v1',
          createdAt: DateTime(2026, 8, 7),
          updatedAt: DateTime(2026, 8, 7),
          vectorClock: null,
        ),
      );
      await run(onTrackSignals());
      final escalation = upserts.whereType<ScheduledWakeEntity>().singleWhere(
        (w) => isGoalEscalationWorkspace(w.workspaceKey),
      );
      expect(escalation.triggerTokens, contains('goal-baseline:atRisk'));
    },
  );

  test(
    'the register and its escalation land in ONE transaction — a '
    'transition acknowledged without escalation would be permanent',
    () async {
      stubSpec();
      final order = <String>[];
      final txnSyncService = _OrderRecordingSyncService(order);
      when(() => txnSyncService.upsertEntity(any())).thenAnswer(
        (invocation) async {
          final entity =
              invocation.positionalArguments.first as AgentDomainEntity;
          if (entity is GoalProgressEntity) order.add('register');
          if (entity is ScheduledWakeEntity &&
              isGoalEscalationWorkspace(entity.workspaceKey)) {
            order.add('escalation');
          }
        },
      );
      final atomic = GoalAgentPhaseA(
        repository: repository,
        syncService: txnSyncService,
        signalReader: _FakeSignalReader(onTrackSignals()),
      );
      await withClock(
        fixedClock,
        () => atomic.execute(
          agentIdentity: identity,
          runKey: 'run-1',
          triggerTokens: const {},
          threadId: 'thread-1',
        ),
      );
      expect(
        order,
        // The first transaction is the (empty) staleness sweep; the
        // register and its escalation share the SECOND.
        ['transaction', 'transaction', 'register', 'escalation'],
        reason: 'both writes must happen inside the same transaction',
      );
    },
  );

  test('the escalation callback nudges the wake manager exactly when an '
      'escalation is armed', () async {
    stubSpec();
    var nudges = 0;
    final nudging = GoalAgentPhaseA(
      repository: repository,
      syncService: syncService,
      signalReader: _FakeSignalReader(onTrackSignals()),
      onEscalationArmed: () => nudges++,
    );
    await withClock(
      fixedClock,
      () => nudging.execute(
        agentIdentity: identity,
        runKey: 'run-1',
        triggerTokens: const {},
        threadId: 'thread-1',
      ),
    );
    expect(nudges, 1);
  });

  test('a gap in the register history breaks the grace streak', () async {
    stubSpec();
    // Two days ago was bad, but YESTERDAY is missing: the old bad day
    // must not compact forward into "the immediately preceding period".
    when(
      () => repository.getEntity(goalProgressId(agentId, '2026-08-06')),
    ).thenAnswer(
      (_) async => AgentDomainEntity.goalProgress(
        id: goalProgressId(agentId, '2026-08-06'),
        agentId: agentId,
        periodKey: '2026-08-06',
        trackStatus: GoalTrackStatus.atRisk,
        attainment: 0.5,
        dataCoverage: 1,
        satisfied: false,
        specVersionId: '$agentId:spec-v1',
        createdAt: DateTime(2026, 8, 6),
        updatedAt: DateTime(2026, 8, 6),
        vectorClock: null,
      ),
    );
    final badWeek = GoalSignalWindow(
      quantitativeDailySums: {
        'cumulative_step_count': {
          for (var day = 2; day <= 8; day++) DateTime.utc(2026, 8, day): 6000,
        },
      },
    );
    await run(badWeek);
    final register = upserts.whereType<GoalProgressEntity>().single;
    // First bad period as far as the CONSECUTIVE streak knows → grace.
    expect(register.trackStatus, GoalTrackStatus.atRisk);
  });

  test('rows from a superseded spec version do not exhaust grace', () async {
    stubSpec();
    when(
      () => repository.getEntity(goalProgressId(agentId, '2026-08-07')),
    ).thenAnswer(
      (_) async => AgentDomainEntity.goalProgress(
        id: goalProgressId(agentId, '2026-08-07'),
        agentId: agentId,
        periodKey: '2026-08-07',
        trackStatus: GoalTrackStatus.offTrack,
        attainment: 0.3,
        dataCoverage: 1,
        satisfied: false,
        specVersionId: '$agentId:spec-v0-old',
        createdAt: DateTime(2026, 8, 7),
        updatedAt: DateTime(2026, 8, 7),
        vectorClock: null,
      ),
    );
    final badWeek = GoalSignalWindow(
      quantitativeDailySums: {
        'cumulative_step_count': {
          for (var day = 2; day <= 8; day++) DateTime.utc(2026, 8, day): 6000,
        },
      },
    );
    await run(badWeek);
    final register = upserts.whereType<GoalProgressEntity>().single;
    // A revised goal starts its grace history fresh.
    expect(register.trackStatus, GoalTrackStatus.atRisk);
  });

  test(
    'a goal that has not started yet writes nothing but keeps ticking',
    () async {
      when(
        () => repository.getEntity(goalSpecHeadId(agentId)),
      ).thenAnswer((_) async => specHead);
      when(() => repository.getEntity('$agentId:spec-v1')).thenAnswer(
        (_) async => AgentDomainEntity.goalSpecVersion(
          id: '$agentId:spec-v1',
          agentId: agentId,
          version: 1,
          status: GoalSpecVersionStatus.active,
          authoredBy: 'user',
          title: 'Daily steps',
          statement: 'Average 10,000 steps a day.',
          criteria: criteria,
          createdAt: DateTime(2026),
          vectorClock: null,
          startDate: DateTime(2026, 9),
        ),
      );
      final result = await run(onTrackSignals());
      expect(result.success, isTrue);
      expect(upserts.whereType<GoalProgressEntity>(), isEmpty);
      // The cadence tick still re-arms, so the start day is not missed.
      expect(
        upserts.whereType<ScheduledWakeEntity>().where(
          (w) => w.workspaceKey == goalCadenceWorkspaceKey,
        ),
        hasLength(1),
      );
    },
  );

  test('recomputing over a synced register carries its vector clock', () async {
    stubSpec();
    const peerClock = VectorClock({'peer-host': 7});
    when(
      () => repository.getEntity(goalProgressId(agentId, '2026-08-08')),
    ).thenAnswer(
      (_) async => AgentDomainEntity.goalProgress(
        id: goalProgressId(agentId, '2026-08-08'),
        agentId: agentId,
        periodKey: '2026-08-08',
        trackStatus: GoalTrackStatus.onTrack,
        attainment: 1,
        dataCoverage: 1,
        satisfied: true,
        specVersionId: '$agentId:spec-v1',
        createdAt: DateTime(2026, 8, 8, 6),
        updatedAt: DateTime(2026, 8, 8, 6),
        vectorClock: peerClock,
      ),
    );
    await run(onTrackSignals());
    final register = upserts.whereType<GoalProgressEntity>().single;
    // Dropping it would make this write causally concurrent with the row
    // it is based on, letting wall-clock LWW revert fresh progress.
    expect(register.vectorClock, peerClock);
  });

  test('re-running the same day preserves the register createdAt', () async {
    stubSpec();
    final created = DateTime(2026, 8, 8, 6);
    when(
      () => repository.getEntity(goalProgressId(agentId, '2026-08-08')),
    ).thenAnswer(
      (_) async => AgentDomainEntity.goalProgress(
        id: goalProgressId(agentId, '2026-08-08'),
        agentId: agentId,
        periodKey: '2026-08-08',
        trackStatus: GoalTrackStatus.onTrack,
        attainment: 1,
        dataCoverage: 1,
        satisfied: true,
        specVersionId: '$agentId:spec-v1',
        createdAt: created,
        updatedAt: created,
        vectorClock: null,
      ),
    );
    await run(onTrackSignals());
    final register = upserts.whereType<GoalProgressEntity>().single;
    expect(register.createdAt, created);
    expect(register.updatedAt, now);
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
