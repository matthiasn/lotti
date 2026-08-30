import 'package:beamer/beamer.dart';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/dashboards/state/measurables_controller.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/goals/state/goal_assessment_state.dart';
import 'package:lotti/features/goals/state/goal_habit_watchers.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/features/goals/ui/goal_assessment_widgets.dart';
import 'package:lotti/features/habits/state/habit_signal_status_controller.dart';
import 'package:lotti/features/habits/ui/sheets/habit_completion_sheet.dart';
import 'package:lotti/features/habits/ui/widgets/habit_signal_row.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/signals/habit_rule_evaluator.dart';
import 'package:lotti/logic/signals/signal_window.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

class _FixedSuggestions extends MeasurableSuggestionsController {
  _FixedSuggestions() : super('water');
  @override
  Future<List<num>?> build() async => [250, 500];
}

/// A status controller fed from a mutable window so a chip tap can be
/// observed to flip the verdict.
class _FakeStatus extends HabitSignalStatusController {
  _FakeStatus(super.habitId, this.windowOf);
  final SignalWindow Function() windowOf;

  static const rule = AutoCompleteRule.measurable(
    dataTypeId: 'water',
    minimum: 500,
  );

  HabitSignalStatus _status() {
    final window = windowOf();
    return HabitSignalStatus(
      rule: rule,
      window: window,
      verdict: const HabitRuleEvaluator().evaluate(
        rule: rule,
        window: window,
        day: window.end,
      ),
      today: window.end,
    );
  }

  @override
  Future<HabitSignalStatus?> build() async => _status();

  @override
  Future<void> refresh() async => state = AsyncData(_status());
}

/// Like [_FakeStatus], for the hydration habit's any-entry choice rule.
class _ChoiceStatus extends HabitSignalStatusController {
  _ChoiceStatus(super.habitId, this.windowOf);
  final SignalWindow Function() windowOf;

  static const rule = AutoCompleteRule.measurable(dataTypeId: 'hydration');

  HabitSignalStatus _status() {
    final window = windowOf();
    return HabitSignalStatus(
      rule: rule,
      window: window,
      verdict: const HabitRuleEvaluator().evaluate(
        rule: rule,
        window: window,
        day: window.end,
      ),
      today: window.end,
    );
  }

  @override
  Future<HabitSignalStatus?> build() async => _status();

  @override
  Future<void> refresh() async => state = AsyncData(_status());
}

/// A status for a three-leaf rule — the handover's threshold for the
/// desktop sheet to lay its signal rows out two abreast.
class _TripleStatus extends HabitSignalStatusController {
  _TripleStatus(super.habitId, this.windowOf);
  final SignalWindow Function() windowOf;

  static const rule = AutoCompleteRule.and(
    rules: [
      AutoCompleteRule.measurable(dataTypeId: 'water', minimum: 500),
      AutoCompleteRule.measurable(dataTypeId: 'hydration'),
      AutoCompleteRule.measurable(dataTypeId: 'water', minimum: 250),
    ],
  );

  HabitSignalStatus _status() {
    final window = windowOf();
    return HabitSignalStatus(
      rule: rule,
      window: window,
      verdict: const HabitRuleEvaluator().evaluate(
        rule: rule,
        window: window,
        day: window.end,
      ),
      today: window.end,
    );
  }

  @override
  Future<HabitSignalStatus?> build() async => _status();

  @override
  Future<void> refresh() async => state = AsyncData(_status());
}

/// [testWidgets] under the fixed sheet clock.
void clockedWidgets(
  String description,
  Future<void> Function(WidgetTester tester) body,
) => testWidgets(
  description,
  (tester) =>
      withClock(Clock.fixed(DateTime(2026, 8, 8, 14, 30)), () => body(tester)),
);

