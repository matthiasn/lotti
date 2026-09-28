import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// One record as an inventory lists it: its id and its vector clock. A null
/// clock is a row written before clocks existed.
typedef DeepBackfillRow = ({String id, VectorClock? clock});

/// The records of one payload type, as deep backfill reads and resends them.
///
/// Every read is a single primary-key query — a page in id order, or every
/// row of an id range — so diffing a batch of any size costs one query per
/// table, never one per record.
abstract class DeepBackfillStore {
  const DeepBackfillStore();

  /// The payload type these records travel as.
  SyncSequencePayloadType get payloadType;

  /// How many rows a round will advertise, tombstones included.
  Future<int> count();

  /// Up to [limit] rows whose id sorts after [after] (from the first when
  /// null), in id order, tombstones included.
  Future<List<DeepBackfillRow>> page({
    required String? after,
    required int limit,
  });

  /// Every row whose id lies in `[start, end)`; a null bound is unbounded.
  Future<Map<String, VectorClock?>> range({
    required String? start,
    required String? end,
  });

  /// The clocks of the open conflict versions of records in `[start, end)`.
  /// Only journal entries have conflicts; other records merge.
  Future<Map<String, List<VectorClock>>> openConflicts({
    required String? start,
    required String? end,
  }) async => const {};

  /// The size in bytes of this device's file for each live record in
  /// `[start, end)` that carries media — 0 when the file is missing. A
  /// deletion makes no claim on its file, and is left out. Only journal
  /// entries (images and audio) carry media.
  Future<Map<String, int>> mediaSizes({
    required String? start,
    required String? end,
  }) async => const {};

  /// Enqueues the current version of each record in [ids] — a deletion as
  /// much as a live row — through the ordinary sync message for its type.
  /// Records in [withMedia] carry their media: the peer holds nothing of
  /// them yet, or a smaller copy of the file. Returns how many were enqueued; an id with no row is skipped.
  Future<int> enqueueCurrent(Set<String> ids, {required Set<String> withMedia});
}

/// The SQL every store shares: a table with a TEXT primary key `id` and a
/// clock at [clockSql]. [table] and [clockSql] are constants of the store,
/// never input.
class DeepBackfillTableQueries {
  const DeepBackfillTableQueries({
    required this.db,
    required this.table,
    required this.clockSql,
  });

  final GeneratedDatabase db;
  final String table;
  final String clockSql;

  /// Chunk size for `IN (...)` lists, well under SQLite's variable limit.
  static const int inListChunk = 500;

  Future<int> count() async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS n FROM $table')
        .getSingle();
    return row.read<int>('n');
  }

  Future<List<DeepBackfillRow>> page({
    required String? after,
    required int limit,
  }) async {
    final rows = await db
        .customSelect(
          'SELECT id, $clockSql AS vc FROM $table '
          '${after == null ? '' : 'WHERE id > ? '}'
          'ORDER BY id LIMIT ?',
          variables: [
            if (after != null) Variable.withString(after),
            Variable.withInt(limit),
          ],
        )
        .get();
    return [
      for (final row in rows)
        (
          id: row.read<String>('id'),
          clock: parseClock(row.readNullable<String>('vc')),
        ),
    ];
  }

  Future<Map<String, VectorClock?>> range({
    required String? start,
    required String? end,
  }) async {
    final (where, variables) = rangeClause(start: start, end: end);
    final rows = await db
        .customSelect(
          'SELECT id, $clockSql AS vc FROM $table $where',
          variables: variables,
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('id'): parseClock(row.readNullable<String>('vc')),
    };
  }

  /// The `serialized` column of each of [ids] that has a row, in chunks.
  Future<Map<String, String>> serializedByIds(Iterable<String> ids) async {
    final list = ids.toList(growable: false);
    final result = <String, String>{};
    for (var i = 0; i < list.length; i += inListChunk) {
      final chunk = list.sublist(
        i,
        i + inListChunk > list.length ? list.length : i + inListChunk,
      );
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await db
          .customSelect(
            'SELECT id, serialized FROM $table WHERE id IN ($placeholders)',
            variables: [for (final id in chunk) Variable.withString(id)],
          )
          .get();
      for (final row in rows) {
        result[row.read<String>('id')] = row.read<String>('serialized');
      }
    }
    return result;
  }

  /// `WHERE` for `start <= id < end`, only naming the bounds that are set so
  /// SQLite can use the primary-key index for the range.
  static (String, List<Variable<Object>>) rangeClause({
    required String? start,
    required String? end,
  }) {
    final conditions = <String>[
      if (start != null) 'id >= ?',
      if (end != null) 'id < ?',
    ];
    return (
      conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}',
      [
        if (start != null) Variable.withString(start),
        if (end != null) Variable.withString(end),
      ],
    );
  }

  /// A clock as the database stores it: a JSON object of host to counter.
  /// Null, empty or malformed reads as no clock.
  static VectorClock? parseClock(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return null;
      return VectorClock.fromJson(decoded);
    } on Object {
      return null;
    }
  }
}
