import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/state/front_pull_request_providers.dart';
import 'package:lotti/features/front_agent/ui/front_pull_request_chart_card.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  // Monday 2026-10-26 through Wednesday 2026-10-28: days long past.
  final monday = epochDay(DateTime(2026, 10, 26));

  FrontPullRequestChart chart(int days) => FrontPullRequestChart(
    range: InsightsRange(startDay: monday, endDayExclusive: monday + days),
    categoryIds: const {},
  );

  FrontPullRequestDays days(int count) => frontPullRequestDays(
    [
      FrontPullRequest(
        key: 'p/c#1',
        title: 'One',
        createdAt: dayStart(monday).add(const Duration(hours: 9)),
        additions: 120,
        deletions: 30,
      ),
      FrontPullRequest(
        key: 'p/c#2',
        title: 'Two',
        createdAt: dayStart(monday).add(const Duration(hours: 15)),
        additions: 80,
        deletions: 10,
      ),
      if (count > 2)
        FrontPullRequest(
          key: 'p/c#3',
          title: 'Three',
          createdAt: dayStart(monday + 2).add(const Duration(hours: 9)),
          additions: 5,
          deletions: 400,
        ),
    ],
    chart(count).range,
  );

  Future<void> pump(
    WidgetTester tester,
    FrontPullRequestChart shown,
    Future<FrontPullRequestDays> Function() load,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(body: FrontPullRequestChartCard(chart: shown)),
        overrides: [
          frontPullRequestChartProvider.overrideWith(
            (ref, _) => Stream.fromFuture(load()),
          ),
        ],
      ),
    );
    await tester.pump();
  }

  List<double> barTops(WidgetTester tester) => [
    for (final group
        in tester.widget<BarChart>(find.byType(BarChart)).data.barGroups)
      group.barRods.single.toY,
  ];

  testWidgets('draws one bar per day of pull requests opened, then of the '
      'lines added or deleted as the toggle picks', (tester) async {
    await pump(tester, chart(3), () async => days(3));

    expect(barTops(tester), [2, 0, 1]);

    await tester.tap(find.text('Lines added').last);
    await tester.pump();
    expect(barTops(tester), [200, 0, 5]);

    await tester.tap(find.text('Lines deleted').last);
    await tester.pump();
    expect(barTops(tester), [40, 0, 400]);
  });

  testWidgets('the running total draws each day as the sum so far', (
    tester,
  ) async {
    await pump(tester, chart(3), () async => days(3));
    await tester.tap(find.text('Lines added').last);
    await tester.tap(find.text('Running total').last);
    await tester.pump();

    expect(find.byType(BarChart), findsNothing);
    final line = tester
        .widget<LineChart>(find.byType(LineChart))
        .data
        .lineBarsData
        .single;
    expect(line.spots.map((spot) => spot.y), [200, 200, 205]);

    await tester.tap(find.text('Per day').last);
    await tester.pump();
    expect(barTops(tester), [200, 0, 5]);
  });

  testWidgets('a single day has no running total to offer', (tester) async {
    await pump(tester, chart(1), () async => days(1));

    expect(barTops(tester), [2]);
    expect(find.text('Running total'), findsNothing);
  });

  testWidgets('holds its height while it reads, and draws nothing once no '
      'pull request it counted is left', (tester) async {
    final pending = Completer<FrontPullRequestDays>();
    await pump(tester, chart(3), () => pending.future);
    expect(
      tester.getSize(find.byType(FrontPullRequestChartCard)).height,
      ChartSizes.inline,
    );
    expect(find.byType(BarChart), findsNothing);

    pending.complete(frontPullRequestDays(const [], chart(3).range));
    // The stream's event, then the rebuild.
    await tester.pump();
    await tester.pump();
    expect(tester.getSize(find.byType(FrontPullRequestChartCard)).height, 0);
  });
}
