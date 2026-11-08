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

  test('stores the categories the user named, and a chart stored before '
      'they were reads back with none', () {
    const named = FrontLoggedTimeChart(
      range: InsightsRange(startDay: 20396, endDayExclusive: 20403),
      categoryIds: {'work', 'colony'},
      namedCategoryIds: {'work'},
    );
    final json = named.toJson();
    expect(json['namedCategoryIds'], ['work']);
    expect(FrontLoggedTimeChart.fromJson(json), named);
    expect(FrontLoggedTimeChart.fromJson(json).hashCode, named.hashCode);
    // Naming a category makes it a different chart.
    expect(named == chart, isFalse);
    expect(json.containsKey('namedCategoryIds'), isTrue);
    expect(chart.toJson().containsKey('namedCategoryIds'), isFalse);
    expect(
      FrontLoggedTimeChart.fromJson(chart.toJson())!.namedCategoryIds,
      isEmpty,
    );
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
      {
        'startDay': 20396,
        'endDayExclusive': 20403,
        'categoryIds': <String>[],
        'namedCategoryIds': 'work',
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
