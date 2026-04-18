// ignore_for_file: avoid_redundant_argument_values
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

/// Subclass of [JournalDb] whose `runTasksDueFetch` throws, so the
/// coalescer's error-propagation branch can be exercised deterministically.
class _FailingTasksDueJournalDb extends JournalDb {
  _FailingTasksDueJournalDb()
    : super(inMemoryDatabase: true, background: false, readPool: 0);

  Object failure = StateError('not set');
  int attempts = 0;

  @override
  Future<List<Task>> runTasksDueFetch({
    required DateTime endInclusive,
    required List<bool> privateStatuses,
  }) {
    attempts += 1;
    return Future<List<Task>>.error(failure);
  }
}

/// Subclass of [JournalDb] that counts `customSelect` invocations whose
/// raw SQL pins the partial open-task due-date index. The coalescer flushes
/// the whole wave through that one statement, so the counter equals the
/// number of DB round-trips for due-task fetches.
class _CountingJournalDb extends JournalDb {
  _CountingJournalDb()
    : super(inMemoryDatabase: true, background: false, readPool: 0);

  int tasksDueQueryCount = 0;

  @override
  drift.Selectable<drift.QueryRow> customSelect(
    String query, {
    List<drift.Variable<Object>> variables = const [],
    Set<drift.ResultSetImplementation<dynamic, dynamic>> readsFrom = const {},
  }) {
    if (query.contains('INDEXED BY idx_journal_tasks_due_open')) {
      tasksDueQueryCount += 1;
    }
    return super.customSelect(
      query,
      variables: variables,
      readsFrom: readsFrom,
    );
  }
}

