import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/daily_os_next/logic/day_plan_availability.dart';

import '../../categories/test_utils.dart';

void main() {
  final testDate = DateTime(2026, 3, 15, 10);

  group('isCategoryAvailableForDayPlan', () {
    test('full truth table over flag × active × deleted', () {
      // (flag, active, deleted) -> expected availability. Strict opt-in:
      // only an explicitly-true flag on an active, non-deleted category
      // makes it available; null (never set) behaves like false.
      const cases = <(bool?, bool, bool, bool)>[
        (true, true, false, true),
        (true, true, true, false),
        (true, false, false, false),
        (true, false, true, false),
        (false, true, false, false),
        (false, false, false, false),
        (false, true, true, false),
        (false, false, true, false),
        (null, true, false, false),
        (null, false, false, false),
        (null, true, true, false),
        (null, false, true, false),
      ];

      for (final (flag, active, deleted, expected) in cases) {
        final category = CategoryTestUtils.createTestCategory(
          isAvailableForDayPlan: flag,
          active: active,
          deletedAt: deleted ? testDate : null,
        );
        expect(
          isCategoryAvailableForDayPlan(category),
          expected,
          reason: 'flag=$flag active=$active deleted=$deleted',
        );
      }
    });
  });

  group('filterDayPlanCategories', () {
    test('keeps only available categories, sorted by name '
        'case-insensitively', () {
      final categories = [
        CategoryTestUtils.createTestCategory(
          id: 'c-banana',
          name: 'banana',
          isAvailableForDayPlan: true,
        ),
        CategoryTestUtils.createTestCategory(
          id: 'c-apple',
          name: 'Apple',
          isAvailableForDayPlan: true,
        ),
        CategoryTestUtils.createTestCategory(
          id: 'c-unflagged',
          name: 'Unflagged',
        ),
        CategoryTestUtils.createTestCategory(
          id: 'c-off',
          name: 'Opted out',
          isAvailableForDayPlan: false,
        ),
        CategoryTestUtils.createTestCategory(
          id: 'c-inactive',
          name: 'Inactive',
          active: false,
          isAvailableForDayPlan: true,
        ),
        CategoryTestUtils.createTestCategory(
          id: 'c-deleted',
          name: 'Deleted',
          isAvailableForDayPlan: true,
          deletedAt: testDate,
        ),
      ];

      final result = filterDayPlanCategories(categories);

      expect(result.map((c) => c.id), ['c-apple', 'c-banana']);
    });

    test('returns an empty universe when nothing is opted in', () {
      final categories = [
        CategoryTestUtils.createTestCategory(id: 'c-1'),
        CategoryTestUtils.createTestCategory(
          id: 'c-2',
          isAvailableForDayPlan: false,
        ),
      ];

      expect(filterDayPlanCategories(categories), isEmpty);
      expect(filterDayPlanCategories(const []), isEmpty);
    });
  });

  group('availability properties', () {
    glados.Glados<int>(
      glados.any.intInRange(0, 1000),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'category availability equals active && !deleted && flag == true',
      (seed) {
        final flag = switch (seed % 3) {
          0 => null,
          1 => false,
          _ => true,
        };
        final active = seed.isEven;
        final deleted = seed % 5 == 0;
        final category = CategoryTestUtils.createTestCategory(
          isAvailableForDayPlan: flag,
          active: active,
          deletedAt: deleted ? testDate : null,
        );
        expect(
          isCategoryAvailableForDayPlan(category),
          active && !deleted && flag == true,
          reason: 'flag=$flag active=$active deleted=$deleted',
        );
      },
      tags: 'glados',
    );
  });
}
