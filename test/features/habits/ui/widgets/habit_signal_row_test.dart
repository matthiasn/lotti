import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/dashboards/state/measurables_controller.dart';
import 'package:lotti/features/habits/state/habit_signal_status_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habit_signal_row.dart';
import 'package:lotti/features/habits/ui/widgets/measurable_quick_record_chips.dart';
import 'package:lotti/features/habits/ui/widgets/signal_sparkline.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/signals/habit_rule_evaluator.dart';
import 'package:lotti/logic/signals/signal_window.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../logic/signals/signal_test_fixtures.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

class _FixedSuggestions extends MeasurableSuggestionsController {
  _FixedSuggestions() : super('water');
  @override
  Future<List<num>?> build() async => [250, 500];
}

void main() {
  late MockEntitiesCacheService cache;
  final todayKey = DateTime.utc(2026, 8, 8);
  final water = measurableWater.copyWith(
    id: 'water',
    displayName: 'Water',
    unitName: 'ml',
  );

  setUp(() async {
    cache = MockEntitiesCacheService();
    when(() => cache.getDataTypeById('water')).thenReturn(water);
    when(
      () => cache.getDataTypeById('hydration'),
    ).thenReturn(measurableHydration.copyWith(id: 'hydration'));
    when(() => cache.getHabitById(any())).thenReturn(null);
    await setUpTestGetIt(
      additionalSetup: () =>
          getIt.registerSingleton<EntitiesCacheService>(cache),
    );
  });
  tearDown(tearDownTestGetIt);

  HabitSignalStatus status(AutoCompleteRule rule, SignalWindow window) =>
      HabitSignalStatus(
        rule: rule,
        window: window,
        verdict: const HabitRuleEvaluator().evaluate(
          rule: rule,
          window: window,
          day: todayKey,
        ),
        today: todayKey,
      );

  SignalWindow window({
    Map<String, Map<DateTime, num>> measurables = const {},
    Map<String, Map<DateTime, num>> quantitative = const {},
    Map<String, Map<DateTime, List<WorkoutData>>> workouts = const {},
  }) => SignalWindow(
    start: DateTime.utc(2026, 7, 26),
    end: todayKey,
    measurableTotalsByDay: measurables,
    quantitativeByDay: quantitative,
    workoutsByDay: workouts,
  );

  final recorded = <(String, MeasurableQuickValue)>[];
  final more = <String>[];

  Future<void> pump(
    WidgetTester tester,
    AutoCompleteRule rule,
    SignalWindow w, {
    MeasurableQuickValue? recordedValue,
  }) {
    recorded.clear();
    more.clear();
    final s = status(rule, w);
    return tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        HabitSignalRow(
          leaf: s.verdict.leaves.single,
          status: s,
          recordedValue: recordedValue,
          onRecordMeasurable: (dt, v) => recorded.add((dt.id, v)),
          onMoreMeasurable: (dt) => more.add(dt.id),
        ),
        overrides: [
          measurableSuggestionsControllerProvider(
            'water',
          ).overrideWith(_FixedSuggestions.new),
        ],
      ),
    );
  }

  group('measurable', () {
    const anyEntry = AutoCompleteRule.measurable(dataTypeId: 'water');
    const threshold = AutoCompleteRule.measurable(
      dataTypeId: 'water',
      minimum: 1000,
    );

    testWidgets('names the measurable, unit and "any entry · not yet"', (
      tester,
    ) async {
      await pump(tester, anyEntry, window());
      await tester.pump();
      expect(find.textContaining('Water'), findsOneWidget);
      expect(find.text('any entry · not yet'), findsOneWidget);
      expect(find.text('today: —'), findsOneWidget);
      expect(find.byType(MeasurableQuickRecordChips), findsOneWidget);
      expect(find.byType(SignalSparkline), findsOneWidget);
    });

    testWidgets('a threshold shows progress, then done', (tester) async {
      await pump(
        tester,
        threshold,
        window(
          measurables: {
            'water': {todayKey: 750},
          },
        ),
      );
      await tester.pump();
      expect(find.text('≥ 1,000 ml · 750 so far'), findsOneWidget);
      // The pill already states the reading; the caption would repeat it.
      expect(find.textContaining('today:'), findsNothing);

      await pump(
        tester,
        threshold,
        window(
          measurables: {
            'water': {todayKey: 1250},
          },
        ),
      );
      await tester.pump();
      expect(find.text('≥ 1,000 ml · done'), findsOneWidget);
    });

    testWidgets('chips record through the row callbacks', (tester) async {
      await pump(
        tester,
        anyEntry,
        window(),
        recordedValue: (value: 500, choiceId: null),
      );
      await tester.pump();
      await tester.tap(find.text('250 ml'));
      expect(recorded, [('water', (value: 250, choiceId: null))]);
      await tester.tap(find.text('Other'));
      expect(more, ['water']);
    });

    testWidgets(
      'a choice measurable shows no unit, says "logged" for today, and '
      'records the tapped choice',
      (tester) async {
        const rule = AutoCompleteRule.measurable(dataTypeId: 'hydration');
        await pump(
          tester,
          rule,
          window(
            measurables: {
              'hydration': {todayKey: 1},
            },
          ),
        );
        await tester.pump();

        expect(find.text('Hydration'), findsOneWidget);
        expect(find.text('any entry · done'), findsOneWidget);
        // Never the occurrence count that backs the day value.
        expect(find.text('today: logged'), findsOneWidget);
        expect(find.textContaining('today: 1'), findsNothing);

        await tester.tap(find.text('Pale'));
        expect(recorded, [
          ('hydration', (value: 1, choiceId: hydrationPale.id)),
        ]);
      },
    );

    testWidgets('a choice measurable with nothing today says so', (
      tester,
    ) async {
      const rule = AutoCompleteRule.measurable(dataTypeId: 'hydration');
      await pump(tester, rule, window());
      await tester.pump();
      expect(find.text('any entry · not yet'), findsOneWidget);
      expect(find.text('today: —'), findsOneWidget);
    });

    testWidgets('the sparkline carries one value per window day', (
      tester,
    ) async {
      await pump(
        tester,
        anyEntry,
        window(
          measurables: {
            'water': {todayKey: 300, DateTime.utc(2026, 8): 900},
          },
        ),
      );
      await tester.pump();
      final spark = tester.widget<SignalSparkline>(
        find.byType(SignalSparkline),
      );
      expect(spark.values, hasLength(14));
      expect(spark.values.last, 300);
      expect(spark.values[6], 900);
      expect(spark.values.first, isNull);
    });
  });

  group('health and workout', () {
    testWidgets('steps read from the config name with "any reading"', (
      tester,
    ) async {
      const steps = AutoCompleteRule.health(
        dataType: 'cumulative_step_count',
        minimum: 6000,
      );
      await pump(
        tester,
        steps,
        window(
          quantitative: {
            'cumulative_step_count': {todayKey: 4120},
          },
        ),
      );
      await tester.pump();
      expect(find.text('≥ 6,000 steps · 4,120 so far'), findsOneWidget);
      expect(find.byType(MeasurableQuickRecordChips), findsNothing);
    });

    testWidgets('a workout counts sessions, or its dimension with a unit', (
      tester,
    ) async {
      final run = workoutEntity(
        DateTime(2026, 8, 8, 7),
        length: const Duration(minutes: 30),
        distance: 5000,
      );
      final w = window(
        workouts: {
          'running': {
            todayKey: [(run as WorkoutEntry).data],
          },
        },
      );
      await pump(
        tester,
        const AutoCompleteRule.workout(dataType: 'running'),
        w,
      );
      await tester.pump();
      expect(find.text('any workout · done'), findsOneWidget);

      await pump(
        tester,
        const AutoCompleteRule.workout(
          dataType: 'running',
          minimum: 5,
          valueType: WorkoutValueType.distance,
        ),
        w,
      );
      await tester.pump();
      expect(find.text('≥ 5 km · done'), findsOneWidget);
      expect(find.text('today: 5 km'), findsOneWidget);
    });
  });

  group('other leaves', () {
    testWidgets('a habit leaf names the habit and marks a done day', (
      tester,
    ) async {
      when(() => cache.getHabitById('floss')).thenReturn(
        habitFlossing.copyWith(id: 'floss', name: 'Floss'),
      );
      final w = SignalWindow(
        start: DateTime.utc(2026, 7, 26),
        end: todayKey,
        habitSuccessDays: {
          'floss': {todayKey, DateTime.utc(2026, 8, 3)},
        },
      );
      await pump(tester, const AutoCompleteRule.habit(habitId: 'floss'), w);
      await tester.pump();
      expect(find.text('Floss'), findsOneWidget);
      expect(find.text('habit done · done'), findsOneWidget);
      final spark = tester.widget<SignalSparkline>(
        find.byType(SignalSparkline),
      );
      expect(spark.values.last, 1);
      expect(spark.values[8], 1);
      expect(spark.values.first, isNull);
    });

    testWidgets('workout duration and energy use minutes and kcal', (
      tester,
    ) async {
      final run = workoutEntity(
        DateTime(2026, 8, 8, 7),
        length: const Duration(minutes: 30),
        energy: 320,
      );
      final w = window(
        workouts: {
          'running': {
            todayKey: [(run as WorkoutEntry).data],
          },
        },
      );
      await pump(
        tester,
        const AutoCompleteRule.workout(
          dataType: 'running',
          minimum: 45,
          valueType: WorkoutValueType.duration,
        ),
        w,
      );
      await tester.pump();
      expect(find.text('≥ 45 min · 30 so far'), findsOneWidget);
      await pump(
        tester,
        const AutoCompleteRule.workout(
          dataType: 'running',
          minimum: 300,
          valueType: WorkoutValueType.energy,
        ),
        w,
      );
      await tester.pump();
      expect(find.text('≥ 300 kcal · done'), findsOneWidget);
    });

    testWidgets('a maximum rule reads with ≤', (tester) async {
      await pump(
        tester,
        const AutoCompleteRule.measurable(dataTypeId: 'water', maximum: 2),
        window(
          measurables: {
            'water': {todayKey: 3},
          },
        ),
      );
      await tester.pump();
      expect(find.text('≤ 2 ml · 3 so far'), findsOneWidget);
    });

    testWidgets('a composite handed in as a leaf gets a stable key', (
      tester,
    ) async {
      const composite = AutoCompleteRule.and(rules: []);
      final s = HabitSignalStatus(
        rule: composite,
        window: window(),
        verdict: const HabitRuleVerdict(
          satisfied: true,
          leaves: [
            HabitLeafVerdict(rule: composite, satisfied: true, present: true),
          ],
        ),
        today: todayKey,
      );
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          HabitSignalRow(
            leaf: s.verdict.leaves.single,
            status: s,
            onRecordMeasurable: (_, _) {},
            onMoreMeasurable: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('habit-signal-row-composite')),
        findsOneWidget,
      );
    });

    testWidgets('numbers follow the app locale, not the process locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) {
              final s = status(
                const AutoCompleteRule.health(
                  dataType: 'cumulative_step_count',
                  minimum: 6000,
                ),
                window(
                  quantitative: {
                    'cumulative_step_count': {todayKey: 4120},
                  },
                ),
              );
              return HabitSignalRow(
                leaf: s.verdict.leaves.single,
                status: s,
                onRecordMeasurable: (_, _) {},
                onMoreMeasurable: (_) {},
              );
            },
          ),
          locale: const Locale('de'),
        ),
      );
      await tester.pump();
      expect(find.text('≥ 6.000 steps · bisher 4.120'), findsOneWidget);
    });
  });
}
