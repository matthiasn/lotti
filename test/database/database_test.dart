// ignore_for_file: avoid_redundant_argument_values
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';
import '../test_data/test_data.dart';

// Setup a temp directory for testing
Directory setupTestDirectory() {
  final directory = Directory.systemTemp.createTempSync('lotti_test_');
  return directory;
}

final Set<String> expectedActiveFlagNames = {
  privateFlag,
  enableTooltipFlag,
  enableAiStreamingFlag,
  logAgentRuntimeFlag,
  logAgentWorkflowFlag,
  enableWhatsNewFlag,
};

final expectedFlags = <ConfigFlag>{
  const ConfigFlag(
    name: privateFlag,
    description: 'Show private entries?',
    status: true,
  ),
  const ConfigFlag(
    name: recordLocationFlag,
    description: 'Record geolocation?',
    status: false,
  ),
  // enableSyncFlag removed; enableMatrixFlag is the source of truth for sync visibility
  const ConfigFlag(
    name: enableMatrixFlag,
    description: 'Enable Matrix Sync',
    status: false,
  ),
  const ConfigFlag(
    name: enableTooltipFlag,
    description: 'Enable Tooltips',
    status: true,
  ),
  const ConfigFlag(
    name: enableAiStreamingFlag,
    description: 'Enable AI streaming responses?',
    status: true,
  ),
  const ConfigFlag(
    name: resendAttachments,
    description: 'Resend Attachments',
    status: false,
  ),
  const ConfigFlag(
    name: enableLoggingFlag,
    description: 'Enable logging?',
    status: false,
  ),
  const ConfigFlag(
    name: enableHabitsPageFlag,
    description: 'Enable Habits Page?',
    status: false,
  ),
  const ConfigFlag(
    name: enableDashboardsPageFlag,
    description: 'Enable Dashboards Page?',
    status: false,
  ),
  const ConfigFlag(
    name: enableNotificationsFlag,
    description: 'Enable notifications?',
    status: false,
  ),
  const ConfigFlag(
    name: enableEventsFlag,
    description: 'Enable Events?',
    status: false,
  ),
  const ConfigFlag(
    name: enableDailyOsPageFlag,
    description: 'Enable DailyOS Page?',
    status: false,
  ),
  const ConfigFlag(
    name: enableSessionRatingsFlag,
    description: 'Enable session ratings?',
    status: false,
  ),
  const ConfigFlag(
    name: enableSyncActorFlag,
    description: 'Enable Sync Actor (isolate-based sync)?',
    status: false,
  ),
  const ConfigFlag(
    name: enableAgentsFlag,
    description: 'Enable Agents?',
    status: false,
  ),
  const ConfigFlag(
    name: enableProjectsFlag,
    description: 'Enable Projects?',
    status: false,
  ),
  const ConfigFlag(
    name: enableTasksRedesignFlag,
    description: 'Enable Tasks redesign?',
    status: false,
  ),
  const ConfigFlag(
    name: logAgentRuntimeFlag,
    description: 'Log agent runtime (wake orchestrator)',
    status: true,
  ),
  const ConfigFlag(
    name: logAgentWorkflowFlag,
    description: 'Log agent workflow execution',
    status: true,
  ),
  const ConfigFlag(
    name: logSyncFlag,
    description: 'Log sync operations',
    status: false,
  ),
  const ConfigFlag(
    name: logSlowQueriesFlag,
    description: 'Log slow database queries',
    status: false,
  ),
  const ConfigFlag(
    name: enableEmbeddingsFlag,
    description: 'Generate embeddings for entries?',
    status: false,
  ),
  const ConfigFlag(
    name: enableVectorSearchFlag,
    description: 'Enable vector search UI?',
    status: false,
  ),
  const ConfigFlag(
    name: enableWhatsNewFlag,
    description: "Enable What's New feature?",
    status: true,
  ),
};

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(const Stream<Set<String>>.empty());
    registerFallbackValue(fallbackJournalEntity);
    registerFallbackValue(
      EntryLink.basic(
        id: 'link-id',
        fromId: 'from',
        toId: 'to',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      ),
    );
    registerFallbackValue(measurableWater);
    registerFallbackValue(fallbackAiConfig);
    registerFallbackValue(Uri.parse('mxc://placeholder'));
  });

  JournalDb? db;
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockLoggingService = MockLoggingService();
  late Directory testDirectory;

  group('Database Tests - ', () {
    setUp(() async {
      // Create a real temporary directory for testing
      testDirectory = setupTestDirectory();

      reset(mockLoggingService);

      // Register services
      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<LoggingService>(mockLoggingService)
        ..registerSingleton<Directory>(testDirectory);

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(
        () => mockLoggingService.captureEvent(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
        ),
      ).thenAnswer((_) => Future<void>.value());

      when(
        () => mockLoggingService.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) async {});

      db = JournalDb(inMemoryDatabase: true);
      await initConfigFlags(db!, inMemoryDatabase: true);
    });

    group('JSON persistence -', () {
      test(
        'does not rewrite JSON when update skipped by vector clock',
        () async {
          const freshClock = VectorClock(<String, int>{'device1': 2});
          const staleClock = VectorClock(<String, int>{'device1': 1});
          final freshEntry = createJournalEntryWithVclock(freshClock).copyWith(
            entryText: const EntryText(plainText: 'fresh text'),
          );
          await db!.updateJournalEntity(freshEntry);

          final docDir = getIt<Directory>();
          final savedPath = entityPath(freshEntry, docDir);
          final file = File(savedPath);
          final beforeJson = await file.readAsString();

          final staleEntry =
              createJournalEntryWithVclock(
                staleClock,
                id: freshEntry.meta.id,
              ).copyWith(
                entryText: const EntryText(plainText: 'stale text'),
              );

          final result = await db!.updateJournalEntity(staleEntry);
          expect(result.applied, isFalse);
          expect(result.skipReason, JournalUpdateSkipReason.olderOrEqual);

          final savedEntity = JournalEntity.fromJson(
            jsonDecode(await file.readAsString()) as Map<String, dynamic>,
          );
          expect(savedEntity.entryText?.plainText, 'fresh text');
          expect(savedEntity.meta.vectorClock, freshClock);
          expect(await file.readAsString(), beforeJson);
        },
      );

      test(
        'does not rewrite JSON when update prevented by overwrite=false',
        () async {
          final entry = createJournalEntry('original text');
          await db!.updateJournalEntity(entry);

          final docDir = getIt<Directory>();
          final savedPath = entityPath(entry, docDir);
          final file = File(savedPath);
          final beforeJson = await file.readAsString();

          final updated = entry.copyWith(
            entryText: const EntryText(plainText: 'overwrite prevented'),
          );

          final result = await db!.updateJournalEntity(
            updated,
            overwrite: false,
          );

          expect(result.applied, isFalse);
          expect(result.skipReason, JournalUpdateSkipReason.overwritePrevented);
          final savedEntity = JournalEntity.fromJson(
            jsonDecode(await file.readAsString()) as Map<String, dynamic>,
          );
          expect(savedEntity.entryText?.plainText, 'original text');
          expect(await file.readAsString(), beforeJson);
        },
      );
    });

    group('Edge cases -', () {
      test(
        'journalEntityById returns new data after an initial cache miss',
        () async {
          final entry = buildJournalEntry(
            id: 'cache-miss-then-insert',
            timestamp: DateTime(2024, 4, 1, 10),
            text: 'Seeded after miss',
          );

          expect(await db!.journalEntityById(entry.meta.id), isNull);

          await db!.upsertJournalDbEntity(toDbEntity(entry));

          final retrieved = await db!.journalEntityById(entry.meta.id);
          expect(retrieved?.meta.id, entry.meta.id);
          expect(retrieved?.entryText?.plainText, 'Seeded after miss');
        },
      );

      test('handles null vector clock on incoming entity', () async {
        const existingClock = VectorClock(<String, int>{'device1': 1});
        final existing = createJournalEntryWithVclock(existingClock);
        await db!.updateJournalEntity(existing);

        final update = existing.copyWith(
          entryText: const EntryText(plainText: 'null vector clock update'),
          meta: existing.meta.copyWith(vectorClock: null),
        );

        final result = await db!.updateJournalEntity(update);

        expect(result.applied, isTrue);
        final stored = await db!.journalEntityById(existing.meta.id);
        expect(stored, isNotNull);
        expect(stored?.entryText?.plainText, 'null vector clock update');
        expect(stored?.meta.vectorClock, isNull);
      });

      test('returns skipReason when detectConflict throws', () async {
        final throwingDb = _DetectConflictThrowsJournalDb();
        await initConfigFlags(throwingDb, inMemoryDatabase: true);

        try {
          const existingClock = VectorClock(<String, int>{'device1': 1});
          const incomingClock = VectorClock(<String, int>{'device1': 2});
          final existing = createJournalEntryWithVclock(existingClock);
          await throwingDb.updateJournalEntity(existing);

          throwingDb.shouldThrowOnDetectConflict = true;
          final incoming = createJournalEntryWithVclock(
            incomingClock,
            id: existing.meta.id,
          );

          clearInteractions(mockLoggingService);
          final result = await throwingDb.updateJournalEntity(incoming);

          expect(result.applied, isFalse);
          expect(result.skipReason, JournalUpdateSkipReason.conflict);
          verify(
            () => mockLoggingService.captureException(
              any<Object>(),
              domain: 'JOURNAL_DB',
              subDomain: 'detectConflict',
              stackTrace: any<StackTrace>(named: 'stackTrace'),
            ),
          ).called(1);
        } finally {
          await throwingDb.close();
        }
      });
    });

    group('Journal queries -', () {
      test('getJournalEntities filters by types', () async {
        final base = DateTime(2024);
        final textEntry = buildJournalEntry(
          id: 'journal-type-text',
          timestamp: base,
          text: 'Entry text',
        );
        final taskTimestamp = base.add(const Duration(minutes: 1));
        final taskEntry = buildTaskEntry(
          id: 'journal-type-task',
          timestamp: taskTimestamp,
          status: TaskStatus.open(
            id: 'type-task-status',
            createdAt: taskTimestamp,
            utcOffset: taskTimestamp.timeZoneOffset.inMinutes,
          ),
        );

        await db!.upsertJournalDbEntity(toDbEntity(textEntry));
        await db!.upsertJournalDbEntity(toDbEntity(taskEntry));

        final results = await fetchJournalEntities(
          db!,
          types: const ['Task'],
          starredStatuses: const [true, false],
          privateStatuses: const [true, false],
          flaggedStatuses: [
            EntryFlag.none.index,
            EntryFlag.followUpNeeded.index,
          ],
        );

        expect(results.map((e) => e.meta.id), [taskEntry.meta.id]);
      });

      test('getJournalEntities filters by starred status', () async {
        final base = DateTime(2024, 2);
        final starredEntry = buildJournalEntry(
          id: 'starred',
          timestamp: base,
          text: 'starred',
          starred: true,
        );
        final regularEntry = buildJournalEntry(
          id: 'not-starred',
          timestamp: base.add(const Duration(minutes: 1)),
          text: 'not starred',
        );

        await db!.upsertJournalDbEntity(toDbEntity(starredEntry));
        await db!.upsertJournalDbEntity(toDbEntity(regularEntry));

        final results = await fetchJournalEntities(
          db!,
          types: const ['JournalEntry'],
          starredStatuses: const [true],
          privateStatuses: const [true, false],
          flaggedStatuses: [
            EntryFlag.none.index,
            EntryFlag.followUpNeeded.index,
          ],
        );

        expect(results.map((e) => e.meta.id), [starredEntry.meta.id]);
      });

      test('getJournalEntities filters by private status', () async {
        final base = DateTime(2024, 3);
        final privateEntry = buildJournalEntry(
          id: 'private',
          timestamp: base,
          text: 'private',
          privateFlag: true,
        );
        final publicEntry = buildJournalEntry(
          id: 'public',
          timestamp: base.add(const Duration(minutes: 1)),
          text: 'public',
        );

        await db!.upsertJournalDbEntity(toDbEntity(privateEntry));
        await db!.upsertJournalDbEntity(toDbEntity(publicEntry));

        final results = await fetchJournalEntities(
          db!,
          types: const ['JournalEntry'],
          starredStatuses: const [true, false],
          privateStatuses: const [true],
          flaggedStatuses: [
            EntryFlag.none.index,
            EntryFlag.followUpNeeded.index,
          ],
        );

        expect(results.map((e) => e.meta.id), [privateEntry.meta.id]);
      });

      test('getJournalEntities filters by flag', () async {
        final base = DateTime(2024, 4);
        final flaggedEntry = buildJournalEntry(
          id: 'flagged',
          timestamp: base,
          text: 'flagged',
          flag: EntryFlag.followUpNeeded,
        );
        final normalEntry = buildJournalEntry(
          id: 'normal',
          timestamp: base.add(const Duration(minutes: 1)),
          text: 'normal',
        );

        await db!.upsertJournalDbEntity(toDbEntity(flaggedEntry));
        await db!.upsertJournalDbEntity(toDbEntity(normalEntry));

        final results = await fetchJournalEntities(
          db!,
          types: const ['JournalEntry'],
          starredStatuses: const [true, false],
          privateStatuses: const [true, false],
          flaggedStatuses: [EntryFlag.followUpNeeded.index],
        );

        expect(results.map((e) => e.meta.id), [flaggedEntry.meta.id]);
      });

      test('getJournalEntities filters by category ids', () async {
        final base = DateTime(2024, 5);
        final categoryEntry = buildJournalEntry(
          id: 'cat-entry',
          timestamp: base,
          text: 'cat-entry',
          categoryId: 'category-1',
        );
        final otherEntry = buildJournalEntry(
          id: 'other',
          timestamp: base.add(const Duration(minutes: 1)),
          text: 'other',
          categoryId: 'category-2',
        );

        await db!.upsertJournalDbEntity(toDbEntity(categoryEntry));
        await db!.upsertJournalDbEntity(toDbEntity(otherEntry));

        final results = await fetchJournalEntities(
          db!,
          types: const ['JournalEntry'],
          starredStatuses: const [true, false],
          privateStatuses: const [true, false],
          flaggedStatuses: [
            EntryFlag.none.index,
            EntryFlag.followUpNeeded.index,
          ],
          categoryIds: {'category-1'},
        );

        expect(results.map((e) => e.meta.id), [categoryEntry.meta.id]);
      });

      test('getJournalEntities filters by explicit ids', () async {
        final base = DateTime(2024, 6);
        final entryA = buildJournalEntry(
          id: 'id-A',
          timestamp: base,
          text: 'A',
        );
        final entryB = buildJournalEntry(
          id: 'id-B',
          timestamp: base.add(const Duration(minutes: 1)),
          text: 'B',
        );

        await db!.upsertJournalDbEntity(toDbEntity(entryA));
        await db!.upsertJournalDbEntity(toDbEntity(entryB));

        final results = await fetchJournalEntities(
          db!,
          types: const ['JournalEntry'],
          starredStatuses: const [true, false],
          privateStatuses: const [true, false],
          flaggedStatuses: [
            EntryFlag.none.index,
            EntryFlag.followUpNeeded.index,
          ],
          ids: const ['id-B'],
        );

        expect(results.map((e) => e.meta.id), [entryB.meta.id]);
      });
    });

    group('Task queries -', () {
      test('getTasks filters by status and category', () async {
        final base = DateTime(2024, 7, 1, 8);
        final inProgressTask = buildTaskEntry(
          id: 'task-in-progress',
          timestamp: base,
          status: TaskStatus.inProgress(
            id: 'status-in-progress',
            createdAt: base,
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-1',
        );
        final doneTask = buildTaskEntry(
          id: 'task-done',
          timestamp: base.add(const Duration(minutes: 5)),
          status: TaskStatus.done(
            id: 'status-done',
            createdAt: base.add(const Duration(minutes: 5)),
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-1',
        );
        final otherCatTask = buildTaskEntry(
          id: 'task-other-cat',
          timestamp: base.add(const Duration(minutes: 10)),
          status: TaskStatus.inProgress(
            id: 'status-in-progress-2',
            createdAt: base.add(const Duration(minutes: 10)),
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-2',
        );

        await db!.upsertJournalDbEntity(toDbEntity(inProgressTask));
        await db!.upsertJournalDbEntity(toDbEntity(doneTask));
        await db!.upsertJournalDbEntity(toDbEntity(otherCatTask));

        final results = await db!.getTasks(
          starredStatuses: const [true, false],
          taskStatuses: const ['IN PROGRESS'],
          categoryIds: const ['cat-1'],
        );

        expect(results.map((e) => e.meta.id), ['task-in-progress']);
      });

      test('getTasks filters by explicit ids', () async {
        final base = DateTime(2024, 7, 2, 9);
        final openTask = buildTaskEntry(
          id: 'task-open',
          timestamp: base,
          status: TaskStatus.open(
            id: 'status-open',
            createdAt: base,
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-3',
        );
        final blockedTask = buildTaskEntry(
          id: 'task-blocked',
          timestamp: base.add(const Duration(minutes: 5)),
          status: TaskStatus.blocked(
            id: 'status-blocked',
            createdAt: base.add(const Duration(minutes: 5)),
            utcOffset: base.timeZoneOffset.inMinutes,
            reason: 'Blocked',
          ),
          categoryId: 'cat-3',
        );

        await db!.upsertJournalDbEntity(toDbEntity(openTask));
        await db!.upsertJournalDbEntity(toDbEntity(blockedTask));

        final results = await db!.getTasks(
          starredStatuses: const [true, false],
          taskStatuses: const ['BLOCKED'],
          categoryIds: const ['cat-3'],
          ids: const ['task-blocked'],
        );

        expect(results.map((e) => e.meta.id), ['task-blocked']);
      });

      test('getWipCount counts tasks with IN PROGRESS status', () async {
        final base = DateTime(2024, 7, 3, 10);
        final inProgressA = buildTaskEntry(
          id: 'wip-A',
          timestamp: base,
          status: TaskStatus.inProgress(
            id: 'wip-status-a',
            createdAt: base,
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
        );
        final inProgressB = buildTaskEntry(
          id: 'wip-B',
          timestamp: base.add(const Duration(minutes: 5)),
          status: TaskStatus.inProgress(
            id: 'wip-status-b',
            createdAt: base.add(const Duration(minutes: 5)),
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
        );
        final doneTask = buildTaskEntry(
          id: 'wip-done',
          timestamp: base.add(const Duration(minutes: 10)),
          status: TaskStatus.done(
            id: 'wip-status-done',
            createdAt: base.add(const Duration(minutes: 10)),
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
        );

        await db!.upsertJournalDbEntity(toDbEntity(inProgressA));
        await db!.upsertJournalDbEntity(toDbEntity(inProgressB));
        await db!.upsertJournalDbEntity(toDbEntity(doneTask));

        expect(await db!.getWipCount(), 2);
      });

      test('getTasks filters by priorities', () async {
        final base = DateTime(2024, 7, 4, 11);
        final p0 = JournalEntity.task(
          meta: Metadata(
            id: 'prio-0',
            createdAt: base,
            updatedAt: base,
            dateFrom: base,
            dateTo: base,
          ),
          data: testTask.data.copyWith(
            status: TaskStatus.open(
              id: 's0',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            dateFrom: base,
            dateTo: base,
            title: 'P0',
            priority: TaskPriority.p0Urgent,
          ),
          entryText: const EntryText(plainText: 'prio 0'),
        );
        final p2 = JournalEntity.task(
          meta: Metadata(
            id: 'prio-2',
            createdAt: base,
            updatedAt: base,
            dateFrom: base,
            dateTo: base,
          ),
          data: testTask.data.copyWith(
            status: TaskStatus.open(
              id: 's2',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            dateFrom: base,
            dateTo: base,
            title: 'P2',
            priority: TaskPriority.p2Medium,
          ),
          entryText: const EntryText(plainText: 'prio 2'),
        );

        await db!.upsertJournalDbEntity(toDbEntity(p0));
        await db!.upsertJournalDbEntity(toDbEntity(p2));

        final results = await db!.getTasks(
          starredStatuses: const [true, false],
          taskStatuses: const ['OPEN'],
          categoryIds: const [''],
          priorities: const ['P0'],
        );

        expect(results.map((e) => e.meta.id), ['prio-0']);
      });

      test(
        'getTasks returns empty list when no task statuses are selected',
        () async {
          final base = DateTime(2024, 7, 4, 11);
          final task = buildTaskEntry(
            id: 'task-no-status-filter',
            timestamp: base,
            status: TaskStatus.open(
              id: 'no-status-filter-open',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            categoryId: 'cat-1',
          );

          await db!.upsertJournalDbEntity(toDbEntity(task));

          final results = await db!.getTasks(
            starredStatuses: const [true, false],
            taskStatuses: const [],
            categoryIds: const ['cat-1'],
          );

          expect(results, isEmpty);
        },
      );

      test(
        'getTasks returns consistent results and reflects writes',
        () async {
          final base = DateTime(2024, 7, 4, 11);
          final firstTask = buildTaskEntry(
            id: 'cached-task-1',
            timestamp: base,
            status: TaskStatus.open(
              id: 'cached-open-1',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            categoryId: 'cat-cache',
          );

          await db!.upsertJournalDbEntity(toDbEntity(firstTask));

          final firstResults = await db!.getTasks(
            starredStatuses: const [true, false],
            taskStatuses: const ['OPEN'],
            categoryIds: const ['cat-cache'],
            sortByDate: true,
          );
          final secondResults = await db!.getTasks(
            starredStatuses: const [true, false],
            taskStatuses: const ['OPEN'],
            categoryIds: const ['cat-cache'],
            sortByDate: true,
          );

          expect(firstResults.map((e) => e.meta.id), ['cached-task-1']);
          expect(secondResults.map((e) => e.meta.id), ['cached-task-1']);

          final secondTask = buildTaskEntry(
            id: 'cached-task-2',
            timestamp: base.add(const Duration(minutes: 1)),
            status: TaskStatus.open(
              id: 'cached-open-2',
              createdAt: base.add(const Duration(minutes: 1)),
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            categoryId: 'cat-cache',
          );

          await db!.upsertJournalDbEntity(toDbEntity(secondTask));

          final refreshedResults = await db!.getTasks(
            starredStatuses: const [true, false],
            taskStatuses: const ['OPEN'],
            categoryIds: const ['cat-cache'],
            sortByDate: true,
          );

          expect(
            refreshedResults.map((e) => e.meta.id),
            ['cached-task-2', 'cached-task-1'],
          );
        },
      );

      test('getTasks orders by priority rank then date_from desc', () async {
        final base = DateTime(2024, 7, 5, 12);
        final p3older = JournalEntity.task(
          meta: Metadata(
            id: 'older-low',
            createdAt: base,
            updatedAt: base,
            dateFrom: base,
            dateTo: base,
          ),
          data: testTask.data.copyWith(
            status: TaskStatus.open(
              id: 's3',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            dateFrom: base,
            dateTo: base,
            title: 'P3 older',
            priority: TaskPriority.p3Low,
          ),
          entryText: const EntryText(plainText: 'older low'),
        );
        final p1newer = JournalEntity.task(
          meta: Metadata(
            id: 'newer-high',
            createdAt: base.add(const Duration(minutes: 1)),
            updatedAt: base.add(const Duration(minutes: 1)),
            dateFrom: base.add(const Duration(minutes: 1)),
            dateTo: base.add(const Duration(minutes: 1)),
          ),
          data: testTask.data.copyWith(
            status: TaskStatus.open(
              id: 's1',
              createdAt: base.add(const Duration(minutes: 1)),
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            dateFrom: base.add(const Duration(minutes: 1)),
            dateTo: base.add(const Duration(minutes: 1)),
            title: 'P1 newer',
            priority: TaskPriority.p1High,
          ),
          entryText: const EntryText(plainText: 'newer high'),
        );
        final p0newest = JournalEntity.task(
          meta: Metadata(
            id: 'newest-urgent',
            createdAt: base.add(const Duration(minutes: 2)),
            updatedAt: base.add(const Duration(minutes: 2)),
            dateFrom: base.add(const Duration(minutes: 2)),
            dateTo: base.add(const Duration(minutes: 2)),
          ),
          data: testTask.data.copyWith(
            status: TaskStatus.open(
              id: 's0',
              createdAt: base.add(const Duration(minutes: 2)),
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            dateFrom: base.add(const Duration(minutes: 2)),
            dateTo: base.add(const Duration(minutes: 2)),
            title: 'P0 newest',
            priority: TaskPriority.p0Urgent,
          ),
          entryText: const EntryText(plainText: 'newest urgent'),
        );

        await db!.upsertJournalDbEntity(toDbEntity(p3older));
        await db!.upsertJournalDbEntity(toDbEntity(p1newer));
        await db!.upsertJournalDbEntity(toDbEntity(p0newest));

        final results = await db!.getTasks(
          starredStatuses: const [true, false],
          taskStatuses: const ['OPEN'],
          categoryIds: const [''],
        );

        // Order: P0 -> P1 -> P3; within same priority, date_from DESC
        expect(
          results.map((e) => e.meta.id).toList(),
          ['newest-urgent', 'newer-high', 'older-low'],
        );
      });

      test('getTasks with sortByDate orders by date_from desc only', () async {
        final base = DateTime(2024, 7, 5, 12);
        // Create tasks with different priorities and dates
        // When sorting by date, priority should be ignored
        final p3oldest = JournalEntity.task(
          meta: Metadata(
            id: 'oldest-low',
            createdAt: base,
            updatedAt: base,
            dateFrom: base,
            dateTo: base,
          ),
          data: testTask.data.copyWith(
            status: TaskStatus.open(
              id: 's3',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            dateFrom: base,
            dateTo: base,
            title: 'P3 oldest',
            priority: TaskPriority.p3Low,
          ),
          entryText: const EntryText(plainText: 'oldest low'),
        );
        final p0middle = JournalEntity.task(
          meta: Metadata(
            id: 'middle-urgent',
            createdAt: base.add(const Duration(minutes: 1)),
            updatedAt: base.add(const Duration(minutes: 1)),
            dateFrom: base.add(const Duration(minutes: 1)),
            dateTo: base.add(const Duration(minutes: 1)),
          ),
          data: testTask.data.copyWith(
            status: TaskStatus.open(
              id: 's0',
              createdAt: base.add(const Duration(minutes: 1)),
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            dateFrom: base.add(const Duration(minutes: 1)),
            dateTo: base.add(const Duration(minutes: 1)),
            title: 'P0 middle',
            priority: TaskPriority.p0Urgent,
          ),
          entryText: const EntryText(plainText: 'middle urgent'),
        );
        final p1newest = JournalEntity.task(
          meta: Metadata(
            id: 'newest-high',
            createdAt: base.add(const Duration(minutes: 2)),
            updatedAt: base.add(const Duration(minutes: 2)),
            dateFrom: base.add(const Duration(minutes: 2)),
            dateTo: base.add(const Duration(minutes: 2)),
          ),
          data: testTask.data.copyWith(
            status: TaskStatus.open(
              id: 's1',
              createdAt: base.add(const Duration(minutes: 2)),
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            dateFrom: base.add(const Duration(minutes: 2)),
            dateTo: base.add(const Duration(minutes: 2)),
            title: 'P1 newest',
            priority: TaskPriority.p1High,
          ),
          entryText: const EntryText(plainText: 'newest high'),
        );

        await db!.upsertJournalDbEntity(toDbEntity(p3oldest));
        await db!.upsertJournalDbEntity(toDbEntity(p0middle));
        await db!.upsertJournalDbEntity(toDbEntity(p1newest));

        final results = await db!.getTasks(
          starredStatuses: const [true, false],
          taskStatuses: const ['OPEN'],
          categoryIds: const [''],
          sortByDate: true,
        );

        // Order: newest -> middle -> oldest (date_from DESC, ignoring priority)
        // P1 newest (minute 2) > P0 middle (minute 1) > P3 oldest (minute 0)
        expect(
          results.map((e) => e.meta.id).toList(),
          ['newest-high', 'middle-urgent', 'oldest-low'],
        );
      });

      test(
        'getTasks with sortByDate and ids uses filteredTasksByDate2',
        () async {
          final base = DateTime(2024, 7, 5, 12);
          // Create tasks with different priorities and dates
          final p3oldest = JournalEntity.task(
            meta: Metadata(
              id: 'oldest-low',
              createdAt: base,
              updatedAt: base,
              dateFrom: base,
              dateTo: base,
            ),
            data: testTask.data.copyWith(
              status: TaskStatus.open(
                id: 's3',
                createdAt: base,
                utcOffset: base.timeZoneOffset.inMinutes,
              ),
              dateFrom: base,
              dateTo: base,
              title: 'P3 oldest',
              priority: TaskPriority.p3Low,
            ),
            entryText: const EntryText(plainText: 'oldest low'),
          );
          final p0middle = JournalEntity.task(
            meta: Metadata(
              id: 'middle-urgent',
              createdAt: base.add(const Duration(minutes: 1)),
              updatedAt: base.add(const Duration(minutes: 1)),
              dateFrom: base.add(const Duration(minutes: 1)),
              dateTo: base.add(const Duration(minutes: 1)),
            ),
            data: testTask.data.copyWith(
              status: TaskStatus.open(
                id: 's0',
                createdAt: base.add(const Duration(minutes: 1)),
                utcOffset: base.timeZoneOffset.inMinutes,
              ),
              dateFrom: base.add(const Duration(minutes: 1)),
              dateTo: base.add(const Duration(minutes: 1)),
              title: 'P0 middle',
              priority: TaskPriority.p0Urgent,
            ),
            entryText: const EntryText(plainText: 'middle urgent'),
          );
          final p1newest = JournalEntity.task(
            meta: Metadata(
              id: 'newest-high',
              createdAt: base.add(const Duration(minutes: 2)),
              updatedAt: base.add(const Duration(minutes: 2)),
              dateFrom: base.add(const Duration(minutes: 2)),
              dateTo: base.add(const Duration(minutes: 2)),
            ),
            data: testTask.data.copyWith(
              status: TaskStatus.open(
                id: 's1',
                createdAt: base.add(const Duration(minutes: 2)),
                utcOffset: base.timeZoneOffset.inMinutes,
              ),
              dateFrom: base.add(const Duration(minutes: 2)),
              dateTo: base.add(const Duration(minutes: 2)),
              title: 'P1 newest',
              priority: TaskPriority.p1High,
            ),
            entryText: const EntryText(plainText: 'newest high'),
          );

          await db!.upsertJournalDbEntity(toDbEntity(p3oldest));
          await db!.upsertJournalDbEntity(toDbEntity(p0middle));
          await db!.upsertJournalDbEntity(toDbEntity(p1newest));

          // Query with ids filter + sortByDate to exercise filteredTasksByDate2
          final results = await db!.getTasks(
            starredStatuses: const [true, false],
            taskStatuses: const ['OPEN'],
            categoryIds: const [''],
            ids: ['oldest-low', 'newest-high', 'middle-urgent'],
            sortByDate: true,
          );

          // Order: newest -> middle -> oldest (date_from DESC, ignoring priority)
          // With ids filter, should use filteredTasksByDate2 query
          expect(
            results.map((e) => e.meta.id).toList(),
            ['newest-high', 'middle-urgent', 'oldest-low'],
          );
        },
      );

      test(
        'getTasksDueOn returns only tasks due on the specified date',
        () async {
          final targetDate = DateTime(2024, 8, 15);
          final base = DateTime(2024, 8, 10);

          // Task due on target date (should be included)
          final taskDueOnDate = buildTaskEntry(
            id: 'task-due-on-date',
            timestamp: base,
            status: TaskStatus.inProgress(
              id: 'status-1',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            due: DateTime(2024, 8, 15, 14, 30), // Due on target date
          );

          // Task due the day before (should NOT be included)
          final taskDueBefore = buildTaskEntry(
            id: 'task-due-before',
            timestamp: base,
            status: TaskStatus.inProgress(
              id: 'status-2',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            due: DateTime(2024, 8, 14, 12), // Due day before
          );

          // Task due the day after (should NOT be included)
          final taskDueAfter = buildTaskEntry(
            id: 'task-due-after',
            timestamp: base,
            status: TaskStatus.inProgress(
              id: 'status-3',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            due: DateTime(2024, 8, 16, 9), // Due day after
          );

          // Task with no due date (should NOT be included)
          final taskNoDue = buildTaskEntry(
            id: 'task-no-due',
            timestamp: base,
            status: TaskStatus.inProgress(
              id: 'status-4',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            // No due date
          );

          // Completed task due on target date (should NOT be included)
          final taskDoneOnDate = buildTaskEntry(
            id: 'task-done-on-date',
            timestamp: base,
            status: TaskStatus.done(
              id: 'status-5',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            due: DateTime(2024, 8, 15, 10),
          );

          await db!.upsertJournalDbEntity(toDbEntity(taskDueOnDate));
          await db!.upsertJournalDbEntity(toDbEntity(taskDueBefore));
          await db!.upsertJournalDbEntity(toDbEntity(taskDueAfter));
          await db!.upsertJournalDbEntity(toDbEntity(taskNoDue));
          await db!.upsertJournalDbEntity(toDbEntity(taskDoneOnDate));

          final results = await db!.getTasksDueOn(targetDate);

          // Only the non-completed task due on the target date should be returned
          expect(results.map((e) => e.meta.id).toList(), ['task-due-on-date']);
        },
      );

      test('getTasksDueOn returns multiple tasks due on same date', () async {
        final targetDate = DateTime(2024, 9, 20);
        final base = DateTime(2024, 9, 15);

        final task1 = buildTaskEntry(
          id: 'task-morning',
          timestamp: base,
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: base,
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          due: DateTime(2024, 9, 20, 9), // 9 AM
          title: 'Morning task',
        );

        final task2 = buildTaskEntry(
          id: 'task-evening',
          timestamp: base,
          status: TaskStatus.inProgress(
            id: 'status-2',
            createdAt: base,
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          due: DateTime(2024, 9, 20, 18), // 6 PM
          title: 'Evening task',
        );

        await db!.upsertJournalDbEntity(toDbEntity(task1));
        await db!.upsertJournalDbEntity(toDbEntity(task2));

        final results = await db!.getTasksDueOn(targetDate);

        // Both tasks due on target date should be returned, ordered by due time
        expect(results.length, 2);
        expect(
          results.map((e) => e.meta.id).toList(),
          ['task-morning', 'task-evening'],
        );
      });

      test(
        'getTasksDueOn returns empty list when no tasks due on date',
        () async {
          final targetDate = DateTime(2024, 10, 5);
          final base = DateTime(2024, 10, 1);

          final taskDueDifferentDay = buildTaskEntry(
            id: 'task-different-day',
            timestamp: base,
            status: TaskStatus.inProgress(
              id: 'status-1',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            due: DateTime(2024, 10, 10), // Due on different date
          );

          await db!.upsertJournalDbEntity(toDbEntity(taskDueDifferentDay));

          final results = await db!.getTasksDueOn(targetDate);

          expect(results, isEmpty);
        },
      );

      test('tasks due queries use the active due-date index', () async {
        final endOfDay = DateTime(
          2024,
          10,
          5,
          23,
          59,
          59,
          999,
        ).toIso8601String();

        final plan = await db!
            .customSelect(
              r'''
          EXPLAIN QUERY PLAN
          SELECT * FROM journal INDEXED BY idx_journal_tasks_due_active
          WHERE type = 'Task'
          AND deleted = 0
          AND task_status NOT IN ('DONE', 'REJECTED')
          AND json_extract(serialized, '$.data.due') IS NOT NULL
          AND json_extract(serialized, '$.data.due') <= ?1
          AND private IN (0, (SELECT status FROM config_flags WHERE name = 'private'))
          ORDER BY json_extract(serialized, '$.data.due') ASC
          ''',
              variables: [drift.Variable<String>(endOfDay)],
            )
            .get();

        final details = plan.map((row) => row.read<String>('detail')).join(' ');
        expect(details, contains('idx_journal_tasks_due_active'));
      });

      test(
        'date-sorted task queries use the date-oriented task index',
        () async {
          final plan = await db!.customSelect(
            '''
          EXPLAIN QUERY PLAN
          SELECT * FROM journal
          WHERE type = 'Task'
          AND deleted = FALSE
          AND task = 1
          AND task_status = 'OPEN'
          AND category = ''
          ORDER BY date_from DESC, id ASC
          LIMIT 50 OFFSET 0
          ''',
          ).get();

          final details = plan
              .map((row) => row.read<String>('detail'))
              .join(' ');
          expect(details, contains('idx_journal_tasks_date'));
        },
      );

      test(
        'priority-filtered date-sorted task queries use the priority-aware date index',
        () async {
          final plan = await db!.customSelect(
            '''
          EXPLAIN QUERY PLAN
          SELECT * FROM journal
          WHERE type = 'Task'
          AND deleted = FALSE
          AND task = 1
          AND task_status = 'OPEN'
          AND category = ''
          AND task_priority = 'P1'
          ORDER BY date_from DESC, id ASC
          LIMIT 50 OFFSET 0
          ''',
          ).get();

          final details = plan
              .map((row) => row.read<String>('detail'))
              .join(' ');
          expect(details, contains('idx_journal_tasks_date_priority'));
        },
      );

      test(
        'journal browse queries use the browse-oriented journal index',
        () async {
          final plan = await db!.customSelect(
            '''
          EXPLAIN QUERY PLAN
          SELECT * FROM journal
          WHERE type = 'JournalEntry'
          AND deleted = FALSE
          ORDER BY date_from DESC
          LIMIT 50 OFFSET 0
          ''',
          ).get();

          final details = plan
              .map((row) => row.read<String>('detail'))
              .join(' ');
          expect(details, contains('idx_journal_browse'));
        },
      );

      test(
        'getJournalEntities returns consistent results and reflects writes',
        () async {
          final base = DateTime(2024, 8, 6, 11);
          final firstEntry = buildJournalEntry(
            id: 'cached-journal-1',
            timestamp: base,
            text: 'First cached entry',
          );

          await db!.upsertJournalDbEntity(toDbEntity(firstEntry));

          final firstResults = await fetchJournalEntities(
            db!,
            types: const ['JournalEntry'],
            starredStatuses: const [true, false],
            privateStatuses: const [false, true],
            flaggedStatuses: const [0, 1],
          );
          final secondResults = await fetchJournalEntities(
            db!,
            types: const ['JournalEntry'],
            starredStatuses: const [true, false],
            privateStatuses: const [false, true],
            flaggedStatuses: const [0, 1],
          );

          expect(
            firstResults.map((e) => e.meta.id),
            secondResults.map((e) => e.meta.id),
          );

          final secondEntry = buildJournalEntry(
            id: 'cached-journal-2',
            timestamp: base.add(const Duration(minutes: 1)),
            text: 'Second cached entry',
          );
          await db!.upsertJournalDbEntity(toDbEntity(secondEntry));

          final refreshedResults = await fetchJournalEntities(
            db!,
            types: const ['JournalEntry'],
            starredStatuses: const [true, false],
            privateStatuses: const [false, true],
            flaggedStatuses: const [0, 1],
          );

          expect(
            refreshedResults
                .where((entry) => entry.meta.id.startsWith('cached-journal-'))
                .map((entry) => entry.meta.id),
            ['cached-journal-2', 'cached-journal-1'],
          );
        },
      );
    });

    group('Linked entities -', () {
      test(
        'getLinkedEntities returns linked children sorted by recency',
        () async {
          final base = DateTime(2024, 8);
          final parent = buildJournalEntry(
            id: 'parent-entry',
            timestamp: base,
            text: 'Parent',
          );
          final childOlder = buildJournalEntry(
            id: 'child-older',
            timestamp: base.subtract(const Duration(hours: 1)),
            text: 'Older child',
          );
          final childNewer = buildJournalEntry(
            id: 'child-newer',
            timestamp: base.add(const Duration(hours: 1)),
            text: 'Newer child',
          );

          await db!.upsertJournalDbEntity(toDbEntity(parent));
          await db!.upsertJournalDbEntity(toDbEntity(childOlder));
          await db!.upsertJournalDbEntity(toDbEntity(childNewer));

          await db!.upsertEntryLink(
            buildEntryLink(
              id: 'link-older',
              fromId: parent.meta.id,
              toId: childOlder.meta.id,
              timestamp: base,
            ),
          );
          await db!.upsertEntryLink(
            buildEntryLink(
              id: 'link-newer',
              fromId: parent.meta.id,
              toId: childNewer.meta.id,
              timestamp: base.add(const Duration(minutes: 5)),
            ),
          );

          final results = await db!.getLinkedEntities(parent.meta.id);
          expect(results.map((e) => e.meta.id), ['child-newer', 'child-older']);
        },
      );

      test(
        'getLinkedEntities respects the private flag without a config subquery',
        () async {
          final base = DateTime(2024, 8, 3);
          final parent = buildJournalEntry(
            id: 'private-parent',
            timestamp: base,
            text: 'Parent',
          );
          final publicChild = buildJournalEntry(
            id: 'public-child',
            timestamp: base.add(const Duration(minutes: 1)),
            text: 'Public child',
          );
          final privateChild = buildJournalEntry(
            id: 'private-child',
            timestamp: base.add(const Duration(minutes: 2)),
            text: 'Private child',
            privateFlag: true,
          );

          await db!.upsertJournalDbEntity(toDbEntity(parent));
          await db!.upsertJournalDbEntity(toDbEntity(publicChild));
          await db!.upsertJournalDbEntity(toDbEntity(privateChild));

          await db!.upsertEntryLink(
            buildEntryLink(
              id: 'public-link',
              fromId: parent.meta.id,
              toId: publicChild.meta.id,
              timestamp: base,
            ),
          );
          await db!.upsertEntryLink(
            buildEntryLink(
              id: 'private-link',
              fromId: parent.meta.id,
              toId: privateChild.meta.id,
              timestamp: base.add(const Duration(minutes: 1)),
            ),
          );

          final privateConfig = await db!.getConfigFlagByName(privateFlag);
          expect(privateConfig, isNotNull);

          await db!.upsertConfigFlag(privateConfig!.copyWith(status: false));
          expect(
            (await db!.getLinkedEntities(parent.meta.id)).map((e) => e.meta.id),
            ['public-child'],
          );

          await db!.upsertConfigFlag(privateConfig.copyWith(status: true));
          expect(
            (await db!.getLinkedEntities(parent.meta.id)).map((e) => e.meta.id),
            ['private-child', 'public-child'],
          );
        },
      );

      test(
        'getLinkedToEntities respects the private flag without a config subquery',
        () async {
          final base = DateTime(2024, 8, 4);
          final publicParent = buildJournalEntry(
            id: 'public-parent',
            timestamp: base,
            text: 'Public parent',
          );
          final privateParent = buildJournalEntry(
            id: 'private-parent',
            timestamp: base.add(const Duration(minutes: 1)),
            text: 'Private parent',
            privateFlag: true,
          );
          final child = buildJournalEntry(
            id: 'reverse-child',
            timestamp: base.add(const Duration(minutes: 2)),
            text: 'Child',
          );

          await db!.upsertJournalDbEntity(toDbEntity(publicParent));
          await db!.upsertJournalDbEntity(toDbEntity(privateParent));
          await db!.upsertJournalDbEntity(toDbEntity(child));

          await db!.upsertEntryLink(
            buildEntryLink(
              id: 'public-reverse-link',
              fromId: publicParent.meta.id,
              toId: child.meta.id,
              timestamp: base,
            ),
          );
          await db!.upsertEntryLink(
            buildEntryLink(
              id: 'private-reverse-link',
              fromId: privateParent.meta.id,
              toId: child.meta.id,
              timestamp: base.add(const Duration(minutes: 1)),
            ),
          );

          final privateConfig = await db!.getConfigFlagByName(privateFlag);
          expect(privateConfig, isNotNull);

          await db!.upsertConfigFlag(privateConfig!.copyWith(status: false));
          final publicOnly = await db!.getLinkedToEntities(child.meta.id);
          expect(publicOnly.map((entry) => entry.id), ['public-parent']);

          await db!.upsertConfigFlag(privateConfig.copyWith(status: true));
          final withPrivate = await db!.getLinkedToEntities(child.meta.id);
          expect(
            withPrivate.map((entry) => entry.id),
            ['private-parent', 'public-parent'],
          );
        },
      );

      test(
        'bulk journal id lookups respect private visibility on both fast paths',
        () async {
          final base = DateTime(2024, 8, 5);
          final publicEntry = buildJournalEntry(
            id: 'bulk-public-entry',
            timestamp: base,
            text: 'Public entry',
          );
          final privateEntry = buildJournalEntry(
            id: 'bulk-private-entry',
            timestamp: base.add(const Duration(minutes: 1)),
            text: 'Private entry',
            privateFlag: true,
          );

          await db!.upsertJournalDbEntity(toDbEntity(publicEntry));
          await db!.upsertJournalDbEntity(toDbEntity(privateEntry));

          final privateConfig = await db!.getConfigFlagByName(privateFlag);
          expect(privateConfig, isNotNull);

          await db!.upsertConfigFlag(privateConfig!.copyWith(status: false));
          expect(
            (await db!.getJournalEntitiesForIdsUnordered({
              publicEntry.meta.id,
              privateEntry.meta.id,
            })).map((entry) => entry.meta.id),
            {'bulk-public-entry'},
          );

          await db!.upsertConfigFlag(privateConfig.copyWith(status: true));

          final unordered = await db!.getJournalEntitiesForIdsUnordered({
            publicEntry.meta.id,
            privateEntry.meta.id,
          });
          expect(
            unordered.map((entry) => entry.meta.id).toSet(),
            {'bulk-public-entry', 'bulk-private-entry'},
          );

          final ordered = await db!.getJournalEntitiesForIds({
            publicEntry.meta.id,
            privateEntry.meta.id,
          });
          expect(
            ordered.map((entry) => entry.meta.id),
            ['bulk-private-entry', 'bulk-public-entry'],
          );

          expect(
            await db!.getJournalEntityIdsSortedByDateFromDesc({
              publicEntry.meta.id,
              privateEntry.meta.id,
            }),
            ['bulk-private-entry', 'bulk-public-entry'],
          );
        },
      );

      test('getBulkLinkedEntities groups results by parent id', () async {
        final base = DateTime(2024, 8, 2);
        final parentA = buildJournalEntry(
          id: 'bulk-parent-a',
          timestamp: base,
          text: 'Parent A',
        );
        final parentB = buildJournalEntry(
          id: 'bulk-parent-b',
          timestamp: base,
          text: 'Parent B',
        );
        final child1 = buildJournalEntry(
          id: 'bulk-child-1',
          timestamp: base.add(const Duration(minutes: 1)),
          text: 'Child 1',
        );
        final child2 = buildJournalEntry(
          id: 'bulk-child-2',
          timestamp: base.add(const Duration(minutes: 2)),
          text: 'Child 2',
        );
        final child3 = buildJournalEntry(
          id: 'bulk-child-3',
          timestamp: base.add(const Duration(minutes: 3)),
          text: 'Child 3',
        );

        for (final entry in [parentA, parentB, child1, child2, child3]) {
          await db!.upsertJournalDbEntity(toDbEntity(entry));
        }

        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'bulk-link-a1',
            fromId: parentA.meta.id,
            toId: child1.meta.id,
            timestamp: base,
          ),
        );
        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'bulk-link-a2',
            fromId: parentA.meta.id,
            toId: child2.meta.id,
            timestamp: base.add(const Duration(minutes: 1)),
          ),
        );
        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'bulk-link-b3',
            fromId: parentB.meta.id,
            toId: child3.meta.id,
            timestamp: base.add(const Duration(minutes: 2)),
          ),
        );

        final results = await db!.getBulkLinkedEntities({
          parentA.meta.id,
          parentB.meta.id,
        });

        expect(results[parentA.meta.id]!.map((e) => e.meta.id), [
          'bulk-child-2',
          'bulk-child-1',
        ]);
        expect(results[parentB.meta.id]!.map((e) => e.meta.id), [
          'bulk-child-3',
        ]);
      });

      test('getBulkLinkedEntities returns empty map for empty input', () async {
        final results = await db!.getBulkLinkedEntities({});
        expect(results, isEmpty);
      });
    });

    group('Day plan queries -', () {
      test(
        'day plan reads respect the private flag without a config subquery',
        () async {
          final publicPlanDate = DateTime(2026, 1, 15);
          final privatePlanDate = publicPlanDate.add(const Duration(days: 1));
          final publicPlan = DayPlanEntry(
            meta: Metadata(
              id: dayPlanId(publicPlanDate),
              createdAt: publicPlanDate,
              updatedAt: publicPlanDate,
              dateFrom: publicPlanDate,
              dateTo: publicPlanDate.add(const Duration(days: 1)),
            ),
            data: DayPlanData(
              planDate: publicPlanDate,
              status: const DayPlanStatus.draft(),
              plannedBlocks: const [],
            ),
          );
          final privatePlan = DayPlanEntry(
            meta: Metadata(
              id: dayPlanId(privatePlanDate),
              createdAt: privatePlanDate,
              updatedAt: privatePlanDate,
              dateFrom: privatePlanDate,
              dateTo: privatePlanDate.add(const Duration(days: 1)),
              private: true,
            ),
            data: DayPlanData(
              planDate: privatePlanDate,
              status: const DayPlanStatus.draft(),
              plannedBlocks: const [],
            ),
          );

          await db!.upsertJournalDbEntity(toDbEntity(publicPlan));
          await db!.upsertJournalDbEntity(toDbEntity(privatePlan));

          await db!.upsertConfigFlag(
            const ConfigFlag(
              name: privateFlag,
              description: 'Show private entries?',
              status: false,
            ),
          );

          expect(await db!.getDayPlanById(publicPlan.meta.id), isNotNull);
          expect(await db!.getDayPlanById(privatePlan.meta.id), isNull);

          final visiblePlans = await db!.getDayPlansInRange(
            rangeStart: publicPlanDate.subtract(const Duration(days: 1)),
            rangeEnd: privatePlanDate.add(const Duration(days: 2)),
          );

          expect(visiblePlans.map((e) => e.meta.id), [publicPlan.meta.id]);
        },
      );
    });

    group('Watch streams -', () {
      test('watchConflicts emits unresolved conflicts and updates', () async {
        final stream = db!
            .watchConflicts(ConflictStatus.unresolved)
            .asBroadcastStream();
        final initialFuture = stream.first;
        final afterInsertFuture = stream.skip(1).first;
        final afterResolveFuture = stream.skip(2).first;

        expect(await initialFuture, isEmpty);

        final now = DateTime(2024, 9);
        final conflict = Conflict(
          id: 'conflict-unresolved',
          createdAt: now,
          updatedAt: now,
          serialized: jsonEncode(
            buildJournalEntry(
              id: 'conflict-entry',
              timestamp: now,
              text: 'Conflict entry',
            ).toJson(),
          ),
          schemaVersion: db!.schemaVersion,
          status: ConflictStatus.unresolved.index,
        );

        await db!.addConflict(conflict);
        expect(
          (await afterInsertFuture).map((c) => c.id),
          ['conflict-unresolved'],
        );

        await db!.resolveConflict(conflict);
        expect(await afterResolveFuture, isEmpty);
      });

      test('watchConflictById emits conflict updates', () async {
        const conflictId = 'conflict-by-id';
        final stream = db!.watchConflictById(conflictId).asBroadcastStream();
        final initialFuture = stream.first;
        final unresolvedFuture = stream.skip(1).first;
        final resolvedFuture = stream.skip(2).first;

        expect(await initialFuture, isEmpty);

        final now = DateTime(2024, 9, 2);
        final conflict = Conflict(
          id: conflictId,
          createdAt: now,
          updatedAt: now,
          serialized: jsonEncode(
            buildJournalEntry(
              id: 'conflict-by-id-entry',
              timestamp: now,
              text: 'Conflict by id',
            ).toJson(),
          ),
          schemaVersion: db!.schemaVersion,
          status: ConflictStatus.unresolved.index,
        );

        await db!.addConflict(conflict);
        expect(
          (await unresolvedFuture).single.status,
          ConflictStatus.unresolved.index,
        );

        await db!.resolveConflict(conflict);
        expect(
          (await resolvedFuture).single.status,
          ConflictStatus.resolved.index,
        );
      });
    });

    group('Upsert helpers -', () {
      test('upsertMeasurableDataType inserts and updates entity', () async {
        await db!.upsertMeasurableDataType(measurableWater);
        var row = await (db!.select(
          db!.measurableTypes,
        )..where((tbl) => tbl.id.equals(measurableWater.id))).getSingle();
        expect(
          measurableDataType(row).displayName,
          measurableWater.displayName,
        );

        final updated = measurableWater.copyWith(displayName: 'Water+');
        await db!.upsertMeasurableDataType(updated);
        row = await (db!.select(
          db!.measurableTypes,
        )..where((tbl) => tbl.id.equals(measurableWater.id))).getSingle();
        expect(measurableDataType(row).displayName, 'Water+');
      });

      test('upsertHabitDefinition upserts habit', () async {
        await db!.upsertHabitDefinition(habitFlossing);
        var row = await (db!.select(
          db!.habitDefinitions,
        )..where((tbl) => tbl.id.equals(habitFlossing.id))).getSingle();
        expect(
          HabitDefinition.fromJson(
            jsonDecode(row.serialized) as Map<String, dynamic>,
          ).name,
          habitFlossing.name,
        );

        final updated = habitFlossing.copyWith(name: 'Floss Nightly');
        await db!.upsertHabitDefinition(updated);
        row = await (db!.select(
          db!.habitDefinitions,
        )..where((tbl) => tbl.id.equals(habitFlossing.id))).getSingle();
        expect(
          HabitDefinition.fromJson(
            jsonDecode(row.serialized) as Map<String, dynamic>,
          ).name,
          'Floss Nightly',
        );
      });

      test('upsertDashboardDefinition upserts dashboard', () async {
        final dashboard = testDashboardConfig.copyWith(
          id: 'dashboard-upsert',
          name: 'Initial Dashboard',
          createdAt: DateTime(2024, 12),
          updatedAt: DateTime(2024, 12),
        );
        await db!.upsertDashboardDefinition(dashboard);
        var row = await (db!.select(
          db!.dashboardDefinitions,
        )..where((tbl) => tbl.id.equals('dashboard-upsert'))).getSingle();
        expect(
          DashboardDefinition.fromJson(
            jsonDecode(row.serialized) as Map<String, dynamic>,
          ).name,
          'Initial Dashboard',
        );

        final updated = dashboard.copyWith(name: 'Updated Dashboard');
        await db!.upsertDashboardDefinition(updated);
        row = await (db!.select(
          db!.dashboardDefinitions,
        )..where((tbl) => tbl.id.equals('dashboard-upsert'))).getSingle();
        expect(
          DashboardDefinition.fromJson(
            jsonDecode(row.serialized) as Map<String, dynamic>,
          ).name,
          'Updated Dashboard',
        );
      });

      test('upsertCategoryDefinition upserts category', () async {
        await db!.upsertCategoryDefinition(categoryMindfulness);
        var row = await (db!.select(
          db!.categoryDefinitions,
        )..where((tbl) => tbl.id.equals(categoryMindfulness.id))).getSingle();
        expect(
          CategoryDefinition.fromJson(
            jsonDecode(row.serialized) as Map<String, dynamic>,
          ).name,
          categoryMindfulness.name,
        );

        final updated = categoryMindfulness.copyWith(name: 'Mindfulness+');
        await db!.upsertCategoryDefinition(updated);
        row = await (db!.select(
          db!.categoryDefinitions,
        )..where((tbl) => tbl.id.equals(categoryMindfulness.id))).getSingle();
        expect(
          CategoryDefinition.fromJson(
            jsonDecode(row.serialized) as Map<String, dynamic>,
          ).name,
          'Mindfulness+',
        );
      });

      test('upsertEntityDefinition delegates based on entity type', () async {
        final measurable = measurableWater.copyWith(
          displayName: 'Entity Water',
        );
        await db!.upsertEntityDefinition(
          EntityDefinition.measurableDataType(
            id: measurable.id,
            createdAt: measurable.createdAt,
            updatedAt: measurable.updatedAt,
            displayName: measurable.displayName,
            description: measurable.description,
            unitName: measurable.unitName,
            version: measurable.version,
            vectorClock: measurable.vectorClock,
            aggregationType: measurable.aggregationType,
            private: measurable.private ?? false,
            favorite: measurable.favorite ?? false,
            deletedAt: measurable.deletedAt,
            categoryId: measurable.categoryId,
          ),
        );
        final measurableRow = await (db!.select(
          db!.measurableTypes,
        )..where((tbl) => tbl.id.equals(measurable.id))).getSingle();
        expect(measurableDataType(measurableRow).displayName, 'Entity Water');

        final habit = habitFlossing.copyWith(name: 'Entity Habit');
        await db!.upsertEntityDefinition(
          EntityDefinition.habit(
            id: habit.id,
            createdAt: habit.createdAt,
            updatedAt: habit.updatedAt,
            name: habit.name,
            description: habit.description,
            habitSchedule: habit.habitSchedule,
            vectorClock: habit.vectorClock,
            active: habit.active,
            private: habit.private,
            autoCompleteRule: habit.autoCompleteRule,
            version: habit.version,
            activeFrom: habit.activeFrom,
            activeUntil: habit.activeUntil,
            deletedAt: habit.deletedAt,
            // ignore: deprecated_member_use_from_same_package
            defaultStoryId: habit.defaultStoryId,
            categoryId: habit.categoryId,
            dashboardId: habit.dashboardId,
            priority: habit.priority,
          ),
        );
        final habitRow = await (db!.select(
          db!.habitDefinitions,
        )..where((tbl) => tbl.id.equals(habit.id))).getSingle();
        expect(
          HabitDefinition.fromJson(
            jsonDecode(habitRow.serialized) as Map<String, dynamic>,
          ).name,
          'Entity Habit',
        );
      });
    });

    group('Aggregate queries -', () {
      test('getJournalCount returns total journal entries', () async {
        final entryA = buildJournalEntry(
          id: 'journal-count-a',
          timestamp: DateTime(2024, 11),
          text: 'Entry A',
        );
        final entryB = buildJournalEntry(
          id: 'journal-count-b',
          timestamp: DateTime(2024, 11, 2),
          text: 'Entry B',
        );

        await db!.upsertJournalDbEntity(toDbEntity(entryA));
        await db!.upsertJournalDbEntity(toDbEntity(entryB));

        expect(await db!.getJournalCount(), 2);
      });
    });

    group('purgeDeletedFiles -', () {
      test('removes image files and JSON', () async {
        final deletionTime = DateTime(2024, 1, 1, 8);
        final imageEntry = buildImageEntry(
          id: 'image-to-delete',
          timestamp: deletionTime,
          imageDirectory: '/images/2024/01/01/',
          imageFile: 'image.jpg',
          deletedAt: deletionTime,
        );
        await db!.updateJournalEntity(imageEntry);

        final image = imageEntry as JournalImage;
        final docDir = getIt<Directory>();
        final imagePath = getFullImagePath(
          image,
          documentsDirectory: docDir.path,
        );
        await File(imagePath).create(recursive: true);
        await File(imagePath).writeAsBytes(const [1, 2, 3]);

        final jsonPath = '$imagePath.json';
        expect(File(jsonPath).existsSync(), isTrue);

        await db!.purgeDeletedFiles();

        expect(File(imagePath).existsSync(), isFalse);
        expect(File(jsonPath).existsSync(), isFalse);
      });

      test('removes audio files and JSON', () async {
        final deletionTime = DateTime(2024, 1, 2, 9);
        final audioEntry = buildAudioEntry(
          id: 'audio-to-delete',
          timestamp: deletionTime,
          audioDirectory: '/audio/2024/01/02/',
          audioFile: 'clip.m4a',
          deletedAt: deletionTime,
        );
        await db!.updateJournalEntity(audioEntry);

        final audio = audioEntry as JournalAudio;
        final audioPath = await AudioUtils.getFullAudioPath(audio);
        await File(audioPath).create(recursive: true);
        await File(audioPath).writeAsBytes(const [4, 5, 6]);

        final jsonPath = '$audioPath.json';
        expect(File(jsonPath).existsSync(), isTrue);

        await db!.purgeDeletedFiles();

        expect(File(audioPath).existsSync(), isFalse);
        expect(File(jsonPath).existsSync(), isFalse);
      });

      test('removes JSON for deleted text entries', () async {
        final deletionTime = DateTime(2024, 1, 3, 10);
        final textEntry = buildTextEntry(
          id: 'text-to-delete',
          timestamp: deletionTime,
          text: 'Deleted journal',
          deletedAt: deletionTime,
        );
        await db!.updateJournalEntity(textEntry);

        final docDir = getIt<Directory>();
        final jsonPath = entityPath(textEntry, docDir);
        expect(File(jsonPath).existsSync(), isTrue);

        await db!.purgeDeletedFiles();

        expect(File(jsonPath).existsSync(), isFalse);
      });

      test('handles file deletion errors gracefully', () async {
        final deletionTime = DateTime(2024, 1, 4, 11);
        final imageEntry = buildImageEntry(
          id: 'image-missing-file',
          timestamp: deletionTime,
          imageDirectory: '/images/2024/01/04/',
          imageFile: 'missing.jpg',
          deletedAt: deletionTime,
        );
        final textEntry = buildTextEntry(
          id: 'text-still-deleted',
          timestamp: deletionTime,
          text: 'Should still be deleted',
          deletedAt: deletionTime,
        );
        await db!.updateJournalEntity(imageEntry);
        await db!.updateJournalEntity(textEntry);

        final docDir = getIt<Directory>();
        final textJsonPath = entityPath(textEntry, docDir);
        expect(File(textJsonPath).existsSync(), isTrue);

        await db!.purgeDeletedFiles();

        verify(
          () => mockLoggingService.captureException(
            any<Object>(),
            domain: 'Database',
            subDomain: 'purgeDeletedFiles',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).called(1);
        expect(File(textJsonPath).existsSync(), isFalse);
      });
    });

    group('purgeDeleted -', () {
      test('creates backup when backup=true', () async {
        final docDir = getIt<Directory>();
        await createPlaceholderDbFile(docDir);

        final progress = await db!
            .purgeDeleted(stepDelay: Duration.zero)
            .toList();
        expect(progress, equals([1.0]));

        final backupDir = Directory('${docDir.path}/backup');
        final backups = backupDir.existsSync()
            ? backupDir.listSync()
            : <FileSystemEntity>[];
        expect(backups.whereType<File>(), isNotEmpty);
        expect(
          backups
              .whereType<File>()
              .first
              .path
              .split('/')
              .last
              .startsWith('db.'),
          isTrue,
        );
      });

      test('skips backup when backup=false', () async {
        final docDir = getIt<Directory>();
        final backupDir = Directory('${docDir.path}/backup');
        if (backupDir.existsSync()) {
          backupDir.deleteSync(recursive: true);
        }

        final progress = await db!
            .purgeDeleted(backup: false, stepDelay: Duration.zero)
            .toList();
        expect(progress, equals([1.0]));
        expect(backupDir.existsSync(), isFalse);
      });

      test('purges all deleted entity types', () async {
        final deletionTime = DateTime(2024, 2, 1, 8);
        final docDir = getIt<Directory>();
        await createPlaceholderDbFile(docDir);
        await seedDeletedDatabaseContent(db!, deletionTime);

        await db!
            .purgeDeleted(backup: false, stepDelay: Duration.zero)
            .toList();

        expect(await db!.select(db!.dashboardDefinitions).get(), isEmpty);
        expect(await db!.select(db!.measurableTypes).get(), isEmpty);
        expect(await db!.select(db!.journal).get(), isEmpty);
      });

      test('reports progress accurately', () async {
        final deletionTime = DateTime(2024, 2, 2, 9);
        await seedDeletedDatabaseContent(db!, deletionTime);

        final progress = await db!
            .purgeDeleted(backup: false, stepDelay: Duration.zero)
            .toList();
        expect(progress, equals([0.33, 0.66, 1.0]));
      });

      test('returns 1.0 immediately when nothing to purge', () async {
        final progress = await db!
            .purgeDeleted(backup: false, stepDelay: Duration.zero)
            .toList();
        expect(progress, equals([1.0]));
      });
    });

    group('Time-range queries -', () {
      test('sortedCalendarEntries filters and sorts correctly', () async {
        final janEarly = buildTextEntry(
          id: 'jan-05',
          timestamp: DateTime(2024, 1, 5, 8),
          text: 'Entry Jan 05',
        );
        final janLate = buildWorkoutEntry(
          id: 'jan-20-workout',
          start: DateTime(2024, 1, 20, 7),
          end: DateTime(2024, 1, 20, 8),
        );
        final febOutside = buildTextEntry(
          id: 'feb-01',
          timestamp: DateTime(2024, 2, 1, 9),
          text: 'Outside range',
        );

        await db!.updateJournalEntity(janEarly);
        await db!.updateJournalEntity(janLate);
        await db!.updateJournalEntity(febOutside);

        final rangeStart = DateTime(2024, 1, 1);
        final rangeEnd = DateTime(2024, 1, 31, 23, 59);
        final results = await db!.sortedCalendarEntries(
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        expect(
          results.map((e) => e.meta.id),
          equals(['jan-20-workout', 'jan-05']),
        );
      });

      test('getMeasurementsByType filters by type and range', () async {
        final measurementDate = DateTime(2024, 3, 5);
        final inRangeWater = testMeasurementChocolateEntry.copyWith(
          meta: testMeasurementChocolateEntry.meta.copyWith(
            id: 'measurement-water',
            createdAt: measurementDate,
            updatedAt: measurementDate,
            dateFrom: measurementDate,
            dateTo: measurementDate,
          ),
          data: testMeasurementChocolateEntry.data.copyWith(
            dataTypeId: measurableWater.id,
            dateFrom: measurementDate,
            dateTo: measurementDate,
          ),
        );
        final oldMeasurementDate = DateTime(2023, 12, 1);
        final outOfRangeWater = inRangeWater.copyWith(
          meta: inRangeWater.meta.copyWith(
            id: 'measurement-water-old',
            createdAt: oldMeasurementDate,
            updatedAt: oldMeasurementDate,
            dateFrom: oldMeasurementDate,
            dateTo: oldMeasurementDate,
          ),
        );
        final otherType = inRangeWater.copyWith(
          meta: inRangeWater.meta.copyWith(
            id: 'measurement-chocolate',
          ),
          data: inRangeWater.data.copyWith(dataTypeId: measurableChocolate.id),
        );

        await db!.updateJournalEntity(inRangeWater);
        await db!.updateJournalEntity(outOfRangeWater);
        await db!.updateJournalEntity(otherType);

        final rangeStart = DateTime(2024, 3, 1);
        final rangeEnd = DateTime(2024, 3, 31);
        final results = await db!.getMeasurementsByType(
          type: measurableWater.id,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        expect(results, hasLength(1));
        expect(results.first.meta.id, 'measurement-water');
      });

      test('getHabitCompletionsByHabitId filters correctly', () async {
        final habitId = habitFlossing.id;
        final inRange = buildHabitCompletionEntry(
          id: 'habit-complete-1',
          habitId: habitId,
          timestamp: DateTime(2024, 4, 15),
        );
        final outsideRange = buildHabitCompletionEntry(
          id: 'habit-complete-old',
          habitId: habitId,
          timestamp: DateTime(2024, 1, 1),
        );
        final otherHabit = buildHabitCompletionEntry(
          id: 'habit-other',
          habitId: 'other-habit',
          timestamp: DateTime(2024, 4, 16),
        );

        await db!.updateJournalEntity(inRange);
        await db!.updateJournalEntity(outsideRange);
        await db!.updateJournalEntity(otherHabit);

        final rangeStart = DateTime(2024, 4, 1);
        final rangeEnd = DateTime(2024, 4, 30);
        final results = await db!.getHabitCompletionsByHabitId(
          habitId: habitId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        expect(results.map((e) => e.meta.id), equals(['habit-complete-1']));
      });

      test('getQuantitativeByType filters correctly', () async {
        final weightEntry = buildQuantitativeEntry(
          id: 'weight-1',
          dataType: 'weight',
          timestamp: DateTime(2024, 5, 10),
        );
        final weightOutsideRange = buildQuantitativeEntry(
          id: 'weight-old',
          dataType: 'weight',
          timestamp: DateTime(2023, 5, 10),
        );
        final otherType = buildQuantitativeEntry(
          id: 'blood-pressure',
          dataType: 'bp',
          timestamp: DateTime(2024, 5, 10),
        );

        await db!.updateJournalEntity(weightEntry);
        await db!.updateJournalEntity(weightOutsideRange);
        await db!.updateJournalEntity(otherType);

        final quantStart = DateTime(2024, 5, 1);
        final quantEnd = DateTime(2024, 5, 31);
        final results = await db!.getQuantitativeByType(
          type: 'weight',
          rangeStart: quantStart,
          rangeEnd: quantEnd,
        );

        expect(results.map((e) => e.meta.id), equals(['weight-1']));
      });

      test('latestQuantitativeByType returns most recent entry', () async {
        final older = buildQuantitativeEntry(
          id: 'quant-old',
          dataType: 'coverage',
          timestamp: DateTime(2024, 6, 1),
        );
        final newer = buildQuantitativeEntry(
          id: 'quant-new',
          dataType: 'coverage',
          timestamp: DateTime(2024, 6, 2),
        );
        await db!.updateJournalEntity(older);
        await db!.updateJournalEntity(newer);

        final result = await db!.latestQuantitativeByType('coverage');
        expect(result, isNotNull);
        expect(result!.meta.id, 'quant-new');
      });

      test('latestQuantitativeByType returns null when none exist', () async {
        DevLogger.clear();

        final result = await db!.latestQuantitativeByType('missing-type');
        expect(result, isNull);
        expect(
          DevLogger.capturedLogs.any(
            (message) => message.contains('no result for missing-type'),
          ),
          isTrue,
        );
      });

      test('latestWorkout returns most recent workout', () async {
        final first = buildWorkoutEntry(
          id: 'workout-1',
          start: DateTime(2024, 7, 1, 8),
          end: DateTime(2024, 7, 1, 9),
        );
        final latest = buildWorkoutEntry(
          id: 'workout-2',
          start: DateTime(2024, 7, 2, 7),
          end: DateTime(2024, 7, 2, 8),
        );
        await db!.updateJournalEntity(first);
        await db!.updateJournalEntity(latest);

        final result = await db!.latestWorkout();
        expect(result, isNotNull);
        expect(result!.meta.id, 'workout-2');
      });

      test('latestWorkout returns null when none exist', () async {
        DevLogger.clear();

        final result = await db!.latestWorkout();
        expect(result, isNull);
        expect(
          DevLogger.capturedLogs.any(
            (message) => message.contains('no workout found'),
          ),
          isTrue,
        );
      });
    });

    group('Entry links -', () {
      test('linksForEntryIds returns all links for target set', () async {
        final linkAb = buildEntryLink(
          id: 'link-ab',
          fromId: 'a',
          toId: 'b',
          timestamp: DateTime(2024, 8, 1),
        );
        final linkAc = buildEntryLink(
          id: 'link-ac',
          fromId: 'a',
          toId: 'c',
          timestamp: DateTime(2024, 8, 2),
        );
        final linkDe = buildEntryLink(
          id: 'link-de',
          fromId: 'd',
          toId: 'e',
          timestamp: DateTime(2024, 8, 3),
        );

        await db!.upsertEntryLink(linkAb);
        await db!.upsertEntryLink(linkAc);
        await db!.upsertEntryLink(linkDe);

        final results = await db!.linksForEntryIds({'b', 'c'});
        expect(results.map((link) => link.id).toSet(), {'link-ab', 'link-ac'});
      });

      test(
        'linksForEntryIdsBidirectional returns links for from/to matches',
        () async {
          final linkAb = buildEntryLink(
            id: 'link-ab',
            fromId: 'a',
            toId: 'b',
            timestamp: DateTime(2024, 8, 1),
          );
          final linkCa = buildEntryLink(
            id: 'link-ca',
            fromId: 'c',
            toId: 'a',
            timestamp: DateTime(2024, 8, 2),
          );

          await db!.upsertEntryLink(linkAb);
          await db!.upsertEntryLink(linkCa);

          final results = await db!.linksForEntryIdsBidirectional({'a'});
          expect(results.map((link) => link.id).toSet(), {
            'link-ab',
            'link-ca',
          });
        },
      );

      test(
        'basicLinksForEntryIds returns empty list for empty target set',
        () async {
          final results = await db!.basicLinksForEntryIds(<String>{});
          expect(results, isEmpty);
        },
      );

      test('basicLinksForEntryIds filters out RatingLink entries', () async {
        final basicLink = buildEntryLink(
          id: 'basic-link',
          fromId: 'task-1',
          toId: 'entry-1',
          timestamp: DateTime(2024, 8, 2),
        );
        final ratingLink = EntryLink.rating(
          id: 'rating-link',
          fromId: 'rating-1',
          toId: 'entry-1',
          createdAt: DateTime(2024, 8, 2),
          updatedAt: DateTime(2024, 8, 2),
          vectorClock: null,
        );

        await db!.upsertEntryLink(basicLink);
        await db!.upsertEntryLink(ratingLink);

        final results = await db!.basicLinksForEntryIds({'entry-1'});
        expect(results, hasLength(1));
        expect(results.single.id, 'basic-link');
        expect(results.single, isA<BasicLink>());
      });

      test('upsertEntryLink rejects self-links', () async {
        final link = buildEntryLink(
          id: 'self-link',
          fromId: 'self',
          toId: 'self',
          timestamp: DateTime(2024, 8, 4),
        );

        final written = await db!.upsertEntryLink(link);
        expect(written, 0);
        expect(await db!.linksForEntryIds({'self'}), isEmpty);
      });

      test('upsertEntryLink skips no-op updates', () async {
        final link = buildEntryLink(
          id: 'stable-link',
          fromId: 'origin',
          toId: 'target',
          timestamp: DateTime(2024, 8, 5),
        );

        final firstWrite = await db!.upsertEntryLink(link);
        final secondWrite = await db!.upsertEntryLink(link);

        expect(firstWrite, 1);
        expect(secondWrite, 0);
      });

      test('upsertEntryLink creates new link', () async {
        final link = buildEntryLink(
          id: 'new-link',
          fromId: 'origin',
          toId: 'fresh',
          timestamp: DateTime(2024, 8, 6),
        );

        final result = await db!.upsertEntryLink(link);
        expect(result, 1);
        final stored = await db!.linksForEntryIds({'fresh'});
        expect(stored.single.id, 'new-link');
      });

      test('upsertEntryLink updates existing link', () async {
        final link = buildEntryLink(
          id: 'update-link',
          fromId: 'source',
          toId: 'initial',
          timestamp: DateTime(2024, 8, 7),
        );
        await db!.upsertEntryLink(link);

        final updated = link.copyWith(
          toId: 'updated',
          updatedAt: DateTime(2024, 8, 8),
        );
        final result = await db!.upsertEntryLink(updated);
        expect(result, 1);

        final oldLookup = await db!.linksForEntryIds({'initial'});
        expect(oldLookup, isEmpty);
        final newLookup = await db!.linksForEntryIds({'updated'});
        expect(newLookup.single.toId, 'updated');
      });

      test('upsertEntryLink handles precheck errors gracefully', () async {
        final specialDb = _PrecheckThrowingJournalDb();
        addTearDown(() async {
          await specialDb.close();
        });
        await initConfigFlags(specialDb, inMemoryDatabase: true);

        final link = buildEntryLink(
          id: 'throwing-link',
          fromId: 'src',
          toId: 'dst',
          timestamp: DateTime(2024, 8, 9),
        );

        final result = await specialDb.upsertEntryLink(link);
        expect(result, 1);
        final stored = await specialDb.linksForEntryIds({'dst'});
        expect(stored, hasLength(1));
      });
    });

    group('Rating queries -', () {
      final base = DateTime(2024, 9, 1, 10);

      JournalEntity buildRatingEntry({
        required String id,
        required String targetId,
        DateTime? timestamp,
        DateTime? deletedAt,
      }) {
        final ts = timestamp ?? base;
        return JournalEntity.rating(
          meta: Metadata(
            id: id,
            createdAt: ts,
            updatedAt: ts,
            dateFrom: ts,
            dateTo: ts,
            deletedAt: deletedAt,
          ),
          data: RatingData(
            targetId: targetId,
            dimensions: const [
              RatingDimension(key: 'productivity', value: 0.8),
              RatingDimension(key: 'energy', value: 0.6),
            ],
          ),
        );
      }

      EntryLink buildRatingLink({
        required String id,
        required String fromId,
        required String toId,
        DateTime? timestamp,
        bool hidden = false,
      }) {
        final ts = timestamp ?? base;
        return EntryLink.rating(
          id: id,
          fromId: fromId,
          toId: toId,
          createdAt: ts,
          updatedAt: ts,
          vectorClock: const VectorClock({'db': 1}),
          hidden: hidden,
        );
      }

      test('getRatingForTimeEntry returns rating entity', () async {
        final timeEntry = buildJournalEntry(
          id: 'te-1',
          timestamp: base,
          text: 'Work session',
        );
        final ratingEntry = buildRatingEntry(
          id: 'rating-1',
          targetId: 'te-1',
        );

        await db!.upsertJournalDbEntity(toDbEntity(timeEntry));
        await db!.upsertJournalDbEntity(toDbEntity(ratingEntry));
        await db!.upsertEntryLink(
          buildRatingLink(
            id: 'link-1',
            fromId: 'rating-1',
            toId: 'te-1',
          ),
        );

        final result = await db!.getRatingForTimeEntry('te-1');
        expect(result, isNotNull);
        expect(result, isA<RatingEntry>());
        expect(result!.meta.id, 'rating-1');
        expect(result.data.targetId, 'te-1');
      });

      test(
        'getRatingForTimeEntry returns null when no rating exists',
        () async {
          final timeEntry = buildJournalEntry(
            id: 'te-no-rating',
            timestamp: base,
            text: 'No rating',
          );
          await db!.upsertJournalDbEntity(toDbEntity(timeEntry));

          final result = await db!.getRatingForTimeEntry('te-no-rating');
          expect(result, isNull);
        },
      );

      test('getRatingForTimeEntry excludes deleted ratings', () async {
        final timeEntry = buildJournalEntry(
          id: 'te-deleted',
          timestamp: base,
          text: 'Session',
        );
        final deletedRating = buildRatingEntry(
          id: 'rating-deleted',
          targetId: 'te-deleted',
          deletedAt: base.add(const Duration(hours: 1)),
        );

        await db!.upsertJournalDbEntity(toDbEntity(timeEntry));
        await db!.upsertJournalDbEntity(toDbEntity(deletedRating));
        await db!.upsertEntryLink(
          buildRatingLink(
            id: 'link-deleted',
            fromId: 'rating-deleted',
            toId: 'te-deleted',
          ),
        );

        final result = await db!.getRatingForTimeEntry('te-deleted');
        expect(result, isNull);
      });

      test('getRatingForTimeEntry excludes hidden links', () async {
        final timeEntry = buildJournalEntry(
          id: 'te-hidden',
          timestamp: base,
          text: 'Session',
        );
        final rating = buildRatingEntry(
          id: 'rating-hidden',
          targetId: 'te-hidden',
        );

        await db!.upsertJournalDbEntity(toDbEntity(timeEntry));
        await db!.upsertJournalDbEntity(toDbEntity(rating));
        await db!.upsertEntryLink(
          buildRatingLink(
            id: 'link-hidden',
            fromId: 'rating-hidden',
            toId: 'te-hidden',
            hidden: true,
          ),
        );

        final result = await db!.getRatingForTimeEntry('te-hidden');
        expect(result, isNull);
      });

      test('getRatingForTimeEntry returns most recently updated when '
          'multiple ratings exist', () async {
        final timeEntry = buildJournalEntry(
          id: 'te-multi',
          timestamp: base,
          text: 'Session',
        );
        final olderRating = buildRatingEntry(
          id: 'rating-older',
          targetId: 'te-multi',
          timestamp: base,
        );
        final newerRating = buildRatingEntry(
          id: 'rating-newer',
          targetId: 'te-multi',
          timestamp: base.add(const Duration(hours: 2)),
        );

        await db!.upsertJournalDbEntity(toDbEntity(timeEntry));
        await db!.upsertJournalDbEntity(toDbEntity(olderRating));
        await db!.upsertJournalDbEntity(toDbEntity(newerRating));
        await db!.upsertEntryLink(
          buildRatingLink(
            id: 'link-older',
            fromId: 'rating-older',
            toId: 'te-multi',
          ),
        );
        await db!.upsertEntryLink(
          buildRatingLink(
            id: 'link-newer',
            fromId: 'rating-newer',
            toId: 'te-multi',
          ),
        );

        final result = await db!.getRatingForTimeEntry('te-multi');
        expect(result, isNotNull);
        expect(result!.meta.id, 'rating-newer');
      });

      test(
        'getRatingIdsForTimeEntries returns mapping for multiple entries',
        () async {
          for (final i in [1, 2, 3]) {
            final teId = 'bulk-te-$i';
            final ratingId = 'bulk-rating-$i';
            await db!.upsertJournalDbEntity(
              toDbEntity(
                buildJournalEntry(
                  id: teId,
                  timestamp: base.add(Duration(hours: i)),
                  text: 'Session $i',
                ),
              ),
            );
            await db!.upsertJournalDbEntity(
              toDbEntity(
                buildRatingEntry(
                  id: ratingId,
                  targetId: teId,
                  timestamp: base.add(Duration(hours: i)),
                ),
              ),
            );
            await db!.upsertEntryLink(
              buildRatingLink(
                id: 'bulk-link-$i',
                fromId: ratingId,
                toId: teId,
                timestamp: base.add(Duration(hours: i)),
              ),
            );
          }

          final result = await db!.getRatingIdsForTimeEntries({
            'bulk-te-1',
            'bulk-te-2',
            'bulk-te-3',
          });
          expect(result.length, 3);
          expect(result['bulk-te-1'], 'bulk-rating-1');
          expect(result['bulk-te-2'], 'bulk-rating-2');
          expect(result['bulk-te-3'], 'bulk-rating-3');
        },
      );

      test('getRatingIdsForTimeEntries excludes deleted ratings', () async {
        // Active rating for te-a
        await db!.upsertJournalDbEntity(
          toDbEntity(
            buildJournalEntry(
              id: 'del-te-a',
              timestamp: base,
              text: 'Session A',
            ),
          ),
        );
        await db!.upsertJournalDbEntity(
          toDbEntity(
            buildRatingEntry(
              id: 'del-rating-a',
              targetId: 'del-te-a',
            ),
          ),
        );
        await db!.upsertEntryLink(
          buildRatingLink(
            id: 'del-link-a',
            fromId: 'del-rating-a',
            toId: 'del-te-a',
          ),
        );

        // Deleted rating for te-b
        await db!.upsertJournalDbEntity(
          toDbEntity(
            buildJournalEntry(
              id: 'del-te-b',
              timestamp: base,
              text: 'Session B',
            ),
          ),
        );
        await db!.upsertJournalDbEntity(
          toDbEntity(
            buildRatingEntry(
              id: 'del-rating-b',
              targetId: 'del-te-b',
              deletedAt: base.add(const Duration(hours: 1)),
            ),
          ),
        );
        await db!.upsertEntryLink(
          buildRatingLink(
            id: 'del-link-b',
            fromId: 'del-rating-b',
            toId: 'del-te-b',
          ),
        );

        final result = await db!.getRatingIdsForTimeEntries({
          'del-te-a',
          'del-te-b',
        });
        expect(result.length, 1);
        expect(result.containsKey('del-te-a'), isTrue);
        expect(result.containsKey('del-te-b'), isFalse);
      });

      test('getRatingIdsForTimeEntries excludes hidden links', () async {
        await db!.upsertJournalDbEntity(
          toDbEntity(
            buildJournalEntry(
              id: 'hid-te',
              timestamp: base,
              text: 'Session',
            ),
          ),
        );
        await db!.upsertJournalDbEntity(
          toDbEntity(
            buildRatingEntry(
              id: 'hid-rating',
              targetId: 'hid-te',
            ),
          ),
        );
        await db!.upsertEntryLink(
          buildRatingLink(
            id: 'hid-link',
            fromId: 'hid-rating',
            toId: 'hid-te',
            hidden: true,
          ),
        );

        final result = await db!.getRatingIdsForTimeEntries({'hid-te'});
        expect(result.isEmpty, isTrue);
      });

      test(
        'getRatingIdsForTimeEntries returns empty map for empty input',
        () async {
          final result = await db!.getRatingIdsForTimeEntries({});
          expect(result.isEmpty, isTrue);
        },
      );
    });

    group('Vector clock streaming for sequence log population -', () {
      test(
        'streamEntriesWithVectorClock returns entries with vector clocks',
        () async {
          // Create entries with vector clocks
          const vc1 = VectorClock({'host1': 1, 'host2': 2});
          const vc2 = VectorClock({'host1': 3});
          final entry1 = createJournalEntryWithVclock(vc1);
          final entry2 = createJournalEntryWithVclock(vc2);

          await db!.updateJournalEntity(entry1);
          await db!.updateJournalEntity(entry2);

          // Stream and collect all batches
          final results = await db!
              .streamEntriesWithVectorClock()
              .expand((batch) => batch)
              .toList();

          // Verify we got the entries with their vector clocks
          expect(results.length, greaterThanOrEqualTo(2));

          final result1 = results.firstWhere((r) => r.id == entry1.meta.id);
          expect(result1.vectorClock, {'host1': 1, 'host2': 2});

          final result2 = results.firstWhere((r) => r.id == entry2.meta.id);
          expect(result2.vectorClock, {'host1': 3});
        },
      );

      test(
        'streamEntriesWithVectorClock handles entries without vector clock',
        () async {
          final entryNoVc = createJournalEntry('no vector clock');
          await db!.updateJournalEntity(entryNoVc);

          final results = await db!
              .streamEntriesWithVectorClock()
              .expand((batch) => batch)
              .toList();

          final found = results.firstWhere((r) => r.id == entryNoVc.meta.id);
          expect(found.vectorClock, isNull);
        },
      );

      test(
        'streamEntryLinksWithVectorClock returns links with vector clocks',
        () async {
          const vc = VectorClock({'host1': 5});
          final link = EntryLink.basic(
            id: 'link-with-vc',
            fromId: 'from-entry',
            toId: 'to-entry',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
            vectorClock: vc,
          );

          await db!.upsertEntryLink(link);

          final results = await db!
              .streamEntryLinksWithVectorClock()
              .expand((batch) => batch)
              .toList();

          expect(results, isNotEmpty);
          final found = results.firstWhere((r) => r.id == 'link-with-vc');
          expect(found.vectorClock, {'host1': 5});
        },
      );

      test(
        'streamEntryLinksWithVectorClock handles links without vector clock',
        () async {
          final link = EntryLink.basic(
            id: 'link-no-vc',
            fromId: 'from-entry',
            toId: 'to-entry',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
            vectorClock: null,
          );

          await db!.upsertEntryLink(link);

          final results = await db!
              .streamEntryLinksWithVectorClock()
              .expand((batch) => batch)
              .toList();

          final found = results.firstWhere((r) => r.id == 'link-no-vc');
          expect(found.vectorClock, isNull);
        },
      );

      test('countAllJournalEntries returns correct count', () async {
        final initialCount = await db!.countAllJournalEntries();

        await db!.updateJournalEntity(createJournalEntry('entry 1'));
        await db!.updateJournalEntity(createJournalEntry('entry 2'));

        final newCount = await db!.countAllJournalEntries();
        expect(newCount, initialCount + 2);
      });

      test('countAllEntryLinks returns correct count', () async {
        final initialCount = await db!.countAllEntryLinks();

        await db!.upsertEntryLink(
          EntryLink.basic(
            id: 'count-link-1',
            fromId: 'from',
            toId: 'to1',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
            vectorClock: null,
          ),
        );
        await db!.upsertEntryLink(
          EntryLink.basic(
            id: 'count-link-2',
            fromId: 'from',
            toId: 'to2',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
            vectorClock: null,
          ),
        );

        final newCount = await db!.countAllEntryLinks();
        expect(newCount, initialCount + 2);
      });

      test('streamEntriesWithVectorClock respects batch size', () async {
        // Create several entries
        for (var i = 0; i < 5; i++) {
          await db!.updateJournalEntity(createJournalEntry('batch test $i'));
        }

        // Stream with small batch size
        var batchCount = 0;
        await for (final batch in db!.streamEntriesWithVectorClock(
          batchSize: 2,
        )) {
          batchCount++;
          expect(batch.length, lessThanOrEqualTo(2));
        }

        // Should have multiple batches
        expect(batchCount, greaterThanOrEqualTo(1));
      });

      test(
        'streamEntriesWithVectorClock handles malformed serialized data',
        () async {
          // Create a valid entry first
          final validEntry = createJournalEntryWithVclock(
            const VectorClock({'host': 42}),
            id: 'valid-entry',
          );
          await db!.updateJournalEntity(validEntry);

          // Insert a malformed entry via raw SQL with non-numeric vectorClock
          // This bypasses normal serialization to test DB layer parsing
          final malformedSerialized = jsonEncode({
            'meta': {
              'id': 'malformed-entry',
              'createdAt': '2024-01-01T00:00:00.000',
              'updatedAt': '2024-01-01T00:00:00.000',
              'dateFrom': '2024-01-01T00:00:00.000',
              'dateTo': '2024-01-01T00:00:00.000',
              'starred': false,
              'private': false,
              'vectorClock': {'host': 'not-a-number'},
            },
            'entryText': {'plainText': 'malformed entry'},
          });

          final timestamp = DateTime(2024, 1, 1).millisecondsSinceEpoch;
          await db!.customStatement(
            'INSERT INTO journal '
            '(id, created_at, updated_at, date_from, date_to, deleted, starred, '
            'private, task, flag, type, serialized, schema_version, category) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              'malformed-entry',
              timestamp,
              timestamp,
              timestamp,
              timestamp,
              0, // deleted
              0, // starred
              0, // private
              0, // task
              0, // flag
              'JournalEntry',
              malformedSerialized,
              0, // schema_version
              '', // category
            ],
          );

          // The streaming method should handle entries gracefully
          // even if vector clock extraction fails (returns null)
          final results = await db!
              .streamEntriesWithVectorClock()
              .expand((batch) => batch)
              .toList();

          expect(results.length, greaterThanOrEqualTo(2));

          // Valid entry should have its vectorClock intact
          final validFound = results.firstWhere((r) => r.id == 'valid-entry');
          expect(validFound.vectorClock, {'host': 42});

          // Malformed entry should have vectorClock == null (graceful handling)
          final malformedFound = results.firstWhere(
            (r) => r.id == 'malformed-entry',
          );
          expect(
            malformedFound.vectorClock,
            isNull,
            reason: 'Non-numeric vectorClock values should result in null',
          );
        },
      );

      test(
        'streamEntryLinksWithVectorClock handles links with non-numeric vectorClock values gracefully',
        () async {
          // Create a valid link first
          final validLink = EntryLink.basic(
            id: 'link-valid',
            fromId: 'from-valid',
            toId: 'to-valid',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
            vectorClock: const VectorClock({'host': 1}),
          );
          await db!.upsertEntryLink(validLink);

          // Insert a malformed link via raw SQL with non-numeric vectorClock values
          // This bypasses normal serialization to test DB layer parsing
          final malformedSerialized = jsonEncode({
            'id': 'link-malformed',
            'fromId': 'from-malformed',
            'toId': 'to-malformed',
            'linkType': 'basic',
            'createdAt': '2024-01-01T00:00:00.000',
            'updatedAt': '2024-01-01T00:00:00.000',
            'vectorClock': {'host': 'not-a-number', 'other': 'also-invalid'},
          });

          // Use Unix timestamp in milliseconds for created_at/updated_at
          final timestamp = DateTime(2024, 1, 1).millisecondsSinceEpoch;
          await db!.customStatement(
            'INSERT INTO linked_entries '
            '(id, from_id, to_id, type, serialized, hidden, created_at, updated_at) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            [
              'link-malformed',
              'from-malformed',
              'to-malformed',
              'basic',
              malformedSerialized,
              0,
              timestamp,
              timestamp,
            ],
          );

          // Streaming should NOT throw and should handle both entries
          final results = await db!
              .streamEntryLinksWithVectorClock()
              .expand((batch) => batch)
              .toList();

          expect(results.length, greaterThanOrEqualTo(2));

          // Valid link should have its vectorClock intact
          final validFound = results.firstWhere((r) => r.id == 'link-valid');
          expect(validFound.vectorClock, {'host': 1});

          // Malformed link should have vectorClock == null (graceful handling)
          final malformedFound = results.firstWhere(
            (r) => r.id == 'link-malformed',
          );
          expect(
            malformedFound.vectorClock,
            isNull,
            reason: 'Non-numeric vectorClock values should result in null',
          );
        },
      );
    });

    tearDownAll(() async {
      await getIt.reset();
    });

    tearDown(() async {
      // Unregister services first to avoid hanging references
      getIt
        ..unregister<UpdateNotifications>()
        ..unregister<LoggingService>()
        ..unregister<Directory>();

      // Then close database
      await db?.close();

      // Clean up the temp directory
      if (testDirectory.existsSync()) {
        testDirectory.deleteSync(recursive: true);
      }
    });

    test(
      'Config flags are initialized as expected',
      () async {
        final flags = await db?.watchConfigFlags().first;
        expect(flags, expectedFlags);
      },
    );

    test(
      'ConfigFlag can be retrieved by name',
      () async {
        expect(
          await db?.getConfigFlagByName(recordLocationFlag),
          const ConfigFlag(
            name: recordLocationFlag,
            description: 'Record geolocation?',
            status: false,
          ),
        );

        await db?.toggleConfigFlag(recordLocationFlag);

        expect(
          await db?.getConfigFlagByName(recordLocationFlag),
          const ConfigFlag(
            name: recordLocationFlag,
            description: 'Record geolocation?',
            status: true,
          ),
        );

        expect(await db?.getConfigFlagByName('invalid'), null);
      },
    );

    test(
      'watchConfigFlag returns correct flag status as a stream',
      () async {
        final existingFlag = await db!.getConfigFlagByName(recordLocationFlag);
        await db!.upsertConfigFlag(existingFlag!.copyWith(status: false));

        final emittedValuesFuture = db!
            .watchConfigFlag(recordLocationFlag)
            .take(2)
            .toList();
        await db!.toggleConfigFlag(recordLocationFlag);

        expect(await emittedValuesFuture, [false, true]);
      },
    );

    test(
      'watchConfigFlags emits updates from the shared in-memory snapshot',
      () async {
        final existingFlag = await db!.getConfigFlagByName(recordLocationFlag);
        await db!.upsertConfigFlag(existingFlag!.copyWith(status: false));

        final emittedFlagsFuture = db!.watchConfigFlags().take(2).toList();
        await db!.toggleConfigFlag(recordLocationFlag);
        final emittedFlags = await emittedFlagsFuture;
        final initialFlags = emittedFlags.first;
        expect(
          db!.findConfigFlag(recordLocationFlag, initialFlags.toList()),
          false,
        );
        final updatedFlags = emittedFlags.last;

        expect(
          db!.findConfigFlag(recordLocationFlag, updatedFlags.toList()),
          true,
        );
      },
    );

    test(
      'watchActiveConfigFlagNames returns active flag names correctly',
      () async {
        final existingFlag = await db!.getConfigFlagByName(recordLocationFlag);
        await db!.upsertConfigFlag(existingFlag!.copyWith(status: false));

        final emittedFlagsFuture = db!
            .watchActiveConfigFlagNames()
            .take(2)
            .toList();
        await db!.toggleConfigFlag(recordLocationFlag);
        final emittedFlags = await emittedFlagsFuture;
        final activeFlags = emittedFlags.first;
        expect(activeFlags, expectedActiveFlagNames);
        final updatedFlags = emittedFlags.last;
        expect(updatedFlags, {...expectedActiveFlagNames, recordLocationFlag});
      },
    );

    test(
      'findConfigFlag finds config flag status correctly',
      () async {
        final flags = await db?.listConfigFlags().get();
        expect(flags, isNotNull);

        final result = db?.findConfigFlag(privateFlag, flags!);
        expect(result, true);

        final result2 = db?.findConfigFlag(recordLocationFlag, flags!);
        expect(result2, false);

        final result3 = db?.findConfigFlag('non-existent-flag', flags!);
        expect(result3, false);
      },
    );

    test(
      'getConfigFlag retrieves flag value correctly',
      () async {
        expect(await db?.getConfigFlag(privateFlag), true);
        expect(await db?.getConfigFlag(recordLocationFlag), false);
        expect(await db?.getConfigFlag('non-existent-flag'), false);
      },
    );

    test(
      'upsertConfigFlag updates existing flag or inserts new one',
      () async {
        // Update existing flag
        const newFlag = ConfigFlag(
          name: recordLocationFlag,
          description: 'Record geolocation?',
          status: true,
        );

        await db?.upsertConfigFlag(newFlag);
        expect(
          await db?.getConfigFlagByName(recordLocationFlag),
          newFlag,
        );

        // Insert new flag
        const customFlag = ConfigFlag(
          name: 'custom_flag_test',
          description: 'Custom flag for testing',
          status: true,
        );

        await db?.upsertConfigFlag(customFlag);
        expect(
          await db?.getConfigFlagByName('custom_flag_test'),
          customFlag,
        );
      },
    );

    test(
      'insertFlagIfNotExists inserts only if flag does not exist',
      () async {
        // Try to insert existing flag with different status
        const existingFlag = ConfigFlag(
          name: privateFlag,
          description: 'Show private entries?',
          status: false, // Original is true
        );

        await db?.insertFlagIfNotExists(existingFlag);

        // Should still have the original value
        expect(
          await db?.getConfigFlagByName(privateFlag),
          const ConfigFlag(
            name: privateFlag,
            description: 'Show private entries?',
            status: true,
          ),
        );

        // Insert a new flag
        const newTestFlag = ConfigFlag(
          name: 'test_new_flag',
          description: 'Test new flag insertion',
          status: true,
        );

        await db?.insertFlagIfNotExists(newTestFlag);
        expect(
          await db?.getConfigFlagByName('test_new_flag'),
          newTestFlag,
        );
      },
    );

    group('Journal Entity Operations -', () {
      test('updateJournalEntity creates new entity', () async {
        final entry = createJournalEntry('Test entry');
        final result = await db!.updateJournalEntity(entry);

        expect(result.applied, isTrue); // entity persisted
        expect(result.rowsWritten, 1);

        final retrieved = await db?.journalEntityById(entry.meta.id);
        expect(retrieved, isNotNull);
        expect(retrieved?.meta.id, entry.meta.id);
        expect(retrieved?.meta.dateFrom, isA<DateTime>());
      });

      test('updateJournalEntity updates existing entity', () async {
        final entry = createJournalEntry('Original text');
        await db!.updateJournalEntity(entry);

        // Create modified entry with same ID
        final testDate = DateTime(2024, 3, 15, 11);
        final updatedEntry = JournalEntity.journalEntry(
          meta: Metadata(
            id: entry.meta.id,
            createdAt: entry.meta.createdAt,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
            starred: true,
            private: false,
          ),
          entryText: const EntryText(plainText: 'Updated text'),
        );

        final result = await db!.updateJournalEntity(updatedEntry);
        expect(result.applied, isTrue);
        expect(result.rowsWritten, 1);

        final retrieved = await db?.journalEntityById(entry.meta.id);
        expect(retrieved, isNotNull);
        expect(retrieved?.meta.starred, true);
      });

      test(
        'updateJournalEntity with overwrite=false does not update',
        () async {
          final entry = createJournalEntry('Original text');
          await db!.updateJournalEntity(entry);

          // Create modified entry with same ID
          final testDate = DateTime(2024, 3, 15, 12);
          final updatedEntry = JournalEntity.journalEntry(
            meta: Metadata(
              id: entry.meta.id,
              createdAt: entry.meta.createdAt,
              updatedAt: testDate,
              dateFrom: testDate,
              dateTo: testDate,
              starred: true,
              private: false,
            ),
            entryText: const EntryText(plainText: 'Updated text'),
          );

          final result = await db!.updateJournalEntity(
            updatedEntry,
            overwrite: false,
          );

          expect(result.applied, isFalse); // No change
          expect(result.skipReason, JournalUpdateSkipReason.overwritePrevented);

          final retrieved = await db?.journalEntityById(entry.meta.id);
          expect(retrieved?.meta.starred, false);
        },
      );
    });

    group('Conflict Handling -', () {
      test('detectConflict detects concurrent vector clocks', () async {
        DevLogger.clear();

        // Create two entities with concurrent vector clocks
        const vclockA = VectorClock(<String, int>{'device1': 1, 'device2': 1});
        const vclockB = VectorClock(<String, int>{'device1': 2, 'device3': 1});

        final entryA = createJournalEntryWithVclock(vclockA);
        final entryB = createJournalEntryWithVclock(
          vclockB,
          id: entryA.meta.id,
        );

        // First insert A
        await db!.updateJournalEntity(entryA);

        // Try to update with B, should detect conflict
        final status = await db?.detectConflict(entryA, entryB);
        expect(status, VclockStatus.concurrent);

        // Check that a conflict was created
        final conflict = await db?.conflictById(entryA.meta.id);
        expect(conflict, isNotNull);
        expect(conflict?.status, ConflictStatus.unresolved.index);

        // The serialized entity should be B
        final serializedEntity = jsonDecode(conflict!.serialized);
        // ignore: avoid_dynamic_calls
        expect(serializedEntity['meta']['id'], entryA.meta.id);

        // Verify DevLogger.warning was called for conflicting vector clocks
        expect(
          DevLogger.capturedLogs.any(
            (log) =>
                log.contains('JournalDb') &&
                log.contains('Conflicting vector clocks'),
          ),
          isTrue,
          reason: 'Should log warning for conflicting vector clocks',
        );
      });

      test('updateJournalEntity respects vector clock ordering', () async {
        // Create two entities with B > A vector clocks
        const vclockA = VectorClock(<String, int>{'device1': 1});
        const vclockB = VectorClock(<String, int>{'device1': 2});

        final entryA = createJournalEntryWithVclock(vclockA);
        final entryB = createJournalEntryWithVclock(
          vclockB,
          id: entryA.meta.id,
        );

        // First insert A
        await db!.updateJournalEntity(entryA);

        // Update with B, should succeed
        final result = await db!.updateJournalEntity(entryB);
        expect(result.applied, isTrue);
        expect(result.rowsWritten, 1);

        // Retrieve - should be B
        final retrieved = await db?.journalEntityById(entryA.meta.id);
        expect(retrieved?.meta.id, entryA.meta.id);

        // Now try to update with A again (lower vclock), should fail
        final result2 = await db!.updateJournalEntity(entryA);
        expect(result2.applied, isFalse);
        expect(result2.skipReason, JournalUpdateSkipReason.olderOrEqual);

        // Retrieve - should still be B
        final stillB = await db?.journalEntityById(entryA.meta.id);
        expect(stillB?.meta.id, entryA.meta.id);

        // We can override with overrideComparison
        final result3 = await db!.updateJournalEntity(
          entryA,
          overrideComparison: true,
        );
        expect(result3.applied, isTrue);

        // Now it should be A
        final nowA = await db?.journalEntityById(entryA.meta.id);
        expect(nowA?.meta.id, entryA.meta.id);
      });

      test('resolves existing conflict when applying newer update', () async {
        const staleClock = VectorClock(<String, int>{'device1': 1});
        const freshClock = VectorClock(<String, int>{'device1': 2});

        final existingEntry = createJournalEntryWithVclock(staleClock);
        await db!.updateJournalEntity(existingEntry);

        final conflict = Conflict(
          id: existingEntry.meta.id,
          createdAt: DateTime(2024, 3, 15, 10),
          updatedAt: DateTime(2024, 3, 15, 10),
          serialized: jsonEncode(existingEntry),
          schemaVersion: db!.schemaVersion,
          status: ConflictStatus.unresolved.index,
        );
        await db!.addConflict(conflict);

        final updatedEntry = createJournalEntryWithVclock(
          freshClock,
          id: existingEntry.meta.id,
        );
        final result = await db!.updateJournalEntity(updatedEntry);

        expect(result.applied, isTrue);
        final resolved = await db!.conflictById(existingEntry.meta.id);
        expect(resolved, isNotNull);
        expect(resolved?.status, ConflictStatus.resolved.index);
      });

      test('does not resolve conflict when update is skipped', () async {
        const freshClock = VectorClock(<String, int>{'device1': 2});
        const staleClock = VectorClock(<String, int>{'device1': 1});

        final appliedEntry = createJournalEntryWithVclock(freshClock);
        await db!.updateJournalEntity(appliedEntry);

        final conflict = Conflict(
          id: appliedEntry.meta.id,
          createdAt: DateTime(2024, 3, 15, 11),
          updatedAt: DateTime(2024, 3, 15, 11),
          serialized: jsonEncode(appliedEntry),
          schemaVersion: db!.schemaVersion,
          status: ConflictStatus.unresolved.index,
        );
        await db!.addConflict(conflict);

        final skippedEntry = createJournalEntryWithVclock(
          staleClock,
          id: appliedEntry.meta.id,
        );

        final result = await db!.updateJournalEntity(skippedEntry);

        expect(result.applied, isFalse);
        expect(result.skipReason, JournalUpdateSkipReason.olderOrEqual);

        final unresolved = await db!.conflictById(appliedEntry.meta.id);
        expect(unresolved, isNotNull);
        expect(unresolved?.status, ConflictStatus.unresolved.index);
      });
    });

    group('Label reconciliation -', () {
      test('addLabeled mirrors metadata labelIds changes', () async {
        // Ensure label definitions exist to satisfy the labeled.label_id FK
        await db!.upsertLabelDefinition(
          LabelDefinition(
            id: 'alpha',
            createdAt: DateTime(2024, 3, 15, 10),
            updatedAt: DateTime(2024, 3, 15, 10),
            name: 'alpha',
            color: '#AAAAAA',
            vectorClock: null,
          ),
        );
        await db!.upsertLabelDefinition(
          LabelDefinition(
            id: 'beta',
            createdAt: DateTime(2024, 3, 15, 10),
            updatedAt: DateTime(2024, 3, 15, 10),
            name: 'beta',
            color: '#BBBBBB',
            vectorClock: null,
          ),
        );
        await db!.upsertLabelDefinition(
          LabelDefinition(
            id: 'gamma',
            createdAt: DateTime(2024, 3, 15, 10),
            updatedAt: DateTime(2024, 3, 15, 10),
            name: 'gamma',
            color: '#CCCCCC',
            vectorClock: null,
          ),
        );
        final entry = createJournalEntry(
          'with labels',
          labelIds: const ['alpha', 'beta'],
        );

        await db!.updateJournalEntity(entry);

        final initial = await db!.labeledForJournal(entry.meta.id).get();
        expect(initial, unorderedEquals(['alpha', 'beta']));

        final updated = entry.copyWith(
          meta: entry.meta.copyWith(
            labelIds: const ['beta', 'gamma'],
            updatedAt: DateTime(2024, 3, 15, 10, 1),
          ),
        );

        await db!.updateJournalEntity(updated);

        final afterUpdate = await db!.labeledForJournal(entry.meta.id).get();
        expect(afterUpdate, unorderedEquals(['beta', 'gamma']));

        final cleared = updated.copyWith(
          meta: updated.meta.copyWith(
            labelIds: null,
            updatedAt: DateTime(2024, 3, 15, 10, 2),
          ),
        );

        await db!.updateJournalEntity(cleared);

        final afterClear = await db!.labeledForJournal(entry.meta.id).get();
        expect(afterClear, isEmpty);
      });

      test('addLabeled is idempotent when metadata is unchanged', () async {
        // Ensure label definition exists to satisfy FK
        await db!.upsertLabelDefinition(
          LabelDefinition(
            id: 'keep',
            createdAt: DateTime(2024, 3, 15, 10),
            updatedAt: DateTime(2024, 3, 15, 10),
            name: 'keep',
            color: '#DDDDDD',
            vectorClock: null,
          ),
        );
        final entry = createJournalEntry(
          'idempotent labels',
          labelIds: const ['keep'],
        );

        await db!.updateJournalEntity(entry);
        await db!.updateJournalEntity(entry);

        final rows = await db!.labeledForJournal(entry.meta.id).get();
        expect(rows, unorderedEquals(['keep']));
      });
    });

    group('getTaskEstimatesByIds -', () {
      test('returns empty map for empty input', () async {
        final result = await db!.getTaskEstimatesByIds({});
        expect(result, isEmpty);
      });

      test('returns Duration for task with estimate', () async {
        final base = DateTime(2024, 8, 2);
        final task = buildTaskEntry(
          id: 'task-with-estimate',
          timestamp: base,
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: base,
            utcOffset: 60,
          ),
        );
        // buildTaskEntry copies testTask.data which has estimate: Duration(hours: 4)
        await db!.upsertJournalDbEntity(toDbEntity(task));

        final result = await db!.getTaskEstimatesByIds({'task-with-estimate'});
        expect(result, hasLength(1));
        expect(result['task-with-estimate'], const Duration(hours: 4));
      });

      test('returns null for task without estimate', () async {
        final base = DateTime(2024, 8, 2);
        final taskNoEstimate = JournalEntity.task(
          meta: Metadata(
            id: 'task-no-estimate',
            createdAt: base,
            updatedAt: base,
            dateFrom: base,
            dateTo: base,
            starred: false,
            private: false,
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-2',
              createdAt: base,
              utcOffset: 60,
            ),
            title: 'Task without estimate',
            statusHistory: [],
            dateFrom: base,
            dateTo: base,
          ),
          entryText: const EntryText(plainText: 'No estimate task'),
        );
        await db!.upsertJournalDbEntity(toDbEntity(taskNoEstimate));

        final result = await db!.getTaskEstimatesByIds({'task-no-estimate'});
        expect(result, hasLength(1));
        expect(result['task-no-estimate'], isNull);
      });

      test('excludes non-task entities', () async {
        final base = DateTime(2024, 8, 2);
        final journalEntry = buildJournalEntry(
          id: 'not-a-task',
          timestamp: base,
          text: 'Just a journal entry',
        );
        await db!.upsertJournalDbEntity(toDbEntity(journalEntry));

        final result = await db!.getTaskEstimatesByIds({'not-a-task'});
        expect(result, isEmpty);
      });

      test('returns mix of tasks with and without estimates', () async {
        final base = DateTime(2024, 8, 2);
        final taskWithEstimate = buildTaskEntry(
          id: 'task-est-yes',
          timestamp: base,
          status: TaskStatus.open(
            id: 'status-3',
            createdAt: base,
            utcOffset: 60,
          ),
        );
        final taskWithoutEstimate = JournalEntity.task(
          meta: Metadata(
            id: 'task-est-no',
            createdAt: base,
            updatedAt: base,
            dateFrom: base,
            dateTo: base,
            starred: false,
            private: false,
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-4',
              createdAt: base,
              utcOffset: 60,
            ),
            title: 'No estimate',
            statusHistory: [],
            dateFrom: base,
            dateTo: base,
          ),
          entryText: const EntryText(plainText: 'No estimate'),
        );
        final notATask = buildJournalEntry(
          id: 'entry-not-task',
          timestamp: base,
          text: 'Not a task',
        );

        await db!.upsertJournalDbEntity(toDbEntity(taskWithEstimate));
        await db!.upsertJournalDbEntity(toDbEntity(taskWithoutEstimate));
        await db!.upsertJournalDbEntity(toDbEntity(notATask));

        final result = await db!.getTaskEstimatesByIds({
          'task-est-yes',
          'task-est-no',
          'entry-not-task',
        });
        expect(result, hasLength(2));
        expect(result['task-est-yes'], const Duration(hours: 4));
        expect(result['task-est-no'], isNull);
        expect(result.containsKey('entry-not-task'), isFalse);
      });
    });

    group('getBulkLinkedTimeSpans -', () {
      test('returns empty map for empty input', () async {
        final result = await db!.getBulkLinkedTimeSpans({});
        expect(result, isEmpty);
      });

      test('returns time spans for parent with linked journal entry', () async {
        final base = DateTime(2024, 8, 2);
        final parent = buildTaskEntry(
          id: 'ts-parent',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-status-1',
            createdAt: base,
            utcOffset: 60,
          ),
        );
        final child = buildJournalEntry(
          id: 'ts-child',
          timestamp: base.add(const Duration(hours: 1)),
          text: 'Time tracking entry',
        );

        await db!.upsertJournalDbEntity(toDbEntity(parent));
        await db!.upsertJournalDbEntity(toDbEntity(child));

        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'ts-link-1',
            fromId: parent.meta.id,
            toId: child.meta.id,
            timestamp: base,
          ),
        );

        final result = await db!.getBulkLinkedTimeSpans({'ts-parent'});
        expect(result, hasLength(1));
        expect(result['ts-parent'], hasLength(1));
        expect(result['ts-parent']!.first.id, 'ts-child');
        expect(
          result['ts-parent']!.first.dateFrom,
          base.add(const Duration(hours: 1)),
        );
        expect(
          result['ts-parent']!.first.dateTo,
          base.add(const Duration(hours: 1)),
        );
      });

      test('excludes tasks linked to parent', () async {
        final base = DateTime(2024, 8, 2);
        final parent = buildTaskEntry(
          id: 'ts-parent-excl',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-status-2',
            createdAt: base,
            utcOffset: 60,
          ),
        );
        final linkedTask = buildTaskEntry(
          id: 'ts-linked-task',
          timestamp: base.add(const Duration(hours: 1)),
          status: TaskStatus.open(
            id: 'ts-status-3',
            createdAt: base,
            utcOffset: 60,
          ),
        );
        final linkedEntry = buildJournalEntry(
          id: 'ts-linked-entry',
          timestamp: base.add(const Duration(hours: 2)),
          text: 'Regular entry',
        );

        await db!.upsertJournalDbEntity(toDbEntity(parent));
        await db!.upsertJournalDbEntity(toDbEntity(linkedTask));
        await db!.upsertJournalDbEntity(toDbEntity(linkedEntry));

        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'ts-link-task',
            fromId: parent.meta.id,
            toId: linkedTask.meta.id,
            timestamp: base,
          ),
        );
        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'ts-link-entry',
            fromId: parent.meta.id,
            toId: linkedEntry.meta.id,
            timestamp: base.add(const Duration(minutes: 1)),
          ),
        );

        final result = await db!.getBulkLinkedTimeSpans({'ts-parent-excl'});
        expect(result['ts-parent-excl'], hasLength(1));
        expect(result['ts-parent-excl']!.first.id, 'ts-linked-entry');
      });

      test('groups results by multiple parents', () async {
        final base = DateTime(2024, 8, 2);
        final parentA = buildTaskEntry(
          id: 'ts-multi-parent-a',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-status-4',
            createdAt: base,
            utcOffset: 60,
          ),
        );
        final parentB = buildTaskEntry(
          id: 'ts-multi-parent-b',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-status-5',
            createdAt: base,
            utcOffset: 60,
          ),
        );
        final childA = buildJournalEntry(
          id: 'ts-child-a',
          timestamp: base.add(const Duration(hours: 1)),
          text: 'Child of A',
        );
        final childB1 = buildJournalEntry(
          id: 'ts-child-b1',
          timestamp: base.add(const Duration(hours: 2)),
          text: 'First child of B',
        );
        final childB2 = buildJournalEntry(
          id: 'ts-child-b2',
          timestamp: base.add(const Duration(hours: 3)),
          text: 'Second child of B',
        );

        for (final entry in [parentA, parentB, childA, childB1, childB2]) {
          await db!.upsertJournalDbEntity(toDbEntity(entry));
        }

        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'ts-link-multi-a',
            fromId: parentA.meta.id,
            toId: childA.meta.id,
            timestamp: base,
          ),
        );
        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'ts-link-multi-b1',
            fromId: parentB.meta.id,
            toId: childB1.meta.id,
            timestamp: base,
          ),
        );
        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'ts-link-multi-b2',
            fromId: parentB.meta.id,
            toId: childB2.meta.id,
            timestamp: base.add(const Duration(minutes: 1)),
          ),
        );

        final result = await db!.getBulkLinkedTimeSpans({
          'ts-multi-parent-a',
          'ts-multi-parent-b',
        });
        expect(result['ts-multi-parent-a'], hasLength(1));
        expect(result['ts-multi-parent-a']!.first.id, 'ts-child-a');
        expect(result['ts-multi-parent-b'], hasLength(2));
        expect(
          result['ts-multi-parent-b']!.map((e) => e.id).toSet(),
          {'ts-child-b1', 'ts-child-b2'},
        );
      });

      test('respects private flag when private is disabled', () async {
        final base = DateTime(2024, 8, 2);
        final parent = buildTaskEntry(
          id: 'ts-priv-parent',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-status-6',
            createdAt: base,
            utcOffset: 60,
          ),
        );
        final publicChild = buildJournalEntry(
          id: 'ts-public-child',
          timestamp: base.add(const Duration(hours: 1)),
          text: 'Public child',
        );
        final privateChild = buildJournalEntry(
          id: 'ts-private-child',
          timestamp: base.add(const Duration(hours: 2)),
          text: 'Private child',
          privateFlag: true,
        );

        await db!.upsertJournalDbEntity(toDbEntity(parent));
        await db!.upsertJournalDbEntity(toDbEntity(publicChild));
        await db!.upsertJournalDbEntity(toDbEntity(privateChild));

        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'ts-link-pub',
            fromId: parent.meta.id,
            toId: publicChild.meta.id,
            timestamp: base,
          ),
        );
        await db!.upsertEntryLink(
          buildEntryLink(
            id: 'ts-link-priv',
            fromId: parent.meta.id,
            toId: privateChild.meta.id,
            timestamp: base.add(const Duration(minutes: 1)),
          ),
        );

        // Disable private flag
        final privateCfg = await db!.getConfigFlagByName(privateFlag);
        await db!.upsertConfigFlag(privateCfg!.copyWith(status: false));

        final result = await db!.getBulkLinkedTimeSpans({'ts-priv-parent'});
        expect(result['ts-priv-parent'], hasLength(1));
        expect(result['ts-priv-parent']!.first.id, 'ts-public-child');

        // Re-enable private flag to see both
        await db!.upsertConfigFlag(privateCfg.copyWith(status: true));

        final resultWithPrivate = await db!.getBulkLinkedTimeSpans({
          'ts-priv-parent',
        });
        expect(resultWithPrivate['ts-priv-parent'], hasLength(2));
      });
    });

    group('Project queries -', () {
      JournalEntity buildProjectEntry({
        required String id,
        required DateTime timestamp,
        bool privateFlag = false,
        String? categoryId,
      }) {
        return JournalEntity.project(
          meta: Metadata(
            id: id,
            createdAt: timestamp,
            updatedAt: timestamp,
            dateFrom: timestamp,
            dateTo: timestamp,
            private: privateFlag,
            categoryId: categoryId,
          ),
          data: ProjectData(
            title: 'Project $id',
            status: ProjectStatus.active(
              id: 'ps-$id',
              createdAt: timestamp,
              utcOffset: 0,
            ),
            dateFrom: timestamp,
            dateTo: timestamp,
          ),
        );
      }

      EntryLink buildProjectLink({
        required String id,
        required String fromId,
        required String toId,
        required DateTime timestamp,
        bool hidden = false,
      }) {
        return EntryLink.project(
          id: id,
          fromId: fromId,
          toId: toId,
          createdAt: timestamp,
          updatedAt: timestamp,
          vectorClock: const VectorClock({'db': 1}),
          hidden: hidden ? true : null,
          deletedAt: hidden ? timestamp : null,
        );
      }

      test('getProjectsForCategory returns projects in category', () async {
        final base = DateTime(2024, 7, 1);
        final p1 = buildProjectEntry(
          id: 'proj-cat-1',
          timestamp: base,
          categoryId: 'cat-a',
        );
        final p2 = buildProjectEntry(
          id: 'proj-cat-2',
          timestamp: base.add(const Duration(hours: 1)),
          categoryId: 'cat-a',
        );
        final p3 = buildProjectEntry(
          id: 'proj-other',
          timestamp: base,
          categoryId: 'cat-b',
        );

        await db!.upsertJournalDbEntity(toDbEntity(p1));
        await db!.upsertJournalDbEntity(toDbEntity(p2));
        await db!.upsertJournalDbEntity(toDbEntity(p3));

        final result = await db!.getProjectsForCategory('cat-a');

        expect(result, hasLength(2));
        expect(
          result.map((p) => p.meta.id).toSet(),
          {'proj-cat-1', 'proj-cat-2'},
        );
      });

      test('getProjectsForCategory excludes deleted projects', () async {
        final base = DateTime(2024, 7, 2);
        final active = buildProjectEntry(
          id: 'proj-active',
          timestamp: base,
          categoryId: 'cat-del',
        );
        final deleted = buildProjectEntry(
          id: 'proj-deleted',
          timestamp: base,
          categoryId: 'cat-del',
        );
        final deletedEntity = (deleted as ProjectEntry).copyWith(
          meta: deleted.meta.copyWith(deletedAt: base),
        );

        await db!.upsertJournalDbEntity(toDbEntity(active));
        await db!.upsertJournalDbEntity(toDbEntity(deletedEntity));

        final result = await db!.getProjectsForCategory('cat-del');

        expect(result, hasLength(1));
        expect(result.first.meta.id, 'proj-active');
      });

      test('getProjectsForCategory respects private flag', () async {
        final base = DateTime(2024, 7, 3);
        final publicProj = buildProjectEntry(
          id: 'proj-public',
          timestamp: base,
          categoryId: 'cat-priv',
        );
        final privateProj = buildProjectEntry(
          id: 'proj-private',
          timestamp: base,
          categoryId: 'cat-priv',
          privateFlag: true,
        );

        await db!.upsertJournalDbEntity(toDbEntity(publicProj));
        await db!.upsertJournalDbEntity(toDbEntity(privateProj));

        // Disable private entries
        await db!.upsertConfigFlag(
          const ConfigFlag(
            name: 'private',
            description: 'Show private entries?',
            status: false,
          ),
        );

        final result = await db!.getProjectsForCategory('cat-priv');
        expect(result, hasLength(1));
        expect(result.first.meta.id, 'proj-public');

        // Re-enable private entries
        await db!.upsertConfigFlag(
          const ConfigFlag(
            name: 'private',
            description: 'Show private entries?',
            status: true,
          ),
        );

        final resultWithPrivate = await db!.getProjectsForCategory('cat-priv');
        expect(resultWithPrivate, hasLength(2));
      });

      test('getTasksForProject returns linked tasks', () async {
        final base = DateTime(2024, 7, 4);
        final project = buildProjectEntry(
          id: 'proj-tasks',
          timestamp: base,
          categoryId: 'cat-t',
        );
        final task1 = buildTaskEntry(
          id: 'task-linked-1',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-l1',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'cat-t',
        );
        final task2 = buildTaskEntry(
          id: 'task-linked-2',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-l2',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'cat-t',
        );
        final unlinkedTask = buildTaskEntry(
          id: 'task-unlinked',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-u',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'cat-t',
        );

        await db!.upsertJournalDbEntity(toDbEntity(project));
        await db!.upsertJournalDbEntity(toDbEntity(task1));
        await db!.upsertJournalDbEntity(toDbEntity(task2));
        await db!.upsertJournalDbEntity(toDbEntity(unlinkedTask));

        // Link task1 and task2 to project
        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-1',
            fromId: 'proj-tasks',
            toId: 'task-linked-1',
            timestamp: base,
          ),
        );
        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-2',
            fromId: 'proj-tasks',
            toId: 'task-linked-2',
            timestamp: base,
          ),
        );

        final result = await db!.getTasksForProject('proj-tasks');

        expect(result, hasLength(2));
        expect(
          result.map((t) => t.meta.id).toSet(),
          {'task-linked-1', 'task-linked-2'},
        );
      });

      test('getTasksForProject excludes hidden links', () async {
        final base = DateTime(2024, 7, 5);
        final project = buildProjectEntry(
          id: 'proj-hidden',
          timestamp: base,
          categoryId: 'cat-h',
        );
        final task = buildTaskEntry(
          id: 'task-hidden-link',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-h',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'cat-h',
        );

        await db!.upsertJournalDbEntity(toDbEntity(project));
        await db!.upsertJournalDbEntity(toDbEntity(task));

        // Create a hidden (soft-deleted) link
        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-hidden',
            fromId: 'proj-hidden',
            toId: 'task-hidden-link',
            timestamp: base,
            hidden: true,
          ),
        );

        final result = await db!.getTasksForProject('proj-hidden');

        expect(result, isEmpty);
      });

      test('getTasksForProject only returns Task type entities', () async {
        final base = DateTime(2024, 7, 6);
        final project = buildProjectEntry(
          id: 'proj-type-guard',
          timestamp: base,
          categoryId: 'cat-tg',
        );
        final task = buildTaskEntry(
          id: 'task-type-guard',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-tg',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'cat-tg',
        );
        // A non-task entity linked with a ProjectLink
        final note = createJournalEntry('note body', id: 'note-type-guard');

        await db!.upsertJournalDbEntity(toDbEntity(project));
        await db!.upsertJournalDbEntity(toDbEntity(task));
        await db!.upsertJournalDbEntity(toDbEntity(note));

        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-task',
            fromId: 'proj-type-guard',
            toId: 'task-type-guard',
            timestamp: base,
          ),
        );
        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-note',
            fromId: 'proj-type-guard',
            toId: 'note-type-guard',
            timestamp: base,
          ),
        );

        final result = await db!.getTasksForProject('proj-type-guard');

        // Only the Task should be returned, not the note
        expect(result, hasLength(1));
        expect(result.first.meta.id, 'task-type-guard');
      });

      test('getTasksForProject respects private flag', () async {
        final base = DateTime(2024, 7, 13);
        final project = buildProjectEntry(
          id: 'proj-task-priv',
          timestamp: base,
          categoryId: 'cat-tp',
        );
        final publicTask = buildTaskEntry(
          id: 'task-public-tp',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-pub-tp',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'cat-tp',
        );
        final privateTask = buildTaskEntry(
          id: 'task-private-tp',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-priv-tp',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'cat-tp',
          privateFlag: true,
        );

        await db!.upsertJournalDbEntity(toDbEntity(project));
        await db!.upsertJournalDbEntity(toDbEntity(publicTask));
        await db!.upsertJournalDbEntity(toDbEntity(privateTask));

        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-pub-tp',
            fromId: 'proj-task-priv',
            toId: 'task-public-tp',
            timestamp: base,
          ),
        );
        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-priv-tp',
            fromId: 'proj-task-priv',
            toId: 'task-private-tp',
            timestamp: base,
          ),
        );

        // Disable private entries
        await db!.upsertConfigFlag(
          const ConfigFlag(
            name: 'private',
            description: 'Show private entries?',
            status: false,
          ),
        );

        final result = await db!.getTasksForProject('proj-task-priv');
        expect(result, hasLength(1));
        expect(result.first.meta.id, 'task-public-tp');

        // Re-enable private entries
        await db!.upsertConfigFlag(
          const ConfigFlag(
            name: 'private',
            description: 'Show private entries?',
            status: true,
          ),
        );

        final resultWithPrivate = await db!.getTasksForProject(
          'proj-task-priv',
        );
        expect(resultWithPrivate, hasLength(2));
      });

      test('getProjectForTask returns linked project', () async {
        final base = DateTime(2024, 7, 7);
        final project = buildProjectEntry(
          id: 'proj-for-task',
          timestamp: base,
          categoryId: 'cat-ft',
        );
        final task = buildTaskEntry(
          id: 'task-has-project',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-ft',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'cat-ft',
        );

        await db!.upsertJournalDbEntity(toDbEntity(project));
        await db!.upsertJournalDbEntity(toDbEntity(task));
        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-ft',
            fromId: 'proj-for-task',
            toId: 'task-has-project',
            timestamp: base,
          ),
        );

        final result = await db!.getProjectForTask('task-has-project');

        expect(result, isNotNull);
        expect(result!.meta.id, 'proj-for-task');
        expect(result.data.title, 'Project proj-for-task');
      });

      test('getProjectForTask returns null for unlinked task', () async {
        final result = await db!.getProjectForTask('nonexistent-task');
        expect(result, isNull);
      });

      test('getProjectForTask excludes hidden links', () async {
        final base = DateTime(2024, 7, 8);
        final project = buildProjectEntry(
          id: 'proj-hidden-ft',
          timestamp: base,
          categoryId: 'cat-hft',
        );
        final task = buildTaskEntry(
          id: 'task-hidden-ft',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-hft',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'cat-hft',
        );

        await db!.upsertJournalDbEntity(toDbEntity(project));
        await db!.upsertJournalDbEntity(toDbEntity(task));
        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-hft',
            fromId: 'proj-hidden-ft',
            toId: 'task-hidden-ft',
            timestamp: base,
            hidden: true,
          ),
        );

        final result = await db!.getProjectForTask('task-hidden-ft');
        expect(result, isNull);
      });

      test('getProjectForTask respects private flag', () async {
        final base = DateTime(2024, 7, 9);
        final privateProject = buildProjectEntry(
          id: 'proj-priv-ft',
          timestamp: base,
          categoryId: 'cat-pft',
          privateFlag: true,
        );
        final task = buildTaskEntry(
          id: 'task-priv-ft',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-pft',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'cat-pft',
        );

        await db!.upsertJournalDbEntity(toDbEntity(privateProject));
        await db!.upsertJournalDbEntity(toDbEntity(task));
        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-pft',
            fromId: 'proj-priv-ft',
            toId: 'task-priv-ft',
            timestamp: base,
          ),
        );

        // Disable private entries
        await db!.upsertConfigFlag(
          const ConfigFlag(
            name: 'private',
            description: 'Show private entries?',
            status: false,
          ),
        );

        final result = await db!.getProjectForTask('task-priv-ft');
        expect(result, isNull);

        // Re-enable private entries
        await db!.upsertConfigFlag(
          const ConfigFlag(
            name: 'private',
            description: 'Show private entries?',
            status: true,
          ),
        );

        final resultWithPrivate = await db!.getProjectForTask('task-priv-ft');
        expect(resultWithPrivate, isNotNull);
        expect(resultWithPrivate!.meta.id, 'proj-priv-ft');
      });

      test(
        'getExistingProjectIds returns only live project ids and handles empty input',
        () async {
          expect(await db!.getExistingProjectIds({}), isEmpty);

          final base = DateTime(2024, 7, 10);
          final activeProject = buildProjectEntry(
            id: 'proj-existing-live',
            timestamp: base,
            categoryId: 'cat-existing',
          );
          final deletedProjectBase =
              buildProjectEntry(
                    id: 'proj-existing-deleted',
                    timestamp: base.add(const Duration(minutes: 1)),
                    categoryId: 'cat-existing',
                  )
                  as ProjectEntry;
          final deletedProject = deletedProjectBase.copyWith(
            meta: deletedProjectBase.meta.copyWith(
              deletedAt: base.add(const Duration(minutes: 2)),
            ),
          );
          final task = buildTaskEntry(
            id: 'task-existing-ignore',
            timestamp: base,
            status: TaskStatus.open(
              id: 'ts-existing-ignore',
              createdAt: base,
              utcOffset: 0,
            ),
            categoryId: 'cat-existing',
          );

          await db!.upsertJournalDbEntity(toDbEntity(activeProject));
          await db!.upsertJournalDbEntity(toDbEntity(deletedProject));
          await db!.upsertJournalDbEntity(toDbEntity(task));

          final result = await db!.getExistingProjectIds({
            'proj-existing-live',
            'proj-existing-deleted',
            'task-existing-ignore',
            'proj-missing',
          });

          expect(result, {'proj-existing-live'});
        },
      );

      test(
        'getProjectIdsForTaskIds returns distinct live project ids and ignores non-tasks',
        () async {
          expect(await db!.getProjectIdsForTaskIds({}), isEmpty);

          final base = DateTime(2024, 7, 11);
          final projectOne = buildProjectEntry(
            id: 'proj-task-lookup-1',
            timestamp: base,
            categoryId: 'cat-lookup',
          );
          final projectTwo = buildProjectEntry(
            id: 'proj-task-lookup-2',
            timestamp: base.add(const Duration(minutes: 1)),
            categoryId: 'cat-lookup',
          );
          final projectDeletedTarget = buildProjectEntry(
            id: 'proj-deleted-target',
            timestamp: base.add(const Duration(minutes: 5)),
            categoryId: 'cat-lookup',
          );
          final projectNoteTarget = buildProjectEntry(
            id: 'proj-note-target',
            timestamp: base.add(const Duration(minutes: 6)),
            categoryId: 'cat-lookup',
          );
          final linkedTaskOne = buildTaskEntry(
            id: 'task-project-one-a',
            timestamp: base,
            status: TaskStatus.open(
              id: 'ts-project-one-a',
              createdAt: base,
              utcOffset: 0,
            ),
            categoryId: 'cat-lookup',
          );
          final linkedTaskTwo = buildTaskEntry(
            id: 'task-project-one-b',
            timestamp: base.add(const Duration(minutes: 1)),
            status: TaskStatus.open(
              id: 'ts-project-one-b',
              createdAt: base.add(const Duration(minutes: 1)),
              utcOffset: 0,
            ),
            categoryId: 'cat-lookup',
          );
          final linkedTaskThree = buildTaskEntry(
            id: 'task-project-two',
            timestamp: base.add(const Duration(minutes: 2)),
            status: TaskStatus.open(
              id: 'ts-project-two',
              createdAt: base.add(const Duration(minutes: 2)),
              utcOffset: 0,
            ),
            categoryId: 'cat-lookup',
          );
          final unlinkedTask = buildTaskEntry(
            id: 'task-without-project',
            timestamp: base.add(const Duration(minutes: 3)),
            status: TaskStatus.open(
              id: 'ts-without-project',
              createdAt: base.add(const Duration(minutes: 3)),
              utcOffset: 0,
            ),
            categoryId: 'cat-lookup',
          );
          final deletedTaskBase =
              buildTaskEntry(
                    id: 'task-deleted-project',
                    timestamp: base.add(const Duration(minutes: 4)),
                    status: TaskStatus.open(
                      id: 'ts-deleted-project',
                      createdAt: base.add(const Duration(minutes: 4)),
                      utcOffset: 0,
                    ),
                    categoryId: 'cat-lookup',
                  )
                  as Task;
          final deletedTask = deletedTaskBase.copyWith(
            meta: deletedTaskBase.meta.copyWith(
              deletedAt: base.add(const Duration(minutes: 5)),
            ),
          );
          final note = createJournalEntry(
            'linked note body',
            id: 'note-linked-to-project',
          );

          await db!.upsertJournalDbEntity(toDbEntity(projectOne));
          await db!.upsertJournalDbEntity(toDbEntity(projectTwo));
          await db!.upsertJournalDbEntity(toDbEntity(projectDeletedTarget));
          await db!.upsertJournalDbEntity(toDbEntity(projectNoteTarget));
          await db!.upsertJournalDbEntity(toDbEntity(linkedTaskOne));
          await db!.upsertJournalDbEntity(toDbEntity(linkedTaskTwo));
          await db!.upsertJournalDbEntity(toDbEntity(linkedTaskThree));
          await db!.upsertJournalDbEntity(toDbEntity(unlinkedTask));
          await db!.upsertJournalDbEntity(toDbEntity(deletedTask));
          await db!.upsertJournalDbEntity(toDbEntity(note));

          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-project-one-a',
              fromId: 'proj-task-lookup-1',
              toId: 'task-project-one-a',
              timestamp: base,
            ),
          );
          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-project-one-b',
              fromId: 'proj-task-lookup-1',
              toId: 'task-project-one-b',
              timestamp: base.add(const Duration(minutes: 1)),
            ),
          );
          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-project-two',
              fromId: 'proj-task-lookup-2',
              toId: 'task-project-two',
              timestamp: base.add(const Duration(minutes: 2)),
            ),
          );
          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-project-deleted',
              fromId: 'proj-deleted-target',
              toId: 'task-deleted-project',
              timestamp: base.add(const Duration(minutes: 3)),
            ),
          );
          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-project-note',
              fromId: 'proj-note-target',
              toId: 'note-linked-to-project',
              timestamp: base.add(const Duration(minutes: 4)),
            ),
          );

          final result = await db!.getProjectIdsForTaskIds({
            'task-project-one-a',
            'task-project-one-b',
            'task-project-two',
            'task-without-project',
            'task-deleted-project',
            'note-linked-to-project',
            'task-missing',
          });

          expect(result, {'proj-task-lookup-1', 'proj-task-lookup-2'});
        },
      );

      test('getProjectLinkForTask returns active link', () async {
        final base = DateTime(2024, 7, 10);
        final link = buildProjectLink(
          id: 'pl-link-ft',
          fromId: 'proj-link-ft',
          toId: 'task-link-ft',
          timestamp: base,
        );

        await db!.upsertEntryLink(link);

        final result = await db!.getProjectLinkForTask('task-link-ft');

        expect(result, isNotNull);
        expect(result, isA<ProjectLink>());
        expect(result!.fromId, 'proj-link-ft');
        expect(result.toId, 'task-link-ft');
      });

      test('getProjectLinkForTask returns null for hidden link', () async {
        final base = DateTime(2024, 7, 11);
        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-hidden-link',
            fromId: 'proj-hidden-link',
            toId: 'task-hidden-link',
            timestamp: base,
            hidden: true,
          ),
        );

        final result = await db!.getProjectLinkForTask('task-hidden-link');
        expect(result, isNull);
      });

      test('getProjectLinkForTask returns null for no link', () async {
        final result = await db!.getProjectLinkForTask('no-link-task');
        expect(result, isNull);
      });

      test(
        'getProjectLinkForTask returns most recently updated link',
        () async {
          final base = DateTime(2024, 7, 12);
          // Create two active links (shouldn't normally happen, but tests
          // deterministic ordering)
          await db!.upsertEntryLink(
            EntryLink.project(
              id: 'pl-older',
              fromId: 'proj-older',
              toId: 'task-determ',
              createdAt: base,
              updatedAt: base,
              vectorClock: const VectorClock({'db': 1}),
            ),
          );
          await db!.upsertEntryLink(
            EntryLink.project(
              id: 'pl-newer',
              fromId: 'proj-newer',
              toId: 'task-determ',
              createdAt: base,
              updatedAt: base.add(const Duration(hours: 1)),
              vectorClock: const VectorClock({'db': 2}),
            ),
          );

          final result = await db!.getProjectLinkForTask('task-determ');

          expect(result, isNotNull);
          // Should return the most recently updated link
          expect(result!.fromId, 'proj-newer');
        },
      );

      test(
        'getVisibleProjects returns non-deleted projects ordered by '
        'dateFrom desc',
        () async {
          final base = DateTime(2024, 8, 1);
          final p1 = buildProjectEntry(
            id: 'proj-vis-1',
            timestamp: base,
            categoryId: 'cat-vis',
          );
          final p2 = buildProjectEntry(
            id: 'proj-vis-2',
            timestamp: base.add(const Duration(hours: 2)),
            categoryId: 'cat-vis',
          );
          final p3 = buildProjectEntry(
            id: 'proj-vis-3',
            timestamp: base.add(const Duration(hours: 1)),
            categoryId: 'cat-vis-other',
          );
          final deletedBase =
              buildProjectEntry(
                    id: 'proj-vis-deleted',
                    timestamp: base.add(const Duration(hours: 3)),
                    categoryId: 'cat-vis',
                  )
                  as ProjectEntry;
          final deletedProject = deletedBase.copyWith(
            meta: deletedBase.meta.copyWith(
              deletedAt: base.add(const Duration(hours: 4)),
            ),
          );

          await db!.upsertJournalDbEntity(toDbEntity(p1));
          await db!.upsertJournalDbEntity(toDbEntity(p2));
          await db!.upsertJournalDbEntity(toDbEntity(p3));
          await db!.upsertJournalDbEntity(toDbEntity(deletedProject));

          final result = await db!.getVisibleProjects();

          // Should exclude the deleted project
          final ids = result.map((p) => p.meta.id).toList();
          expect(ids, contains('proj-vis-1'));
          expect(ids, contains('proj-vis-2'));
          expect(ids, contains('proj-vis-3'));
          expect(ids, isNot(contains('proj-vis-deleted')));

          // Should be ordered by dateFrom descending
          final visIds = result
              .where(
                (p) => p.meta.id.startsWith('proj-vis-'),
              )
              .map((p) => p.meta.id)
              .toList();
          final idx1 = visIds.indexOf('proj-vis-2');
          final idx2 = visIds.indexOf('proj-vis-3');
          final idx3 = visIds.indexOf('proj-vis-1');
          expect(idx1, lessThan(idx2));
          expect(idx2, lessThan(idx3));
        },
      );

      test(
        'getProjectTaskRollups returns empty map for empty input',
        () async {
          final result = await db!.getProjectTaskRollups({});
          expect(result, isEmpty);
        },
      );

      test(
        'getProjectTaskRollups aggregates task counts by project',
        () async {
          final base = DateTime(2024, 8, 2);
          final project1 = buildProjectEntry(
            id: 'proj-rollup-1',
            timestamp: base,
            categoryId: 'cat-rollup',
          );
          final project2 = buildProjectEntry(
            id: 'proj-rollup-2',
            timestamp: base.add(const Duration(hours: 1)),
            categoryId: 'cat-rollup',
          );

          // Project 1 tasks: 1 DONE, 1 BLOCKED, 1 open
          final task1Done = buildTaskEntry(
            id: 'task-r1-done',
            timestamp: base,
            status: TaskStatus.done(
              id: 'ts-r1-done',
              createdAt: base,
              utcOffset: 0,
            ),
            categoryId: 'cat-rollup',
          );
          final task1Blocked = buildTaskEntry(
            id: 'task-r1-blocked',
            timestamp: base.add(const Duration(minutes: 1)),
            status: TaskStatus.blocked(
              id: 'ts-r1-blocked',
              createdAt: base.add(const Duration(minutes: 1)),
              utcOffset: 0,
              reason: 'waiting on dependency',
            ),
            categoryId: 'cat-rollup',
          );
          final task1Open = buildTaskEntry(
            id: 'task-r1-open',
            timestamp: base.add(const Duration(minutes: 2)),
            status: TaskStatus.open(
              id: 'ts-r1-open',
              createdAt: base.add(const Duration(minutes: 2)),
              utcOffset: 0,
            ),
            categoryId: 'cat-rollup',
          );

          // Project 2 tasks: 2 DONE
          final task2DoneA = buildTaskEntry(
            id: 'task-r2-done-a',
            timestamp: base.add(const Duration(minutes: 3)),
            status: TaskStatus.done(
              id: 'ts-r2-done-a',
              createdAt: base.add(const Duration(minutes: 3)),
              utcOffset: 0,
            ),
            categoryId: 'cat-rollup',
          );
          final task2DoneB = buildTaskEntry(
            id: 'task-r2-done-b',
            timestamp: base.add(const Duration(minutes: 4)),
            status: TaskStatus.done(
              id: 'ts-r2-done-b',
              createdAt: base.add(const Duration(minutes: 4)),
              utcOffset: 0,
            ),
            categoryId: 'cat-rollup',
          );

          // Insert all entities
          await db!.upsertJournalDbEntity(toDbEntity(project1));
          await db!.upsertJournalDbEntity(toDbEntity(project2));
          await db!.upsertJournalDbEntity(toDbEntity(task1Done));
          await db!.upsertJournalDbEntity(toDbEntity(task1Blocked));
          await db!.upsertJournalDbEntity(toDbEntity(task1Open));
          await db!.upsertJournalDbEntity(toDbEntity(task2DoneA));
          await db!.upsertJournalDbEntity(toDbEntity(task2DoneB));

          // Link tasks to projects
          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-r1-done',
              fromId: 'proj-rollup-1',
              toId: 'task-r1-done',
              timestamp: base,
            ),
          );
          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-r1-blocked',
              fromId: 'proj-rollup-1',
              toId: 'task-r1-blocked',
              timestamp: base.add(const Duration(minutes: 1)),
            ),
          );
          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-r1-open',
              fromId: 'proj-rollup-1',
              toId: 'task-r1-open',
              timestamp: base.add(const Duration(minutes: 2)),
            ),
          );
          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-r2-done-a',
              fromId: 'proj-rollup-2',
              toId: 'task-r2-done-a',
              timestamp: base.add(const Duration(minutes: 3)),
            ),
          );
          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-r2-done-b',
              fromId: 'proj-rollup-2',
              toId: 'task-r2-done-b',
              timestamp: base.add(const Duration(minutes: 4)),
            ),
          );

          final result = await db!.getProjectTaskRollups({
            'proj-rollup-1',
            'proj-rollup-2',
          });

          expect(result, hasLength(2));

          // Project 1: 3 total, 1 completed, 1 blocked
          final rollup1 = result['proj-rollup-1']!;
          expect(rollup1.totalTaskCount, 3);
          expect(rollup1.completedTaskCount, 1);
          expect(rollup1.blockedTaskCount, 1);

          // Project 2: 2 total, 2 completed, 0 blocked
          final rollup2 = result['proj-rollup-2']!;
          expect(rollup2.totalTaskCount, 2);
          expect(rollup2.completedTaskCount, 2);
          expect(rollup2.blockedTaskCount, 0);
        },
      );
    });

    test(
      'database operations are covered by tests',
      () async {
        // This test ensures that database operations are covered by tests
        expect(db, isNotNull);
        expect(await db?.listConfigFlags().get(), isNotNull);
        expect(await db?.watchConfigFlags().first, isNotNull);
      },
    );
  });
}

