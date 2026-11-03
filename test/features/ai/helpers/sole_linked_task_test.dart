import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/helpers/sole_linked_task.dart';

import '../../../test_data/test_data.dart';

Task _task(String id) =>
    testTask.copyWith(meta: testTask.meta.copyWith(id: id));

void main() {
  group('soleLinkedTask', () {
    test('answers the only task among the linked entries', () {
      expect(
        soleLinkedTask([testTextEntry, _task('task-a'), testAudioEntry])?.id,
        'task-a',
      );
    });

    test('answers the task once when both link directions name it', () {
      // The entry links to its task and the task links back: one task.
      expect(soleLinkedTask([_task('task-a'), _task('task-a')])?.id, 'task-a');
    });

    test('answers nothing for an entry in a task and its follow-up', () {
      // Picking either would write the run's result into a task nobody
      // chose for it.
      expect(soleLinkedTask([_task('task-a'), _task('task-b')]), isNull);
    });

    test('answers nothing when no task is linked', () {
      expect(soleLinkedTask([testTextEntry, testAudioEntry]), isNull);
      expect(soleLinkedTask(const []), isNull);
    });
  });
}
