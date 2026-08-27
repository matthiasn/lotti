import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/logic/signals/signal_window.dart';

void main() {
  final start = DateTime.utc(2026, 8);
  final end = DateTime.utc(2026, 8, 14);

  test('windows with equal contents are equal and hash alike', () {
    final a = SignalWindow(
      start: start,
      end: end,
      measurableTotalsByDay: {
        'water': {end: 750},
      },
      habitSuccessDays: {
        'habit-a': {end},
      },
    );
    final b = SignalWindow(
      start: start,
      end: end,
      measurableTotalsByDay: {
        'water': {end: 750},
      },
      habitSuccessDays: {
        'habit-a': {end},
      },
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('a differing series or bound makes windows unequal', () {
    final base = SignalWindow(start: start, end: end);
    expect(SignalWindow(start: start, end: start), isNot(base));
    expect(
      SignalWindow(
        start: start,
        end: end,
        quantitativeByDay: {
          'cumulative_step_count': {end: 1},
        },
      ),
      isNot(base),
    );
  });
}
