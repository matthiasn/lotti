import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/ui/goal_habit_reflections.dart';

void main() {
  test('reflectionSpanDays covers the day and never drops below a week', () {
    final today = DateTime(2026, 8, 8, 14);
    expect(reflectionSpanDays(from: today, today: today), 7);
    expect(
      reflectionSpanDays(from: DateTime(2026, 8, 6, 23), today: today),
      7,
    );
    expect(reflectionSpanDays(from: DateTime(2026, 8), today: today), 8);
    expect(reflectionSpanDays(from: DateTime(2026, 7, 20), today: today), 20);
  });
}
