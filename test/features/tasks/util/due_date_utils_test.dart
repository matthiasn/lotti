import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'package:lotti/themes/colors.dart';

class _GeneratedDueDateScenario {
  const _GeneratedDueDateScenario({
    required this.referenceYear,
    required this.referenceMonth,
    required this.referenceDaySeed,
    required this.referenceMinuteOfDay,
    required this.dayOffset,
    required this.dueMinuteOfDay,
  });

  final int referenceYear;
  final int referenceMonth;
  final int referenceDaySeed;
  final int referenceMinuteOfDay;
  final int dayOffset;
  final int dueMinuteOfDay;

  int get referenceDay =>
      (referenceDaySeed % DateTime(referenceYear, referenceMonth + 1, 0).day) +
      1;

  DateTime get referenceDate => DateTime(
    referenceYear,
    referenceMonth,
    referenceDay,
    referenceMinuteOfDay ~/ 60,
    referenceMinuteOfDay % 60,
  );

  DateTime get dueDate {
    final dueMidnight = DateTime(
      referenceYear,
      referenceMonth,
      referenceDay + dayOffset,
    );
    return DateTime(
      dueMidnight.year,
      dueMidnight.month,
      dueMidnight.day,
      dueMinuteOfDay ~/ 60,
      dueMinuteOfDay % 60,
    );
  }

  DueDateUrgency get expectedUrgency {
    if (dayOffset < 0) return DueDateUrgency.overdue;
    if (dayOffset == 0) return DueDateUrgency.dueToday;
    return DueDateUrgency.normal;
  }

  bool get expectedUrgent => dayOffset <= 0;

  @override
  String toString() {
    return '_GeneratedDueDateScenario('
        'referenceDate: $referenceDate, '
        'dueDate: $dueDate, '
        'dayOffset: $dayOffset)';
  }
}

extension _AnyDueDateScenario on glados.Any {
  glados.Generator<_GeneratedDueDateScenario> get dueDateScenario =>
      glados.CombinableAny(this).combine6(
        glados.IntAnys(this).intInRange(2000, 2031),
        glados.IntAnys(this).intInRange(1, 13),
        glados.IntAnys(this).intInRange(0, 400),
        glados.IntAnys(this).intInRange(0, 24 * 60),
        glados.IntAnys(this).intInRange(-400, 401),
        glados.IntAnys(this).intInRange(0, 24 * 60),
        (
          int referenceYear,
          int referenceMonth,
          int referenceDaySeed,
          int referenceMinuteOfDay,
          int dayOffset,
          int dueMinuteOfDay,
        ) => _GeneratedDueDateScenario(
          referenceYear: referenceYear,
          referenceMonth: referenceMonth,
          referenceDaySeed: referenceDaySeed,
          referenceMinuteOfDay: referenceMinuteOfDay,
          dayOffset: dayOffset,
          dueMinuteOfDay: dueMinuteOfDay,
        ),
      );
}

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

    glados.Glados(
      glados.any.dueDateScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'classifies generated date offsets and ignores time of day',
      (scenario) {
        final status = getDueDateStatus(
          dueDate: scenario.dueDate,
          referenceDate: scenario.referenceDate,
        );

        expect(status.urgency, scenario.expectedUrgency, reason: '$scenario');
        expect(status.daysUntilDue, scenario.dayOffset, reason: '$scenario');
        expect(status.isUrgent, scenario.expectedUrgent, reason: '$scenario');
      },
      tags: 'glados',
    );
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
