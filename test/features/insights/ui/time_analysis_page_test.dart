import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/state/insights_providers.dart';
import 'package:lotti/features/insights/ui/time_analysis_page.dart';
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

  testWidgets('empty range shows the designed empty state with YTD action', (
    tester,
  ) async {
    stubRows(const []);
    await pumpPage(tester);

    expect(find.text('No tracked time in this range'), findsOneWidget);
    expect(find.text('View year to date'), findsOneWidget);

    // The action switches the range provider to YTD.
    await withClock(Clock.fixed(fixedNow), () async {
      await tester.tap(find.text('View year to date'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    });
    // YTD is now the active preset; the YTD-specific action is gone.
    expect(find.text('View year to date'), findsNothing);
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

  testWidgets('switching presets recomputes the dashboard from memory', (
    tester,
  ) async {
    stubRows([
      // One entry today, one 20 days ago — only the latter distinguishes
      // 7d from 30d. Totals are deliberately non-round so they can't
      // collide with axis tick labels like "1h".
      row(daysAgo: 0, hour: 9, minutes: 90, categoryId: 'cat-client'),
      row(daysAgo: 20, hour: 9, minutes: 120, categoryId: 'cat-client'),
    ]);
    await pumpPage(tester);

    expect(find.text('1h 30m'), findsOneWidget); // 7d total

    await withClock(Clock.fixed(fixedNow), () async {
      await tester.tap(find.text('30d'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    });

    expect(find.text('3h 30m'), findsOneWidget); // 30d total includes both
    // The same in-memory window serves both presets: exactly one fetch.
    verify(
      () => repository.fetchTimeRows(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).called(1);
  });
}
