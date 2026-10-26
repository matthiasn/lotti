import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/isolate/isolate_apply_loop.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

/// The UI isolate's apply loop when the worker hosts the stack: it starts and
/// stops the inbound worker, and relays journal changes to the worker once
/// per burst.
void main() {
  late MockSyncIsolateHost host;
  late MockInboundQueue queue;
  late MockSyncEventProcessor processor;
  late MockJournalDb journalDb;
  late MockSyncSequenceLogService sequenceLog;
  late MockDomainLogger logging;
  late MockIsolateSyncService service;
  late MockUpdateNotifications notifications;
  late MockInboundWorker worker;
  late StreamController<Set<String>> updates;

  setUp(() {
    host = MockSyncIsolateHost();
    queue = MockInboundQueue();
    processor = MockSyncEventProcessor();
    journalDb = MockJournalDb();
    sequenceLog = MockSyncSequenceLogService();
    logging = MockDomainLogger();
    service = MockIsolateSyncService();
    notifications = MockUpdateNotifications();
    worker = MockInboundWorker();
    updates = StreamController<Set<String>>.broadcast(sync: true);
    when(() => notifications.updateStream).thenAnswer((_) => updates.stream);
    when(
      () => host.tablesChanged,
    ).thenAnswer((_) => const Stream<List<String>>.empty());
    when(() => worker.start()).thenAnswer((_) async {});
    when(() => worker.stop()).thenAnswer((_) async {});
    when(() => service.journalChanged()).thenAnswer((_) async {});
  });

  tearDown(() => updates.close());

  IsolateApplyLoop build({bool realWorker = false}) => IsolateApplyLoop(
    host: host,
    queue: queue,
    processor: processor,
    journalDb: journalDb,
    sequenceLogService: sequenceLog,
    logging: logging,
    service: service,
    updateNotifications: notifications,
    workerOverride: realWorker ? null : worker,
  );

  test('start runs the worker; starting again does not resubscribe', () {
    fakeAsync((async) {
      final loop = build()..start();
      async.flushMicrotasks();
      loop.start();
      async.flushMicrotasks();

      updates.add({'journal'});
      async.elapse(IsolateApplyLoop.journalChangedDebounce);

      verify(() => worker.start()).called(2);
      verify(() => service.journalChanged()).called(1);
      expect(updates.hasListener, isTrue);
    });
  });

  test('a burst of journal notifications is one nudge, after the debounce', () {
    fakeAsync((async) {
      build().start();
      async.flushMicrotasks();

      updates
        ..add({'journal'})
        ..add({'journal'});
      async.elapse(const Duration(milliseconds: 400));
      verifyNever(() => service.journalChanged());

      updates.add({'tasks'});
      async.elapse(const Duration(milliseconds: 400));
      verifyNever(() => service.journalChanged());

      async.elapse(const Duration(milliseconds: 100));
      verify(() => service.journalChanged()).called(1);

      updates.add({'journal'});
      async.elapse(IsolateApplyLoop.journalChangedDebounce);
      verify(() => service.journalChanged()).called(1);
    });
  });

  test('dispose drops a pending nudge and stops listening', () {
    fakeAsync((async) {
      final loop = build()..start();
      async.flushMicrotasks();
      updates.add({'journal'});

      // Not awaited: the timer and the subscription go synchronously, and the
      // worker's stop is proven below under real time.
      unawaited(loop.dispose());
      async.elapse(const Duration(seconds: 2));

      verifyNever(() => service.journalChanged());
      expect(updates.hasListener, isFalse);
    });
  });

  test('dispose stops the worker', () async {
    final loop = build();
    await loop.start();

    await loop.dispose();

    verify(() => worker.stop()).called(1);
  });

  test('without an override the loop builds its own inbound worker', () async {
    final loop = build(realWorker: true);

    // Never started: stopping an idle worker is a no-op, so dispose only has
    // to prove the composition held together.
    await loop.dispose();

    verifyNever(() => worker.start());
    verifyNever(() => worker.stop());
  });
}
