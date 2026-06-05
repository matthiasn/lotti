import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import 'test_utils.dart';

enum _ConflictClockRelation {
  equal,
  incomingNewer,
  incomingOlder,
  concurrent,
}

class _ConflictMergeScenario {
  const _ConflictMergeScenario({
    required this.relation,
    required this.overrideComparison,
    required this.preExistingConflict,
    required this.baseA,
    required this.baseB,
    required this.bumpA,
    required this.bumpB,
  });

  final _ConflictClockRelation relation;
  final bool overrideComparison;
  final bool preExistingConflict;
  final int baseA;
  final int baseB;
  final int bumpA;
  final int bumpB;

  VectorClock get existingClock {
    return switch (relation) {
      _ConflictClockRelation.equal => VectorClock({
        'a': baseA,
        'b': baseB,
      }),
      _ConflictClockRelation.incomingNewer => VectorClock({
        'a': baseA,
        'b': baseB,
      }),
      _ConflictClockRelation.incomingOlder => VectorClock({
        'a': baseA + bumpA + 1,
        'b': baseB + bumpB,
      }),
      _ConflictClockRelation.concurrent => VectorClock({
        'a': baseA + bumpA + 1,
        'b': baseB,
      }),
    };
  }

  VectorClock get incomingClock {
    return switch (relation) {
      _ConflictClockRelation.equal => VectorClock({
        'a': baseA,
        'b': baseB,
      }),
      _ConflictClockRelation.incomingNewer => VectorClock({
        'a': baseA + bumpA + 1,
        'b': baseB + bumpB,
      }),
      _ConflictClockRelation.incomingOlder => VectorClock({
        'a': baseA,
        'b': baseB,
      }),
      _ConflictClockRelation.concurrent => VectorClock({
        'a': baseA,
        'b': baseB + bumpB + 1,
      }),
    };
  }

  VclockStatus get expectedStatus {
    return switch (relation) {
      _ConflictClockRelation.equal => VclockStatus.equal,
      _ConflictClockRelation.incomingNewer => VclockStatus.b_gt_a,
      _ConflictClockRelation.incomingOlder => VclockStatus.a_gt_b,
      _ConflictClockRelation.concurrent => VclockStatus.concurrent,
    };
  }

  @override
  String toString() {
    return '_ConflictMergeScenario('
        'relation: $relation, '
        'overrideComparison: $overrideComparison, '
        'preExistingConflict: $preExistingConflict, '
        'baseA: $baseA, '
        'baseB: $baseB, '
        'bumpA: $bumpA, '
        'bumpB: $bumpB'
        ')';
  }
}

extension _AnyConflictMergeScenario on glados.Any {
  glados.Generator<_ConflictClockRelation> get conflictClockRelation =>
      glados.AnyUtils(this).choose(_ConflictClockRelation.values);

  glados.Generator<_ConflictMergeScenario> get conflictMergeScenario =>
      glados.CombinableAny(this).combine7(
        conflictClockRelation,
        glados.BoolAny(this).bool,
        glados.BoolAny(this).bool,
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 3),
        glados.IntAnys(this).intInRange(0, 3),
        (
          _ConflictClockRelation relation,
          bool overrideComparison,
          bool preExistingConflict,
          int baseA,
          int baseB,
          int bumpA,
          int bumpB,
        ) => _ConflictMergeScenario(
          relation: relation,
          overrideComparison: overrideComparison,
          preExistingConflict: preExistingConflict,
          baseA: baseA,
          baseB: baseB,
          bumpA: bumpA,
          bumpB: bumpB,
        ),
      );
}

