import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/widgets/charts/habits/habit_completion_rate_chart.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
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

/// Returns the canned [HabitsState] instead of loading from the database.
class _FixedStateController extends HabitsController {
  _FixedStateController(this._state);

  final HabitsState _state;

  @override
  HabitsState build() => _state;
}

/// A 14-day window with two habits; [habitFlossing] is kept every day and
/// [habitFlossingDueLater] is never kept, so the daily rate is a flat 50% and
/// the second habit is the laggard.
HabitsState _fourteenDayState() {
  final days = [
    for (var d = 1; d <= 14; d++) '2024-03-${d.toString().padLeft(2, '0')}',
  ];
  return HabitsState.initial().copyWith(
    days: days,
    timeSpanDays: 14,
    habitDefinitions: [habitFlossing, habitFlossingDueLater],
    allByDay: {
      for (final day in days) day: {habitFlossing.id, habitFlossingDueLater.id},
    },
    successfulByDay: {
      for (final day in days) day: {habitFlossing.id},
    },
  );
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

  /// Pumps the chart, optionally pinning the habits state to [state].
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

  group('HabitCompletionRateChart headline', () {
    testWidgets('shows the rolling-average label when no day is selected', (
      tester,
    ) async {
      await pumpChart(tester);

      expect(find.byType(LineChart), findsOneWidget);
      expect(find.textContaining('7-day avg'), findsOneWidget);
      // Empty data → the forward-looking goal line, not a pass/fail count.
      expect(find.textContaining('goal'), findsOneWidget);
    });

    testWidgets('shows average, on-track count, trend and laggard nudge', (
      tester,
    ) async {
      await pumpChart(tester, state: _fourteenDayState());

      // The rate and its unit read as one inline group "50%  7-day avg".
      expect(find.textContaining('50%'), findsOneWidget);
      expect(find.textContaining('7-day avg'), findsOneWidget);
      // 50% average → 30 pts to the 80% goal (gain-framed, not pass/fail).
      expect(find.textContaining('30 pts to goal'), findsOneWidget);
      // A full prior week exists and is identical → flat trend.
      expect(find.byIcon(Icons.trending_flat_rounded), findsOneWidget);
      // The never-kept habit is named as the laggard, gain-framed.
      expect(find.textContaining(habitFlossingDueLater.name), findsOneWidget);
      expect(find.textContaining('kept 0 of 14'), findsOneWidget);
    });

    testWidgets('the goal chip flips to "On track" at/above target', (
      tester,
    ) async {
      final days = [
        for (var d = 1; d <= 14; d++) '2024-03-${d.toString().padLeft(2, '0')}',
      ];
      await pumpChart(
        tester,
        state: HabitsState.initial().copyWith(
          days: days,
          timeSpanDays: 14,
          allByDay: {
            for (final day in days) day: const {'h1'},
          },
          // Every day kept → 100% average, at/above the 80% goal.
          successfulByDay: {
            for (final day in days) day: const {'h1'},
          },
        ),
      );

      expect(find.text('On track'), findsOneWidget);
      expect(find.textContaining('to goal'), findsNothing);
    });

    testWidgets('hides the trend chip on the short 7-day window', (
      tester,
    ) async {
      final days = [
        for (var d = 8; d <= 14; d++) '2024-03-${d.toString().padLeft(2, '0')}',
      ];
      await pumpChart(
        tester,
        state: HabitsState.initial().copyWith(days: days, timeSpanDays: 7),
      );

      expect(find.byIcon(Icons.trending_flat_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
    });
  });

  group('HabitCompletionRateChart line data', () {
    testWidgets('plots a daily scatter and a curved rolling-average hero', (
      tester,
    ) async {
      await pumpChart(tester, state: _fourteenDayState());

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final bars = chart.data.lineBarsData;
      expect(bars, hasLength(2));

      // Daily scatter: an invisible line carrying faint dots.
      expect(bars[0].color, Colors.transparent);
      expect(bars[0].dotData.show, isTrue);

      // Hero: a curved success-coloured average line, no dots of its own.
      expect(bars[1].isCurved, isTrue);
      expect(bars[1].barWidth, 3);
      expect(bars[1].color, successColor);
      expect(bars[1].dotData.show, isFalse);
    });

    testWidgets('shades the on-track band and drops vertical gridlines', (
      tester,
    ) async {
      await pumpChart(tester, state: _fourteenDayState());

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final bands = chart.data.rangeAnnotations.horizontalRangeAnnotations;
      expect(bands, hasLength(1));
      expect(bands.first.y1, 80);
      expect(bands.first.y2, 100);

      expect(chart.data.gridData.drawVerticalLine, isFalse);
      // No dead right margin: the last spot sits at maxX.
      expect(chart.data.maxX, chart.data.lineBarsData[1].spots.last.x);
    });
  });

  group('HabitCompletionRateChart day breakdown', () {
    testWidgets('chart tap triggers setInfoYmd on next frame', (tester) async {
      await pumpChart(tester);

      final chartFinder = find.byType(LineChart);
      expect(chartFinder, findsOneWidget);

      await tester.tapAt(tester.getCenter(chartFinder));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The deferred paint-time callback must not throw.
      expect(tester.takeException(), isNull);
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('shows the per-day split when a day is selected', (
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

      expect(find.textContaining('2025-12-30'), findsOneWidget);
      expect(find.textContaining('% successful'), findsOneWidget);
      expect(find.textContaining('% skipped'), findsOneWidget);
      expect(find.textContaining('% recorded fails'), findsOneWidget);
    });

    testWidgets('a pointer-exit is wired and a no-op with no selection', (
      tester,
    ) async {
      await pumpChart(tester);
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      // The hover/scrub-exit clear is wired (so the breakdown snaps back to the
      // headline on pointer-exit rather than waiting out the idle debounce).
      expect(chart.data.lineTouchData.touchCallback, isNotNull);

      // With nothing selected the guard short-circuits: no clear is scheduled
      // and nothing throws.
      chart.data.lineTouchData.touchCallback!(
        const FlPointerExitEvent(PointerExitEvent()),
        null,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
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
    ]) {
      testWidgets(edgeCase.description, (tester) async {
        await pumpChart(tester, state: edgeCase.state);

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

      expect(tooltipData.getTooltipItems([]), isEmpty);
    });

    testWidgets('does not throw when spot index is out of bounds', (
      tester,
    ) async {
      await pumpChart(tester, state: withDaysState);

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tooltipData = lineChart.data.lineTouchData.touchTooltipData;

      final barDataObj = LineChartBarData(spots: const [FlSpot(999, 50)]);
      final spots = [LineBarSpot(barDataObj, 0, const FlSpot(999, 50))];

      final items = tooltipData.getTooltipItems(spots);
      expect(items, hasLength(1));
      expect(items.first, isNull);
    });
  });

  group('leftTitleWidgets', () {
    Future<void> pumpTitleWidget(WidgetTester tester, double value) async {
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
}
