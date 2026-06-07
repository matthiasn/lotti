import 'dart:async';

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

        // dispose() is async; fakeAsync can't await it at the top level,
        // so kick both futures off and drain their microtasks before the
        // zone closes.
        unawaited(gate.dispose());
        unawaited(service.dispose());
        async.flushMicrotasks();
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

        // dispose() is async; fakeAsync can't await it at the top level,
        // so kick both futures off and drain their microtasks before the
        // zone closes.
        unawaited(gate.dispose());
        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    });

    test('resets idle window on repeated activity', () {
      fakeAsync((async) {
        // Mark as recently active before creating the gate so it starts non‑idle.
        final service = UserActivityService()..updateActivity();
        // Create gate with a reasonable idle threshold; we will keep activity
        // happening to verify it never completes while active.
        final gate = UserActivityGate(
          activityService: service,
        );

        // Start waiting while non-idle.
        var completed = false;
        gate.waitUntilIdle().then((_) => completed = true);

        // First idle window not yet reached.
        async
          ..elapse(const Duration(milliseconds: 400))
          ..flushMicrotasks();
        expect(completed, isFalse);

        // New activity resets the idle window.
        service.updateActivity();
        async.flushMicrotasks();
        expect(gate.canProcess, isFalse);

        // Still not idle after another partial window.
        async
          ..elapse(const Duration(milliseconds: 600))
          ..flushMicrotasks();
        expect(completed, isFalse);

        // Now allow a full idle window to pass.
        async
          ..elapse(const Duration(milliseconds: 401))
          ..flushMicrotasks();
        expect(completed, isTrue);

        // dispose() is async; fakeAsync can't await it at the top level,
        // so kick both futures off and drain their microtasks before the
        // zone closes.
        unawaited(gate.dispose());
        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    });
  });
  group('UserActivityGate — stream and lifecycle edges', () {
    test('canProcessStream is distinct across repeated activity', () {
      fakeAsync((async) {
        final service = UserActivityService()..updateActivity();
        final gate = UserActivityGate(
          activityService: service,
          idleThreshold: const Duration(milliseconds: 100),
        );

        final events = <bool>[];
        gate.canProcessStream.listen(events.add);
        async.flushMicrotasks();

        // Rapid identical non-idle transitions must not re-emit false.
        service
          ..updateActivity()
          ..updateActivity()
          ..updateActivity();
        async.flushMicrotasks();
        expect(events.where((e) => !e), hasLength(lessThanOrEqualTo(1)));

        // Going idle emits exactly one true.
        async
          ..elapse(const Duration(milliseconds: 101))
          ..flushMicrotasks();
        expect(events.where((e) => e), hasLength(1));

        unawaited(gate.dispose());
        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    });

    test('an exactly-elapsed threshold takes the zero-duration branch', () {
      fakeAsync((async) {
        final service = UserActivityService()..updateActivity();
        // Let exactly the threshold pass before constructing the gate, so
        // `idleThreshold - elapsed == Duration.zero` … the >= comparison in
        // the constructor already treats this as idle.
        async.elapse(const Duration(milliseconds: 100));
        final gate = UserActivityGate(
          activityService: service,
          idleThreshold: const Duration(milliseconds: 100),
        );

        expect(gate.canProcess, isTrue);

        // The same boundary via _handleActivity: new activity arms a
        // threshold timer; firing it flips back to idle immediately at the
        // boundary instant.
        service.updateActivity();
        async.flushMicrotasks();
        expect(gate.canProcess, isFalse);
        async
          ..elapse(const Duration(milliseconds: 100))
          ..flushMicrotasks();
        expect(gate.canProcess, isTrue);

        unawaited(gate.dispose());
        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    });

    test('activity after dispose does not throw on the closed controller', () {
      fakeAsync((async) {
        final service = UserActivityService();
        final gate = UserActivityGate(
          activityService: service,
          idleThreshold: const Duration(milliseconds: 50),
        );

        unawaited(gate.dispose());
        async.flushMicrotasks();

        // The activity subscription was cancelled before the controller
        // closed — no add-to-closed-controller error can fire.
        service.updateActivity();
        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 100))
          ..flushMicrotasks();

        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    });
  });
}
