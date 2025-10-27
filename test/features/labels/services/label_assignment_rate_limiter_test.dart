// ignore_for_file: avoid_redundant_argument_values, cascade_invocations

// ignore_for_file: cascade_invocations
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/labels/services/label_assignment_rate_limiter.dart';

class _MutableClock extends Clock {
  _MutableClock(this._now);
  DateTime _now;
  @override
  DateTime now() => _now;
  void advance(Duration by) => _now = _now.add(by);
}

void main() {
  test('rate limiter caps by window and prunes history', () {
    final start = DateTime(2025, 1, 1, 12, 0, 0);
    final clock = _MutableClock(start);
    final limiter = LabelAssignmentRateLimiter(clock: clock);

    const taskId = 't1';
    expect(limiter.isRateLimited(taskId), isFalse);
    expect(limiter.nextAllowedAt(taskId), isNull);

    limiter.recordAssignment(taskId);
    expect(limiter.isRateLimited(taskId), isTrue);
    final next = limiter.nextAllowedAt(taskId)!;
    expect(next.isAfter(start), isTrue);

    // Advance just under the window: still rate limited
    clock.advance(LabelAssignmentRateLimiter.rateLimitWindow -
        const Duration(seconds: 1));
    expect(limiter.isRateLimited(taskId), isTrue);

    // Advance past the window: not rate limited; entry pruned
    clock.advance(const Duration(seconds: 2));
    expect(limiter.isRateLimited(taskId), isFalse);
    expect(limiter.nextAllowedAt(taskId), isNull);
    expect(limiter.history.containsKey(taskId), isFalse);
  });

  test('history is unmodifiable', () {
    final clock = _MutableClock(DateTime(2025));
    final limiter = LabelAssignmentRateLimiter(clock: clock);
    limiter.recordAssignment('a');
    final history = limiter.history;
    expect(() => history['x'] = DateTime.now(), throwsUnsupportedError);
  });
}
