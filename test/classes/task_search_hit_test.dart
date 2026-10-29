import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task_search_hit.dart';

void main() {
  test('hits compare by value', () {
    const hit = TaskSearchHit(
      taskId: 't',
      snippet: 'krill',
      matchedType: 'Task',
    );

    expect(
      hit,
      const TaskSearchHit(taskId: 't', snippet: 'krill', matchedType: 'Task'),
    );
    expect(
      hit.hashCode,
      const TaskSearchHit(
        taskId: 't',
        snippet: 'krill',
        matchedType: 'Task',
      ).hashCode,
    );
    expect(
      hit,
      isNot(
        const TaskSearchHit(
          taskId: 't',
          snippet: 'krill',
          matchedType: 'ChecklistItem',
        ),
      ),
    );
  });
}
