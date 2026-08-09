import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
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
  });

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
