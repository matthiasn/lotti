import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';

import '../../categories/test_utils.dart';
import '../test_utils.dart';

void main() {
  group('ProjectsSearchMode', () {
    test('has expected values', () {
      expect(ProjectsSearchMode.values, hasLength(3));
      expect(
        ProjectsSearchMode.values,
        containsAll([
          ProjectsSearchMode.disabled,
          ProjectsSearchMode.localText,
          ProjectsSearchMode.vector,
        ]),
      );
    });
  });

  group('ProjectsQuery', () {
    group('matchesCategory', () {
      test('empty categoryIds matches any categoryId', () {
        const query = ProjectsQuery();
        expect(query.matchesCategory('cat-1'), isTrue);
        expect(query.matchesCategory('cat-2'), isTrue);
      });

      test('empty categoryIds matches null categoryId', () {
        const query = ProjectsQuery();
        expect(query.matchesCategory(null), isTrue);
      });

      test('non-empty categoryIds filters matching categoryId', () {
        const query = ProjectsQuery(categoryIds: {'cat-1', 'cat-3'});
        expect(query.matchesCategory('cat-1'), isTrue);
        expect(query.matchesCategory('cat-3'), isTrue);
        expect(query.matchesCategory('cat-2'), isFalse);
      });

      test('non-empty categoryIds rejects null categoryId', () {
        const query = ProjectsQuery(categoryIds: {'cat-1'});
        expect(query.matchesCategory(null), isFalse);
      });
    });

    group('equality and hashCode', () {
      test('equal when categoryIds match', () {
        const a = ProjectsQuery(categoryIds: {'x', 'y'});
        const b = ProjectsQuery(categoryIds: {'y', 'x'});
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('not equal when categoryIds differ', () {
        const a = ProjectsQuery(categoryIds: {'x'});
        const b = ProjectsQuery(categoryIds: {'y'});
        expect(a, isNot(equals(b)));
      });

      test('identical instance is equal', () {
        const query = ProjectsQuery(categoryIds: {'a'});
        expect(query, equals(query));
      });

      test('not equal to non-ProjectsQuery object', () {
        const query = ProjectsQuery();
        expect(query, isNot(equals('not a query')));
      });
    });

    group('copyWith', () {
      test('copies with new categoryIds', () {
        const original = ProjectsQuery(categoryIds: {'a'});
        final copied = original.copyWith(categoryIds: {'b', 'c'});
        expect(copied.categoryIds, equals({'b', 'c'}));
      });

      test('retains original categoryIds when not specified', () {
        const original = ProjectsQuery(categoryIds: {'a'});
        final copied = original.copyWith();
        expect(copied.categoryIds, equals({'a'}));
      });
    });
  });

  group('ProjectsFilter', () {
    group('equality and hashCode', () {
      test('equal when all fields match', () {
        const a = ProjectsFilter(
          selectedCategoryIds: {'cat-1'},
          textQuery: 'hello',
          searchMode: ProjectsSearchMode.localText,
        );
        const b = ProjectsFilter(
          selectedCategoryIds: {'cat-1'},
          textQuery: 'hello',
          searchMode: ProjectsSearchMode.localText,
        );
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('not equal when selectedCategoryIds differ', () {
        const a = ProjectsFilter(selectedCategoryIds: {'cat-1'});
        const b = ProjectsFilter(selectedCategoryIds: {'cat-2'});
        expect(a, isNot(equals(b)));
      });

      test('not equal when textQuery differs', () {
        const a = ProjectsFilter(textQuery: 'alpha');
        const b = ProjectsFilter(textQuery: 'beta');
        expect(a, isNot(equals(b)));
      });

      test('not equal when searchMode differs', () {
        // ignore: avoid_redundant_argument_values
        const a = ProjectsFilter(searchMode: ProjectsSearchMode.disabled);
        const b = ProjectsFilter(searchMode: ProjectsSearchMode.vector);
        expect(a, isNot(equals(b)));
      });

      test('identical instance is equal', () {
        const filter = ProjectsFilter(textQuery: 'x');
        expect(filter, equals(filter));
      });

      test('not equal to non-ProjectsFilter object', () {
        const filter = ProjectsFilter();
        expect(filter, isNot(equals(42)));
      });

      test('set order does not affect equality', () {
        const a = ProjectsFilter(selectedCategoryIds: {'x', 'y'});
        const b = ProjectsFilter(selectedCategoryIds: {'y', 'x'});
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });
    });

    group('copyWith', () {
      test('copies with new selectedCategoryIds', () {
        const original = ProjectsFilter(selectedCategoryIds: {'a'});
        final copied = original.copyWith(selectedCategoryIds: {'b'});
        expect(copied.selectedCategoryIds, equals({'b'}));
        expect(copied.textQuery, isEmpty);
        expect(copied.searchMode, ProjectsSearchMode.disabled);
      });

      test('copies with new textQuery', () {
        const original = ProjectsFilter(textQuery: 'old');
        final copied = original.copyWith(textQuery: 'new');
        expect(copied.textQuery, 'new');
      });

      test('copies with new searchMode', () {
        const original = ProjectsFilter();
        final copied = original.copyWith(searchMode: ProjectsSearchMode.vector);
        expect(copied.searchMode, ProjectsSearchMode.vector);
      });

      test('retains all fields when no arguments given', () {
        const original = ProjectsFilter(
          selectedCategoryIds: {'z'},
          textQuery: 'keep',
          searchMode: ProjectsSearchMode.localText,
        );
        final copied = original.copyWith();
        expect(copied, equals(original));
      });
    });
  });

  group('ProjectTaskRollupData', () {
    group('completionRatio', () {
      test('returns 0 when totalTaskCount is 0', () {
        const rollup = ProjectTaskRollupData();
        expect(rollup.completionRatio, 0.0);
      });

      test('returns correct ratio for normal case', () {
        const rollup = ProjectTaskRollupData(
          completedTaskCount: 3,
          totalTaskCount: 4,
        );
        expect(rollup.completionRatio, 0.75);
      });

      test('returns 1.0 when all tasks are completed', () {
        const rollup = ProjectTaskRollupData(
          completedTaskCount: 5,
          totalTaskCount: 5,
        );
        expect(rollup.completionRatio, 1.0);
      });

      test('returns 0.0 when no tasks are completed', () {
        const rollup = ProjectTaskRollupData(
          totalTaskCount: 10,
        );
        expect(rollup.completionRatio, 0.0);
      });
    });

    group('completionPercent', () {
      test('returns 0 when totalTaskCount is 0', () {
        const rollup = ProjectTaskRollupData();
        expect(rollup.completionPercent, 0);
      });

      test('rounds to nearest integer', () {
        const rollup = ProjectTaskRollupData(
          completedTaskCount: 1,
          totalTaskCount: 3,
        );
        // 1/3 = 0.3333... * 100 = 33.33... rounds to 33
        expect(rollup.completionPercent, 33);
      });

      test('rounds up at 0.5', () {
        const rollup = ProjectTaskRollupData(
          completedTaskCount: 1,
          totalTaskCount: 6,
        );
        // 1/6 = 0.1666... * 100 = 16.66... rounds to 17
        expect(rollup.completionPercent, 17);
      });

      test('returns 100 when all tasks are completed', () {
        const rollup = ProjectTaskRollupData(
          completedTaskCount: 7,
          totalTaskCount: 7,
        );
        expect(rollup.completionPercent, 100);
      });
    });
  });

  group('ProjectListItemData', () {
    final category = CategoryTestUtils.createTestCategory(
      id: 'cat-work',
      name: 'Work',
      color: '#FF0000',
    );

    group('categoryId', () {
      test('returns categoryId from project meta', () {
        final item = makeTestProjectListItemData(
          project: makeTestProject(categoryId: 'cat-work'),
          category: category,
        );
        expect(item.categoryId, 'cat-work');
      });

      test('returns null when project has no categoryId', () {
        final item = makeTestProjectListItemData(
          project: makeTestProject(),
        );
        expect(item.categoryId, isNull);
      });
    });

    group('categoryName', () {
      test('returns category name when category is set', () {
        final item = makeTestProjectListItemData(
          project: makeTestProject(categoryId: 'cat-work'),
          category: category,
        );
        expect(item.categoryName, 'Work');
      });

      test('returns empty string when category is null', () {
        final project = makeTestProject();
        final item = ProjectListItemData(
          project: project,
          category: null,
          taskRollup: const ProjectTaskRollupData(),
        );
        expect(item.categoryName, isEmpty);
      });
    });

    group('status', () {
      test('returns project status', () {
        final openStatus = ProjectStatus.open(
          id: 'status-1',
          // ignore: avoid_redundant_argument_values
          createdAt: DateTime(2024, 6, 1),
          utcOffset: 60,
        );
        final item = makeTestProjectListItemData(
          project: makeTestProject(status: openStatus),
          category: category,
        );
        expect(item.status, equals(openStatus));
      });
    });

    group('targetDate', () {
      test('returns target date when set', () {
        final target = DateTime(2025, 12, 31);
        final item = makeTestProjectListItemData(
          project: makeTestProject(targetDate: target),
          category: category,
        );
        expect(item.targetDate, target);
      });

      test('returns null when no target date', () {
        final item = makeTestProjectListItemData(
          project: makeTestProject(),
          category: category,
        );
        expect(item.targetDate, isNull);
      });
    });

    group('searchableText', () {
      test('includes title and category name', () {
        final item = makeTestProjectListItemData(
          project: makeTestProject(
            title: 'Alpha Project',
            categoryId: 'cat-work',
          ),
          category: category,
        );
        expect(item.searchableText, contains('Alpha Project'));
        expect(item.searchableText, contains('Work'));
      });

      test('includes plain text from entryText when present', () {
        final baseProject = makeTestProject(
          title: 'Beta Project',
          categoryId: 'cat-work',
        );
        final project = baseProject.copyWith(
          entryText: const EntryText(plainText: 'some description'),
        );

        final item = ProjectListItemData(
          project: project,
          category: category,
          taskRollup: const ProjectTaskRollupData(),
        );

        expect(item.searchableText, contains('some description'));
        expect(item.searchableText, contains('Beta Project'));
        expect(item.searchableText, contains('Work'));
      });

      test('omits blank segments', () {
        final project = makeTestProject(title: 'Only Title');
        // makeTestProject does not set entryText, so plainText is null.
        // Category is null, so categoryName is empty.
        final item = ProjectListItemData(
          project: project,
          category: null,
          taskRollup: const ProjectTaskRollupData(),
        );
        // Only title should appear, no trailing spaces or separators
        expect(item.searchableText, 'Only Title');
      });
    });
  });

  group('ProjectCategoryGroup', () {
    final category = CategoryTestUtils.createTestCategory(
      id: 'cat-1',
      name: 'Engineering',
    );

    test('projectCount returns number of projects', () {
      final group = ProjectCategoryGroup(
        categoryId: 'cat-1',
        category: category,
        projects: [
          makeTestProjectListItemData(category: category),
          makeTestProjectListItemData(category: category),
          makeTestProjectListItemData(category: category),
        ],
      );
      expect(group.projectCount, 3);
    });

    test('projectCount returns 0 for empty list', () {
      final group = ProjectCategoryGroup(
        categoryId: 'cat-1',
        category: category,
        projects: const [],
      );
      expect(group.projectCount, 0);
    });

    group('copyWith', () {
      test('replaces projects list', () {
        final original = ProjectCategoryGroup(
          categoryId: 'cat-1',
          category: category,
          projects: [makeTestProjectListItemData(category: category)],
        );
        final copied = original.copyWith(projects: const []);
        expect(copied.projectCount, 0);
        expect(copied.categoryId, 'cat-1');
        expect(copied.category, category);
      });

      test('retains projects when not specified', () {
        final item = makeTestProjectListItemData(category: category);
        final original = ProjectCategoryGroup(
          categoryId: 'cat-1',
          category: category,
          projects: [item],
        );
        final copied = original.copyWith();
        expect(copied.projects, hasLength(1));
        expect(copied.categoryId, original.categoryId);
      });
    });
  });

  group('ProjectsOverviewSnapshot', () {
    final category = CategoryTestUtils.createTestCategory(
      id: 'cat-1',
      name: 'Design',
    );

    group('totalProjectCount', () {
      test('sums project counts across all groups', () {
        final snapshot = ProjectsOverviewSnapshot(
          groups: [
            ProjectCategoryGroup(
              categoryId: 'cat-1',
              category: category,
              projects: [
                makeTestProjectListItemData(category: category),
                makeTestProjectListItemData(category: category),
              ],
            ),
            ProjectCategoryGroup(
              categoryId: 'cat-2',
              category: null,
              projects: [
                makeTestProjectListItemData(),
              ],
            ),
          ],
        );
        expect(snapshot.totalProjectCount, 3);
      });

      test('returns 0 when there are no groups', () {
        const snapshot = ProjectsOverviewSnapshot(groups: []);
        expect(snapshot.totalProjectCount, 0);
      });

      test('returns 0 when all groups are empty', () {
        final snapshot = ProjectsOverviewSnapshot(
          groups: [
            ProjectCategoryGroup(
              categoryId: 'cat-1',
              category: category,
              projects: const [],
            ),
          ],
        );
        expect(snapshot.totalProjectCount, 0);
      });
    });

    group('isEmpty', () {
      test('returns true when no projects exist', () {
        const snapshot = ProjectsOverviewSnapshot(groups: []);
        expect(snapshot.isEmpty, isTrue);
      });

      test('returns true when all groups have empty project lists', () {
        final snapshot = ProjectsOverviewSnapshot(
          groups: [
            ProjectCategoryGroup(
              categoryId: 'cat-1',
              category: category,
              projects: const [],
            ),
          ],
        );
        expect(snapshot.isEmpty, isTrue);
      });

      test('returns false when projects exist', () {
        final snapshot = ProjectsOverviewSnapshot(
          groups: [
            ProjectCategoryGroup(
              categoryId: 'cat-1',
              category: category,
              projects: [makeTestProjectListItemData(category: category)],
            ),
          ],
        );
        expect(snapshot.isEmpty, isFalse);
      });
    });
  });
}
