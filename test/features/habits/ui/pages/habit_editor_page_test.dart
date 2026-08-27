import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/habits/state/habit_editor_providers.dart';
import 'package:lotti/features/habits/state/habit_settings_controller.dart';
import 'package:lotti/features/habits/ui/pages/habit_editor_page.dart';
import 'package:lotti/features/habits/ui/widgets/editor/habit_composite_picker.dart';
import 'package:lotti/features/habits/ui/widgets/editor/habit_signal_card.dart';
import 'package:lotti/features/habits/ui/widgets/editor/habit_signal_picker.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurables_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  late TestGetItMocks mocks;
  late MockPersistenceLogic persistence;
  late MockEntitiesCacheService cache;
  late MockNotificationService notifications;
  String? beamedTo;

  final water = measurableWater.copyWith(
    id: 'water',
    displayName: 'Water',
    unitName: 'ml',
  );
  final ruledHabit = habitFlossing.copyWith(
    id: 'ruled',
    name: 'Drink water',
    autoCompleteRule: const AutoCompleteRule.and(
      rules: [
        AutoCompleteRule.measurable(dataTypeId: 'water', minimum: 1000),
        AutoCompleteRule.health(
          dataType: 'cumulative_step_count',
          minimum: 6000,
        ),
      ],
    ),
    autoCompleteNotify: false,
  );

  setUpAll(() {
    registerFallbackValue(FakeHabitDefinition());
  });

  setUp(() async {
    persistence = MockPersistenceLogic();
    cache = MockEntitiesCacheService();
    notifications = MockNotificationService();
    mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<PersistenceLogic>(persistence)
          ..registerSingleton<EntitiesCacheService>(cache)
          ..registerSingleton<NotificationService>(notifications);
      },
    );
    when(
      () => mocks.journalDb.getHabitById(any()),
    ).thenAnswer((_) async => null);
    when(
      () => mocks.journalDb.getHabitById(habitFlossing.id),
    ).thenAnswer((_) async => habitFlossing);
    when(
      () => mocks.journalDb.getHabitById(ruledHabit.id),
    ).thenAnswer((_) async => ruledHabit);
    when(() => cache.sortedCategories).thenReturn([categoryMindfulness]);
    when(() => cache.getCategoryById(any())).thenReturn(null);
    when(
      () => notifications.scheduleHabitNotification(any()),
    ).thenAnswer((_) async {});
    when(
      () => persistence.upsertEntityDefinition(any()),
    ).thenAnswer((_) async => 1);
    beamedTo = null;
    beamToNamedOverride = (path) => beamedTo = path;
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  Future<void> pumpEditor(
    WidgetTester tester, {
    String? habitId,
    String returnPath = '/habits',
  }) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        AppCommandHost(
          handlers: const <AppCommandId, AppCommandHandler>{},
          platform: TargetPlatform.windows,
          child: HabitEditorPage(habitId: habitId, returnPath: returnPath),
        ),
        mediaQueryData: const MediaQueryData(size: Size(1200, 1800)),
        overrides: [
          measurableDataTypesStreamProvider.overrideWith(
            (ref) => Stream.value([water]),
          ),
          workoutTypesProvider.overrideWith((ref) async => ['running']),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  HabitDefinition savedHabit() =>
      verify(
            () => persistence.upsertEntityDefinition(captureAny()),
          ).captured.last
          as HabitDefinition;

  group('create', () {
    testWidgets('step 1 asks for a name; Continue needs one', (tester) async {
      await pumpEditor(tester);
      expect(find.text('New habit'), findsOneWidget);
      expect(find.text('What do you want to keep doing?'), findsOneWidget);
      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(find.byType(HabitSignalCard), findsNothing);

      await tester.tap(find.byKey(const ValueKey('habit-editor-primary')));
      await tester.pump();
      // Still on step 1: the name is required.
      expect(find.byType(HabitSignalCard), findsNothing);

      await tester.enterText(find.byKey(const Key('habit_name_field')), 'Walk');
      await tester.tap(find.byKey(const ValueKey('habit-editor-primary')));
      await tester.pump();
      expect(find.text('Step 2 of 2'), findsOneWidget);
      expect(find.byType(HabitSignalCard), findsOneWidget);
      expect(find.text('Create habit'), findsOneWidget);
    });

    testWidgets('an example fills the name and pre-checks its signal', (
      tester,
    ) async {
      await pumpEditor(tester);
      await tester.tap(find.byKey(const ValueKey('habit-editor-example-1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('habit-editor-primary')));
      await tester.pump();
      expect(find.text('Steps'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('habit-signal-threshold-health-cumulative_step_count'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('habit-editor-primary')));
      await tester.pump(const Duration(milliseconds: 300));
      final saved = savedHabit();
      expect(saved.name, '6,000 steps');
      expect(
        saved.autoCompleteRule,
        const AutoCompleteRule.health(
          dataType: GoalHealthDataTypes.steps,
          minimum: 6000,
        ),
      );
      expect(beamedTo, '/habits');
    });

    testWidgets(
      'signals picked from the sheet become the rule; composite too',
      (
        tester,
      ) async {
        await pumpEditor(tester);
        await tester.enterText(
          find.byKey(const Key('habit_name_field')),
          'Hydrate',
        );
        await tester.tap(find.byKey(const ValueKey('habit-editor-primary')));
        await tester.pump();

        await tester.tap(find.byKey(const ValueKey('habit-signal-add-row')));
        await tester.pumpAndSettle();
        expect(find.byType(HabitSignalPicker), findsOneWidget);
        await tester.tap(find.text('Water'));
        await tester.pump();
        // Filter instead of scrolling: the modal is still settling its
        // transform, which a drag-based scroll would hit-test mid-layout.
        await tester.enterText(
          find.byKey(const ValueKey('habit-signal-picker-search')),
          'run',
        );
        await tester.pump();
        await tester.tap(find.text('running'));
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey('habit-signal-picker-done')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('habit-signal-composite-row')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('habit-signal-composite-row')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(HabitCompositePicker), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('habit-composite-all')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('habit-composite-done')));
        await tester.pumpAndSettle();
        expect(find.text('All signals'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('habit-editor-primary')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          savedHabit().autoCompleteRule,
          const AutoCompleteRule.and(
            rules: [
              AutoCompleteRule.measurable(dataTypeId: 'water'),
              AutoCompleteRule.workout(dataType: 'running'),
            ],
          ),
        );
      },
    );

    testWidgets('unchecking in the picker removes the signal', (tester) async {
      await pumpEditor(tester, habitId: ruledHabit.id);
      await tester.tap(find.byKey(const ValueKey('habit-signal-add-row')));
      await tester.pumpAndSettle();
      // Water is already selected; tapping it deselects.
      await tester.tap(find.text('Water').last);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('habit-signal-picker-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('habit-editor-primary')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        savedHabit().autoCompleteRule,
        const AutoCompleteRule.health(
          dataType: 'cumulative_step_count',
          minimum: 6000,
        ),
      );
    });

    testWidgets('Primary+S on step 1 does not save', (tester) async {
      await pumpEditor(tester);
      await tester.tap(find.byKey(const Key('habit_name_field')));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump(const Duration(milliseconds: 300));
      verifyNever(() => persistence.upsertEntityDefinition(any()));
    });

    testWidgets('a bounded rule without a value cannot be saved', (
      tester,
    ) async {
      await pumpEditor(tester, habitId: ruledHabit.id);
      await tester.enterText(
        find.byKey(
          const ValueKey('habit-signal-threshold-measurable-water'),
        ),
        '',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('habit-editor-primary')));
      await tester.pump(const Duration(milliseconds: 300));
      verifyNever(() => persistence.upsertEntityDefinition(any()));
      expect(find.text('Enter a value for this rule'), findsWidgets);
      expect(beamedTo, isNull);
    });

    testWidgets('a route rebuild keeps the same new-habit id and its state', (
      tester,
    ) async {
      await pumpEditor(tester);
      final first = tester.state<HabitEditorPageState>(
        find.byType(HabitEditorPage),
      );
      final firstId = first.habitId;
      await tester.enterText(find.byKey(const Key('habit_name_field')), 'Keep');
      // Beamer rebuilds the page with a fresh widget instance; the element
      // (and its state) is reused because the BeamPage key is stable.
      await pumpEditor(tester);
      final second = tester.state<HabitEditorPageState>(
        find.byType(HabitEditorPage),
      );
      expect(second.habitId, firstId);
      expect(find.text('Keep'), findsOneWidget);
    });

    testWidgets('back on step 2 returns to step 1; on step 1 leaves', (
      tester,
    ) async {
      await pumpEditor(tester);
      await tester.enterText(find.byKey(const Key('habit_name_field')), 'X');
      await tester.tap(find.byKey(const ValueKey('habit-editor-primary')));
      await tester.pump();
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(beamedTo, isNull);
      await tester.tap(find.byType(BackButton));
      expect(beamedTo, '/habits');
    });
  });

  group('edit', () {
    testWidgets('shows the existing rule, settings and options on one page', (
      tester,
    ) async {
      await pumpEditor(tester, habitId: ruledHabit.id);
      expect(find.text('Edit habit'), findsOneWidget);
      expect(find.text('Step 1 of 2'), findsNothing);
      expect(find.byType(HabitSignalCard), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('Steps'), findsOneWidget);
      expect(find.text('All signals'), findsOneWidget);
      expect(find.byKey(const Key('habit_active')), findsOneWidget);
      expect(find.byKey(const ValueKey('habit-editor-delete')), findsOneWidget);
    });

    testWidgets('toggling notify and saving persists the flag', (tester) async {
      await pumpEditor(
        tester,
        habitId: ruledHabit.id,
        returnPath: '/settings/habits',
      );
      await tester.tap(find.byKey(const ValueKey('habit-editor-notify')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('habit-editor-primary')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(savedHabit().autoCompleteNotify, isTrue);
      expect(beamedTo, '/settings/habits');
    });

    testWidgets('removing a signal saves a smaller rule', (tester) async {
      await pumpEditor(tester, habitId: ruledHabit.id);
      await tester.tap(
        find.byKey(
          const ValueKey('habit-signal-check-health-cumulative_step_count'),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('habit-editor-primary')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        savedHabit().autoCompleteRule,
        const AutoCompleteRule.measurable(dataTypeId: 'water', minimum: 1000),
      );
    });

    testWidgets('Primary+S saves', (tester) async {
      await pumpEditor(tester, habitId: ruledHabit.id);
      await tester.tap(find.byKey(const Key('habit_name_field')));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump(const Duration(milliseconds: 300));
      verify(() => persistence.upsertEntityDefinition(any())).called(1);
    });

    testWidgets('delete asks, then marks the habit deleted and leaves', (
      tester,
    ) async {
      await pumpEditor(tester, habitId: ruledHabit.id);
      await tester.tap(find.byKey(const ValueKey('habit-editor-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes, delete this habit'));
      await tester.pumpAndSettle();
      expect(savedHabit().deletedAt, isNotNull);
      expect(beamedTo, '/habits');
    });

    testWidgets('a save that throws shows a toast and stays', (tester) async {
      when(
        () => persistence.upsertEntityDefinition(any()),
      ).thenThrow(StateError('db'));
      await pumpEditor(tester, habitId: ruledHabit.id);
      await tester.tap(find.byKey(const ValueKey('habit-editor-primary')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(beamedTo, isNull);
      expect(find.byType(HabitSignalCard), findsOneWidget);
    });

    testWidgets('an unknown habit renders a titled empty scaffold', (
      tester,
    ) async {
      await pumpEditor(tester, habitId: 'missing');
      expect(find.byType(HabitSignalCard), findsNothing);
      expect(find.byKey(const ValueKey('habit-editor-primary')), findsNothing);
      expect(find.text('Edit habit'), findsOneWidget);
    });

    testWidgets('a stream error after load keeps the editor on screen', (
      tester,
    ) async {
      // The provider re-emits on journal updates; a transient failure must
      // not swap a loaded editor for the shell.
      final habits = StreamController<HabitDefinition?>.broadcast();
      addTearDown(habits.close);
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          AppCommandHost(
            handlers: const <AppCommandId, AppCommandHandler>{},
            platform: TargetPlatform.windows,
            child: HabitEditorPage(habitId: ruledHabit.id),
          ),
          mediaQueryData: const MediaQueryData(size: Size(1200, 1800)),
          overrides: [
            habitByIdProvider(
              ruledHabit.id,
            ).overrideWith((ref) => habits.stream),
            measurableDataTypesStreamProvider.overrideWith(
              (ref) => Stream.value([water]),
            ),
            workoutTypesProvider.overrideWith((ref) async => ['running']),
          ],
        ),
      );
      habits.add(ruledHabit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(HabitSignalCard), findsOneWidget);
      habits.addError(StateError('db hiccup'));
      await tester.pump();
      expect(find.byType(HabitSignalCard), findsOneWidget);
    });
  });
}
