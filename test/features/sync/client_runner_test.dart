import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
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

      final runner = ClientRunner<int>(
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

      final runner = ClientRunner<int>(callback: (value) async {
        processed.add(value);
      })
        ..enqueueRequest(1)
        ..enqueueRequest(2);

      async.flushMicrotasks();

      expect(processed, [1, 2]);

      runner.close();
    });
  });
}
