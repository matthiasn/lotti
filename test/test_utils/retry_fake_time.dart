/// Utilities for deterministic retry and timeout testing under fake time.
///
/// This module provides helpers to test code with retry logic and timeouts
/// without waiting for real time to pass. Instead of manually calculating and
/// elapsing complex retry sequences, you build a [RetryPlan] that encodes the
/// entire retry schedule, then apply it with [FakeAsyncRetryX.elapseRetryPlan].
///
/// ## Example: Testing timeout with exponential backoff retries
///
/// ```dart
/// import 'package:fake_async/fake_async.dart';
/// import '../test_utils/retry_fake_time.dart';
///
/// test('exhausts retries after 3 attempts with exponential backoff', () {
///   fakeAsync((async) {
///     // System under test will timeout after 10s per attempt,
///     // with 2s base delay and exponential backoff between attempts
///     final plan = buildRetryBackoffPlan(
///       maxRetries: 3,
///       timeout: const Duration(seconds: 10),
///       baseDelay: const Duration(seconds: 2),  // 2s, 4s between attempts
///       epsilon: const Duration(seconds: 1),
///     );
///
///     sut.startOperationWithRetries();
///     async.flushMicrotasks();
///
///     // Advance through all retry attempts deterministically
///     // Total: (10s + 1s) + 2s + (10s + 1s) + 4s + (10s + 1s) = 39s
///     async.elapseRetryPlan(plan);
///
///     expect(sut.didExhaustRetries, isTrue);
///   });
/// });
/// ```
///
/// See test/README.md for additional patterns and debugging tips.
library;

import 'package:fake_async/fake_async.dart';

/// A plan describing how much fake time to elapse at each step of a retry
/// sequence.
///
/// Each step represents either:
/// - A timeout duration (+ epsilon) to trigger a timeout
/// - A backoff delay between retry attempts
///
/// Build plans with [buildRetryBackoffPlan], then apply them with
/// [FakeAsyncRetryX.elapseRetryPlan].
///
/// ## Example
///
/// ```dart
/// final plan = buildRetryBackoffPlan(
///   maxRetries: 3,
///   timeout: const Duration(seconds: 10),
///   baseDelay: const Duration(seconds: 2),
/// );
///
/// print(plan.total);  // Duration(seconds: 39)
/// print(plan.steps);  // [11s, 2s, 11s, 4s, 11s]
/// ```
class RetryPlan {
  /// Creates a retry plan with the given [steps].
  ///
  /// Each step is a duration to elapse. Steps typically alternate between
  /// timeout boundaries and backoff delays.
  RetryPlan(this.steps);

  /// The sequence of durations to elapse, in order.
  ///
  /// For plans built with [buildRetryBackoffPlan], steps alternate between:
  /// - `timeout + epsilon` (to trigger timeout)
  /// - `baseDelay * 2^(attempt-1)` (exponential backoff between attempts)
  final List<Duration> steps;

  /// The total duration of all steps combined.
  ///
  /// Useful for understanding the total virtual time the plan will advance.
  Duration get total => steps.fold(Duration.zero, (acc, d) => acc + d);
}

