import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show UniqueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
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
    name: enableSyncV2Flag,
    description:
        'Enable Matrix Sync V2 (simplified pipeline) – requires restart',
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
