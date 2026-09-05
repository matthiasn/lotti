import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/projects/ui/model/project_task_list_options.dart';

void main() {
  test(
    'defaults group by creation month, sort by actionability, fold done',
    () {
      const options = ProjectTaskListOptions.defaults;
      expect(options.groupBy, ProjectTaskGroupBy.creationMonth);
      expect(options.sortBy, ProjectTaskSortBy.actionability);
      expect(options.keepDoneInGroups, isFalse);
      expect(options.collapsedGroups, {'done'});
      expect(options.isCollapsed('done'), isTrue);
      expect(options.isCollapsed('2026-09'), isFalse);
    },
  );

  test(
    'toggleCollapsed folds and unfolds one group without touching others',
    () {
      const options = ProjectTaskListOptions.defaults;

      final folded = options.toggleCollapsed('2026-09');
      expect(folded.collapsedGroups, {'done', '2026-09'});
      expect(folded.isCollapsed('2026-09'), isTrue);
      expect(options.collapsedGroups, {'done'}, reason: 'immutable');

      final unfolded = folded.toggleCollapsed('done');
      expect(unfolded.collapsedGroups, {'2026-09'});
      expect(unfolded.toggleCollapsed('2026-09').collapsedGroups, isEmpty);
    },
  );

  test('round-trips through JSON and compares by value', () {
    const options = ProjectTaskListOptions(
      groupBy: ProjectTaskGroupBy.dueWindow,
      sortBy: ProjectTaskSortBy.title,
      keepDoneInGroups: true,
      collapsedGroups: {'later', 'none'},
    );

    final json = options.toJson();
    expect(json['collapsedGroups'], ['later', 'none'], reason: 'sorted');
    final restored = ProjectTaskListOptions.fromJson(json);

    expect(restored, options);
    expect(restored.hashCode, options.hashCode);
    expect(restored, isNot(options.copyWith(keepDoneInGroups: false)));
    expect(restored, isNot(options.copyWith(collapsedGroups: const {'later'})));
    expect(
      restored,
      const ProjectTaskListOptions(
        groupBy: ProjectTaskGroupBy.dueWindow,
        sortBy: ProjectTaskSortBy.title,
        keepDoneInGroups: true,
        collapsedGroups: {'none', 'later'},
      ),
      reason: 'set order does not matter',
    );
    expect(
      options.copyWith(groupBy: ProjectTaskGroupBy.none).groupBy,
      ProjectTaskGroupBy.none,
    );
  });

  test('unknown or missing values fall back field by field', () {
    final restored = ProjectTaskListOptions.fromJson(const {
      'groupBy': 'byMoonPhase',
      'sortBy': 'priority',
      'keepDoneInGroups': 'yes',
    });

    expect(restored.groupBy, ProjectTaskGroupBy.creationMonth);
    expect(restored.sortBy, ProjectTaskSortBy.priority);
    expect(restored.keepDoneInGroups, isFalse);
    expect(
      ProjectTaskListOptions.fromJson(const <String, dynamic>{}),
      ProjectTaskListOptions.defaults,
    );
    expect(
      ProjectTaskListOptions.fromJson(const {
        'collapsedGroups': 'done',
      }).collapsedGroups,
      {'done'},
      reason: 'a non-list falls back to the default fold',
    );
    expect(
      ProjectTaskListOptions.fromJson(const {
        'collapsedGroups': ['2026-08', 7, null],
      }).collapsedGroups,
      {'2026-08'},
      reason: 'non-string entries are dropped, and an explicit list wins',
    );
  });

  test('describes itself for logs', () {
    expect(
      ProjectTaskListOptions.defaults.toString(),
      'ProjectTaskListOptions(creationMonth, actionability, '
      'keepDoneInGroups: false, collapsed: [done])',
    );
  });
}
