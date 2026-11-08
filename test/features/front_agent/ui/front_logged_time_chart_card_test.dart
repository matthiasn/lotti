import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/design_system/theme/icon_tokens.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/state/front_logged_time_providers.dart';
import 'package:lotti/features/front_agent/ui/front_logged_time_chart_card.dart';
import 'package:lotti/features/insights/logic/chart_colors.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/ui/widgets/insights_chart_card.dart';
import 'package:lotti/features/insights/ui/widgets/insights_chart_card_charts.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  final at = DateTime(2026, 10, 2);
  CategoryDefinition category(String id, String name, String color) =>
      CategoryDefinition(
        id: id,
        name: name,
        color: color,
        createdAt: at,
        updatedAt: at,
        vectorClock: null,
        private: false,
        active: true,
      );
  final colony = category('colony', 'Colony', '#4CAF93');
  final fishing = category('fishing', 'Fishing', '#3F7FD9');

  // Monday 2026-10-26 through Sunday 2026-11-01: a week long past.
  final monday = epochDay(DateTime(2026, 10, 26));
  final chart = FrontLoggedTimeChart(
    range: InsightsRange(startDay: monday, endDayExclusive: monday + 7),
    categoryIds: const {},
  );

  InsightsTimeRow row(String id, int day, int fromHour, int toHour) {
    final date = dayStart(monday + day);
    return InsightsTimeRow(
      dateFrom: date.add(Duration(hours: fromHour)),
      dateTo: date.add(Duration(hours: toHour)),
      categoryId: id,
    );
  }

  InsightsChartData data(List<InsightsTimeRow> rows) => buildChartData(
    bucketize(rows, windowStartDay: monday),
    chart.range,
  );

  Future<void> pump(
    WidgetTester tester,
    Future<InsightsChartData> Function() load,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(body: FrontLoggedTimeChartCard(chart: chart)),
        overrides: [
          frontLoggedTimeChartProvider.overrideWith(
            (ref, _) => Stream.fromFuture(load()),
          ),
          categoriesStreamProvider.overrideWith(
            (ref) => Stream.value([colony, fishing]),
          ),
        ],
      ),
    );
    // The read, then the categories' stream.
    await tester.pump();
    await tester.pump();
  }

  BarChartData bars(WidgetTester tester) =>
      tester.widget<BarChart>(find.byType(BarChart)).data;

  testWidgets('several categories stack in their own colours, one bar per '
      'day, an empty day at zero, and a legend names them', (tester) async {
    await pump(
      tester,
      () async => data([
        row('colony', 0, 9, 12),
        row('fishing', 0, 13, 14),
        row('fishing', 2, 8, 10),
      ]),
    );

    final groups = bars(tester).barGroups;
    expect(groups, hasLength(7));
    final mondayStack = groups[0].barRods.single.rodStackItems;
    // The largest category sits on the baseline.
    expect(
      [for (final item in mondayStack) (item.fromY, item.toY)],
      [(0.0, 3 * 3600.0), (3 * 3600.0, 4 * 3600.0)],
    );
    final brightness = Theme.of(
      tester.element(find.byType(BarChart)),
    ).brightness;
    expect(mondayStack[0].color, chartColorFor('#4CAF93', brightness));
    expect(mondayStack[1].color, chartColorFor('#3F7FD9', brightness));
    // Tuesday has nothing logged: a bar of zero height, not a hole.
    expect(groups[1].barRods.single.toY, 0);
    expect(find.text('Colony'), findsOne);
    expect(find.text('Fishing'), findsOne);
  });

  testWidgets('one category draws in its colour alone, with no legend', (
    tester,
  ) async {
    await pump(tester, () async => data([row('colony', 3, 9, 11)]));

    final colours = {
      for (final group in bars(tester).barGroups)
        for (final item in group.barRods.single.rodStackItems) item.color,
    };
    final brightness = Theme.of(
      tester.element(find.byType(BarChart)),
    ).brightness;
    expect(colours, {chartColorFor('#4CAF93', brightness)});
    expect(find.byType(ChartLegend), findsNothing);
  });

  testWidgets('holds its height while reading, and draws nothing once the '
      'time it charted is gone', (tester) async {
    final reading = Completer<InsightsChartData>();
    await pump(tester, () => reading.future);
    expect(
      tester.getSize(find.byType(FrontLoggedTimeChartCard)).height,
      greaterThan(0),
    );
    expect(find.byType(BarChart), findsNothing);

    reading.complete(data(const []));
    await tester.pump();
    await tester.pump();
    expect(find.byType(BarChart), findsNothing);
    expect(tester.getSize(find.byType(FrontLoggedTimeChartCard)).height, 0);
  });

  testWidgets('expanding opens the Insights chart card for the same days, '
      'titled with them', (tester) async {
    await pump(tester, () async => data([row('colony', 0, 9, 12)]));

    await tester.tap(find.byIcon(LottiIcons.expandFull));
    await tester.pumpAndSettle();

    final card = tester.widget<InsightsChartCard>(
      find.byType(InsightsChartCard),
    );
    expect(card.chartData.bucketStarts.first, dayStart(monday));
    expect(card.chartData.bucketStarts, hasLength(7));
    expect(find.text('Oct 26 – Nov 1'), findsOne);
  });
}
