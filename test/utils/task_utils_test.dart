import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';

void main() {
  group('Task utils test', () {
    test('Expected color is returned', () {
      expect(
        TaskStatus.open(
          id: 'id',
          createdAt: DateTime.now(),
          utcOffset: 120,
        ).color,
        Colors.orange,
      );
      expect(
        TaskStatus.groomed(
          id: 'id',
          createdAt: DateTime.now(),
          utcOffset: 120,
        ).color,
        Colors.lightGreenAccent,
      );
      expect(
        TaskStatus.started(
          id: 'id',
          createdAt: DateTime.now(),
          utcOffset: 120,
        ).color,
        Colors.blue,
      );
      expect(
        TaskStatus.inProgress(
          id: 'id',
          createdAt: DateTime.now(),
          utcOffset: 120,
        ).color,
        Colors.blue,
      );
      expect(
        TaskStatus.blocked(
          id: 'id',
          createdAt: DateTime.now(),
          utcOffset: 120,
          reason: '',
        ).color,
        Colors.red,
      );
      expect(
        TaskStatus.onHold(
          id: 'id',
          createdAt: DateTime.now(),
          utcOffset: 120,
          reason: '',
        ).color,
        Colors.red,
      );
      expect(
        TaskStatus.done(
          id: 'id',
          createdAt: DateTime.now(),
          utcOffset: 120,
        ).color,
        Colors.green,
      );
      expect(
        TaskStatus.rejected(
          id: 'id',
          createdAt: DateTime.now(),
          utcOffset: 120,
        ).color,
        Colors.red,
      );
    });
  });
}
