import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/instrumentation/sync_cost_meter.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:matrix/matrix.dart' show SyncStatus, SyncStatusUpdate;
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockDomainLogger logger;
  late Set<LogDomain> enabled;

  setUp(() {
    logger = MockDomainLogger();
    enabled = {LogDomain.sync};
    when(() => logger.enabledDomains).thenAnswer((_) => enabled);
    when(
      () => logger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
        level: any(named: 'level'),
      ),
    ).thenReturn(null);
  });

  // The production cadence: a report a minute, a probe tick every 100 ms.
  SyncCostMeter makeMeter() => SyncCostMeter(logger: logger);

  /// The summary lines the meter wrote to the sync log.
  List<String> reported() => verify(
    () => logger.log(
      LogDomain.sync,
      captureAny(),
      subDomain: 'cost',
      level: any(named: 'level'),
    ),
  ).captured.cast<String>();

  test('a synchronous section is timed by the clock while it runs', () {
    fakeAsync((async) {
      final meter = makeMeter();

      final result = meter.measureSync(SyncCostSection.admissionCopy, () {
        async.elapseBlocking(const Duration(milliseconds: 40));
        return 'copied';
      });

      expect(result, 'copied');
      expect(
        meter.summary(),
        startsWith('sync cost 60s: copy 40ms/1 (max 40)'),
      );
    });
  });

  test('an async section is timed until its future completes, failures '
      'included', () {
    fakeAsync((async) {
      final meter = makeMeter();
      final done = Completer<void>();

      final admitted = meter.measure(SyncCostSection.admission, () async {
        await done.future;
        return 3;
      });
      int? value;
      unawaited(admitted.then((v) => value = v));
      async.elapse(const Duration(milliseconds: 250));
      done.complete();
      async.flushMicrotasks();
      Object? error;
      unawaited(
        meter
            .measure<void>(
              SyncCostSection.admission,
              () => throw StateError('decrypt failed'),
            )
            .catchError((Object e) => error = e),
      );
      async.flushMicrotasks();

      expect(value, 3);
      expect(error, isStateError);
      expect(meter.summary(), contains('admit 250ms/2 (max 250)'));
    });
  });

  test('a span ended twice counts once', () {
    fakeAsync((async) {
      final meter = makeMeter();

      final span = meter.begin(SyncCostSection.sdkSync);
      async.elapse(const Duration(milliseconds: 30));
      span
        ..end()
        ..end();

      expect(meter.summary(), contains('sdk 30ms/1 (max 30)'));
    });
  });

  test('with the sync log off nothing is counted or written', () {
    fakeAsync((async) {
      enabled = {};
      final meter = makeMeter()
        ..start()
        ..measureSync(SyncCostSection.admissionCopy, () {
          async.elapseBlocking(const Duration(milliseconds: 40));
        });
      async.elapse(const Duration(seconds: 60));

      expect(meter.summary(), isNull);
      verifyNever(
        () => logger.log(
          any(),
          any(),
          subDomain: 'cost',
          level: any(named: 'level'),
        ),
      );
      unawaited(meter.dispose());
    });
  });

  test('a stall while sync runs is counted as one, and a stall without it '
      'as a plain stall', () {
    fakeAsync((async) {
      final meter = makeMeter()..start();
      async.elapse(const Duration(milliseconds: 100));

      // The UI isolate blocks for 250 ms inside a sync section: the probe
      // tick due 100 ms after the last one fires 150 ms late.
      meter.measureSync(SyncCostSection.admissionCopy, () {
        async.elapseBlocking(const Duration(milliseconds: 250));
      });
      // Then 180 ms of blocking with no sync work anywhere near it: the
      // next tick fires 130 ms late.
      async
        ..elapse(const Duration(milliseconds: 200))
        ..elapseBlocking(const Duration(milliseconds: 180))
        ..elapse(const Duration(milliseconds: 200));

      expect(
        meter.summary(),
        endsWith(
          '| ui stall 280ms (150ms with sync running), worst 150ms, '
          '2 over 50ms',
        ),
      );
      unawaited(meter.dispose());
    });
  });

  test('each report writes the minute and starts the next one empty', () {
    fakeAsync((async) {
      final meter = makeMeter()..start();

      final span = meter.begin(SyncCostSection.bridgeWalk);
      async.elapse(const Duration(milliseconds: 700));
      span.end();
      async
        ..elapse(const Duration(seconds: 60))
        // A quiet minute writes nothing.
        ..elapse(const Duration(seconds: 60));

      const line =
          'sync cost 60s: bridge 700ms/1 (max 700) | '
          'ui stall 0ms (0ms with sync running), worst 0ms, 0 over 50ms';
      expect(reported(), [line]);
      unawaited(meter.dispose());
    });
  });

  test('switching the sync log on starts the stall probe at the next '
      'report', () {
    fakeAsync((async) {
      enabled = {};
      final meter = makeMeter()..start();
      async.elapse(const Duration(seconds: 60));

      enabled = {LogDomain.sync};
      async
        ..elapse(const Duration(seconds: 60))
        ..elapse(const Duration(milliseconds: 100))
        ..elapseBlocking(const Duration(milliseconds: 160))
        ..elapse(const Duration(milliseconds: 100));

      expect(meter.summary(), contains('ui stall 60ms'));

      // And switching it off stops it again.
      enabled = {};
      async
        ..elapse(const Duration(seconds: 60))
        ..elapseBlocking(const Duration(milliseconds: 500))
        ..elapse(const Duration(seconds: 1));
      expect(meter.summary(), isNull);
      unawaited(meter.dispose());
    });
  });

  test("the SDK's sync handling is timed from processing to finished or "
      'error, and a superseded sync closes its span', () {
    fakeAsync((async) {
      final statuses = StreamController<SyncStatusUpdate>(sync: true);
      final meter = makeMeter()..observeSdkSync(statuses.stream);

      // Waiting on the network is not UI-isolate work and is not counted.
      statuses.add(const SyncStatusUpdate(SyncStatus.waitingForResponse));
      async.elapse(const Duration(seconds: 30));
      statuses.add(const SyncStatusUpdate(SyncStatus.processing));
      async.elapse(const Duration(milliseconds: 300));
      statuses.add(const SyncStatusUpdate(SyncStatus.cleaningUp));
      async.elapse(const Duration(milliseconds: 100));
      statuses
        ..add(const SyncStatusUpdate(SyncStatus.finished))
        // A sync the SDK dropped for a newer one, then a failed one.
        ..add(const SyncStatusUpdate(SyncStatus.processing));
      async.elapse(const Duration(milliseconds: 50));
      statuses.add(const SyncStatusUpdate(SyncStatus.processing));
      async.elapse(const Duration(milliseconds: 20));
      statuses.add(const SyncStatusUpdate(SyncStatus.error));

      expect(meter.summary(), contains('sdk 470ms/3 (max 400)'));
      unawaited(meter.dispose());
      unawaited(statuses.close());
    });
  });

  test('the inert meter only emits timeline spans', () {
    fakeAsync((async) {
      final meter = SyncCostMeter.inert()..start();

      final value = meter.measureSync(SyncCostSection.apply, () => 7);
      async.elapse(const Duration(minutes: 2));

      expect(value, 7);
      expect(meter.summary(), isNull);
      verifyNever(() => logger.enabledDomains);
    });
  });
}
