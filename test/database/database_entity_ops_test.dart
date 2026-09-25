import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/ui/pages/conflicts/conflict_detail_shared.dart';
import 'package:lotti/features/sync/ui/widgets/conflicts/conflict_merge.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import 'test_utils.dart';

part 'journal_replication_model_conformance.dart';

/// Holds the first sidecar write until released so a later write for the
/// same entity can overtake it on disk.
class _SlowFirstSidecarJournalDb extends JournalDb {
  _SlowFirstSidecarJournalDb() : super(inMemoryDatabase: true);

  final Completer<void> releaseFirst = Completer<void>();
  int sidecarWrites = 0;

  @override
  Future<void> persistEntityJson(JournalEntity updated) async {
    if (++sidecarWrites == 1) {
      await releaseFirst.future;
    }
    await super.persistEntityJson(updated);
  }
}

enum _ConflictClockRelation {
  equal,
  incomingNewer,
  incomingOlder,
  concurrent,
}

class _ConflictMergeScenario {
  const _ConflictMergeScenario({
    required this.relation,
    required this.preExistingConflict,
    required this.baseA,
    required this.baseB,
    required this.bumpA,
    required this.bumpB,
  });

  final _ConflictClockRelation relation;
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
      glados.CombinableAny(this).combine6(
        conflictClockRelation,
        glados.BoolAny(this).bool,
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 3),
        glados.IntAnys(this).intInRange(0, 3),
        (
          _ConflictClockRelation relation,
          bool preExistingConflict,
          int baseA,
          int baseB,
          int bumpA,
          int bumpB,
        ) => _ConflictMergeScenario(
          relation: relation,
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
    // The expensive ~40-step migration ladder runs once for the whole file;
    // each test re-uses the instance and starts clean via clearAllTables.
    setUpAll(() async {
      db = JournalDb(inMemoryDatabase: true);
    });

    setUp(() async {
      testDirectory = setupTestDirectory();
      reset(mockLoggingService);
      registerJournalDbTestServices(
        updateNotifications: mockUpdateNotifications,
        loggingService: mockLoggingService,
        documentsDirectory: testDirectory,
      );
      await clearAllTables(db!);
      await initConfigFlags(db!, inMemoryDatabase: true);
    });

    tearDown(() async {
      unregisterJournalDbTestServices();
      if (testDirectory.existsSync()) {
        testDirectory.deleteSync(recursive: true);
      }
    });

    tearDownAll(() async {
      await db?.close();
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

      test(
        'conflictsByStatus uses the status/created_at index for newest-first '
        'lists',
        () async {
          final now = DateTime(2024, 9, 3);
          for (var i = 0; i < 20; i++) {
            await db!.addConflict(
              Conflict(
                id: 'indexed-conflict-$i',
                createdAt: now.add(Duration(minutes: i)),
                updatedAt: now.add(Duration(minutes: i)),
                serialized: jsonEncode(
                  buildJournalEntry(
                    id: 'indexed-conflict-entry-$i',
                    timestamp: now,
                    text: 'Conflict $i',
                  ).toJson(),
                ),
                schemaVersion: db!.schemaVersion,
                status: i.isEven
                    ? ConflictStatus.unresolved.index
                    : ConflictStatus.resolved.index,
              ),
            );
          }
          await db!.customStatement('ANALYZE');

          final rows = await db!
              .customSelect(
                '''
                EXPLAIN QUERY PLAN
                SELECT *
                FROM conflicts
                WHERE status = ?
                ORDER BY created_at DESC
                LIMIT ?
                ''',
                variables: [
                  Variable.withInt(ConflictStatus.unresolved.index),
                  Variable.withInt(10),
                ],
              )
              .get();
          final details = rows.map((row) => row.data.toString()).join('\n');

          expect(details, contains('idx_conflicts_status_created_at'));
          expect(details, isNot(contains('USE TEMP B-TREE FOR ORDER BY')));
        },
      );
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
        expect(await db!.select(db!.journal).get(), isEmpty);
      });

      test('reports progress accurately', () async {
        final deletionTime = DateTime(2024, 2, 2, 9);
        await seedDeletedDatabaseContent(db!, deletionTime);

        final progress = await db!.purgeDeleted(backup: false).toList();
        expect(progress, equals([0.33, 0.66, 1.0]));
      });

      test(
        'purges deleted entries and their files across chunk boundaries',
        () async {
          final docDir = getIt<Directory>();
          final deletionTime = DateTime(2024, 2, 3, 10);
          // More deleted rows than one chunk holds, so the rowid walk has
          // to continue past its first page without skipping or repeating.
          const total = 1203;
          final paths = <String>[];
          for (var i = 0; i < total; i++) {
            final live = buildJournalEntry(
              id: 'chunk-$i',
              timestamp: deletionTime.add(Duration(seconds: i)),
              text: 'deleted $i',
            );
            final entry = live.copyWith(
              meta: live.meta.copyWith(deletedAt: deletionTime),
            );
            await db!.updateJournalEntity(entry);
            paths.add(entityPath(entry, docDir));
          }
          expect(paths.where((p) => File(p).existsSync()), hasLength(total));

          final progress = await db!.purgeDeleted(backup: false).toList();

          expect(progress, equals([0.33, 0.66, 1.0]));
          expect(await db!.select(db!.journal).get(), isEmpty);
          expect(paths.where((p) => File(p).existsSync()), isEmpty);
        },
      );

      test('returns 1.0 immediately when nothing to purge', () async {
        final progress = await db!.purgeDeleted(backup: false).toList();
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

      test('updateJournalEntity stamps updated_at from clock.now()', () async {
        // Drift stores DateTime columns as whole seconds, so a fixed instant
        // with no sub-second part round-trips exactly.
        final fixedNow = DateTime(2026, 9, 5, 10, 30);
        final entry = createJournalEntry('Clock-driven write');

        await withClock(
          Clock.fixed(fixedNow),
          () => db!.updateJournalEntity(entry),
        );

        final row = await db!.entityById(entry.meta.id);
        expect(row?.updatedAt, fixedNow);
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

      test(
        'updateJournalEntity applies a local edit that extends the stored '
        "clock by the host's counter 0 (ADR 0080)",
        () async {
          // A device set up by a build that started counters at 0 edits an
          // entry it synced from device A: its first edit's clock is A's plus
          // `device-b: 0`. Read as equal, the edit was refused as older and
          // its counter burned.
          final stored = createJournalEntryWithVclock(
            const VectorClock({'device-a': 1}),
          );
          await db!.updateJournalEntity(stored);
          final edit = createJournalEntryWithVclock(
            const VectorClock({'device-a': 1, 'device-b': 0}),
            id: stored.meta.id,
          ).copyWith(entryText: const EntryText(plainText: 'edited on B'));

          final result = await db!.updateJournalEntity(edit);

          expect(result.applied, isTrue);
          final row = await db!.journalEntityById(stored.meta.id);
          expect(row?.entryText?.plainText, 'edited on B');
          expect(await db!.conflictById(stored.meta.id), isNull);
        },
      );

      test(
        "two devices through the real services: a new device's first edit "
        'of a synced entry is saved there and applied on the device it came '
        'from (ADR 0080)',
        () async {
          final settingsDb = SettingsDb(inMemoryDatabase: true);
          getIt.registerSingleton<SettingsDb>(settingsDb);
          final deviceA = JournalDb(inMemoryDatabase: true);
          addTearDown(() async {
            await deviceA.close();
            getIt.unregister<SettingsDb>();
            await settingsDb.close();
          });

          // A wrote the entry; B (db), just set up, received it.
          final written = createJournalEntryWithVclock(
            const VectorClock({'device-a': 1}),
          );
          await deviceA.updateJournalEntity(written);
          await db!.updateJournalEntity(written);

          // B edits it the way PersistenceLogic does: a clock reserved from
          // B's new host with the stored clock as `previous`.
          final clocks = VectorClockService();
          await clocks.initialized;
          final meta = await MetadataService(
            vectorClockService: clocks,
          ).updateMetadata(written.meta);
          final edit = written.copyWith(
            meta: meta,
            entryText: const EntryText(plainText: 'edited on B'),
          );

          expect((await db!.updateJournalEntity(edit)).applied, isTrue);
          expect((await deviceA.updateJournalEntity(edit)).applied, isTrue);
          for (final device in [db!, deviceA]) {
            final row = await device.journalEntityById(written.meta.id);
            expect(row?.entryText?.plainText, 'edited on B');
            expect(row?.meta.vectorClock, meta.vectorClock);
          }
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

    group('Write-path atomicity -', () {
      test(
        'refused precondition preserves the stored row and JSON sidecar',
        () async {
          final entry = createJournalEntryWithVclock(
            const VectorClock({'a': 1}),
            id: 'guarded',
          );
          await db!.updateJournalEntity(entry);
          final file = File(entityPath(entry, getIt<Directory>()));
          final before = await file.readAsString();
          final updated = entry.copyWith(
            meta: entry.meta.copyWith(
              vectorClock: const VectorClock({'a': 2}),
              deletedAt: DateTime(2026, 9, 6),
            ),
          );
          final result = await db!.updateJournalEntity(
            updated,
            precondition: () async => false,
          );
          expect(result.applied, isFalse);
          expect(result.skipReason, JournalUpdateSkipReason.overwritePrevented);
          expect(await db!.journalEntityById(entry.id), entry);
          expect(await file.readAsString(), before);
          expect(await db!.conflictById(entry.id), isNull);
        },
      );

      test('precondition reads and write share one transaction', () async {
        final entry = createJournalEntryWithVclock(
          const VectorClock({'a': 1}),
          id: 'guard-race',
        );
        await db!.updateJournalEntity(entry);
        final entered = Completer<void>();
        final release = Completer<void>();
        final updated = entry.copyWith(
          meta: entry.meta.copyWith(vectorClock: const VectorClock({'a': 3})),
        );
        final deletion = db!.updateJournalEntity(
          updated,
          precondition: () async {
            entered.complete();
            await release.future;
            return (await db!.entityById(entry.id))?.serialized ==
                jsonEncode(entry);
          },
        );
        await entered.future;
        final competing = db!.updateJournalEntity(
          entry.copyWith(
            meta: entry.meta.copyWith(vectorClock: const VectorClock({'a': 2})),
          ),
        );
        release.complete();
        expect((await deletion).applied, isTrue);
        expect(
          (await competing).skipReason,
          JournalUpdateSkipReason.olderOrEqual,
        );
        expect(await db!.journalEntityById(entry.id), updated);
      });

      test(
        'concurrent writes of the same id are serialised: the second sees '
        'the first and records a conflict instead of overwriting it',
        () async {
          const id = 'race-entry';
          final first = createJournalEntryWithVclock(
            const VectorClock({'a': 1}),
            id: id,
          );
          final second = createJournalEntryWithVclock(
            const VectorClock({'b': 1}),
            id: id,
          );

          // Both calls are issued before either has read the row. Without a
          // transaction around read + write, both reads return "no row", both
          // writes apply, and the concurrent clocks are never noticed.
          final results = await Future.wait([
            db!.updateJournalEntity(first),
            db!.updateJournalEntity(second),
          ]);

          expect(results.where((r) => r.applied), hasLength(1));
          expect(
            results.map((r) => r.skipReason),
            contains(JournalUpdateSkipReason.conflict),
          );
          final conflict = await db!.conflictById(id);
          expect(conflict, isNotNull);
          expect(conflict!.status, ConflictStatus.unresolved.index);
        },
      );

      test(
        'sidecars for one entity land in commit order even when the earlier '
        'write finishes last',
        () async {
          final slowDb = _SlowFirstSidecarJournalDb();
          addTearDown(slowDb.close);
          await initConfigFlags(slowDb, inMemoryDatabase: true);
          const id = 'ordered-sidecar';
          final first = createJournalEntryWithVclock(
            const VectorClock({'a': 1}),
            id: id,
          );
          final second = createJournalEntryWithVclock(
            const VectorClock({'a': 2}),
            id: id,
          );

          final firstWrite = slowDb.updateJournalEntity(first);
          final secondWrite = slowDb.updateJournalEntity(second);
          // Both rows commit; the first sidecar write is parked. Without
          // per-entity ordering the second sidecar lands now and the first
          // overwrites it once released, leaving the older document as the
          // sync payload for the newer row.
          await pumpEventQueue();
          slowDb.releaseFirst.complete();
          await Future.wait([firstWrite, secondWrite]);

          final sidecar = File(entityPath(second, testDirectory));
          final onDisk = JournalEntity.fromJson(
            jsonDecode(sidecar.readAsStringSync()) as Map<String, dynamic>,
          );
          expect(onDisk.meta.vectorClock?.vclock, {'a': 2});
        },
      );

      test('the JSON sidecar is written only for an applied write', () async {
        final existing = createJournalEntryWithVclock(
          const VectorClock({'a': 2}),
          id: 'sidecar-entry',
        );
        await db!.updateJournalEntity(existing);
        final sidecar = File(entityPath(existing, testDirectory));
        expect(sidecar.existsSync(), isTrue);
        final before = sidecar.lastModifiedSync();
        final beforeContent = sidecar.readAsStringSync();

        final older = createJournalEntryWithVclock(
          const VectorClock({'a': 1}),
          id: 'sidecar-entry',
        );
        final result = await db!.updateJournalEntity(older);

        expect(result.applied, isFalse);
        expect(sidecar.lastModifiedSync(), before);
        expect(sidecar.readAsStringSync(), beforeContent);
      });
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
        expect(stillB?.meta.vectorClock, vclockB);
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

          final result = await db!.updateJournalEntity(incomingEntry);
          final shouldApply = scenario.expectedStatus == VclockStatus.b_gt_a;

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
            // The pre-existing conflict holds the version the incoming one
            // succeeds, so the write settles it.
            if (scenario.preExistingConflict) {
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

    // Regressions for the holes specs/tla/JournalReplication.tla found
    // (ADR 0083). Each mirrors the model's counterexample on one device.
    group('Replication model conformance -', () {
      final devices = <JournalDb>[];
      final directories = <Directory>[];

      setUpAll(() {
        for (var d = 0; d < 3; d++) {
          final directory = setupTestDirectory();
          directories.add(directory);
          devices.add(
            JournalDb(inMemoryDatabase: true, documentsDirectory: directory),
          );
        }
      });

      tearDownAll(() async {
        for (final device in devices) {
          await device.close();
        }
        for (final directory in directories) {
          directory.deleteSync(recursive: true);
        }
      });

      registerJournalReplicationConformance(() => devices);
    });

    group('Replication -', () {
      const id = 'replicated-entry';

      JournalEntity version(
        Map<String, int>? clock,
        String text, {
        bool deleted = false,
      }) {
        final base = createJournalEntryWithVclock(
          VectorClock(clock ?? const <String, int>{}),
          id: id,
        );
        return base.copyWith(
          meta: base.meta.copyWith(
            vectorClock: clock == null ? null : VectorClock(clock),
            deletedAt: deleted ? testDate : null,
          ),
          entryText: EntryText(plainText: text),
        );
      }

      Future<JournalEntity?> stored() =>
          db!.journalEntityByIdIncludingDeleted(id);

      Future<String?> conflictText() async {
        final conflict = await db!.conflictById(id);
        if (conflict == null ||
            conflict.status != ConflictStatus.unresolved.index) {
          return null;
        }
        return JournalEntity.fromJson(
          jsonDecode(conflict.serialized) as Map<String, dynamic>,
        ).entryText?.plainText;
      }

      test(
        'a late copy of the version a deletion replaced is refused',
        () async {
          await db!.updateJournalEntity(version({'a': 1}, 'v1'));
          await db!.updateJournalEntity(
            version({'a': 2}, 'v2', deleted: true),
          );

          final late = await db!.updateJournalEntity(version({'a': 1}, 'v1'));

          expect(late.applied, isFalse);
          expect(late.skipReason, JournalUpdateSkipReason.olderOrEqual);
          expect((await stored())?.meta.deletedAt, isNotNull);
          expect(await db!.journalEntityById(id), isNull);
        },
      );

      test('an edit concurrent with a stored deletion is a conflict', () async {
        await db!.updateJournalEntity(version({'a': 1}, 'v1'));
        await db!.updateJournalEntity(
          version({'a': 2}, 'deleted here', deleted: true),
        );

        final edit = await db!.updateJournalEntity(
          version({'a': 1, 'b': 1}, 'edited there'),
        );

        expect(edit.applied, isFalse);
        expect(edit.skipReason, JournalUpdateSkipReason.conflict);
        expect((await stored())?.meta.deletedAt, isNotNull);
        expect(await conflictText(), 'edited there');
      });

      test(
        'two concurrent deletions merge to the same row in either order',
        () async {
          final onA = version({'a': 2, 'b': 1}, 'A', deleted: true);
          final onB = version({'a': 1, 'b': 2}, 'B', deleted: true);

          Future<JournalEntity?> receive(
            JournalEntity first,
            JournalEntity second,
          ) async {
            await clearAllTables(db!);
            await db!.updateJournalEntity(first);
            final result = await db!.updateJournalEntity(second);
            expect(result.applied, isTrue);
            expect(await db!.conflictById(id), isNull);
            return stored();
          }

          final aThenB = await receive(onA, onB);
          final bThenA = await receive(onB, onA);

          const joined = VectorClock({'a': 2, 'b': 2});
          expect(aThenB?.meta.vectorClock, joined);
          expect(bThenA?.meta.vectorClock, joined);
          // The canonically greater deletion's fields: `a` decides, 2 > 1.
          expect(aThenB?.entryText?.plainText, 'A');
          expect(bThenA?.entryText?.plainText, 'A');
          expect(aThenB?.meta.deletedAt, isNotNull);
        },
      );

      test(
        'an applied write that does not include the open conflict leaves it '
        'open; the resolution settles it',
        () async {
          await db!.updateJournalEntity(version({'a': 2}, 'mine'));
          await db!.updateJournalEntity(version({'a': 1, 'b': 1}, 'other'));
          expect(await conflictText(), 'other');

          final later = await db!.updateJournalEntity(
            version({'a': 3}, 'mine again'),
          );
          expect(later.applied, isTrue);
          expect(await conflictText(), 'other');

          final resolution = await db!.updateJournalEntity(
            version({'a': 4, 'b': 1}, 'resolved'),
          );
          expect(resolution.applied, isTrue);
          expect(await conflictText(), isNull);
        },
      );

      test(
        'an unreadable conflict row is settled by the next applied write',
        () async {
          await db!.updateJournalEntity(version({'a': 1}, 'v1'));
          await db!.addConflict(
            Conflict(
              id: id,
              createdAt: testDate,
              updatedAt: testDate,
              serialized: 'not json',
              schemaVersion: db!.schemaVersion,
              status: ConflictStatus.unresolved.index,
            ),
          );

          await db!.updateJournalEntity(version({'a': 2}, 'v2'));

          expect(
            (await db!.conflictById(id))?.status,
            ConflictStatus.resolved.index,
          );
          verify(
            () => mockLoggingService.error(
              LogDomain.database,
              any<Object>(),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'conflictClock',
            ),
          ).called(1);
        },
      );

      test('a late copy does not replace a newer open conflict', () async {
        await db!.updateJournalEntity(version({'a': 2}, 'mine'));
        await db!.updateJournalEntity(version({'a': 1, 'b': 2}, 'theirs v2'));
        expect(await conflictText(), 'theirs v2');

        final late = await db!.updateJournalEntity(
          version({'a': 1, 'b': 1}, 'theirs v1'),
        );

        expect(late.skipReason, JournalUpdateSkipReason.conflict);
        expect(await conflictText(), 'theirs v2');
      });

      test('a clockless version never replaces a clocked row', () async {
        await db!.updateJournalEntity(version({'a': 1}, 'clocked'));

        final legacy = await db!.updateJournalEntity(version(null, 'legacy'));

        expect(legacy.applied, isFalse);
        expect(legacy.skipReason, JournalUpdateSkipReason.olderOrEqual);
        expect((await stored())?.entryText?.plainText, 'clocked');
      });

      test('a clocked or clockless version replaces a clockless row', () async {
        await db!.updateJournalEntity(version(null, 'legacy'));
        final again = await db!.updateJournalEntity(version(null, 'legacy 2'));
        expect(again.applied, isTrue);

        final clocked = await db!.updateJournalEntity(
          version({'a': 1}, 'clocked'),
        );

        expect(clocked.applied, isTrue);
        expect((await stored())?.entryText?.plainText, 'clocked');
      });

      test('a creation still replaces a deleted row', () async {
        await db!.updateJournalEntity(
          version({'a': 1}, 'deleted', deleted: true),
        );

        final created = await db!.updateJournalEntity(
          version({'b': 1}, 'created'),
          overwrite: false,
        );

        expect(created.applied, isTrue);
        expect((await stored())?.meta.deletedAt, isNull);
      });

      test(
        'restoreSidecar writes the stored row back to its sidecar',
        () async {
          final entry = version({'a': 1}, 'stored');
          await db!.updateJournalEntity(entry);
          final file = File(entityPath(entry, getIt<Directory>()))
            ..writeAsStringSync(
              jsonEncode(version({'b': 1}, 'a refused copy')),
            );

          expect(await db!.restoreSidecar(id), isTrue);

          final onDisk = JournalEntity.fromJson(
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
          );
          expect(onDisk.entryText?.plainText, 'stored');
          expect(await db!.restoreSidecar('never-stored'), isFalse);
        },
      );

      test(
        'a refused precondition writes neither the row nor a conflict',
        () async {
          await db!.updateJournalEntity(version({'a': 1}, 'v1'));

          final result = await db!.updateJournalEntity(
            version({'b': 1}, 'built on a row no longer stored'),
            precondition: () =>
                db!.isStoredVersion(id, const VectorClock({'a': 0})),
          );

          expect(result.applied, isFalse);
          expect(await db!.conflictById(id), isNull);
          expect((await stored())?.entryText?.plainText, 'v1');
        },
      );
    });
  });
}