Future<File> createPlaceholderDbFile(Directory docDir) async {
  final dbFile = File('${docDir.path}/$journalDbFileName');
  if (!dbFile.existsSync()) {
    await dbFile.create(recursive: true);
  }
  await dbFile.writeAsBytes(const [0]);
  return dbFile;
}

Future<void> seedDeletedDatabaseContent(
  JournalDb database,
  DateTime deletionTime,
) async {
  final dashboard = testDashboardConfig.copyWith(
    id: 'dashboard-${deletionTime.millisecondsSinceEpoch}',
    createdAt: deletionTime,
    updatedAt: deletionTime,
    deletedAt: deletionTime,
  );
  final measurable = measurableWater.copyWith(
    id: 'measurable-${deletionTime.millisecondsSinceEpoch}',
    createdAt: deletionTime,
    updatedAt: deletionTime,
    deletedAt: deletionTime,
  );
  final journalEntry = buildTextEntry(
    id: 'deleted-${deletionTime.millisecondsSinceEpoch}',
    timestamp: deletionTime,
    text: 'Marked for purge',
    deletedAt: deletionTime,
  );

  await database.upsertDashboardDefinition(dashboard);
  await database.upsertMeasurableDataType(measurable);
  await database.updateJournalEntity(journalEntry);
}

