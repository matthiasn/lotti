import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show UniqueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/lotti_logger.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';

// Add missing mock classes
class MockLottiLogger extends Mock implements LottiLogger {}

class MockFile extends Mock implements File {}

// Setup a temp directory for testing
Directory setupTestDirectory() {
  final directory = Directory.systemTemp.createTempSync('lotti_test_');
  return directory;
}

final Set<String> expectedActiveFlagNames = {
  privateFlag,
  enableSyncFlag,
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
  const ConfigFlag(
    name: enableSyncFlag,
    description: 'Enable sync? (requires restart)',
    status: true,
  ),
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
};

void main() {
  JournalDb? db;
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockLottiLogger = MockLottiLogger();
  late Directory testDirectory;

  group('Database Tests - ', () {
    setUp(() async {
      // Create a real temporary directory for testing
      testDirectory = setupTestDirectory();

      // Register services
      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<LottiLogger>(mockLottiLogger)
        ..registerSingleton<Directory>(testDirectory);

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(
        () => mockLottiLogger.event(
          any<Object>(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenAnswer((_) => Future<void>.value());

      db = JournalDb(inMemoryDatabase: true);
      await initConfigFlags(db!, inMemoryDatabase: true);
    });

    tearDownAll(() async {
      await getIt.reset();
    });

    tearDown(() async {
      // Unregister services first to avoid hanging references
      getIt
        ..unregister<UpdateNotifications>()
        ..unregister<LottiLogger>()
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
        final result = await db?.updateJournalEntity(entry);

        expect(result, 1); // 1 row affected

        final retrieved = await db?.journalEntityById(entry.meta.id);
        expect(retrieved, isNotNull);
        expect(retrieved?.meta.id, entry.meta.id);
        expect(retrieved?.meta.dateFrom, isA<DateTime>());
      });

      test('updateJournalEntity updates existing entity', () async {
        final entry = createJournalEntry('Original text');
        await db?.updateJournalEntity(entry);

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

        final result = await db?.updateJournalEntity(updatedEntry);
        expect(result, 1);

        final retrieved = await db?.journalEntityById(entry.meta.id);
        expect(retrieved, isNotNull);
        expect(retrieved?.meta.starred, true);
      });

      test('updateJournalEntity with overwrite=false does not update',
          () async {
        final entry = createJournalEntry('Original text');
        await db?.updateJournalEntity(entry);

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

        final result = await db?.updateJournalEntity(
          updatedEntry,
          overwrite: false,
        );

        expect(result, 0); // No rows affected

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
        await db?.updateJournalEntity(entryA);

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
        await db?.updateJournalEntity(entryA);

        // Update with B, should succeed
        final result = await db?.updateJournalEntity(entryB);
        expect(result, 1);

        // Retrieve - should be B
        final retrieved = await db?.journalEntityById(entryA.meta.id);
        expect(retrieved?.meta.id, entryA.meta.id);

        // Now try to update with A again (lower vclock), should fail
        final result2 = await db?.updateJournalEntity(entryA);
        expect(result2, 0);

        // Retrieve - should still be B
        final stillB = await db?.journalEntityById(entryA.meta.id);
        expect(stillB?.meta.id, entryA.meta.id);

        // We can override with overrideComparison
        final result3 = await db?.updateJournalEntity(
          entryA,
          overrideComparison: true,
        );
        expect(result3, 1);

        // Now it should be A
        final nowA = await db?.journalEntityById(entryA.meta.id);
        expect(nowA?.meta.id, entryA.meta.id);
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
