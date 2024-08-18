import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/client_runner.dart';

void main() {
  group('ClientRunner Tests', () {
    test(
      'callback is called as often as expected',
      () async {
        const delayMs = 10;
        var lastCalled = 0;
        const n = 10;
        final runner = ClientRunner<int>(
          callback: (event) async {
            debugPrint('Request #$event');
            lastCalled = event;
            await Future<void>.delayed(const Duration(milliseconds: delayMs));
          },
        );
        for (var i = 1; i <= n; i++) {
          runner.enqueueRequest(i);
        }
        expect(lastCalled, 0);
        await Future.delayed(
          const Duration(milliseconds: n * delayMs + 1000),
          () {},
        );
        expect(lastCalled, n);
      },
    );
  });
}
