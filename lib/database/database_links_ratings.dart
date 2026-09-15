part of 'database.dart';

typedef LinkedEntityTimeSpan = ({
  String id,
  DateTime dateFrom,
  DateTime dateTo,
});

/// Entry-link and rating query surface for [JournalDb], including the
/// microtask coalescer for basic-link lookups and the guarded
/// [upsertEntryLink] write path.
mixin _JournalDbLinksRatings
    on _$JournalDb, _JournalDbConfigFlags, _JournalDbJournalQueries {
  /// Returns raw links for Sync staging without applying the UI's hidden-link
  /// filter. Hidden links are persisted replication state and must reach a new
  /// device even though ordinary linked-entity views exclude them.
  Future<List<LinkedDbEntry>> linkRowsFromIdsIncludingHidden(
    List<String> fromIds,
  ) {
    return (select(
      linkedEntries,
    )..where((row) => row.fromId.isIn(fromIds))).get();
  }

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
    final privateStatuses = await _visiblePrivateStatuses();
    final filterPrivate = !_matchesAllPrivateStates(privateStatuses);
    final privateClause = filterPrivate
        ? "AND journal.private IN (${List.filled(privateStatuses.length, '?').join(', ')})"
        : '';

    final result = <String, List<LinkedEntityTimeSpan>>{
      for (final id in fromIds) id: <LinkedEntityTimeSpan>[],
    };
    final seenEntities = <String, Set<String>>{
      for (final id in fromIds) id: <String>{},
    };

    // Chunk the parent ids so a caller fanning out past the DailyOS
    // prefetch window cannot blow past SQLite's bind-variable cap — same
    // pattern as the other bulk-by-id helpers in this library.
    for (var i = 0; i < fromIdList.length; i += _sqliteInListChunk) {
      final chunkEnd = (i + _sqliteInListChunk).clamp(0, fromIdList.length);
      final chunk = fromIdList.sublist(i, chunkEnd);
      final fromPlaceholders = List.filled(chunk.length, '?').join(', ');

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
          for (final fromId in chunk) Variable<String>(fromId),
          if (filterPrivate)
            for (final privateStatus in privateStatuses)
              Variable<bool>(privateStatus),
        ],
        readsFrom: {linkedEntries, journal},
      ).get();

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

  /// Returns typed links (e.g. `blocks`, `followsUp`) touching any of [ids]
  /// in either direction, restricted to [types] (the `linked_entries.type`
  /// column values from [linkedDbEntity], e.g. `'BlocksLink'`).
  ///
  /// Two indexed selects — one on `to_id`, one on `from_id`, both scoped by
  /// `type` — unioned and deduplicated by link id in Dart, mirroring the
  /// [basicLinksForEntryIds] discipline. Unlike that method, this is not
  /// microtask-coalesced: callers batch their own id sets, and the type set
  /// is typically small and stable per call site, so a coalescing wave would
  /// add complexity without the fan-out pressure that justifies it there.
  Future<List<EntryLink>> typedLinksForTaskIds(
    Set<String> ids, {
    required Set<String> types,
  }) async {
    if (ids.isEmpty || types.isEmpty) return <EntryLink>[];
    final idList = ids.toList(growable: false);
    final typeList = types.toList(growable: false);

    final toRows =
        await (select(linkedEntries)..where(
              (t) => t.toId.isIn(idList) & t.type.isIn(typeList),
            ))
            .get();
    final fromRows =
        await (select(linkedEntries)..where(
              (t) => t.fromId.isIn(idList) & t.type.isIn(typeList),
            ))
            .get();

    final seenIds = <String>{};
    final result = <EntryLink>[];
    for (final row in toRows.followedBy(fromRows)) {
      if (seenIds.add(row.id)) {
        result.add(entryLinkFromLinkedDbEntry(row));
      }
    }
    return result;
  }

  /// Deletes only the [type]-typed link between [fromId] and [toId], leaving
  /// any other type coexisting between the same pair intact. Unlike the
  /// generic `deleteLink` (which deletes every type for the pair), this is
  /// needed once a pair can hold both a `BasicLink` and e.g. a `BlocksLink`
  /// simultaneously (ADR 0042) — unlinking one must not silently remove the
  /// other.
  Future<int> deleteTypedLink(String fromId, String toId, String type) {
    return (delete(linkedEntries)..where(
          (t) =>
              t.fromId.equals(fromId) &
              t.toId.equals(toId) &
              t.type.equals(type),
        ))
        .go();
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

  /// Inserts or updates [link], refusing self-links and active duplicates.
  ///
  /// The equality pre-read, the `(from_id, to_id, type)` duplicate check,
  /// the tombstone replacement and the upsert run in one transaction, so two
  /// concurrent creations of the same link — a local one racing the same
  /// link arriving by sync — cannot both pass the duplicate check and then
  /// collide on the UNIQUE constraint. A failing read propagates; it is a
  /// database error, not a reason to write blind.
  Future<int> upsertEntryLink(EntryLink link) async {
    if (link.fromId == link.toId) {
      return 0;
    }
    return transaction(() async {
      // Equality precheck: if an entry with the same id exists and the
      // serialized payload is identical, skip the UPSERT to avoid a no-op
      // UPDATE and downstream log noise.
      final existing = await (select(
        linkedEntries,
      )..where((t) => t.id.equals(link.id))).getSingleOrNull();
      if (existing != null && existing.serialized == jsonEncode(link)) {
        return 0; // no change needed
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
    });
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
