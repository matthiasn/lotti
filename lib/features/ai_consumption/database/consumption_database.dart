import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:lotti/database/common.dart';

part 'consumption_database.g.dart';

const consumptionDbFileName = 'ai_consumption.sqlite';

/// Dedicated, append-only store for AI consumption events — one immutable row
/// per backend call (see `AiConsumptionEvent`).
///
/// Kept separate from the journal (`db.sqlite`) and agent (`agent.sqlite`)
/// databases so high-volume diagnostics writes never contend with primary data,
/// and so it can carry its own migration lifecycle. Rows are Matrix-synced like
/// the agent domain's append-only entities.
@DriftDatabase(include: {'consumption_database.drift'})
class ConsumptionDatabase extends _$ConsumptionDatabase {
  ConsumptionDatabase({
    this.inMemoryDatabase = false,
    bool background = true,
    // Consumption reads are aggregation scans, not latency-critical UI reads,
    // so a single read isolate is plenty.
    int readPool = 1,
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? tempDirectoryProvider,
  }) : super(
         openDbConnection(
           consumptionDbFileName,
           inMemoryDatabase: inMemoryDatabase,
           background: background,
           readPool: readPool,
           documentsDirectoryProvider: documentsDirectoryProvider,
           tempDirectoryProvider: tempDirectoryProvider,
         ),
       );

  final bool inMemoryDatabase;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (m) => m.createAll());

  /// Stream consumption events with their vector clocks for populating the sync
  /// sequence log. Yields batches of `(id, vectorClock)` records using
  /// lightweight SQL + JSON extraction to avoid full deserialization. Mirrors
  /// `AgentDatabase.streamAgentEntitiesWithVectorClock`.
  Stream<List<({String id, Map<String, int>? vectorClock})>>
  streamConsumptionEventsWithVectorClock({int batchSize = 1000}) async* {
    var offset = 0;
    while (true) {
      final rows = await customSelect(
        'SELECT id, serialized FROM consumption_events '
        'ORDER BY id LIMIT ? OFFSET ?',
        variables: [Variable(batchSize), Variable(offset)],
      ).get();

      if (rows.isEmpty) break;

      yield rows
          .map(
            (row) => (
              id: row.read<String>('id'),
              vectorClock: _extractVectorClock(row.read<String>('serialized')),
            ),
          )
          .toList();
      offset += batchSize;
    }
  }

  /// Count total consumption events for sync progress reporting.
  Future<int> countAllConsumptionEvents() async {
    final result = await customSelect(
      'SELECT COUNT(*) AS cnt FROM consumption_events',
    ).getSingle();
    return result.read<int>('cnt');
  }

  /// Lightweight extraction of the vector clock from serialized JSON. Returns
  /// null for any malformed data rather than throwing.
  static Map<String, int>? _extractVectorClock(String serialized) {
    try {
      final decoded = jsonDecode(serialized);
      if (decoded is! Map<String, dynamic>) return null;

      final vc = decoded['vectorClock'];
      if (vc is! Map<String, dynamic>) return null;

      final result = <String, int>{};
      for (final entry in vc.entries) {
        if (entry.value is! num) return null;
        result[entry.key] = (entry.value as num).toInt();
      }
      return result;
    } on Object catch (_) {
      return null;
    }
  }
}
