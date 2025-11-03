import 'package:flutter_test/flutter_test.dart';

/// A simple plan describing how much virtual time to pump per step in a retry
/// sequence. Steps alternate between per-attempt timeouts and (if non-zero)
/// exponential backoff delays.
class RetryPumpPlan {
  RetryPumpPlan(this.steps);

  final List<Duration> steps;

  Duration get total => steps.fold(Duration.zero, (acc, d) => acc + d);
}

/// Builds a retry pump plan mirroring exponential backoff behavior for
/// widget tests. Use with [WidgetTesterPumpRetryX.pumpRetryPlan].
RetryPumpPlan buildRetryBackoffPumpPlan({
  required int maxRetries,
  required Duration timeout,
  required Duration baseDelay,
  Duration epsilon = const Duration(milliseconds: 1),
}) {
  final steps = <Duration>[];
  for (var attempt = 1; attempt <= maxRetries; attempt++) {
    steps.add(timeout + epsilon);
    if (attempt < maxRetries && baseDelay > Duration.zero) {
      final factor = 1 << (attempt - 1);
      steps.add(baseDelay * factor);
    }
  }
  return RetryPumpPlan(steps);
}

extension WidgetTesterPumpRetryX on WidgetTester {
  /// Applies a [RetryPumpPlan] by pumping each step in sequence to advance
  /// virtual time deterministically in widget tests.
  Future<void> pumpRetryPlan(RetryPumpPlan plan) async {
    for (final step in plan.steps) {
      await pump(step);
    }
  }
}
