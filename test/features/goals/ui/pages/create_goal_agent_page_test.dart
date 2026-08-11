import 'dart:async';

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
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
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

HabitDefinition _habit(
  String id,
  String name, {
  bool active = true,
  bool private = false,
  DateTime? deletedAt,
}) => HabitDefinition(
  id: id,
  name: name,
  description: '',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
  vectorClock: null,
  active: active,
  private: private,
  deletedAt: deletedAt,
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

  List<Override> overrides({
    GoalSpecVersionEntity? editSpec,
    bool identityFails = false,
    bool healthFails = false,
    bool identityMissing = false,
    bool healthMissing = false,
    AgentLifecycle identityLifecycle = AgentLifecycle.active,
  }) => [
    goalAgentServiceProvider.overrideWithValue(agentService),
    goalSpecRevisionServiceProvider.overrideWithValue(revisionService),
    habitsRepositoryProvider.overrideWithValue(habitsRepository),
    if (editSpec != null ||
        identityFails ||
        healthFails ||
        identityMissing ||
        healthMissing) ...[
      agentIdentityProvider(
        'goal-1',
      ).overrideWith((ref) async {
        if (identityFails) throw StateError('identity unavailable');
        if (identityMissing) return null;
        return _identity.copyWith(lifecycle: identityLifecycle);
      }),
      goalAgentHealthProvider('goal-1').overrideWith(
        (ref) async {
          if (healthFails) throw StateError('health unavailable');
          return (
            trackStatus: GoalTrackStatus.atRisk,
            attainment: 0.5,
            reportOneLiner: null,
            pendingProposals: 0,
            spec: healthMissing ? null : editSpec,
            direction: GoalHealthDirection.flat,
            deficit: null,
            buffer: null,
          );
        },
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
    when(
      () => habitsRepository.getHabitByIdForIntegrity(any()),
    ).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.single as String;
      return _habit(id, id, private: true);
    });
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

  testWidgets('an example fills the intention and back returns one step', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('gym twice a week'));
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .controller
          .text,
      'gym twice a week',
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Here’s what I can watch'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('What do you want to work toward?'), findsOneWidget);
    expect(find.text('gym twice a week'), findsNWidgets(2));
  });

  testWidgets(
    'back exits from intention and system back returns from mapping',
    (
      tester,
    ) async {
      final navigated = <String>[];
      beamToNamedOverride = navigated.add;
      addTearDown(() => beamToNamedOverride = null);
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const CreateGoalAgentPage(),
          overrides: overrides(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BackButton));
      expect(navigated, ['/agents']);

      await tester.enterText(
        find.byKey(const ValueKey('goal-form-intention')),
        'Gym every week',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Here’s what I can watch'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('What do you want to work toward?'), findsOneWidget);
    },
  );

  testWidgets('a matched steps signal can be removed before confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Average steps per day',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Average steps per day').first);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('goal-form-steps-target')),
      findsNothing,
    );
    expect(find.textContaining('I can’t see this intention'), findsOneWidget);
  });

  testWidgets('a removed steps signal can be selected again', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Average steps per day',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('goal-form-steps-row')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('goal-form-steps-target')),
      findsNothing,
    );

    await tester.tap(find.text('Choose an existing habit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-form-steps-row')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('goal-form-steps-target')),
      findsOneWidget,
    );
    final stepsField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('goal-form-steps-target')),
        matching: find.byType(TextField),
      ),
    );
    expect(stepsField.keyboardType, TextInputType.number);
    expect(find.text('automatic step count'), findsOneWidget);
  });

  testWidgets('a steps goal validates and restates its daily target', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Average steps per day',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('goal-form-steps-target')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('goal-form-steps-target')),
      '',
    );
    await tester.tap(find.text('Looks right'));
    await tester.pump();
    expect(
      find.text('Choose at least one signal the agent can actually observe.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('goal-form-steps-target')),
      '8000',
    );
    final stepsController = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .singleWhere((widget) => widget.controller.text == '8000')
        .controller;
    await tester.tap(find.text('Looks right'));
    await tester.pumpAndSettle();
    expect(find.text('Meet your agent'), findsOneWidget);
    expect(find.textContaining('8,000 steps a day'), findsOneWidget);
    final title = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('goal-form-title')),
        matching: find.byType(EditableText),
      ),
    );
    expect(title.controller.text, 'Daily steps (rolling week)');

    stepsController.clear();
    await tester.tap(find.text('Create agent'));
    await tester.pump();
    verifyNever(
      () => agentService.createGoalAgent(
        title: any(named: 'title'),
        displayName: any(named: 'displayName'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    );
  });

  testWidgets('successful creation returns to the agents list', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);
    when(
      () => agentService.createGoalAgent(
        title: any(named: 'title'),
        displayName: any(named: 'displayName'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    ).thenAnswer((_) async => _identity);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Gym every week',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Looks right'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create agent'));
    await tester.pump();

    verify(
      () => agentService.createGoalAgent(
        title: 'Gym',
        displayName: 'Juno',
        statement: 'Gym every week',
        criteria: any(named: 'criteria'),
      ),
    ).called(1);
    expect(navigated, ['/agents']);
  });

  testWidgets('confirmation requires both goal and persona names', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Gym every week',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Looks right'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('goal-form-persona')),
      '',
    );
    await tester.enterText(find.byKey(const ValueKey('goal-form-title')), '');
    await tester.tap(find.text('Create agent'));
    await tester.pump();

    expect(
      find.text('Give the goal and its agent a name.'),
      findsOneWidget,
    );
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

  testWidgets('back preserves manually selected signals and targets when the '
      'intention is unchanged', (tester) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Gym every week',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose an existing habit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-form-habit-run')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-form-decrease-gym')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-form-increase-run')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-form-increase-run')));
    await tester.pump();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('2× / 7 days', skipOffstage: false), findsOneWidget);
    expect(find.text('5× / 7 days', skipOffstage: false), findsOneWidget);
    expect(
      tester
          .widget<DesignSystemSelectionRow>(
            find.byKey(const ValueKey('goal-form-habit-run')),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets('changing the intention refreshes an untouched derived title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Gym every week',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Run every week',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Looks right'));
    await tester.pumpAndSettle();

    final title = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('goal-form-title')),
        matching: find.byType(EditableText),
      ),
    );
    expect(title.controller.text, 'Run');
  });

  testWidgets('a pending habit snapshot is rematched after it resolves', (
    tester,
  ) async {
    final habits = StreamController<List<HabitDefinition>>();
    when(
      habitsRepository.watchHabitDefinitions,
    ).thenAnswer((_) => habits.stream);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Gym every week',
    );
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.byKey(const ValueKey('goal-form-habit-gym')), findsNothing);

    await tester.tap(find.byType(BackButton));
    habits.add([_habit('gym', 'Gym')]);
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(
      tester
          .widget<DesignSystemSelectionRow>(
            find.byKey(const ValueKey('goal-form-habit-gym')),
          )
          .selected,
      isTrue,
    );
    await habits.close();
    await tester.pump();
  });

  testWidgets('manual mapping survives while the habit snapshot is pending', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final habits = StreamController<List<HabitDefinition>>();
    when(
      habitsRepository.watchHabitDefinitions,
    ).thenAnswer((_) => habits.stream);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Build a consistent routine',
    );
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('Choose an existing habit'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-form-steps-row')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('goal-form-steps-target')),
      findsOneWidget,
    );

    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('goal-form-steps-target')),
      findsOneWidget,
    );
    await habits.close();
    await tester.pump();
  });

  testWidgets('habit labels do not match inside unrelated words', (
    tester,
  ) async {
    when(habitsRepository.watchHabitDefinitions).thenAnswer(
      (_) => Stream.value([_habit('read', 'Read'), _habit('run', 'Run')]),
    );
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'I already walk daily and eat brunch mindfully',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose an existing habit'));
    await tester.pumpAndSettle();

    for (final habitId in ['read', 'run']) {
      expect(
        tester
            .widget<DesignSystemSelectionRow>(
              find.byKey(ValueKey('goal-form-habit-$habitId')),
            )
            .selected,
        isFalse,
      );
    }
  });

  testWidgets('generic cadence words do not select an unrelated habit', (
    tester,
  ) async {
    when(habitsRepository.watchHabitDefinitions).thenAnswer(
      (_) => Stream.value([
        _habit('meditate', 'Meditate daily'),
        _habit('walk', 'Walk'),
      ]),
    );
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Walk daily',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose an existing habit'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<DesignSystemSelectionRow>(
            find.byKey(const ValueKey('goal-form-habit-meditate')),
          )
          .selected,
      isFalse,
    );
    expect(
      tester
          .widget<DesignSystemSelectionRow>(
            find.byKey(const ValueKey('goal-form-habit-walk')),
          )
          .selected,
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

    await tester.tap(find.byKey(const ValueKey('goal-form-habit-gym')));
    await tester.pump();
    expect(find.text('3× / 7 days', skipOffstage: false), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('goal-form-habit-gym')));
    await tester.pump();
    expect(find.text('3× / 7 days', skipOffstage: false), findsNothing);
  });

  testWidgets('an empty habit source links to habit setup', (tester) async {
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);
    when(
      habitsRepository.watchHabitDefinitions,
    ).thenAnswer((_) => Stream.value([]));
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Be more patient',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose an existing habit'));
    await tester.pumpAndSettle();

    expect(find.text('No active habits are available yet.'), findsOneWidget);
    await tester.tap(find.text('Create a habit first'));
    expect(navigated, ['/habits']);
  });

  testWidgets('a failed habit source explains that the list is unavailable', (
    tester,
  ) async {
    when(habitsRepository.watchHabitDefinitions).thenAnswer(
      (_) => Stream<List<HabitDefinition>>.error(StateError('offline')),
    );
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Be more patient',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose an existing habit'));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't load your habits right now — try again in a moment."),
      findsOneWidget,
    );
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
        baseVersionId: any(named: 'baseVersionId'),
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
        baseVersionId: current.id,
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

  for (final failure in ['identity', 'health']) {
    testWidgets('editing blocks the form when $failure fails to load', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const CreateGoalAgentPage(agentId: 'goal-1'),
          overrides: overrides(
            editSpec: _spec(),
            identityFails: failure == 'identity',
            healthFails: failure == 'health',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't load this goal's health right now."),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('goal-form-intention')),
        findsNothing,
      );
      expect(find.text('Save new version'), findsNothing);
    });
  }

  for (final missingPart in ['identity', 'health']) {
    testWidgets('editing stops loading when the goal $missingPart is missing', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const CreateGoalAgentPage(agentId: 'goal-1'),
          overrides: overrides(
            identityMissing: missingPart == 'identity',
            healthMissing: missingPart == 'health',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't load this goal's health right now."),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  }

  for (final lifecycle in [AgentLifecycle.dormant, AgentLifecycle.destroyed]) {
    testWidgets('editing blocks a ${lifecycle.name} goal', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const CreateGoalAgentPage(agentId: 'goal-1'),
          overrides: overrides(
            editSpec: _spec(),
            identityLifecycle: lifecycle,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't load this goal's health right now."),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('goal-form-intention')),
        findsNothing,
      );
    });
  }

  testWidgets(
    'editing preserves loaded habits while the active-habit stream is pending',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final habits = StreamController<List<HabitDefinition>>();
      when(
        habitsRepository.watchHabitDefinitions,
      ).thenAnswer((_) => habits.stream);
      const criteria = GoalCriterion.allOf(
        criterionId: 'routine',
        criteria: [
          GoalCriterion.habit(
            criterionId: 'habit-gym',
            habitId: 'gym',
            window: GoalWindow.rollingDays(count: 7),
            targetCount: 2,
          ),
          GoalCriterion.metric(
            criterionId: 'steps',
            dataType: 'cumulative_step_count',
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.dailySumThenAverage,
            target: 9000,
          ),
        ],
      );
      final current = _spec(criteria: criteria);
      when(
        () => revisionService.reviseFromOwner(
          agentId: 'goal-1',
          baseVersionId: current.id,
          displayName: any(named: 'displayName'),
          title: any(named: 'title'),
          statement: any(named: 'statement'),
          criteria: any(named: 'criteria'),
        ),
      ).thenAnswer(
        (_) async => const GoalSpecRevisionRefused(
          'the owner edit does not change the goal',
        ),
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const CreateGoalAgentPage(agentId: 'goal-1'),
          overrides: overrides(editSpec: current),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.tap(find.text('Looks right'));
      await tester.pump();
      await tester.tap(find.text('Save new version'));
      await tester.pump();

      verify(
        () => revisionService.reviseFromOwner(
          agentId: 'goal-1',
          baseVersionId: current.id,
          displayName: 'Juno',
          title: 'Weekly movement',
          statement: 'Gym and run every week',
          criteria: criteria,
        ),
      ).called(1);
      verify(() => habitsRepository.getHabitByIdForIntegrity('gym')).called(1);
      await habits.close();
      await tester.pump();
    },
  );

  testWidgets('editing preserves a habit omitted from the visible snapshot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const hiddenCriteria = GoalCriterion.habit(
      criterionId: 'habit-private',
      habitId: 'private-habit',
      window: GoalWindow.rollingDays(count: 7),
      targetCount: 4,
    );
    final current = _spec(criteria: hiddenCriteria);
    when(
      () => revisionService.reviseFromOwner(
        agentId: 'goal-1',
        baseVersionId: current.id,
        displayName: 'Mika',
        title: current.title,
        statement: current.statement,
        criteria: any(named: 'criteria'),
      ),
    ).thenAnswer(
      (_) async => const GoalSpecRevisionRefused(
        GoalSpecRevisionService.ownerNoChangesReason,
      ),
    );

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(agentId: 'goal-1'),
        overrides: overrides(editSpec: current),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Looks right'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-persona')),
      'Mika',
    );
    await tester.tap(find.text('Save new version'));
    await tester.pump();

    final criteria = verify(
      () => revisionService.reviseFromOwner(
        agentId: 'goal-1',
        baseVersionId: current.id,
        displayName: 'Mika',
        title: current.title,
        statement: current.statement,
        criteria: captureAny(named: 'criteria'),
      ),
    ).captured.single;
    expect(criteria, hiddenCriteria);
    verify(
      () => habitsRepository.getHabitByIdForIntegrity('private-habit'),
    ).called(1);
  });

  testWidgets('editing drops a hidden habit confirmed inactive before save', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const criteria = GoalCriterion.allOf(
      criterionId: 'routine',
      criteria: [
        GoalCriterion.habit(
          criterionId: 'habit-private',
          habitId: 'private-habit',
          window: GoalWindow.rollingDays(count: 7),
          targetCount: 4,
        ),
        GoalCriterion.habit(
          criterionId: 'habit-gym',
          habitId: 'gym',
          window: GoalWindow.rollingDays(count: 7),
          targetCount: 2,
        ),
      ],
    );
    final current = _spec(criteria: criteria);
    when(
      () => habitsRepository.getHabitByIdForIntegrity('private-habit'),
    ).thenAnswer(
      (_) async => _habit(
        'private-habit',
        'Private habit',
        active: false,
        private: true,
      ),
    );
    when(
      () => revisionService.reviseFromOwner(
        agentId: 'goal-1',
        baseVersionId: current.id,
        displayName: any(named: 'displayName'),
        title: any(named: 'title'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    ).thenAnswer(
      (_) async => const GoalSpecRevisionRefused(
        GoalSpecRevisionService.ownerNoChangesReason,
      ),
    );

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(agentId: 'goal-1'),
        overrides: overrides(editSpec: current),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Looks right'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-title')),
      'Updated movement',
    );
    await tester.tap(find.text('Save new version'));
    await tester.pump();

    final saved = verify(
      () => revisionService.reviseFromOwner(
        agentId: 'goal-1',
        baseVersionId: current.id,
        displayName: 'Juno',
        title: 'Updated movement',
        statement: current.statement,
        criteria: captureAny(named: 'criteria'),
      ),
    ).captured.single;
    final savedHabits = (saved as GoalCriterionAllOf).criteria
        .whereType<GoalCriterionHabit>()
        .toList();
    expect(savedHabits, hasLength(1));
    expect(savedHabits.single.habitId, 'gym');
  });

  testWidgets(
    'editing drops a visible habit that became inactive before save',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const criteria = GoalCriterion.habit(
        criterionId: 'habit-gym',
        habitId: 'gym',
        window: GoalWindow.rollingDays(count: 7),
        targetCount: 2,
      );
      final current = _spec(criteria: criteria);
      when(
        () => habitsRepository.getHabitByIdForIntegrity('gym'),
      ).thenAnswer((_) async => _habit('gym', 'Gym', active: false));

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const CreateGoalAgentPage(agentId: 'goal-1'),
          overrides: overrides(editSpec: current),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Looks right'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save new version'));
      await tester.pump();

      expect(
        find.text('Choose at least one signal the agent can actually observe.'),
        findsOneWidget,
      );
      verify(() => habitsRepository.getHabitByIdForIntegrity('gym')).called(1);
      verifyNever(
        () => revisionService.reviseFromOwner(
          agentId: any(named: 'agentId'),
          baseVersionId: any(named: 'baseVersionId'),
          displayName: any(named: 'displayName'),
          title: any(named: 'title'),
          statement: any(named: 'statement'),
          criteria: any(named: 'criteria'),
        ),
      );
    },
  );

  testWidgets('an integrity lookup failure keeps the edit open and unsaved', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const hiddenCriteria = GoalCriterion.habit(
      criterionId: 'habit-private',
      habitId: 'private-habit',
      window: GoalWindow.rollingDays(count: 7),
      targetCount: 4,
    );
    final current = _spec(criteria: hiddenCriteria);
    when(
      () => habitsRepository.getHabitByIdForIntegrity('private-habit'),
    ).thenThrow(StateError('database unavailable'));

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(agentId: 'goal-1'),
        overrides: overrides(editSpec: current),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Looks right'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save new version'));
    await tester.pump();

    expect(
      find.text('Saving the goal failed — please try again.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('goal-form-title')),
      findsOneWidget,
    );
    verifyNever(
      () => revisionService.reviseFromOwner(
        agentId: any(named: 'agentId'),
        baseVersionId: any(named: 'baseVersionId'),
        displayName: any(named: 'displayName'),
        title: any(named: 'title'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    );
  });

  testWidgets('a disposed edit abandons a pending integrity lookup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const hiddenCriteria = GoalCriterion.habit(
      criterionId: 'habit-private',
      habitId: 'private-habit',
      window: GoalWindow.rollingDays(count: 7),
      targetCount: 4,
    );
    final integrityLookup = Completer<HabitDefinition?>();
    when(
      () => habitsRepository.getHabitByIdForIntegrity('private-habit'),
    ).thenAnswer((_) => integrityLookup.future);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(agentId: 'goal-1'),
        overrides: overrides(editSpec: _spec(criteria: hiddenCriteria)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Looks right'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save new version'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    integrityLookup.complete(_habit('private-habit', 'Private habit'));
    await tester.pump();

    verifyNever(
      () => revisionService.reviseFromOwner(
        agentId: any(named: 'agentId'),
        baseVersionId: any(named: 'baseVersionId'),
        displayName: any(named: 'displayName'),
        title: any(named: 'title'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    );
  });

  testWidgets('an integrity lookup makes the edit busy and deduplicates save', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const criteria = GoalCriterion.habit(
      criterionId: 'habit-gym',
      habitId: 'gym',
      window: GoalWindow.rollingDays(count: 7),
      targetCount: 2,
    );
    final current = _spec(criteria: criteria);
    final integrityLookup = Completer<HabitDefinition?>();
    when(
      () => habitsRepository.getHabitByIdForIntegrity('gym'),
    ).thenAnswer((_) => integrityLookup.future);
    when(
      () => revisionService.reviseFromOwner(
        agentId: 'goal-1',
        baseVersionId: current.id,
        displayName: any(named: 'displayName'),
        title: any(named: 'title'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    ).thenAnswer(
      (_) async => const GoalSpecRevisionRefused(
        GoalSpecRevisionService.ownerNoChangesReason,
      ),
    );

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(agentId: 'goal-1'),
        overrides: overrides(editSpec: current),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Looks right'));
    await tester.pumpAndSettle();

    final saveLabel = find.text('Save new version');
    await tester.tap(saveLabel);
    await tester.tap(saveLabel);
    await tester.pump();

    TextField inputInside(String key) => tester.widget<TextField>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(TextField),
      ),
    );
    expect(inputInside('goal-form-persona').enabled, isFalse);
    expect(inputInside('goal-form-title').enabled, isFalse);
    verify(() => habitsRepository.getHabitByIdForIntegrity('gym')).called(1);

    integrityLookup.complete(_habit('gym', 'Gym'));
    await tester.pump();
    await tester.pump();

    verify(
      () => revisionService.reviseFromOwner(
        agentId: 'goal-1',
        baseVersionId: current.id,
        displayName: any(named: 'displayName'),
        title: any(named: 'title'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    ).called(1);
  });

  testWidgets('editing preserves an unsupported mapping while renaming', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const unsupported = GoalCriterion.habit(
      criterionId: 'habit-gym',
      habitId: 'gym',
      window: GoalWindow.calendarWeek(),
      targetCount: 4,
    );
    final current = _spec(criteria: unsupported);
    when(
      () => revisionService.reviseFromOwner(
        agentId: 'goal-1',
        baseVersionId: any(named: 'baseVersionId'),
        displayName: any(named: 'displayName'),
        title: any(named: 'title'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    ).thenAnswer(
      (_) async => const GoalSpecRevisionRefused(
        'the owner edit does not change the goal',
      ),
    );
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(agentId: 'goal-1'),
        overrides: overrides(editSpec: current),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('uses a mapping this editor can’t safely rewrite'),
      findsOneWidget,
    );
    await tester.tap(find.text('Looks right'));
    await tester.pumpAndSettle();
    expect(
      find.text('The existing signals and schedule will be preserved exactly.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Save new version'));
    await tester.pump();

    final criteria = verify(
      () => revisionService.reviseFromOwner(
        agentId: 'goal-1',
        baseVersionId: current.id,
        displayName: 'Juno',
        title: 'Weekly movement',
        statement: 'Gym and run every week',
        criteria: captureAny(named: 'criteria'),
      ),
    ).captured.single;
    expect(criteria, unsupported);
    verifyNever(
      () => agentService.refreshAfterRevision(
        agentId: any(named: 'agentId'),
        criteria: any(named: 'criteria'),
      ),
    );
    expect(navigated, ['/agents/details/goal-1']);
  });

  testWidgets('a habit removed while confirming is not saved as a criterion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final habits = StreamController<List<HabitDefinition>>.broadcast();
    when(
      habitsRepository.watchHabitDefinitions,
    ).thenAnswer((_) => habits.stream);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    habits.add([_habit('gym', 'Gym')]);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Gym every week',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Looks right'));
    await tester.pumpAndSettle();

    habits.add([]);
    await tester.pump();
    await tester.tap(find.text('Create agent'));
    await tester.pump();

    expect(
      find.text('Choose at least one signal the agent can actually observe.'),
      findsOneWidget,
    );
    verifyNever(
      () => agentService.createGoalAgent(
        title: any(named: 'title'),
        displayName: any(named: 'displayName'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await habits.close();
  });

  testWidgets(
    'a committed edit refreshes runtime after the route is disposed',
    (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final revision = Completer<GoalSpecRevisionOutcome>();
      final revised = _spec(version: 4);
      when(
        () => revisionService.reviseFromOwner(
          agentId: 'goal-1',
          baseVersionId: any(named: 'baseVersionId'),
          displayName: any(named: 'displayName'),
          title: any(named: 'title'),
          statement: any(named: 'statement'),
          criteria: any(named: 'criteria'),
        ),
      ).thenAnswer((_) => revision.future);
      when(
        () => agentService.refreshAfterRevision(
          agentId: 'goal-1',
          criteria: any(named: 'criteria'),
        ),
      ).thenReturn(null);

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const CreateGoalAgentPage(agentId: 'goal-1'),
          overrides: overrides(editSpec: _spec()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Looks right'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('goal-form-title')),
        'Updated movement',
      );
      await tester.tap(find.text('Save new version'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());

      revision.complete(
        GoalSpecRevisionMinted(version: revised, changeSummaries: const []),
      );
      await tester.pump();

      verify(
        () => agentService.refreshAfterRevision(
          agentId: 'goal-1',
          criteria: revised.criteria,
        ),
      ).called(1);
    },
  );

  testWidgets('an edit refusal remains on the form with a saving error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(
      () => revisionService.reviseFromOwner(
        agentId: 'goal-1',
        baseVersionId: any(named: 'baseVersionId'),
        displayName: any(named: 'displayName'),
        title: any(named: 'title'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    ).thenAnswer((_) async => const GoalSpecRevisionRefused('locked'));

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(agentId: 'goal-1'),
        overrides: overrides(editSpec: _spec()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Looks right'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-title')),
      'New name',
    );
    await tester.tap(find.text('Save new version'));
    await tester.pump();

    expect(
      find.text('Saving the goal failed — please try again.'),
      findsOneWidget,
    );
    verifyNever(
      () => agentService.refreshAfterRevision(
        agentId: any(named: 'agentId'),
        criteria: any(named: 'criteria'),
      ),
    );
  });

  testWidgets('a stale edit returns to the refreshed goal details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);
    when(
      () => revisionService.reviseFromOwner(
        agentId: 'goal-1',
        baseVersionId: any(named: 'baseVersionId'),
        displayName: any(named: 'displayName'),
        title: any(named: 'title'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    ).thenAnswer(
      (_) async => const GoalSpecRevisionRefused(
        GoalSpecRevisionService.ownerStaleVersionReason,
      ),
    );

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(agentId: 'goal-1'),
        overrides: overrides(editSpec: _spec()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Looks right'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-title')),
      'New name',
    );
    await tester.tap(find.text('Save new version'));
    await tester.pump();

    expect(navigated, ['/agents/details/goal-1']);
    expect(
      find.text('Saving the goal failed — please try again.'),
      findsNothing,
    );
  });

  testWidgets('a successful edit refreshes mounted proposal cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var pendingReads = 0;
    final current = _spec();
    final revised = _spec(version: 4);
    when(
      () => revisionService.reviseFromOwner(
        agentId: 'goal-1',
        baseVersionId: current.id,
        displayName: any(named: 'displayName'),
        title: any(named: 'title'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    ).thenAnswer(
      (_) async => GoalSpecRevisionMinted(
        version: revised,
        changeSummaries: const ['goal name updated'],
      ),
    );
    when(
      () => agentService.refreshAfterRevision(
        agentId: 'goal-1',
        criteria: any(named: 'criteria'),
      ),
    ).thenReturn(null);
    final harness = makeTestableWidgetWithContainer(
      const CreateGoalAgentPage(agentId: 'goal-1'),
      overrides: [
        ...overrides(editSpec: current),
        selfTargetedPendingChangeSetsProvider('goal-1').overrideWith((ref) {
          pendingReads++;
          return Future.value([]);
        }),
      ],
    );
    addTearDown(harness.container.dispose);
    final subscription = harness.container.listen(
      selfTargetedPendingChangeSetsProvider('goal-1'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    expect(pendingReads, 1);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Looks right'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-title')),
      'Updated movement',
    );
    await tester.tap(find.text('Save new version'));
    await tester.pumpAndSettle();

    expect(pendingReads, 2);
  });
}
