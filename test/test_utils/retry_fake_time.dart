import 'package:fake_async/fake_async.dart';

/// A simple plan describing how much fake time to elapse per step in a retry
/// sequence. Steps alternate between per-attempt timeouts and (if non-zero)
/// exponential backoff delays.
class RetryPlan {
  RetryPlan(this.steps);

  final List<Duration> steps;

  Duration get total => steps.fold(Duration.zero, (acc, d) => acc + d);
}

/// Builds a retry plan that mirrors exponential backoff behavior.
///
/// - For each attempt, first elapse [timeout] + [epsilon] to deterministically
///   trigger a timeout.
/// - Between attempts (except after the last), elapse [baseDelay] * 2^(attempt-1)
///   if [baseDelay] is greater than zero.
RetryPlan buildRetryBackoffPlan({
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
  return RetryPlan(steps);
}

extension FakeAsyncRetryX on FakeAsync {
  /// Applies a [RetryPlan] by elapsing each step and flushing microtasks
  /// after each segment to progress timers and queued tasks deterministically.
  void elapseRetryPlan(RetryPlan plan) {
    for (final step in plan.steps) {
      elapse(step);
      flushMicrotasks();
    }
  }
}
