import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/client_runner.dart';

void main() {
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
