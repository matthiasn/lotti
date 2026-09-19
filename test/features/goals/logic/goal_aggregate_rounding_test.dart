import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

  group('properties', () {
    // Values with up to three decimals across every magnitude tier.
    final value = glados.any.combine2(
      glados.any.intInRange(-2000000, 2000000),
      glados.any.intInRange(0, 4),
      (int mantissa, int decimals) => mantissa / math.pow(10, decimals),
    );
    final offset = glados.any.intInRange(-200, 201);

    glados.Glados(value, glados.ExploreConfig(numRuns: 400)).test(
      'without a target: bounded by the tier step, idempotent, int if whole',
      (x) {
        final rounded = roundGoalAggregate(x);
        final bound = x.abs() >= 1000
            ? 50
            : x.abs() >= 100
            ? 0.5
            : 0.05;
        expect((rounded - x).abs(), lessThanOrEqualTo(bound + 1e-9));
        expect(roundGoalAggregate(rounded), rounded);
        if (rounded is double) {
          expect(rounded, isNot(rounded.roundToDouble()));
        }
      },
      tags: 'glados',
    );

    glados.Glados2(value, offset, glados.ExploreConfig(numRuns: 400)).test(
      'against a target: never rounded onto or across it',
      (target, delta) {
        // Offsets from a thousandth up to a few hundred units, so the coarse
        // step regularly collides with the target.
        final x = target + delta * (delta.isEven ? 1 : 0.001);
        final rounded = roundGoalAggregate(x, against: target);
        expect((rounded - target).sign, (x - target).sign, reason: '$x');
      },
      tags: 'glados',
    );
  });
}
