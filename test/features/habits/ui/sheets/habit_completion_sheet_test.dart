import 'package:beamer/beamer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/state/measurables_controller.dart';
import 'package:lotti/features/habits/state/habit_signal_status_controller.dart';
import 'package:lotti/features/habits/ui/sheets/habit_completion_sheet.dart';
import 'package:lotti/features/habits/ui/widgets/habit_signal_row.dart';
import 'package:lotti/features/keyboard/ui/app_command_host.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/signals/habit_rule_evaluator.dart';
import 'package:lotti/logic/signals/signal_window.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:mocktail/mocktail.dart';

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

void main() {
  late MockPersistenceLogic persistence;
  late MockEntitiesCacheService cache;

  final todayKey = DateTime.utc(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
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
  var waterToday = <DateTime, num>{};

  SignalWindow window() => SignalWindow(
    start: todayKey.subtract(const Duration(days: 13)),
    end: todayKey,
    measurableTotalsByDay: {'water': Map.of(waterToday)},
  );

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    persistence = MockPersistenceLogic();
    cache = MockEntitiesCacheService();
    waterToday = {};
    when(() => cache.getHabitById(habitFlossing.id)).thenReturn(habitFlossing);
    when(() => cache.getHabitById(waterHabit.id)).thenReturn(waterHabit);
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
      return null;
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
  }) async {
    tester.view.physicalSize = const Size(800, 1400);
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
            child: Material(
              child: HabitCompletionSheet(
                habitId: habitId ?? habitFlossing.id,
                themeData: resolveTestTheme(),
                dateString: dateString,
              ),
            ),
          ),
        ),
        overrides: [
          measurableSuggestionsControllerProvider(
            'water',
          ).overrideWith(_FixedSuggestions.new),
          habitSignalStatusProvider(
            waterHabit.id,
          ).overrideWith(() => _FakeStatus(waterHabit.id, window)),
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
    testWidgets('Record persists a success completion by default', (
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
      testWidgets('selecting $label then Record persists it', (tester) async {
        await pumpSheet(tester);
        await tester.tap(find.text(label).first);
        await tester.pump();
        await tester.tap(find.byKey(const Key('habit_save')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(captured().completionType, type);
      });
    }

    testWidgets('a comment is persisted with the completion', (tester) async {
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

    testWidgets('Primary+S records through the command scope', (tester) async {
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

    testWidgets('a past dateString records at the end of that day', (
      tester,
    ) async {
      await pumpSheet(tester, dateString: '2024-01-15');
      expect(find.text('2024-01-15 23:59'), findsOneWidget);
      await tester.tap(find.byKey(const Key('habit_save')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(captured().dateFrom, DateTime(2024, 1, 15, 23, 59, 59));
    });

    testWidgets('picking a date moves the recorded start', (tester) async {
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

    testWidgets('close dismisses without recording', (tester) async {
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

    testWidgets('renders nothing for an unknown habit', (tester) async {
      await pumpSheet(tester, habitId: 'missing');
      expect(find.byKey(const Key('habit_save')), findsNothing);
    });
  });

  group('signals', () {
    testWidgets('a habit without a rule shows no signal rows', (tester) async {
      await pumpSheet(tester);
      expect(find.byType(HabitSignalRow), findsNothing);
    });

    testWidgets("one row per leaf, from the habit's own rule", (tester) async {
      await pumpSheet(tester, habitId: waterHabit.id);
      expect(find.byType(HabitSignalRow), findsOneWidget);
      expect(find.text('≥ 500 ml · not yet'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('habit-sheet-auto-banner')),
        findsNothing,
      );
    });

    testWidgets(
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

    testWidgets('an untouched outcome flips to Success when the rule is met', (
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
    });

    testWidgets('a past day shows no signal rows', (tester) async {
      await pumpSheet(tester, habitId: waterHabit.id, dateString: '2024-01-15');
      expect(find.byType(HabitSignalRow), findsNothing);
    });
  });
}
