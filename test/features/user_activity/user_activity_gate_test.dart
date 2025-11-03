import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserActivityGate.waitUntilIdle', () {
    test('returns immediately when already idle', () {
      fakeAsync((async) {
        final service = UserActivityService();
        final gate = UserActivityGate(
          activityService: service,
          idleThreshold: const Duration(milliseconds: 50),
        );

        // Already idle at construction time
        expect(gate.canProcess, isTrue);

        // waitUntilIdle should complete without advancing time
        var completed = false;
        gate.waitUntilIdle().then((_) => completed = true);
        async.flushMicrotasks();
        expect(completed, isTrue);

        gate.dispose();
        service.dispose();
      });
    });

    test('waits until threshold elapses when recently active', () {
      fakeAsync((async) {
        // Mark user as recently active before constructing the gate so initial
        // state is non‑idle.
        final service = UserActivityService()..updateActivity();
        final gate = UserActivityGate(
          activityService: service,
          idleThreshold: const Duration(milliseconds: 120),
        );

        expect(gate.canProcess, isFalse);

        var completed = false;
        gate.waitUntilIdle().then((_) => completed = true);

        // Not yet idle
        async.flushMicrotasks();
        expect(completed, isFalse);

        // Elapse threshold and verify completion
        async
          ..elapse(const Duration(milliseconds: 121))
          ..flushMicrotasks();
        expect(completed, isTrue);

        gate.dispose();
        service.dispose();
      });
    });

    test('returns after hard deadline when continuously active', () {
      fakeAsync((async) {
        // Mark as recently active before creating the gate so it starts non‑idle.
        final service = UserActivityService()..updateActivity();
        // Create gate with a reasonable idle threshold; we will keep activity
        // happening to force the hard deadline path (~2s).
        final gate = UserActivityGate(
          activityService: service,
          idleThreshold: const Duration(milliseconds: 300),
        );

        // Continuously report activity deterministically under fake time.
        // Step through ~1900ms in 150ms increments, updating activity each step.
        const step = Duration(milliseconds: 150);
        var elapsed = Duration.zero;
        while (elapsed < const Duration(milliseconds: 1900)) {
          service.updateActivity();
          async
            ..elapse(step)
            ..flushMicrotasks();
          elapsed += step;
        }

        var completed = false;
        gate.waitUntilIdle().then((_) => completed = true);

        // Elapse to just before hard deadline (additional 100ms)
        async
          ..elapse(const Duration(milliseconds: 100))
          ..flushMicrotasks();
        expect(completed, isFalse);

        // Advance past hard deadline (~2s); small epsilon beyond boundary
        async
          ..elapse(const Duration(milliseconds: 210))
          ..flushMicrotasks();
        expect(completed, isTrue);

        gate.dispose();
        service.dispose();
      });
    });
  });
}