JournalEntity buildTextEntry({
  required String id,
  required DateTime timestamp,
  required String text,
  DateTime? deletedAt,
  Duration duration = const Duration(minutes: 1),
}) {
  return JournalEntity.journalEntry(
    meta: Metadata(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp.add(duration),
      deletedAt: deletedAt,
      starred: false,
      private: false,
    ),
    entryText: EntryText(plainText: text),
  );
}

JournalEntity buildImageEntry({
  required String id,
  required DateTime timestamp,
  required String imageDirectory,
  required String imageFile,
  DateTime? deletedAt,
}) {
  return JournalEntity.journalImage(
    meta: Metadata(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp,
      deletedAt: deletedAt,
      starred: false,
      private: false,
    ),
    data: ImageData(
      imageId: id,
      imageFile: imageFile,
      imageDirectory: imageDirectory,
      capturedAt: timestamp,
    ),
    entryText: const EntryText(plainText: 'image entry'),
  );
}

JournalEntity buildAudioEntry({
  required String id,
  required DateTime timestamp,
  required String audioDirectory,
  required String audioFile,
  DateTime? deletedAt,
}) {
  return JournalEntity.journalAudio(
    meta: Metadata(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp,
      deletedAt: deletedAt,
      starred: false,
      private: false,
    ),
    data: AudioData(
      dateFrom: timestamp,
      dateTo: timestamp,
      duration: const Duration(minutes: 5),
      audioDirectory: audioDirectory,
      audioFile: audioFile,
    ),
    entryText: const EntryText(plainText: 'audio entry'),
  );
}

