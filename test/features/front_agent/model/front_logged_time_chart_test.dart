import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/insights/model/insights_models.dart';

void main() {
  const chart = FrontLoggedTimeChart(
    range: InsightsRange(startDay: 20396, endDayExclusive: 20403),
    categoryIds: {'work', 'colony'},
  );

  test('stores the days and the scope, ids sorted, and reads them back', () {
    final json = chart.toJson();
    expect(json, {
      'startDay': 20396,
      'endDayExclusive': 20403,
      'categoryIds': ['colony', 'work'],
    });
    expect(FrontLoggedTimeChart.fromJson(json), chart);
    expect(FrontLoggedTimeChart.fromJson(json).hashCode, chart.hashCode);
  });

  test('a stored chart this build cannot read is none', () {
    for (final json in <Object?>[
      null,
      'chart',
      {'startDay': 20396, 'endDayExclusive': 20403},
      {
        'startDay': '20396',
        'endDayExclusive': 20403,
        'categoryIds': <String>[],
      },
      // An empty or backwards range.
      {'startDay': 20403, 'endDayExclusive': 20403, 'categoryIds': <String>[]},
    ]) {
      expect(FrontLoggedTimeChart.fromJson(json), isNull, reason: '$json');
    }
  });

  test('a different scope or range is a different chart', () {
    expect(
      chart ==
          const FrontLoggedTimeChart(
            range: InsightsRange(startDay: 20396, endDayExclusive: 20403),
            categoryIds: {'work'},
          ),
      isFalse,
    );
    expect(
      chart ==
          const FrontLoggedTimeChart(
            range: InsightsRange(startDay: 20397, endDayExclusive: 20403),
            categoryIds: {'work', 'colony'},
          ),
      isFalse,
    );
  });
}
