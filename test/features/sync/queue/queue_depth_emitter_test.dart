import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/queue/inbound_queue_models.dart';
import 'package:lotti/features/sync/queue/queue_depth_emitter.dart';

QueueStats _stats({
  int total = 0,
  Map<InboundEventProducer, int> byProducer = const {},
  int? oldestEnqueuedAt,
  int abandoned = 0,
}) => QueueStats(
  total: total,
  byProducer: byProducer,
  readyNow: 0,
  oldestEnqueuedAt: oldestEnqueuedAt,
  abandoned: abandoned,
);

/// Shared bench: a [QueueDepthEmitter] over a swappable stats snapshot
/// with a call counter and a collected emission list.
class _EmitterBench {
  _EmitterBench({QueueStats? initial}) : current = initial ?? _stats() {
    emitter = QueueDepthEmitter(
      loadStats: () async {
        loadCalls++;
        // Capture before the gate: a real stats scan reads the table
        // when the load starts, not when it resolves.
        final snapshot = current;
        final gate = this.gate;
        if (gate != null) await gate.future;
        return snapshot;
      },
    );
    subscription = emitter.changes.listen(emissions.add);
  }

  late final QueueDepthEmitter emitter;
  late final StreamSubscription<QueueDepthSignal> subscription;
  final List<QueueDepthSignal> emissions = [];
  QueueStats current;
  int loadCalls = 0;

  /// When set, the next loadStats call blocks until completed.
  Completer<void>? gate;

  Future<void> close() async {
    await subscription.cancel();
    await emitter.dispose();
  }
}

void main() {
  group('schedule', () {
    test('emits one signal mapped from the loaded stats', () async {
      final bench = _EmitterBench(
        initial: _stats(
          total: 3,
          byProducer: const {InboundEventProducer.bootstrap: 3},
          oldestEnqueuedAt: 1234,
          abandoned: 2,
        ),
      );
      addTearDown(bench.close);

      bench.emitter.schedule();
      await pumpEventQueue();

      expect(bench.loadCalls, 1);
      final signal = bench.emissions.single;
      expect(signal.total, 3);
      expect(signal.byProducer, const {InboundEventProducer.bootstrap: 3});
      expect(signal.oldestEnqueuedAt, 1234);
      expect(signal.abandoned, 2);
    });

    test(
      'schedule during an in-flight load coalesces into one rerun '
      'that emits the latest stats',
      () async {
        final bench = _EmitterBench(initial: _stats(total: 5));
        addTearDown(bench.close);

        final gate = Completer<void>();
        bench.gate = gate;
        bench.emitter.schedule();
        await pumpEventQueue();
        expect(bench.loadCalls, 1);
        expect(bench.emissions, isEmpty);

        // Three triggers while the first load is blocked → exactly one
        // rerun, observing the stats as they are *after* the burst.
        bench.emitter
          ..schedule()
          ..schedule()
          ..schedule();
        bench
          ..current = _stats(total: 1)
          ..gate = null;
        gate.complete();
        await pumpEventQueue();

        expect(bench.loadCalls, 2);
        expect(bench.emissions, hasLength(2));
        expect(bench.emissions.first.total, 5);
        expect(bench.emissions.last.total, 1);
      },
    );

    test('after dispose schedule is a no-op and never loads stats', () async {
      final bench = _EmitterBench();
      await bench.close();

      bench.emitter.schedule();
      await pumpEventQueue();

      expect(bench.loadCalls, 0);
      expect(bench.emissions, isEmpty);
    });

    test(
      'dispose during an in-flight load discards the snapshot silently',
      () async {
        final bench = _EmitterBench();

        final gate = Completer<void>();
        bench.gate = gate;
        bench.emitter.schedule();
        await pumpEventQueue();
        expect(bench.loadCalls, 1);

        await bench.close();
        gate.complete();
        await pumpEventQueue();

        // No emission, no "add after close" error.
        expect(bench.emissions, isEmpty);
      },
    );

    test(
      'a loadStats failure after dispose is swallowed (teardown race)',
      () async {
        final bench = _EmitterBench();

        final gate = Completer<void>();
        bench.gate = gate;
        bench.emitter.schedule();
        await pumpEventQueue();

        await bench.close();
        // The DB the stats scan was using got torn down mid-flight.
        gate.completeError(StateError('db closed'));
        await pumpEventQueue();

        expect(bench.emissions, isEmpty);
      },
    );

    test('a loadStats failure while open surfaces as an error', () async {
      final errors = <Object>[];
      final bench = await runZonedGuarded(
        () async {
          final bench = _EmitterBench();
          final gate = Completer<void>();
          bench.gate = gate;
          bench.emitter.schedule();
          await pumpEventQueue();
          gate.completeError(StateError('boom'));
          await pumpEventQueue();
          return bench;
        },
        (error, _) => errors.add(error),
      );
      addTearDown(bench!.close);

      expect(errors.single, isA<StateError>());
      expect(bench.emissions, isEmpty);
    });
  });

  group('holdDuring', () {
    test(
      'holds back schedules inside the body and fires exactly one '
      'post-body emission with the final stats',
      () async {
        final bench = _EmitterBench();
        addTearDown(bench.close);

        await bench.emitter.holdDuring(() async {
          bench.emitter.schedule();
          bench.current = _stats(total: 7);
          bench.emitter.schedule();
          await pumpEventQueue();
          // Nothing emits while the hold is active.
          expect(bench.loadCalls, 0);
          expect(bench.emissions, isEmpty);
        });
        await pumpEventQueue();

        expect(bench.loadCalls, 1);
        expect(bench.emissions.single.total, 7);
      },
    );

    test('returns the body result and propagates body errors', () async {
      final bench = _EmitterBench();
      addTearDown(bench.close);

      expect(await bench.emitter.holdDuring(() async => 42), 42);
      await expectLater(
        bench.emitter.holdDuring<void>(
          () async => throw StateError('body failed'),
        ),
        throwsStateError,
      );
      await pumpEventQueue();
      // Neither body scheduled anything → no emission at all.
      expect(bench.emissions, isEmpty);
    });

    test(
      'nested holds: an inner schedule survives the inner finalizer '
      'and fires once when the outermost hold completes',
      () async {
        final bench = _EmitterBench(initial: _stats(total: 9));
        addTearDown(bench.close);

        await bench.emitter.holdDuring(() async {
          await bench.emitter.holdDuring(() async {
            bench.emitter.schedule();
          });
          await pumpEventQueue();
          // The inner (non-outermost) finalizer must not consume the
          // dirty bit the outer hold still owns.
          expect(bench.emissions, isEmpty);
        });
        await pumpEventQueue();

        expect(bench.loadCalls, 1);
        expect(bench.emissions.single.total, 9);
      },
    );

    test('a clean hold (no schedule inside) emits nothing', () async {
      final bench = _EmitterBench();
      addTearDown(bench.close);

      await bench.emitter.holdDuring(() async {});
      await pumpEventQueue();

      expect(bench.loadCalls, 0);
      expect(bench.emissions, isEmpty);
    });
  });
}