JournalEntity buildWorkoutEntry({
  required String id,
  required DateTime start,
  required DateTime end,
  DateTime? deletedAt,
}) {
  return JournalEntity.workout(
    meta: Metadata(
      id: id,
      createdAt: end,
      updatedAt: end,
      dateFrom: start,
      dateTo: end,
      deletedAt: deletedAt,
      starred: false,
      private: false,
    ),
    data: WorkoutData(
      distance: 1000,
      dateFrom: start,
      dateTo: end,
      workoutType: 'running',
      energy: 200,
      id: 'workout-$id',
      source: 'test',
    ),
  );
}

JournalEntity buildHabitCompletionEntry({
  required String id,
  required String habitId,
  required DateTime timestamp,
  DateTime? deletedAt,
}) {
  return JournalEntity.habitCompletion(
    meta: Metadata(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp,
      deletedAt: deletedAt,
      starred: false,
      private: false,
    ),
    data: HabitCompletionData(
      habitId: habitId,
      dateFrom: timestamp,
      dateTo: timestamp,
    ),
  );
}

JournalEntity buildQuantitativeEntry({
  required String id,
  required String dataType,
  required DateTime timestamp,
  double value = 1,
  DateTime? deletedAt,
}) {
  return JournalEntity.quantitative(
    meta: Metadata(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp,
      deletedAt: deletedAt,
      starred: false,
      private: false,
    ),
    data: QuantitativeData.discreteQuantityData(
      dateFrom: timestamp,
      dateTo: timestamp,
      value: value,
      dataType: dataType,
      unit: 'unit',
    ),
  );
}