void main() {
  setUpAll(registerJournalDbTestFallbacks);

  JournalDb? db;
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockLoggingService = MockDomainLogger();
  late Directory testDirectory;

  group('JournalDb entity ops - ', () {
    setUp(() async {
      testDirectory = setupTestDirectory();
      reset(mockLoggingService);
      registerJournalDbTestServices(
        updateNotifications: mockUpdateNotifications,
        loggingService: mockLoggingService,
        documentsDirectory: testDirectory,
      );
      db = JournalDb(inMemoryDatabase: true);
      await initConfigFlags(db!, inMemoryDatabase: true);
    });

    tearDown(() async {
      unregisterJournalDbTestServices();
      await db?.close();
      if (testDirectory.existsSync()) {
        testDirectory.deleteSync(recursive: true);
      }
    });

    tearDownAll(() async {
      await getIt.reset();
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

    group('purgeDeletedFiles -', () {
      test(
        'missing media file does not prevent JSON descriptor cleanup',
        () async {
          final deletionTime = DateTime(2024, 1, 4, 11);
          final imageEntry = buildImageEntry(
            id: 'image-missing-media',
            timestamp: deletionTime,
            imageDirectory: '/images/2024/01/04/',
            imageFile: 'missing.jpg',
            deletedAt: deletionTime,
          );
          await db!.updateJournalEntity(imageEntry);

          final image = imageEntry as JournalImage;
          final docDir = getIt<Directory>();
          final imagePath = getFullImagePath(
            image,
            documentsDirectory: docDir.path,
          );
          // The media file was never written (or is already gone); only the
          // JSON descriptor exists.
          final jsonPath = '$imagePath.json';
          expect(File(imagePath).existsSync(), isFalse);
          expect(File(jsonPath).existsSync(), isTrue);

          await db!.purgeDeletedFiles();

          expect(File(jsonPath).existsSync(), isFalse);
        },
      );

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

      test(
        'handles per-entity purge errors gracefully and continues',
        () async {
          final deletionTime = DateTime(2024, 1, 4, 11);
          // A deleted row whose serialized payload cannot be decoded forces
          // the per-entity error path; the loop must log it and keep purging
          // the remaining entities. (Missing files no longer error — deletes
          // are existence-checked.)
          final malformedRow = toDbEntity(
            buildTextEntry(
              id: 'malformed-purge-row',
              timestamp: deletionTime,
              text: 'will be corrupted',
              deletedAt: deletionTime,
            ),
          ).copyWith(serialized: 'not-json');
          await db!.upsertJournalDbEntity(malformedRow);

          final textEntry = buildTextEntry(
            id: 'text-still-deleted',
            timestamp: deletionTime,
            text: 'Should still be deleted',
            deletedAt: deletionTime,
          );
          await db!.updateJournalEntity(textEntry);

          final docDir = getIt<Directory>();
          final textJsonPath = entityPath(textEntry, docDir);
          expect(File(textJsonPath).existsSync(), isTrue);

          await db!.purgeDeletedFiles();

          verify(
            () => mockLoggingService.error(
              LogDomain.database,
              any<Object>(),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'purgeDeletedFiles',
            ),
          ).called(1);
          expect(File(textJsonPath).existsSync(), isFalse);
        },
      );
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

      test(
        'updateJournalEntity reports rows written, not SQLite rowid',
        () async {
          for (var i = 0; i < 3; i++) {
            await db!.updateJournalEntity(createJournalEntry('Seed $i'));
          }

          final entry = createJournalEntry('Inserted after seed rows');
          final result = await db!.updateJournalEntity(entry);

          expect(result.applied, isTrue);
          expect(result.rowsWritten, 1);
        },
      );

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
      test(
        'addConflict upserts: writing the same conflict id twice keeps a '
        'single row with the latest payload',
        () async {
          final base = DateTime(2024, 3, 15, 10);
          const conflictId = 'dup-conflict';

          await db!.addConflict(
            Conflict(
              id: conflictId,
              createdAt: base,
              updatedAt: base,
              serialized: '{"v": 1}',
              schemaVersion: 1,
              status: ConflictStatus.unresolved.index,
            ),
          );
          await db!.addConflict(
            Conflict(
              id: conflictId,
              createdAt: base,
              updatedAt: base.add(const Duration(minutes: 5)),
              serialized: '{"v": 2}',
              schemaVersion: 1,
              status: ConflictStatus.unresolved.index,
            ),
          );

          final stored = await db!.conflictById(conflictId);
          expect(stored, isNotNull);
          expect(stored!.serialized, '{"v": 2}');

          final count = await db!
              .customSelect('SELECT COUNT(*) AS c FROM conflicts')
              .getSingle();
          expect(count.read<int>('c'), 1);
        },
      );

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

      glados.Glados(
        _AnyConflictMergeScenario(glados.any).conflictMergeScenario,
        glados.ExploreConfig(numRuns: 40),
      ).test(
        'updateJournalEntity follows generated vector-clock merge semantics',
        (scenario) async {
          final id = UniqueKey().toString();
          final existingText = 'existing-${scenario.relation.name}';
          final incomingText = 'incoming-${scenario.relation.name}';
          final existingEntry = createJournalEntryWithVclock(
            scenario.existingClock,
            id: id,
          ).copyWith(entryText: EntryText(plainText: existingText));
          final incomingEntry = createJournalEntryWithVclock(
            scenario.incomingClock,
            id: id,
          ).copyWith(entryText: EntryText(plainText: incomingText));

          expect(
            VectorClock.compare(
              scenario.existingClock,
              scenario.incomingClock,
            ),
            scenario.expectedStatus,
          );

          final initialResult = await db!.updateJournalEntity(existingEntry);
          expect(initialResult.applied, isTrue);

          if (scenario.preExistingConflict) {
            await db!.addConflict(
              Conflict(
                id: id,
                createdAt: testDate,
                updatedAt: testDate,
                serialized: jsonEncode(existingEntry),
                schemaVersion: db!.schemaVersion,
                status: ConflictStatus.unresolved.index,
              ),
            );
          }

          final result = await db!.updateJournalEntity(
            incomingEntry,
            overrideComparison: scenario.overrideComparison,
          );
          final shouldApply =
              scenario.expectedStatus == VclockStatus.b_gt_a ||
              scenario.overrideComparison;

          expect(result.applied, shouldApply);
          if (!shouldApply) {
            expect(
              result.skipReason,
              scenario.expectedStatus == VclockStatus.concurrent
                  ? JournalUpdateSkipReason.conflict
                  : JournalUpdateSkipReason.olderOrEqual,
            );
          }

          final stored = await db!.journalEntityById(id);
          expect(stored, isNotNull);
          expect(
            stored?.entryText?.plainText,
            shouldApply ? incomingText : existingText,
          );
          expect(
            stored?.meta.vectorClock,
            shouldApply ? scenario.incomingClock : scenario.existingClock,
          );

          final conflict = await db!.conflictById(id);
          if (shouldApply) {
            if (scenario.preExistingConflict ||
                scenario.expectedStatus == VclockStatus.concurrent) {
              expect(conflict, isNotNull);
              expect(conflict?.status, ConflictStatus.resolved.index);
            } else {
              expect(conflict, isNull);
            }
          } else if (scenario.expectedStatus == VclockStatus.concurrent) {
            expect(conflict, isNotNull);
            expect(conflict?.status, ConflictStatus.unresolved.index);
            final serializedEntity =
                jsonDecode(conflict!.serialized) as Map<String, dynamic>;
            expect(serializedEntity['meta'], isA<Map<String, dynamic>>());
            expect(
              (serializedEntity['meta'] as Map<String, dynamic>)['id'],
              id,
            );
            expect(
              (serializedEntity['entryText']
                  as Map<String, dynamic>)['plainText'],
              incomingText,
            );
          } else if (scenario.preExistingConflict) {
            expect(conflict, isNotNull);
            expect(conflict?.status, ConflictStatus.unresolved.index);
          } else {
            expect(conflict, isNull);
          }
        },
        tags: 'glados',
      );

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
  });
}
