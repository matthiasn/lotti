// ignore_for_file: avoid_redundant_argument_values
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fallbacks.dart';
import '../mocks/mocks.dart';
import '../test_data/test_data.dart';

// Add missing mock classes
class MockLoggingService extends Mock implements LoggingService {}

// Setup a temp directory for testing
Directory setupTestDirectory() {
  final directory = Directory.systemTemp.createTempSync('lotti_test_');
  return directory;
}

final Set<String> expectedActiveFlagNames = {
  privateFlag,
  enableTooltipFlag,
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
    status: false,
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
    name: enableCalendarPageFlag,
    description: 'Enable Calendar Page?',
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
};

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(const Stream<Set<String>>.empty());
    registerFallbackValue(fallbackJournalEntity);
    registerFallbackValue(fallbackTagEntity);
    registerFallbackValue(EntryLink.basic(
      id: 'link-id',
      fromId: 'from',
      toId: 'to',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      vectorClock: null,
    ));
    registerFallbackValue(testTag1);
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
      test('does not rewrite JSON when update skipped by vector clock',
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

        final staleEntry = createJournalEntryWithVclock(
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
      });

      test('does not rewrite JSON when update prevented by overwrite=false',
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
      });
    });

    group('Edge cases -', () {
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

    group('Tagging helpers -', () {
      test('insertTag creates tagged association', () async {
        const journalId = 'journal-tagged';
        await db!.upsertTagEntity(testTag1);
        await db!.upsertJournalDbEntity(
          toDbEntity(
            testTextEntry.copyWith(
              meta: testTextEntry.meta.copyWith(id: journalId),
            ),
          ),
        );

        await db!.insertTag(journalId, testTag1.id);

        final rows = await db!.select(db!.tagged).get();
        expect(rows, hasLength(1));
        final taggedRow = rows.single;
        expect(taggedRow.journalId, journalId);
        expect(taggedRow.tagEntityId, testTag1.id);
      });

      test('insertTag ignores duplicate gracefully', () async {
        const journalId = 'journal-duplicate';
        await db!.upsertTagEntity(testTag1);
        await db!.upsertJournalDbEntity(
          toDbEntity(
            testTextEntry.copyWith(
              meta: testTextEntry.meta.copyWith(id: journalId),
            ),
          ),
        );

        await db!.insertTag(journalId, testTag1.id);
        await db!.insertTag(journalId, testTag1.id); // should be ignored

        final rows = await db!.select(db!.tagged).get();
        expect(rows, hasLength(1));
        expect(rows.single.tagEntityId, testTag1.id);
      });

      test('addTagged replaces existing tag associations', () async {
        const journalId = 'journal-add-tagged';
        await db!
            .upsertTagEntity(testTag1); // existing tag that will be removed
        await db!.upsertTagEntity(testStoryTag1);
        await db!.upsertTagEntity(testPersonTag1);
        await db!.upsertJournalDbEntity(
          toDbEntity(
            testTextEntry.copyWith(
              meta: testTextEntry.meta.copyWith(id: journalId),
            ),
          ),
        );

        await db!.insertTag(journalId, testTag1.id);

        final updatedEntity = testTextEntry.copyWith(
          meta: testTextEntry.meta.copyWith(
            id: journalId,
            tagIds: [
              testStoryTag1.id,
              testPersonTag1.id,
            ],
          ),
        );

        await db!.addTagged(updatedEntity);

        final rows = await db!.select(db!.tagged).get();
        expect(rows, hasLength(2));
        final tagIds = rows.map((row) => row.tagEntityId).toList();
        expect(tagIds, containsAll([testStoryTag1.id, testPersonTag1.id]));
        expect(tagIds, isNot(contains(testTag1.id)));
      });

      test('addTagged handles empty tag list by removing existing entries',
          () async {
        const journalId = 'journal-clear-tags';
        await db!.upsertTagEntity(testTag1);
        await db!.upsertJournalDbEntity(
          toDbEntity(
            testTextEntry.copyWith(
              meta: testTextEntry.meta.copyWith(id: journalId),
            ),
          ),
        );

        await db!.insertTag(journalId, testTag1.id);

        final noTagEntity = testTextEntry.copyWith(
          meta: testTextEntry.meta.copyWith(
            id: journalId,
            tagIds: const [],
          ),
        );

        await db!.addTagged(noTagEntity);

        final rows = await db!.select(db!.tagged).get();
        expect(rows, isEmpty);
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
            EntryFlag.followUpNeeded.index
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
            EntryFlag.followUpNeeded.index
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
            EntryFlag.followUpNeeded.index
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
            EntryFlag.followUpNeeded.index
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
            EntryFlag.followUpNeeded.index
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
    });

    group('Linked entities -', () {
      test('getLinkedEntities returns linked children sorted by recency',
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
      });

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

        expect(results[parentA.meta.id]!.map((e) => e.meta.id),
            ['bulk-child-2', 'bulk-child-1']);
        expect(
            results[parentB.meta.id]!.map((e) => e.meta.id), ['bulk-child-3']);
      });

      test('getBulkLinkedEntities returns empty map for empty input', () async {
        final results = await db!.getBulkLinkedEntities({});
        expect(results, isEmpty);
      });
    });

    group('Watch streams -', () {
      test('watchConflicts emits unresolved conflicts and updates', () async {
        final stream =
            db!.watchConflicts(ConflictStatus.unresolved).asBroadcastStream();
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

      test('watchTags emits updates for tag changes', () async {
        final stream = db!.watchTags().asBroadcastStream();
        final initialFuture = stream.first;
        final afterInsertFuture = stream.skip(1).first;
        final afterUpdateFuture = stream.skip(2).first;

        expect(await initialFuture, isEmpty);

        await db!.upsertTagEntity(testTag1);
        expect((await afterInsertFuture).single.id, testTag1.id);

        await db!.upsertTagEntity(
          testTag1.copyWith(
            tag: 'Updated Tag',
            updatedAt: testTag1.updatedAt.add(const Duration(minutes: 1)),
          ),
        );
        expect((await afterUpdateFuture).single.tag, 'Updated Tag');
      });

      test('watchDashboards emits dashboards', () async {
        final stream = db!.watchDashboards().asBroadcastStream();
        final initialFuture = stream.first;
        final afterInsertFuture = stream.skip(1).first;

        expect(await initialFuture, isEmpty);

        final dashboard = testDashboardConfig.copyWith(
          id: 'dashboard-1',
          name: 'Dashboard One',
          updatedAt: DateTime(2024, 10),
          createdAt: DateTime(2024, 10),
        );

        await db!.upsertDashboardDefinition(dashboard);
        expect((await afterInsertFuture).single.id, 'dashboard-1');
      });

      test('watchDashboardById emits dashboard or null', () async {
        final dashboard = testDashboardConfig.copyWith(
          id: 'dashboard-by-id',
          name: 'Dashboard Detail',
          updatedAt: DateTime(2024, 10),
          createdAt: DateTime(2024, 10),
        );

        final stream = db!.watchDashboardById(dashboard.id).asBroadcastStream();
        final initialFuture = stream.first;
        final afterInsertFuture = stream.skip(1).first;

        expect(await initialFuture, isNull);

        await db!.upsertDashboardDefinition(dashboard);
        expect((await afterInsertFuture)?.id, dashboard.id);
      });

      test('watchHabitDefinitions emits stored habits', () async {
        final stream = db!.watchHabitDefinitions().asBroadcastStream();
        final initialFuture = stream.first;
        final afterInsertFuture = stream.skip(1).first;

        expect(await initialFuture, isEmpty);

        await db!.upsertHabitDefinition(habitFlossing);
        expect((await afterInsertFuture).single.id, habitFlossing.id);
      });

      test('watchHabitById emits habit updates', () async {
        final stream = db!.watchHabitById(habitFlossing.id).asBroadcastStream();
        final initialFuture = stream.first;
        final afterInsertFuture = stream.skip(1).first;

        expect(await initialFuture, isNull);

        await db!.upsertHabitDefinition(habitFlossing);
        expect((await afterInsertFuture)?.id, habitFlossing.id);
      });

      test('watchCategories emits active categories', () async {
        final stream = db!.watchCategories().asBroadcastStream();
        final initialFuture = stream.first;
        final afterInsertFuture = stream.skip(1).first;

        expect(await initialFuture, isEmpty);

        await db!.upsertCategoryDefinition(categoryMindfulness);
        expect((await afterInsertFuture).single.id, categoryMindfulness.id);
      });

      test('watchCategoryById emits category updates', () async {
        final stream =
            db!.watchCategoryById(categoryMindfulness.id).asBroadcastStream();
        final initialFuture = stream.first;
        final afterInsertFuture = stream.skip(1).first;

        expect(await initialFuture, isNull);

        await db!.upsertCategoryDefinition(categoryMindfulness);
        expect((await afterInsertFuture)?.id, categoryMindfulness.id);
      });

      test('watchMeasurableDataTypes emits only active types', () async {
        final stream = db!.watchMeasurableDataTypes().asBroadcastStream();
        final initialFuture = stream.first;
        final afterInsertFuture = stream.skip(1).first;

        expect(await initialFuture, isEmpty);

        await db!.upsertMeasurableDataType(measurableWater);
        final deletedType = measurableChocolate.copyWith(
          deletedAt: DateTime(2024, 11),
        );
        await db!.upsertMeasurableDataType(deletedType);

        expect(
          (await afterInsertFuture).map((type) => type.id),
          [measurableWater.id],
        );
      });

      test('watchMeasurableDataTypeById emits measurable type', () async {
        final stream = db!
            .watchMeasurableDataTypeById(measurableWater.id)
            .asBroadcastStream();
        final initialFuture = stream.first;
        final afterInsertFuture = stream.skip(1).first;

        expect(await initialFuture, isNull);

        await db!.upsertMeasurableDataType(measurableWater);
        expect((await afterInsertFuture)?.id, measurableWater.id);
      });
    });

    group('Upsert helpers -', () {
      test('upsertMeasurableDataType inserts and updates entity', () async {
        await db!.upsertMeasurableDataType(measurableWater);
        var row = await (db!.select(db!.measurableTypes)
              ..where((tbl) => tbl.id.equals(measurableWater.id)))
            .getSingle();
        expect(
            measurableDataType(row).displayName, measurableWater.displayName);

        final updated = measurableWater.copyWith(displayName: 'Water+');
        await db!.upsertMeasurableDataType(updated);
        row = await (db!.select(db!.measurableTypes)
              ..where((tbl) => tbl.id.equals(measurableWater.id)))
            .getSingle();
        expect(measurableDataType(row).displayName, 'Water+');
      });

      test('upsertTagEntity upserts tag definitions', () async {
        await db!.upsertTagEntity(testTag1);
        var row = await (db!.select(db!.tagEntities)
              ..where((tbl) => tbl.id.equals(testTag1.id)))
            .getSingle();
        expect(fromTagDbEntity(row).tag, testTag1.tag);

        final updated = testTag1.copyWith(
          tag: 'UpdatedTag',
          updatedAt: testTag1.updatedAt.add(const Duration(minutes: 1)),
        );
        await db!.upsertTagEntity(updated);
        row = await (db!.select(db!.tagEntities)
              ..where((tbl) => tbl.id.equals(testTag1.id)))
            .getSingle();
        expect(fromTagDbEntity(row).tag, 'UpdatedTag');
      });

      test('upsertHabitDefinition upserts habit', () async {
        await db!.upsertHabitDefinition(habitFlossing);
        var row = await (db!.select(db!.habitDefinitions)
              ..where((tbl) => tbl.id.equals(habitFlossing.id)))
            .getSingle();
        expect(
          HabitDefinition.fromJson(
            jsonDecode(row.serialized) as Map<String, dynamic>,
          ).name,
          habitFlossing.name,
        );

        final updated = habitFlossing.copyWith(name: 'Floss Nightly');
        await db!.upsertHabitDefinition(updated);
        row = await (db!.select(db!.habitDefinitions)
              ..where((tbl) => tbl.id.equals(habitFlossing.id)))
            .getSingle();
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
        var row = await (db!.select(db!.dashboardDefinitions)
              ..where((tbl) => tbl.id.equals('dashboard-upsert')))
            .getSingle();
        expect(
          DashboardDefinition.fromJson(
            jsonDecode(row.serialized) as Map<String, dynamic>,
          ).name,
          'Initial Dashboard',
        );

        final updated = dashboard.copyWith(name: 'Updated Dashboard');
        await db!.upsertDashboardDefinition(updated);
        row = await (db!.select(db!.dashboardDefinitions)
              ..where((tbl) => tbl.id.equals('dashboard-upsert')))
            .getSingle();
        expect(
          DashboardDefinition.fromJson(
            jsonDecode(row.serialized) as Map<String, dynamic>,
          ).name,
          'Updated Dashboard',
        );
      });

      test('upsertCategoryDefinition upserts category', () async {
        await db!.upsertCategoryDefinition(categoryMindfulness);
        var row = await (db!.select(db!.categoryDefinitions)
              ..where((tbl) => tbl.id.equals(categoryMindfulness.id)))
            .getSingle();
        expect(
          CategoryDefinition.fromJson(
            jsonDecode(row.serialized) as Map<String, dynamic>,
          ).name,
          categoryMindfulness.name,
        );

        final updated = categoryMindfulness.copyWith(name: 'Mindfulness+');
        await db!.upsertCategoryDefinition(updated);
        row = await (db!.select(db!.categoryDefinitions)
              ..where((tbl) => tbl.id.equals(categoryMindfulness.id)))
            .getSingle();
        expect(
          CategoryDefinition.fromJson(
            jsonDecode(row.serialized) as Map<String, dynamic>,
          ).name,
          'Mindfulness+',
        );
      });

      test('upsertEntityDefinition delegates based on entity type', () async {
        final measurable =
            measurableWater.copyWith(displayName: 'Entity Water');
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
        final measurableRow = await (db!.select(db!.measurableTypes)
              ..where((tbl) => tbl.id.equals(measurable.id)))
            .getSingle();
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
            defaultStoryId: habit.defaultStoryId,
            categoryId: habit.categoryId,
            dashboardId: habit.dashboardId,
            priority: habit.priority,
          ),
        );
        final habitRow = await (db!.select(db!.habitDefinitions)
              ..where((tbl) => tbl.id.equals(habit.id)))
            .getSingle();
        expect(
          HabitDefinition.fromJson(
            jsonDecode(habitRow.serialized) as Map<String, dynamic>,
          ).name,
          'Entity Habit',
        );
      });
    });

    group('Aggregate queries -', () {
      test('getTaggedCount returns number of tag associations', () async {
        final entry = buildJournalEntry(
          id: 'tagged-entry',
          timestamp: DateTime(2024, 11),
          text: 'Tagged entry',
        );

        await db!.upsertJournalDbEntity(toDbEntity(entry));
        await db!.upsertTagEntity(testTag1);
        await db!.insertTag(entry.meta.id, testTag1.id);

        expect(await db!.getTaggedCount(), 1);
      });

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

      test('getMatchingTags returns matching active tags', () async {
        await db!.upsertTagEntity(testTag1);
        await db!.upsertTagEntity(
          testTag1.copyWith(
            id: 'secondary-tag',
            tag: 'Different tag',
            updatedAt: testTag1.updatedAt.add(const Duration(minutes: 5)),
          ),
        );

        final matches = await db!.getMatchingTags('Some');
        expect(matches.map((tag) => tag.id), contains(testTag1.id));
        expect(matches.map((tag) => tag.id), isNot(contains('secondary-tag')));
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
        final imagePath =
            getFullImagePath(image, documentsDirectory: docDir.path);
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

        final progress = await db!.purgeDeleted().toList();
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

        final progress = await db!.purgeDeleted(backup: false).toList();
        expect(progress, equals([1.0]));
        expect(backupDir.existsSync(), isFalse);
      });

      test('purges all deleted entity types', () async {
        final deletionTime = DateTime(2024, 2, 1, 8);
        final docDir = getIt<Directory>();
        await createPlaceholderDbFile(docDir);
        await seedDeletedDatabaseContent(db!, deletionTime);

        await db!.purgeDeleted(backup: false).toList();

        expect(await db!.select(db!.dashboardDefinitions).get(), isEmpty);
        expect(await db!.select(db!.measurableTypes).get(), isEmpty);
        expect(await db!.select(db!.tagEntities).get(), isEmpty);
        expect(await db!.select(db!.journal).get(), isEmpty);
      });

      test('reports progress accurately', () async {
        final deletionTime = DateTime(2024, 2, 2, 9);
        await seedDeletedDatabaseContent(db!, deletionTime);

        final progress = await db!.purgeDeleted(backup: false).toList();
        expect(progress, equals([0.25, 0.5, 0.75, 1.0]));
      });

      test('returns 1.0 immediately when nothing to purge', () async {
        final progress = await db!.purgeDeleted(backup: false).toList();
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

        expect(results.map((e) => e.meta.id),
            equals(['jan-20-workout', 'jan-05']));
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
        final messages = <String?>[];
        final original = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          messages.add(message);
        };
        addTearDown(() {
          debugPrint = original;
        });

        final result = await db!.latestQuantitativeByType('missing-type');
        expect(result, isNull);
        expect(
          messages.any(
            (message) =>
                message?.contains('no result for missing-type') ?? false,
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
        final messages = <String?>[];
        final original = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          messages.add(message);
        };
        addTearDown(() {
          debugPrint = original;
        });

        final result = await db!.latestWorkout();
        expect(result, isNull);
        expect(
          messages
              .any((message) => message?.contains('no workout found') ?? false),
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
        expect(await db?.watchConfigFlag(recordLocationFlag).first, false);
        await db?.toggleConfigFlag(recordLocationFlag);
        expect(await db?.watchConfigFlag(recordLocationFlag).first, true);
      },
    );

    test(
      'watchActiveConfigFlagNames returns active flag names correctly',
      () async {
        final activeFlags = await db?.watchActiveConfigFlagNames().first;
        expect(activeFlags, expectedActiveFlagNames);

        await db?.toggleConfigFlag(recordLocationFlag);
        final updatedFlags = await db?.watchActiveConfigFlagNames().first;
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
        final now = DateTime.now();
        final updatedEntry = JournalEntity.journalEntry(
          meta: Metadata(
            id: entry.meta.id,
            createdAt: entry.meta.createdAt,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
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

      test('updateJournalEntity with overwrite=false does not update',
          () async {
        final entry = createJournalEntry('Original text');
        await db!.updateJournalEntity(entry);

        // Create modified entry with same ID
        final now = DateTime.now();
        final updatedEntry = JournalEntity.journalEntry(
          meta: Metadata(
            id: entry.meta.id,
            createdAt: entry.meta.createdAt,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
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
      });
    });

    group('Conflict Handling -', () {
      test('detectConflict detects concurrent vector clocks', () async {
        // Create two entities with concurrent vector clocks
        const vclockA = VectorClock(<String, int>{'device1': 1, 'device2': 1});
        const vclockB = VectorClock(<String, int>{'device1': 2, 'device3': 1});

        final entryA = createJournalEntryWithVclock(vclockA);
        final entryB =
            createJournalEntryWithVclock(vclockB, id: entryA.meta.id);

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
      });

      test('updateJournalEntity respects vector clock ordering', () async {
        // Create two entities with B > A vector clocks
        const vclockA = VectorClock(<String, int>{'device1': 1});
        const vclockB = VectorClock(<String, int>{'device1': 2});

        final entryA = createJournalEntryWithVclock(vclockA);
        final entryB =
            createJournalEntryWithVclock(vclockB, id: entryA.meta.id);

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
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
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
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
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
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            name: 'alpha',
            color: '#AAAAAA',
            vectorClock: null,
          ),
        );
        await db!.upsertLabelDefinition(
          LabelDefinition(
            id: 'beta',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            name: 'beta',
            color: '#BBBBBB',
            vectorClock: null,
          ),
        );
        await db!.upsertLabelDefinition(
          LabelDefinition(
            id: 'gamma',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
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
            updatedAt: DateTime.now().add(const Duration(minutes: 1)),
          ),
        );

        await db!.updateJournalEntity(updated);

        final afterUpdate = await db!.labeledForJournal(entry.meta.id).get();
        expect(afterUpdate, unorderedEquals(['beta', 'gamma']));

        final cleared = updated.copyWith(
          meta: updated.meta.copyWith(
            labelIds: null,
            updatedAt: DateTime.now().add(const Duration(minutes: 2)),
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
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
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
  final tag = testTag1.copyWith(
    id: 'tag-${deletionTime.millisecondsSinceEpoch}',
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
  await database.upsertTagEntity(tag);
  await database.updateJournalEntity(journalEntry);
}

JournalEntity buildTextEntry({
  required String id,
  required DateTime timestamp,
  required String text,
  DateTime? deletedAt,
}) {
  return JournalEntity.journalEntry(
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
JournalEntity createJournalEntry(
  String text, {
  String? id,
  List<String>? labelIds,
}) {
  final now = DateTime.now();
  return JournalEntity.journalEntry(
    meta: Metadata(
      id: id ?? UniqueKey().toString(),
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
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
  final now = DateTime.now();
  final entryId = id ?? UniqueKey().toString();

  return JournalEntity.journalEntry(
    meta: Metadata(
      id: entryId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
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