void main() {
  late MockPersistenceLogic persistence;
  late MockEntitiesCacheService cache;

  // Every sheet runs under the clockedWidgets instant, so "today" never
  // depends on the wall clock (a run crossing midnight would otherwise
  // build the fake window for one day while the sheet evaluated another).
  final todayKey = DateTime.utc(2026, 8, 8);
  final water = measurableWater.copyWith(
    id: 'water',
    displayName: 'Water',
    unitName: 'ml',
  );
  final waterHabit = habitFlossing.copyWith(
    id: 'water-habit',
    name: 'Drink water',
    autoCompleteRule: _FakeStatus.rule,
  );
  final hydration = measurableHydration.copyWith(id: 'hydration');
  final hydrationHabit = habitFlossing.copyWith(
    id: 'hydration-habit',
    name: 'Check hydration',
    autoCompleteRule: _ChoiceStatus.rule,
  );
  final tripleHabit = habitFlossing.copyWith(
    id: 'triple-habit',
    name: 'Three signals',
    autoCompleteRule: _TripleStatus.rule,
  );
  var waterToday = <DateTime, num>{};
  var hydrationToday = <DateTime, num>{};

  SignalWindow window() => SignalWindow(
    start: todayKey.subtract(const Duration(days: 13)),
    end: todayKey,
    measurableTotalsByDay: {
      'water': Map.of(waterToday),
      'hydration': Map.of(hydrationToday),
    },
  );

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    persistence = MockPersistenceLogic();
    cache = MockEntitiesCacheService();
    waterToday = {};
    hydrationToday = {};
    when(() => cache.getHabitById(habitFlossing.id)).thenReturn(habitFlossing);
    when(() => cache.getHabitById(waterHabit.id)).thenReturn(waterHabit);
    when(
      () => cache.getHabitById(hydrationHabit.id),
    ).thenReturn(hydrationHabit);
    when(() => cache.getDataTypeById('hydration')).thenReturn(hydration);
    when(() => cache.getHabitById(tripleHabit.id)).thenReturn(tripleHabit);
    when(() => cache.getHabitById('missing')).thenReturn(null);
    when(() => cache.getDataTypeById('water')).thenReturn(water);
    when(
      () => persistence.createHabitCompletionEntry(
        data: any(named: 'data'),
        comment: any(named: 'comment'),
        habitDefinition: any(named: 'habitDefinition'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => persistence.createMeasurementEntry(
        data: any(named: 'data'),
        private: any(named: 'private'),
      ),
    ).thenAnswer((invocation) async {
      final data = invocation.namedArguments[#data] as MeasurementData;
      // Bucket like the reader does: one total per calendar day.
      waterToday[todayKey] = (waterToday[todayKey] ?? 0) + data.value;
      return JournalEntity.measurement(
            meta: Metadata(
              id: 'm-${data.value}',
              createdAt: data.dateFrom,
              updatedAt: data.dateFrom,
              dateFrom: data.dateFrom,
              dateTo: data.dateTo,
            ),
            data: data,
          )
          as MeasurementEntry;
    });
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(
            mockJournalDbWithHabits([habitFlossing]),
          )
          ..registerSingleton<EntitiesCacheService>(cache)
          ..registerSingleton<PersistenceLogic>(persistence);
      },
    );
  });
  tearDown(tearDownTestGetIt);

  Future<void> pumpSheet(
    WidgetTester tester, {
    String? habitId,
    String? dateString,
    List<Override> overrides = const [],
    Size viewport = const Size(800, 1400),
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final delegate = BeamerDelegate(
      locationBuilder: RoutesLocationBuilder(
        routes: {'/': (context, state, data) => Container()},
      ).call,
    );
    await tester.pumpWidget(
      makeTestableWidget(
        BeamerProvider(
          routerDelegate: delegate,
          child: AppCommandHost(
            handlers: const {},
            // A Scaffold, as in the app: the failed-write snackbar needs one.
            // Bounded, because the harness scrolls its child.
            child: SizedBox(
              height: 1300,
              child: Scaffold(
                body: HabitCompletionSheet(
                  habitId: habitId ?? habitFlossing.id,
                  themeData: resolveTestTheme(),
                  dateString: dateString,
                ),
              ),
            ),
          ),
        ),
        mediaQueryData: MediaQueryData(size: viewport),
        overrides: [
          measurableSuggestionsControllerProvider(
            'water',
          ).overrideWith(_FixedSuggestions.new),
          habitSignalStatusProvider(
            waterHabit.id,
          ).overrideWith(() => _FakeStatus(waterHabit.id, window)),
          habitSignalStatusProvider(
            hydrationHabit.id,
          ).overrideWith(() => _ChoiceStatus(hydrationHabit.id, window)),
          habitSignalStatusProvider(
            tripleHabit.id,
          ).overrideWith(() => _TripleStatus(tripleHabit.id, window)),
          ...overrides,
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  HabitCompletionData captured() =>
      verify(
            () => persistence.createHabitCompletionEntry(
              data: captureAny(named: 'data'),
              comment: any(named: 'comment'),
              habitDefinition: any(named: 'habitDefinition'),
            ),
          ).captured.single
          as HabitCompletionData;

  group('recording', () {
    clockedWidgets('Record persists a success completion by default', (
      tester,
    ) async {
      await pumpSheet(tester);
      expect(find.text(habitFlossing.name), findsOneWidget);
      await tester.tap(find.byKey(const Key('habit_save')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(captured().completionType, HabitCompletionType.success);
    });

    for (final (label, type) in [
      ('Skip', HabitCompletionType.skip),
      ('Missed', HabitCompletionType.fail),
    ]) {
      clockedWidgets('selecting $label then Record persists it', (
        tester,
      ) async {
        await pumpSheet(tester);
        await tester.tap(find.text(label).first);
        await tester.pump();
        await tester.tap(find.byKey(const Key('habit_save')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(captured().completionType, type);
      });
    }

    clockedWidgets('a comment is persisted with the completion', (
      tester,
    ) async {
      await pumpSheet(tester);
      await tester.enterText(
        find.byKey(const Key('habit_comment_field')),
        'felt great',
      );
      await tester.tap(find.byKey(const Key('habit_save')));
      await tester.pump(const Duration(milliseconds: 300));
      verify(
        () => persistence.createHabitCompletionEntry(
          data: any(named: 'data'),
          comment: 'felt great',
          habitDefinition: habitFlossing,
        ),
      ).called(1);
    });

    clockedWidgets('Primary+S records through the command scope', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await pumpSheet(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump(const Duration(milliseconds: 300));
        expect(captured().completionType, HabitCompletionType.success);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    clockedWidgets('a past dateString records at the end of that day', (
      tester,
    ) async {
      await pumpSheet(tester, dateString: '2024-01-15');
      expect(find.text('2024-01-15 23:59'), findsOneWidget);
      await tester.tap(find.byKey(const Key('habit_save')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(captured().dateFrom, DateTime(2024, 1, 15, 23, 59, 59));
    });

    clockedWidgets('picking a date moves the recorded start', (tester) async {
      await pumpSheet(tester);
      tester
          .widget<DateTimeField>(find.byType(DateTimeField))
          .setDateTime(DateTime(2024, 6, 1, 9, 30));
      await tester.pump();
      expect(find.textContaining('09:30'), findsAtLeastNWidgets(1));
      await tester.tap(find.byKey(const Key('habit_save')));
      await tester.pump(const Duration(milliseconds: 300));
      final data = captured();
      expect(data.dateFrom, DateTime(2024, 6, 1, 9, 30));
      expect(data.dateTo, DateTime(2024, 6, 1, 9, 30));
    });

    clockedWidgets('close dismisses without recording', (tester) async {
      await pumpSheet(tester);
      await tester.tap(find.bySemanticsLabel('Close habit completion'));
      await tester.pumpAndSettle();
      expect(find.byType(HabitCompletionSheet), findsNothing);
      verifyNever(
        () => persistence.createHabitCompletionEntry(
          data: any(named: 'data'),
          comment: any(named: 'comment'),
          habitDefinition: any(named: 'habitDefinition'),
        ),
      );
    });

    clockedWidgets('shown as a sheet: the scrim dismisses, the form does not', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        makeTestableWidget(
          // Bounded: the harness scrolls its child.
          SizedBox(
            height: 1300,
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => HabitCompletionSheet.show(
                      context,
                      habitId: habitFlossing.id,
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(HabitCompletionSheet), findsOneWidget);

      // A tap on the form keeps the sheet.
      await tester.tap(find.text(habitFlossing.name));
      await tester.pumpAndSettle();
      expect(find.byType(HabitCompletionSheet), findsOneWidget);

      // A tap on the transparent area above the form dismisses it.
      await tester.tapAt(const Offset(400, 20));
      await tester.pumpAndSettle();
      expect(find.byType(HabitCompletionSheet), findsNothing);
      verifyNever(
        () => persistence.createHabitCompletionEntry(
          data: any(named: 'data'),
          comment: any(named: 'comment'),
          habitDefinition: any(named: 'habitDefinition'),
        ),
      );
    });

    clockedWidgets('the edit action closes the sheet and opens the editor', (
      tester,
    ) async {
      String? beamedTo;
      beamToNamedOverride = (path) => beamedTo = path;
      addTearDown(() => beamToNamedOverride = null);
      await pumpSheet(tester);
      await tester.tap(find.byKey(const ValueKey('habit-sheet-edit')));
      await tester.pumpAndSettle();
      expect(beamedTo, '/habits/edit/${habitFlossing.id}');
      expect(find.byType(HabitCompletionSheet), findsNothing);
    });

    clockedWidgets('renders nothing for an unknown habit', (tester) async {
      await pumpSheet(tester, habitId: 'missing');
      expect(find.byKey(const Key('habit_save')), findsNothing);
    });
  });

  group('signals', () {
    const columnsKey = ValueKey('habit-sheet-signal-columns');
    List<Rect> signalRects(WidgetTester tester) => [
      for (final element in find.byType(HabitSignalRow).evaluate())
        tester.getRect(find.byWidget(element.widget)),
    ];

    clockedWidgets(
      'three signals on a desktop window go two abreast in a wider card, '
      'the unpaired last row spanning both',
      (tester) async {
        await pumpSheet(
          tester,
          habitId: tripleHabit.id,
          viewport: const Size(kDesktopBreakpoint, 1400),
        );
        expect(find.byKey(columnsKey), findsOneWidget);
        expect(find.byType(HabitSignalRow), findsNWidgets(3));
        final rows = signalRects(tester);
        expect(rows[0].top, rows[1].top, reason: 'first pair shares a line');
        expect(rows[1].left, greaterThan(rows[0].right));
        expect(rows[2].top, greaterThan(rows[0].bottom));
        expect(rows[2].left, rows[0].left);
        expect(rows[2].right, rows[1].right, reason: 'odd row spans both');
        expect(
          tester.getSize(find.byType(Card)).width,
          kHabitCompletionSheetWideWidth,
        );
      },
    );

    clockedWidgets('three signals on a phone-width window stay stacked', (
      tester,
    ) async {
      await pumpSheet(tester, habitId: tripleHabit.id);
      expect(find.byKey(columnsKey), findsNothing);
      final rows = signalRects(tester);
      expect(rows[1].top, greaterThan(rows[0].bottom));
      expect(rows[2].top, greaterThan(rows[1].bottom));
      expect(
        tester.getSize(find.byType(Card)).width,
        kHabitCompletionSheetWidth,
      );
    });

    clockedWidgets('one signal on a desktop window keeps the narrow card', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        habitId: waterHabit.id,
        viewport: const Size(kDesktopBreakpoint, 1400),
      );
      expect(find.byKey(columnsKey), findsNothing);
      expect(
        tester.getSize(find.byType(Card)).width,
        kHabitCompletionSheetWidth,
      );
    });

    clockedWidgets('a habit without a rule shows no signal rows', (
      tester,
    ) async {
      await pumpSheet(tester);
      expect(find.byType(HabitSignalRow), findsNothing);
    });

    clockedWidgets("one row per leaf, from the habit's own rule", (
      tester,
    ) async {
      await pumpSheet(tester, habitId: waterHabit.id);
      expect(find.byType(HabitSignalRow), findsOneWidget);
      expect(find.text('≥ 500 ml · not yet'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('habit-sheet-auto-banner')),
        findsNothing,
      );
    });

    clockedWidgets(
      'a chip writes the measurement at once; meeting the rule flips the '
      'outcome to Success and shows the banner, sheet stays open',
      (tester) async {
        await pumpSheet(tester, habitId: waterHabit.id);
        await tester.tap(find.text('Skip').first);
        await tester.pump();

        await tester.tap(find.text('500 ml'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        verify(
          () => persistence.createMeasurementEntry(
            data: any(named: 'data'),
            private: false,
          ),
        ).called(1);
        expect(find.text('≥ 500 ml · done'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('habit-sheet-auto-banner')),
          findsOneWidget,
        );
        expect(find.byType(HabitCompletionSheet), findsOneWidget);

        // The user had picked Skip themselves; a chip never overrides that.
        await tester.tap(find.byKey(const Key('habit_save')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(captured().completionType, HabitCompletionType.skip);
      },
    );

    clockedWidgets(
      'an untouched outcome flips to Success when the rule is met',
      (
        tester,
      ) async {
        await pumpSheet(tester, habitId: waterHabit.id);
        await tester.tap(find.text('250 ml'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('≥ 500 ml · 250 so far'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('habit-sheet-auto-banner')),
          findsNothing,
        );

        await tester.tap(find.text('500 ml'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.byKey(const ValueKey('habit-sheet-auto-banner')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('habit_save')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(captured().completionType, HabitCompletionType.success);
      },
    );

    clockedWidgets(
      'a choice chip records one occurrence of the choice, marks the row '
      'done and the chip selected',
      (tester) async {
        MeasurementData? saved;
        when(
          () => persistence.createMeasurementEntry(
            data: any(named: 'data'),
            private: any(named: 'private'),
          ),
        ).thenAnswer((invocation) async {
          saved = invocation.namedArguments[#data] as MeasurementData;
          hydrationToday[todayKey] = (hydrationToday[todayKey] ?? 0) + 1;
          return testMeasurementHydrationEntry;
        });

        await pumpSheet(tester, habitId: hydrationHabit.id);
        expect(find.text('any entry · not yet'), findsOneWidget);
        expect(find.text('Pale'), findsOneWidget);
        expect(find.text('Brown'), findsNothing);

        await tester.tap(find.text('Pale'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(saved, isNotNull);
        expect(saved!.dataTypeId, 'hydration');
        expect(saved!.choiceId, hydrationPale.id);
        expect(saved!.value, 1);
        expect(find.text('any entry · done'), findsOneWidget);
        expect(find.text('today: logged'), findsOneWidget);
        final paleChip = tester.widget<DsPill>(
          find.byKey(
            const ValueKey('habit-quick-record-hydration-hydration-pale'),
          ),
        );
        expect(paleChip.selected, isTrue);
      },
    );

    clockedWidgets('a failed measurement write leaves the chip unrecorded', (
      tester,
    ) async {
      when(
        () => persistence.createMeasurementEntry(
          data: any(named: 'data'),
          private: any(named: 'private'),
        ),
      ).thenAnswer((_) async => null);
      await pumpSheet(tester, habitId: waterHabit.id);
      await tester.tap(find.text('500 ml'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('≥ 500 ml · not yet'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('habit-sheet-auto-banner')),
        findsNothing,
      );
      expect(find.text("That didn't save — please try again."), findsOneWidget);
    });

    clockedWidgets('picking a past day in the field hides the signal rows', (
      tester,
    ) async {
      await pumpSheet(tester, habitId: waterHabit.id);
      expect(find.byType(HabitSignalRow), findsOneWidget);
      tester
          .widget<DateTimeField>(find.byType(DateTimeField))
          .setDateTime(DateTime(2026, 8, 1, 9));
      await tester.pump();
      expect(find.byType(HabitSignalRow), findsNothing);
    });

    clockedWidgets('Other opens the full measurement capture', (tester) async {
      await pumpSheet(tester, habitId: waterHabit.id);
      await tester.tap(find.text('Other'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Water'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    clockedWidgets('a past day shows no signal rows', (tester) async {
      await pumpSheet(tester, habitId: waterHabit.id, dateString: '2024-01-15');
      expect(find.byType(HabitSignalRow), findsNothing);
    });
  });

  group('HabitDescription', () {
    late MockUrlLauncher mockUrlLauncher;
    late UrlLauncherPlatform originalPlatform;

    setUp(() {
      originalPlatform = UrlLauncherPlatform.instance;
      mockUrlLauncher = MockUrlLauncher();
      UrlLauncherPlatform.instance = mockUrlLauncher;
      registerFallbackValue(FakeLaunchOptions());
    });

    tearDown(() {
      UrlLauncherPlatform.instance = originalPlatform;
    });

    Future<Linkify> pumpDescription(WidgetTester tester, String text) async {
      await tester.pumpWidget(
        makeTestableWidget(
          Material(
            child: HabitDescription(habitFlossing.copyWith(description: text)),
          ),
        ),
      );
      await tester.pump();
      return tester.widget<Linkify>(find.byType(Linkify));
    }

    testWidgets('renders the description text', (tester) async {
      await pumpDescription(tester, habitFlossing.description);
      expect(find.textContaining(habitFlossing.description), findsOneWidget);
    });

    testWidgets('a launchable link opens through url_launcher', (tester) async {
      when(
        () => mockUrlLauncher.canLaunch(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockUrlLauncher.launchUrl(any(), any()),
      ).thenAnswer((_) async => true);
      final linkify = await pumpDescription(tester, 'See https://example.com');
      linkify.onOpen!(LinkableElement('example', 'https://example.com'));
      await tester.pump();
      verify(
        () => mockUrlLauncher.launchUrl('https://example.com', any()),
      ).called(1);
    });

    testWidgets('an unlaunchable link is logged, never thrown', (tester) async {
      when(
        () => mockUrlLauncher.canLaunch(any()),
      ).thenAnswer((_) async => false);
      final linkify = await pumpDescription(tester, 'See https://bad.url');
      await expectLater(
        () => linkify.onOpen!(LinkableElement('bad', 'https://bad.url')),
        returnsNormally,
      );
      verifyNever(() => mockUrlLauncher.launchUrl(any(), any()));
    });
  });
  group('reflecting in a watching goal', () {
    GoalHabitWatcher watcher(String agentId) => (
      identity:
          AgentDomainEntity.agent(
                id: agentId,
                agentId: agentId,
                kind: AgentKinds.goalAgent,
                displayName: 'Fitness',
                lifecycle: AgentLifecycle.active,
                mode: AgentInteractionMode.autonomous,
                allowedCategoryIds: const {},
                currentStateId: '$agentId:state',
                config: const AgentConfig(),
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
                vectorClock: null,
              )
              as AgentIdentityEntity,
      spec:
          AgentDomainEntity.goalSpecVersion(
                id: '$agentId:spec',
                agentId: agentId,
                version: 1,
                status: GoalSpecVersionStatus.active,
                authoredBy: 'user',
                title: 'Fitness',
                statement: 'Floss daily.',
                criteria: GoalCriterion.habit(
                  criterionId: 'c-floss',
                  habitId: habitFlossing.id,
                  window: const GoalWindow.rollingDays(count: 7),
                  targetCount: 4,
                ),
                createdAt: DateTime(2026),
                vectorClock: null,
              )
              as GoalSpecVersionEntity,
      criterionId: 'c-floss',
    );

    GoalProgressView progress() => GoalProgressView(
      today: todayKey,
      habits: [
        GoalHabitProgressView(
          habitId: habitFlossing.id,
          criterionId: 'c-floss',
          name: habitFlossing.name,
          targetCount: 4,
          successfulWeeks: 0,
          days: [
            for (var offset = 6; offset >= 0; offset--)
              GoalProgressDay(
                day: todayKey.subtract(Duration(days: offset)),
                value: 0,
              ),
          ],
        ),
      ],
    );

    clockedWidgets('a habit no goal watches offers no reflection', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        overrides: [
          goalsWatchingHabitProvider(
            habitFlossing.id,
          ).overrideWith((ref) async => const []),
        ],
      );
      expect(
        find.byKey(const ValueKey('habit-sheet-reflections')),
        findsNothing,
      );
    });

    clockedWidgets("one action per watching goal opens that goal's "
        'reflection for the day being recorded', (tester) async {
      await pumpSheet(
        tester,
        dateString: '2026-08-06',
        overrides: [
          goalsWatchingHabitProvider(
            habitFlossing.id,
          ).overrideWith((ref) async => [watcher('g1')]),
          // The sheet asks for a span reaching the picked day (2 days back
          // → the seven-day floor).
          goalAgentProgressViewForSpanProvider((
            agentId: 'g1',
            historyDays: 7,
          )).overrideWith((ref) async => progress()),
          goalAssessmentHistoryProvider(
            'g1',
          ).overrideWith((ref) async => const []),
        ],
      );
      await tester.pump();
      expect(find.text('Reflect on this day in Fitness'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('habit-reflect-g1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final sheet = tester.widget<GoalDayAssessmentSheet>(
        find.byType(GoalDayAssessmentSheet),
      );
      expect(sheet.agentId, 'g1');
      expect(sheet.specVersionId, 'g1:spec');
      // The day the habit sheet was opened for — a backfilled day judges
      // that day, not today.
      expect(DateUtils.dateOnly(sheet.day), DateTime(2026, 8, 6));
    });
    clockedWidgets('a backfilled day far back asks for a projection that '
        'reaches it', (tester) async {
      await pumpSheet(
        tester,
        dateString: '2026-07-20',
        overrides: [
          goalsWatchingHabitProvider(
            habitFlossing.id,
          ).overrideWith((ref) async => [watcher('g1')]),
          // 19 days back plus the day itself.
          goalAgentProgressViewForSpanProvider((
            agentId: 'g1',
            historyDays: 20,
          )).overrideWith((ref) async => progress()),
          goalAssessmentHistoryProvider(
            'g1',
          ).overrideWith((ref) async => const []),
        ],
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('habit-reflect-g1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(GoalDayAssessmentSheet), findsOneWidget);
    });

    test('reflectionSpanDays covers the day and never drops below a week', () {
      final today = DateTime(2026, 8, 8, 14);
      expect(reflectionSpanDays(from: today, today: today), 7);
      expect(
        reflectionSpanDays(from: DateTime(2026, 8, 6, 23), today: today),
        7,
      );
      expect(reflectionSpanDays(from: DateTime(2026, 8), today: today), 8);
      expect(reflectionSpanDays(from: DateTime(2026, 7, 20), today: today), 20);
    });
  });
}
