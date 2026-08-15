import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/logic/goal_aggregate_rounding.dart';

void main() {
  test('quantizes by magnitude: hundreds, wholes, then one decimal', () {
    // A seven-day step mean carries no unit digits.
    expect(roundGoalAggregate(7684.428571), 7700);
    expect(roundGoalAggregate(1049), 1000);
    // Blood pressure is whole numbers.
    expect(roundGoalAggregate(127.3), 127);
    expect(roundGoalAggregate(127.6), 128);
    // Weight keeps the one decimal that means something.
    expect(roundGoalAggregate(94.53), 94.5);
    expect(roundGoalAggregate(94.55), 94.6);
  });

  test('whole results stay ints, so serialized FACTS grow no ".0"', () {
    expect(roundGoalAggregate(95), isA<int>());
    expect(roundGoalAggregate(6400), isA<int>());
    expect(roundGoalAggregate(94.5), isA<double>());
  });

  test('never rounds a value onto the wrong side of its target', () {
    // 9,950 must not read as "10,000 of 10,000".
    expect(roundGoalAggregate(9950, against: 10000), 9950);
    // The fixed ladder's last rung was not enough for 87.996 vs 88: keep
    // adding decimals until the two stop reading as the same number.
    expect(roundGoalAggregate(87.996, against: 88), 87.996);
    // A genuinely equal pair still quantizes normally.
    expect(roundGoalAggregate(10000, against: 10000), 10000);
    // Far from the target, the coarse step is safe and applies.
    expect(roundGoalAggregate(7684.428571, against: 10000), 7700);
  });
}
