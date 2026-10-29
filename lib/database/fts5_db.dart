import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts_query.dart';
import 'package:lotti/database/search_document.dart';
import 'package:lotti/database/title_search.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';

part 'fts5_db.g.dart';

const fts5DbFileName = 'fts5_db.sqlite';

/// Whether replacing [previous] with [next] changes measurement search text.
bool measurementDefinitionAffectsFts(
  MeasurableDataType? previous,
  MeasurableDataType next,
) {
  if (previous == null ||
      previous.displayName != next.displayName ||
      previous.unitName != next.unitName) {
    return true;
  }
  return _choiceTitleSignature(previous) != _choiceTitleSignature(next);
}

String _choiceTitleSignature(MeasurableDataType dataType) {
  final titles = [
    for (final choice in dataType.choices ?? const <MeasurableChoice>[])
      '${choice.id}\u0000${choice.title}',
  ]..sort();
  return titles.join('\u0001');
}

/// The search index: a derived, rebuildable copy of the journal's text.
///
/// Every write runs through one serial queue, and the writes that read the
/// journal ([indexByIds], [catchUp]) read it inside that queue, so a rebuild
/// batch read before a live edit can never be written after it.
@DriftDatabase(include: {'fts5_db.drift'})
class Fts5Db extends _$Fts5Db {
  Fts5Db({
    this.inMemoryDatabase = false,
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? tempDirectoryProvider,
    this.rebuildBatchSize = 500,
  }) : super(
         openDbConnection(
           fts5DbFileName,
           inMemoryDatabase: inMemoryDatabase,
           documentsDirectoryProvider: documentsDirectoryProvider,
           tempDirectoryProvider: tempDirectoryProvider,
         ),
       );

  final bool inMemoryDatabase;

