import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_host.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_startup.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_queue_settlement.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../test/database/test_utils.dart';
import '../test/features/sync/queue/test_utils.dart';
import '../test/mocks/mocks.dart';

/// The sync isolate in a real app build (ADR 0142), from the flag a fresh
/// install seeds to a worker answering inside the running engine.
///
/// Unit tests spawn the worker on the Dart VM; this runs it in the compiled
/// app, which is where a stray platform-channel call or an isolate the
/// engine will not start would show. Later steps grow this file into the
/// two-device suite the isolated sync stack is specified by, the way the
/// removed actor's network test was (ADR 0046).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerJournalDbTestFallbacks);

  late JournalDb journalDb;
  late SyncDatabase syncDb;
  late Directory tempDir;
  late MockDomainLogger logger;
  late GetIt services;

  setUp(() async {
    journalDb = JournalDb(inMemoryDatabase: true);
    tempDir = await Directory.systemTemp.createTemp('sync_isolate_it');
    syncDb = SyncDatabase(
      background: false,
      documentsDirectoryProvider: () async => tempDir,
      tempDirectoryProvider: () async => tempDir,
    );
    await initConfigFlags(journalDb, inMemoryDatabase: true);
    logger = MockDomainLogger();
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
    services = GetIt.asNewInstance();
  });

  tearDown(() async {
    await services.reset();
    await journalDb.close();
    await syncDb.close();
    await tempDir.delete(recursive: true);
  });

  Future<SyncIsolateHost?> register() => registerSyncIsolateIfEnabled(
    getIt: services,
    journalDb: journalDb,
    syncDatabase: syncDb,
    documentsDirectory: tempDir,
    temporaryDirectory: () async => tempDir,
    logger: logger,
  );

  testWidgets('a fresh install leaves the sync isolate off', (tester) async {
    final host = await register();

    expect(host, isNull);
    expect(services.isRegistered<SyncIsolateHost>(), isFalse);
  });

  testWidgets('turned on, the worker starts in the app and answers until '
      'it is disposed', (tester) async {
    await journalDb.upsertConfigFlag(
      const ConfigFlag(
        name: useIsolateSyncFlag,
        description: 'Start the sync isolate?',
        status: true,
      ),
    );

    final host = await register();
    await tester.runAsync(
      () => host!.states.firstWhere((s) => s == SyncIsolateState.running),
    );

    final health = await tester.runAsync(host!.ping);
    expect(health!.handled, 1);
    verifyNever(
      () => logger.error(
        any(),
        any<Object>(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
        message: any(named: 'message'),
      ),
    );

    await tester.runAsync(services.reset);
    expect(host.state, SyncIsolateState.disposed);
  });

  testWidgets("turned on, the worker owns the inbound queue in the app's own "
      'sync.sqlite: it leases what the UI isolate enqueued and its settlement '
      "reaches the UI isolate's Drift streams", (tester) async {
    await journalDb.upsertConfigFlag(
      const ConfigFlag(
        name: useIsolateSyncFlag,
        description: 'Start the sync isolate?',
        status: true,
      ),
    );
    final host = await register();
    await tester.runAsync(
      () => host!.states.firstWhere((s) => s == SyncIsolateState.running),
    );
    final queue = InboundQueue(
      trust: AdmittingSyncEventTrust(),
      db: syncDb,
      logging: logger,
    );
    addTearDown(queue.dispose);
    // The UI isolate's own Drift stream over the row. It fires for the
    // worker's settlement only through the startup's tables-changed bridge.
    final statuses = syncDb
        .select(syncDb.inboundEventQueue)
        .watchSingleOrNull()
        .where((row) => row != null)
        .map((row) => row!.status);
    final seenApplied = statuses.firstWhere(
      (status) => status == InboundQueueStatuses.applied,
    );

    await tester.runAsync(() async {
      await queue.enqueueLive(
        buildSyncEvent(
          eventId: r'$in-app',
          roomId: '!room:example.org',
          originTsMs: 1,
        ),
      );
      final leased = await host!.lease(maxBatch: 1);
      expect(leased.single.eventId, r'$in-app');
      final applied = await host.settle([
        InboundEntryOutcome(leased.single, ApplyOutcome.applied),
      ]);
      expect(applied, 1);
      await seenApplied.timeout(const Duration(seconds: 10));
    });

    expect((await queue.stats()).applied, 1);
    await tester.runAsync(services.reset);
  });
}
