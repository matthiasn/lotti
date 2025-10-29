import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/themes/colors.dart';

void main() {
  group('TaskPriority parsing', () {
    test('parses P0..P3 correctly', () {
      expect(taskPriorityFromString('P0'), TaskPriority.p0Urgent);
      expect(taskPriorityFromString('P1'), TaskPriority.p1High);
      expect(taskPriorityFromString('P2'), TaskPriority.p2Medium);
      expect(taskPriorityFromString('P3'), TaskPriority.p3Low);
    });

    test('falls back to P2 for unknown', () {
      expect(taskPriorityFromString('Px'), TaskPriority.p2Medium);
    });
  });

  group('TaskPriority ext helpers', () {
    test('rank and short mapping', () {
      expect(TaskPriority.p0Urgent.rank, 0);
      expect(TaskPriority.p0Urgent.short, 'P0');
      expect(TaskPriority.p3Low.rank, 3);
      expect(TaskPriority.p3Low.short, 'P3');
    });

    test('labels', () {
      expect(TaskPriority.p0Urgent.label, 'Urgent');
      expect(TaskPriority.p1High.label, 'High');
      expect(TaskPriority.p2Medium.label, 'Medium');
      expect(TaskPriority.p3Low.label, 'Low');
    });

    test('color mapping (light mode)', () {
      expect(
        TaskPriority.p0Urgent.colorForBrightness(Brightness.light),
        taskStatusDarkRed,
      );
      expect(
        TaskPriority.p1High.colorForBrightness(Brightness.light),
        taskStatusDarkOrange,
      );
      expect(
        TaskPriority.p2Medium.colorForBrightness(Brightness.light),
        taskStatusDarkBlue,
      );
      expect(
        TaskPriority.p3Low.colorForBrightness(Brightness.light),
        Colors.grey,
      );
    });

    test('color mapping (dark mode)', () {
      expect(
        TaskPriority.p0Urgent.colorForBrightness(Brightness.dark),
        taskStatusRed,
      );
      expect(
        TaskPriority.p1High.colorForBrightness(Brightness.dark),
        taskStatusOrange,
      );
      expect(
        TaskPriority.p2Medium.colorForBrightness(Brightness.dark),
        taskStatusBlue,
      );
      expect(
        TaskPriority.p3Low.colorForBrightness(Brightness.dark),
        Colors.grey,
      );
    });
  });
}
