import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show UniqueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
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
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/file_utils.dart';
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
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenAnswer((_) => Future<void>.value());

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

// Helper functions to create test entities
JournalEntity createJournalEntry(
  String text, {
  String? id,
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
    ),
    entryText: EntryText(plainText: text),
  );
}

JournalEntity createJournalEntryWithVclock(
  VectorClock vclock, {
  String? id,
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
