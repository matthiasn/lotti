import 'package:fake_async/fake_async.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/ui/plaza_frame_pacer.dart';

void main() {
  testWidgets('default scheduler paints on vsync and cancels pending work', (
    tester,
  ) async {
    final painted = <Duration>[];
    final pacer = PlazaFramePacer(onFrame: painted.add, cap: () => null);
    addTearDown(pacer.dispose);
    pacer
      ..start()
      ..start();
    expect(tester.binding.transientCallbackCount, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(painted, [Duration.zero, const Duration(milliseconds: 16)]);
    expect(tester.binding.transientCallbackCount, 1);
    pacer.stop();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(painted.length, 2);
  });

  test('idle waits without scheduling engine frames, input wakes once', () {
    fakeAsync((async) {
      final pending = <int, FrameCallback>{};
      final painted = <Duration>[];
      var id = 0;
      final pacer = PlazaFramePacer(
        onFrame: painted.add,
        nowMicros: () => async.elapsed.inMicroseconds,
        cap: () => 30,
        schedule: (callback) {
          pending[++id] = callback;
          return id;
        },
        cancel: pending.remove,
      )..start();
      void frame(Duration at) {
        final callback = pending.values.single;
        pending.clear();
        callback(at);
      }

      frame(Duration.zero);
      expect(pending, isEmpty);
      async.elapse(const Duration(microseconds: 33332));
      expect(pending, isEmpty);
      pacer
        ..requestFrame()
        ..requestFrame();
      expect(pending.length, 1);
      frame(const Duration(milliseconds: 30));
      async.elapse(const Duration(microseconds: 33332));
      expect(
        pending,
        isEmpty,
        reason: 'the cancelled timer must not wake again',
      );
      async.elapse(const Duration(microseconds: 1));
      expect(pending.length, 1);
      frame(const Duration(milliseconds: 60));
      expect(painted, [
        Duration.zero,
        const Duration(milliseconds: 30),
        const Duration(milliseconds: 60),
      ]);
      pacer.dispose();
      async.elapse(const Duration(seconds: 1));
      expect(pending, isEmpty);
    });
  });

  test('engine delivery consumes the interval without drifting the cap', () {
    fakeAsync((async) {
      final pending = <int, FrameCallback>{};
      var id = 0;
      final pacer = PlazaFramePacer(
        onFrame: (_) {},
        nowMicros: () => async.elapsed.inMicroseconds,
        cap: () => 30,
        schedule: (callback) {
          pending[++id] = callback;
          return id;
        },
        cancel: pending.remove,
      )..start();
      for (var i = 0; i < 3; i++) {
        final callback = pending.values.single;
        pending.clear();
        async.elapse(const Duration(milliseconds: 17));
        callback(async.elapsed);
        async.elapse(const Duration(microseconds: 16332));
        expect(pending, isEmpty);
        async.elapse(const Duration(microseconds: 1));
        expect(pending.length, 1);
        expect(async.elapsed.inMicroseconds, 33333 * (i + 1));
      }
      pacer.dispose();
    });
  });

  test('frame preparation consumes the wait instead of delaying the cap', () {
    fakeAsync((async) {
      final pending = <int, FrameCallback>{};
      var id = 0;
      var work = const Duration(milliseconds: 5);
      final pacer = PlazaFramePacer(
        onFrame: (_) => async.elapse(work),
        cap: () => 30,
        nowMicros: () => async.elapsed.inMicroseconds,
        schedule: (callback) {
          pending[++id] = callback;
          return id;
        },
        cancel: pending.remove,
      )..start();
      final first = pending.values.single;
      pending.clear();
      first(Duration.zero);
      async.elapse(const Duration(microseconds: 28332));
      expect(pending, isEmpty);
      async.elapse(const Duration(microseconds: 1));
      expect(pending.length, 1);
      final next = pending.values.single;
      pending.clear();
      work = const Duration(milliseconds: 40);
      next(const Duration(milliseconds: 33));
      expect(
        pending.length,
        1,
        reason: 'overdue work needs no additional wait',
      );
      expect(async.pendingTimers, isEmpty);
      pacer.dispose();
    });
  });

  test('uncapped movement follows vsync and pause excludes hidden time', () {
    fakeAsync((async) {
      final pending = <int, FrameCallback>{};
      final painted = <Duration>[];
      var id = 0;
      final pacer = PlazaFramePacer(
        onFrame: painted.add,
        nowMicros: () => async.elapsed.inMicroseconds,
        cap: () => null,
        schedule: (callback) {
          pending[++id] = callback;
          return id;
        },
        cancel: pending.remove,
      )..start();
      void frame(int ms) {
        final callback = pending.values.single;
        pending.clear();
        callback(Duration(milliseconds: ms));
      }

      frame(0);
      expect(pending.length, 1);
      frame(16);
      pacer.stop();
      expect(pending, isEmpty);
      pacer.requestFrame();
      expect(pending, isEmpty);
      pacer.start();
      frame(10000);
      frame(10016);
      expect(painted.map((t) => t.inMilliseconds), [0, 16, 16, 32]);
      pacer
        ..dispose()
        ..start();
      expect(pending, isEmpty);
    });
  });
}
