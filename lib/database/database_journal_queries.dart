part of 'database.dart';

/// Journal-entity read paths for [JournalDb]: by-id lookups (with
/// microtask coalescing), bulk fetches, filtered list queries, calendar
/// range reads (also coalesced), and the vector-clock streams used by
/// sync backfill.
mixin _JournalDbJournalQueries on _$JournalDb, _JournalDbConfigFlags {
  Future<JournalDbEntity?> entityById(String id) async {
    final res =
        await (select(journal)
              ..where((t) => t.id.equals(id))
              ..where((t) => t.deleted.equals(false)))
            .get();

    return res.firstOrNull;
  }

  Future<JournalEntity?> journalEntityById(String id) async {
    final dbEntity = await _coalesceEntityById(id);
    if (dbEntity != null) {
      return fromDbEntity(dbEntity);
    }
    return null;
  }

  // Microtask-coalescing state for `journalEntityById`. Riverpod
  // `FutureProvider.autoDispose.family` shapes (e.g.
  // `taskLiveDataProvider`) spin up one provider per visible row in a
  // scrolling list; when a tasks page mounts ~30 rows simultaneously,
  // each fires its own single-id read. The cluster shows up in the
  // super-slow log as ~30 nearly-identical `WHERE id = ? AND deleted = ?`
  // selects all reporting the same elapsed time — they're queued behind
  // each other in the read pool, not actually slow per row. The
  // coalescer merges every concurrent caller in one microtask wave into
  // one bulk `journalEntitiesByIdsUnorderedAllPrivate` round-trip; each
  // caller picks its own id out of the resulting map.
  //
  // Only the public `journalEntityById` is coalesced. `entityById` (the
  // internal read used inside `upsertJournalDbEntity`'s pre-write check)
  // stays direct so it sees a strict snapshot rather than joining a
  // microtask wave outside the write transaction.
  _PendingEntityByIdWave? _pendingEntityByIdWave;

  /// Single-shot bulk fetch executed by the entity-by-id coalescer.
  /// Extracted as a protected seam so tests can count DB round-trips
  /// and inject failures without depending on a query interceptor.
  @protected
  @visibleForTesting
  Future<List<JournalDbEntity>> runEntitiesByIdsFetch(Set<String> ids) {
    return journalEntitiesByIdsUnorderedAllPrivate(ids.toList()).get();
  }

  Future<JournalDbEntity?> _coalesceEntityById(String id) {
    final wave = _pendingEntityByIdWave ??= _PendingEntityByIdWave();
    wave.mergedIds.add(id);
    if (!wave.scheduled) {
      wave.scheduled = true;
      scheduleMicrotask(() async {
        _pendingEntityByIdWave = null;
        try {
          final entities = await runEntitiesByIdsFetch(wave.mergedIds);
          wave.completer.complete(<String, JournalDbEntity>{
            for (final entity in entities) entity.id: entity,
          });
        } catch (error, stack) {
          wave.completer.completeError(error, stack);
        }
      });
    }
    return wave.completer.future.then((map) => map[id]);
  }

  /// Bulk-fetches the [JournalEntity] for each id in [ids], returning a
  /// map keyed by entry id. Bypasses the privacy filter (sync needs every
  /// entry, including private ones) and skips deleted rows. Used by the
  /// outbox bundler to avoid an N+1 fan-out when a single bundle covers
  /// up to `SyncTuning.outboxBundleMaxSize` children, and by the inbound
  /// bundle unpacker for the same reason.
  ///
  /// Chunks the id list into [_sqliteInListChunk]-sized batches so a
  /// caller passing a long list (well above what an outbox bundle ever
  /// produces) cannot blow past SQLite's bind-variable cap. Same pattern
  /// the other bulk-by-id helpers in this file use (e.g.
  /// `getDayPlansForIds`).
  Future<Map<String, JournalEntity>> journalEntityMapForIds(
    Iterable<String> ids,
  ) async {
    final idList = ids.toSet().toList(growable: false);
    if (idList.isEmpty) {
      return const <String, JournalEntity>{};
    }
    final result = <String, JournalEntity>{};
    for (var i = 0; i < idList.length; i += _sqliteInListChunk) {
      final end = (i + _sqliteInListChunk).clamp(0, idList.length);
      final chunk = idList.sublist(i, end);
      final dbEntities = await journalEntitiesByIdsUnorderedAllPrivate(
        chunk,
      ).get();
      for (final dbEntity in dbEntities) {
        result[dbEntity.id] = fromDbEntity(dbEntity);
      }
    }
    return result;
  }

  Future<List<JournalEntity>> getJournalEntities({
    required List<String> types,
    required List<bool> starredStatuses,
    required List<bool> privateStatuses,
    required List<int> flaggedStatuses,
    required List<String>? ids,
    Set<String>? categoryIds,
    int limit = 500,
    int offset = 0,
  }) async {
    final res = await _selectJournalEntities(
      types: types,
      starredStatuses: starredStatuses,
      privateStatuses: privateStatuses,
      flaggedStatuses: flaggedStatuses,
      categoryIds: categoryIds?.toList(),
      ids: ids,
      limit: limit,
      offset: offset,
    ).get();
    return res.map(fromDbEntity).toList();
  }

  Future<List<JournalEntity>> getJournalEntitiesForIds(
    Set<String> ids,
  ) async {
    if (ids.isEmpty) {
      return const <JournalEntity>[];
    }
    final idList = ids.toList(growable: false);
    final dbEntities =
        await _queryWithPrivateFilter(
            allPrivate: () =>
                journalEntitiesByIdsUnorderedAllPrivate(idList).get(),
            filtered: (s) => journalEntitiesByIdsUnordered(idList, s).get(),
          )
          ..sort((a, b) {
            final dateCompare = b.dateFrom.compareTo(a.dateFrom);
            if (dateCompare != 0) return dateCompare;
            return a.id.compareTo(b.id);
          });
    return dbEntities.map(fromDbEntity).toList();
  }

  Future<List<JournalEntity>> getJournalEntitiesForIdsUnordered(
    Set<String> ids,
  ) async {
    if (ids.isEmpty) {
      return const <JournalEntity>[];
    }
    final idList = ids.toList(growable: false);
    final dbEntities = await _queryWithPrivateFilter(
      allPrivate: () => journalEntitiesByIdsUnorderedAllPrivate(idList).get(),
      filtered: (s) => journalEntitiesByIdsUnordered(idList, s).get(),
    );
    return dbEntities.map(fromDbEntity).toList();
  }

  /// Lean metadata-only fetch: returns the denormalized `category` column for
  /// each id, without loading or deserializing the fat `serialized` JSON
  /// payload. Intended for callers that only need the category-id lookup
  /// (e.g. time-history header aggregation) — any caller that also needs
  /// `meta.categoryId` as the source of truth can use this without losing
  /// information because `conversions.toDbEntity` keeps the column in lock-
  /// step with the JSON on every upsert.
  ///
  /// Entries filtered out by the private-status gate are simply absent from
  /// the returned map. An empty category value in the `journal.category`
  /// column is returned as `null` so callers can treat "no category" and
  /// "not present" uniformly.
  Future<Map<String, String?>> getCategoryIdsForEntryIds(
    Iterable<String> ids,
  ) async {
    final idList = ids.toSet().toList(growable: false);
    if (idList.isEmpty) return const <String, String?>{};
    final pairs = await _queryWithPrivateFilter<List<MapEntry<String, String>>>(
      allPrivate: () async {
        final rows = await journalCategoriesByIds(idList).get();
        return [for (final row in rows) MapEntry(row.id, row.category)];
      },
      filtered: (s) async {
        final rows = await journalCategoriesByIdsByPrivateStatuses(
          idList,
          s,
        ).get();
        return [for (final row in rows) MapEntry(row.id, row.category)];
      },
    );
    return {
      for (final pair in pairs)
        pair.key: pair.value.isEmpty ? null : pair.value,
    };
  }

  Future<List<String>> getJournalEntityIdsSortedByDateFromDesc(
    Iterable<String> ids,
  ) {
    final idList = ids.toSet().toList(growable: false);
    if (idList.isEmpty) {
      return Future.value(const <String>[]);
    }
    return _queryWithPrivateFilter(
      allPrivate: () => journalEntityIdsByDateFromDescAllPrivate(idList).get(),
      filtered: (s) => journalEntityIdsByDateFromDesc(idList, s).get(),
    );
  }

  /// Stream entries with their vector clocks for populating the sequence log.
  /// Yields batches of records with entry ID and vector clock map.
  /// Uses lightweight JSON extraction to avoid full deserialization.
  Stream<List<({String id, Map<String, int>? vectorClock})>>
  streamEntriesWithVectorClock({int batchSize = 1000}) async* {
    var offset = 0;

    while (true) {
      // Deterministic paging order: without ORDER BY, SQLite gives no
      // stability guarantee across LIMIT/OFFSET batches, which could skip
      // or duplicate rows while populating the sequence log.
      final batch =
          await (select(journal)
                ..orderBy([(t) => OrderingTerm.asc(t.id)])
                ..limit(batchSize, offset: offset))
              .map(
                (row) => (
                  id: row.id,
                  vectorClock: _extractVectorClock(row.serialized),
                ),
              )
              .get();

      if (batch.isEmpty) break;

      yield batch;
      offset += batchSize;
    }
  }

  /// Stream entry links with their vector clocks for populating the sequence log.
  /// Yields batches of records with link ID and vector clock map.
  /// Uses lightweight JSON extraction to avoid full deserialization.
  Stream<List<({String id, Map<String, int>? vectorClock})>>
  streamEntryLinksWithVectorClock({int batchSize = 1000}) async* {
    var offset = 0;

    while (true) {
      // Same deterministic paging order as the journal-entry stream above.
      final batch =
          await (select(linkedEntries)
                ..orderBy([(t) => OrderingTerm.asc(t.id)])
                ..limit(batchSize, offset: offset))
              .map(
                (row) => (
                  id: row.id,
                  vectorClock: _extractEntryLinkVectorClock(row.serialized),
                ),
              )
              .get();

      if (batch.isEmpty) break;

      yield batch;
      offset += batchSize;
    }
  }

  /// Count total entries for progress reporting (includes deleted).
  Future<int> countAllJournalEntries() async {
    final count = journal.id.count();
    final query = selectOnly(journal)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Count total entry links for progress reporting.
  Future<int> countAllEntryLinks() async {
    final count = linkedEntries.id.count();
    final query = selectOnly(linkedEntries)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  Selectable<JournalDbEntity> _selectJournalEntities({
    required List<String> types,
    required List<bool> starredStatuses,
    required List<bool> privateStatuses,
    required List<int> flaggedStatuses,
    required List<String>? ids,
    required List<String>? categoryIds,
    int limit = 500,
    int offset = 0,
  }) {
    final matchesAllStarredStates =
        starredStatuses.length == 2 &&
        starredStatuses.contains(true) &&
        starredStatuses.contains(false);
    final matchesAllFlagStates =
        flaggedStatuses.length == 2 &&
        flaggedStatuses.contains(0) &&
        flaggedStatuses.contains(1);
    final matchesAllPrivateStates = _matchesAllPrivateStates(privateStatuses);

    if (ids != null) {
      return filteredJournalByIds(
        types,
        ids,
        starredStatuses,
        privateStatuses,
        flaggedStatuses,
        limit,
        offset,
      );
    } else if (categoryIds != null) {
      if (matchesAllStarredStates && matchesAllFlagStates) {
        return matchesAllPrivateStates
            ? filteredJournalByCategoriesFastAllPrivate(
                types,
                categoryIds,
                limit,
                offset,
              )
            : filteredJournalByCategoriesFast(
                types,
                privateStatuses,
                categoryIds,
                limit,
                offset,
              );
      }

      return filteredJournalByCategories(
        types,
        starredStatuses,
        privateStatuses,
        flaggedStatuses,
        categoryIds,
        limit,
        offset,
      );
    } else if (matchesAllStarredStates && matchesAllFlagStates) {
      return matchesAllPrivateStates
          ? filteredJournalFastAllPrivate(
              types,
              limit,
              offset,
            )
          : filteredJournalFast(
              types,
              privateStatuses,
              limit,
              offset,
            );
    } else {
      return filteredJournal(
        types,
        starredStatuses,
        privateStatuses,
        flaggedStatuses,
        limit,
        offset,
      );
    }
  }

  // Microtask-coalescing state for `sortedCalendarEntries`.
  //
  // The DailyOS prefetch window spins up one controller per visible date
  // and each controller fires `sortedCalendarEntries(day, day+1)`
  // independently. With ~22 days in flight (slow_queries log
  // 2026-05-02, 00:04:26) the per-day fan-out shows up as 22 nearly
  // identical date-range queries hitting the same second, each
  // ~750 ms under contention. The coalescer merges concurrent callers
  // into one DB round-trip across the union range; each caller filters
  // the in-memory result down to its own [rangeStart, rangeEnd) window.
  _PendingCalendarEntriesWave? _pendingCalendarEntriesWave;

  /// Single-shot query executed by the calendar-entries coalescer.
  /// Extracted as a protected seam so tests can count round-trips and
  /// inject failures without depending on a query interceptor.
  @protected
  @visibleForTesting
  Future<List<JournalEntity>> runCalendarEntriesFetch({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final dbEntities = await sortedCalenderEntriesInRange(
      rangeStart,
      rangeEnd,
    ).get();
    return dbEntities.map(fromDbEntity).toList(growable: false);
  }

  Future<List<JournalEntity>> sortedCalendarEntries({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final superset = await _coalesceCalendarEntries(rangeStart, rangeEnd);
    return [
      for (final entity in superset)
        if (!entity.meta.dateFrom.isBefore(rangeStart) &&
            !entity.meta.dateTo.isAfter(rangeEnd))
          entity,
    ];
  }

  Future<List<JournalEntity>> _coalesceCalendarEntries(
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final existing = _pendingCalendarEntriesWave;
    if (existing != null) {
      // Widen the union so the superset still covers every joining
      // caller. Per-caller filtering happens client-side, so a wider
      // window costs only one extra DB streaming pass.
      if (rangeStart.isBefore(existing.rangeStart)) {
        existing.rangeStart = rangeStart;
      }
      if (rangeEnd.isAfter(existing.rangeEnd)) {
        existing.rangeEnd = rangeEnd;
      }
      return existing.completer.future;
    }

    final wave = _PendingCalendarEntriesWave(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
    _pendingCalendarEntriesWave = wave;
    scheduleMicrotask(() async {
      _pendingCalendarEntriesWave = null;
      try {
        final entities = await runCalendarEntriesFetch(
          rangeStart: wave.rangeStart,
          rangeEnd: wave.rangeEnd,
        );
        wave.completer.complete(entities);
      } catch (error, stack) {
        wave.completer.completeError(error, stack);
      }
    });
    return wave.completer.future;
  }

  Future<int> getJournalCount() async {
    return (await countJournalEntries().get()).first;
  }

  Future<int> getCountImportFlagEntries() async {
    final res = await countImportFlagEntries().get();
    return res.first;
  }
}

/// Lightweight extraction of vector clock from serialized JSON.
/// Avoids full deserialization of the entity.
Map<String, int>? _extractVectorClock(String serialized) {
  try {
    final json = jsonDecode(serialized) as Map<String, dynamic>;
    final meta = json['meta'] as Map<String, dynamic>?;
    if (meta == null) return null;

    final vc = meta['vectorClock'] as Map<String, dynamic>?;
    if (vc == null) return null;

    return vc.map((k, v) => MapEntry(k, (v as num).toInt()));
  } catch (_) {
    return null;
  }
}

/// Lightweight extraction of vector clock from serialized EntryLink JSON.
Map<String, int>? _extractEntryLinkVectorClock(String serialized) {
  try {
    final json = jsonDecode(serialized) as Map<String, dynamic>;
    final vc = json['vectorClock'] as Map<String, dynamic>?;
    if (vc == null) return null;

    // Validate all values are numeric before converting
    for (final v in vc.values) {
      if (v is! num) return null;
    }
    return vc.map((k, v) => MapEntry(k, (v as num).toInt()));
  } catch (_) {
    // Invalid JSON, or a valid document whose top level / vectorClock is
    // not an object — either way the row carries no usable clock. A bad
    // row must yield null instead of aborting the enclosing stream.
    return null;
  }
}

/// Test-only seam for the pure JSON parser behind
/// [_JournalDbJournalQueries.streamEntriesWithVectorClock].
@visibleForTesting
Map<String, int>? extractVectorClockForTesting(String serialized) =>
    _extractVectorClock(serialized);

/// Test-only seam for the pure JSON parser behind
/// [_JournalDbJournalQueries.streamEntryLinksWithVectorClock].
@visibleForTesting
Map<String, int>? extractEntryLinkVectorClockForTesting(String serialized) =>
    _extractEntryLinkVectorClock(serialized);

/// In-flight coalescing wave for `journalEntityById`. Concurrent callers
/// within the same microtask merge their ids; the wave fires one bulk
/// `id IN (…)` query and each caller pulls its own row out of the
/// returned map.
class _PendingEntityByIdWave {
  final Set<String> mergedIds = <String>{};
  bool scheduled = false;
  final Completer<Map<String, JournalDbEntity>> completer =
      Completer<Map<String, JournalDbEntity>>.sync();
}

/// In-flight coalescing wave for `sortedCalendarEntries`. Every caller in
/// the same microtask wave joins one fetch covering the union of all
/// requested ranges; each caller then filters the result down to its own
/// `[rangeStart, rangeEnd]` window client-side.
class _PendingCalendarEntriesWave {
  _PendingCalendarEntriesWave({
    required this.rangeStart,
    required this.rangeEnd,
  });

  DateTime rangeStart;
  DateTime rangeEnd;
  final Completer<List<JournalEntity>> completer =
      Completer<List<JournalEntity>>.sync();
}
