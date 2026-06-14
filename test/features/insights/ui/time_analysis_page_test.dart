import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/state/insights_providers.dart';
import 'package:lotti/features/insights/ui/time_analysis_page.dart';
import 'package:lotti/features/insights/ui/widgets/insights_period_picker.dart';
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
    // The likeliest recovery — "show me the last one" — leads as a real
    // (pill-chrome) button; widening to the year is the quieter text link.
    expect(find.text('Show the previous period'), findsOneWidget);
    expect(find.text('View this year'), findsOneWidget);

    // The secondary action widens the period to the whole year.
    await withClock(Clock.fixed(fixedNow), () async {
      await tester.tap(find.text('View this year'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    });
    // The year is now selected; the year-specific action is gone.
    expect(find.text('View this year'), findsNothing);
  });

  testWidgets('empty-state primary action steps to the previous period', (
    tester,
  ) async {
    stubRows(const []);
    await pumpPage(tester);
    expect(find.text('June 2026 (so far)'), findsOneWidget);

    await withClock(Clock.fixed(fixedNow), () async {
      await tester.tap(find.text('Show the previous period'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    });
    // Stepped back from month-to-date June to the full previous month.
    expect(find.text('May 2026'), findsOneWidget);
    expect(find.text('June 2026 (so far)'), findsNothing);
  });

  testWidgets('tapping the period label opens the jump-to-date calendar', (
    tester,
  ) async {
    stubRows([row(daysAgo: 1, hour: 9, minutes: 60, categoryId: 'cat-client')]);
    await pumpPage(tester);

    await withClock(Clock.fixed(fixedNow), () async {
      await tester.tap(find.text('June 2026 (so far)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    });
    expect(find.byType(InsightsPeriodPickerBody), findsOneWidget);
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

    expect(find.text('1h 30m'), findsOneWidget); // current month-to-date total

    // Widen to the quarter (Apr–Jun 2026), which also contains May 18.
    await withClock(Clock.fixed(fixedNow), () async {
      await tester.tap(find.text('Month')); // open the granularity dropdown
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
    // The default is month-to-date; switch to the current week for a
    // week-over-week comparison against the data above.
    await withClock(Clock.fixed(fixedNow), () async {
      await tester.tap(find.text('Month')); // open the granularity dropdown
      await tester.pumpAndSettle();
      await tester.tap(find.text('Week'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    });
    expect(find.text('2h 30m'), findsOneWidget); // current week total

    await withClock(Clock.fixed(fixedNow), () async {
      await tester.tap(find.text('Compare'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    });

    // 2h30m this week vs 1h last week = +150%, surfaced in the KPI tile and the
    // table's Δ% / PREVIOUS columns. The comparison is numeric only — there is
    // no second chart series.
    expect(find.text('PREVIOUS'), findsOneWidget);
    expect(find.text('+150%'), findsWidgets);
    expect(find.textContaining('vs 1h'), findsOneWidget);
    // The current week is in progress, so the basis is the elapsed "same days"
    // — named at both the KPI and the table (never the misleading full period).
    expect(find.textContaining('same days'), findsWidgets);
  });

  testWidgets(
    'stepping across a year keeps the previous data on screen while the new '
    'window loads, instead of flashing a spinner',
    (tester) async {
      // The bucket window is keyed by year, so crossing a year boundary spins
      // up a fresh provider instance with no value yet. The current year
      // (2026) loads at once; the previous year (2025) is held pending so the
      // transition frame can be observed.
      final pending2025 = Completer<List<InsightsTimeRow>>();
      when(
        () => repository.fetchTimeRows(
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).thenAnswer((invocation) {
        final start = invocation.namedArguments[#start] as DateTime;
        if (start.year <= 2025) return pending2025.future;
        // 2026: a single 2h 15m entry — non-round so it can't collide with a
        // round chart axis tick.
        return Future.value([
          row(daysAgo: 1, hour: 9, minutes: 135, categoryId: 'cat-client'),
        ]);
      });
      await pumpPage(tester);
      expect(find.text('2h 15m'), findsOneWidget); // June 2026 month-to-date

      await withClock(Clock.fixed(fixedNow), () async {
        // Widen to the year — still 2026, same in-memory window, no fetch.
        await tester.tap(find.text('Month'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Year'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        // Step back into 2025: a new window that stays pending.
        await tester.tap(find.byIcon(Icons.chevron_left_rounded));
        await tester.pump();
      });

      // keepPreviousData: 2025 is still loading, but the dashboard keeps the
      // 2026 figures on screen rather than flashing a loading shell.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('2h 15m'), findsOneWidget);
      // The header/stepper, however, already reflects the period just selected.
      expect(find.text('2025'), findsOneWidget);

      // Once 2025 resolves, the body swaps to its figures (4h 50m).
      await withClock(Clock.fixed(fixedNow), () async {
        pending2025.complete([
          InsightsTimeRow(
            dateFrom: DateTime(2025, 6, 1, 9),
            dateTo: DateTime(2025, 6, 1, 13, 50),
            categoryId: 'cat-client',
          ),
        ]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
      });
      expect(find.text('4h 50m'), findsOneWidget);
      expect(find.text('2h 15m'), findsNothing);
    },
  );

  testWidgets(
    'a failed year-crossing load keeps the last data and surfaces a '
    'non-blocking refresh notice instead of a shell',
    (tester) async {
      // 2026 loads; the 2025 window fetch throws. After a successful first
      // load the data is never blanked, so the failure must be surfaced inline.
      when(
        () => repository.fetchTimeRows(
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).thenAnswer((invocation) {
        final start = invocation.namedArguments[#start] as DateTime;
        if (start.year <= 2025) throw StateError('boom');
        return Future.value([
          row(daysAgo: 1, hour: 9, minutes: 135, categoryId: 'cat-client'),
        ]);
      });
      await pumpPage(tester);
      expect(find.text('2h 15m'), findsOneWidget);

      await withClock(Clock.fixed(fixedNow), () async {
        await tester.tap(find.text('Month'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Year'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        // Step back into 2025 — the window load throws.
        await tester.tap(find.byIcon(Icons.chevron_left_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
      });

      // The 2026 figures stay on screen — never the load-error shell or a
      // spinner.
      expect(find.text('2h 15m'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text("Couldn't load time data"), findsNothing);
      // The failure is surfaced as a slim, non-blocking notice instead.
      expect(find.textContaining("Couldn't refresh"), findsOneWidget);
      // The header still reflects the period the user stepped to.
      expect(find.text('2025'), findsOneWidget);
    },
  );
}
