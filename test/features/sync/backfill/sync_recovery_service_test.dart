// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/backfill/sync_recovery_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  const interval = Duration(seconds: 10);
  setUpAll(() => registerFallbackValue(StackTrace.empty));

  for (final synchronous in [false, true]) {
    test('periodic recovery retries a synchronous=$synchronous failure', () {
      fakeAsync((async) {
        final logging = MockDomainLogger();
        final failure = StateError('store unavailable');
        var attempts = 0;
        var recovered = false;
        final service = SyncRecoveryService(
          logging: logging,
          interval: interval,
          recover: () {
            attempts++;
            if (attempts == 1) {
              if (synchronous) throw failure;
              return Future<void>.error(failure);
            }
            recovered = true;
            return Future<void>.value();
          },
        );
        var firstPassFinished = false;
        unawaited(service.start().then((_) => firstPassFinished = true));
        async.flushMicrotasks();
        expect(firstPassFinished, isTrue);
        expect(recovered, isFalse);
        verify(
          () => logging.error(
            LogDomain.sync,
            failure,
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'sync.recovery',
          ),
        ).called(1);

        async.elapse(interval);
        async.flushMicrotasks();
        expect(attempts, 2);
        expect(recovered, isTrue);
        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    });
  }

  test('starts and timer ticks share an active pass', () {
    fakeAsync((async) {
      final pending = Completer<void>();
      var attempts = 0;
      final service = SyncRecoveryService(
        logging: MockDomainLogger(),
        interval: interval,
        recover: () {
          attempts++;
          return attempts == 1 ? pending.future : Future<void>.value();
        },
      );
      final first = service.start();
      expect(service.start(), same(first));
      async.elapse(interval * 5);
      async.flushMicrotasks();
      expect(attempts, 1);
      pending.complete();
      async.flushMicrotasks();
      async.elapse(interval);
      async.flushMicrotasks();
      expect(attempts, 2);
      unawaited(service.dispose());
      async.flushMicrotasks();
    });
  });

  for (final fails in [false, true]) {
    test('shutdown drains active recovery (failure=$fails)', () {
      fakeAsync((async) {
        final pending = Completer<void>();
        var attempts = 0;
        final service = SyncRecoveryService(
          logging: MockDomainLogger(),
          interval: interval,
          recover: () {
            attempts++;
            return pending.future;
          },
        );
        unawaited(service.start());
        var disposed = false;
        unawaited(service.dispose().then((_) => disposed = true));
        async.flushMicrotasks();
        expect(disposed, isFalse);
        async.elapse(interval * 3);
        expect(attempts, 1);

        if (fails) {
          pending.completeError(StateError('store failed during shutdown'));
        } else {
          pending.complete();
        }
        async.flushMicrotasks();
        expect(disposed, isTrue);
        unawaited(service.start());
        async.elapse(interval * 3);
        async.flushMicrotasks();
        expect(attempts, 1);
        expect(async.periodicTimerCount, 0);
      });
    });
  }
}
