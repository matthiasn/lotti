import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/goals/service/goal_spec_revision_service.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/pages/create_goal_agent_page.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

class _MockGoalSpecRevisionService extends Mock
    implements GoalSpecRevisionService {}

HabitDefinition _habit(String id, String name) => HabitDefinition(
  id: id,
  name: name,
  description: '',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
  vectorClock: null,
  active: true,
  private: false,
  version: '1',
);

GoalSpecVersionEntity _spec({
  int version = 3,
  GoalCriterion criteria = const GoalCriterion.allOf(
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
  ),
}) =>
    AgentDomainEntity.goalSpecVersion(
          id: 'goal-1:spec-v$version',
          agentId: 'goal-1',
          version: version,
          status: GoalSpecVersionStatus.active,
          authoredBy: 'user',
          title: 'Weekly movement',
          statement: 'Gym and run every week',
          criteria: criteria,
          createdAt: DateTime(2026, 8, 11),
          vectorClock: null,
        )
        as GoalSpecVersionEntity;

final _identity =
    AgentDomainEntity.agent(
          id: 'goal-1',
          agentId: 'goal-1',
          kind: AgentKinds.goalAgent,
          displayName: 'Juno',
          lifecycle: AgentLifecycle.active,
          mode: AgentInteractionMode.autonomous,
          allowedCategoryIds: const {},
          currentStateId: 'goal-1:state',
          config: const AgentConfig(),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          vectorClock: null,
        )
        as AgentIdentityEntity;

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(
      const GoalCriterion.allOf(criterionId: 'fallback', criteria: []),
    );
  });

  late MockGoalAgentService agentService;
  late MockHabitsRepository habitsRepository;
  late _MockGoalSpecRevisionService revisionService;

  List<Override> overrides({GoalSpecVersionEntity? editSpec}) => [
    goalAgentServiceProvider.overrideWithValue(agentService),
    goalSpecRevisionServiceProvider.overrideWithValue(revisionService),
    habitsRepositoryProvider.overrideWithValue(habitsRepository),
    if (editSpec != null) ...[
      agentIdentityProvider(
        'goal-1',
      ).overrideWith((ref) async => _identity),
      goalAgentHealthProvider('goal-1').overrideWith(
        (ref) async => (
          trackStatus: GoalTrackStatus.atRisk,
          attainment: 0.5,
          reportOneLiner: null,
          pendingProposals: 0,
          spec: editSpec,
          direction: GoalHealthDirection.flat,
          deficit: null,
          buffer: null,
        ),
      ),
    ],
  ];

  setUp(() {
    agentService = MockGoalAgentService();
    habitsRepository = MockHabitsRepository();
    revisionService = _MockGoalSpecRevisionService();
    when(habitsRepository.watchHabitDefinitions).thenAnswer(
      (_) => Stream.value([_habit('gym', 'Gym'), _habit('run', 'Run')]),
    );
  });

  testWidgets('requires a speakable intention before mapping', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.text('Describe what you want to work toward first.'),
      findsOneWidget,
    );
    expect(find.text('What do you want to work toward?'), findsOneWidget);
    verifyNever(
      () => agentService.createGoalAgent(
        title: any(named: 'title'),
        displayName: any(named: 'displayName'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    );
  });

  testWidgets('maps habits and creates independent rolling-week targets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    GoalCriterion? capturedCriteria;
    String? capturedDisplayName;
    when(
      () => agentService.createGoalAgent(
        title: any(named: 'title'),
        displayName: any(named: 'displayName'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    ).thenAnswer((invocation) async {
      capturedCriteria = invocation.namedArguments[#criteria] as GoalCriterion;
      capturedDisplayName = invocation.namedArguments[#displayName] as String;
      throw StateError('stop before navigation');
    });

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Gym and Run every week',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Here’s what I can watch'), findsOneWidget);
    expect(find.text('3× / 7 days', skipOffstage: false), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('goal-form-decrease-gym')));
    await tester.tap(find.byKey(const ValueKey('goal-form-increase-run')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-form-increase-run')));
    await tester.pumpAndSettle();
    expect(find.text('2× / 7 days', skipOffstage: false), findsOneWidget);
    expect(find.text('5× / 7 days', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Looks right'));
    await tester.pumpAndSettle();
    expect(find.text('Meet your agent'), findsOneWidget);
    expect(
      find.textContaining('Gym (2× a week) · Run (5× a week)'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-persona')),
      'Mika',
    );
    await tester.tap(find.text('Create agent'));
    await tester.pumpAndSettle();

    expect(capturedDisplayName, 'Mika');
    final composite = capturedCriteria! as GoalCriterionAllOf;
    expect(
      {
        for (final habit in composite.criteria.whereType<GoalCriterionHabit>())
          habit.habitId: habit.targetCount,
      },
      {'gym': 2, 'run': 5},
    );
    expect(
      composite.criteria.whereType<GoalCriterionHabit>().every(
        (habit) => habit.window == const GoalWindow.rollingDays(count: 7),
      ),
      isTrue,
    );
  });

  testWidgets('refuses an unobservable intention and offers real signals', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Be more patient with people',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('I can’t see this intention'),
      findsOneWidget,
    );
    expect(
      find.textContaining('I’d be guessing'),
      findsOneWidget,
    );
    await tester.tap(find.text('Choose an existing habit'));
    await tester.pumpAndSettle();
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('Run'), findsOneWidget);
  });

  testWidgets('editing loads distinct targets and mints the next version', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final current = _spec();
    final revised = _spec(version: 4);
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);
    when(
      () => revisionService.reviseFromOwner(
        agentId: 'goal-1',
        displayName: any(named: 'displayName'),
        title: any(named: 'title'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    ).thenAnswer(
      (_) async => GoalSpecRevisionMinted(
        version: revised,
        changeSummaries: const ['persona name updated'],
      ),
    );
    when(
      () => agentService.refreshAfterRevision(
        agentId: 'goal-1',
        criteria: any(named: 'criteria'),
      ),
    ).thenReturn(null);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(agentId: 'goal-1'),
        overrides: overrides(editSpec: current),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gym and run every week'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('2× / 7 days', skipOffstage: false), findsOneWidget);
    expect(find.text('5× / 7 days', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Looks right'));
    await tester.pumpAndSettle();
    expect(
      find.text('This starts version 4. Your history is kept.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-persona')),
      'Mika',
    );
    await tester.tap(find.text('Save new version'));
    await tester.pump();

    final captured = verify(
      () => revisionService.reviseFromOwner(
        agentId: 'goal-1',
        displayName: captureAny(named: 'displayName'),
        title: 'Weekly movement',
        statement: 'Gym and run every week',
        criteria: captureAny(named: 'criteria'),
      ),
    ).captured;
    expect(captured.first, 'Mika');
    final criteria = captured.last as GoalCriterionAllOf;
    expect(
      {
        for (final habit in criteria.criteria.whereType<GoalCriterionHabit>())
          habit.habitId: habit.targetCount,
      },
      {'gym': 2, 'run': 5},
    );
    verify(
      () => agentService.refreshAfterRevision(
        agentId: 'goal-1',
        criteria: revised.criteria,
      ),
    ).called(1);
    expect(navigated, contains('/agents/details/goal-1'));
  });
}
