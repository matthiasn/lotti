import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/retry_and_circuit.dart';

void main() {
  group('RetryTracker', () {
    test('blocks until nextDue and schedules/clears/prunes', () {
      final tracker =
          RetryTracker(ttl: const Duration(seconds: 1), maxEntries: 2);
      final now = DateTime.fromMillisecondsSinceEpoch(0);
      final due = now.add(const Duration(milliseconds: 500));

      expect(tracker.size(), 0);
      tracker.scheduleNext('a', 1, due);
      expect(tracker.size(), 1);
      expect(tracker.blockedUntil('a', now), due);
      expect(tracker.attempts('a'), 1);

      // After due passed, not blocked
      final later = now.add(const Duration(milliseconds: 600));
      expect(tracker.blockedUntil('a', later), isNull);

      // Prune based on ttl
      final beyondTtl = now.add(const Duration(seconds: 2));
      tracker.prune(beyondTtl);
      expect(tracker.size(), 0);

      // Enforce max entries by evicting oldest
      tracker
        ..scheduleNext('a', 1, now)
        ..scheduleNext('b', 1, now.add(const Duration(milliseconds: 1)))
        ..scheduleNext('c', 1, now.add(const Duration(milliseconds: 2)));
      // Enforce size cap via prune
      // ignore: cascade_invocations
      tracker.prune(now);
      expect(tracker.size(), 2);

      // mark all due now
      tracker.markAllDueNow(now);
      expect(tracker.blockedUntil('b', now), isNull);
      expect(tracker.blockedUntil('c', now), isNull);
    });
  });

  group('CircuitBreaker', () {
    test('opens after threshold and provides cooldown, resets on success', () {
      final cb = CircuitBreaker(
        failureThreshold: 3,
        cooldown: const Duration(seconds: 2),
      );
      final t0 = DateTime.fromMillisecondsSinceEpoch(0);
      expect(cb.remainingCooldown(t0), isNull);
      expect(cb.isOpen(t0), isFalse);

      // Record fewer than threshold -> still closed
      expect(cb.recordFailures(2, t0), isFalse);
      expect(cb.isOpen(t0), isFalse);

      // Cross threshold -> opens
      expect(cb.recordFailures(1, t0), isTrue);
      expect(cb.isOpen(t0), isTrue);
      expect(cb.remainingCooldown(t0), const Duration(seconds: 2));

      // After cooldown finished -> closed
      final t1 = t0.add(const Duration(seconds: 3));
      expect(cb.isOpen(t1), isFalse);

      // Reset clears failure counter
      cb.reset();
      expect(cb.isOpen(t1), isFalse);
    });
  });
}