class _PrecheckThrowingJournalDb extends JournalDb {
  _PrecheckThrowingJournalDb() : super(inMemoryDatabase: true);

  bool _shouldThrow = true;

  @override
  drift.SimpleSelectStatement<T, R> select<T extends drift.HasResultSet, R>(
    drift.ResultSetImplementation<T, R> table, {
    bool distinct = false,
  }) {
    if (_shouldThrow &&
        table is drift.TableInfo<LinkedEntries, LinkedDbEntry>) {
      _shouldThrow = false;
      throw StateError('precheck failure');
    }
    return super.select(table, distinct: distinct);
  }
}

// Helper functions to create test entities
final _testDate = DateTime(2024, 3, 15, 10, 30);

JournalEntity createJournalEntry(
  String text, {
  String? id,
  List<String>? labelIds,
}) {
  return JournalEntity.journalEntry(
    meta: Metadata(
      id: id ?? UniqueKey().toString(),
      createdAt: _testDate,
      updatedAt: _testDate,
      dateFrom: _testDate,
      dateTo: _testDate,
      starred: false,
      private: false,
      labelIds: labelIds,
    ),
    entryText: EntryText(plainText: text),
  );
}

JournalEntity createJournalEntryWithVclock(
  VectorClock vclock, {
  String? id,
  List<String>? labelIds,
}) {
  final entryId = id ?? UniqueKey().toString();

  return JournalEntity.journalEntry(
    meta: Metadata(
      id: entryId,
      createdAt: _testDate,
      updatedAt: _testDate,
      dateFrom: _testDate,
      dateTo: _testDate,
      vectorClock: vclock,
      starred: false,
      private: false,
      labelIds: labelIds,
    ),
    entryText: const EntryText(plainText: 'Entry with vector clock'),
  );
}

