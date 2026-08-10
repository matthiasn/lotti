import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/pages/create_goal_agent_page.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

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

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(
      const GoalCriterion.allOf(criterionId: 'f', criteria: []),
    );
  });

  late MockGoalAgentService service;
  late MockHabitsRepository habitsRepository;

  List<Override> overrides() => [
    goalAgentServiceProvider.overrideWithValue(service),
    habitsRepositoryProvider.overrideWithValue(habitsRepository),
  ];

  setUp(() {
    service = MockGoalAgentService();
    habitsRepository = MockHabitsRepository();
    when(habitsRepository.watchHabitDefinitions).thenAnswer(
      (_) => Stream.value([_habit('h-gym', 'Gym'), _habit('h-run', 'Run')]),
    );
  });

  testWidgets('an empty form validates instead of creating', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create agent'));
    await tester.pumpAndSettle();
    expect(
      find.text('Give the goal a name and at least one criterion.'),
      findsOneWidget,
    );
    verifyNever(
      () => service.createGoalAgent(
        title: any(named: 'title'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    );
  });

  testWidgets('a steps goal creates a rolling-week metric criterion', (
    tester,
  ) async {
    var captured = <dynamic>[];
    when(
      () => service.createGoalAgent(
        title: any(named: 'title'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    ).thenAnswer((invocation) async {
      captured = [
        invocation.namedArguments[#title],
        invocation.namedArguments[#criteria],
      ];
      throw StateError('stop before navigation');
    });

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Move more');
    await tester.tap(find.text('Create agent'));
    await tester.pumpAndSettle();

    expect(captured.first, 'Move more');
    final criteria = captured[1] as GoalCriterionMetric;
    expect(criteria.dataType, 'cumulative_step_count');
    expect(criteria.target, 10000);
  });

  testWidgets('picking two habits builds the allOf composite — the '
      'multi-habit goal', (tester) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    GoalCriterion? captured;
    when(
      () => service.createGoalAgent(
        title: any(named: 'title'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    ).thenAnswer((invocation) async {
      captured = invocation.namedArguments[#criteria] as GoalCriterion;
      throw StateError('stop before navigation');
    });

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Routine');
    await tester.tap(find.text('Habit routine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gym'));
    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create agent'));
    await tester.pumpAndSettle();

    final composite = captured! as GoalCriterionAllOf;
    expect(composite.criteria, hasLength(2));
    expect(
      composite.criteria.whereType<GoalCriterionHabit>().map((h) => h.habitId),
      containsAll(['h-gym', 'h-run']),
    );
    expect(
      composite.criteria.whereType<GoalCriterionHabit>().every(
        (h) => h.targetCount == 3,
      ),
      isTrue,
    );
  });

  testWidgets('one habit stays a single leaf; unchecking removes it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    GoalCriterion? captured;
    when(
      () => service.createGoalAgent(
        title: any(named: 'title'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    ).thenAnswer((invocation) async {
      captured = invocation.namedArguments[#criteria] as GoalCriterion;
      throw StateError('stop before navigation');
    });

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Routine');
    await tester.tap(find.text('Habit routine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gym'));
    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();
    // Change of heart: Run comes back out.
    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create agent'));
    await tester.pumpAndSettle();

    final leaf = captured! as GoalCriterionHabit;
    expect(leaf.habitId, 'h-gym');
  });

  testWidgets('a habit deactivated by sync after being ticked is pruned '
      'from the created goal', (tester) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final habitsController = StreamController<List<HabitDefinition>>();
    addTearDown(habitsController.close);
    when(
      habitsRepository.watchHabitDefinitions,
    ).thenAnswer((_) => habitsController.stream);
    GoalCriterion? captured;
    when(
      () => service.createGoalAgent(
        title: any(named: 'title'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    ).thenAnswer((invocation) async {
      captured = invocation.namedArguments[#criteria] as GoalCriterion;
      throw StateError('stop before navigation');
    });

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    habitsController.add([_habit('h-gym', 'Gym'), _habit('h-run', 'Run')]);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Routine');
    await tester.tap(find.text('Habit routine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gym'));
    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();

    // Sync pauses the Run habit while the form is still open.
    habitsController.add([_habit('h-gym', 'Gym')]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create agent'));
    await tester.pumpAndSettle();

    // The stale selection is reconciled: only the still-active habit
    // reaches the goal, as a single leaf rather than a composite.
    final leaf = captured! as GoalCriterionHabit;
    expect(leaf.habitId, 'h-gym');
  });

  testWidgets('a failed habit stream shows the load-failure notice instead '
      'of a silently empty picker', (tester) async {
    when(
      habitsRepository.watchHabitDefinitions,
    ).thenAnswer((_) => Stream.error(StateError('db unavailable')));

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Habit routine'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Couldn't load your habits right now — try again in a "
        'moment.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CheckboxListTile), findsNothing);
  });

  testWidgets('a completed system-back pop persists the Agents root '
      'through NavService', (tester) async {
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const SizedBox.shrink(),
        overrides: overrides(),
      ),
    );
    unawaited(
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => const CreateGoalAgentPage(),
            ),
          ),
    );
    await tester.pumpAndSettle();
    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pumpAndSettle();
    expect(navigated, ['/agents']);
  });

  testWidgets('a weekly count above seven is rejected with its own message '
      '— one success per day makes eight unsatisfiable', (tester) async {
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
    await tester.enterText(find.byType(TextField).first, 'Routine');
    await tester.tap(find.text('Habit routine'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '8');
    await tester.tap(find.text('Gym'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create agent'));
    await tester.pumpAndSettle();

    expect(
      find.text('The weekly count must be between 1 and 7.'),
      findsOneWidget,
    );
    verifyNever(
      () => service.createGoalAgent(
        title: any(named: 'title'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    );
  });
}
