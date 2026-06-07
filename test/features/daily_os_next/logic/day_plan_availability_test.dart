import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/daily_os_next/logic/day_plan_availability.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_attributes.dart';

import '../../categories/test_utils.dart';
import '../../projects/test_utils.dart';

void main() {
  final testDate = DateTime(2026, 3, 15, 10);

  ProjectStatus statusOf(ProjectStatusKind kind) =>
      buildProjectStatus(kind, testDate);

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

  group('dayPlanAllowedCategoryIds', () {
    test('returns the ids of available categories only', () {
      final categories = [
        CategoryTestUtils.createTestCategory(
          id: 'c-on',
          isAvailableForDayPlan: true,
        ),
        CategoryTestUtils.createTestCategory(id: 'c-unset'),
        CategoryTestUtils.createTestCategory(
          id: 'c-also-on',
          name: 'Another',
          isAvailableForDayPlan: true,
        ),
      ];

      expect(
        dayPlanAllowedCategoryIds(categories),
        {'c-on', 'c-also-on'},
      );
    });

    test('strict opt-in: empty input and unflagged input both yield '
        'an empty set', () {
      expect(dayPlanAllowedCategoryIds(const []), isEmpty);
      expect(
        dayPlanAllowedCategoryIds([
          CategoryTestUtils.createTestCategory(id: 'c-unset'),
        ]),
        isEmpty,
      );
    });
  });

  group('dayPlanProjectPriority', () {
    test('maps every status to its day-plan tier', () {
      const expectedByKind = <ProjectStatusKind, DayPlanProjectPriority>{
        ProjectStatusKind.open: DayPlanProjectPriority.opportunistic,
        ProjectStatusKind.active: DayPlanProjectPriority.scheduled,
        ProjectStatusKind.monitoring: DayPlanProjectPriority.opportunistic,
        ProjectStatusKind.onHold: DayPlanProjectPriority.opportunistic,
        ProjectStatusKind.completed: DayPlanProjectPriority.unavailable,
        ProjectStatusKind.archived: DayPlanProjectPriority.unavailable,
      };
      // Guards against a new status variant being added without deciding
      // its day-plan tier here.
      expect(expectedByKind.keys, containsAll(ProjectStatusKind.values));

      for (final kind in ProjectStatusKind.values) {
        final project = makeTestProject(status: statusOf(kind));
        expect(
          dayPlanProjectPriority(project.data),
          expectedByKind[kind],
          reason: '$kind',
        );
      }
    });
  });

  group('isProjectAvailableForDayPlan', () {
    test('every non-closed project is available at some priority', () {
      const expectedByKind = <ProjectStatusKind, bool>{
        ProjectStatusKind.open: true,
        ProjectStatusKind.active: true,
        ProjectStatusKind.monitoring: true,
        ProjectStatusKind.onHold: true,
        ProjectStatusKind.completed: false,
        ProjectStatusKind.archived: false,
      };
      expect(expectedByKind.keys, containsAll(ProjectStatusKind.values));

      for (final kind in ProjectStatusKind.values) {
        final project = makeTestProject(status: statusOf(kind));
        expect(
          isProjectAvailableForDayPlan(project.data),
          expectedByKind[kind],
          reason: '$kind',
        );
      }
    });
  });

  group('filterDayPlanProjects', () {
    test(
      'keeps non-closed projects, scheduled before opportunistic, '
      'and drops closed ones',
      () {
        final projects = [
          for (final kind in ProjectStatusKind.values)
            makeTestProject(id: 'p-${kind.name}', status: statusOf(kind)),
        ];

        final result = filterDayPlanProjects(projects);

        // Active first (scheduled tier), then the opportunistic tier in
        // input order; completed/archived dropped entirely.
        expect(result.map((p) => p.meta.id), [
          'p-active',
          'p-open',
          'p-monitoring',
          'p-onHold',
        ]);
      },
    );

    test('drops soft-deleted projects even when active', () {
      final active = makeTestProject(
        id: 'p-live',
        status: statusOf(ProjectStatusKind.active),
      );
      final deleted = makeTestProject(
        id: 'p-deleted',
        status: statusOf(ProjectStatusKind.active),
      );
      final deletedEntry = deleted.copyWith(
        meta: deleted.meta.copyWith(deletedAt: testDate),
      );

      final result = filterDayPlanProjects([active, deletedEntry]);

      expect(result.map((p) => p.meta.id), ['p-live']);
    });

    test('returns empty for empty input', () {
      expect(filterDayPlanProjects(const []), isEmpty);
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
