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
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/service/goal_spec_revision_service.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/ui/pages/create_goal_agent_page.dart';
import 'package:lotti/features/goals/ui/pages/goal_form_mapping.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
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

CategoryDefinition _category(
  String id,
  String name, {
  bool active = true,
  bool private = false,
  DateTime? deletedAt,
}) => CategoryDefinition(
  id: id,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  name: name,
  vectorClock: null,
  private: private,
  active: active,
  deletedAt: deletedAt,
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
  late MockCategoryRepository categoryRepository;
  late _MockGoalSpecRevisionService revisionService;

  List<Override> overrides({
    GoalSpecVersionEntity? editSpec,
    bool identityFails = false,
    bool healthFails = false,
    bool identityMissing = false,
    bool healthMissing = false,
    AgentLifecycle identityLifecycle = AgentLifecycle.active,
    List<CategoryDefinition> categories = const [],
    Stream<List<CategoryDefinition>>? categoriesStream,
  }) => [
    goalAgentServiceProvider.overrideWithValue(agentService),
    goalSpecRevisionServiceProvider.overrideWithValue(revisionService),
    habitsRepositoryProvider.overrideWithValue(habitsRepository),
    categoryRepositoryProvider.overrideWithValue(categoryRepository),
    categoriesStreamProvider.overrideWith(
      (ref) => categoriesStream ?? Stream.value(categories),
    ),
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
    categoryRepository = MockCategoryRepository();
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
    when(
      categoryRepository.getAllCategoriesIncludingHidden,
    ).thenAnswer((_) async => [_category('deep-work', 'Deep work')]);
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
    // The example pills wrap to more lines since the health example landed
    // first; keep them above the fold.
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 3'), findsOneWidget);
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
    // The progress dots now carry a visible caption.
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsNothing);

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

    // With steps chosen and nothing else matched, there is nothing to
    // suggest — the caption only renders when suggestions exist.
    expect(find.text('Suggested'), findsNothing);

    await tester.tap(find.text('Average steps per day').first);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('goal-form-steps-target')),
      findsNothing,
    );
    // Stable order: the deselected steps row stays where it was — no
    // Suggested caption materialises mid-interaction.
    expect(find.text('Suggested'), findsNothing);
    expect(find.textContaining('I can’t see this intention'), findsOneWidget);

    // With nothing mapped at all, Continue falls back to the generic
    // mapping message rather than a per-target error.
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(
      find.text('Choose at least one signal the agent can actually observe.'),
      findsOneWidget,
    );
    expect(find.text('Meet your agent'), findsNothing);
  });

  testWidgets('steps are selectable without the intention naming them — no '
      'show-all detour required', (tester) async {
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
      // Deliberately no "steps" wording anywhere.
      'Walk more every day',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // The steps row is a first-class dimension, visible immediately.
    expect(find.byKey(const ValueKey('goal-form-steps-row')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('goal-form-steps-row')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('goal-form-steps-target')),
      findsOneWidget,
    );
  });

  testWidgets('the mapping step edits the goal title in place: the derived '
      'composite follows the selection until the user types their own', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(habitsRepository.watchHabitDefinitions).thenAnswer(
      (_) => Stream.value([_habit('gym', 'Gym'), _habit('run', 'Run')]),
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
      'Gym and run every week',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // The title edits on the mapping step, pre-filled with the derived
    // habit composite.
    final titleField = find.byKey(const ValueKey('goal-form-title-mapping'));
    expect(titleField, findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: titleField, matching: find.byType(TextField)),
          )
          .controller
          ?.text,
      'Gym & Run',
    );

    // Still form-owned: deselecting a habit refreshes the derived name.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('goal-form-habit-run')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // With everything the intention matched selected, nothing is suggested
    // yet except the steps offer.
    expect(find.text('Suggested'), findsOneWidget);

    // Tap the row title rather than the row center: a selected row's center
    // can coincide with the cadence stepper in the trailing slot.
    await tester.tap(find.text('Run'));
    await tester.pump();
    expect(
      tester
          .widget<DesignSystemSelectionRow>(
            find.byKey(const ValueKey('goal-form-habit-run')),
          )
          .selected,
      isFalse,
    );
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: titleField, matching: find.byType(TextField)),
          )
          .controller
          ?.text,
      'Gym',
    );

    // A user-authored title survives further selection changes. The
    // deselected matched habit's row stays visible in the mapping card.
    await tester.enterText(titleField, 'Stronger every week');
    await tester.tap(find.byKey(const ValueKey('goal-form-habit-run')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: titleField, matching: find.byType(TextField)),
          )
          .controller
          ?.text,
      'Stronger every week',
    );
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

    // Tap the row title: while selected, the keyed row also spans its
    // secondary-line target input, so the widget center is not the row.
    await tester.tap(find.text('Average steps per day').first);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('goal-form-steps-target')),
      findsNothing,
    );

    // The steps row stays visible after deselection — re-selecting it needs
    // no detour.
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
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    // The missing target errors on the steps input itself; the generic
    // message is reserved for a form with nothing mapped at all.
    expect(find.text('Set a target to continue.'), findsOneWidget);
    expect(
      find.text('Choose at least one signal the agent can actually observe.'),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const ValueKey('goal-form-steps-target')),
      '8000',
    );
    await tester.pump();
    // Typing a target clears the inline error immediately.
    expect(find.text('Set a target to continue.'), findsNothing);
    final stepsController = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .singleWhere((widget) => widget.controller.text == '8000')
        .controller;
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Meet your agent'), findsOneWidget);
    expect(find.textContaining('8,000 steps a day'), findsOneWidget);
    // The confirmation renders the derived title as a read-only summary row.
    expect(find.text('Daily steps (rolling week)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('goal-form-title-edit')),
      findsOneWidget,
    );

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
    await tester.tap(find.text('Continue'));
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

  testWidgets('selects category time and saves its rolling weekly hour cap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
        overrides: overrides(
          categories: [
            _category('deep-work', 'Deep work'),
            _category('archived', 'Archived category', active: false),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Spend less time working',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();

    expect(find.text('Tracked category time'), findsOneWidget);
    expect(find.text('Deep work'), findsOneWidget);
    expect(find.text('Archived category'), findsNothing);
    await tester.tap(find.text('Deep work'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
    await tester.pumpAndSettle();

    final target = find.byKey(
      const ValueKey('goal-form-category-time-target-deep-work'),
    );
    expect(target, findsOneWidget);
    // Picker selection seeds a 1-hour target instead of an empty value the
    // form would reject on Continue.
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: target, matching: find.byType(EditableText)),
          )
          .controller
          .text,
      '1',
    );
    await tester.enterText(target, '12');
    await tester.tap(
      find
          .descendant(
            of: find.byKey(
              const ValueKey('goal-form-category-time-direction-deep-work'),
            ),
            matching: find.text('At least'),
          )
          .last,
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Deep work: At least 12 hours per rolling 7 days',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Create agent'));
    await tester.pump();

    final saved = verify(
      () => agentService.createGoalAgent(
        title: 'Spend less time working',
        displayName: 'Juno',
        statement: 'Spend less time working',
        criteria: captureAny(named: 'criteria'),
      ),
    ).captured.single;
    expect(
      saved,
      const GoalCriterion.categoryTime(
        criterionId: 'category-time-deep-work',
        categoryId: 'deep-work',
        title: 'Deep work',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.sum,
        targetHours: 12,
        direction: GoalDirection.atLeast,
      ),
    );
  });

  testWidgets('matches category time from the intention with safe defaults', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(
          categories: [_category('deep-work', 'Deep work')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Deep work every week',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final target = find.byKey(
      const ValueKey('goal-form-category-time-target-deep-work'),
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: target,
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      '1',
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Deep work: No more than 1 hour per rolling 7 days',
      ),
      findsOneWidget,
    );
  });

  testWidgets('removed category time can be selected again', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(
          categories: [_category('deep-work', 'Deep work')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Track my week',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deep work'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
    await tester.pumpAndSettle();

    final card = find.byKey(
      const ValueKey('goal-form-category-time-card-deep-work'),
    );
    await tester.tap(
      find.descendant(of: card, matching: find.byIcon(Icons.close_rounded)),
    );
    await tester.pumpAndSettle();
    expect(card, findsNothing);

    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();
    expect(find.text('Deep work'), findsOneWidget);
    expect(
      tester
          .widget<DesignSystemSelectionRow>(
            find.byKey(
              const ValueKey('goal-form-category-time-source-deep-work'),
            ),
          )
          .selected,
      isFalse,
    );
  });

  testWidgets('retains an unavailable category by its stored identifier', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const criteria = GoalCriterion.categoryTime(
      criterionId: 'archived-hours',
      categoryId: 'archived',
      window: GoalWindow.rollingDays(count: 7),
      aggregation: GoalAggregation.sum,
      targetHours: 5,
    );
    final current = _spec(criteria: criteria);
    when(
      () => revisionService.reviseFromOwner(
        agentId: any(named: 'agentId'),
        baseVersionId: any(named: 'baseVersionId'),
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

    final card = find.byKey(
      const ValueKey('goal-form-category-time-card-archived'),
    );
    expect(
      find.descendant(of: card, matching: find.text('archived')),
      findsOneWidget,
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('archived: No more than 5 hours per rolling 7 days'),
      findsOneWidget,
    );
    await tester.tap(find.text('Save new version'));
    await tester.pump();

    final saved = verify(
      () => revisionService.reviseFromOwner(
        agentId: 'goal-1',
        baseVersionId: current.id,
        displayName: 'Juno',
        title: 'Weekly movement',
        statement: 'Gym and run every week',
        criteria: captureAny(named: 'criteria'),
      ),
    ).captured.single;
    expect(saved, criteria);
  });

  testWidgets('rematches categories that load after the first mapping', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final categories = StreamController<List<CategoryDefinition>>();
    addTearDown(categories.close);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(categoriesStream: categories.stream),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Deep work every week',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('goal-form-category-time-card-deep-work')),
      findsNothing,
    );

    await tester.tap(find.byType(BackButton));
    categories.add([_category('deep-work', 'Deep work')]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final target = find.byKey(
      const ValueKey('goal-form-category-time-target-deep-work'),
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: target, matching: find.byType(EditableText)),
          )
          .controller
          .text,
      '1',
    );
  });

  testWidgets('category refresh preserves manually configured mappings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final categories = StreamController<List<CategoryDefinition>>.broadcast();
    addTearDown(categories.close);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(categoriesStream: categories.stream),
      ),
    );
    categories.add([_category('deep-work', 'Deep work')]);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Build a consistent routine',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-form-steps-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deep work'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(
        const ValueKey('goal-form-category-time-target-deep-work'),
      ),
      '5',
    );

    await tester.tap(find.byType(BackButton));
    categories.add([
      _category('deep-work', 'Deep work'),
      _category('admin', 'Admin'),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('goal-form-steps-target')),
      findsOneWidget,
    );
    final target = find.byKey(
      const ValueKey('goal-form-category-time-target-deep-work'),
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: target, matching: find.byType(EditableText)),
          )
          .controller
          .text,
      '5',
    );
  });

  testWidgets('category refresh does not restore a manually removed match', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final categories = StreamController<List<CategoryDefinition>>.broadcast();
    addTearDown(categories.close);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(categoriesStream: categories.stream),
      ),
    );
    categories.add([_category('deep-work', 'Deep work')]);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Deep work every week',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    final card = find.byKey(
      const ValueKey('goal-form-category-time-card-deep-work'),
    );
    await tester.tap(
      find.descendant(of: card, matching: find.byType(DesignSystemIconAction)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    categories.add([
      _category('deep-work', 'Deep work'),
      _category('admin', 'Admin'),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('goal-form-category-time-card-deep-work')),
      findsNothing,
    );
  });

  testWidgets('drops a newly selected category that becomes inactive', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final categories = StreamController<List<CategoryDefinition>>.broadcast();
    addTearDown(categories.close);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(categoriesStream: categories.stream),
      ),
    );
    categories.add([_category('deep-work', 'Deep work')]);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Track my week',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deep work'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(
        const ValueKey('goal-form-category-time-target-deep-work'),
      ),
      '5',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    when(
      categoryRepository.getAllCategoriesIncludingHidden,
    ).thenAnswer(
      (_) async => [_category('deep-work', 'Deep work', active: false)],
    );
    categories.add([]);
    await tester.pumpAndSettle();
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
  });

  testWidgets('keeps a selected private category when visibility changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final categories = StreamController<List<CategoryDefinition>>.broadcast();
    addTearDown(categories.close);
    when(
      categoryRepository.getAllCategoriesIncludingHidden,
    ).thenAnswer(
      (_) async => [_category('deep-work', 'Deep work', private: true)],
    );
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
        overrides: overrides(categoriesStream: categories.stream),
      ),
    );
    categories.add([_category('deep-work', 'Deep work')]);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Track my week',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deep work'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(
        const ValueKey('goal-form-category-time-target-deep-work'),
      ),
      '5',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    categories.add([]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create agent'));
    await tester.pump();

    final saved =
        verify(
              () => agentService.createGoalAgent(
                title: any(named: 'title'),
                displayName: any(named: 'displayName'),
                statement: any(named: 'statement'),
                criteria: captureAny(named: 'criteria'),
              ),
            ).captured.single
            as GoalCriterionCategoryTime;
    expect(saved.categoryId, 'deep-work');
    expect(saved.title, 'Deep work');
    verify(categoryRepository.getAllCategoriesIncludingHidden).called(1);
    verifyNever(() => categoryRepository.getCategoryById(any()));
  });

  testWidgets('save refreshes an untouched derived title after cleanup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(
      () => habitsRepository.getHabitByIdForIntegrity('run'),
    ).thenAnswer((_) async => _habit('run', 'Run', active: false));
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
      'Gym and Run every week',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create agent'));
    await tester.pump();

    final call = verify(
      () => agentService.createGoalAgent(
        title: captureAny(named: 'title'),
        displayName: 'Juno',
        statement: 'Gym and Run every week',
        criteria: captureAny(named: 'criteria'),
      ),
    ).captured;
    expect(call.first, 'Gym');
    final saved = call.last as GoalCriterionHabit;
    expect(saved.habitId, 'gym');
  });

  testWidgets(
    'save recovers from a blank title after habit integrity checks',
    (tester) async {
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
        'Gym and Run every week',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('goal-form-title-edit')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('goal-form-title')),
        '',
      );
      await tester.tap(find.text('Create agent'));
      await tester.pumpAndSettle();

      expect(
        find.text('Give your goal a name.'),
        findsOneWidget,
      );
      expect(find.text('Create agent'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('goal-form-title')),
                matching: find.byType(TextField),
              ),
            )
            .enabled,
        isTrue,
      );
      verify(() => habitsRepository.getHabitByIdForIntegrity('gym')).called(1);
      verify(() => habitsRepository.getHabitByIdForIntegrity('run')).called(1);
      verifyNever(
        () => agentService.createGoalAgent(
          title: any(named: 'title'),
          displayName: any(named: 'displayName'),
          statement: any(named: 'statement'),
          criteria: any(named: 'criteria'),
        ),
      );
    },
  );

  testWidgets('a newly selected habit stays selected when it becomes private', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final habits = StreamController<List<HabitDefinition>>.broadcast();
    final runLookup = Completer<HabitDefinition?>();
    when(
      habitsRepository.watchHabitDefinitions,
    ).thenAnswer((_) => habits.stream);
    when(
      () => habitsRepository.getHabitByIdForIntegrity('gym'),
    ).thenAnswer((_) async => _habit('gym', 'Gym'));
    when(
      () => habitsRepository.getHabitByIdForIntegrity('run'),
    ).thenAnswer((_) => runLookup.future);
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
    habits.add([_habit('gym', 'Gym'), _habit('run', 'Run')]);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Gym every week',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-form-picker-habit-run')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create agent'));
    await tester.pump();

    habits.add([_habit('gym', 'Gym')]);
    await tester.pump();
    runLookup.complete(_habit('run', 'Run', private: true));
    await tester.pump();

    final saved =
        verify(
              () => agentService.createGoalAgent(
                title: 'Gym & Run',
                displayName: 'Juno',
                statement: 'Gym every week',
                criteria: captureAny(named: 'criteria'),
              ),
            ).captured.single
            as GoalCriterionAllOf;
    expect(
      saved.criteria.whereType<GoalCriterionHabit>().map(
        (habit) => habit.habitId,
      ),
      containsAll(['gym', 'run']),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await habits.close();
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
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('goal-form-title-edit')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('goal-form-title')), '');
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-persona')),
      '',
    );
    await tester.tap(find.text('Create agent'));
    await tester.pump();

    // Validation is per-field: the empty persona blocks the save first.
    expect(find.text('Give your agent a name.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('goal-form-persona')),
      'Mika',
    );
    await tester.tap(find.text('Create agent'));
    await tester.pumpAndSettle();

    // With the persona named, the still-empty goal title blocks the save.
    expect(find.text('Give your goal a name.'), findsOneWidget);
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
    expect(find.text('3×/week', skipOffstage: false), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('goal-form-decrease-gym')));
    await tester.tap(find.byKey(const ValueKey('goal-form-increase-run')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-form-increase-run')));
    await tester.pumpAndSettle();
    expect(find.text('2×/week', skipOffstage: false), findsOneWidget);
    expect(find.text('5×/week', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Meet your agent'), findsOneWidget);
    expect(
      find.textContaining('Gym (2×/week) · Run (5×/week)'),
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
    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-form-picker-habit-run')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
    await tester.pumpAndSettle();
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

    expect(find.text('2×/week', skipOffstage: false), findsOneWidget);
    expect(find.text('5×/week', skipOffstage: false), findsOneWidget);
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
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Re-deriving is additive: the earlier Gym selection is preserved, the
    // new Run match is added, and the untouched title follows both.
    expect(find.text('Gym & Run'), findsOneWidget);
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
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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

    // Nothing matched: no habit rows surface in the mapping card, and the
    // picker offers both habits unselected.
    expect(find.byKey(const ValueKey('goal-form-habit-read')), findsNothing);
    expect(find.byKey(const ValueKey('goal-form-habit-run')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();
    for (final habitId in ['read', 'run']) {
      expect(
        tester
            .widget<DesignSystemSelectionRow>(
              find.byKey(ValueKey('goal-form-picker-habit-$habitId')),
            )
            .selected,
        isFalse,
      );
    }
  });

  testWidgets('generic cadence words do not select an unrelated habit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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

    // Walk matched and is selected in the mapping card; Meditate daily did
    // not match and stays unselected in the picker.
    expect(
      tester
          .widget<DesignSystemSelectionRow>(
            find.byKey(const ValueKey('goal-form-habit-walk')),
          )
          .selected,
      isTrue,
    );
    expect(
      find.byKey(const ValueKey('goal-form-habit-meditate')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DesignSystemSelectionRow>(
            find.byKey(const ValueKey('goal-form-picker-habit-meditate')),
          )
          .selected,
      isFalse,
    );
  });

  testWidgets('refuses an unobservable intention and offers real signals', (
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
    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('Run'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('goal-form-picker-habit-gym')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
    await tester.pumpAndSettle();
    expect(find.text('3×/week', skipOffstage: false), findsOneWidget);
    // Tap the row's leading edge: its center coincides with the cadence
    // stepper, which would decrement instead of deselect.
    final gymRow = find.byKey(const ValueKey('goal-form-habit-gym'));
    final gymRect = tester.getRect(gymRow);
    await tester.tapAt(Offset(gymRect.left + 40, gymRect.center.dy));
    await tester.pump();
    // The picker-added habit keeps its unchecked row for this step entry —
    // only the cadence stepper leaves with the selection.
    expect(gymRow, findsOneWidget);
    expect(
      tester.widget<DesignSystemSelectionRow>(gymRow).selected,
      isFalse,
    );
    expect(find.text('3×/week', skipOffstage: false), findsNothing);
  });

  testWidgets('an empty habit source links to habit setup', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();

    expect(find.text('No active habits are available yet.'), findsOneWidget);
    await tester.ensureVisible(find.text('Create a habit first'));
    await tester.tap(find.text('Create a habit first'));
    expect(navigated, ['/habits']);
  });

  testWidgets('an empty measurable source links to measurable setup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: [
          ...overrides(),
          measurableDataTypesStreamProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Read more often',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('goal-form-add-signal')),
    );
    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();
    expect(find.text('Your measurables'), findsOneWidget);
    expect(find.text('Create measurable'), findsOneWidget);

    await tester.tap(find.text('Create measurable'));
    await tester.pumpAndSettle();
    expect(navigated, ['/settings/measurables/create']);
  });

  testWidgets('clearing a selected measurable target blocks confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final measurable = MeasurableDataType(
      id: 'meds',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      displayName: 'Medication doses',
      description: '',
      unitName: 'doses',
      version: 1,
      vectorClock: null,
    );
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: [
          ...overrides(),
          measurableDataTypesStreamProvider.overrideWith(
            (ref) => Stream.value([measurable]),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Build consistency',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medication doses'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('goal-form-measurable-target-meds')),
      '',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // The cleared target errors inline on the measurable's own input.
    expect(find.text('Set a target to continue.'), findsOneWidget);
    expect(
      find.text('Choose at least one signal the agent can actually observe.'),
      findsNothing,
    );
    expect(find.text('Meet your agent'), findsNothing);
  });

  testWidgets('new goals can select weight and blood pressure', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
      'Track my health baseline',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();
    expect(find.text('Health data'), findsOneWidget);
    // Weight before blood pressure: the order that once reparented the live
    // weight input onto a disposed controller — kept natural now that the
    // input rebinds in didUpdateWidget.
    await tester.tap(
      find.byKey(const ValueKey('goal-form-health-source-weight')),
    );
    await tester.pump();
    // The picker stays open, so blood pressure joins in the same visit.
    await tester.tap(
      find.byKey(
        const ValueKey('goal-form-health-source-blood-pressure'),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(
        const ValueKey(
          'goal-form-health-target-HealthDataType.WEIGHT',
        ),
      ),
      '75',
    );
    await tester.tap(
      find
          .descendant(
            of: find.byKey(
              const ValueKey('goal-form-health-direction-weight'),
            ),
            matching: find.text('At least'),
          )
          .last,
    );
    await tester.enterText(
      find.byKey(
        const ValueKey(
          'goal-form-health-target-HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
        ),
      ),
      '120',
    );
    await tester.enterText(
      find.byKey(
        const ValueKey(
          'goal-form-health-target-HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
        ),
      ),
      '80',
    );

    await tester.tap(find.widgetWithText(DesignSystemButton, 'Change'));
    await tester.pumpAndSettle();
    Finder selectionRow(String title) => find.byWidgetPredicate(
      (widget) => widget is DesignSystemSelectionRow && widget.title == title,
    );
    expect(selectionRow('All dimensions'), findsOneWidget);
    expect(selectionRow('Any dimension'), findsOneWidget);
    expect(selectionRow('At least 1 of 3'), findsOneWidget);
    expect(
      find.text('Strictest — every dimension must be met.'),
      findsOneWidget,
    );
    expect(
      find.text('Loosest — one met dimension is enough.'),
      findsOneWidget,
    );
    // Choosing a rule applies it but keeps the sheet open — only Done (or a
    // dismiss gesture) closes it.
    await tester.tap(selectionRow('Any dimension'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DesignSystemSelectionRow>(selectionRow('Any dimension'))
          .selected,
      isTrue,
    );

    // Selecting the at-least rule reveals its stepper on its own line, and
    // stepping adjusts the count without dismissing the sheet.
    await tester.tap(selectionRow('At least 1 of 3'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('goal-form-composite-increase')),
    );
    await tester.pumpAndSettle();
    expect(selectionRow('At least 2 of 3'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('goal-form-composite-decrease')),
    );
    await tester.pumpAndSettle();
    expect(selectionRow('At least 1 of 3'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.tap(selectionRow('All dimensions'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('goal-form-composite-done')),
    );
    await tester.pumpAndSettle();
    expect(selectionRow('All dimensions'), findsNothing);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Meet your agent'), findsOneWidget);
    await tester.tap(find.text('Create agent'));
    await tester.pump();

    final captured =
        verify(
              () => agentService.createGoalAgent(
                title: any(named: 'title'),
                displayName: any(named: 'displayName'),
                statement: 'Track my health baseline',
                criteria: captureAny(named: 'criteria'),
              ),
            ).captured.single
            as GoalCriterionAllOf;
    final healthLeaves = captured.criteria.whereType<GoalCriterionMetric>();
    expect(
      {
        for (final leaf in healthLeaves)
          leaf.dataType: (leaf.target, leaf.direction),
      },
      {
        GoalHealthDataTypes.weight: (75, GoalDirection.atLeast),
        GoalHealthDataTypes.bloodPressureSystolic: (
          120,
          GoalDirection.atMost,
        ),
        GoalHealthDataTypes.bloodPressureDiastolic: (
          80,
          GoalDirection.atMost,
        ),
      },
    );
  });

  testWidgets('dimension search finds measurable units and health aliases', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final measurable = MeasurableDataType(
      id: 'meds',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      displayName: 'Medication doses',
      description: '',
      unitName: 'doses',
      version: 1,
      vectorClock: null,
    );
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
        overrides: [
          ...overrides(),
          measurableDataTypesStreamProvider.overrideWith(
            (ref) => Stream.value([measurable]),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Build consistency',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    Future<void> searchFor(String query) async {
      final search = find.descendant(
        of: find.byType(DesignSystemTextInput).last,
        matching: find.byType(EditableText),
      );
      await tester.enterText(search, query);
      await tester.pump();
    }

    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();
    await searchFor('dose');
    Finder selectionRow(String title) => find.byWidgetPredicate(
      (widget) => widget is DesignSystemSelectionRow && widget.title == title,
    );
    expect(selectionRow('Medication doses'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('goal-form-health-source-weight')),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey('goal-form-health-source-blood-pressure'),
      ),
      findsNothing,
    );
    await tester.tap(selectionRow('Medication doses'));
    await tester.pump();

    // Same open sheet: a new query swaps the results in place.
    await searchFor('kg');
    expect(
      find.byKey(const ValueKey('goal-form-health-source-weight')),
      findsOneWidget,
    );
    expect(selectionRow('Medication doses'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('goal-form-health-source-weight')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(
        const ValueKey('goal-form-health-target-HealthDataType.WEIGHT'),
      ),
      '75',
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Medication doses: 1 per rolling week'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Weight: 7-day average No more than 75 kg'),
      findsOneWidget,
    );
    await tester.tap(find.text('Create agent'));
    await tester.pump();

    final criteria =
        verify(
              () => agentService.createGoalAgent(
                title: any(named: 'title'),
                displayName: any(named: 'displayName'),
                statement: 'Build consistency',
                criteria: captureAny(named: 'criteria'),
              ),
            ).captured.single
            as GoalCriterionAllOf;
    expect(
      criteria.criteria.whereType<GoalCriterionMeasurable>().single.dataTypeId,
      'meds',
    );
  });

  testWidgets('editing can add health dimensions without replacing old ones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final current = _spec(
      criteria: const GoalCriterion.habit(
        criterionId: 'habit-gym-v3',
        habitId: 'gym',
        window: GoalWindow.rollingDays(count: 7),
        targetCount: 2,
      ),
    );
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
    ).thenAnswer(
      (_) async => GoalSpecRevisionMinted(
        version: revised,
        changeSummaries: const ['health signals added'],
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

    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();
    for (final sourceKey in ['weight', 'blood-pressure']) {
      await tester.tap(
        find.byKey(ValueKey('goal-form-health-source-$sourceKey')),
      );
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
    await tester.pumpAndSettle();
    for (final entry in {
      GoalHealthDataTypes.weight: '78',
      GoalHealthDataTypes.bloodPressureSystolic: '122',
      GoalHealthDataTypes.bloodPressureDiastolic: '82',
    }.entries) {
      await tester.enterText(
        find.byKey(ValueKey('goal-form-health-target-${entry.key}')),
        entry.value,
      );
    }
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save new version'));
    await tester.pump();

    final saved =
        verify(
              () => revisionService.reviseFromOwner(
                agentId: 'goal-1',
                baseVersionId: current.id,
                displayName: any(named: 'displayName'),
                title: any(named: 'title'),
                statement: any(named: 'statement'),
                criteria: captureAny(named: 'criteria'),
              ),
            ).captured.single
            as GoalCriterionAllOf;
    expect(
      saved.criteria.whereType<GoalCriterionHabit>().single.criterionId,
      'habit-gym-v3',
    );
    expect(
      saved.criteria.whereType<GoalCriterionMetric>().map(
        (leaf) => leaf.dataType,
      ),
      containsAll(GoalHealthDataTypes.supported),
    );
  });

  testWidgets('removing one health dimension preserves the other targets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final current = _spec(
      criteria: const GoalCriterion.habit(
        criterionId: 'habit-gym-v3',
        habitId: 'gym',
        window: GoalWindow.rollingDays(count: 7),
        targetCount: 2,
      ),
    );
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(agentId: 'goal-1'),
        overrides: overrides(editSpec: current),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();
    for (final sourceKey in ['weight', 'blood-pressure']) {
      await tester.tap(
        find.byKey(ValueKey('goal-form-health-source-$sourceKey')),
      );
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
    await tester.pumpAndSettle();
    for (final entry in {
      GoalHealthDataTypes.weight: '78',
      GoalHealthDataTypes.bloodPressureSystolic: '122',
      GoalHealthDataTypes.bloodPressureDiastolic: '82',
    }.entries) {
      await tester.enterText(
        find.byKey(ValueKey('goal-form-health-target-${entry.key}')),
        entry.value,
      );
    }

    // Health rows have no remove button anymore: tapping the selected
    // weight row's title deselects it.
    await tester.tap(find.text('Weight'));
    await tester.pump();

    String targetText(String dataType) => tester
        .widget<EditableText>(
          find.descendant(
            of: find.byKey(ValueKey('goal-form-health-target-$dataType')),
            matching: find.byType(EditableText),
          ),
        )
        .controller
        .text;
    expect(
      targetText(GoalHealthDataTypes.bloodPressureSystolic),
      '122',
    );
    expect(
      targetText(GoalHealthDataTypes.bloodPressureDiastolic),
      '82',
    );
    expect(
      find.byKey(
        const ValueKey('goal-form-health-target-HealthDataType.WEIGHT'),
      ),
      findsNothing,
    );
  });

  testWidgets('a failed habit source explains that the list is unavailable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
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
    expect(find.text('2×/week', skipOffstage: false), findsOneWidget);
    expect(find.text('5×/week', skipOffstage: false), findsOneWidget);

    await tester.tap(find.text('Continue'));
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
    await tester.tap(find.byKey(const ValueKey('goal-form-title-edit')));
    await tester.pump();
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

  testWidgets(
    'editing validates and drops a newly selected inactive habit before save',
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
        () => habitsRepository.getHabitByIdForIntegrity('run'),
      ).thenAnswer((_) async => _habit('run', 'Run', active: false));
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
      await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('goal-form-picker-habit-run')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('goal-form-title-edit')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('goal-form-title')),
        'Updated movement',
      );
      await tester.tap(find.text('Save new version'));
      await tester.pump();

      final saved =
          verify(
                () => revisionService.reviseFromOwner(
                  agentId: 'goal-1',
                  baseVersionId: current.id,
                  displayName: 'Juno',
                  title: 'Updated movement',
                  statement: current.statement,
                  criteria: captureAny(named: 'criteria'),
                ),
              ).captured.single
              as GoalCriterionHabit;
      expect(saved.habitId, 'gym');
      expect(saved.targetCount, 2);
      verify(() => habitsRepository.getHabitByIdForIntegrity('gym')).called(1);
      verify(() => habitsRepository.getHabitByIdForIntegrity('run')).called(1);
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
    await tester.tap(find.text('Save new version'));
    await tester.pump();

    expect(
      find.text('Saving the goal failed — please try again.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('goal-form-title-edit')),
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

  testWidgets(
    'an integrity lookup makes the edit busy and blocks duplicate save or back',
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
      // Open the title input so its disabled state is observable while the
      // save is busy.
      await tester.tap(find.byKey(const ValueKey('goal-form-title-edit')));
      await tester.pump();

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
      expect(
        tester.widget<BackButton>(find.byType(BackButton)).onPressed,
        isNull,
      );
      verify(() => habitsRepository.getHabitByIdForIntegrity('gym')).called(1);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byKey(const ValueKey('goal-form-title')), findsOneWidget);
      expect(find.byKey(const ValueKey('goal-form-habit-gym')), findsNothing);

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
          criteria: criteria,
        ),
      ).called(1);
    },
  );

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
    expect(
      find.textContaining('uses a mapping this editor can’t safely rewrite'),
      findsOneWidget,
    );
    await tester.tap(find.text('Continue'));
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
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    habits.add([]);
    await tester.pump();
    when(
      () => habitsRepository.getHabitByIdForIntegrity('gym'),
    ).thenAnswer((_) async => null);
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
      await tester.tap(find.byKey(const ValueKey('goal-form-title-edit')));
      await tester.pump();
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
    await tester.tap(find.byKey(const ValueKey('goal-form-title-edit')));
    await tester.pump();
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
    await tester.tap(find.byKey(const ValueKey('goal-form-title-edit')));
    await tester.pump();
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
    await tester.tap(find.byKey(const ValueKey('goal-form-title-edit')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-title')),
      'Updated movement',
    );
    await tester.tap(find.text('Save new version'));
    await tester.pumpAndSettle();

    expect(pendingReads, 2);
  });

  testWidgets('re-checking a habit restores its remembered cadence', (
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

    await tester.tap(find.byKey(const ValueKey('goal-form-increase-gym')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-form-increase-gym')));
    await tester.pump();
    expect(find.text('5×/week'), findsOneWidget);

    // Deselect via the row's leading edge — the row center hosts the
    // cadence stepper.
    final gymRow = find.byKey(const ValueKey('goal-form-habit-gym'));
    final gymRect = tester.getRect(gymRow);
    await tester.tapAt(Offset(gymRect.left + 40, gymRect.center.dy));
    await tester.pump();
    expect(find.text('5×/week'), findsNothing);

    // Re-checking restores the shaped 5× cadence, not the 3× default.
    await tester.tap(gymRow);
    await tester.pump();
    expect(find.text('5×/week'), findsOneWidget);
    expect(find.text('3×/week'), findsNothing);
  });

  testWidgets(
    'a blood-pressure intention arrives pre-selected with seeded paired '
    'targets sharing one direction',
    (tester) async {
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
        'Keep my blood pressure under control',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // The substance arrives selected: the single blood-pressure row is
      // already checked, with paired targets seeded 130/80.
      final row = find.byKey(
        const ValueKey('goal-form-health-row-blood-pressure'),
      );
      expect(row, findsOneWidget);
      expect(
        tester.widget<DesignSystemSelectionRow>(row).selected,
        isTrue,
      );
      String targetText(String dataType) => tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(ValueKey('goal-form-health-target-$dataType')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text;
      expect(targetText(GoalHealthDataTypes.bloodPressureSystolic), '130');
      expect(targetText(GoalHealthDataTypes.bloodPressureDiastolic), '80');
      expect(find.text('Systolic (mmHg)'), findsOneWidget);
      expect(find.text('Diastolic (mmHg)'), findsOneWidget);
      // The paired controls stay within the inline target measure.
      expect(
        tester
            .getSize(
              find.byKey(
                const ValueKey('goal-form-health-direction-blood-pressure'),
              ),
            )
            .width,
        lessThanOrEqualTo(kInlineTargetInputWidth),
      );

      // The row carries ONE direction toggle that drives both readings.
      await tester.tap(
        find
            .descendant(
              of: find.byKey(
                const ValueKey('goal-form-health-direction-blood-pressure'),
              ),
              matching: find.text('At least'),
            )
            .last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Systolic blood pressure: 7-day average At least 130 mmHg',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Diastolic blood pressure: 7-day average At least 80 mmHg',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'the blood-pressure row toggles in place and re-selecting re-seeds it',
    (tester) async {
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
        'Keep my blood pressure under control',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      final row = find.byKey(
        const ValueKey('goal-form-health-row-blood-pressure'),
      );
      // Checked on arrival: the row sits in the chosen group, above the
      // Suggested caption (which holds the steps offer).
      expect(
        tester.getRect(row).top,
        lessThan(tester.getRect(find.text('Suggested')).top),
      );

      // Tapping the checked row's title removes both readings, but the row
      // does NOT move: the order is frozen for this step entry, so it stays
      // above the Suggested caption, merely unchecked.
      await tester.tap(find.text('Blood Pressure'));
      await tester.pump();
      expect(
        tester.widget<DesignSystemSelectionRow>(row).selected,
        isFalse,
      );
      expect(
        find.byKey(
          const ValueKey(
            'goal-form-health-target-HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
          ),
        ),
        findsNothing,
      );
      expect(
        tester.getRect(row).top,
        lessThan(tester.getRect(find.text('Suggested')).top),
      );

      // Re-selecting seeds the defaults again instead of empty targets.
      await tester.tap(find.text('Blood Pressure'));
      await tester.pump();
      expect(
        tester.widget<DesignSystemSelectionRow>(row).selected,
        isTrue,
      );
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(
                  const ValueKey(
                    'goal-form-health-target-'
                    'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
                  ),
                ),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        '130',
      );
    },
  );

  testWidgets(
    'a missing health target errors inline and is scrolled into view',
    (tester) async {
      tester.view.physicalSize = const Size(900, 700);
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
        'Keep my blood pressure and weight in check',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Both health rows arrive pre-selected; weight seeds no target, and
      // its row trails the seeded blood-pressure controls below the fold
      // at this height.
      final weightInput = find.byKey(
        const ValueKey('goal-form-health-target-HealthDataType.WEIGHT'),
      );
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: weightInput,
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        isEmpty,
      );
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.pixels, 0);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // The empty weight target errors inline, and the page scrolls the
      // offending input into the viewport.
      expect(find.text('Set a target to continue.'), findsOneWidget);
      expect(
        find.text(
          'Choose at least one signal the agent can actually observe.',
        ),
        findsNothing,
      );
      expect(scrollable.position.pixels, greaterThan(0));
      final revealed = tester.getRect(weightInput);
      expect(revealed.top, greaterThanOrEqualTo(0));
      expect(revealed.bottom, lessThanOrEqualTo(700));
    },
  );

  testWidgets('clearing a category time target errors on its own input', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: overrides(
          categories: [_category('deep-work', 'Deep work')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Deep work every week',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(
        const ValueKey('goal-form-category-time-target-deep-work'),
      ),
      '',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Set a target to continue.'), findsOneWidget);
    expect(find.text('Meet your agent'), findsNothing);
  });

  testWidgets('habit rows and the derived title strip emoji from names', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(habitsRepository.watchHabitDefinitions).thenAnswer(
      (_) => Stream.value([_habit('gym', 'Gym 💪')]),
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
      'Gym every week',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<DesignSystemSelectionRow>(
            find.byKey(const ValueKey('goal-form-habit-gym')),
          )
          .title,
      'Gym',
    );
    expect(find.text('Gym 💪'), findsNothing);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('goal-form-title-mapping')),
              matching: find.byType(TextField),
            ),
          )
          .controller
          ?.text,
      'Gym',
    );
  });

  testWidgets(
    'desktop layouts place the primary action inside the content column',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const CreateGoalAgentPage(),
          overrides: overrides(),
          // The harness pins a phone MediaQuery by default; the desktop CTA
          // placement keys off MediaQuery width.
          mediaQueryData: const MediaQueryData(size: Size(1200, 2000)),
        ),
      );
      await tester.pumpAndSettle();

      final action = find.byKey(const ValueKey('goal-form-primary-action'));
      // One pinned bottom band on every form factor: the CTA never scrolls
      // with the content, and it sits on an opaque strip closed by a top
      // hairline.
      expect(
        find.ancestor(of: action, matching: find.byType(ListView)),
        findsNothing,
      );
      final band = tester.widget<DecoratedBox>(
        find.ancestor(of: action, matching: find.byType(DecoratedBox)).first,
      );
      final bandDecoration = band.decoration as BoxDecoration;
      expect(
        (bandDecoration.border! as Border).top.color,
        dsTokensLight.colors.decorative.level01,
      );
      expect(tester.widget<DesignSystemButton>(action).fullWidth, isTrue);

      await tester.enterText(
        find.byKey(const ValueKey('goal-form-intention')),
        'Gym every week',
      );
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Here’s what I can watch'), findsOneWidget);

      // Desktop demotes the add affordance to an intrinsic tertiary while
      // the commit action keeps the full column width.
      final addSignal = tester.widget<DesignSystemButton>(
        find.byKey(const ValueKey('goal-form-add-signal')),
      );
      expect(addSignal.variant, DesignSystemButtonVariant.tertiary);
      expect(addSignal.fullWidth, isFalse);
      expect(tester.widget<DesignSystemButton>(action).fullWidth, isTrue);
    },
  );

  testWidgets(
    'an intention-matched measurable seeds its card and can be removed',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final water = MeasurableDataType(
        id: 'water',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        displayName: 'Water',
        description: '',
        unitName: 'ml',
        version: 1,
        vectorClock: null,
      );
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const CreateGoalAgentPage(),
          overrides: [
            ...overrides(),
            measurableDataTypesStreamProvider.overrideWith(
              (ref) => Stream.value([water]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('goal-form-intention')),
        'Drink more water',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // The matched measurable arrives as a card seeded with a target of 1.
      final card = find.byKey(
        const ValueKey('goal-form-measurable-card-water'),
      );
      expect(card, findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(
                  const ValueKey('goal-form-measurable-target-water'),
                ),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        '1',
      );

      // The card's remove action deselects the measurable entirely.
      await tester.tap(
        find.descendant(of: card, matching: find.byIcon(Icons.close_rounded)),
      );
      await tester.pumpAndSettle();
      expect(card, findsNothing);
    },
  );

  testWidgets('the picker unselects an already-selected habit', (
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

    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();
    final pickerRow = find.byKey(const ValueKey('goal-form-picker-habit-gym'));
    expect(
      tester.widget<DesignSystemSelectionRow>(pickerRow).selected,
      isTrue,
    );

    await tester.tap(pickerRow);
    await tester.pump();
    expect(
      tester.widget<DesignSystemSelectionRow>(pickerRow).selected,
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
    await tester.pumpAndSettle();
    // The matched habit stays visible on the page, but deselected.
    expect(
      tester
          .widget<DesignSystemSelectionRow>(
            find.byKey(const ValueKey('goal-form-habit-gym')),
          )
          .selected,
      isFalse,
    );
  });

  testWidgets('the picker toggles a selected weight dimension off', (
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
      'Track my health',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();
    final weightRow = find.byKey(
      const ValueKey('goal-form-health-source-weight'),
    );
    await tester.tap(weightRow);
    await tester.pump();
    expect(
      tester.widget<DesignSystemSelectionRow>(weightRow).selected,
      isTrue,
    );

    // A second tap toggles the dimension back off instead of dead-ending.
    await tester.tap(weightRow);
    await tester.pump();
    expect(
      tester.widget<DesignSystemSelectionRow>(weightRow).selected,
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
    await tester.pumpAndSettle();
    // The toggled-off signal keeps an unchecked row (frozen order) with no
    // target controls.
    final pageWeightRow = find.byKey(
      const ValueKey('goal-form-health-row-weight'),
    );
    expect(pageWeightRow, findsOneWidget);
    expect(
      tester.widget<DesignSystemSelectionRow>(pageWeightRow).selected,
      isFalse,
    );
    expect(
      find.byKey(
        const ValueKey('goal-form-health-target-HealthDataType.WEIGHT'),
      ),
      findsNothing,
    );
  });

  testWidgets('fixing one invalid target keeps the other error visible', (
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
      'Track my week',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Steps on with a blanked target, weight picked with its null default.
    await tester.tap(find.byKey(const ValueKey('goal-form-steps-row')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-steps-target')),
      '',
    );
    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('goal-form-health-source-weight')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Set a target to continue.'), findsNWidgets(2));

    // Fixing the steps target clears ONLY the steps error; the untouched
    // weight target stays flagged.
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-steps-target')),
      '9000',
    );
    await tester.pump();
    expect(find.text('Set a target to continue.'), findsOneWidget);
    expect(
      tester
          .widget<DesignSystemTextInput>(
            find.byKey(const ValueKey('goal-form-steps-target')),
          )
          .errorText,
      isNull,
    );
    expect(
      tester
          .widget<DesignSystemTextInput>(
            find.byKey(
              const ValueKey('goal-form-health-target-HealthDataType.WEIGHT'),
            ),
          )
          .errorText,
      'Set a target to continue.',
    );
  });

  testWidgets('typing clears the confirmation field errors without saving', (
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
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('goal-form-title-edit')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('goal-form-title')), '');
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-persona')),
      '',
    );
    await tester.tap(find.text('Create agent'));
    await tester.pump();
    expect(find.text('Give your agent a name.'), findsOneWidget);

    // Typing a persona name clears its error immediately, before any save.
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-persona')),
      'Mika',
    );
    await tester.pump();
    expect(find.text('Give your agent a name.'), findsNothing);

    await tester.tap(find.text('Create agent'));
    await tester.pumpAndSettle();
    expect(find.text('Give your goal a name.'), findsOneWidget);

    // Typing a goal name clears the title error the same way.
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-title')),
      'Comeback season',
    );
    await tester.pump();
    expect(find.text('Give your goal a name.'), findsNothing);
    verifyNever(
      () => agentService.createGoalAgent(
        title: any(named: 'title'),
        displayName: any(named: 'displayName'),
        statement: any(named: 'statement'),
        criteria: any(named: 'criteria'),
      ),
    );
  });

  testWidgets('a measurable card lays out without overflow at phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final water = MeasurableDataType(
      id: 'water',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      displayName: 'Water',
      description: '',
      unitName: 'ml',
      version: 1,
      vectorClock: null,
    );
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(),
        overrides: [
          ...overrides(),
          measurableDataTypesStreamProvider.overrideWith(
            (ref) => Stream.value([water]),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Drink more water',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // The card renders, and the flexible target input yields instead of
    // forcing a RenderFlex overflow at 320 logical pixels.
    expect(
      find.byKey(const ValueKey('goal-form-measurable-card-water')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the picker toggles blood pressure, category time and measurables '
    'back off',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final water = MeasurableDataType(
        id: 'water',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        displayName: 'Water',
        description: '',
        unitName: 'ml',
        version: 1,
        vectorClock: null,
      );
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const CreateGoalAgentPage(),
          overrides: [
            ...overrides(categories: [_category('deep-work', 'Deep work')]),
            measurableDataTypesStreamProvider.overrideWith(
              (ref) => Stream.value([water]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('goal-form-intention')),
        'Track my week',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
      await tester.pumpAndSettle();

      Future<void> toggleTwice(Finder row) async {
        await tester.tap(row);
        await tester.pump();
        expect(
          tester.widget<DesignSystemSelectionRow>(row).selected,
          isTrue,
        );
        await tester.tap(row);
        await tester.pump();
        expect(
          tester.widget<DesignSystemSelectionRow>(row).selected,
          isFalse,
        );
      }

      await toggleTwice(
        find.byKey(const ValueKey('goal-form-health-source-blood-pressure')),
      );
      await toggleTwice(
        find.byKey(
          const ValueKey('goal-form-category-time-source-deep-work'),
        ),
      );
      await toggleTwice(
        find.byWidgetPredicate(
          (widget) =>
              widget is DesignSystemSelectionRow && widget.title == 'Water',
        ),
      );

      await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
      await tester.pumpAndSettle();

      // The toggled-off blood-pressure signal keeps an unchecked row in the
      // frozen order; the category and measurable cards leave entirely.
      final bpRow = find.byKey(
        const ValueKey('goal-form-health-row-blood-pressure'),
      );
      expect(bpRow, findsOneWidget);
      expect(
        tester.widget<DesignSystemSelectionRow>(bpRow).selected,
        isFalse,
      );
      expect(
        find.byKey(
          const ValueKey('goal-form-category-time-card-deep-work'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('goal-form-measurable-card-water')),
        findsNothing,
      );
    },
  );

  testWidgets('blank paired blood-pressure targets error inline', (
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
      'Keep my blood pressure under control',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Clearing both paired inputs flags each reading on its own field.
    for (final dataType in [
      GoalHealthDataTypes.bloodPressureSystolic,
      GoalHealthDataTypes.bloodPressureDiastolic,
    ]) {
      await tester.enterText(
        find.byKey(ValueKey('goal-form-health-target-$dataType')),
        '',
      );
    }
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Set a target to continue.'), findsNWidgets(2));
    expect(find.text('Meet your agent'), findsNothing);
  });

  testWidgets(
    'a deselected weight row regroups under Suggested only on re-entry',
    (tester) async {
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
        'Watch my weight and gym',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // The matched weight row arrives checked, with no seeded target.
      final row = find.byKey(const ValueKey('goal-form-health-row-weight'));
      expect(
        tester.widget<DesignSystemSelectionRow>(row).selected,
        isTrue,
      );
      final weightInput = find.byKey(
        const ValueKey('goal-form-health-target-HealthDataType.WEIGHT'),
      );
      expect(weightInput, findsOneWidget);

      // Deselecting keeps the row in place for this step entry.
      await tester.tap(find.text('Weight'));
      await tester.pump();
      expect(
        tester.widget<DesignSystemSelectionRow>(row).selected,
        isFalse,
      );
      expect(weightInput, findsNothing);
      expect(
        tester.getRect(row).top,
        lessThan(tester.getRect(find.text('Suggested')).top),
      );

      // Re-entering the step regroups: the unchecked weight row now waits
      // under the Suggested caption.
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Meet your agent'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('Suggested')).top,
        lessThan(tester.getRect(row).top),
      );

      // Re-selecting from the suggestion restores its target input.
      await tester.tap(find.text('Weight'));
      await tester.pump();
      expect(
        tester.widget<DesignSystemSelectionRow>(row).selected,
        isTrue,
      );
      expect(weightInput, findsOneWidget);
    },
  );

  testWidgets(
    'a habit naming a matched health capability is demoted to unchecked',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      when(habitsRepository.watchHabitDefinitions).thenAnswer(
        (_) => Stream.value([
          _habit('bp-log', 'Measure Blood Pressure'),
          _habit('gym', 'Gym'),
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
        'Keep my blood pressure under control and go to the gym',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // The readings signal carries the goal…
      expect(
        tester
            .widget<DesignSystemSelectionRow>(
              find.byKey(
                const ValueKey('goal-form-health-row-blood-pressure'),
              ),
            )
            .selected,
        isTrue,
      );
      // …its bookkeeping twin stays visible but unchecked…
      expect(
        tester
            .widget<DesignSystemSelectionRow>(
              find.byKey(const ValueKey('goal-form-habit-bp-log')),
            )
            .selected,
        isFalse,
      );
      // …while a matched habit with no health overlap arrives checked.
      expect(
        tester
            .widget<DesignSystemSelectionRow>(
              find.byKey(const ValueKey('goal-form-habit-gym')),
            )
            .selected,
        isTrue,
      );
    },
  );

  testWidgets(
    'the signals card groups chosen rows above the Suggested caption',
    (tester) async {
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

      // Chosen: the checked gym habit. Suggested: the unselected steps row.
      final gymTop = tester
          .getRect(find.byKey(const ValueKey('goal-form-habit-gym')))
          .top;
      final captionTop = tester.getRect(find.text('Suggested')).top;
      final stepsTop = tester
          .getRect(find.byKey(const ValueKey('goal-form-steps-row')))
          .top;
      expect(gymTop, lessThan(captionTop));
      expect(captionTop, lessThan(stepsTop));
    },
  );

  testWidgets('the picker offers a steps row that toggles immediately', (
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
      'Walk more often',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();
    final pickerSteps = find.byKey(const ValueKey('goal-form-picker-steps'));
    expect(pickerSteps, findsOneWidget);
    expect(
      tester.widget<DesignSystemSelectionRow>(pickerSteps).selected,
      isFalse,
    );

    // Toggles apply immediately and can be reversed within the same visit.
    await tester.tap(pickerSteps);
    await tester.pump();
    expect(
      tester.widget<DesignSystemSelectionRow>(pickerSteps).selected,
      isTrue,
    );
    await tester.tap(pickerSteps);
    await tester.pump();
    expect(
      tester.widget<DesignSystemSelectionRow>(pickerSteps).selected,
      isFalse,
    );
    await tester.tap(pickerSteps);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
    await tester.pumpAndSettle();

    // The page reflects the picker's final steps state.
    expect(
      tester
          .widget<DesignSystemSelectionRow>(
            find.byKey(const ValueKey('goal-form-steps-row')),
          )
          .selected,
      isTrue,
    );
    expect(
      find.byKey(const ValueKey('goal-form-steps-target')),
      findsOneWidget,
    );
  });

  testWidgets(
    'REGRESSION: weight then blood pressure in one picker visit accepts a '
    'typed weight target',
    (tester) async {
      // Selecting weight first meant the blood-pressure row inserted above
      // it, reparenting the anchored weight input while its old controller
      // was disposed — typing then threw. Fixed by rebinding the input's
      // controller in didUpdateWidget.
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
        'Track my health baseline',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('goal-form-health-source-weight')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(
          const ValueKey('goal-form-health-source-blood-pressure'),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
      await tester.pumpAndSettle();

      final weightInput = find.byKey(
        const ValueKey('goal-form-health-target-HealthDataType.WEIGHT'),
      );
      await tester.enterText(weightInput, '75');
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: weightInput,
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        '75',
      );
    },
  );

  testWidgets(
    'a suggested habit checked in place regroups only on step re-entry',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      when(habitsRepository.watchHabitDefinitions).thenAnswer(
        (_) => Stream.value([
          _habit('bp-log', 'Measure Blood Pressure'),
          _habit('gym', 'Gym'),
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
        'Keep my blood pressure under control and go to the gym',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // The demoted BP-twin habit waits under Suggested; checking it keeps
      // it there — with its cadence stepper — until the step is re-entered.
      final twinRow = find.byKey(const ValueKey('goal-form-habit-bp-log'));
      final caption = find.text('Suggested');
      expect(
        tester.getRect(caption).top,
        lessThan(tester.getRect(twinRow).top),
      );
      await tester.tap(find.text('Measure Blood Pressure'));
      await tester.pump();
      expect(
        tester.widget<DesignSystemSelectionRow>(twinRow).selected,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('goal-form-increase-bp-log')),
        findsOneWidget,
      );
      expect(
        tester.getRect(caption).top,
        lessThan(tester.getRect(twinRow).top),
      );

      // Re-entering the mapping step promotes the checked habit above the
      // caption.
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Meet your agent'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(twinRow).top,
        lessThan(tester.getRect(find.text('Suggested')).top),
      );
    },
  );

  testWidgets('a picker-added habit appends to the chosen group', (
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

    await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-form-picker-habit-run')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
    await tester.pumpAndSettle();

    // The newly picked habit lands at the end of the chosen group: after
    // the matched gym row, above the Suggested caption.
    final gymTop = tester
        .getRect(find.byKey(const ValueKey('goal-form-habit-gym')))
        .top;
    final runTop = tester
        .getRect(find.byKey(const ValueKey('goal-form-habit-run')))
        .top;
    final captionTop = tester.getRect(find.text('Suggested')).top;
    expect(gymTop, lessThan(runTop));
    expect(runTop, lessThan(captionTop));
  });

  testWidgets(
    'a deselected blood-pressure row regroups under Suggested on re-entry',
    (tester) async {
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
        'Keep my blood pressure under control and go to the gym',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Blood Pressure'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Meet your agent'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // The re-entry snapshot files the matched-but-unselected reading
      // under Suggested.
      final row = find.byKey(
        const ValueKey('goal-form-health-row-blood-pressure'),
      );
      expect(
        tester.widget<DesignSystemSelectionRow>(row).selected,
        isFalse,
      );
      expect(
        tester.getRect(find.text('Suggested')).top,
        lessThan(tester.getRect(row).top),
      );
    },
  );

  testWidgets(
    'the confirmation leads with the agent name and bolds only the recap '
    'signals',
    (tester) async {
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
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // The agent's name comes first; the goal name closes the recap card.
      expect(
        tester.getRect(find.byKey(const ValueKey('goal-form-persona'))).top,
        lessThan(
          tester.getRect(find.byKey(const ValueKey('goal-form-title'))).top,
        ),
      );

      // The recap is prose in which only the signals carry weight.
      final recap = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.textSpan != null &&
              widget.textSpan!.toPlainText().contains('I’ll watch'),
        ),
      );
      final rootSpan = recap.textSpan! as TextSpan;
      final semiBold = dsTokensLight.typography.weight.semiBold;
      expect(rootSpan.style?.fontWeight, isNot(semiBold));
      expect(
        rootSpan.style?.color,
        dsTokensLight.colors.text.mediumEmphasis,
      );
      final signalSpan = rootSpan.children!.whereType<TextSpan>().firstWhere(
        (span) => span.text == 'Gym (3×/week)',
      );
      expect(signalSpan.style?.fontWeight, semiBold);
      expect(
        signalSpan.style?.color,
        dsTokensLight.colors.text.highEmphasis,
      );
      // The emphasized span derives from the bodyMedium token, not a raw
      // TextStyle that would drop the typeface metrics.
      expect(
        signalSpan.style?.fontSize,
        dsTokensLight.typography.styles.body.bodyMedium.fontSize,
      );
    },
  );

  testWidgets(
    'an edited goal with only a diastolic reading renders a checked '
    'blood-pressure row',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const criteria = GoalCriterion.metric(
        criterionId: 'bp-dia',
        dataType: GoalHealthDataTypes.bloodPressureDiastolic,
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.dailySumThenAverage,
        target: 82,
      );
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const CreateGoalAgentPage(agentId: 'goal-1'),
          overrides: overrides(editSpec: _spec(criteria: criteria)),
        ),
      );
      await tester.pumpAndSettle();

      // A partial pair is still a selected signal: checked, carrying the
      // one value it has.
      final row = find.byKey(
        const ValueKey('goal-form-health-row-blood-pressure'),
      );
      expect(
        tester.widget<DesignSystemSelectionRow>(row).selected,
        isTrue,
      );
      String targetText(String dataType) => tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(ValueKey('goal-form-health-target-$dataType')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text;
      expect(targetText(GoalHealthDataTypes.bloodPressureDiastolic), '82');
      expect(targetText(GoalHealthDataTypes.bloodPressureSystolic), isEmpty);

      // Deselecting removes whatever half of the pair is present.
      await tester.tap(find.text('Blood Pressure'));
      await tester.pump();
      expect(
        tester.widget<DesignSystemSelectionRow>(row).selected,
        isFalse,
      );
      expect(
        find.byKey(
          const ValueKey(
            'goal-form-health-target-HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
          ),
        ),
        findsNothing,
      );
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(
        find.text(
          'Choose at least one signal the agent can actually observe.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'only bookkeeping-twin habits are demoted beside a health signal',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      when(habitsRepository.watchHabitDefinitions).thenAnswer(
        (_) => Stream.value([
          _habit('wt', 'Weight training'),
          _habit('logw', 'Log weight'),
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
        'lose weight',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // The readings signal arrives selected…
      expect(
        tester
            .widget<DesignSystemSelectionRow>(
              find.byKey(const ValueKey('goal-form-health-row-weight')),
            )
            .selected,
        isTrue,
      );
      // …"Weight training" is a real habit that shares a word with the
      // label, so it keeps its default selection…
      expect(
        tester
            .widget<DesignSystemSelectionRow>(
              find.byKey(const ValueKey('goal-form-habit-wt')),
            )
            .selected,
        isTrue,
      );
      // …while "Log weight" is pure bookkeeping and waits unchecked.
      expect(
        tester
            .widget<DesignSystemSelectionRow>(
              find.byKey(const ValueKey('goal-form-habit-logw')),
            )
            .selected,
        isFalse,
      );
    },
  );

  testWidgets(
    'a deselected health signal survives an intention re-map unseeded',
    (tester) async {
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
        'Keep my blood pressure under control',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      final row = find.byKey(
        const ValueKey('goal-form-health-row-blood-pressure'),
      );
      expect(
        tester.widget<DesignSystemSelectionRow>(row).selected,
        isTrue,
      );
      await tester.tap(find.text('Blood Pressure'));
      await tester.pump();

      // A changed intention re-maps, but the explicit deselection survives
      // as an unchecked suggestion instead of being re-seeded.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('goal-form-intention')),
        'Keep my blood pressure under control every single morning',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      expect(
        tester.widget<DesignSystemSelectionRow>(row).selected,
        isFalse,
      );

      // An explicit re-select clears the suppression and re-seeds…
      await tester.tap(find.text('Blood Pressure'));
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(
                  const ValueKey(
                    'goal-form-health-target-'
                    'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
                  ),
                ),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        '130',
      );

      // …and the next re-map keeps it selected.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('goal-form-intention')),
        'Keep my blood pressure under control before breakfast',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<DesignSystemSelectionRow>(row).selected,
        isTrue,
      );
    },
  );

  testWidgets(
    'deselected picker-added signals keep their unchecked rows until '
    're-entry',
    (tester) async {
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
        'Track my week',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('goal-form-picker-habit-run')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('goal-form-health-source-weight')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
      await tester.pumpAndSettle();

      final runRow = find.byKey(const ValueKey('goal-form-habit-run'));
      final weightRow = find.byKey(
        const ValueKey('goal-form-health-row-weight'),
      );
      expect(
        tester.widget<DesignSystemSelectionRow>(runRow).selected,
        isTrue,
      );
      expect(
        tester.widget<DesignSystemSelectionRow>(weightRow).selected,
        isTrue,
      );

      // Deselecting a picker-added habit leaves its unchecked row in place
      // (tap the row's own title — the derived goal name is also "Run").
      await tester.tap(
        find.descendant(of: runRow, matching: find.text('Run')),
      );
      await tester.pump();
      expect(runRow, findsOneWidget);
      expect(
        tester.widget<DesignSystemSelectionRow>(runRow).selected,
        isFalse,
      );
      expect(
        find.byKey(const ValueKey('goal-form-increase-run')),
        findsNothing,
      );

      // Same for a picker-added health signal.
      await tester.tap(find.text('Weight'));
      await tester.pump();
      expect(weightRow, findsOneWidget);
      expect(
        tester.widget<DesignSystemSelectionRow>(weightRow).selected,
        isFalse,
      );
      expect(
        find.byKey(
          const ValueKey('goal-form-health-target-HealthDataType.WEIGHT'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'a German bookkeeping habit is demoted beside the weight signal',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      when(habitsRepository.watchHabitDefinitions).thenAnswer(
        (_) => Stream.value([
          _habit('wiegen', 'Gewicht messen'),
          _habit('heben', 'Gewicht heben'),
        ]),
      );
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const CreateGoalAgentPage(),
          overrides: overrides(),
          locale: const Locale('de'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('goal-form-intention')),
        'Gewicht verlieren',
      );
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();

      // The readings signal arrives selected…
      expect(
        tester
            .widget<DesignSystemSelectionRow>(
              find.byKey(const ValueKey('goal-form-health-row-weight')),
            )
            .selected,
        isTrue,
      );
      // …"Gewicht messen" is pure bookkeeping in German too, so it waits
      // unchecked instead of duplicating the readings signal…
      expect(
        tester
            .widget<DesignSystemSelectionRow>(
              find.byKey(const ValueKey('goal-form-habit-wiegen')),
            )
            .selected,
        isFalse,
      );
      expect(
        tester.getRect(find.text('Vorgeschlagen')).top,
        lessThan(
          tester
              .getRect(find.byKey(const ValueKey('goal-form-habit-wiegen')))
              .top,
        ),
      );
      // …while "Gewicht heben" has a real leftover word and stays selected.
      expect(
        tester
            .widget<DesignSystemSelectionRow>(
              find.byKey(const ValueKey('goal-form-habit-heben')),
            )
            .selected,
        isTrue,
      );
    },
  );

  testWidgets(
    'a diastolic-only goal renders its stored direction on the shared '
    'blood-pressure toggle',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const criteria = GoalCriterion.metric(
        criterionId: 'bp-dia',
        dataType: GoalHealthDataTypes.bloodPressureDiastolic,
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.dailySumThenAverage,
        target: 82,
        // Spelled out: the stored direction is what this test is about.
        // ignore: avoid_redundant_argument_values
        direction: GoalDirection.atLeast,
      );
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const CreateGoalAgentPage(agentId: 'goal-1'),
          overrides: overrides(editSpec: _spec(criteria: criteria)),
        ),
      );
      await tester.pumpAndSettle();

      // One toggle drives both readings, so it must read the direction off
      // whichever half the partial pair actually carries.
      expect(
        tester
            .widget<DsSegmentedToggle<GoalDirection>>(
              find.byKey(
                const ValueKey('goal-form-health-direction-blood-pressure'),
              ),
            )
            .selected,
        GoalDirection.atLeast,
      );

      // The stored direction survives the round trip to confirmation.
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Diastolic blood pressure: 7-day average At least 82 mmHg',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'the picker shows a diastolic-only goal as selected and deselects it',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const criteria = GoalCriterion.metric(
        criterionId: 'bp-dia',
        dataType: GoalHealthDataTypes.bloodPressureDiastolic,
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.dailySumThenAverage,
        target: 82,
      );
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const CreateGoalAgentPage(agentId: 'goal-1'),
          overrides: overrides(editSpec: _spec(criteria: criteria)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('goal-form-add-signal')));
      await tester.pumpAndSettle();
      final source = find.byKey(
        const ValueKey('goal-form-health-source-blood-pressure'),
      );
      // The picker agrees with the row: a partial pair reads as selected.
      expect(
        tester.widget<DesignSystemSelectionRow>(source).selected,
        isTrue,
      );

      // Tapping therefore DESELECTS rather than seeding a systolic 130.
      await tester.tap(source);
      await tester.pump();
      expect(
        tester.widget<DesignSystemSelectionRow>(source).selected,
        isFalse,
      );
      await tester.tap(find.byKey(const ValueKey('goal-form-picker-done')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<DesignSystemSelectionRow>(
              find.byKey(
                const ValueKey('goal-form-health-row-blood-pressure'),
              ),
            )
            .selected,
        isFalse,
      );
      for (final dataType in [
        GoalHealthDataTypes.bloodPressureSystolic,
        GoalHealthDataTypes.bloodPressureDiastolic,
      ]) {
        expect(
          find.byKey(ValueKey('goal-form-health-target-$dataType')),
          findsNothing,
        );
      }
      expect(find.text('130'), findsNothing);
    },
  );

  testWidgets(
    'a German bookkeeping habit carrying a cadence word is demoted',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      when(habitsRepository.watchHabitDefinitions).thenAnswer(
        (_) => Stream.value([
          _habit('wiegen', 'Gewicht täglich messen'),
          _habit('heben', 'Gewicht heben'),
        ]),
      );
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const CreateGoalAgentPage(),
          overrides: overrides(),
          locale: const Locale('de'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('goal-form-intention')),
        'Gewicht verlieren',
      );
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();

      // The readings signal arrives selected…
      expect(
        tester
            .widget<DesignSystemSelectionRow>(
              find.byKey(const ValueKey('goal-form-health-row-weight')),
            )
            .selected,
        isTrue,
      );
      // …and "täglich" is a German generic cadence word, so it no longer
      // shields the bookkeeping habit from demotion.
      final bookkeeping = find.byKey(const ValueKey('goal-form-habit-wiegen'));
      expect(
        tester.widget<DesignSystemSelectionRow>(bookkeeping).selected,
        isFalse,
      );
      expect(
        tester.getRect(find.text('Vorgeschlagen')).top,
        lessThan(tester.getRect(bookkeeping).top),
      );
      // A habit with a real leftover word still keeps its selection.
      expect(
        tester
            .widget<DesignSystemSelectionRow>(
              find.byKey(const ValueKey('goal-form-habit-heben')),
            )
            .selected,
        isTrue,
      );
    },
  );

  testWidgets(
    'a newly filled blood-pressure half saves the shared direction',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const criteria = GoalCriterion.metric(
        criterionId: 'bp-dia',
        dataType: GoalHealthDataTypes.bloodPressureDiastolic,
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.dailySumThenAverage,
        target: 82,
        // Spelled out: the stored direction is what this test is about.
        // ignore: avoid_redundant_argument_values
        direction: GoalDirection.atLeast,
      );
      final current = _spec(criteria: criteria);
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

      // Filling the blank half of the pair must adopt the direction the
      // shared toggle already shows, not the atMost default.
      await tester.enterText(
        find.byKey(
          const ValueKey(
            'goal-form-health-target-'
            'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
          ),
        ),
        '128',
      );
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Systolic blood pressure: 7-day average At least 128 mmHg',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Diastolic blood pressure: 7-day average At least 82 mmHg',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Save new version'));
      await tester.pump();

      final saved =
          verify(
                () => revisionService.reviseFromOwner(
                  agentId: 'goal-1',
                  baseVersionId: current.id,
                  displayName: any(named: 'displayName'),
                  title: any(named: 'title'),
                  statement: any(named: 'statement'),
                  criteria: captureAny(named: 'criteria'),
                ),
              ).captured.single
              as GoalCriterionAllOf;
      expect(
        {
          for (final leaf in saved.criteria.whereType<GoalCriterionMetric>())
            leaf.dataType: (leaf.target, leaf.direction),
        },
        {
          GoalHealthDataTypes.bloodPressureSystolic: (
            128,
            GoalDirection.atLeast,
          ),
          GoalHealthDataTypes.bloodPressureDiastolic: (
            82,
            GoalDirection.atLeast,
          ),
        },
      );
    },
  );

  testWidgets('editing is a two-step flow with the statement inline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(agentId: 'goal-1'),
        overrides: overrides(editSpec: _spec()),
      ),
    );
    await tester.pumpAndSettle();

    // No intention page: editing lands on the consolidated mapping page
    // with the statement as a single-line field at the top.
    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.text('What do you want to work toward?'), findsNothing);
    expect(find.text('Here’s what I can watch'), findsOneWidget);
    final statementField = find.byKey(const ValueKey('goal-form-intention'));
    expect(statementField, findsOneWidget);
    final editable = tester.widget<EditableText>(
      find.descendant(
        of: statementField,
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.controller.text, 'Gym and run every week');
    expect(editable.maxLines, 1);
    // The example pills fold in under the field.
    expect(find.text('gym twice a week'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 2'), findsOneWidget);
    expect(find.text('Save new version'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 2'), findsOneWidget);
  });

  testWidgets('back from the consolidated edit page exits to goal details', (
    tester,
  ) async {
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(agentId: 'goal-1'),
        overrides: overrides(editSpec: _spec()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 2'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    expect(navigated, ['/agents/details/goal-1']);
  });

  testWidgets('editing blocks continue while the statement is empty', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(agentId: 'goal-1'),
        overrides: overrides(editSpec: _spec()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      '',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.text('Describe what you want to work toward first.'),
      findsOneWidget,
    );
    // Still on the mapping page, not the confirmation.
    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.text('Save new version'), findsNothing);

    // Typing clears the inline error.
    await tester.enterText(
      find.byKey(const ValueKey('goal-form-intention')),
      'Gym often',
    );
    await tester.pump();
    expect(
      find.text('Describe what you want to work toward first.'),
      findsNothing,
    );
  });

  testWidgets('an example pill rewrites the statement on the edit page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final current = _spec();
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
    await tester.pumpAndSettle();

    await tester.tap(find.text('gym twice a week'));
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('goal-form-intention')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'gym twice a week',
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save new version'));
    await tester.pump();

    verify(
      () => revisionService.reviseFromOwner(
        agentId: 'goal-1',
        baseVersionId: current.id,
        displayName: any(named: 'displayName'),
        title: any(named: 'title'),
        statement: 'gym twice a week',
        criteria: any(named: 'criteria'),
      ),
    ).called(1);
  });

  testWidgets('the steps input is labelled as the daily target, not a '
      'duplicate of the row title', (tester) async {
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
      'Move more every day',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('goal-form-steps-row')));
    await tester.pumpAndSettle();

    // The signal's name appears once (the row title); the target input
    // carries its own label instead of repeating it.
    expect(find.text('Average steps per day'), findsOneWidget);
    expect(find.text('Daily target'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('goal-form-steps-target')),
      findsOneWidget,
    );
  });

  GoalSpecVersionEntity threeOfThreeSpec() => _spec(
    criteria: const GoalCriterion.atLeastCount(
      criterionId: 'routine',
      successes: 3,
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
        GoalCriterion.metric(
          criterionId: 'steps',
          dataType: 'cumulative_step_count',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 9000,
        ),
      ],
    ),
  );

  testWidgets('a stale at-least count clamps on the card and Done commits '
      'the clamped rule', (tester) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(agentId: 'goal-1'),
        overrides: overrides(editSpec: threeOfThreeSpec()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('At least 3 of 3'), findsOneWidget);

    // Removing a dimension strands the stored "3 of" above a two-dimension
    // goal; the card must show the clamped promise, not an impossible one.
    await tester.tap(find.byKey(const ValueKey('goal-form-habit-run')));
    await tester.pumpAndSettle();
    expect(find.textContaining('At least 3 of 2'), findsNothing);
    expect(find.textContaining('At least 2 of 2'), findsOneWidget);

    // Done propagates the clamp to the page: re-adding the dimension keeps
    // the count the sheet showed, instead of resurrecting the stale 3.
    await tester.tap(find.widgetWithText(DesignSystemButton, 'Change'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('goal-form-composite-done')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('goal-form-habit-run')));
    await tester.pumpAndSettle();
    expect(find.textContaining('At least 2 of 3'), findsOneWidget);
  });

  testWidgets('the rule sheet scrolls on a short screen instead of clipping '
      'the stepper or Done', (tester) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CreateGoalAgentPage(agentId: 'goal-1'),
        overrides: overrides(editSpec: threeOfThreeSpec()),
      ),
    );
    await tester.pumpAndSettle();

    final changeButton = find.widgetWithText(DesignSystemButton, 'Change');
    await tester.ensureVisible(changeButton);
    // Past the pinned Continue band, which overlays the bottom edge that
    // ensureVisible stops at on a screen this short.
    await tester.drag(find.byType(ListView).first, const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(changeButton);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);

    // The at-least row (with its full-width stepper line) may start below
    // the fold of the shortened sheet; it must be reachable by scrolling,
    // not clipped by an overflowing fixed column.
    final atLeastRow = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DesignSystemSelectionRow &&
            widget.title.startsWith('At least'),
      ),
    );
    await tester.scrollUntilVisible(
      atLeastRow,
      50,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(atLeastRow);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('goal-form-composite-decrease')),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('goal-form-composite-done')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
