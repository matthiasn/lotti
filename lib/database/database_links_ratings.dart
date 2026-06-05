part of 'database.dart';

typedef LinkedEntityTimeSpan = ({
  String id,
  DateTime dateFrom,
  DateTime dateTo,
});

/// Entry-link and rating query surface for [JournalDb], including the
/// microtask coalescers for basic links and rating-id lookups, and the
/// guarded [upsertEntryLink] write path.
mixin _JournalDbLinksRatings
    on _$JournalDb, _JournalDbConfigFlags, _JournalDbJournalQueries {
  Future<List<JournalEntity>> getLinkedEntities(String linkedFrom) async {
    final dbEntities = await _queryWithPrivateFilter(
      allPrivate: () => linkedJournalEntitiesAllPrivate(linkedFrom).get(),
      filtered: (s) => linkedJournalEntities(linkedFrom, s).get(),
    );
    return dbEntities.map(fromDbEntity).toList();
  }

  Future<List<JournalDbEntity>> getLinkedToEntities(String linkedTo) {
    return _queryWithPrivateFilter(
      allPrivate: () => linkedToJournalEntities(linkedTo).get(),
      filtered: (s) =>
          linkedToJournalEntitiesByPrivateStatuses(linkedTo, s).get(),
    );
  }

  /// Get linked entities for multiple parent IDs in bulk to avoid N+1 queries
  Future<Map<String, List<JournalEntity>>> getBulkLinkedEntities(
    Set<String> fromIds,
  ) async {
    // Early return for empty set
    if (fromIds.isEmpty) {
      return <String, List<JournalEntity>>{};
    }

    // Get all links FROM the parent IDs (matching getLinkedEntities behavior)
    final linkEntries = await linksFromIds(fromIds.toList()).get();
    final links = linkEntries.map(entryLinkFromLinkedDbEntry).toList();

    // Collect all target IDs
    final targetIds = links.map((link) => link.toId).toSet();

    // Fetch all linked entities in one query
    final entities = await getJournalEntitiesForIdsUnordered(targetIds);

    // Group by parent ID with deduplication tracking
    final result = <String, List<JournalEntity>>{
      for (final id in fromIds) id: [],
    };
    final seenEntities = <String, Set<String>>{
      for (final id in fromIds) id: {},
    };

    // Create entity lookup map for O(1) access
    final entityMap = <String, JournalEntity>{};
    for (final entity in entities) {
      entityMap[entity.meta.id] = entity;
    }

    // Map entities to their parent IDs using O(1) lookup with deduplication
    for (final link in links) {
      final entity = entityMap[link.toId];
      if (entity != null) {
        // Only add if not already seen for this parent
        if (seenEntities[link.fromId]!.add(entity.meta.id)) {
          result[link.fromId]?.add(entity);
        }
      }
    }

    // Sort each result list by dateFrom descending to match single-parent semantics
    for (final entry in result.entries) {
      entry.value.sort((a, b) => b.meta.dateFrom.compareTo(a.meta.dateFrom));
    }

    return result;
  }

  Future<Map<String, List<LinkedEntityTimeSpan>>> getBulkLinkedTimeSpans(
    Set<String> fromIds,
  ) async {
    if (fromIds.isEmpty) {
      return <String, List<LinkedEntityTimeSpan>>{};
    }

    final fromIdList = fromIds.toList(growable: false);
    final fromPlaceholders = List.filled(fromIdList.length, '?').join(', ');
    final privateStatuses = await _visiblePrivateStatuses();
    final filterPrivate = !_matchesAllPrivateStates(privateStatuses);
    final privateClause = filterPrivate
        ? 'AND journal.private IN (${List.filled(privateStatuses.length, '?').join(', ')})'
        : '';

    final rows = await customSelect(
      '''
      SELECT
        linked_entries.from_id AS parent_id,
        journal.id AS entity_id,
        journal.date_from AS date_from,
        journal.date_to AS date_to
      FROM linked_entries
      INNER JOIN journal ON journal.id = linked_entries.to_id
      WHERE linked_entries.from_id IN ($fromPlaceholders)
        AND linked_entries.hidden = FALSE
        AND journal.deleted = FALSE
        AND journal.type NOT IN ('Task', 'AiResponse', 'JournalAudio')
        $privateClause
      ''',
      variables: [
        for (final fromId in fromIdList) Variable<String>(fromId),
        if (filterPrivate)
          for (final privateStatus in privateStatuses)
            Variable<bool>(privateStatus),
      ],
      readsFrom: {linkedEntries, journal},
    ).get();

    final result = <String, List<LinkedEntityTimeSpan>>{
      for (final id in fromIds) id: <LinkedEntityTimeSpan>[],
    };
    final seenEntities = <String, Set<String>>{
      for (final id in fromIds) id: <String>{},
    };

    for (final row in rows) {
      final parentId = row.read<String>('parent_id');
      final entityId = row.read<String>('entity_id');
      final seenForParent = seenEntities[parentId];
      if (seenForParent == null || !seenForParent.add(entityId)) {
        continue;
      }

      result[parentId]!.add((
        id: entityId,
        dateFrom: row.read<DateTime>('date_from'),
        dateTo: row.read<DateTime>('date_to'),
      ));
    }

    return result;
  }

  /// Find existing rating entity for a target entry and catalog
  /// (for edit/re-open).
  Future<RatingEntry?> getRatingForTimeEntry(
    String targetId, {
    String catalogId = 'session',
  }) async {
    final res = await ratingForTimeEntry(targetId, catalogId).get();
    if (res.isEmpty) return null;
    final entity = fromDbEntity(res.first);
    return entity is RatingEntry ? entity : null;
  }

  /// Fetch all ratings linked to a target entity (across all catalogs).
  Future<List<RatingEntry>> getAllRatingsForTarget(String targetId) async {
    final res = await allRatingsForTarget(targetId).get();
    return res.map(fromDbEntity).whereType<RatingEntry>().toList();
  }

  /// Bulk fetch rating IDs for a set of time entries.
  ///
  /// The query orders by `updated_at ASC` so that when multiple ratings
  /// link to the same time entry, the most recently updated one wins
  /// (last-write-wins in the map comprehension).
  ///
  /// Concurrent callers within the same microtask (the DailyOS prefetch
  /// window fires `_fetchAllData` per date) share a single round-trip: the
  /// wave merges every caller's id set, issues one `ratingsForTimeEntries`
  /// query, and hands each caller a map restricted to its own ids.
  ///
  /// Per-row ordering (`j.updated_at ASC`) is preserved across the wave so
  /// last-write-wins remains stable within each caller's subset. The
  /// caller's set is snapshotted before scheduling so the post-query filter
  /// never reads a mutated view if the caller reuses or clears the set
  /// before the coalesced wave fires.
  Future<Map<String, String>> getRatingIdsForTimeEntries(
    Set<String> timeEntryIds,
  ) {
    final snapshot = Set<String>.unmodifiable(timeEntryIds);
    if (snapshot.isEmpty) return Future.value(const <String, String>{});
    return _coalesceRatings(snapshot);
  }

  _PendingRatingsWave? _pendingRatingsWave;

  /// Single-shot query executed by the ratings coalescer. Extracted as a
  /// protected seam so tests can count DB round-trips without depending on
  /// a query interceptor. The merged wave set can grow past SQLite's
  /// 999-variable limit when many prefetched dates converge in one
  /// microtask; chunk through [_sqliteInListChunk] with a stable
  /// `updated_at ASC` order preserved across chunks so last-write-wins
  /// holds at the map-comprehension step.
  @protected
  @visibleForTesting
  Future<List<RatingsForTimeEntriesResult>> runRatingsForTimeEntriesQueryForIds(
    Set<String> ids,
  ) async {
    final idList = ids.toList(growable: false);
    if (idList.length <= _sqliteInListChunk) {
      return ratingsForTimeEntries(idList).get();
    }
    final combined = <RatingsForTimeEntriesResult>[];
    for (var i = 0; i < idList.length; i += _sqliteInListChunk) {
      final end = (i + _sqliteInListChunk).clamp(0, idList.length);
      final chunk = idList.sublist(i, end);
      combined.addAll(await ratingsForTimeEntries(chunk).get());
    }
    return combined;
  }

  Future<Map<String, String>> _coalesceRatings(Set<String> ids) {
    final wave = _pendingRatingsWave ??= _PendingRatingsWave();
    wave.mergedIds.addAll(ids);
    if (!wave.scheduled) {
      wave.scheduled = true;
      scheduleMicrotask(() async {
        _pendingRatingsWave = null;
        try {
          final rows = await runRatingsForTimeEntriesQueryForIds(
            wave.mergedIds,
          );
          wave.completer.complete(rows);
        } catch (error, stack) {
          wave.completer.completeError(error, stack);
        }
      });
    }
    return wave.completer.future.then(
      (rows) => {
        for (final row in rows)
          if (ids.contains(row.timeEntryId)) row.timeEntryId: row.ratingId,
      },
    );
  }

  Future<List<EntryLink>> linksForEntryIds(Set<String> ids) async {
    if (ids.isEmpty) return <EntryLink>[];
    final entryLinks = await linksForIds(ids.toList()).get();
    return entryLinks.map(entryLinkFromLinkedDbEntry).toList();
  }

  /// Returns only [BasicLink] entries for the given [ids], filtering out
  /// RatingLinks at the SQL level using the `type` column.
  ///
  /// Concurrent callers within the same microtask (e.g. the DailyOS prefetch
  /// window firing `_fetchAllData` per date) share a single round-trip: the
  /// wave merges every caller's id set, issues one `to_id IN (…)` query, and
  /// hands each caller the subset matching its own ids.
  ///
  /// The caller's set is snapshotted before scheduling so the post-query
  /// filter never reads a mutated view if the caller reuses or clears the
  /// set before the coalesced wave fires.
  Future<List<EntryLink>> basicLinksForEntryIds(Set<String> ids) {
    final snapshot = Set<String>.unmodifiable(ids);
    if (snapshot.isEmpty) return Future.value(const <EntryLink>[]);
    return _coalesceBasicLinks(snapshot);
  }

  _PendingLinksWave? _pendingBasicLinksWave;

  /// Single-shot query executed by the basic-links coalescer. Extracted as a
  /// protected seam so tests can count DB round-trips without depending on
  /// a query interceptor.
  @protected
  @visibleForTesting
  Future<List<EntryLink>> runBasicLinksQueryForIds(Set<String> ids) async {
    final rows =
        await (select(linkedEntries)..where(
              (t) => t.toId.isIn(ids.toList()) & t.type.equals('BasicLink'),
            ))
            .get();
    return rows.map(entryLinkFromLinkedDbEntry).toList();
  }

  Future<List<EntryLink>> _coalesceBasicLinks(Set<String> ids) {
    final wave = _pendingBasicLinksWave ??= _PendingLinksWave();
    wave.mergedIds.addAll(ids);
    if (!wave.scheduled) {
      wave.scheduled = true;
      scheduleMicrotask(() async {
        _pendingBasicLinksWave = null;
        try {
          final links = await runBasicLinksQueryForIds(wave.mergedIds);
          wave.completer.complete(links);
        } catch (error, stack) {
          wave.completer.completeError(error, stack);
        }
      });
    }
    return wave.completer.future.then(
      (links) => [
        for (final link in links)
          if (ids.contains(link.toId)) link,
      ],
    );
  }

  Future<List<EntryLink>> linksForEntryIdsBidirectional(Set<String> ids) async {
    if (ids.isEmpty) return <EntryLink>[];
    final idList = ids.toList();
    final entryLinks =
        await (select(linkedEntries)..where(
              (t) => t.fromId.isIn(idList) | t.toId.isIn(idList),
            ))
            .get();
    return entryLinks.map(entryLinkFromLinkedDbEntry).toList();
  }

  Future<EntryLink?> entryLinkById(String id) async {
    final res = await (select(
      linkedEntries,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (res == null) return null;
    return entryLinkFromLinkedDbEntry(res);
  }

  Future<int> upsertEntryLink(EntryLink link) async {
    if (link.fromId != link.toId) {
      try {
        // Equality precheck: if an entry with the same id exists and the
        // serialized payload is identical, skip the UPSERT to avoid a no-op
        // UPDATE and downstream log noise.
        final existing = await (select(
          linkedEntries,
        )..where((t) => t.id.equals(link.id))).getSingleOrNull();
        if (existing != null) {
          final incomingSerialized = jsonEncode(link);
          if (existing.serialized == incomingSerialized) {
            return 0; // no change needed
          }
        }
      } catch (_) {
        // Best-effort precheck only; fall through to UPSERT on failure.
      }

      // Guard against secondary UNIQUE(from_id, to_id, type) constraint.
      // insertOnConflictUpdate only handles primary key conflicts, so a
      // duplicate (from_id, to_id, type) with a different id would throw.
      final dbLink = linkedDbEntity(link);
      final existingByTriple =
          await (select(linkedEntries)..where(
                (t) =>
                    t.fromId.equals(dbLink.fromId) &
                    t.toId.equals(dbLink.toId) &
                    t.type.equals(dbLink.type),
              ))
              .getSingleOrNull();
      if (existingByTriple != null && existingByTriple.id != dbLink.id) {
        if (existingByTriple.hidden != true) {
          return 0; // genuine active duplicate — block it
        }
        // The existing row is a soft-deleted tombstone. Hard-delete it so the
        // UNIQUE(from_id, to_id, type) constraint doesn't block the new insert.
        await (delete(
          linkedEntries,
        )..where((t) => t.id.equals(existingByTriple.id))).go();
      }

      final res = await into(linkedEntries).insertOnConflictUpdate(dbLink);

      // Keep the denormalized project_id column in sync whenever a
      // ProjectLink is created or soft-deleted. Use the same "latest
      // non-hidden ProjectLink wins" subquery so late-arriving sync
      // messages and hide-then-restore sequences remain correct.
      if (res != 0 && dbLink.type == 'ProjectLink') {
        await customStatement(
          'UPDATE journal SET project_id = ($_projectIdSubquery) WHERE id = ?',
          [dbLink.toId],
        );
      }

      return res;
    } else {
      return 0;
    }
  }
}

/// In-flight coalescing wave for `basicLinksForEntryIds`. Concurrent callers
/// within the same microtask merge their id sets; the wave fires one
/// `to_id IN (…)` query and each caller filters the full result down to
/// its own ids.
class _PendingLinksWave {
  final Set<String> mergedIds = <String>{};
  bool scheduled = false;
  final Completer<List<EntryLink>> completer =
      Completer<List<EntryLink>>.sync();
}

/// In-flight coalescing wave for `getRatingIdsForTimeEntries`. Mirrors
/// [_PendingLinksWave] but keeps drift's rating-query result rows so each
/// caller can reconstruct its own last-write-wins map for its id subset.
class _PendingRatingsWave {
  final Set<String> mergedIds = <String>{};
  bool scheduled = false;
  final Completer<List<RatingsForTimeEntriesResult>> completer =
      Completer<List<RatingsForTimeEntriesResult>>.sync();
}
