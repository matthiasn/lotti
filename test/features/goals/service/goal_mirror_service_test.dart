import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_data.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/goals/service/goal_mirror_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  final testDate = DateTime.utc(2026, 8, 18, 10, 30);

  const criteria = GoalCriterion.habit(
    criterionId: 'walk-daily',
    habitId: 'habit-walk',
    targetCount: 5,
    window: GoalWindow.rollingDays(count: 7),
  );

  late MockGoalRepository goals;
  late MockAgentRepository agents;
  late MockAgentSyncService sync;
  late GoalMirrorService service;

  GoalSpecVersionEntity version({int number = 1, String? id}) =>
      AgentDomainEntity.goalSpecVersion(
            id: id ?? 'agent-1:spec-v$number',
            agentId: 'agent-1',
            version: number,
            status: GoalSpecVersionStatus.active,
            authoredBy: 'user',
            title: 'Walk more',
            statement: 'Walk on five days a week.',
            criteria: criteria,
            createdAt: testDate,
            vectorClock: null,
          )
          as GoalSpecVersionEntity;

  Metadata meta(String id) => Metadata(
    id: id,
    createdAt: testDate,
    updatedAt: testDate,
    dateFrom: testDate,
    dateTo: testDate,
  );

  GoalEntry entry(String id, {String? snapshotOf}) => GoalEntry(
    meta: meta(id),
    data: GoalData(
      title: 'Walk more',
      statement: 'Walk on five days a week.',
      criteria: criteria,
      specVersion: 1,
      specVersionId: 'snap-1',
      snapshotOf: snapshotOf,
    ),
  );

  setUpAll(() {
    registerFallbackValue(criteria);
    registerFallbackValue(
      AgentLink.basic(
        id: 'fallback',
        fromId: 'a',
        toId: 'b',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        vectorClock: null,
      ),
    );
  });

  setUp(() {
    goals = MockGoalRepository();
    agents = MockAgentRepository();
    sync = MockAgentSyncService();
    service = GoalMirrorService(
      goalRepository: goals,
      agentRepository: agents,
      syncService: sync,
    );

    when(() => goals.goalIdForAgent('agent-1')).thenReturn('goal-1');
    when(() => sync.upsertLink(any())).thenAnswer((_) async {});
    when(
      () => agents.getLinksFrom(any(), type: any(named: 'type')),
    ).thenAnswer((_) async => []);
  });

  void stubWrites({GoalEntry? snapshot, GoalEntry? goal}) {
    when(
      () => goals.ensureSpecSnapshot(
        goalId: any(named: 'goalId'),
        specVersionId: any(named: 'specVersionId'),
        title: any(named: 'title'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
        specVersion: any(named: 'specVersion'),
        createdAt: any(named: 'createdAt'),
        startDate: any(named: 'startDate'),
        targetDate: any(named: 'targetDate'),
        rationale: any(named: 'rationale'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => snapshot);
    when(
      () => goals.upsertGoal(
        agentId: any(named: 'agentId'),
        title: any(named: 'title'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
        specVersion: any(named: 'specVersion'),
        specVersionId: any(named: 'specVersionId'),
        startDate: any(named: 'startDate'),
        targetDate: any(named: 'targetDate'),
        rationale: any(named: 'rationale'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => goal);
  }

  group('mirrorSpec', () {
    test('writes the snapshot before the goal that points at it', () async {
      stubWrites(
        snapshot: entry('snap-1', snapshotOf: 'goal-1'),
        goal: entry('goal-1'),
      );

      await withClock(
        Clock.fixed(testDate),
        () => service.mirrorSpec(version: version()),
      );

      // Order matters: the goal's specVersionId names the snapshot row, so
      // writing the goal first would briefly point at nothing.
      verifyInOrder([
        () => goals.ensureSpecSnapshot(
          goalId: 'goal-1',
          specVersionId: 'agent-1:spec-v1',
          title: any(named: 'title'),
          statement: any(named: 'statement'),
          criteria: any(named: 'criteria'),
          specVersion: 1,
          createdAt: any(named: 'createdAt'),
          startDate: any(named: 'startDate'),
          targetDate: any(named: 'targetDate'),
          rationale: any(named: 'rationale'),
          categoryId: any(named: 'categoryId'),
        ),
        () => goals.upsertGoal(
          agentId: 'agent-1',
          title: any(named: 'title'),
          statement: any(named: 'statement'),
          criteria: any(named: 'criteria'),
          specVersion: 1,
          specVersionId: 'snap-1',
          startDate: any(named: 'startDate'),
          targetDate: any(named: 'targetDate'),
          rationale: any(named: 'rationale'),
          categoryId: any(named: 'categoryId'),
        ),
      ]);
    });

    test('binds the agent to the goal it wrote', () async {
      stubWrites(snapshot: entry('snap-1'), goal: entry('goal-1'));

      await withClock(
        Clock.fixed(testDate),
        () => service.mirrorSpec(version: version()),
      );

      final link =
          verify(() => sync.upsertLink(captureAny())).captured.single
              as AgentLink;
      expect(link, isA<AgentGoalLink>());
      // Agent → goal: the disposable side points at the durable one.
      expect(link.fromId, 'agent-1');
      expect(link.toId, 'goal-1');
      // Derived, not minted. `agent_links` is unique on (from_id, to_id,
      // type) while upsertLink resolves conflicts by id alone, so two devices
      // that backfilled independently would otherwise hold two ids for the
      // same natural key and fail the constraint forever on sync.
      expect(link.id, agentGoalLinkId(agentId: 'agent-1', goalId: 'goal-1'));
    });

    test('two devices derive the same link id for the same pair', () {
      expect(
        agentGoalLinkId(agentId: 'agent-1', goalId: 'goal-1'),
        agentGoalLinkId(agentId: 'agent-1', goalId: 'goal-1'),
      );
      expect(
        agentGoalLinkId(agentId: 'agent-1', goalId: 'goal-2'),
        isNot(agentGoalLinkId(agentId: 'agent-1', goalId: 'goal-1')),
      );
      expect(
        agentGoalLinkId(agentId: 'agent-2', goalId: 'goal-1'),
        isNot(agentGoalLinkId(agentId: 'agent-1', goalId: 'goal-1')),
      );
    });

    test('does not write a second link when one already exists', () async {
      stubWrites(snapshot: entry('snap-1'), goal: entry('goal-1'));
      when(
        () => agents.getLinksFrom('agent-1', type: AgentLinkTypes.agentGoal),
      ).thenAnswer(
        (_) async => [
          AgentLink.agentGoal(
            id: 'existing',
            fromId: 'agent-1',
            toId: 'goal-1',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          ),
        ],
      );

      await withClock(
        Clock.fixed(testDate),
        () => service.mirrorSpec(version: version()),
      );

      // The backfill runs on every launch; re-linking each time would grow an
      // unbounded pile of identical links.
      verifyNever(() => sync.upsertLink(any()));
    });

    test('a soft-deleted link is replaced rather than left broken', () async {
      stubWrites(snapshot: entry('snap-1'), goal: entry('goal-1'));
      when(
        () => agents.getLinksFrom('agent-1', type: AgentLinkTypes.agentGoal),
      ).thenAnswer(
        (_) async => [
          AgentLink.agentGoal(
            id: 'dead',
            fromId: 'agent-1',
            toId: 'goal-1',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
            deletedAt: testDate,
          ),
        ],
      );

      await withClock(
        Clock.fixed(testDate),
        () => service.mirrorSpec(version: version()),
      );

      verify(() => sync.upsertLink(any())).called(1);
    });

    test(
      'falls back to the agent-side id when no snapshot was written',
      () async {
        stubWrites(goal: entry('goal-1'));

        await withClock(
          Clock.fixed(testDate),
          () => service.mirrorSpec(version: version()),
        );

        // Never leave specVersionId dangling: a goal that names nothing is worse
        // than one naming the version it came from.
        verify(
          () => goals.upsertGoal(
            agentId: 'agent-1',
            title: any(named: 'title'),
            statement: any(named: 'statement'),
            criteria: any(named: 'criteria'),
            specVersion: 1,
            specVersionId: 'agent-1:spec-v1',
            startDate: any(named: 'startDate'),
            targetDate: any(named: 'targetDate'),
            rationale: any(named: 'rationale'),
            categoryId: any(named: 'categoryId'),
          ),
        ).called(1);
      },
    );

    test('a failed write is absorbed, not thrown at the caller', () async {
      // Goal creation must not fail because its journal mirror could not be
      // written; the next launch's backfill repairs it.
      when(
        () => goals.ensureSpecSnapshot(
          goalId: any(named: 'goalId'),
          specVersionId: any(named: 'specVersionId'),
          title: any(named: 'title'),
          statement: any(named: 'statement'),
          criteria: any(named: 'criteria'),
          specVersion: any(named: 'specVersion'),
          createdAt: any(named: 'createdAt'),
          startDate: any(named: 'startDate'),
          targetDate: any(named: 'targetDate'),
          rationale: any(named: 'rationale'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenThrow(Exception('db is gone'));

      expect(await service.mirrorSpec(version: version()), isNull);
    });
  });

  group('mirrorHead', () {
    test('resolves the head and mirrors the version it points at', () async {
      stubWrites(snapshot: entry('snap-1'), goal: entry('goal-1'));
      when(
        () => agents.getEntity(goalSpecHeadId('agent-1')),
      ).thenAnswer(
        (_) async =>
            AgentDomainEntity.goalSpecHead(
                  id: goalSpecHeadId('agent-1'),
                  agentId: 'agent-1',
                  versionId: 'agent-1:spec-v3',
                  updatedAt: testDate,
                  vectorClock: null,
                )
                as GoalSpecHeadEntity,
      );
      when(
        () => agents.getEntity('agent-1:spec-v3'),
      ).thenAnswer((_) async => version(number: 3, id: 'agent-1:spec-v3'));

      final result = await withClock(
        Clock.fixed(testDate),
        () => service.mirrorHead('agent-1'),
      );

      expect(result, isNotNull);
      verify(
        () => goals.ensureSpecSnapshot(
          goalId: 'goal-1',
          specVersionId: 'agent-1:spec-v3',
          title: any(named: 'title'),
          statement: any(named: 'statement'),
          criteria: any(named: 'criteria'),
          specVersion: 3,
          createdAt: any(named: 'createdAt'),
          startDate: any(named: 'startDate'),
          targetDate: any(named: 'targetDate'),
          rationale: any(named: 'rationale'),
          categoryId: any(named: 'categoryId'),
        ),
      ).called(1);
    });

    test('a repository explosion is contained and logged', () async {
      // The backfill runs on every launch; an unreadable agent store must not
      // take the launch down, and the failure must be visible in the log
      // rather than swallowed silently.
      final logger = MockDomainLogger();
      final logging = GoalMirrorService(
        goalRepository: goals,
        agentRepository: agents,
        syncService: sync,
        domainLogger: logger,
      );
      when(() => agents.getEntity(any())).thenThrow(Exception('db is gone'));

      expect(await logging.mirrorHead('agent-1'), isNull);
      verify(
        () => logger.error(
          any(),
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
          message: any(named: 'message'),
        ),
      ).called(1);
    });

    test('an agent with no head writes nothing', () async {
      when(() => agents.getEntity(any())).thenAnswer((_) async => null);

      expect(await service.mirrorHead('agent-1'), isNull);
      verifyNever(() => sync.upsertLink(any()));
    });
  });
}
