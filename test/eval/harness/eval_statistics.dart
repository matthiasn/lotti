// Shared statistical helpers for eval reports.

import 'dart:math' as math;

const _z95 = 1.959963984540054;

/// A binomial rate with a Wilson 95% confidence interval.
class RateEstimate {
  const RateEstimate({
    required this.successes,
    required this.total,
    required this.lowerBound,
    required this.upperBound,
  });

  factory RateEstimate.wilson({
    required int successes,
    required int total,
  }) {
    if (successes < 0) {
      throw ArgumentError.value(successes, 'successes', 'must be non-negative');
    }
    if (total < 0) {
      throw ArgumentError.value(total, 'total', 'must be non-negative');
    }
    if (successes > total) {
      throw ArgumentError.value(
        successes,
        'successes',
        'must not exceed total',
      );
    }
    if (total <= 0) {
      return const RateEstimate(
        successes: 0,
        total: 0,
        lowerBound: 0,
        upperBound: 0,
      );
    }
    final n = total.toDouble();
    final p = successes / n;
    const z2 = _z95 * _z95;
    final denominator = 1 + z2 / n;
    final center = (p + z2 / (2 * n)) / denominator;
    final margin =
        _z95 * math.sqrt((p * (1 - p) + z2 / (4 * n)) / n) / denominator;
    return RateEstimate(
      successes: successes,
      total: total,
      lowerBound: math.max(0, center - margin),
      upperBound: math.min(1, center + margin),
    );
  }

  final int successes;
  final int total;
  final double lowerBound;
  final double upperBound;

  double get rate => total == 0 ? 0 : successes / total;
}
