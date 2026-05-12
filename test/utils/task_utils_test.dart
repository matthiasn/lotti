import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';

void main() {
  group('Task utils test', () {
    final testDate = DateTime(2024, 3, 15);

    test('Expected color is returned', () {
      expect(
        TaskStatus.open(
          id: 'id',
          createdAt: testDate,
          utcOffset: 120,
        ).colorForBrightness(Brightness.dark),
        Colors.orange,
      );
      expect(
        TaskStatus.groomed(
          id: 'id',
          createdAt: testDate,
          utcOffset: 120,
        ).colorForBrightness(Brightness.dark),
        Colors.lightGreenAccent,
      );
      expect(
        TaskStatus.inProgress(
          id: 'id',
          createdAt: testDate,
          utcOffset: 120,
        ).colorForBrightness(Brightness.dark),
        Colors.blue,
      );
      expect(
        TaskStatus.inProgress(
          id: 'id',
          createdAt: testDate,
          utcOffset: 120,
        ).colorForBrightness(Brightness.dark),
        Colors.blue,
      );
      expect(
        TaskStatus.blocked(
          id: 'id',
          createdAt: testDate,
          utcOffset: 120,
          reason: '',
        ).colorForBrightness(Brightness.dark),
        Colors.red,
      );
      expect(
        TaskStatus.onHold(
          id: 'id',
          createdAt: testDate,
          utcOffset: 120,
          reason: '',
        ).colorForBrightness(Brightness.dark),
        Colors.red,
      );
      expect(
        TaskStatus.done(
          id: 'id',
          createdAt: testDate,
          utcOffset: 120,
        ).colorForBrightness(Brightness.dark),
        Colors.green,
      );
      expect(
        TaskStatus.rejected(
          id: 'id',
          createdAt: testDate,
          utcOffset: 120,
        ).colorForBrightness(Brightness.dark),
        Colors.red,
      );
    });
  });
}
