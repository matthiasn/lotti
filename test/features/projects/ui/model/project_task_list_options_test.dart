import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/projects/ui/model/project_task_list_options.dart';

void main() {
  test(
    'defaults group by creation month, sort by actionability, fold done',
    () {
      const options = ProjectTaskListOptions.defaults;
      expect(options.groupBy, ProjectTaskGroupBy.creationMonth);
      expect(options.sortBy, ProjectTaskSortBy.actionability);
      expect(options.showDone, isFalse);
    },
  );

  test('round-trips through JSON and compares by value', () {
    const options = ProjectTaskListOptions(
      groupBy: ProjectTaskGroupBy.dueWindow,
      sortBy: ProjectTaskSortBy.title,
      showDone: true,
    );

    final restored = ProjectTaskListOptions.fromJson(options.toJson());

    expect(restored, options);
    expect(restored.hashCode, options.hashCode);
    expect(restored, isNot(options.copyWith(showDone: false)));
    expect(
      options.copyWith(groupBy: ProjectTaskGroupBy.none).groupBy,
      ProjectTaskGroupBy.none,
    );
  });

  test('unknown or missing values fall back field by field', () {
    final restored = ProjectTaskListOptions.fromJson(const {
      'groupBy': 'byMoonPhase',
      'sortBy': 'priority',
      'showDone': 'yes',
    });

    expect(restored.groupBy, ProjectTaskGroupBy.creationMonth);
    expect(restored.sortBy, ProjectTaskSortBy.priority);
    expect(restored.showDone, isFalse);
    expect(
      ProjectTaskListOptions.fromJson(const <String, dynamic>{}),
      ProjectTaskListOptions.defaults,
    );
  });

  test('describes itself for logs', () {
    expect(
      ProjectTaskListOptions.defaults.toString(),
      'ProjectTaskListOptions(creationMonth, actionability, showDone: false)',
    );
  });
}
