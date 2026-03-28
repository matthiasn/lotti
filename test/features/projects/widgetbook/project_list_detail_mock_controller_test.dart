import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/widgetbook/project_list_detail_mock_controller.dart';

void main() {
  group('ProjectListDetailShowcaseController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('loads grouped mock data with Device Sync selected by default', () {
      final state = container.read(projectListDetailShowcaseControllerProvider);

      expect(state.selectedProject?.project.data.title, 'Device Sync');
      expect(
        state.visibleGroups.map((group) => group.category?.name).toList(),
        ['Work', 'Meals', 'Study'],
      );
      expect(state.filter.searchMode, ProjectsSearchMode.localText);
    });

    test('updates selection when the search excludes the current project', () {
      container
          .read(
            projectListDetailShowcaseControllerProvider.notifier,
          )
          .updateSearchQuery('meal');

      final state = container.read(projectListDetailShowcaseControllerProvider);

      expect(state.visibleGroups, hasLength(1));
      expect(state.visibleGroups.single.category?.name, 'Meals');
      expect(state.selectedProject?.project.data.title, 'Weekly Meal Prep');
    });

    test('keeps the selected project when it still matches the search', () {
      container
          .read(
            projectListDetailShowcaseControllerProvider.notifier,
          )
          .updateSearchQuery('device');

      final state = container.read(projectListDetailShowcaseControllerProvider);

      expect(state.selectedProject?.project.data.title, 'Device Sync');
      expect(
        state.visibleGroups.single.projects.single.project.data.title,
        'Device Sync',
      );
    });

    test('updates visible groups when applying a status filter', () {
      container
          .read(
            projectListDetailShowcaseControllerProvider.notifier,
          )
          .updateFilter(
            const ProjectsFilter(
              searchMode: ProjectsSearchMode.localText,
              selectedStatusIds: {ProjectStatusFilterIds.completed},
            ),
          );

      final state = container.read(projectListDetailShowcaseControllerProvider);

      expect(
        state.visibleGroups
            .expand((group) => group.projects)
            .map(
              (project) => project.project.data.title,
            ),
        ['CI/CD Pipeline', 'Design System Book'],
      );
      expect(state.selectedProject?.project.data.title, 'CI/CD Pipeline');
    });
  });
}
