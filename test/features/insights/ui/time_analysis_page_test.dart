import 'package:clock/clock.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/state/insights_providers.dart';
import 'package:lotti/features/insights/ui/time_analysis_page.dart';
import 'package:lotti/utils/device_region.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import 'insights_test_scenarios.dart';

void main() {
  final fixedNow = DateTime(2026, 6, 7, 16);
  const desktopMq = MediaQueryData(size: Size(1280, 900));

  late MockInsightsRepository repository;

  setUp(() {
    repository = MockInsightsRepository();
  });

  void stubRows(List<InsightsTimeRow> rows) {
    when(
      () => repository.fetchTimeRows(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => rows);
  }

  Future<void> pumpPage(WidgetTester tester) async {
    // The ListView only builds what fits the real render surface, so the
    // table needs an actual desktop-sized viewport, not just MediaQuery.
    tester.view
      ..physicalSize = const Size(1280, 1100)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await withClock(Clock.fixed(fixedNow), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          mediaQueryData: desktopMq,
          overrides: [
            insightsRepositoryProvider.overrideWithValue(repository),
            maybeUpdateNotificationsProvider.overrideWith((ref) => null),
            categoriesStreamProvider.overrideWith(
              (ref) => Stream.value(insightsScenarioCategories),
            ),
            // Deterministic Monday-start weeks regardless of host region.
            // Synchronous so AsyncData lands at build time; an async override
            // resolves on a microtask and leaves Riverpod's refresh timer
            // pending past teardown.
            firstDayOfWeekIndexProvider.overrideWith(
              (ref) => DateTime.monday % 7,
            ),
          ],
          const TimeAnalysisPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    });
  }

  InsightsTimeRow row({
    required int daysAgo,
    required int hour,
    required int minutes,
    String? categoryId,
  }) {
    final start = DateTime(
      fixedNow.year,
      fixedNow.month,
      fixedNow.day - daysAgo,
      hour,
    );
    return InsightsTimeRow(
      dateFrom: start,
      dateTo: DateTime(start.year, start.month, start.day, hour, minutes),
      categoryId: categoryId,
    );
  }

  testWidgets(
    'renders KPI total, chart, and table values computed from the data',
    (tester) async {
      stubRows([
        row(daysAgo: 1, hour: 9, minutes: 120, categoryId: 'cat-client'),
        row(daysAgo: 2, hour: 10, minutes: 60, categoryId: 'cat-admin'),
        row(daysAgo: 3, hour: 11, minutes: 60),
      ]);
      await pumpPage(tester);

      expect(find.text('Time Analysis'), findsOneWidget);
      // KPI: 2h + 1h + 1h tracked in the trailing week.
      expect(find.text('4h'), findsOneWidget);
      // Table rows with shares 50% / 25% / 25%.
      expect(find.text('Client Work'), findsWidgets);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('2:00'), findsOneWidget);
      expect(find.text('Uncategorized'), findsWidgets);
      // Chart legend present (legend + table both mention categories).
      expect(find.text('Admin'), findsWidgets);
    },
  );

  testWidgets('empty period shows the empty state with a view-year action', (
    tester,
  ) async {
    stubRows(const []);
    await pumpPage(tester);

    expect(find.text('No tracked time in this range'), findsOneWidget);
    expect(find.text('View this year'), findsOneWidget);

    // The action widens the period to the whole year.
    await withClock(Clock.fixed(fixedNow), () async {
      await tester.tap(find.text('View this year'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    });
    // The year is now selected; the year-specific action is gone.
    expect(find.text('View this year'), findsNothing);
  });

  testWidgets('repository errors surface the error message, not a crash', (
    tester,
  ) async {
    when(
      () => repository.fetchTimeRows(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenThrow(StateError('boom'));
    await pumpPage(tester);

    expect(find.text("Couldn't load time data"), findsOneWidget);
  });

  testWidgets('switching granularity recomputes the dashboard from memory', (
    tester,
  ) async {
    stubRows([
      // One entry today (inside the current week), one on May 18 — only the
      // latter distinguishes the week from the quarter. Totals are
      // deliberately non-round so they can't collide with axis tick labels.
      row(daysAgo: 0, hour: 9, minutes: 90, categoryId: 'cat-client'),
      row(daysAgo: 20, hour: 9, minutes: 120, categoryId: 'cat-client'),
    ]);
    await pumpPage(tester);

    expect(find.text('1h 30m'), findsOneWidget); // current week total

    // Widen to the quarter (Apr–Jun 2026), which also contains May 18.
    await withClock(Clock.fixed(fixedNow), () async {
      await tester.tap(find.text('Week')); // open the granularity dropdown
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quarter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    });

    expect(find.text('3h 30m'), findsOneWidget); // quarter includes both
    // The same in-memory window serves week and quarter: exactly one fetch.
    verify(
      () => repository.fetchTimeRows(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).called(1);
  });

  testWidgets('Compare shows previous-period deltas in the KPI and table', (
    tester,
  ) async {
    stubRows([
      // Current week (Jun 1–7): 2h30m. Previous week (May 25–31): 1h. The
      // non-round current total can't collide with a round chart axis tick.
      row(daysAgo: 1, hour: 9, minutes: 150, categoryId: 'cat-client'),
      row(daysAgo: 8, hour: 9, minutes: 60, categoryId: 'cat-client'),
    ]);
    await pumpPage(tester);
    expect(find.text('2h 30m'), findsOneWidget); // current week total

    await withClock(Clock.fixed(fixedNow), () async {
      await tester.tap(find.text('Compare'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    });

    // 2h30m this week vs 1h last week = ↑150%, shown on the KPI tile and the
    // table's new PREVIOUS column.
    expect(find.text('PREVIOUS'), findsOneWidget);
    expect(find.text('↑150%'), findsWidgets);
    expect(find.text('vs 1h'), findsOneWidget);

    // The chart switches to grouped current-vs-previous bars: every day group
    // now carries two rods, and the caption announces the comparison.
    expect(find.text('This period vs the previous'), findsOneWidget);
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(
      chart.data.barGroups,
      everyElement(
        isA<BarChartGroupData>().having((g) => g.barRods.length, 'rods', 2),
      ),
    );
  });
}
