import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';

void main() {
  group('UserActivityGate', () {
    test('waitUntilIdle resolves immediately when already idle', () async {
      final service = UserActivityService();
      final gate = UserActivityGate(
        activityService: service,
        idleThreshold: const Duration(milliseconds: 200),
      );

      expect(gate.canProcess, isTrue);
      await gate.waitUntilIdle();

      await gate.dispose();
      await service.dispose();
    });

    test('waitUntilIdle waits for threshold after activity', () {
      fakeAsync((async) {
        final service = UserActivityService();
        final gate = UserActivityGate(
          activityService: service,
          idleThreshold: const Duration(milliseconds: 500),
        );

        service.updateActivity();
        async.flushMicrotasks();

        expect(gate.canProcess, isFalse);

        var completed = false;
        gate.waitUntilIdle().then((_) => completed = true);

        async.elapse(const Duration(milliseconds: 400));
        expect(completed, isFalse);

        async
          ..elapse(const Duration(milliseconds: 100))
          ..flushTimers();
        expect(gate.canProcess, isTrue);
        expect(completed, isTrue);

        gate.dispose();
        service.dispose();
      });
    });

    test('canProcessStream emits changes on activity transitions', () {
      fakeAsync((async) {
        final service = UserActivityService();
        final gate = UserActivityGate(
          activityService: service,
          idleThreshold: const Duration(milliseconds: 50),
        );

        final events = <bool>[];
        final sub = gate.canProcessStream.listen(events.add);

        service.updateActivity();
        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 60))
          ..flushTimers();

        expect(events.contains(false), isTrue);
        expect(events.last, isTrue);

        sub.cancel();
        gate.dispose();
        service.dispose();
      });
    });

    test('initial state stays busy until idle threshold elapses', () {
      fakeAsync((async) {
        final service = UserActivityService()..updateActivity();

        final gate = UserActivityGate(
          activityService: service,
          idleThreshold: const Duration(milliseconds: 200),
        );

        final events = <bool>[];
        final sub = gate.canProcessStream.listen(events.add);

        expect(gate.canProcess, isFalse);

        async.flushMicrotasks();
        expect(events, isEmpty);

        async
          ..elapse(const Duration(milliseconds: 200))
          ..flushTimers();

        expect(events, [true]);

        sub.cancel();
        gate.dispose();
        service.dispose();
      });
    });
  });
}
