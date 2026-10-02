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
  // constructor-injected `_loggingService` that lives on the [JournalDb]
  // shell class.

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

  /// Compares the stored [existing] version with the incoming [updated] one
  /// and records a concurrent [updated] as one of the entry's [Conflict]s.
  ///
  /// A version without a vector clock carries no causal information. It
  /// replaces a stored row that has none either, but never a clocked one: a
  /// late copy from before clocks existed would otherwise undo every edit
  /// made since (ADR 0083). Two concurrent deletions are not a conflict:
  /// there is nothing for the user to choose, and [updateJournalEntity]
  /// merges them. Nor are two versions of a pull request entry: their
  /// snapshots are fetched, not written by anyone, and [updateJournalEntity]
  /// keeps the newer observation.
  Future<VclockStatus> detectConflict(
    JournalEntity existing,
    JournalEntity updated,
  ) async {
    final vcA = existing.meta.vectorClock;
    final vcB = updated.meta.vectorClock;

    if (vcA != null && vcB != null) {
      final status = VectorClock.compare(vcA, vcB);

      if (status == VclockStatus.concurrent &&
          !_mergesConcurrent(existing, updated)) {
        DevLogger.warning(
          name: 'JournalDb',
          message: 'Conflicting vector clocks: $status',
        );
        await _recordConflict(updated);
      }

      return status;
    }
    return vcA != null ? VclockStatus.a_gt_b : VclockStatus.b_gt_a;
  }

  static bool _bothDeleted(JournalEntity a, JournalEntity b) =>
      a.meta.deletedAt != null && b.meta.deletedAt != null;

  /// Whether two concurrent versions are merged here rather than left to the
  /// user as a conflict.
  static bool _mergesConcurrent(JournalEntity a, JournalEntity b) =>
      _bothDeleted(a, b) || _pullRequestPair(a, b);

  /// Two concurrent versions of one pull request entry. A purge reduces a
  /// deleted pull request to a [JournalEntry] tombstone (ADR 0095), so either
  /// side may be one, as long as the other is still a pull request.
  static bool _pullRequestPair(JournalEntity a, JournalEntity b) =>
      (a is PullRequestEntry || a.isPurgedTombstone) &&
      (b is PullRequestEntry || b.isPurgedTombstone) &&
      (a is PullRequestEntry || b is PullRequestEntry);

  /// The merged row for two concurrent versions [_mergesConcurrent] accepts.
  ///
  /// A pull request pair is decided by observation, deleted or not, so two
  /// unlinks keep the newer snapshot too. Against a purge's tombstone the
  /// unlink wins under the join of both clocks; [_overStored] then compacts
  /// it as it does for every entry type.
  static JournalEntity _mergeConcurrent(
    JournalEntity stored,
    JournalEntity incoming,
  ) {
    if (!_pullRequestPair(stored, incoming)) {
      return _mergeDeletions(stored, incoming);
    }
    if (stored is PullRequestEntry && incoming is PullRequestEntry) {
      return mergeConcurrentPullRequestVersions(stored, incoming);
    }
    final tombstone = stored.isPurgedTombstone ? stored : incoming;
    return tombstone.copyWith(
      meta: tombstone.meta.copyWith(
        vectorClock: VectorClock.merge(
          stored.meta.vectorClock,
          incoming.meta.vectorClock,
        ),
      ),
    );
  }

  /// Stores [incoming] as an unresolved conflict of its entry, one row per
  /// version (ADR 0092).
  ///
  /// Nothing is stored when an unresolved conflict already holds the same
  /// version or a newer one: a late copy of an older version must not stand
  /// beside the version the user is shown. An unresolved conflict that
  /// [incoming] follows is replaced by it, since [incoming] includes it. Every
  /// other open conflict stays: a second concurrent version — a third
  /// device's, or this device's own save built on an entry read before a
  /// peer's version landed — is added beside the first instead of replacing
  /// it. A replaced local save was never sent, so replacing it lost it.
  Future<void> _recordConflict(JournalEntity incoming) async {
    final incomingClock = incoming.meta.vectorClock;
    final open = await _unresolvedConflictsOf(incoming.meta.id);
    for (final conflict in open) {
      if (_covers(incomingClock, _conflictClock(conflict))) return;
    }
    for (final conflict in open) {
      if (_covers(_conflictClock(conflict), incomingClock)) {
        await _deleteConflict(conflict);
      }
    }
    final now = clock.now();
    await addConflict(
      Conflict(
        id: incoming.meta.id,
        versionKey: incomingClock?.canonicalKey ?? '',
        createdAt: now,
        updatedAt: now,
        serialized: jsonEncode(incoming),
        schemaVersion: schemaVersion,
        status: ConflictStatus.unresolved.index,
      ),
    );
  }

  /// Marks resolved every unresolved conflict of the entry whose version the
  /// version just written, [written], is or follows — the user's resolution,
  /// or any later version that includes it. A conflict [written] does not
  /// include stays open: marking it resolved would drop the other version
  /// without the user choosing so. With several open, a resolution settles
  /// the one the user decided and leaves the next for them.
  Future<void> _settleConflictCoveredBy(JournalEntity written) async {
    for (final conflict in await _unresolvedConflictsOf(written.meta.id)) {
      final conflictClock = _conflictClock(conflict);
      if (conflictClock == null ||
          _covers(conflictClock, written.meta.vectorClock)) {
        await resolveConflict(conflict);
      }
    }
  }

  /// The open conflict version of [entryId] whose clock is exactly
  /// [vectorClock], or null. A concurrent version a peer asks for by deep
  /// backfill may live here rather than in the row (ADR 0092).
  Future<JournalEntity?> openConflictVersion(
    String entryId,
    VectorClock vectorClock,
  ) async {
    for (final conflict in await _unresolvedConflictsOf(entryId)) {
      final conflictClock = _conflictClock(conflict);
      if (conflictClock != null &&
          VectorClock.compare(conflictClock, vectorClock) ==
              VclockStatus.equal) {
        return fromSerialized(conflict.serialized);
      }
    }
    return null;
  }

  Future<List<Conflict>> _unresolvedConflictsOf(String entryId) async =>
      (await conflictsForEntry(
        entryId,
      )).where((c) => c.status == ConflictStatus.unresolved.index).toList();

  Future<void> _deleteConflict(Conflict conflict) =>
      (delete(conflicts)..where(
            (t) =>
                t.id.equals(conflict.id) &
                t.versionKey.equals(conflict.versionKey),
          ))
          .go();

  /// The vector clock of the version stored in [conflict], or null when it
  /// has none or cannot be read.
  VectorClock? _conflictClock(Conflict conflict) {
    try {
      return JournalEntity.fromJson(
        jsonDecode(conflict.serialized) as Map<String, dynamic>,
      ).meta.vectorClock;
    } catch (error, stackTrace) {
      _captureException(
        error,
        subDomain: 'conflictClock',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Whether [b] is the version [a] names or a successor of it.
  static bool _covers(VectorClock? a, VectorClock? b) {
    if (a == null || b == null) return false;
    final status = VectorClock.compare(a, b);
    return status == VclockStatus.b_gt_a || status == VclockStatus.equal;
  }

  /// Two concurrent deletions of one entry, merged the same way on every
  /// device: the canonically greater one's fields under the join of both
  /// clocks, so the row covers both deletions and every device holds it.
  static JournalEntity _mergeDeletions(
    JournalEntity stored,
    JournalEntity incoming,
  ) {
    final storedClock = stored.meta.vectorClock!;
    final incomingClock = incoming.meta.vectorClock!;
    final winner =
        VectorClock.compareCanonically(incomingClock, storedClock) > 0
        ? incoming
        : stored;
    return winner.copyWith(
      meta: winner.meta.copyWith(
        vectorClock: VectorClock.merge(storedClock, incomingClock),
      ),
    );
  }

  /// What an applied [written] version leaves stored over [stored], where one
  /// of them is a purge's tombstone (ADR 0095).
  ///
  /// A tombstone applied over a copy that still holds its fields deletes that
  /// copy: the row keeps its own fields — and its files, for this device's
  /// own purge to remove — deleted under the tombstone's clock. A deletion
  /// applied over a tombstone is compacted in turn, so fields a purge removed
  /// do not come back with a peer's copy of the deletion. Anything else — a
  /// live version over a tombstone included — is stored as it came.
  static JournalEntity _overStored(
    JournalEntity stored,
    JournalEntity written,
  ) {
    final deletedAt = written.meta.deletedAt;
    if (deletedAt == null) return written;
    if (written.isPurgedTombstone && !stored.isPurgedTombstone) {
      return stored.copyWith(
        meta: stored.meta.copyWith(
          updatedAt: written.meta.updatedAt,
          vectorClock: written.meta.vectorClock,
          deletedAt: deletedAt,
        ),
      );
    }
    if (stored.isPurgedTombstone && !written.isPurgedTombstone) {
      return written.toPurgedTombstone(stored.meta.purgedAt!);
    }
    return written;
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
  /// [precondition], when supplied, runs inside that same transaction before
  /// any write. It must only read this journal database, without side effects
  /// or external awaits. Use direct queries, not readers that coalesce calls
  /// across transaction zones. Returning false leaves the row untouched.
  ///
  /// The stored row is read with its soft deletion
  /// ([entityByIdIncludingDeleted]): a deletion is a version like any other,
  /// so a late copy of the version it replaced is refused, and an edit made
  /// concurrently with it is a conflict. A purge's tombstone is such a row
  /// too: [_overStored] keeps it compacted, or applies an incoming one to the
  /// stored copy's own fields (ADR 0095). Only a creation ([overwrite] false)
  /// replaces a deleted row outright, as it always has. Two concurrent
  /// deletions are merged ([_mergeDeletions]), and so are two concurrent
  /// versions of a pull request entry ([mergeConcurrentPullRequestVersions],
  /// `specs/tla/PullRequestSnapshot.tla`). An applied write marks the
  /// entry's conflict resolved only when it includes the conflict's version
  /// (ADR 0083).
  ///
  /// The row is the only stored copy of the entity. Sync reads its payload
  /// from here; nothing writes the entity to a file.
  Future<JournalUpdateResult> updateJournalEntity(
    JournalEntity updated, {
    bool overwrite = true,
    Future<bool> Function()? precondition,
  }) async {
    var written = updated;
    return transaction(() async {
      var applied = false;
      JournalUpdateSkipReason? skipReason;
      var rowsWritten = 0;

      if (precondition != null && !await precondition()) {
        return JournalUpdateResult.skipped(
          reason: JournalUpdateSkipReason.overwritePrevented,
        );
      }
      final stored = await entityByIdIncludingDeleted(updated.meta.id);
      final existingDbEntity = stored != null && stored.deleted && !overwrite
          ? null
          : stored;

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

        final merged =
            status == VclockStatus.concurrent &&
            _mergesConcurrent(existing, updated);
        if (merged) {
          written = _mergeConcurrent(existing, updated);
        }

        if (status == VclockStatus.b_gt_a || merged) {
          written = _overStored(existing, written);
          rowsWritten = await upsertJournalDbEntity(_toRow(written));
          applied = true;
          await _settleConflictCoveredBy(written);
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
        rowsWritten = await upsertJournalDbEntity(_toRow(updated));
        applied = true;
      }

      if (applied) {
        await addLabeled(written);
        return JournalUpdateResult.applied(rowsWritten: rowsWritten);
      }

      return JournalUpdateResult.skipped(
        reason: skipReason ?? JournalUpdateSkipReason.olderOrEqual,
      );
    });
  }

  JournalDbEntity _toRow(JournalEntity entity) =>
      toDbEntity(entity).copyWith(updatedAt: clock.now());

  /// Every conflict row of the entry [entryId], resolved or not, newest
  /// first: one per concurrent version (ADR 0092).
  Future<List<Conflict>> conflictsForEntry(String entryId) =>
      conflictsById(entryId).get();

  /// How many soft-deleted rows [purgeDeleted] compacts per transaction.
  /// Keyed on rowid so the walk never re-reads what it has already visited,
  /// and never holds every deleted entity's JSON in memory at once.
  static const int _purgeChunk = 500;

  /// Selects the soft-deleted journal rows a purge has not yet compacted to
  /// tombstones. A tombstone carries `meta.purgedAt`; no other row does. A
  /// row whose JSON does not parse is selected too, without handing it to
  /// `json_extract`, which would fail the whole statement.
  static const String _unpurgedDeleted =
      'deleted = 1 AND CASE WHEN json_valid(serialized) '
      r"THEN json_extract(serialized, '$.meta.purgedAt') END IS NULL";

  /// Reads the next chunk of soft-deleted, not yet purged journal rows after
  /// [afterRowId], in rowid order.
  Future<List<QueryRow>> _unpurgedDeletedChunk(int afterRowId) => customSelect(
    'SELECT rowid AS rid, id, serialized FROM journal '
    'WHERE $_unpurgedDeleted AND rowid > ? ORDER BY rowid LIMIT ?',
    variables: [
      Variable.withInt(afterRowId),
      Variable.withInt(_purgeChunk),
    ],
    readsFrom: {journal},
  ).get();

  /// Compacts every soft-deleted journal row not yet purged to its tombstone
  /// ([JournalEntityTombstone.toPurgedTombstone]), purged at [purgedAt], and
  /// then deletes the files — media and any JSON an older build wrote beside
  /// the entry — of the rows it compacted.
  ///
  /// The tombstone keeps the deletion's id and clock, so it stays the
  /// deletion: backfill serves it to a device that missed it, and a late copy
  /// of an older version is refused (ADR 0095). Nothing is sent — it is the
  /// same version. A row whose JSON no longer parses cannot be compacted and
  /// is removed, as every purge did before.
  ///
  /// Each chunk of [_purgeChunk] rows is read and rewritten in one
  /// transaction, so a row restored, edited or replaced by a newer version
  /// since the read cannot be overwritten with a tombstone of the stale one.
  /// Files are deleted only after the chunk commits, and only for the rows it
  /// compacted: an entry restored meanwhile keeps its media.
  Future<void> _compactDeletedJournalRows(DateTime purgedAt) async {
    var lastRowId = 0;
    while (true) {
      final compacted = await transaction(() async {
        final rows = await _unpurgedDeletedChunk(lastRowId);
        final serialized = <String>[];
        for (final row in rows) {
          lastRowId = row.read<int>('rid');
          final json = row.read<String>('serialized');
          serialized.add(json);
          final JournalEntity entity;
          try {
            entity = JournalEntity.fromJson(
              jsonDecode(json) as Map<String, dynamic>,
            );
          } catch (_) {
            // Reported once, by the file walk below, which reads it too.
            await (delete(
              journal,
            )..where((t) => t.id.equals(row.read<String>('id')))).go();
            continue;
          }
          final tombstone = entity.toPurgedTombstone(purgedAt);
          await upsertJournalDbEntity(_toRow(tombstone));
          await addLabeled(tombstone);
        }
        return serialized;
      });
      if (compacted.isEmpty) return;
      for (final json in compacted) {
        await _deleteFilesOf(json);
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
        subDomain: 'purgeDeleted',
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

  Future<int> _countDeleted(
    TableInfo<Table, Object?> table, {
    String where = 'deleted = 1',
  }) async {
    final row = await customSelect(
      'SELECT COUNT(*) AS c FROM ${table.actualTableName} WHERE $where',
      readsFrom: {table},
    ).getSingle();
    return row.read<int>('c');
  }

  /// Removes every soft-deleted dashboard and measurable row and compacts
  /// every soft-deleted journal row to its tombstone, deleting the journal
  /// rows' files, reporting progress as it goes.
  ///
  /// A journal row is not removed: a device that never received the deletion
  /// would keep the entry for good, and a late copy of an older version would
  /// bring it back here (ADR 0095). Its tombstone holds the id, dates, clock
  /// and deletion and nothing else, and a later purge skips it.
  ///
  /// Counts come from `COUNT(*)`, not from loading the rows, and the walks
  /// stream in rowid chunks, so the purge costs the same memory on a
  /// journal with a hundred deleted entries and one with a hundred thousand.
  /// Progress is emitted after each table; nothing sleeps to make it
  /// visible.
  Stream<double> purgeDeleted({bool backup = true}) async* {
    if (backup) {
      await createDbBackup(journalDbFileName);
    }

    final dashboardCount = await _countDeleted(dashboardDefinitions);
    final measurableCount = await _countDeleted(measurableTypes);
    final journalCount = await _countDeleted(journal, where: _unpurgedDeleted);

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
      await _compactDeletedJournalRows(clock.now());
    }
    yield 1.0; // 100% complete after journal entries
  }

  Stream<List<Conflict>> watchConflicts(
    ConflictStatus status, {
    int limit = 1000,
  }) {
    return conflictsByStatus(status.index, limit).watch();
  }

  /// Every conflict row of the entry [id], one per concurrent version,
  /// newest first.
  Stream<List<Conflict>> watchConflictById(String id) {
    return conflictsById(id).watch();
  }

  /// Marks [conflict] — one version of its entry — resolved.
  Future<int> resolveConflict(Conflict conflict) {
    return (update(conflicts)..where(
          (t) =>
              t.id.equals(conflict.id) &
              t.versionKey.equals(conflict.versionKey),
        ))
        .write(conflict.copyWith(status: ConflictStatus.resolved.index));
  }
}
