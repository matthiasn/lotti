import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/charts/habits/habit_completion_rate_chart.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

// Minimal TitleMeta for testing title widget callbacks.
TitleMeta _makeMeta() => TitleMeta(
  min: 0,
  max: 100,
  appliedInterval: 20,
  axisPosition: 0,
  formattedValue: '',
  parentAxisSize: 400,
  sideTitles: const SideTitles(showTitles: true),
  axisSide: AxisSide.left,
  rotationQuarterTurns: 0,
);

/// Returns the canned [HabitsState] instead of loading from the database —
/// replaces the five former one-off controller subclasses.
class _FixedStateController extends HabitsController {
  _FixedStateController(this._state);

  final HabitsState _state;

  @override
  HabitsState build() => _state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestGetItMocks mocks;

  setUp(() async {
    final mockNavService = MockNavService();
    when(() => mockNavService.habitsIndex).thenReturn(3);
    when(() => mockNavService.index).thenReturn(3);
    when(
      mockNavService.getIndexStream,
    ).thenAnswer((_) => const Stream<int>.empty());

    mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<NavService>(mockNavService);
      },
    );

    when(
      mocks.journalDb.getAllHabitDefinitions,
    ).thenAnswer((_) async => <HabitDefinition>[]);
    when(
      () => mocks.journalDb.getHabitCompletionsInRange(
        rangeStart: any(named: 'rangeStart'),
      ),
    ).thenAnswer((_) async => []);
  });

  tearDown(tearDownTestGetIt);

  /// Pumps the chart, optionally pinning the habits state to [state] instead
  /// of letting the real controller load from the (mocked) database.
  ///
  /// Uses [makeTestableWidgetNoScroll] so the active theme carries the DsTokens
  /// extension (the chart now reads `context.designTokens` for its tokenized
  /// gridlines and border) and the AppLocalizations delegates are present for
  /// the info-label strings.
  Future<void> pumpChart(WidgetTester tester, {HabitsState? state}) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(body: HabitCompletionRateChart()),
        overrides: [
          if (state != null)
            habitsControllerProvider.overrideWith(
              () => _FixedStateController(state),
            ),
        ],
      ),
    );
    // Two pumps: one for the first frame, one for the controller's async load.
    await tester.pump();
    await tester.pump();
  }

  group('HabitCompletionRateChart', () {
    testWidgets('displays default info label when no day selected', (
      tester,
    ) async {
      await pumpChart(tester);

      expect(find.byType(LineChart), findsOneWidget);
      expect(find.textContaining('active habits'), findsOneWidget);
      expect(find.textContaining('Tap chart'), findsOneWidget);
    });

    testWidgets('chart tap triggers setInfoYmd on next frame', (tester) async {
      await pumpChart(tester);

      // Find the LineChart
      final chartFinder = find.byType(LineChart);
      expect(chartFinder, findsOneWidget);

      // Tap the center of the chart
      await tester.tapAt(tester.getCenter(chartFinder));

      // Pump to allow addPostFrameCallback to execute. The original bug
      // modified provider state during paint (setState/markNeedsBuild while
      // painting), which throws a FlutterError. setInfoYmd is now deferred
      // via addPostFrameCallback, so draining the post-frame callback here
      // must not surface any exception.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Regression guard: no exception was thrown while the deferred
      // paint-time callback ran, and the chart is still mounted.
      expect(tester.takeException(), isNull);
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('displays percentage info when day is selected', (
      tester,
    ) async {
      await pumpChart(
        tester,
        state: HabitsState.initial().copyWith(
          selectedInfoYmd: '2025-12-30',
          successPercentage: 75,
          skippedPercentage: 10,
          failedPercentage: 15,
        ),
      );

      // The pinned state sets selectedInfoYmd, so we should see percentages
      expect(find.textContaining('2025-12-30'), findsOneWidget);
      expect(find.textContaining('% successful'), findsOneWidget);
      expect(find.textContaining('% skipped'), findsOneWidget);
      expect(find.textContaining('% recorded fails'), findsOneWidget);
    });

    for (final edgeCase in [
      (
        description: 'handles empty days list without throwing',
        state: HabitsState.initial().copyWith(days: [], timeSpanDays: 7),
      ),
      (
        description: 'handles single day list without throwing',
        state: HabitsState.initial().copyWith(
          days: ['2025-12-30'],
          timeSpanDays: 7,
        ),
      ),
      (
        description: 'renders with zeroBased mode',
        state: HabitsState.initial().copyWith(zeroBased: true, minY: 50),
      ),
    ]) {
      testWidgets(edgeCase.description, (tester) async {
        await pumpChart(tester, state: edgeCase.state);

        // Renders without errors — bounds checks prevent RangeError.
        expect(tester.takeException(), isNull);
        expect(find.byType(LineChart), findsOneWidget);
      });
    }

    test('preferredSize returns toolbar height', () {
      const chart = HabitCompletionRateChart();
      expect(chart.preferredSize, const Size.fromHeight(kToolbarHeight));
    });
  });

  group('getTooltipItems callback', () {
    final withDaysState = HabitsState.initial().copyWith(
      days: ['2024-03-13', '2024-03-14', '2024-03-15'],
      timeSpanDays: 3,
      successfulByDay: {
        '2024-03-13': {'h1'},
        '2024-03-14': {'h1'},
        '2024-03-15': {'h1'},
      },
      allByDay: {
        '2024-03-13': {'h1', 'h2'},
        '2024-03-14': {'h1', 'h2'},
        '2024-03-15': {'h1', 'h2'},
      },
    );

    testWidgets('returns empty list when spots is empty', (tester) async {
      await pumpChart(tester, state: withDaysState);

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tooltipData = lineChart.data.lineTouchData.touchTooltipData;

      final items = tooltipData.getTooltipItems([]);
      expect(items, isEmpty);
    });

    testWidgets('does not throw when spot index is out of bounds', (
      tester,
    ) async {
      await pumpChart(tester, state: withDaysState);

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tooltipData = lineChart.data.lineTouchData.touchTooltipData;

      // Use an x value far beyond the days list length
      final barDataObj = LineChartBarData(spots: const [FlSpot(999, 50)]);
      final spots = [LineBarSpot(barDataObj, 0, const FlSpot(999, 50))];

      // Must not throw; returns one null per spot
      final items = tooltipData.getTooltipItems(spots);
      expect(items, hasLength(1));
      expect(items.first, isNull);
    });
  });

  group('leftTitleWidgets', () {
    Future<void> pumpTitleWidget(WidgetTester tester, double value) async {
      // Labelled values render a ChartLabel, which reads context.designTokens,
      // so the active theme must carry the DsTokens extension.
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(body: leftTitleWidgets(value, _makeMeta())),
        ),
      );
    }

    for (final testCase in [
      (value: 20.0, expected: '20%'),
      (value: 40.0, expected: '40%'),
      (value: 60.0, expected: '60%'),
      (value: 80.0, expected: '80%'),
      (value: 100.0, expected: '100%'),
    ]) {
      testWidgets(
        'returns ChartLabel with "${testCase.expected}" for value '
        '${testCase.value}',
        (tester) async {
          await pumpTitleWidget(tester, testCase.value);
          expect(find.text(testCase.expected), findsOneWidget);
        },
      );
    }

    testWidgets('returns empty Container for non-labelled values', (
      tester,
    ) async {
      // Values like 0, 10, 30, 50 are not labelled.
      for (final value in [0.0, 10.0, 30.0, 50.0, 70.0, 90.0]) {
        await pumpTitleWidget(tester, value);
        expect(find.byType(Container), findsWidgets);
        expect(
          find.text(value.toInt().toString()),
          findsNothing,
          reason: 'No label expected for value $value',
        );
      }
    });
  });

  group('barData pure function', () {
    HabitsState makeState({
      List<HabitDefinition> habitDefinitions = const [],
      Map<String, Set<String>> allByDay = const {},
      Map<String, Set<String>> successfulByDay = const {},
      Map<String, Set<String>> skippedByDay = const {},
      Map<String, Set<String>> failedByDay = const {},
    }) {
      return HabitsState.initial().copyWith(
        habitDefinitions: habitDefinitions,
        allByDay: allByDay,
        successfulByDay: successfulByDay,
        skippedByDay: skippedByDay,
        failedByDay: failedByDay,
      );
    }

    test('produces zero y-value when habitCount is 0', () {
      const day = '2024-03-15';
      final state = makeState(); // no habits, no allByDay entries
      final result = barData(
        days: [day],
        habitDefinitions: [],
        successfulByDay: {},
        skippedByDay: {},
        failedByDay: {},
        state: state,
        showSuccessful: true,
        showSkipped: true,
        showFailed: true,
        color: Colors.blue,
      );

      expect(result.spots, hasLength(1));
      expect(result.spots.first.y, 0.0);
    });

    test('computes correct rate when showSuccessful only', () {
      const day = '2024-03-15';
      final state = makeState(
        allByDay: {
          day: {'h1', 'h2', 'h3', 'h4'},
        },
        successfulByDay: {
          day: {'h1', 'h2'},
        },
        skippedByDay: {
          day: {'h3'},
        },
        failedByDay: {
          day: {'h4'},
        },
      );

      final result = barData(
        days: [day],
        habitDefinitions: [],
        successfulByDay: {
          day: {'h1', 'h2'},
        },
        skippedByDay: {
          day: {'h3'},
        },
        failedByDay: {
          day: {'h4'},
        },
        state: state,
        showSuccessful: true,
        showSkipped: false,
        showFailed: false,
        color: Colors.green,
      );

      // 2 successful out of 4 total → 50 %
      expect(result.spots, hasLength(1));
      expect(result.spots.first.y, closeTo(50.0, 0.001));
    });

    test('computes correct rate when showSuccessful + showSkipped', () {
      const day = '2024-03-15';
      final state = makeState(
        allByDay: {
          day: {'h1', 'h2', 'h3', 'h4'},
        },
        successfulByDay: {
          day: {'h1', 'h2'},
        },
        skippedByDay: {
          day: {'h3'},
        },
        failedByDay: {
          day: {'h4'},
        },
      );

      final result = barData(
        days: [day],
        habitDefinitions: [],
        successfulByDay: {
          day: {'h1', 'h2'},
        },
        skippedByDay: {
          day: {'h3'},
        },
        failedByDay: {
          day: {'h4'},
        },
        state: state,
        showSuccessful: true,
        showSkipped: true,
        showFailed: false,
        color: Colors.orange,
      );

      // 2 successful + 1 skipped = 3 out of 4 → 75 %
      expect(result.spots.first.y, closeTo(75.0, 0.001));
    });

    test('clamps rate to 100 when value exceeds total', () {
      const day = '2024-03-15';
      // 5 successful out of only 4 total would exceed 100 — must be capped.
      final state = makeState(
        allByDay: {
          day: {'h1', 'h2', 'h3', 'h4'},
        },
        successfulByDay: {
          day: {'h1', 'h2', 'h3', 'h4', 'h5'},
        },
      );

      final result = barData(
        days: [day],
        habitDefinitions: [],
        successfulByDay: {
          day: {'h1', 'h2', 'h3', 'h4', 'h5'},
        },
        skippedByDay: {},
        failedByDay: {},
        state: state,
        showSuccessful: true,
        showSkipped: false,
        showFailed: false,
        color: Colors.teal,
      );

      expect(result.spots.first.y, 100.0);
    });

    test('aboveColor is applied when provided', () {
      const day = '2024-03-15';
      final state = makeState();
      const aboveColor = Colors.red;

      final result = barData(
        days: [day],
        habitDefinitions: [],
        successfulByDay: {},
        skippedByDay: {},
        failedByDay: {},
        state: state,
        showSuccessful: true,
        showSkipped: false,
        showFailed: false,
        color: Colors.blue,
        aboveColor: aboveColor,
      );

      expect(result.aboveBarData, isNotNull);
      expect(result.aboveBarData.show, isTrue);
    });
  });
}
