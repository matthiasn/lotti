import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/client_runner.dart';
import 'package:lotti/services/dev_logger.dart';
import '../test_utils/fake_time.dart';

void main() {
  group('ClientRunner Tests', () {
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
  });
}
