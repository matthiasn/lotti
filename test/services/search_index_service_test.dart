import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/search_index_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fallbacks.dart';
import '../helpers/fts5_stubs.dart';
import '../mocks/mocks.dart';

void main() {
  late MockJournalDb journalDb;
  late MockFts5Db fts;
  late MockUpdateNotifications notifications;
  late MockDomainLogger logger;
  late StreamController<Set<String>> updates;
  late SearchIndexService service;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    journalDb = MockJournalDb();
    fts = MockFts5Db();
    notifications = MockUpdateNotifications();
    logger = MockDomainLogger();
    updates = StreamController<Set<String>>.broadcast();
    stubFts5Db(fts);
    when(() => notifications.updateStream).thenAnswer((_) => updates.stream);
    when(() => fts.needsCatchUp()).thenAnswer((_) async => false);
    service = SearchIndexService(
      journalDb: journalDb,
      fts5Db: () => fts,
      updateNotifications: notifications,
      domainLogger: logger,
    );
  });

  tearDown(() async {
    await service.dispose();
    await updates.close();
  });

  test('every change announced on the update stream is indexed, whatever '
      'its origin', () async {
    await service.start();

    updates
      ..add({'local-edit'})
      ..add({'synced-entry', 'TASK'});
    await pumpEventQueue();

    verify(() => fts.indexByIds(journalDb, {'local-edit'})).called(1);
    verify(() => fts.indexByIds(journalDb, {'synced-entry', 'TASK'})).called(1);
  });

  test('start catches the index up when it owes the journal a rebuild, and '
      'only then', () async {
    when(
      () => fts.catchUp(
        journalDb,
        onProgress: any(named: 'onProgress'),
        shouldContinue: any(named: 'shouldContinue'),
      ),
    ).thenAnswer((_) async => 7);

    await service.start();
    verifyNever(
      () => fts.catchUp(any(), shouldContinue: any(named: 'shouldContinue')),
    );

    when(() => fts.needsCatchUp()).thenAnswer((_) async => true);
    await service.start();

    verify(
      () =>
          fts.catchUp(journalDb, shouldContinue: any(named: 'shouldContinue')),
    ).called(1);
    verify(
      () => logger.log(
        LogDomain.database,
        'search index caught up: 7 entities',
        subDomain: 'SearchIndexService',
      ),
    ).called(1);
  });

  test('a failure is logged, and the next change is still indexed', () async {
    when(
      () => fts.indexByIds(journalDb, {'broken'}),
    ).thenThrow(StateError('index locked'));
    await service.start();

    updates
      ..add({'broken'})
      ..add({'fine'});
    await pumpEventQueue();

    verify(
      () => logger.error(
        LogDomain.database,
        any<Object>(that: isA<StateError>()),
        stackTrace: any(named: 'stackTrace'),
        subDomain: 'SearchIndexService.indexByIds',
      ),
    ).called(1);
    verify(() => fts.indexByIds(journalDb, {'fine'})).called(1);
  });

  test('dispose stops a catch-up between batches and indexes nothing '
      'more', () async {
    when(() => fts.needsCatchUp()).thenAnswer((_) async => true);
    final batch = Completer<int>();
    late bool Function() shouldContinue;
    when(
      () => fts.catchUp(
        journalDb,
        shouldContinue: any(named: 'shouldContinue'),
      ),
    ).thenAnswer((invocation) {
      shouldContinue =
          invocation.namedArguments[#shouldContinue] as bool Function();
      return batch.future;
    });

    final starting = service.start();
    await pumpEventQueue();
    expect(shouldContinue(), isTrue);

    await service.dispose();
    expect(shouldContinue(), isFalse);
    batch.complete(0);
    await starting;

    updates.add({'after-dispose'});
    await pumpEventQueue();
    verifyNever(() => fts.indexByIds(any(), any()));
  });
}
