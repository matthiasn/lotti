import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/ui/goal_day_marks.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';

void main() {
  final today = DateTime.utc(2026, 8, 11);

  test('dates count back from the last day, which is today', () {
    final marks = goalDayMarks(
      states: const [
        DayMarkState.none,
        DayMarkState.partial,
        DayMarkState.full,
      ],
      lastDay: today,
    );
    expect(marks.map((m) => m.day), [
      DateTime.utc(2026, 8, 9),
      DateTime.utc(2026, 8, 10),
      today,
    ]);
    expect(marks.map((m) => m.state), [
      DayMarkState.none,
      DayMarkState.partial,
      DayMarkState.full,
    ]);
    expect(marks.map((m) => m.isToday), [false, false, true]);
  });

  test('verdicts line up by UTC day even when the last day is local', () {
    final localLastDay = DateTime(2026, 8, 11, 23, 30);
    final marks = goalDayMarks(
      states: List.filled(3, DayMarkState.none),
      lastDay: localLastDay,
      verdictsByDay: {
        DateTime.utc(2026, 8, 10): DayVerdict.missed,
        today: DayVerdict.met,
      },
    );
    expect(marks.map((m) => m.verdict), [
      null,
      DayVerdict.missed,
      DayVerdict.met,
    ]);
    expect(marks.map((m) => m.successful), [false, false, true]);
  });

  test('without a last day the marks are undated and carry no verdicts', () {
    final marks = goalDayMarks(
      states: const [DayMarkState.full, DayMarkState.none],
      verdictsByDay: {today: DayVerdict.missed},
    );
    expect(marks.every((m) => m.day == null), isTrue);
    expect(marks.every((m) => m.verdict == null), isTrue);
    expect(marks.last.isToday, isTrue);
  });

  test('an empty window yields no marks', () {
    expect(goalDayMarks(states: const [], lastDay: today), isEmpty);
  });
}
