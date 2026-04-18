// ignore_for_file: avoid_redundant_argument_values
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

/// Spy subclass that counts `runRatingsForTimeEntriesQueryForIds` calls.
/// The coalescer flushes each wave through exactly one call to this method,
/// so the counter equals the number of DB round-trips.
class _CountingJournalDb extends JournalDb {
  _CountingJournalDb()
    : super(inMemoryDatabase: true, background: false, readPool: 0);

  int ratingsQueryCount = 0;
  Set<String>? lastMergedIds;

  @override
  Future<List<RatingsForTimeEntriesResult>> runRatingsForTimeEntriesQueryForIds(
    Set<String> ids,
  ) {
    ratingsQueryCount += 1;
    lastMergedIds = Set<String>.from(ids);
    return super.runRatingsForTimeEntriesQueryForIds(ids);
  }
}

class _FailingRatingsJournalDb extends JournalDb {
  _FailingRatingsJournalDb()
    : super(inMemoryDatabase: true, background: false, readPool: 0);

  Object failure = StateError('not set');
  int attempts = 0;

  @override
  Future<List<RatingsForTimeEntriesResult>> runRatingsForTimeEntriesQueryForIds(
    Set<String> ids,
  ) {
    attempts += 1;
    return Future<List<RatingsForTimeEntriesResult>>.error(failure);
  }
}

RatingEntry makeRating({
  required String id,
  required DateTime updatedAt,
  String catalogId = 'session',
}) {
  return RatingEntry(
    meta: Metadata(
      id: id,
      createdAt: updatedAt,
      updatedAt: updatedAt,
      dateFrom: updatedAt,
      dateTo: updatedAt,
    ),
    data: RatingData(
      targetId: 'te-$id',
      catalogId: catalogId,
      dimensions: const [],
    ),
  );
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
      'lotti_ratings_coalesce_',
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

  Future<void> insertRatingLink({
    required String ratingId,
    required String timeEntryId,
    required DateTime ratingUpdatedAt,
  }) async {
    await db.upsertJournalDbEntity(
      toDbEntity(
        makeRating(id: ratingId, updatedAt: ratingUpdatedAt),
      ),
    );
    final link = EntryLink.rating(
      id: 'rlink-$ratingId-$timeEntryId',
      fromId: ratingId,
      toId: timeEntryId,
      createdAt: ratingUpdatedAt,
      updatedAt: ratingUpdatedAt,
      vectorClock: null,
    );
    await db.upsertEntryLink(link);
  }

  group('getRatingIdsForTimeEntries microtask coalescing', () {
    test(
      'two concurrent callers share one DB query; each receives only its '
      'own subset mapped to the rating id',
      () async {
        await insertRatingLink(
          ratingId: 'r1',
          timeEntryId: 'te-A',
          ratingUpdatedAt: DateTime(2026, 4, 1),
        );
        await insertRatingLink(
          ratingId: 'r2',
          timeEntryId: 'te-B',
          ratingUpdatedAt: DateTime(2026, 4, 2),
        );
        await insertRatingLink(
          ratingId: 'r3',
          timeEntryId: 'te-C',
          ratingUpdatedAt: DateTime(2026, 4, 3),
        );
        db.ratingsQueryCount = 0;

        final futureA = db.getRatingIdsForTimeEntries({'te-A'});
        final futureBC = db.getRatingIdsForTimeEntries({'te-B', 'te-C'});

        final resultA = await futureA;
        final resultBC = await futureBC;

        expect(resultA, {'te-A': 'r1'});
        expect(resultBC, {'te-B': 'r2', 'te-C': 'r3'});
        expect(db.ratingsQueryCount, 1);
        expect(db.lastMergedIds, {'te-A', 'te-B', 'te-C'});
      },
    );

    test('empty id set short-circuits without issuing a query', () async {
      final result = await db.getRatingIdsForTimeEntries(const <String>{});
      expect(result, isEmpty);
      expect(db.ratingsQueryCount, 0);
    });

    test('distinct microtask waves issue separate queries', () async {
      await insertRatingLink(
        ratingId: 'r1',
        timeEntryId: 'te-A',
        ratingUpdatedAt: DateTime(2026, 4, 1),
      );
      db.ratingsQueryCount = 0;

      final first = await db.getRatingIdsForTimeEntries({'te-A'});
      final second = await db.getRatingIdsForTimeEntries({'te-A'});

      expect(first, {'te-A': 'r1'});
      expect(second, {'te-A': 'r1'});
      expect(db.ratingsQueryCount, 2);
    });

    test(
      'last-write-wins: when multiple ratings link to one time entry the '
      'most recently updated rating id is returned',
      () async {
        await insertRatingLink(
          ratingId: 'older',
          timeEntryId: 'te-A',
          ratingUpdatedAt: DateTime(2026, 4, 1),
        );
        await insertRatingLink(
          ratingId: 'newer',
          timeEntryId: 'te-A',
          ratingUpdatedAt: DateTime(2026, 4, 10),
        );
        db.ratingsQueryCount = 0;

        final result = await db.getRatingIdsForTimeEntries({'te-A'});

        expect(result, {'te-A': 'newer'});
        expect(db.ratingsQueryCount, 1);
      },
    );

    test(
      'query error propagates to every caller waiting on the wave',
      () async {
        await db.close();
        final failingDb = _FailingRatingsJournalDb()
          ..failure = StateError('simulated');
        await initConfigFlags(failingDb, inMemoryDatabase: true);
        addTearDown(failingDb.close);

        final futures = [
          failingDb.getRatingIdsForTimeEntries({'te-A'}),
          failingDb.getRatingIdsForTimeEntries({'te-B'}),
        ];

        for (final f in futures) {
          await expectLater(f, throwsA(same(failingDb.failure)));
        }
        expect(failingDb.attempts, 1);
      },
    );

    test(
      "rows outside a caller's id set do not leak into its result map",
      () async {
        await insertRatingLink(
          ratingId: 'r1',
          timeEntryId: 'te-A',
          ratingUpdatedAt: DateTime(2026, 4, 1),
        );
        await insertRatingLink(
          ratingId: 'r2',
          timeEntryId: 'te-B',
          ratingUpdatedAt: DateTime(2026, 4, 2),
        );
        db.ratingsQueryCount = 0;

        // Two callers share a wave. The first must only see te-A even
        // though the DB returned both te-A and te-B to the merged query.
        final narrow = db.getRatingIdsForTimeEntries({'te-A'});
        final wide = db.getRatingIdsForTimeEntries({'te-A', 'te-B'});

        expect(await narrow, {'te-A': 'r1'});
        expect(await wide, {'te-A': 'r1', 'te-B': 'r2'});
        expect(db.ratingsQueryCount, 1);
      },
    );
  });
}