Task makeTask({
  required String id,
  required DateTime due,
  TaskStatus? status,
}) {
  final createdAt = due.subtract(const Duration(days: 1));
  return Task(
    meta: Metadata(
      id: id,
      createdAt: createdAt,
      updatedAt: createdAt,
      dateFrom: due,
      dateTo: due,
    ),
    data: TaskData(
      status:
          status ??
          TaskStatus.open(
            id: '$id-status',
            createdAt: createdAt,
            utcOffset: 0,
          ),
      dateFrom: due,
      dateTo: due,
      statusHistory: const [],
      title: id,
      due: due,
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
    testDirectory = Directory.systemTemp.createTempSync('lotti_due_coalesce_');
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

  Future<void> insertTask(Task task) async {
    await db.upsertJournalDbEntity(toDbEntity(task));
  }

  group('tasks-due microtask coalescing', () {
    test(
      'three concurrent getTasksDueOnOrBefore calls share one DB query '
      'and each returns the correct filtered subset',
      () async {
        final t1 = makeTask(id: 't1', due: DateTime(2026, 4, 10));
        final t2 = makeTask(id: 't2', due: DateTime(2026, 4, 12));
        final t3 = makeTask(id: 't3', due: DateTime(2026, 4, 15));
        await insertTask(t1);
        await insertTask(t2);
        await insertTask(t3);
        db.tasksDueQueryCount = 0;

        final futures = [
          db.getTasksDueOnOrBefore(DateTime(2026, 4, 10)),
          db.getTasksDueOnOrBefore(DateTime(2026, 4, 12)),
          db.getTasksDueOnOrBefore(DateTime(2026, 4, 15)),
        ];
        final results = await Future.wait(futures);

        expect(results[0].map((t) => t.meta.id), ['t1']);
        expect(results[1].map((t) => t.meta.id).toSet(), {'t1', 't2'});
        expect(results[2].map((t) => t.meta.id).toSet(), {'t1', 't2', 't3'});
        expect(db.tasksDueQueryCount, 1);
      },
    );

    test(
      'mixed getTasksDueOn + getTasksDueOnOrBefore in the same wave hits '
      'the DB once and filters each range correctly',
      () async {
        final past = makeTask(id: 'past', due: DateTime(2026, 4, 10));
        final today = makeTask(id: 'today', due: DateTime(2026, 4, 15, 14));
        final future = makeTask(id: 'future', due: DateTime(2026, 4, 20, 10));
        await insertTask(past);
        await insertTask(today);
        await insertTask(future);
        db.tasksDueQueryCount = 0;

        final cumulative = db.getTasksDueOnOrBefore(DateTime(2026, 4, 15));
        final futureDay = db.getTasksDueOn(DateTime(2026, 4, 20));

        final cumulativeResult = await cumulative;
        final futureDayResult = await futureDay;

        expect(cumulativeResult.map((t) => t.meta.id).toSet(), {
          'past',
          'today',
        });
        expect(futureDayResult.map((t) => t.meta.id), ['future']);
        expect(db.tasksDueQueryCount, 1);
      },
    );

    test('distinct microtask waves issue separate queries', () async {
      final t = makeTask(id: 'only', due: DateTime(2026, 4, 10));
      await insertTask(t);
      db.tasksDueQueryCount = 0;

      final first = await db.getTasksDueOnOrBefore(DateTime(2026, 4, 10));
      final second = await db.getTasksDueOnOrBefore(DateTime(2026, 4, 11));

      expect(first.map((t) => t.meta.id), ['only']);
      expect(second.map((t) => t.meta.id), ['only']);
      expect(db.tasksDueQueryCount, 2);
    });

    test('DONE tasks are still excluded after coalescing', () async {
      final open = makeTask(id: 'open', due: DateTime(2026, 4, 10));
      final done = Task(
        meta: Metadata(
          id: 'done',
          createdAt: DateTime(2026, 4, 1),
          updatedAt: DateTime(2026, 4, 1),
          dateFrom: DateTime(2026, 4, 10),
          dateTo: DateTime(2026, 4, 10),
        ),
        data: TaskData(
          status: TaskStatus.done(
            id: 'done-s',
            createdAt: DateTime(2026, 4, 1),
            utcOffset: 0,
          ),
          dateFrom: DateTime(2026, 4, 10),
          dateTo: DateTime(2026, 4, 10),
          statusHistory: const [],
          title: 'done',
          due: DateTime(2026, 4, 10),
        ),
      );
      await insertTask(open);
      await insertTask(done);
      db.tasksDueQueryCount = 0;

      final results = await db.getTasksDueOnOrBefore(DateTime(2026, 4, 10));

      expect(results.map((t) => t.meta.id), ['open']);
    });

    test(
      'query error propagates to every caller waiting on the wave',
      () async {
        await db.close();
        final failingDb = _FailingTasksDueJournalDb()
          ..failure = StateError('simulated');
        await initConfigFlags(failingDb, inMemoryDatabase: true);
        addTearDown(failingDb.close);

        final futures = [
          failingDb.getTasksDueOnOrBefore(DateTime(2026, 4, 10)),
          failingDb.getTasksDueOnOrBefore(DateTime(2026, 4, 12)),
        ];

        // Register expectLater on every future before awaiting: the
        // coalesced wave completes both with the same error in one
        // microtask, so a sequential `await` would leave the second
        // future briefly unhandled.
        await Future.wait([
          for (final f in futures)
            expectLater(f, throwsA(same(failingDb.failure))),
        ]);
        expect(failingDb.attempts, 1);
      },
    );

    test(
      'tasks whose due falls after the caller end-of-day are filtered out',
      () async {
        final tEarly = makeTask(id: 'early', due: DateTime(2026, 4, 10, 8));
        final tLate = makeTask(id: 'late', due: DateTime(2026, 4, 12, 10));
        await insertTask(tEarly);
        await insertTask(tLate);
        db.tasksDueQueryCount = 0;

        // Two concurrent callers share a single query (widest end = 4/12).
        // The caller asking about 4/10 must not see `late`.
        final narrow = db.getTasksDueOnOrBefore(DateTime(2026, 4, 10));
        final wide = db.getTasksDueOnOrBefore(DateTime(2026, 4, 12));

        expect((await narrow).map((t) => t.meta.id), ['early']);
        expect((await wide).map((t) => t.meta.id).toSet(), {'early', 'late'});
        expect(db.tasksDueQueryCount, 1);
      },
    );
  });
}
