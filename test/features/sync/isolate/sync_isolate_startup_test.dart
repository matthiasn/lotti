import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_host.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_startup.dart';
import 'package:lotti/services/logging_domains.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

/// Exits without ever shaking hands.
void _exitsBeforeHandshake(SendPort host) => Isolate.exit();

void main() {
  late MockJournalDb journalDb;
  late MockDomainLogger logger;
  late GetIt getIt;

  setUp(() {
    journalDb = MockJournalDb();
    logger = MockDomainLogger();
    getIt = GetIt.asNewInstance();
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

  tearDown(() => getIt.reset());

  void flag({required bool on}) => when(
    () => journalDb.getConfigFlag(useIsolateSyncFlag),
  ).thenAnswer((_) async => on);

  test('with the flag off nothing is constructed or registered', () async {
    flag(on: false);

    final host = await registerSyncIsolateIfEnabled(
      getIt: getIt,
      journalDb: journalDb,
      logger: logger,
    );

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

    final host = await registerSyncIsolateIfEnabled(
      getIt: getIt,
      journalDb: journalDb,
      logger: logger,
    );

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

    final host = await registerSyncIsolateIfEnabled(
      getIt: getIt,
      journalDb: journalDb,
      logger: logger,
      entry: _exitsBeforeHandshake,
    );

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
}
