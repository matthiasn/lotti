import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/labels/services/label_assignment_rate_limiter.dart';

void main() {
  group('LabelAssignmentRateLimiter', () {
    test('allows first assignment', () {
      final limiter = LabelAssignmentRateLimiter();
      expect(limiter.isRateLimited('task-1'), isFalse);
    });

    test('blocks within window after record', () {
      final limiter = LabelAssignmentRateLimiter();
      limiter.recordAssignment('task-1');
      expect(limiter.isRateLimited('task-1'), isTrue);
    });

    test('allows after window has passed', () {
      final limiter = LabelAssignmentRateLimiter();
      // Simulate a past assignment older than the window
      final past = DateTime.now().subtract(
        LabelAssignmentRateLimiter.rateLimitWindow + const Duration(seconds: 1),
      );
      limiter.setLastAssignmentForTesting('task-1', past);
      expect(limiter.isRateLimited('task-1'), isFalse);
    });

    test('tracks multiple tasks independently', () {
      final limiter = LabelAssignmentRateLimiter();
      limiter.recordAssignment('task-1');
      expect(limiter.isRateLimited('task-1'), isTrue);
      expect(limiter.isRateLimited('task-2'), isFalse);
    });

    test('clearHistory resets state', () {
      final limiter = LabelAssignmentRateLimiter();
      limiter.recordAssignment('task-1');
      expect(limiter.isRateLimited('task-1'), isTrue);
      limiter.clearHistory();
      expect(limiter.isRateLimited('task-1'), isFalse);
    });
  });
}