  /// Version 2 replaced the single `journal_fts` table with `search_doc` and
  /// `search_fts`; its rows cannot be converted, so the upgrade starts a
  /// rebuild ([catchUp]). Version 3 added `title_trigram`, which the same
  /// rebuild fills.
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _startRebuild();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await customStatement('DROP TABLE IF EXISTS journal_fts');
        await m.createAll();
        await _startRebuild();
      } else if (from < 3) {
        await m.create(titleTrigram);
        await _startRebuild();
      }
    },
  );

  /// Rows read from the journal per rebuild batch, each written in one
  /// transaction; also the ids [indexByIds] writes per transaction.
  final int rebuildBatchSize;

  /// Matches returned when a caller does not ask for fewer.
  static const defaultMatchLimit = 500;

  static const _rebuildCursorKey = 'rebuild_after_rowid';

  Future<void> _queue = Future<void>.value();

  Future<T> _serially<T>(Future<T> Function() write) {
    final result = _queue.then((_) => write());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _startRebuild() => setIndexStateValue(_rebuildCursorKey, 0);

  /// Whether the index is still catching up with the journal after it was
  /// created, upgraded or reset — [catchUp] finishes it.
  Future<bool> needsCatchUp() async =>
      await indexStateValue(_rebuildCursorKey).getSingleOrNull() != null;

  /// Indexes every live journal row the index has not caught up with, a
  /// batch at a time, and records each batch's last rowid with it, so a
  /// rebuild cut short by the app closing resumes where it stopped.
  ///
  /// Returns the number of entities indexed; [onProgress] gets that count
  /// after every batch. [shouldContinue] returning false stops it between
  /// batches, for a caller being disposed.
  Future<int> catchUp(
    JournalDb journalDb, {
    void Function(int indexed)? onProgress,
    bool Function()? shouldContinue,
  }) async {
    var indexed = 0;
    while (shouldContinue?.call() ?? true) {
      final done = await _serially(() async {
        final after = await indexStateValue(
          _rebuildCursorKey,
        ).getSingleOrNull();
        if (after == null) return true;
        final batch = await journalDb.liveEntitiesAfterRowId(
          after,
          rebuildBatchSize,
        );
        await transaction(() async {
          await _write(batch.entities);
          if (batch.entities.length < rebuildBatchSize) {
            await clearIndexStateValue(_rebuildCursorKey);
          } else {
            await setIndexStateValue(_rebuildCursorKey, batch.lastRowId);
          }
        });
        indexed += batch.entities.length;
        return batch.entities.length < rebuildBatchSize;
      });
      onProgress?.call(indexed);
      if (done) break;
    }
    return indexed;
  }

  /// Brings the entities among [ids] up to date with the journal: indexes
  /// the live ones, and drops the deleted ones and ids with no row. Ids that
  /// name no entity — notification tokens — cost a lookup and nothing else.
  Future<void> indexByIds(JournalDb journalDb, Set<String> ids) async {
    if (ids.isEmpty) return;
    final idList = ids.toList(growable: false);
    for (var start = 0; start < idList.length; start += rebuildBatchSize) {
      final chunk = idList
          .sublist(start, (start + rebuildBatchSize).clamp(0, idList.length))
          .toSet();
      await _serially(() async {
        final entities = await journalDb
            .getJournalEntitiesForIdsIncludingDeleted(chunk);
        final found = {for (final entity in entities) entity.meta.id};
        await transaction(() async {
          await _write(entities);
          for (final id in chunk.difference(found)) {
            await _remove(id);
          }
        });
      });
    }
  }

  /// Indexes [entities] as they are, without reading the journal — for a
  /// caller writing to a journal this index is not the live one for (a
  /// world being seeded, a demo copy).
  Future<void> indexEntities(Iterable<JournalEntity> entities) =>
      _serially(() => transaction(() => _write(entities)));

  /// Rebuilds the derived text of every measurement of [dataType].
  ///
  /// Choice titles, measurable names, and numeric units live on the
  /// definition rather than the journal entry. When one changes, historical
  /// entries need to be indexed again so search reflects what the journal
  /// currently displays. Passing [dataType] directly avoids racing the
  /// asynchronously refreshed definition cache.
  Future<void> reindexMeasurements(
    MeasurableDataType dataType,
    Iterable<JournalEntity> entries,
  ) => _serially(
    () => transaction(
      () => _write(
        [
          for (final entry in entries)
            if (entry is MeasurementEntry &&
                entry.data.dataTypeId == dataType.id)
              entry,
        ],
        measurableDataType: (id) => id == dataType.id ? dataType : null,
      ),
    ),
  );

  Future<void> _write(
    Iterable<JournalEntity> entities, {
    MeasurableDataType? Function(String dataTypeId)? measurableDataType,
  }) async {
    for (final entity in entities) {
      final document = entity.meta.deletedAt != null
          ? null
          : searchDocumentFor(
              entity,
              measurableDataType: measurableDataType ?? _cachedDataType,
            );
      if (document == null || document.isEmpty) {
        await _remove(entity.meta.id);
        continue;
      }
      final rowId = await into(searchDoc).insertReturning(
        SearchDocCompanion.insert(
          entityId: entity.meta.id,
          type: entityTypeName(entity),
          categoryId: Value(entity.meta.categoryId ?? ''),
          private: Value(entity.meta.private ?? false),
          dateFrom: entity.meta.dateFrom.millisecondsSinceEpoch,
        ),
        onConflict: DoUpdate.withExcluded(
          (old, excluded) => SearchDocCompanion.custom(
            type: excluded.type,
            categoryId: excluded.categoryId,
            private: excluded.private,
            dateFrom: excluded.dateFrom,
          ),
          target: [searchDoc.entityId],
        ),
      );
      await deleteSearchText(rowId.id);
      await insertSearchText(
        rowId.id,
        document.title,
        document.body,
        document.extra,
      );
      await deleteTitleTrigram(rowId.id);
      if (document.title.trim().isNotEmpty) {
        await insertTitleTrigram(rowId.id, document.title);
      }
    }
  }

  Future<void> _remove(String entityId) async {
    final doc = await searchDocByEntityId(entityId).getSingleOrNull();
    if (doc == null) return;
    await deleteSearchText(doc.id);
    await deleteTitleTrigram(doc.id);
    await deleteSearchDoc(doc.id);
  }

  // Resolved lazily so indexing a non-active world (WorldHandle) never
  // touches the active generation's cache unless it holds measurements.
  static MeasurableDataType? _cachedDataType(String dataTypeId) =>
      getIt<EntitiesCacheService>().getDataTypeById(dataTypeId);

  /// The ids of the entities matching what a user typed in [query], best
  /// match first: by BM25 with a title match worth ten times one in the
  /// text and an `extra` match twice, newer first among equals.
  ///
  /// The filters apply before [limit], so the limit keeps the best matches
  /// the caller can show: [types] and [categoryIds] (the empty id for
  /// uncategorised) restrict when given, and [includePrivate] false leaves
  /// private entities out. With [anyTerm], one matching word is enough;
  /// [prefixLastWord] false matches the last word whole too, for a caller
  /// passing finished words rather than what is being typed.
  /// Input with nothing to match returns no ids; it never throws
  /// ([ftsMatchExpression]).
  Future<List<String>> matchIds(
    String query, {
    bool anyTerm = false,
    bool prefixLastWord = true,
    Set<String>? types,
    Set<String>? categoryIds,
    bool includePrivate = true,
    int limit = defaultMatchLimit,
  }) async {
    final expression = ftsMatchExpression(
      query,
      anyTerm: anyTerm,
      prefixLastWord: prefixLastWord,
    );
    if (expression == null) return const [];
    final filter = _DocFilter(
      types,
      categoryIds,
      includePrivate: includePrivate,
    );
    final rows = await customSelect(
      'SELECT d.entity_id AS entity_id FROM search_fts '
      'INNER JOIN search_doc AS d ON d.id = search_fts.rowid '
      'WHERE search_fts MATCH ?${filter.sql} '
      'ORDER BY bm25(search_fts, 10.0, 1.0, 2.0), d.date_from DESC '
      'LIMIT ?',
      variables: [
        Variable.withString(expression),
        ...filter.variables,
        Variable.withInt(limit),
      ],
      readsFrom: {searchFts, searchDoc},
    ).get();
    return [for (final row in rows) row.read<String>('entity_id')];
  }

  /// The entities whose title matches [query], for jumping to one by name:
  /// the title that is the query first, then titles starting with it, then
  /// titles with a word starting with it, then any title holding every word
  /// — a word of three letters or more anywhere, in the middle of a word too
  /// (`title_trigram`), a shorter one as the start of a word.
  ///
  /// When no title holds every word, the titles sharing most of the
  /// query's letter triples come back instead, marked [TitleMatch.fuzzy],
  /// so a misspelt name still finds its task. [types], [categoryIds] and
  /// [includePrivate] filter as in [matchIds].
  Future<List<TitleMatch>> searchTitles(
    String query, {
    Set<String>? types,
    Set<String>? categoryIds,
    bool includePrivate = true,
    int limit = 20,
  }) async {
    final words = searchWords(query);
    if (words.isEmpty) return const [];
    final filter = _DocFilter(
      types,
      categoryIds,
      includePrivate: includePrivate,
    );
    final long = [
      for (final word in words)
        if (word.length >= minTrigramWordLength) word,
    ];
    // Without a word the trigram index can match, the main index's prefix
    // match over the title column finds the candidates.
    final candidates = long.isEmpty
        ? await _titleCandidates(
            'search_fts',
            '{title} : (${words.map((word) => '"$word"*').join(' ')})',
            filter,
          )
        : await _titleCandidates(
            'title_trigram',
            long.map((word) => '"$word"').join(' '),
            filter,
          );
    final ranked = rankTitleMatches(query, candidates);
    if (ranked.isNotEmpty) return ranked.take(limit).toList();

    final trigrams = titleTrigrams(query);
    if (trigrams.length < 2) return const [];
    final near = await _titleCandidates(
      'title_trigram',
      trigrams.map((trigram) => '"$trigram"').join(' OR '),
      filter,
    );
    return nearestTitles(query, near).take(limit).toList();
  }

  /// Candidates ranked before the limit applies. The index's BM25 order is
  /// not the quick-open order — it favours a word repeated over the title
  /// that is the query, and it cannot check a short word's place — so the
  /// whole pool is ranked ([rankTitleMatches], [nearestTitles]) and only then
  /// cut. Titles are short; a pool this size costs a millisecond or two.
  static const titleCandidatePool = 500;

  Future<List<TitleMatch>> _titleCandidates(
    String table,
    String expression,
    _DocFilter filter,
  ) async {
    final rows = await customSelect(
      'SELECT d.entity_id AS entity_id, d.type AS type, $table.title AS title '
      'FROM $table INNER JOIN search_doc AS d ON d.id = $table.rowid '
      'WHERE $table MATCH ?${filter.sql} '
      'ORDER BY rank, d.date_from DESC LIMIT ?',
      variables: [
        Variable.withString(expression),
        ...filter.variables,
        Variable.withInt(titleCandidatePool),
      ],
      readsFrom: {searchFts, titleTrigram, searchDoc},
    ).get();
    return [
      for (final row in rows)
        TitleMatch(
          entityId: row.read<String>('entity_id'),
          type: row.read<String>('type'),
          title: row.read<String>('title'),
        ),
    ];
  }
}

/// The `search_doc` clauses every search applies before its limit, as SQL
/// appended to a `WHERE` and the values it binds, in order.
class _DocFilter {
  _DocFilter(
    Set<String>? types,
    Set<String>? categoryIds, {
    required bool includePrivate,
  }) {
    _inSet('type', types);
    _inSet('category_id', categoryIds);
    if (!includePrivate) _sql.write(' AND d.private = 0');
  }

  final _sql = StringBuffer();
  final variables = <Variable<Object>>[];

  String get sql => _sql.toString();

  void _inSet(String column, Set<String>? values) {
    if (values == null) return;
    if (values.isEmpty) {
      _sql.write(' AND 0');
      return;
    }
    _sql.write(
      ' AND d.$column IN (${List.filled(values.length, '?').join(', ')})',
    );
    variables.addAll(values.map(Variable.withString));
  }
}
