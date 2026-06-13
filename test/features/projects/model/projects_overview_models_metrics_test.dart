import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';

import '../../categories/test_utils.dart';
import '../test_utils.dart';
import 'projects_overview_models_test_helpers.dart';

void main() {
  group('applyProjectsFilter', () {
    final catEngineering = CategoryTestUtils.createTestCategory(
      id: 'cat-eng',
      name: 'Engineering',
      color: '#00FF00',
    );
    final catDesign = CategoryTestUtils.createTestCategory(
      id: 'cat-design',
      name: 'Design',
      color: '#FF0000',
    );

    final openStatus = ProjectStatus.open(
      id: 'status-open',
      createdAt: DateTime(2024, 3, 15),
      utcOffset: 0,
    );
    final activeStatus = ProjectStatus.active(
      id: 'status-active',
      createdAt: DateTime(2024, 3, 15),
      utcOffset: 0,
    );
    final completedStatus = ProjectStatus.completed(
      id: 'status-completed',
      createdAt: DateTime(2024, 3, 15),
      utcOffset: 0,
    );

    ProjectListItemData makeItem({
      required String title,
      required ProjectStatus status,
      CategoryDefinition? category,
      String? categoryId,
    }) {
      final project = makeTestProject(
        title: title,
        status: status,
        categoryId: categoryId ?? category?.id,
      );
      return ProjectListItemData(
        project: project,
        category: category,
        taskRollup: const ProjectTaskRollupData(),
      );
    }

    ProjectsOverviewSnapshot makeSnapshot() {
      return ProjectsOverviewSnapshot(
        groups: [
          ProjectCategoryGroup(
            categoryId: 'cat-eng',
            category: catEngineering,
            projects: [
              makeItem(
                title: 'Backend API',
                status: openStatus,
                category: catEngineering,
                categoryId: 'cat-eng',
              ),
              makeItem(
                title: 'CI Pipeline',
                status: activeStatus,
                category: catEngineering,
                categoryId: 'cat-eng',
              ),
              makeItem(
                title: 'Legacy Cleanup',
                status: completedStatus,
                category: catEngineering,
                categoryId: 'cat-eng',
              ),
            ],
          ),
          ProjectCategoryGroup(
            categoryId: 'cat-design',
            category: catDesign,
            projects: [
              makeItem(
                title: 'Brand Refresh',
                status: openStatus,
                category: catDesign,
                categoryId: 'cat-design',
              ),
              makeItem(
                title: 'Icon System',
                status: activeStatus,
                category: catDesign,
                categoryId: 'cat-design',
              ),
            ],
          ),
        ],
      );
    }

    test('no filters returns all groups unchanged', () {
      final snapshot = makeSnapshot();
      const filter = ProjectsFilter();
      final result = applyProjectsFilter(snapshot, filter);

      expect(result, hasLength(2));
      expect(result[0].projects, hasLength(3));
      expect(result[1].projects, hasLength(2));
    });

    test('status filter includes only projects with matching status', () {
      final snapshot = makeSnapshot();
      const filter = ProjectsFilter(
        selectedStatusIds: {ProjectStatusFilterIds.open},
      );
      final result = applyProjectsFilter(snapshot, filter);

      expect(result, hasLength(2));
      // Engineering: only Backend API (open)
      expect(result[0].projects, hasLength(1));
      expect(
        result[0].projects[0].project.data.title,
        'Backend API',
      );
      // Design: only Brand Refresh (open)
      expect(result[1].projects, hasLength(1));
      expect(
        result[1].projects[0].project.data.title,
        'Brand Refresh',
      );
    });

    test('category filter includes only groups with matching categoryId', () {
      final snapshot = makeSnapshot();
      const filter = ProjectsFilter(
        selectedCategoryIds: {'cat-design'},
      );
      final result = applyProjectsFilter(snapshot, filter);

      expect(result, hasLength(1));
      expect(result[0].categoryId, 'cat-design');
      expect(result[0].projects, hasLength(2));
    });

    test(
      'text query with localText mode filters by searchable text',
      () {
        final snapshot = makeSnapshot();
        const filter = ProjectsFilter(
          textQuery: 'backend',
          searchMode: ProjectsSearchMode.localText,
        );
        final result = applyProjectsFilter(snapshot, filter);

        expect(result, hasLength(1));
        expect(result[0].categoryId, 'cat-eng');
        expect(result[0].projects, hasLength(1));
        expect(
          result[0].projects[0].project.data.title,
          'Backend API',
        );
      },
    );

    test(
      'text query with disabled mode does not filter by text',
      () {
        final snapshot = makeSnapshot();
        const filter = ProjectsFilter(
          textQuery: 'backend',
          // ignore: avoid_redundant_argument_values
          searchMode: ProjectsSearchMode.disabled,
        );
        final result = applyProjectsFilter(snapshot, filter);

        // All groups and projects remain because search mode is disabled
        expect(result, hasLength(2));
        expect(result[0].projects, hasLength(3));
        expect(result[1].projects, hasLength(2));
      },
    );

    test('empty groups are removed after filtering', () {
      final snapshot = makeSnapshot();
      // Completed status only exists in Engineering group
      const filter = ProjectsFilter(
        selectedStatusIds: {ProjectStatusFilterIds.completed},
      );
      final result = applyProjectsFilter(snapshot, filter);

      // Design group has no completed projects, so it is removed
      expect(result, hasLength(1));
      expect(result[0].categoryId, 'cat-eng');
      expect(result[0].projects, hasLength(1));
      expect(
        result[0].projects[0].project.data.title,
        'Legacy Cleanup',
      );
    });

    test('combined status, category, and text query filter', () {
      final snapshot = makeSnapshot();
      const filter = ProjectsFilter(
        selectedStatusIds: {
          ProjectStatusFilterIds.open,
          ProjectStatusFilterIds.active,
        },
        selectedCategoryIds: {'cat-eng'},
        textQuery: 'CI',
        searchMode: ProjectsSearchMode.localText,
      );
      final result = applyProjectsFilter(snapshot, filter);

      // Only Engineering group, only active CI Pipeline matches all criteria
      expect(result, hasLength(1));
      expect(result[0].categoryId, 'cat-eng');
      expect(result[0].projects, hasLength(1));
      expect(
        result[0].projects[0].project.data.title,
        'CI Pipeline',
      );
    });

    test(
      'text query is case-insensitive and trims whitespace',
      () {
        final snapshot = makeSnapshot();
        const filter = ProjectsFilter(
          textQuery: '  BRAND  ',
          searchMode: ProjectsSearchMode.localText,
        );
        final result = applyProjectsFilter(snapshot, filter);

        expect(result, hasLength(1));
        expect(result[0].categoryId, 'cat-design');
        expect(result[0].projects, hasLength(1));
        expect(
          result[0].projects[0].project.data.title,
          'Brand Refresh',
        );
      },
    );

    test('category filter excludes groups with null categoryId', () {
      final uncategorizedItem = makeItem(
        title: 'Uncategorized Work',
        status: openStatus,
      );
      final snapshot = ProjectsOverviewSnapshot(
        groups: [
          ProjectCategoryGroup(
            categoryId: null,
            category: null,
            projects: [uncategorizedItem],
          ),
          ProjectCategoryGroup(
            categoryId: 'cat-eng',
            category: catEngineering,
            projects: [
              makeItem(
                title: 'Backend API',
                status: openStatus,
                category: catEngineering,
                categoryId: 'cat-eng',
              ),
            ],
          ),
        ],
      );

      const filter = ProjectsFilter(
        selectedCategoryIds: {'cat-eng'},
      );
      final result = applyProjectsFilter(snapshot, filter);

      expect(result, hasLength(1));
      expect(result[0].categoryId, 'cat-eng');
    });

    test('multiple status filters match any of the selected statuses', () {
      final snapshot = makeSnapshot();
      const filter = ProjectsFilter(
        selectedStatusIds: {
          ProjectStatusFilterIds.active,
          ProjectStatusFilterIds.completed,
        },
      );
      final result = applyProjectsFilter(snapshot, filter);

      // Engineering: CI Pipeline (active) + Legacy Cleanup (completed)
      expect(result, hasLength(2));
      expect(result[0].projects, hasLength(2));
      expect(
        result[0].projects.map((p) => p.project.data.title).toList(),
        containsAll(['CI Pipeline', 'Legacy Cleanup']),
      );
      // Design: Icon System (active)
      expect(result[1].projects, hasLength(1));
      expect(
        result[1].projects[0].project.data.title,
        'Icon System',
      );
    });
  });

  // -------------------------------------------------------------------------
  // Glados property tests — additive HIGH/LOW/MED items from TEST_REVIEW.md
  // -------------------------------------------------------------------------

  group('ProjectsQuery.matchesCategory — properties', () {
    // LOW item: "if categoryIds is empty, always returns true"
    // Tested for both string and null inputs via worked examples.
    test('empty categoryIds matches any non-null string', () {
      const query = ProjectsQuery();
      for (final id in <String>['cat-a', 'cat-b', 'anything', '']) {
        expect(query.matchesCategory(id), isTrue, reason: 'id=$id');
      }
    });

    test('empty categoryIds matches null', () {
      const query = ProjectsQuery();
      expect(query.matchesCategory(null), isTrue);
    });

    glados.Glados<String>(
      glados.any.letterOrDigits,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'non-empty categoryIds only matches IDs it contains',
      (id) {
        final query = ProjectsQuery(categoryIds: <String>{id});
        expect(query.matchesCategory(id), isTrue);
        // A different string produced by appending a suffix must not match
        // unless it happens to equal id (which cannot happen given the suffix).
        expect(query.matchesCategory('${id}_other'), isFalse);
      },
      tags: 'glados',
    );

    glados.Glados<Set<String>>(
      glados.any.categoryIdSet,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'equality and hashCode follow set equality, not insertion order',
      (ids) {
        final query = ProjectsQuery(categoryIds: ids);
        // Same elements in reversed insertion order: still equal.
        final reordered = ProjectsQuery(
          categoryIds: Set<String>.from(ids.toList().reversed),
        );
        expect(reordered, query);
        expect(reordered.hashCode, query.hashCode);

        // Adding a guaranteed-absent element breaks equality.
        final widened = ProjectsQuery(
          categoryIds: {...ids, '_definitely_not_generated_'},
        );
        expect(widened == query, isFalse);
      },
      tags: 'glados',
    );
  });

  group('applyProjectsFilter — properties', () {
    // Fixed snapshot used across all property runs.
    final cat1 = CategoryTestUtils.createTestCategory(
      id: 'p-cat-1',
      name: 'Alpha',
      color: '#FF0000',
    );
    final cat2 = CategoryTestUtils.createTestCategory(
      id: 'p-cat-2',
      name: 'Beta',
      color: '#00FF00',
    );
    final openStatus = ProjectStatus.open(
      id: 'prop-open',
      createdAt: DateTime(2024, 3, 15),
      utcOffset: 0,
    );
    final snapshot = ProjectsOverviewSnapshot(
      groups: <ProjectCategoryGroup>[
        ProjectCategoryGroup(
          categoryId: 'p-cat-1',
          category: cat1,
          projects: <ProjectListItemData>[
            makeTestProjectListItemData(
              project: makeTestProject(
                categoryId: 'p-cat-1',
                status: openStatus,
              ),
              category: cat1,
            ),
          ],
        ),
        ProjectCategoryGroup(
          categoryId: 'p-cat-2',
          category: cat2,
          projects: <ProjectListItemData>[
            makeTestProjectListItemData(
              project: makeTestProject(
                categoryId: 'p-cat-2',
                status: openStatus,
              ),
              category: cat2,
            ),
          ],
        ),
      ],
    );

    // MED Glados item: result count never exceeds snapshot total.
    glados.Glados<ProjectsFilter>(
      glados.any.projectsFilter,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'filtered group count never exceeds the original group count',
      (filter) {
        final result = applyProjectsFilter(snapshot, filter);
        expect(
          result.length,
          lessThanOrEqualTo(snapshot.groups.length),
        );
      },
      tags: 'glados',
    );

    glados.Glados<ProjectsFilter>(
      glados.any.projectsFilter,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'no result group is empty after filtering',
      (filter) {
        final result = applyProjectsFilter(snapshot, filter);
        for (final group in result) {
          expect(group.projects, isNotEmpty);
        }
      },
      tags: 'glados',
    );

    glados.Glados<ProjectsFilter>(
      glados.any.projectsFilter,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'empty filter is equivalent to no filtering — returns all groups',
      (filter) {
        // An empty filter (no status IDs, no category IDs, empty text) must
        // return all groups from the snapshot.
        const emptyFilter = ProjectsFilter();
        final emptyResult = applyProjectsFilter(snapshot, emptyFilter);
        expect(emptyResult.length, snapshot.groups.length);
      },
      tags: 'glados',
    );

    glados.Glados<ProjectsFilter>(
      glados.any.projectsFilter,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'filtering is idempotent: re-applying the same filter is a no-op',
      (filter) {
        List<List<String>> shape(List<ProjectCategoryGroup> groups) => [
          for (final group in groups)
            [for (final p in group.projects) p.project.meta.id],
        ];

        final once = applyProjectsFilter(snapshot, filter);
        final twice = applyProjectsFilter(
          ProjectsOverviewSnapshot(groups: once),
          filter,
        );

        expect(shape(twice), shape(once));
      },
      tags: 'glados',
    );

    test('a filter selecting every status id equals the identity result', () {
      const allStatuses = ProjectsFilter(
        selectedStatusIds: {
          ProjectStatusFilterIds.open,
          ProjectStatusFilterIds.active,
          ProjectStatusFilterIds.onHold,
          ProjectStatusFilterIds.completed,
          ProjectStatusFilterIds.archived,
        },
      );

      final all = applyProjectsFilter(snapshot, allStatuses);
      final identity = applyProjectsFilter(snapshot, const ProjectsFilter());

      expect(all.length, identity.length);
      for (var i = 0; i < all.length; i++) {
        expect(
          all[i].projects.map((p) => p.project.meta.id),
          identity[i].projects.map((p) => p.project.meta.id),
        );
      }
    });
  });

  group('ProjectsFilter equality/hashCode — Glados properties', () {
    // Rebuild a value with the same field contents but sets reconstructed in
    // reversed insertion order, exercising the order-insensitive SetEquality.
    ProjectsFilter reordered(ProjectsFilter f) => ProjectsFilter(
      selectedStatusIds: Set<String>.from(
        f.selectedStatusIds.toList().reversed,
      ),
      selectedCategoryIds: Set<String>.from(
        f.selectedCategoryIds.toList().reversed,
      ),
      textQuery: f.textQuery,
      searchMode: f.searchMode,
    );

    glados.Glados<ProjectsFilter>(
      glados.any.projectsFilter,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'reflexive, and a field-reordered copy is symmetric & transitive',
      (filter) {
        // Reflexivity.
        expect(filter, filter);
        expect(filter.hashCode, filter.hashCode);

        // Two independently reordered copies are all mutually equal, so we can
        // exercise symmetry and transitivity on a genuinely-equal triple.
        final b = reordered(filter);
        final c = reordered(filter);

        // Symmetry.
        expect(filter == b, isTrue);
        expect(b == filter, isTrue);

        // Transitivity: a == b and b == c implies a == c.
        expect(b == c, isTrue);
        expect(filter == c, isTrue);

        // Equal values must share a hashCode.
        expect(b.hashCode, filter.hashCode);
        expect(c.hashCode, filter.hashCode);
      },
      tags: 'glados',
    );

    glados.Glados2<ProjectsFilter, ProjectsFilter>(
      glados.any.projectsFilter,
      glados.any.projectsFilter,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'equality is symmetric and consistent with hashCode for any two filters',
      (a, b) {
        // == is symmetric regardless of whether the two filters are equal.
        expect(a == b, b == a);
        // Whenever two filters compare equal they must hash the same.
        if (a == b) {
          expect(a.hashCode, b.hashCode);
        }
      },
      tags: 'glados',
    );
  });

  group('ProjectTaskRollupData.completionRatio — Glados properties', () {
    glados.Glados2<int, int>(
      glados.IntAnys(glados.any).intInRange(0, 1 << 20),
      glados.IntAnys(glados.any).intInRange(0, 1 << 20),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'ratio is completed/total bounded to [0, 1] when completed <= total; '
      'zero total always yields 0',
      (a, b) {
        final total = a >= b ? a : b;
        final completed = a >= b ? b : a;
        final rollup = ProjectTaskRollupData(
          totalTaskCount: total,
          completedTaskCount: completed,
        );

        if (total == 0) {
          expect(rollup.completionRatio, 0);
        } else {
          expect(rollup.completionRatio, completed / total);
          expect(rollup.completionRatio, greaterThanOrEqualTo(0.0));
          expect(rollup.completionRatio, lessThanOrEqualTo(1.0));
        }
        expect(
          rollup.completionPercent,
          (rollup.completionRatio * 100).round(),
        );
      },
      tags: 'glados',
    );
  });
}
