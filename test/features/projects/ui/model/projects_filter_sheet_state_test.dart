import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/ui/model/projects_filter_sheet_state.dart';

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
          showDragHandle: false,
        );

        expect(state.title, 'Apply filter');
        expect(state.statusField, isNotNull);
        expect(state.categoryField, isNotNull);
        expect(state.labelField, isNull);
        expect(state.priorityOptions, isEmpty);
        expect(state.showDragHandle, isFalse);
        expect(
          state.statusField!.selectedIds,
          {ProjectStatusFilterIds.completed},
        );
        expect(state.categoryField!.selectedIds, {'study'});
        expect(
          state.categoryField!.options.map((option) => option.label).toList(),
          ['Work', 'Study'],
        );
      },
    );
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

  group('stripTrailingColon', () {
    test('removes a trailing colon and trims the remaining whitespace', () {
      expect(stripTrailingColon('Status :'), 'Status');
      expect(stripTrailingColon('Category:'), 'Category');
      expect(stripTrailingColon('Status'), 'Status');
    });
  });
}
