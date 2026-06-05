part of 'database.dart';

enum ConflictStatus {
  unresolved,
  resolved,
}

/// Journal-entity write path for [JournalDb]: vector-clock conflict
/// detection, upserts, conflict bookkeeping, and purging of deleted
/// entities and their files.
mixin _JournalDbEntityOps
    on _$JournalDb, _JournalDbJournalQueries, _JournalDbDefinitions {
  // Shell seams: implemented in `database.dart` because they consume the
  // constructor-injected dependencies (`_loggingService`,
  // `_documentsDirectory`) that live on the [JournalDb] shell class.

  /// Writes the canonical JSON file for [updated], honoring the
  /// documents-directory override injected via the [JournalDb]
  /// constructor.
  Future<void> _persistEntityJson(JournalEntity updated);

  /// Reports [error] to the domain logger, if one is available.
  void _captureException(
    Object error, {
    required String subDomain,
    required StackTrace? stackTrace,
  });

  /// Reports a diagnostic event to the domain logger, if available.
  void _captureEvent(
    String message, {
    required String subDomain,
  });

  Future<int> upsertJournalDbEntity(JournalDbEntity entry) async {
    return transaction(() async {
      await into(journal).insertOnConflictUpdate(entry);
      // insertOnConflictUpdate overwrites every column including project_id
      // (which is not in the serialized payload). Restore it from linked_entries
      // so the denormalized column stays consistent after any upsert.
      await customStatement(
        'UPDATE journal SET project_id = ($_projectIdSubquery) WHERE id = ?',
        [entry.id],
      );
      return 1;
    });
  }

  Future<int> addConflict(Conflict conflict) async {
    return into(conflicts).insertOnConflictUpdate(conflict);
  }

  Future<VclockStatus> detectConflict(
    JournalEntity existing,
    JournalEntity updated,
  ) async {
    final vcA = existing.meta.vectorClock;
    final vcB = updated.meta.vectorClock;

    if (vcA != null && vcB != null) {
      final status = VectorClock.compare(vcA, vcB);

      if (status == VclockStatus.concurrent) {
        DevLogger.warning(
          name: 'JournalDb',
          message: 'Conflicting vector clocks: $status',
        );
        final now = DateTime.now();
        await addConflict(
          Conflict(
            id: updated.meta.id,
            createdAt: now,
            updatedAt: now,
            serialized: jsonEncode(updated),
            schemaVersion: schemaVersion,
            status: ConflictStatus.unresolved.index,
          ),
        );
      }

      return status;
    }
    return VclockStatus.b_gt_a;
  }

  Future<JournalUpdateResult> updateJournalEntity(
    JournalEntity updated, {
    bool overrideComparison = false,
    bool overwrite = true,
  }) async {
    var applied = false;
    JournalUpdateSkipReason? skipReason;
    var rowsWritten = 0;
    final dbEntity = toDbEntity(updated).copyWith(
      updatedAt: DateTime.now(),
    );

    final existingDbEntity = await entityById(dbEntity.id);

    if (existingDbEntity != null && !overwrite) {
      skipReason = JournalUpdateSkipReason.overwritePrevented;
    } else if (existingDbEntity != null) {
      final existing = fromDbEntity(existingDbEntity);
      VclockStatus? status;
      try {
        status = await detectConflict(existing, updated);
      } catch (error, stackTrace) {
        _captureException(
          error,
          subDomain: 'detectConflict',
          stackTrace: stackTrace,
        );
        skipReason = JournalUpdateSkipReason.conflict;
      }

      final canApply =
          status == VclockStatus.b_gt_a ||
          (overrideComparison && status != null);

      if (canApply) {
        rowsWritten = await upsertJournalDbEntity(dbEntity);
        applied = true;
        final existingConflict = await conflictById(dbEntity.id);

        if (existingConflict != null) {
          await resolveConflict(existingConflict);
        }
      } else if (status != null) {
        _captureEvent(
          EnumToString.convertToString(status),
          subDomain: 'Conflict status',
        );
        skipReason = status == VclockStatus.concurrent
            ? JournalUpdateSkipReason.conflict
            : JournalUpdateSkipReason.olderOrEqual;
      } else {
        skipReason ??= JournalUpdateSkipReason.conflict;
      }
    } else {
      rowsWritten = await upsertJournalDbEntity(dbEntity);
      applied = true;
    }

    if (applied) {
      await _persistEntityJson(updated);
      await addLabeled(updated);
      return JournalUpdateResult.applied(rowsWritten: rowsWritten);
    }

    return JournalUpdateResult.skipped(
      reason: skipReason ?? JournalUpdateSkipReason.olderOrEqual,
    );
  }

  Future<Conflict?> conflictById(String id) async {
    final res = await (select(conflicts)..where((t) => t.id.equals(id))).get();
    if (res.isNotEmpty) {
      return res.first;
    }
    return null;
  }

  Future<void> purgeDeletedFiles() async {
    final deletedEntries = await (select(
      journal,
    )..where((tbl) => tbl.deleted.equals(true))).get();

    for (final entry in deletedEntries) {
      try {
        final journalEntity = JournalEntity.fromJson(
          jsonDecode(entry.serialized) as Map<String, dynamic>,
        );

        await journalEntity.maybeMap(
          journalImage: (JournalImage image) async {
            final fullPath = getFullImagePath(image);
            await _deleteFileIfExists(fullPath);
            await _deleteFileIfExists('$fullPath.json');
          },
          journalAudio: (JournalAudio audio) async {
            final fullPath = await AudioUtils.getFullAudioPath(audio);
            await _deleteFileIfExists(fullPath);
            await _deleteFileIfExists('$fullPath.json');
          },
          orElse: () async {
            // For all other entry types, just delete the JSON file
            final docDir = getDocumentsDirectory();
            await _deleteFileIfExists(entityPath(journalEntity, docDir));
          },
        );
      } catch (e) {
        // Log error but continue with other files
        getIt<DomainLogger>().error(
          LogDomain.database,
          e,
          subDomain: 'purgeDeletedFiles',
        );
      }
    }
  }

  /// Deletes [path] if it exists. A missing media file must not abort the
  /// purge of its sibling JSON descriptor (or vice versa), so deletes are
  /// existence-checked instead of letting [File.delete] throw.
  Future<void> _deleteFileIfExists(String path) async {
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Stream<double> purgeDeleted({
    bool backup = true,
    Duration stepDelay = const Duration(milliseconds: 50),
  }) async* {
    if (backup) {
      await createDbBackup(journalDbFileName);
    }

    // First delete the actual files
    await purgeDeletedFiles();

    // Get counts for each type
    final dashboardCount =
        await (select(dashboardDefinitions)
              ..where((tbl) => tbl.deleted.equals(true)))
            .get()
            .then((list) => list.length);

    final measurableCount =
        await (select(measurableTypes)
              ..where((tbl) => tbl.deleted.equals(true)))
            .get()
            .then((list) => list.length);

    final journalCount =
        await (select(journal)..where((tbl) => tbl.deleted.equals(true)))
            .get()
            .then((list) => list.length);

    final totalItems = dashboardCount + measurableCount + journalCount;

    if (totalItems == 0) {
      yield 1.0; // Already empty
      return;
    }

    // Purge dashboards
    if (dashboardCount > 0) {
      await (delete(
        dashboardDefinitions,
      )..where((tbl) => tbl.deleted.equals(true))).go();
    }
    yield 0.33; // 33% complete after dashboards
    await Future<void>.delayed(stepDelay);

    // Purge measurables
    if (measurableCount > 0) {
      await (delete(
        measurableTypes,
      )..where((tbl) => tbl.deleted.equals(true))).go();
    }
    yield 0.66; // 66% complete after measurables
    await Future<void>.delayed(stepDelay);

    // Purge journal entries
    if (journalCount > 0) {
      await (delete(journal)..where((tbl) => tbl.deleted.equals(true))).go();
    }
    yield 1.0; // 100% complete after journal entries
  }

  Stream<List<Conflict>> watchConflicts(
    ConflictStatus status, {
    int limit = 1000,
  }) {
    return conflictsByStatus(status.index, limit).watch();
  }

  Stream<List<Conflict>> watchConflictById(String id) {
    return conflictsById(id).watch();
  }

  Future<int> resolveConflict(Conflict conflict) {
    return (update(conflicts)..where((t) => t.id.equals(conflict.id))).write(
      conflict.copyWith(status: ConflictStatus.resolved.index),
    );
  }
}
