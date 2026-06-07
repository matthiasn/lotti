import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/insights/model/insights_models.dart';

import '../../categories/test_utils.dart';

/// Deterministic, realistic-looking scenario data for Insights widget and
/// screenshot tests. Everything derives from a fixed `now` so renders are
/// reproducible.
class InsightsScenario {
  const InsightsScenario({required this.categories, required this.rows});

  final List<CategoryDefinition> categories;
  final List<InsightsTimeRow> rows;
}

CategoryDefinition _category(String id, String name, String color) =>
    CategoryTestUtils.createTestCategory(id: id, name: name, color: color);

/// The core category set used across scenarios — colors deliberately
/// include saturated picker-style values to exercise the muting logic.
final List<CategoryDefinition> insightsScenarioCategories = [
  _category('cat-client', 'Client Work', '#3B82F6'),
  _category('cat-deep', 'Deep Work', '#8B5CF6'),
  _category('cat-meetings', 'Meetings', '#EF4444'),
  _category('cat-admin', 'Admin', '#F59E0B'),
  _category('cat-learning', 'Learning', '#10B981'),
  _category('cat-side', 'Side Project', '#EC4899'),
  _category('cat-health', 'Health', '#06B6D4'),
  _category('cat-writing', 'Writing', '#14B8A6'),
  _category('cat-reading', 'Reading', '#A3E635'),
  _category('cat-errands', 'Errands', '#EAB308'),
];

InsightsTimeRow _row(DateTime start, int minutes, String? categoryId) =>
    InsightsTimeRow(
      dateFrom: start,
      dateTo: DateTime(
        start.year,
        start.month,
        start.day,
        start.hour,
        start.minute + minutes,
      ),
      categoryId: categoryId,
    );

/// A busy knowledge-worker year: weekday client/deep/meeting/admin blocks,
/// weekend side-project and health time, occasional uncategorized stretches
/// and one midnight-crossing block per week.
List<InsightsTimeRow> insightsScenarioRows(
  DateTime now, {
  int days = 540,
  bool manyCategories = false,
}) {
  final rows = <InsightsTimeRow>[];
  for (var d = 0; d < days; d++) {
    final day = DateTime(now.year, now.month, now.day - d);
    final seed = d * 7919 % 104729; // deterministic pseudo-noise
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

    if (isWeekend) {
      rows
        ..add(
          _row(
            DateTime(day.year, day.month, day.day, 10, seed % 30),
            100 + seed % 90,
            'cat-side',
          ),
        )
        ..add(
          _row(DateTime(day.year, day.month, day.day, 8, 30), 45, 'cat-health'),
        );
      if (seed.isEven) {
        rows.add(
          _row(DateTime(day.year, day.month, day.day, 14), 60, 'cat-errands'),
        );
      }
    } else {
      rows
        ..add(
          _row(
            DateTime(day.year, day.month, day.day, 9, seed % 4 * 15),
            120 + seed * 37 % 90,
            'cat-client',
          ),
        )
        ..add(
          _row(
            DateTime(day.year, day.month, day.day, 13),
            30 + seed * 13 % 60,
            'cat-meetings',
          ),
        )
        ..add(
          _row(
            DateTime(day.year, day.month, day.day, 17, 30),
            20 + seed * 7 % 40,
            'cat-admin',
          ),
        );
      if (seed % 5 != 0) {
        rows.add(
          _row(
            DateTime(day.year, day.month, day.day, 15),
            60 + seed * 29 % 100,
            'cat-deep',
          ),
        );
      }
      if (seed % 3 == 0) {
        rows.add(
          _row(
            DateTime(day.year, day.month, day.day, 20),
            30 + seed % 30,
            'cat-learning',
          ),
        );
      }
      if (manyCategories) {
        rows.add(
          _row(
            DateTime(day.year, day.month, day.day, 7, 30),
            25 + seed % 25,
            seed.isEven ? 'cat-writing' : 'cat-reading',
          ),
        );
        if (seed % 4 == 1) {
          rows.add(
            _row(DateTime(day.year, day.month, day.day, 19), 35, 'cat-health'),
          );
        }
      }
    }

    // Uncategorized stretches and a weekly midnight-crossing block.
    if (seed % 4 == 0) {
      rows.add(_row(DateTime(day.year, day.month, day.day, 12, 30), 15, null));
    }
    if (day.weekday == DateTime.friday) {
      rows.add(
        _row(DateTime(day.year, day.month, day.day, 23, 15), 90, 'cat-client'),
      );
    }
  }
  return rows;
}

/// Three lonely entries within the trailing 30 days.
List<InsightsTimeRow> insightsSparseRows(DateTime now) => [
  _row(DateTime(now.year, now.month, now.day - 2, 9), 35, 'cat-client'),
  _row(DateTime(now.year, now.month, now.day - 9, 14), 20, 'cat-admin'),
  _row(DateTime(now.year, now.month, now.day - 20, 11), 50, null),
];

/// One category only, trailing week.
List<InsightsTimeRow> insightsSingleCategoryRows(DateTime now) => [
  for (var d = 0; d < 7; d++)
    _row(
      DateTime(now.year, now.month, now.day - d, 9 + d % 3),
      90 + d * 20,
      'cat-client',
    ),
];