/// Builds a retry plan that mirrors exponential backoff behavior.
///
/// Creates a [RetryPlan] encoding the time progression for code that:
/// 1. Times out after [timeout] duration
/// 2. Retries up to [maxRetries] times
/// 3. Waits [baseDelay] * 2^(attempt-1) between attempts (exponential backoff)
///
/// ## Parameters
///
/// - [maxRetries]: Number of attempts (must be >= 1)
/// - [timeout]: How long each attempt waits before timing out
/// - [baseDelay]: Base backoff duration between attempts. Set to `Duration.zero`
///   to disable backoff.
/// - [epsilon]: Small duration added to timeout to ensure the timeout boundary
///   is crossed deterministically (default: 1ms). Increase if code checks
///   timeout boundaries with `>=` and tests are flaky.
///
/// ## Returns
///
/// A [RetryPlan] with steps arranged as:
/// - For each attempt: `timeout + epsilon`
/// - After each attempt (except the last): `baseDelay * 2^(attempt-1)` if
///   `baseDelay > Duration.zero`
///
/// ## Example: 3 retries, 10s timeout, 2s base delay
///
/// ```dart
/// final plan = buildRetryBackoffPlan(
///   maxRetries: 3,
///   timeout: const Duration(seconds: 10),
///   baseDelay: const Duration(seconds: 2),
///   epsilon: const Duration(seconds: 1),
/// );
///
/// // Results in steps:
/// // Attempt 1: 11s (10s timeout + 1s epsilon)
/// // Backoff 1: 2s  (2s * 2^0)
/// // Attempt 2: 11s
/// // Backoff 2: 4s  (2s * 2^1)
/// // Attempt 3: 11s
/// // Total: 39s
/// ```
///
/// ## Example: Single timeout, no retries
///
/// ```dart
/// final plan = buildRetryBackoffPlan(
///   maxRetries: 1,
///   timeout: const Duration(seconds: 5),
///   baseDelay: Duration.zero,  // No backoff needed
/// );
///
/// // Results in steps: [5s + epsilon]
/// ```
///
/// ## Usage in tests
///
/// ```dart
/// test('retries 3 times with exponential backoff', () {
///   fakeAsync((async) {
///     final plan = buildRetryBackoffPlan(
///       maxRetries: 3,
///       timeout: const Duration(seconds: 10),
///       baseDelay: const Duration(seconds: 2),
///     );
///
///     sut.startWithRetries();
///     async.flushMicrotasks();
///
///     async.elapseRetryPlan(plan);
///
///     expect(sut.attemptCount, 3);
///     expect(sut.succeeded, isFalse);
///   });
/// });
/// ```
RetryPlan buildRetryBackoffPlan({
  required int maxRetries,
  required Duration timeout,
  required Duration baseDelay,
  Duration epsilon = const Duration(milliseconds: 1),
}) {
  assert(maxRetries >= 1, 'maxRetries must be at least 1');
  assert(!timeout.isNegative, 'timeout must not be negative');
  assert(!baseDelay.isNegative, 'baseDelay must not be negative');
  assert(!epsilon.isNegative, 'epsilon must not be negative');

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

/// Extension on [FakeAsync] providing retry plan helpers.
///
/// Adds [elapseRetryPlan] to deterministically advance time through retry
/// sequences built with [buildRetryBackoffPlan].
extension FakeAsyncRetryX on FakeAsync {
  /// Applies a [RetryPlan] by elapsing each step and flushing microtasks.
  ///
  /// For each duration in the plan's steps:
  /// 1. Calls [elapse] with the duration
  /// 2. Calls [flushMicrotasks] to process timers and queued tasks
  ///
  /// This progresses virtual time deterministically, allowing timeouts to fire
  /// and retry logic to execute without waiting for real time.
  ///
  /// ## Example
  ///
  /// ```dart
  /// test('exhausts retries deterministically', () {
  ///   fakeAsync((async) {
  ///     final plan = buildRetryBackoffPlan(
  ///       maxRetries: 3,
  ///       timeout: const Duration(seconds: 10),
  ///       baseDelay: const Duration(seconds: 2),
  ///     );
  ///
  ///     sut.startOperationWithRetries();
  ///     async.flushMicrotasks();
  ///
  ///     // Advance through all attempts: 11s, 2s, 11s, 4s, 11s
  ///     async.elapseRetryPlan(plan);
  ///
  ///     expect(sut.finalState, RetryState.exhausted);
  ///   });
  /// });
  /// ```
  ///
  /// ## When to use
  ///
  /// Use this when testing code with retry logic that:
  /// - Has multiple timeout attempts
  /// - Uses exponential backoff or other delays between attempts
  /// - Should be tested deterministically without real time passing
  ///
  /// For simpler cases (single timeout, simple debounce), prefer direct
  /// [elapse] calls for clarity.
  void elapseRetryPlan(RetryPlan plan) {
    for (final step in plan.steps) {
      elapse(step);
      flushMicrotasks();
    }
  }
}
