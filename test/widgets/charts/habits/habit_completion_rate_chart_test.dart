// These layout assertions use the deterministic Flutter test font.
// Bundled screenshot suites load app fonts globally and change their metrics.
@Tags(['skip_very_good_optimization'])
library;

import 'package:easy_debounce/easy_debounce.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/ui/widgets/habits_chart_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/widgets/charts/habits/habit_completion_rate_chart.dart';
import 'package:material_ui/material_ui.dart';
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
      () => mocks.journalDb.getHabitCompletionRecordsInRange(
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

  group('goal-scoped summary', () {
    /// Pumps the headline-less chart above the corner summary the goal
    /// dashboard hoists into its card header, over the shared 14-day state.
    Future<void> pumpScoped(WidgetTester tester) => tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const Scaffold(
          body: Column(
            children: [
              HabitCompletionRateSummary(habitIds: null),
              HabitCompletionRateChart(showsHeadline: false),
            ],
          ),
        ),
        overrides: [
          habitsControllerProvider.overrideWith(
            () => _FixedStateController(_fourteenDayState()),
          ),
        ],
      ),
    );

    testWidgets('states the rate once, with the goal verdict and the '
        'week-over-week move as its caption', (tester) async {
      await pumpScoped(tester);
      await tester.pump();

      // ONE rate, in the corner block — the display-tier headline the plot
      // used to carry would make it two.
      final rate = find.textContaining('7-day Ø');
      expect(rate, findsOneWidget);
      final rateText = tester.widget<Text>(rate).textSpan! as TextSpan;
      expect(rateText.toPlainText(), startsWith('50%'));

      // The verdict, at caption weight rather than in a tinted pill.
      final verdict = find.textContaining('to goal');
      expect(verdict, findsOneWidget);
      final tokens = tester
          .element(find.byType(HabitCompletionRateSummary))
          .designTokens;
      expect(
        tester.widget<Text>(verdict).style?.color,
        tokens.colors.alert.warning.ink,
      );
      expect(
        tester.getTopLeft(verdict).dy,
        greaterThan(tester.getTopLeft(rate).dy),
        reason: 'the verdict is the caption UNDER the key figure',
      );
    });

    testWidgets('the summary shrinks inside a bounded corner instead of '
        'overflowing a phone-width header', (tester) async {
      // Regression: as an inflexible trailing child of the card's header
      // Row, the summary took its intrinsic width — so a long locale or a
      // raised text scale pushed it straight past the card's edge.
      tester.view
        ..physicalSize = const Size(358, 1200)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: HabitsChartCard(
              habitIds: {habitFlossing.id},
              showTimeSpanPicker: false,
            ),
          ),
          overrides: [
            habitsControllerProvider.overrideWith(
              () => _FixedStateController(_fourteenDayState()),
            ),
          ],
          locale: const Locale('de'),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byType(HabitsChartCard));
      final summary = tester.getRect(
        find.byType(HabitCompletionRateSummary),
      );
      expect(summary.right, lessThanOrEqualTo(card.right));
      expect(
        summary.width,
        lessThanOrEqualTo(card.width / 2 + 1),
        reason:
            'the corner is capped at half the card, like the signal '
            'cards it sits beneath',
      );
    });

    testWidgets('the headline-less plot reserves no slot of its own', (
      tester,
    ) async {
      await pumpScoped(tester);
      await tester.pump();

      // The chart draws no second copy of the rate, and nothing sits between
      // the summary and the plot: the 44px headline floor is gone with it.
      expect(find.textContaining('7-day Ø'), findsOneWidget);
      final chart = tester.getRect(find.byType(HabitCompletionRateChart));
      final plot = tester.getRect(find.byType(LineChart));
      expect(
        plot.top - chart.top,
        lessThan(8),
        reason: 'a reserved headline slot would push the plot down 44px',
      );
    });

    testWidgets("a selected day swaps the corner block for that day's "
        'split, so the plot never moves', (tester) async {
      await pumpScoped(tester);
      await tester.pump();

      // Measured against the CHART's own box: the guarantee is that the plot
      // keeps its position inside the chart, because the chart no longer
      // owns a headline slot for the breakdown to expand.
      double plotOffset() =>
          tester.getRect(find.byType(LineChart)).top -
          tester.getRect(find.byType(HabitCompletionRateChart)).top;
      final before = plotOffset();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HabitCompletionRateSummary)),
        listen: false,
      );
      container
          .read(habitsControllerProvider.notifier)
          .setInfoYmd(
            '2024-03-07',
          );
      await tester.pump();

      expect(find.textContaining('2024-03-07'), findsOneWidget);
      expect(find.textContaining('7-day Ø'), findsNothing);
      expect(plotOffset(), before);
      // The controller arms a 15s debounce that clears the selection; let it
      // run out rather than leaving a pending timer behind the test.
      EasyDebounce.cancel('clearInfoYmd');
    });
  });

  group('HabitCompletionRateChart headline', () {
    testWidgets('shows the rolling-average label when no day is selected', (
      tester,
    ) async {
      await pumpChart(tester);

      expect(find.byType(LineChart), findsOneWidget);
      expect(find.textContaining('7-day Ø'), findsOneWidget);
      // Empty data → the forward-looking goal line, not a pass/fail count.
      expect(find.textContaining('goal'), findsOneWidget);
    });

    testWidgets('the headline flows to a second line at phone width '
        'instead of overflowing', (tester) async {
      // Regression: naming the badge "pts to goal" made the headline
      // row (rate block + goal chip + trend chip) wider than a phone-width
      // card, overflowing its right edge by a few pixels. The headline is a
      // Wrap now, so the chips drop to a second line. Reverting the Wrap
      // makes this fail with a RenderFlex overflow exception.
      tester.view.physicalSize = const Size(358, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpChart(tester, state: _fourteenDayState());

      expect(tester.takeException(), isNull);
      expect(find.textContaining('to goal'), findsOneWidget);
    });

    testWidgets('a wrapped headline grows downward instead of overlapping '
        'the plot', (tester) async {
      tester.view.physicalSize = const Size(358, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpChart(tester, state: _fourteenDayState());
      expect(tester.takeException(), isNull);

      // Second run: the goal chip sits BELOW the rate block…
      final rateRect = tester.getRect(find.textContaining('7-day Ø'));
      final chipRect = tester.getRect(find.textContaining('to goal'));
      expect(chipRect.top, greaterThanOrEqualTo(rateRect.bottom - 1));
      // …and the plot starts below the grown header instead of underneath it.
      final chartRect = tester.getRect(find.byType(LineChart));
      expect(chartRect.top, greaterThanOrEqualTo(chipRect.bottom - 1));
    });

    testWidgets('disables the implicit data-swap animation', (tester) async {
      await pumpChart(tester, state: _fourteenDayState());

      // The habits tab rebuilds this chart on every completion, sync, and span
      // change; a non-zero duration would replay the rolling-average line morph
      // each time — unsolicited motion. It must be pinned to zero.
      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.duration, Duration.zero);
    });

    testWidgets('shows average, on-track count, trend and laggard nudge', (
      tester,
    ) async {
      await pumpChart(tester, state: _fourteenDayState());

      // The rate and its unit read as one inline group "50%  7-day Ø".
      expect(find.textContaining('50%'), findsOneWidget);
      expect(find.textContaining('7-day Ø'), findsOneWidget);
      // 50% average → 30 pts to the 80% goal (gain-framed, not pass/fail).
      expect(find.textContaining('30 pts to goal'), findsOneWidget);
      // A full prior week exists and is identical → flat trend.
      expect(find.byIcon(LottiIcons.forward), findsOneWidget);
      // The never-kept habit is named as the laggard, gain-framed.
      expect(find.textContaining(habitFlossingDueLater.name), findsOneWidget);
      expect(find.textContaining('kept 0 of 14'), findsOneWidget);
    });

    testWidgets('the goal chip flips to "On track" at/above the goal', (
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

      expect(find.byIcon(LottiIcons.forward), findsNothing);
      expect(find.byIcon(LottiIcons.arrowUp), findsNothing);
      expect(find.byIcon(LottiIcons.arrowDown), findsNothing);
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
