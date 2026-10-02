import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/ui/model/projects_filter_sheet_state.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';

void main() {
  group('buildProjectsFilterSheetState', () {
    testWidgets(
      'builds a project-specific DS filter sheet with selected statuses and categories',
      (tester) async {
        late BuildContext context;
        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (buildContext) {
                context = buildContext;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final categories = <CategoryDefinition>[
          CategoryTestUtils.createTestCategory(id: 'work', name: 'Work'),
          CategoryTestUtils.createTestCategory(id: 'study', name: 'Study'),
        ];

        final state = buildProjectsFilterSheetState(
          context,
          filter: const ProjectsFilter(
            selectedStatusIds: {ProjectStatusFilterIds.completed},
            selectedCategoryIds: {'study'},
          ),
          categories: categories,
        );

        expect(state.title, 'Filter projects');
        expect(state.statusField, isNotNull);
        expect(state.categoryField, isNotNull);
        expect(state.labelField, isNull);
        expect(state.priorityOptions, isEmpty);
        expect(
          state.statusField!.selectedIds,
          {ProjectStatusFilterIds.completed},
        );
        expect(state.categoryField!.selectedIds, {'study'});
        expect(
          state.categoryField!.options.map((option) => option.label).toList(),
          ['Work', 'Study'],
        );
        // The status options expose every canonical status filter id in
        // display order, including the monitoring status.
        expect(
          state.statusField!.options.map((option) => option.id).toList(),
          [
            ProjectStatusFilterIds.open,
            ProjectStatusFilterIds.active,
            ProjectStatusFilterIds.monitoring,
            ProjectStatusFilterIds.onHold,
            ProjectStatusFilterIds.completed,
            ProjectStatusFilterIds.archived,
          ],
        );
        expect(
          state.statusField!.options.map((option) => option.label).toList(),
          ['Open', 'Active', 'Monitoring', 'On Hold', 'Completed', 'Archived'],
        );
      },
    );
  });

  group('buildProjectsFilterSheetState — toggles', () {
    for (final show in [false, true]) {
      testWidgets('offers both switches, seeded ${show ? 'on' : 'off'}', (
        tester,
      ) async {
        late BuildContext context;
        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (buildContext) {
                context = buildContext;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final state = buildProjectsFilterSheetState(
          context,
          filter: ProjectsFilter(
            showInferenceProfile: show,
            onlyOutOfDate: !show,
          ),
          categories: const [],
        );

        // The narrowing switch first, the display one after it.
        expect(
          state.toggles.map(
            (toggle) => (toggle.id, toggle.label, toggle.value),
          ),
          [
            (
              ProjectsFilterToggleIds.onlyOutOfDate,
              'Only out-of-date summaries',
              !show,
            ),
            (
              ProjectsFilterToggleIds.showInferenceProfile,
              'Show inference profile',
              show,
            ),
          ],
        );
      });
    }
  });

  group('projectsFilterFromSheetState — inference profile toggle', () {
    DesignSystemTaskFilterState sheetWith(
      List<DesignSystemTaskFilterToggle> toggles,
    ) => DesignSystemTaskFilterState(
      title: 'Apply filter',
      clearAllLabel: 'Clear all',
      applyLabel: 'Apply',
      toggles: toggles,
    );

    test('an enabled switch turns the pill on', () {
      final filter = projectsFilterFromSheetState(
        sheetWith(const [
          DesignSystemTaskFilterToggle(
            id: ProjectsFilterToggleIds.showInferenceProfile,
            label: 'Show inference profile',
            value: true,
          ),
        ]),
        baseFilter: const ProjectsFilter(),
      );

      expect(filter.showInferenceProfile, isTrue);
    });

    test('a disabled switch turns a previously shown pill off', () {
      final filter = projectsFilterFromSheetState(
        sheetWith(const [
          DesignSystemTaskFilterToggle(
            id: ProjectsFilterToggleIds.showInferenceProfile,
            label: 'Show inference profile',
            value: false,
          ),
        ]),
        baseFilter: const ProjectsFilter(showInferenceProfile: true),
      );

      expect(filter.showInferenceProfile, isFalse);
    });

    test('the out-of-date switch maps back on its own', () {
      final filter = projectsFilterFromSheetState(
        sheetWith(const [
          DesignSystemTaskFilterToggle(
            id: ProjectsFilterToggleIds.onlyOutOfDate,
            label: 'Only out-of-date summaries',
            value: true,
          ),
          DesignSystemTaskFilterToggle(
            id: ProjectsFilterToggleIds.showInferenceProfile,
            label: 'Show inference profile',
            value: false,
          ),
        ]),
        baseFilter: const ProjectsFilter(showInferenceProfile: true),
      );

      expect(filter.onlyOutOfDate, isTrue);
      expect(filter.showInferenceProfile, isFalse);
    });

    test('an unrelated enabled toggle does not turn the pill on', () {
      final filter = projectsFilterFromSheetState(
        sheetWith(const [
          DesignSystemTaskFilterToggle(
            id: 'some-other-toggle',
            label: 'Other',
            value: true,
          ),
        ]),
        baseFilter: const ProjectsFilter(onlyOutOfDate: true),
      );

      expect(filter.showInferenceProfile, isFalse);
      // An absent switch reads as off, like every other sheet field.
      expect(filter.onlyOutOfDate, isFalse);
    });
  });

  group('projectsFilterFromSheetState', () {
    test('maps DS status/category selections back into a ProjectsFilter', () {
      final sheetState = DesignSystemTaskFilterState(
        title: 'Apply filter',
        clearAllLabel: 'Clear all',
        applyLabel: 'Apply',
        statusField: const DesignSystemTaskFilterFieldState(
          label: 'Status',
          options: [
            DesignSystemTaskFilterOption(
              id: ProjectStatusFilterIds.active,
              label: 'Active',
            ),
            DesignSystemTaskFilterOption(
              id: ProjectStatusFilterIds.completed,
              label: 'Completed',
            ),
          ],
          selectedIds: {ProjectStatusFilterIds.active},
        ),
        categoryField: const DesignSystemTaskFilterFieldState(
          label: 'Category',
          options: [
            DesignSystemTaskFilterOption(id: 'work', label: 'Work'),
            DesignSystemTaskFilterOption(id: 'study', label: 'Study'),
          ],
          selectedIds: {'work'},
        ),
      );

      final filter = projectsFilterFromSheetState(
        sheetState,
        baseFilter: const ProjectsFilter(
          textQuery: 'sync',
          searchMode: ProjectsSearchMode.localText,
        ),
      );

      expect(filter.selectedStatusIds, {ProjectStatusFilterIds.active});
      expect(filter.selectedCategoryIds, {'work'});
      expect(filter.textQuery, 'sync');
      expect(filter.searchMode, ProjectsSearchMode.localText);
    });
  });

  group('projectsFilterFromSheetState — null fields', () {
    test('null status/category fields map to empty selections', () {
      final sheetState = DesignSystemTaskFilterState(
        title: 'Apply filter',
        clearAllLabel: 'Clear all',
        applyLabel: 'Apply',
      );

      final filter = projectsFilterFromSheetState(
        sheetState,
        baseFilter: const ProjectsFilter(
          textQuery: 'sync',
          searchMode: ProjectsSearchMode.localText,
          selectedStatusIds: {ProjectStatusFilterIds.open},
          selectedCategoryIds: {'work'},
        ),
      );

      // The `?? const {}` branches: previous selections are cleared,
      // text query and search mode survive.
      expect(filter.selectedStatusIds, isEmpty);
      expect(filter.selectedCategoryIds, isEmpty);
      expect(filter.textQuery, 'sync');
      expect(filter.searchMode, ProjectsSearchMode.localText);
    });
  });

  group('stripTrailingColon', () {
    test('removes a trailing colon and trims the remaining whitespace', () {
      expect(stripTrailingColon('Status :'), 'Status');
      expect(stripTrailingColon('Category:'), 'Category');
      expect(stripTrailingColon('Status'), 'Status');
    });
  });
}
