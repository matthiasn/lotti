// ignore_for_file: avoid_redundant_argument_values
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

/// [JournalDb] subclass that spies on the protected single-shot query the
/// coalescer delegates to. Counts how many real DB round-trips occur — the
/// coalescer flushes one wave through exactly one call to this method.
class _CountingJournalDb extends JournalDb {
  _CountingJournalDb()
    : super(inMemoryDatabase: true, background: false, readPool: 0);

  int basicLinkQueryCount = 0;
  Set<String>? lastMergedIds;

  @override
  Future<List<EntryLink>> runBasicLinksQueryForIds(Set<String> ids) {
    basicLinkQueryCount += 1;
    lastMergedIds = Set<String>.from(ids);
    return super.runBasicLinksQueryForIds(ids);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingJournalDb db;
  late MockLoggingService loggingService;
  Directory? testDirectory;
  Directory? previousDirectory;

  setUp(() async {
    if (getIt.isRegistered<Directory>()) {
      previousDirectory = getIt<Directory>();
      getIt.unregister<Directory>();
    }
    testDirectory = Directory.systemTemp.createTempSync(
      'lotti_basic_links_coalesce_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory' ||
                methodCall.method == 'getApplicationSupportDirectory' ||
                methodCall.method == 'getTemporaryDirectory') {
              return testDirectory!.path;
            }
            return null;
          },
        );
    getIt.registerSingleton<Directory>(testDirectory!);

    loggingService = MockLoggingService();
    when(
      () => loggingService.captureEvent(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String?>(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => loggingService.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String?>(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(loggingService);

    db = _CountingJournalDb();
    await initConfigFlags(db, inMemoryDatabase: true);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await db.close();
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.unregister<Directory>();
    if (previousDirectory != null) {
      getIt.registerSingleton<Directory>(previousDirectory!);
    }
    if (testDirectory != null && testDirectory!.existsSync()) {
      testDirectory!.deleteSync(recursive: true);
    }
  });

  Future<void> insertBasicLink({
    required String fromId,
    required String toId,
  }) async {
    final link = EntryLink.basic(
      id: 'link-$fromId-$toId',
      fromId: fromId,
      toId: toId,
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1),
      vectorClock: null,
    );
    await db.upsertEntryLink(link);
  }

  group('basicLinksForEntryIds microtask coalescing', () {
    test(
      'two concurrent callers share one DB query and each receives only '
      'the links whose to_id matches its own set',
      () async {
        await insertBasicLink(fromId: 'parent-A', toId: 'child-A');
        await insertBasicLink(fromId: 'parent-B', toId: 'child-B');
        await insertBasicLink(fromId: 'parent-C', toId: 'child-C');
        db.basicLinkQueryCount = 0;

        final futureA = db.basicLinksForEntryIds({'child-A'});
        final futureB = db.basicLinksForEntryIds({'child-B', 'child-C'});

        final resultA = await futureA;
        final resultB = await futureB;

        expect(resultA.map((l) => l.toId), ['child-A']);
        expect(
          resultB.map((l) => l.toId).toSet(),
          {'child-B', 'child-C'},
        );
        expect(db.basicLinkQueryCount, 1);
      },
    );

    test('empty id set short-circuits without issuing a query', () async {
      final result = await db.basicLinksForEntryIds(const <String>{});
      expect(result, isEmpty);
      expect(db.basicLinkQueryCount, 0);
    });

    test('distinct microtask waves issue separate queries', () async {
      await insertBasicLink(fromId: 'p', toId: 'child');

      db.basicLinkQueryCount = 0;

      final first = await db.basicLinksForEntryIds({'child'});
      final second = await db.basicLinksForEntryIds({'child'});

      expect(first.map((l) => l.toId), ['child']);
      expect(second.map((l) => l.toId), ['child']);
      expect(db.basicLinkQueryCount, 2);
    });

    test('RatingLink rows are not returned', () async {
      await insertBasicLink(fromId: 'task-1', toId: 'te-1');
      final rating = EntryLink.rating(
        id: 'rating-link',
        fromId: 'rating-1',
        toId: 'te-1',
        createdAt: DateTime(2026, 4, 1),
        updatedAt: DateTime(2026, 4, 1),
        vectorClock: null,
      );
      await db.upsertEntryLink(rating);

      db.basicLinkQueryCount = 0;
      final links = await db.basicLinksForEntryIds({'te-1'});

      expect(links.map((l) => l.id), ['link-task-1-te-1']);
      expect(db.basicLinkQueryCount, 1);
    });

    test(
      'same id requested twice in one wave issues exactly one query',
      () async {
        await insertBasicLink(fromId: 'p', toId: 'target');
        db.basicLinkQueryCount = 0;

        final results = await Future.wait([
          db.basicLinksForEntryIds({'target'}),
          db.basicLinksForEntryIds({'target'}),
        ]);

        expect(results[0].map((l) => l.toId), ['target']);
        expect(results[1].map((l) => l.toId), ['target']);
        expect(db.basicLinkQueryCount, 1);
      },
    );

    test(
      'query error propagates to every caller waiting on the wave',
      () async {
        await db.close();
        final failingDb = _FailingLinksJournalDb();
        final failure = StateError('simulated');
        failingDb.failure = failure;
        await initConfigFlags(failingDb, inMemoryDatabase: true);
        addTearDown(failingDb.close);

        final futures = [
          failingDb.basicLinksForEntryIds({'a'}),
          failingDb.basicLinksForEntryIds({'b'}),
        ];

        // Register expectLater on every future before awaiting: the
        // coalesced wave completes both with the same error in one
        // microtask, so a sequential `await` would leave the second
        // future briefly unhandled.
        await Future.wait([
          for (final f in futures) expectLater(f, throwsA(same(failure))),
        ]);
        expect(failingDb.attempts, 1);
      },
    );
  });
}

/// Subclass whose `runBasicLinksQueryForIds` throws, so the coalescer's
/// error-propagation branch can be covered deterministically.
class _FailingLinksJournalDb extends JournalDb {
  _FailingLinksJournalDb()
    : super(inMemoryDatabase: true, background: false, readPool: 0);

  Object failure = StateError('not set');
  int attempts = 0;

  @override
  Future<List<EntryLink>> runBasicLinksQueryForIds(Set<String> ids) {
    attempts += 1;
    return Future<List<EntryLink>>.error(failure);
  }
}
