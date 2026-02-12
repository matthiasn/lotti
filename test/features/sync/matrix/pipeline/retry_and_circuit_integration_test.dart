import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/retry_and_circuit.dart';

void main() {
  group('RetryTracker + CircuitBreaker integration', () {
    test('circuit open does not affect retry schedule and vice versa', () {
      final retry =
          RetryTracker(ttl: const Duration(milliseconds: 500), maxEntries: 2);
      final cb = CircuitBreaker(
          failureThreshold: 2, cooldown: const Duration(milliseconds: 300));
      final t0 = DateTime.fromMillisecondsSinceEpoch(0);

      // Schedule retries
      retry
        ..scheduleNext('a', 1, t0.add(const Duration(milliseconds: 100)))
        ..scheduleNext('b', 1, t0.add(const Duration(milliseconds: 200)));
      expect(retry.size(), 2);

      // Open circuit after threshold
      expect(cb.recordFailures(1, t0), isFalse);
      expect(cb.recordFailures(1, t0), isTrue);
      expect(cb.isOpen(t0), isTrue);

      // Mark all due now; circuit remains open independently
      retry.markAllDueNow(t0);
      expect(retry.blockedUntil('a', t0), isNull);
      expect(cb.isOpen(t0), isTrue);

      // After cooldown passes, circuit closes
      final t1 = t0.add(const Duration(milliseconds: 400));
      expect(cb.isOpen(t1), isFalse);

      // Boundary prune: exactly at cap kept, +1 prunes oldest
      retry
        ..scheduleNext('c', 1, t1)
        ..prune(t1);
      expect(retry.size(), 2);
    });

    test('retry and circuit coordination behaves the same in an isolate',
        () async {
      final result = await Isolate.run(() {
        final retry = RetryTracker(
          ttl: const Duration(milliseconds: 500),
          maxEntries: 2,
        );
        final cb = CircuitBreaker(
          failureThreshold: 2,
          cooldown: const Duration(milliseconds: 300),
        );
        final t0 = DateTime.fromMillisecondsSinceEpoch(0);

        retry
          ..scheduleNext('a', 1, t0.add(const Duration(milliseconds: 100)))
          ..scheduleNext('b', 1, t0.add(const Duration(milliseconds: 200)));

        final openedOnThreshold = cb.recordFailures(1, t0);
        final opened = cb.recordFailures(1, t0);
        final isOpenAtStart = cb.isOpen(t0);

        retry.markAllDueNow(t0);
        final blockedAAfterMark = retry.blockedUntil('a', t0);
        final stillOpenAfterRetryUpdate = cb.isOpen(t0);

        final t1 = t0.add(const Duration(milliseconds: 400));
        final isOpenAfterCooldown = cb.isOpen(t1);

        retry
          ..scheduleNext('c', 1, t1)
          ..prune(t1);

        return <String, Object?>{
          'openedOnThreshold': openedOnThreshold,
          'opened': opened,
          'isOpenAtStart': isOpenAtStart,
          'blockedAAfterMark': blockedAAfterMark?.millisecondsSinceEpoch,
          'stillOpenAfterRetryUpdate': stillOpenAfterRetryUpdate,
          'isOpenAfterCooldown': isOpenAfterCooldown,
          'sizeAfterPrune': retry.size(),
        };
      });

      expect(result['openedOnThreshold'], isFalse);
      expect(result['opened'], isTrue);
      expect(result['isOpenAtStart'], isTrue);
      expect(result['blockedAAfterMark'], isNull);
      expect(result['stillOpenAfterRetryUpdate'], isTrue);
      expect(result['isOpenAfterCooldown'], isFalse);
      expect(result['sizeAfterPrune'], 2);
    });

    test('isolate can perform real loopback network retries with circuit open',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      var requestCount = 0;
      server.listen((HttpRequest request) async {
        requestCount++;
        if (requestCount <= 2) {
          request.response.statusCode = HttpStatus.serviceUnavailable;
          request.response.write('retry');
        } else {
          request.response.statusCode = HttpStatus.ok;
          request.response.write('ok');
        }
        await request.response.close();
      });

      final url = Uri(
        scheme: 'http',
        host: server.address.address,
        port: server.port,
        path: '/health',
      ).toString();

      final result = await Isolate.run(() async {
        final retry = RetryTracker(
          ttl: const Duration(seconds: 5),
          maxEntries: 8,
        );
        // Use a generous cooldown; actual waiting uses deterministic time
        // advancement so the exact value doesn't affect test duration.
        const cooldown = Duration(milliseconds: 300);
        final cb = CircuitBreaker(
          failureThreshold: 2,
          cooldown: cooldown,
        );

        var attempts = 0;
        var openedCircuit = false;
        var finalStatus = 0;
        // Track time explicitly to avoid flaky wall-clock dependence.
        var now = DateTime.fromMillisecondsSinceEpoch(0);

        while (attempts < 5) {
          attempts++;
          final client = HttpClient();
          try {
            final request = await client.getUrl(Uri.parse(url));
            final response = await request.close();
            finalStatus = response.statusCode;
            await response.drain<void>();

            if (response.statusCode == HttpStatus.ok) {
              break;
            }

            final nextAttempts = retry.attempts('loopback') + 1;
            now = now.add(const Duration(milliseconds: 30));
            retry.scheduleNext('loopback', nextAttempts, now);
            final openedNow = cb.recordFailures(1, now);
            openedCircuit = openedCircuit || openedNow;
            if (cb.isOpen(now)) {
              // Advance tracked time past the cooldown deterministically.
              now = now.add(cooldown + const Duration(milliseconds: 1));
            }
          } finally {
            client.close(force: true);
          }
        }

        return <String, Object>{
          'attempts': attempts,
          'openedCircuit': openedCircuit,
          'finalStatus': finalStatus,
        };
      });

      expect(result['openedCircuit'], isTrue);
      expect(result['finalStatus'], HttpStatus.ok);
      expect(result['attempts'], 3);
      expect(requestCount, 3);
    });
  });
}
