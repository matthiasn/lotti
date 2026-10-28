import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_page_state.dart';
import 'package:lotti/features/tasks/state/task_due_view_counts.dart';

void main() {
  const counts = TaskDueViewCounts(overdue: 3, dueToday: 2);

  test('reads each view by its clause', () {
    expect(counts.of(TaskDueFilter.overdue), 3);
    expect(counts.of(TaskDueFilter.dueToday), 2);
  });

  test('zero is zero in both views', () {
    expect(
      (TaskDueViewCounts.zero.overdue, TaskDueViewCounts.zero.dueToday),
      (0, 0),
    );
  });

  test('all is not a view', () {
    expect(() => counts.of(TaskDueFilter.all), throwsArgumentError);
  });
}
