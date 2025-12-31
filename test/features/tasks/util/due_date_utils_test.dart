import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'package:lotti/themes/colors.dart';

void main() {
  group('getDueDateStatus', () {
    final referenceDate = DateTime(2025, 6, 15);

    test('returns none status when dueDate is null', () {
      final status = getDueDateStatus(
        dueDate: null,
        referenceDate: referenceDate,
      );

      expect(status.urgency, DueDateUrgency.normal);
      expect(status.daysUntilDue, isNull);
      expect(status.isUrgent, isFalse);
      expect(status.urgentColor, isNull);
    });

    test('returns overdue status when dueDate is before reference', () {
      final dueDate = DateTime(2025, 6, 13); // 2 days before

      final status = getDueDateStatus(
        dueDate: dueDate,
        referenceDate: referenceDate,
      );

      expect(status.urgency, DueDateUrgency.overdue);
      expect(status.daysUntilDue, -2);
      expect(status.isUrgent, isTrue);
      expect(status.urgentColor, taskStatusRed);
    });

    test('returns dueToday status when dueDate equals reference', () {
      final dueDate = DateTime(2025, 6, 15); // Same day

      final status = getDueDateStatus(
        dueDate: dueDate,
        referenceDate: referenceDate,
      );

      expect(status.urgency, DueDateUrgency.dueToday);
      expect(status.daysUntilDue, 0);
      expect(status.isUrgent, isTrue);
      expect(status.urgentColor, taskStatusOrange);
    });

    test('returns normal status when dueDate is after reference', () {
      final dueDate = DateTime(2025, 6, 20); // 5 days after

      final status = getDueDateStatus(
        dueDate: dueDate,
        referenceDate: referenceDate,
      );

      expect(status.urgency, DueDateUrgency.normal);
      expect(status.daysUntilDue, 5);
      expect(status.isUrgent, isFalse);
      expect(status.urgentColor, isNull);
    });

    test('ignores time component - only compares dates', () {
      // Due at 23:59 on June 15
      final dueDate = DateTime(2025, 6, 15, 23, 59);
      // Reference at 00:01 on June 15
      final reference = DateTime(2025, 6, 15, 0, 1);

      final status = getDueDateStatus(
        dueDate: dueDate,
        referenceDate: reference,
      );

      expect(status.urgency, DueDateUrgency.dueToday);
      expect(status.daysUntilDue, 0);
    });

    test('returns overdue for yesterday', () {
      final dueDate = DateTime(2025, 6, 14);

      final status = getDueDateStatus(
        dueDate: dueDate,
        referenceDate: referenceDate,
      );

      expect(status.urgency, DueDateUrgency.overdue);
      expect(status.daysUntilDue, -1);
    });

    test('returns normal for tomorrow', () {
      final dueDate = DateTime(2025, 6, 16);

      final status = getDueDateStatus(
        dueDate: dueDate,
        referenceDate: referenceDate,
      );

      expect(status.urgency, DueDateUrgency.normal);
      expect(status.daysUntilDue, 1);
    });
  });

  group('DueDateStatus', () {
    test('isUrgent is true for overdue', () {
      const status = DueDateStatus(
        urgency: DueDateUrgency.overdue,
        daysUntilDue: -5,
      );

      expect(status.isUrgent, isTrue);
    });

    test('isUrgent is true for dueToday', () {
      const status = DueDateStatus(
        urgency: DueDateUrgency.dueToday,
        daysUntilDue: 0,
      );

      expect(status.isUrgent, isTrue);
    });

    test('isUrgent is false for normal', () {
      const status = DueDateStatus(
        urgency: DueDateUrgency.normal,
        daysUntilDue: 5,
      );

      expect(status.isUrgent, isFalse);
    });

    test('urgentColor returns red for overdue', () {
      const status = DueDateStatus(
        urgency: DueDateUrgency.overdue,
        daysUntilDue: -1,
      );

      expect(status.urgentColor, taskStatusRed);
    });

    test('urgentColor returns orange for dueToday', () {
      const status = DueDateStatus(
        urgency: DueDateUrgency.dueToday,
        daysUntilDue: 0,
      );

      expect(status.urgentColor, taskStatusOrange);
    });

    test('urgentColor returns null for normal', () {
      const status = DueDateStatus(
        urgency: DueDateUrgency.normal,
        daysUntilDue: 10,
      );

      expect(status.urgentColor, isNull);
    });

    test('none factory creates non-urgent status with null daysUntilDue', () {
      const status = DueDateStatus.none();

      expect(status.urgency, DueDateUrgency.normal);
      expect(status.daysUntilDue, isNull);
      expect(status.isUrgent, isFalse);
      expect(status.urgentColor, isNull);
    });
  });
}