JournalEntity buildJournalEntry({
  required String id,
  required DateTime timestamp,
  required String text,
  bool starred = false,
  bool privateFlag = false,
  EntryFlag? flag,
  String? categoryId,
}) {
  return JournalEntity.journalEntry(
    meta: Metadata(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp,
      starred: starred,
      private: privateFlag,
      flag: flag,
      categoryId: categoryId,
    ),
    entryText: EntryText(plainText: text),
  );
}

JournalEntity buildTaskEntry({
  required String id,
  required DateTime timestamp,
  required TaskStatus status,
  String title = 'Task title',
  bool starred = false,
  bool privateFlag = false,
  String? categoryId,
  DateTime? due,
}) {
  return JournalEntity.task(
    meta: Metadata(
      id: id,
      createdAt: timestamp,
      updatedAt: timestamp,
      dateFrom: timestamp,
      dateTo: timestamp,
      starred: starred,
      private: privateFlag,
      categoryId: categoryId,
    ),
    data: testTask.data.copyWith(
      status: status,
      statusHistory: [status],
      dateFrom: timestamp,
      dateTo: timestamp,
      title: title,
      due: due,
    ),
    entryText: const EntryText(plainText: 'Task body'),
  );
}

EntryLink buildEntryLink({
  required String id,
  required String fromId,
  required String toId,
  required DateTime timestamp,
}) {
  return EntryLink.basic(
    id: id,
    fromId: fromId,
    toId: toId,
    createdAt: timestamp,
    updatedAt: timestamp,
    vectorClock: const VectorClock({'db': 1}),
  );
}

Future<List<JournalEntity>> fetchJournalEntities(
  JournalDb db, {
  required List<String> types,
  required List<bool> starredStatuses,
  required List<bool> privateStatuses,
  required List<int> flaggedStatuses,
  Set<String>? categoryIds,
  List<String>? ids,
}) {
  return db.getJournalEntities(
    types: types,
    starredStatuses: starredStatuses,
    privateStatuses: privateStatuses,
    flaggedStatuses: flaggedStatuses,
    ids: ids,
    categoryIds: categoryIds,
  );
}

class _DetectConflictThrowsJournalDb extends JournalDb {
  _DetectConflictThrowsJournalDb()
    : shouldThrowOnDetectConflict = false,
      super(inMemoryDatabase: true);

  bool shouldThrowOnDetectConflict;

  @override
  Future<VclockStatus> detectConflict(
    JournalEntity existing,
    JournalEntity updated,
  ) {
    if (shouldThrowOnDetectConflict) {
      throw StateError('detectConflict failed');
    }
    return super.detectConflict(existing, updated);
  }
}
