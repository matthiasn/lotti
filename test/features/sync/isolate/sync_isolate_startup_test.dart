import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_host.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_protocol.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_startup.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_worker.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_queue_settlement.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../queue/test_utils.dart';

/// Exits without ever shaking hands.
void _exitsBeforeHandshake(SyncIsolateBoot boot) => Isolate.exit();

void main() {
  late MockJournalDb journalDb;
  late MockDomainLogger logger;
  late GetIt getIt;
  late Directory tempDir;
  late SyncDatabase syncDb;

  setUp(() async {
    journalDb = MockJournalDb();
    logger = MockDomainLogger();
    getIt = GetIt.asNewInstance();
    tempDir = await Directory.systemTemp.createTemp('sync_isolate_startup');
    syncDb = SyncDatabase(
      background: false,
      documentsDirectoryProvider: () async => tempDir,
      tempDirectoryProvider: () async => tempDir,
    );
    when(
      () => logger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
        level: any(named: 'level'),
      ),
    ).thenReturn(null);
    when(
      () => logger.error(
        any(),
        any<Object>(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
        message: any(named: 'message'),
      ),
    ).thenReturn(null);
  });

  tearDown(() async {
    await getIt.reset();
    await syncDb.close();
    await tempDir.delete(recursive: true);
  });

  Future<SyncIsolateHost?> register({SyncIsolateEntry? entry}) =>
      registerSyncIsolateIfEnabled(
        getIt: getIt,
        journalDb: journalDb,
        syncDatabase: syncDb,
        documentsDirectory: tempDir,
        temporaryDirectory: () async => tempDir,
        logger: logger,
        entry: entry ?? syncIsolateEntry,
      );

  void flag({required bool on}) => when(
    () => journalDb.getConfigFlag(useIsolateSyncFlag),
  ).thenAnswer((_) async => on);

  test('with the flag off nothing is constructed or registered', () async {
    flag(on: false);

    final host = await register();

    expect(host, isNull);
    expect(getIt.isRegistered<SyncIsolateHost>(), isFalse);
    verifyNever(
      () => logger.log(
        any(),
        any(),
        subDomain: 'isolate',
        level: any(named: 'level'),
      ),
    );
  });

  test('with the flag on the host is registered, started, and disposed '
      'with the rest of getIt', () async {
    flag(on: true);

    final host = await register();

    expect(getIt<SyncIsolateHost>(), same(host));
    // Started, not awaited: registration returned before the worker was up.
    expect(host!.state, SyncIsolateState.starting);
    await host.states.firstWhere((s) => s == SyncIsolateState.running);
    expect((await host.ping()).handled, 1);

    await getIt.reset();
    expect(host.state, SyncIsolateState.disposed);
  });

  test('a worker that cannot start does not fail registration', () async {
    flag(on: true);

    final host = await register(entry: _exitsBeforeHandshake);

    await host!.states.firstWhere((s) => s == SyncIsolateState.restarting);
    verify(
      () => logger.error(
        LogDomain.sync,
        any<Object>(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'isolate',
        message: 'starting the sync isolate failed',
      ),
    ).called(1);
  });

  test(
    "what the worker writes reaches the UI isolate's Drift streams",
    () async {
      flag(on: true);
      final host = await register();
      await host!.states.firstWhere((s) => s == SyncIsolateState.running);
      final queue = InboundQueue(
        trust: AdmittingSyncEventTrust(),
        db: syncDb,
        logging: logger,
      );
      addTearDown(queue.dispose);
      await queue.enqueueLive(
        buildSyncEvent(
          eventId: r'$watched',
          roomId: '!room:example.org',
          originTsMs: 1,
        ),
      );
      final statuses = <String>[];
      final sub = syncDb
          .select(syncDb.inboundEventQueue)
          .watchSingle()
          .listen((row) => statuses.add(row.status));
      addTearDown(sub.cancel);
      await pumpEventQueue();

      final leased = await host.lease(maxBatch: 1);
      await host.settle([
        InboundEntryOutcome(leased.single, ApplyOutcome.applied),
      ]);
      // The worker's writes do not reach this connection's streams on their
      // own; the bridge replays the tables it reports.
      await Future<void>.delayed(Duration.zero);
      await pumpEventQueue();

      expect(statuses.last, InboundQueueStatuses.applied);
      expect(statuses, contains(InboundQueueStatuses.leased));
    },
  );
}
