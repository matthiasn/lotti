// ignore_for_file: avoid_redundant_argument_values
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

DayPlanEntry makePlan(DateTime date) {
  return DayPlanEntry(
    meta: Metadata(
      id: dayPlanId(date),
      createdAt: date,
      updatedAt: date,
      dateFrom: date,
      dateTo: date.add(const Duration(days: 1)),
    ),
    data: DayPlanData(
      planDate: date,
      status: const DayPlanStatus.draft(),
      plannedBlocks: const [],
    ),
  );
}

RatingEntry makeRating({
  required String id,
  required DateTime updatedAt,
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
      catalogId: 'session',
      dimensions: const [],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late JournalDb db;
  late MockLoggingService loggingService;
  Directory? testDirectory;
  Directory? previousDirectory;
  LoggingService? previousLoggingService;

  setUp(() async {
    if (getIt.isRegistered<Directory>()) {
      previousDirectory = getIt<Directory>();
      getIt.unregister<Directory>();
    }
    testDirectory = Directory.systemTemp.createTempSync('lotti_chunking_');
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
      previousLoggingService = getIt<LoggingService>();
      getIt.unregister<LoggingService>();
    } else {
      previousLoggingService = null;
    }
    getIt.registerSingleton<LoggingService>(loggingService);

    db = JournalDb(
      inMemoryDatabase: true,
      background: false,
      readPool: 0,
    );
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
    if (previousLoggingService != null) {
      getIt.registerSingleton<LoggingService>(previousLoggingService!);
    }
    getIt.unregister<Directory>();
    if (previousDirectory != null) {
      getIt.registerSingleton<Directory>(previousDirectory!);
    }
    if (testDirectory != null && testDirectory!.existsSync()) {
      testDirectory!.deleteSync(recursive: true);
    }
  });

  group('getDayPlansByIds', () {
    test('returns empty list for empty input without hitting the DB', () async {
      final result = await db.getDayPlansByIds(const <String>[]);
      expect(result, isEmpty);
    });

    test('returns the matching rows for a small id set', () async {
      final d1 = DateTime(2026, 4, 1);
      final d2 = DateTime(2026, 4, 2);
      final d3 = DateTime(2026, 4, 3);
      await db.upsertJournalDbEntity(toDbEntity(makePlan(d1)));
      await db.upsertJournalDbEntity(toDbEntity(makePlan(d2)));
      await db.upsertJournalDbEntity(toDbEntity(makePlan(d3)));

      final result = await db.getDayPlansByIds({
        dayPlanId(d1),
        dayPlanId(d3),
      });

      expect(result.map((p) => p.meta.id).toSet(), {
        dayPlanId(d1),
        dayPlanId(d3),
      });
    });

    test(
      'deduplicates input ids so chunked queries do not return duplicate rows',
      () async {
        final d = DateTime(2026, 4, 10);
        await db.upsertJournalDbEntity(toDbEntity(makePlan(d)));

        // Caller fans duplicates through an Iterable — a Set-backed input
        // would dedupe up front, but getDayPlansByIds must guard against
        // List-shaped callers too.
        final result = await db.getDayPlansByIds([
          dayPlanId(d),
          dayPlanId(d),
          dayPlanId(d),
        ]);

        expect(result.map((p) => p.meta.id), [dayPlanId(d)]);
      },
    );

    test(
      'excludes private plans when the private flag is off (filtered path)',
      () async {
        // Drop the private flag so `_queryWithPrivateFilter` routes through
        // the `filtered:` branch and uses `dayPlansByIdsByPrivateStatuses`
        // instead of the all-private fast path.
        final privateConfig = await db.getConfigFlagByName(privateFlag);
        await db.upsertConfigFlag(privateConfig!.copyWith(status: false));

        final publicDate = DateTime(2026, 5, 1);
        final privateDate = DateTime(2026, 5, 2);
        final publicPlan = makePlan(publicDate);
        final privatePlan = makePlan(privateDate).copyWith(
          meta: makePlan(privateDate).meta.copyWith(private: true),
        );
        await db.upsertJournalDbEntity(toDbEntity(publicPlan));
        await db.upsertJournalDbEntity(toDbEntity(privatePlan));

        final result = await db.getDayPlansByIds({
          dayPlanId(publicDate),
          dayPlanId(privateDate),
        });

        expect(result.map((p) => p.meta.id), [dayPlanId(publicDate)]);
      },
    );

    test('chunks across the 500-id boundary and returns every match', () async {
      // 1,200 dates → 3 chunks (500 + 500 + 200). Of those 1,200 ids, only
      // 3 actually exist in the DB; the others are unmatched. Every stored
      // row must be returned exactly once across the combined output.
      final base = DateTime(2026, 1, 1);
      final stored = [
        0,
        600,
        1100,
      ].map((offset) => base.add(Duration(days: offset))).toList();
      for (final d in stored) {
        await db.upsertJournalDbEntity(toDbEntity(makePlan(d)));
      }

      final ids = <String>[
        for (var i = 0; i < 1200; i++) dayPlanId(base.add(Duration(days: i))),
      ];

      final result = await db.getDayPlansByIds(ids);

      expect(
        result.map((p) => p.meta.id).toSet(),
        stored.map(dayPlanId).toSet(),
      );
    });
  });

  group('runRatingsForTimeEntriesQueryForIds chunking', () {
    test(
      'a sub-500 id set hits the fast path and returns the stored rating id',
      () async {
        final updatedAt = DateTime(2026, 4, 1);
        await db.upsertJournalDbEntity(
          toDbEntity(makeRating(id: 'r1', updatedAt: updatedAt)),
        );
        await db.upsertEntryLink(
          EntryLink.rating(
            id: 'rlink-r1',
            fromId: 'r1',
            toId: 'te-A',
            createdAt: updatedAt,
            updatedAt: updatedAt,
            vectorClock: null,
          ),
        );

        final rows = await db.runRatingsForTimeEntriesQueryForIds({'te-A'});

        expect(rows, hasLength(1));
        expect(rows.single.timeEntryId, 'te-A');
        expect(rows.single.ratingId, 'r1');
      },
    );

    test(
      'a >500 id set exercises the chunk loop and still returns every match',
      () async {
        // Three real rating links seeded at positions that land in three
        // different 500-id chunks of a 1,200-id request (indexes 0, 600,
        // 1100). The combined loop must concatenate rows from each chunk.
        final updatedAt = DateTime(2026, 4, 1);
        for (final idx in [0, 600, 1100]) {
          await db.upsertJournalDbEntity(
            toDbEntity(
              makeRating(
                id: 'r-$idx',
                updatedAt: updatedAt.add(Duration(minutes: idx)),
              ),
            ),
          );
          await db.upsertEntryLink(
            EntryLink.rating(
              id: 'rlink-$idx',
              fromId: 'r-$idx',
              toId: 'te-$idx',
              createdAt: updatedAt,
              updatedAt: updatedAt,
              vectorClock: null,
            ),
          );
        }

        final ids = <String>{for (var i = 0; i < 1200; i++) 'te-$i'};

        final rows = await db.runRatingsForTimeEntriesQueryForIds(ids);

        expect(rows.map((r) => r.timeEntryId).toSet(), {
          'te-0',
          'te-600',
          'te-1100',
        });
        expect(
          rows.map((r) => r.ratingId).toSet(),
          {'r-0', 'r-600', 'r-1100'},
        );
      },
    );
  });
}
