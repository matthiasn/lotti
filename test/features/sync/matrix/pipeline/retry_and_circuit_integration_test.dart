import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/retry_and_circuit.dart';

void main() {
  group('RetryTracker + CircuitBreaker integration', () {
    test('circuit open does not affect retry schedule and vice versa', () {
      final retry =
          RetryTracker(ttl: const Duration(milliseconds: 500), maxEntries: 2);
      final cb = CircuitBreaker(
          failureThreshold: 2, cooldown: const Duration(milliseconds: 300));
      final t0 = DateTime.fromMillisecondsSinceEpoch(0);

      // Schedule retries
      retry
        ..scheduleNext('a', 1, t0.add(const Duration(milliseconds: 100)))
        ..scheduleNext('b', 1, t0.add(const Duration(milliseconds: 200)));
      expect(retry.size(), 2);

      // Open circuit after threshold
      expect(cb.recordFailures(1, t0), isFalse);
      expect(cb.recordFailures(1, t0), isTrue);
      expect(cb.isOpen(t0), isTrue);

      // Mark all due now; circuit remains open independently
      retry.markAllDueNow(t0);
      expect(retry.blockedUntil('a', t0), isNull);
      expect(cb.isOpen(t0), isTrue);

      // After cooldown passes, circuit closes
      final t1 = t0.add(const Duration(milliseconds: 400));
      expect(cb.isOpen(t1), isFalse);

      // Boundary prune: exactly at cap kept, +1 prunes oldest
      retry
        ..scheduleNext('c', 1, t1)
        ..prune(t1);
      expect(retry.size(), 2);
    });
  });
}
