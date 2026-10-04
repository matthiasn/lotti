import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/task_colors.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('TaskPriority.colorForBrightness', () {
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

  group('TaskStatus.colorForBrightness', () {
    final testDate = DateTime(2024);

    group('Light mode colors', () {
      final testCases = <(String, TaskStatus, Color)>[
        (
          'Open',
          TaskStatus.open(id: 'test', createdAt: testDate, utcOffset: 0),
          taskStatusDarkOrange,
        ),
        (
          'Groomed',
          TaskStatus.groomed(id: 'test', createdAt: testDate, utcOffset: 0),
          taskStatusDarkGreen,
        ),
        (
          'In Progress',
          TaskStatus.inProgress(id: 'test', createdAt: testDate, utcOffset: 0),
          taskStatusDarkBlue,
        ),
        (
          'Blocked',
          TaskStatus.blocked(
            id: 'test',
            createdAt: testDate,
            utcOffset: 0,
            reason: 'test reason',
          ),
          taskStatusDarkRed,
        ),
        (
          'On Hold',
          TaskStatus.onHold(
            id: 'test',
            createdAt: testDate,
            utcOffset: 0,
            reason: 'test reason',
          ),
          taskStatusDarkRed,
        ),
        (
          'Done',
          TaskStatus.done(id: 'test', createdAt: testDate, utcOffset: 0),
          taskStatusDarkGreen,
        ),
        (
          'Rejected',
          TaskStatus.rejected(id: 'test', createdAt: testDate, utcOffset: 0),
          taskStatusDarkRed,
        ),
      ];

      for (final (name, status, expectedColor) in testCases) {
        test('$name status returns correct color in light mode', () {
          expect(
            status.colorForBrightness(Brightness.light),
            equals(expectedColor),
          );
        });
      }
    });

    group('Dark mode colors', () {
      final testCases = <(String, TaskStatus, Color)>[
        (
          'Open',
          TaskStatus.open(id: 'test', createdAt: testDate, utcOffset: 0),
          taskStatusOrange,
        ),
        (
          'Groomed',
          TaskStatus.groomed(id: 'test', createdAt: testDate, utcOffset: 0),
          taskStatusLightGreenAccent,
        ),
        (
          'In Progress',
          TaskStatus.inProgress(id: 'test', createdAt: testDate, utcOffset: 0),
          taskStatusBlue,
        ),
        (
          'Blocked',
          TaskStatus.blocked(
            id: 'test',
            createdAt: testDate,
            utcOffset: 0,
            reason: 'test reason',
          ),
          taskStatusRed,
        ),
        (
          'On Hold',
          TaskStatus.onHold(
            id: 'test',
            createdAt: testDate,
            utcOffset: 0,
            reason: 'test reason',
          ),
          taskStatusRed,
        ),
        (
          'Done',
          TaskStatus.done(id: 'test', createdAt: testDate, utcOffset: 0),
          taskStatusGreen,
        ),
        (
          'Rejected',
          TaskStatus.rejected(id: 'test', createdAt: testDate, utcOffset: 0),
          taskStatusRed,
        ),
      ];

      for (final (name, status, expectedColor) in testCases) {
        test('$name status returns correct color in dark mode', () {
          expect(
            status.colorForBrightness(Brightness.dark),
            equals(expectedColor),
          );
        });
      }
    });
  });
}
