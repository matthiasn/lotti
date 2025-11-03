/// Utilities for deterministic retry and timeout testing in widget tests.
///
/// This module provides helpers to test widgets with retry logic and timeouts
/// using Flutter's built-in virtual time via [WidgetTester.pump]. Instead of
/// manually calculating complex retry sequences, you build a [RetryPumpPlan]
/// that encodes the entire retry schedule, then apply it with
/// [WidgetTesterPumpRetryX.pumpRetryPlan].
///
/// ## Example: Testing widget with timeout and retry animations
///
/// ```dart
/// testWidgets('shows retry indicator through all attempts', (tester) async {
///   // Widget will timeout after 5s per attempt, with 1s backoff
///   final plan = buildRetryBackoffPumpPlan(
///     maxRetries: 3,
///     timeout: const Duration(seconds: 5),
///     baseDelay: const Duration(seconds: 1),
///   );
///
///   await pumpWidget(tester, MyRetryWidget());
///   await tester.pump();  // Let initial frame render
///
///   // Advance through all retry attempts deterministically
///   // Total: (5s + 1ms) + 1s + (5s + 1ms) + 2s + (5s + 1ms) ≈ 18s
///   await tester.pumpRetryPlan(plan);
///
///   expect(find.text('Failed after 3 attempts'), findsOneWidget);
/// });
/// ```
///
/// See test/README.md for additional patterns and debugging tips.
library;

import 'package:flutter_test/flutter_test.dart';

/// A plan describing how much virtual time to pump at each step of a retry
/// sequence in widget tests.
///
/// Each step represents either:
/// - A timeout duration (+ epsilon) to trigger a timeout
/// - A backoff delay between retry attempts
///
/// Build plans with [buildRetryBackoffPumpPlan], then apply them with
/// [WidgetTesterPumpRetryX.pumpRetryPlan].
///
/// ## Example
///
/// ```dart
/// final plan = buildRetryBackoffPumpPlan(
///   maxRetries: 3,
///   timeout: const Duration(seconds: 5),
///   baseDelay: const Duration(seconds: 1),
/// );
///
/// print(plan.total);  // Duration(seconds: 18, milliseconds: 3)
/// print(plan.steps);  // [5.001s, 1s, 5.001s, 2s, 5.001s]
/// ```
class RetryPumpPlan {
  /// Creates a retry pump plan with the given [steps].
  ///
  /// Each step is a duration to pump. Steps typically alternate between
  /// timeout boundaries and backoff delays.
  RetryPumpPlan(this.steps);

  /// The sequence of durations to pump, in order.
  ///
  /// For plans built with [buildRetryBackoffPumpPlan], steps alternate between:
  /// - `timeout + epsilon` (to trigger timeout)
  /// - `baseDelay * 2^(attempt-1)` (exponential backoff between attempts)
  final List<Duration> steps;

  /// The total duration of all steps combined.
  ///
  /// Useful for understanding the total virtual time the plan will advance.
  Duration get total => steps.fold(Duration.zero, (acc, d) => acc + d);
}

/// Builds a retry pump plan that mirrors exponential backoff behavior for
/// widget tests.
///
/// Creates a [RetryPumpPlan] encoding the time progression for widgets that:
/// 1. Time out after [timeout] duration
/// 2. Retry up to [maxRetries] times
/// 3. Wait [baseDelay] * 2^(attempt-1) between attempts (exponential backoff)
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
/// A [RetryPumpPlan] with steps arranged as:
/// - For each attempt: `timeout + epsilon`
/// - After each attempt (except the last): `baseDelay * 2^(attempt-1)` if
///   `baseDelay > Duration.zero`
///
/// ## Example: 3 retries, 5s timeout, 1s base delay
///
/// ```dart
/// final plan = buildRetryBackoffPumpPlan(
///   maxRetries: 3,
///   timeout: const Duration(seconds: 5),
///   baseDelay: const Duration(seconds: 1),
///   epsilon: const Duration(milliseconds: 1),
/// );
///
/// // Results in steps:
/// // Attempt 1: 5.001s (5s timeout + 1ms epsilon)
/// // Backoff 1: 1s     (1s * 2^0)
/// // Attempt 2: 5.001s
/// // Backoff 2: 2s     (1s * 2^1)
/// // Attempt 3: 5.001s
/// // Total: ~18.003s
/// ```
///
/// ## Example: Single timeout, no retries
///
/// ```dart
/// final plan = buildRetryBackoffPumpPlan(
///   maxRetries: 1,
///   timeout: const Duration(seconds: 3),
///   baseDelay: Duration.zero,  // No backoff needed
/// );
///
/// // Results in steps: [3.001s]
/// ```
///
/// ## Usage in widget tests
///
/// ```dart
/// testWidgets('retries 3 times with exponential backoff', (tester) async {
///   final plan = buildRetryBackoffPumpPlan(
///     maxRetries: 3,
///     timeout: const Duration(seconds: 5),
///     baseDelay: const Duration(seconds: 1),
///   );
///
///   await pumpWidget(tester, MyRetryWidget());
///   await tester.pump();
///
///   await tester.pumpRetryPlan(plan);
///
///   expect(find.byType(RetryExhaustedDialog), findsOneWidget);
/// });
/// ```
RetryPumpPlan buildRetryBackoffPumpPlan({
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
  return RetryPumpPlan(steps);
}

/// Extension on [WidgetTester] providing retry plan helpers.
///
/// Adds [pumpRetryPlan] to deterministically advance virtual time through retry
/// sequences built with [buildRetryBackoffPumpPlan].
extension WidgetTesterPumpRetryX on WidgetTester {
  /// Applies a [RetryPumpPlan] by pumping each step in sequence.
  ///
  /// For each duration in the plan's steps:
  /// - Calls [pump] with the duration to advance Flutter's virtual time
  /// - Rebuilds widgets and runs animations for that duration
  ///
  /// This progresses virtual time deterministically, allowing timeouts to fire
  /// and retry logic to execute without waiting for real time.
  ///
  /// ## Example
  ///
  /// ```dart
  /// testWidgets('exhausts retries deterministically', (tester) async {
  ///   final plan = buildRetryBackoffPumpPlan(
  ///     maxRetries: 3,
  ///     timeout: const Duration(seconds: 5),
  ///     baseDelay: const Duration(seconds: 1),
  ///   );
  ///
  ///   await pumpWidget(tester, MyRetryWidget());
  ///   await tester.pump();
  ///
  ///   // Advance through all attempts: 5.001s, 1s, 5.001s, 2s, 5.001s
  ///   await tester.pumpRetryPlan(plan);
  ///
  ///   expect(find.text('All retries failed'), findsOneWidget);
  /// });
  /// ```
  ///
  /// ## When to use
  ///
  /// Use this when testing widgets with retry logic that:
  /// - Have multiple timeout attempts
  /// - Use exponential backoff or other delays between attempts
  /// - Show different UI states during retry sequences
  /// - Should be tested deterministically without real time passing
  ///
  /// For simpler cases (single timeout, simple animation), prefer direct
  /// [pump] calls for clarity.
  ///
  /// ## Note on animations
  ///
  /// If your widget has animations that complete during the retry sequence,
  /// consider using [pumpAndSettle] after applying the plan, or use
  /// [pumpAndSettle] with a duration instead of this helper if animations
  /// are the primary concern.
  Future<void> pumpRetryPlan(RetryPumpPlan plan) async {
    for (final step in plan.steps) {
      await pump(step);
    }
  }
}
