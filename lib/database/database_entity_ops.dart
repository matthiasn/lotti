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
  /// constructor. Protected so a test double can delay or fail one write
  /// and exercise [_publishSidecar]'s ordering.
  @protected
  @visibleForTesting
  Future<void> persistEntityJson(JournalEntity updated);

  // Per-entity ordering for sidecar writes. The transaction hands out a
  // ticket per applied write; sidecar writes for one id run one after the
  // other, and a ticket older than the newest one already on disk is
  // skipped — so two accepted writes of the same entity can never leave
  // the earlier document as the sync payload for the later row.
  final Map<String, int> _sidecarIssued = <String, int>{};
  final Map<String, int> _sidecarWritten = <String, int>{};
  final Map<String, Future<void>> _sidecarChain = <String, Future<void>>{};

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
        final now = clock.now();
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

  /// Applies [updated] to the journal after a vector-clock comparison with
  /// the stored row.
  ///
  /// The read of the existing row, the comparison, the upsert, the conflict
  /// bookkeeping and the `labeled` reconciliation run in **one transaction**:
  /// Drift serialises transactions on the write connection, so a concurrent
  /// write to the same id — a local edit racing an inbound sync, or two
  /// pooled readers seeing different snapshots — cannot slip between the
  /// check and the write. A caller that already holds a transaction (the
  /// sync inbound handler) simply nests this one.
  ///
  /// The JSON sidecar is written **after** the transaction commits: it is
  /// the sync payload, so it must never describe a row that rolled back,
  /// and writing it inside the transaction would hold the journal writer
  /// lock across file I/O. Sidecar writes for one entity are published in
  /// commit order (see [_publishSidecar]).
  Future<JournalUpdateResult> updateJournalEntity(
    JournalEntity updated, {
    bool overrideComparison = false,
    bool overwrite = true,
  }) async {
    final dbEntity = toDbEntity(updated).copyWith(
      updatedAt: clock.now(),
    );

    var ticket = 0;
    final result = await transaction(() async {
      var applied = false;
      JournalUpdateSkipReason? skipReason;
      var rowsWritten = 0;

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
        await addLabeled(updated);
        ticket = (_sidecarIssued[dbEntity.id] ?? 0) + 1;
        _sidecarIssued[dbEntity.id] = ticket;
        return JournalUpdateResult.applied(rowsWritten: rowsWritten);
      }

      return JournalUpdateResult.skipped(
        reason: skipReason ?? JournalUpdateSkipReason.olderOrEqual,
      );
    });

    if (result.applied) {
      await _publishSidecar(updated, ticket);
    }
    return result;
  }

  /// Writes the sidecar for [entity] after the sidecar writes queued before
  /// it for the same id, and only if no newer [ticket] has been written yet.
  ///
  /// A failed write does not poison the chain: the next writer for the id
  /// still runs, and the failure surfaces to this caller.
  Future<void> _publishSidecar(JournalEntity entity, int ticket) {
    final id = entity.meta.id;
    final previous = _sidecarChain[id] ?? Future<void>.value();
    late final Future<void> current;
    current = previous
        .catchError((Object _) {})
        .then((_) async {
          if ((_sidecarWritten[id] ?? 0) >= ticket) return;
          await persistEntityJson(entity);
          _sidecarWritten[id] = ticket;
        })
        .whenComplete(() {
          if (!identical(_sidecarChain[id], current)) return;
          _sidecarChain.remove(id);
          if (_sidecarWritten[id] == _sidecarIssued[id]) {
            _sidecarIssued.remove(id);
            _sidecarWritten.remove(id);
          }
        });
    _sidecarChain[id] = current;
    return current;
  }

  Future<Conflict?> conflictById(String id) async {
    final res = await (select(conflicts)..where((t) => t.id.equals(id))).get();
    if (res.isNotEmpty) {
      return res.first;
    }
    return null;
  }

  /// How many soft-deleted rows [purgeDeletedFiles] reads per round trip.
  /// Keyed on rowid so the walk never re-reads what it has already visited,
  /// and never holds every deleted entity's JSON in memory at once.
  static const int _purgeChunk = 500;

  /// Deletes the files — media and JSON sidecars — of every soft-deleted
  /// journal entity, in rowid chunks of [_purgeChunk].
  Future<void> purgeDeletedFiles() async {
    var lastRowId = 0;
    while (true) {
      final rows = await customSelect(
        'SELECT rowid AS rid, serialized FROM journal '
        'WHERE deleted = 1 AND rowid > ? ORDER BY rowid LIMIT ?',
        variables: [
          Variable.withInt(lastRowId),
          Variable.withInt(_purgeChunk),
        ],
        readsFrom: {journal},
      ).get();
      if (rows.isEmpty) return;
      for (final row in rows) {
        lastRowId = row.read<int>('rid');
        await _deleteFilesOf(row.read<String>('serialized'));
      }
    }
  }

  Future<void> _deleteFilesOf(String serialized) async {
    try {
      final journalEntity = JournalEntity.fromJson(
        jsonDecode(serialized) as Map<String, dynamic>,
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

  /// Deletes [path] if it exists. A missing media file must not abort the
  /// purge of its sibling JSON descriptor (or vice versa), so deletes are
  /// existence-checked instead of letting [File.delete] throw.
  Future<void> _deleteFileIfExists(String path) async {
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<int> _countDeleted(TableInfo<Table, Object?> table) async {
    final row = await customSelect(
      'SELECT COUNT(*) AS c FROM ${table.actualTableName} WHERE deleted = 1',
      readsFrom: {table},
    ).getSingle();
    return row.read<int>('c');
  }

  /// Removes every soft-deleted dashboard, measurable and journal row, after
  /// deleting the journal rows' files, reporting progress as it goes.
  ///
  /// Counts come from `COUNT(*)`, not from loading the rows, and the file
  /// walk streams in rowid chunks, so the purge costs the same memory on a
  /// journal with a hundred deleted entries and one with a hundred thousand.
  /// Progress is emitted after each table; nothing sleeps to make it
  /// visible.
  Stream<double> purgeDeleted({bool backup = true}) async* {
    if (backup) {
      await createDbBackup(journalDbFileName);
    }

    // First delete the actual files
    await purgeDeletedFiles();

    final dashboardCount = await _countDeleted(dashboardDefinitions);
    final measurableCount = await _countDeleted(measurableTypes);
    final journalCount = await _countDeleted(journal);

    if (dashboardCount + measurableCount + journalCount == 0) {
      yield 1.0; // Already empty
      return;
    }

    if (dashboardCount > 0) {
      await (delete(
        dashboardDefinitions,
      )..where((tbl) => tbl.deleted.equals(true))).go();
    }
    yield 0.33; // 33% complete after dashboards

    if (measurableCount > 0) {
      await (delete(
        measurableTypes,
      )..where((tbl) => tbl.deleted.equals(true))).go();
    }
    yield 0.66; // 66% complete after measurables

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
