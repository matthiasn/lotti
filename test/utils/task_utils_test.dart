import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/utils/task_utils.dart';

void main() {
  group('Task utils test', () {
    test('Expected color is returned', () {
      expect(
        taskColor(
          TaskStatus.open(
            id: 'id',
            createdAt: DateTime.now(),
            utcOffset: 120,
          ),
        ),
        Colors.orange,
      );
      expect(
        taskColor(
          TaskStatus.groomed(
            id: 'id',
            createdAt: DateTime.now(),
            utcOffset: 120,
          ),
        ),
        Colors.lightGreenAccent,
      );
      expect(
        taskColor(
          TaskStatus.started(
            id: 'id',
            createdAt: DateTime.now(),
            utcOffset: 120,
          ),
        ),
        Colors.blue,
      );
      expect(
        taskColor(
          TaskStatus.inProgress(
            id: 'id',
            createdAt: DateTime.now(),
            utcOffset: 120,
          ),
        ),
        Colors.blue,
      );
      expect(
        taskColor(
          TaskStatus.blocked(
            id: 'id',
            createdAt: DateTime.now(),
            utcOffset: 120,
            reason: '',
          ),
        ),
        Colors.red,
      );
      expect(
        taskColor(
          TaskStatus.onHold(
            id: 'id',
            createdAt: DateTime.now(),
            utcOffset: 120,
            reason: '',
          ),
        ),
        Colors.red,
      );
      expect(
        taskColor(
          TaskStatus.done(
            id: 'id',
            createdAt: DateTime.now(),
            utcOffset: 120,
          ),
        ),
        Colors.green,
      );
      expect(
        taskColor(
          TaskStatus.rejected(
            id: 'id',
            createdAt: DateTime.now(),
            utcOffset: 120,
          ),
        ),
        Colors.red,
      );
    });
  });
}
