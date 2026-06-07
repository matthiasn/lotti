import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/client_runner.dart';
import 'package:lotti/services/dev_logger.dart';

import '../../test_utils/fake_time.dart';

void main() {
  test('callback is called as often as expected', () {
    fakeAsync((async) {
      const delayMs = 10;
      var lastCalled = 0;
      const n = 10;
      final runner = ClientRunner<int>(
        callback: (event) async {
          DevLogger.log(name: 'Test', message: 'Request #$event');
          lastCalled = event;
          await Future<void>.delayed(const Duration(milliseconds: delayMs));
        },
      );

      for (var i = 1; i <= n; i++) {
        runner.enqueueRequest(i);
      }

      // Kick the runner loop to start processing the first item.
      async.flushMicrotasks();

      // Process each queued item by advancing fake time per callback delay.
      for (var i = 0; i < n; i++) {
        async.elapseAndFlush(const Duration(milliseconds: delayMs));
      }

      expect(lastCalled, n);
    });
  });

  test('ClientRunner processes requests sequentially', () {
    fakeAsync((async) {
      final processed = <int>[];
      final pending = <Completer<void>>[];

      final runner =
          ClientRunner<int>(
              callback: (value) async {
                processed.add(value);
                final completer = Completer<void>();
                pending.add(completer);
                await completer.future;
              },
            )
            ..enqueueRequest(1)
            ..enqueueRequest(2);

      async.flushMicrotasks();

      expect(processed, [1]);
      expect(pending.length, 1);

      pending.removeAt(0).complete();
      async.flushMicrotasks();

      expect(processed, [1, 2]);
      if (pending.isNotEmpty) {
        pending.removeAt(0).complete();
        async.flushMicrotasks();
      }
      expect(pending, isEmpty);

      runner.close();
    });
  });

  test('ClientRunner drains outstanding work on close', () {
    fakeAsync((async) {
      final processed = <int>[];

      final runner =
          ClientRunner<int>(
              callback: (value) async {
                processed.add(value);
              },
            )
            ..enqueueRequest(1)
            ..enqueueRequest(2);

      async.flushMicrotasks();

      expect(processed, [1, 2]);

      runner.close();
    });
  });
  test('close() while the callback is mid-execution exits cleanly', () {
    fakeAsync((async) {
      final processed = <int>[];
      final gate = Completer<void>();

      final runner =
          ClientRunner<int>(
              callback: (value) async {
                processed.add(value);
                // First item parks mid-execution.
                if (value == 1) await gate.future;
              },
            )
            ..enqueueRequest(1)
            ..enqueueRequest(2);

      async.flushMicrotasks();
      expect(processed, [1]);

      // Close while item 1 is still in flight — must not throw, and the
      // already-streamed item 2 still drains after the gate opens.
      runner.close();
      gate.complete();
      async.flushMicrotasks();

      expect(processed, [1, 2]);
    });
  });

  glados.Glados(
    glados.ListAnys(glados.any).listWithLengthInRange(
      0,
      24,
      glados.IntAnys(glados.any).intInRange(-1000, 1000),
    ),
    glados.ExploreConfig(numRuns: 120),
  ).test(
    'every enqueued request is processed exactly once, in enqueue order',
    (requests) {
      fakeAsync((async) {
        final processed = <int>[];
        final runner = ClientRunner<int>(
          callback: (value) async {
            processed.add(value);
            // Vary the per-item latency deterministically by value so the
            // ordering claim survives interleaved timer wakeups.
            await Future<void>.delayed(
              Duration(milliseconds: value.abs() % 7),
            );
          },
        );

        requests.forEach(runner.enqueueRequest);
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 30))
          ..flushMicrotasks();

        expect(processed, requests, reason: 'requests=$requests');
        expect(runner.queueSize, 0, reason: 'requests=$requests');
        runner.close();
      });
    },
    tags: 'glados',
  );
}
