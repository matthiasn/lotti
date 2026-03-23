import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_state.dart';

import '../../test_utils.dart';

void main() {
  group('ProjectListDetailState', () {
    late ProjectListDetailState state;

    setUp(() {
      state = ProjectListDetailState(
        data: makeTestProjectListData(),
        searchQuery: '',
        selectedProjectId: 'p1',
      );
    });

    group('visibleProjects', () {
      test('returns all projects when search query is empty', () {
        expect(state.visibleProjects, hasLength(2));
      });

      test('filters by project title', () {
        final filtered = state.copyWith(searchQuery: 'Alpha').visibleProjects;

        expect(filtered, hasLength(1));
        expect(filtered.first.project.meta.id, 'p1');
      });

      test('filters by category name', () {
        final filtered = state.copyWith(searchQuery: 'Study').visibleProjects;

        expect(filtered, hasLength(1));
        expect(filtered.first.project.meta.id, 'p2');
      });

      test('is case-insensitive', () {
        final filtered = state.copyWith(searchQuery: 'alpha').visibleProjects;

        expect(filtered, hasLength(1));
        expect(filtered.first.project.meta.id, 'p1');
      });

      test('returns empty list when nothing matches', () {
        final filtered = state
            .copyWith(searchQuery: 'nonexistent')
            .visibleProjects;

        expect(filtered, isEmpty);
      });

      test('trims whitespace from query', () {
        final filtered = state
            .copyWith(searchQuery: '  Alpha  ')
            .visibleProjects;

        expect(filtered, hasLength(1));
      });
    });

    group('selectedProject', () {
      test('returns the project matching selectedProjectId', () {
        expect(state.selectedProject?.project.meta.id, 'p1');
      });

      test('falls back to first visible project when ID does not match', () {
        final updated = state.copyWith(selectedProjectId: 'nonexistent');

        expect(updated.selectedProject?.project.meta.id, 'p1');
      });

      test('returns null when no projects are visible', () {
        final updated = state.copyWith(searchQuery: 'nonexistent');

        expect(updated.selectedProject, isNull);
      });

      test('returns matching project even when not first in list', () {
        final updated = state.copyWith(selectedProjectId: 'p2');

        expect(updated.selectedProject?.project.meta.id, 'p2');
      });
    });

    group('visibleGroups', () {
      test('groups projects by category', () {
        final groups = state.visibleGroups;

        expect(groups, hasLength(2));
        expect(groups[0].label, 'Work');
        expect(groups[0].projects, hasLength(1));
        expect(groups[1].label, 'Study');
        expect(groups[1].projects, hasLength(1));
      });

      test('excludes categories with no visible projects', () {
        final filtered = state.copyWith(searchQuery: 'Alpha').visibleGroups;

        expect(filtered, hasLength(1));
        expect(filtered.first.label, 'Work');
      });

      test('returns empty when search matches nothing', () {
        final groups = state.copyWith(searchQuery: 'nonexistent').visibleGroups;

        expect(groups, isEmpty);
      });
    });

    group('copyWith', () {
      test('preserves unchanged fields', () {
        final copy = state.copyWith(searchQuery: 'test');

        expect(copy.searchQuery, 'test');
        expect(copy.selectedProjectId, state.selectedProjectId);
        expect(copy.data, state.data);
      });

      test('replaces all specified fields', () {
        final newData = makeTestProjectListData();
        final copy = state.copyWith(
          data: newData,
          searchQuery: 'new',
          selectedProjectId: 'p2',
        );

        expect(copy.data, newData);
        expect(copy.searchQuery, 'new');
        expect(copy.selectedProjectId, 'p2');
      });
    });
  });
}
