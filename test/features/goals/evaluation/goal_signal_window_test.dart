import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';

void main() {
  DateTime d(int day) => DateTime.utc(2026, 8, day);

  final window = GoalSignalWindow(
    quantitativeDailySums: {
      'cumulative_step_count': {d(1): 9000, d(3): 7000, d(5): 11000},
    },
    habitSuccessesByDay: {
      'gym-habit': {d(3): 1, d(5): 2},
    },
    measurableDailySums: {
      'water-id': {d(2): 1500},
    },
    categoryTimeDailyHours: {
      'late-coding': {d(2): 0.5, d(4): 1.25},
    },
    categoryTimeSessionsByCategory: {
      'coding': [
        GoalCategoryTimeSession(
          categoryId: 'coding',
          dateFrom: DateTime(2026, 8, 2, 21, 45),
          dateTo: DateTime(2026, 8, 2, 23, 15),
        ),
      ],
    },
    categoryTimeEvidenceStart: DateTime(2026, 8),
    categoryTimeEvidenceEnd: DateTime(2026, 8, 6),
    hasActiveCategoryTimer: true,
  );

  test('range queries are inclusive of both endpoints', () {
    expect(
      window.quantitativeInRange('cumulative_step_count', d(1), d(5)),
      {d(1): 9000, d(3): 7000, d(5): 11000},
    );
    expect(
      window.quantitativeInRange('cumulative_step_count', d(2), d(4)),
      {d(3): 7000},
    );
  });

  test('absent days stay absent — no zero filling', () {
    final inRange = window.quantitativeInRange(
      'cumulative_step_count',
      d(1),
      d(5),
    );
    expect(inRange.containsKey(d(2)), isFalse);
    expect(inRange.length, 3);
  });

  test('unknown series ids yield empty maps', () {
    expect(window.quantitativeInRange('unknown', d(1), d(31)), isEmpty);
    expect(window.habitSuccessesInRange('unknown', d(1), d(31)), isEmpty);
    expect(window.measurableInRange('unknown', d(1), d(31)), isEmpty);
  });

  test('habit and measurable series filter by range too', () {
    expect(window.habitSuccessesInRange('gym-habit', d(4), d(6)), {d(5): 2});
    expect(window.measurableInRange('water-id', d(2), d(2)), {d(2): 1500});
    expect(window.measurableInRange('water-id', d(3), d(9)), isEmpty);
  });

  test('category-time dimensions are criterion-scoped and range-filtered', () {
    expect(window.categoryTimeInRange('late-coding', d(2), d(3)), {
      d(2): 0.5,
    });
    expect(window.categoryTimeInRange('unknown', d(1), d(31)), isEmpty);
  });

  test('category session evidence retains exact timing and query bounds', () {
    final session = window.categoryTimeSessionsByCategory['coding']!.single;

    expect(session.categoryId, 'coding');
    expect(session.duration, const Duration(minutes: 90));
    expect(window.categoryTimeEvidenceStart, DateTime(2026, 8));
    expect(window.categoryTimeEvidenceEnd, DateTime(2026, 8, 6));
    expect(window.hasActiveCategoryTimer, isTrue);
  });
}
