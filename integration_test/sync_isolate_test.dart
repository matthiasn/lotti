import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_host.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_startup.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../test/database/test_utils.dart';
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
  late MockDomainLogger logger;
  late GetIt services;

  setUp(() async {
    journalDb = JournalDb(inMemoryDatabase: true);
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
  });

  testWidgets('a fresh install leaves the sync isolate off', (tester) async {
    final host = await registerSyncIsolateIfEnabled(
      getIt: services,
      journalDb: journalDb,
      logger: logger,
    );

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

    final host = await registerSyncIsolateIfEnabled(
      getIt: services,
      journalDb: journalDb,
      logger: logger,
    );
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
}
