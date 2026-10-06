import 'dart:convert';

import 'package:async/async.dart' show StreamGroup;
import 'package:drift/drift.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/deep_backfill/deep_backfill_store.dart';
import 'package:lotti/services/outbox_service.dart';

/// Entity definitions — categories, labels, habits, dashboards, measurables
/// and speech dictionary entries — as one store over their six tables, since
/// they travel as one payload type. Ids are unique across the tables, so the
/// store reads as a single table ordered by id. A deletion is a row with
/// `deletedAt` set; definitions merge rather than conflict.
class DefinitionDeepBackfillStore extends DeepBackfillStore {
  DefinitionDeepBackfillStore({
    required JournalDb journalDb,
    required this._outboxService,
  }) : _tables = [
         for (final table in <TableInfo<Table, Object?>>[
           journalDb.categoryDefinitions,
           journalDb.labelDefinitions,
           journalDb.habitDefinitions,
           journalDb.dashboardDefinitions,
           journalDb.measurableTypes,
           journalDb.speechDictionaryEntries,
         ])
           DeepBackfillTableQueries(
             db: journalDb,
             table: table.actualTableName,
             clockSql: r"json_extract(serialized, '$.vectorClock')",
           ),
       ];

  final OutboxService _outboxService;
  final List<DeepBackfillTableQueries> _tables;

  @override
  SyncSequencePayloadType get payloadType =>
      SyncSequencePayloadType.entityDefinition;

  @override
  Future<int> count() async {
    var total = 0;
    for (final table in _tables) {
      total += await table.count();
    }
    return total;
  }

  @override
  Stream<void> get changes =>
      StreamGroup.merge([for (final table in _tables) table.changes]);

  /// Each table's first [limit] rows after [after], merged in id order: the
  /// first [limit] of the union are among them.
  @override
  Future<List<DeepBackfillRow>> page({
    required String? after,
    required int limit,
  }) async {
    final rows = <DeepBackfillRow>[
      for (final table in _tables)
        ...await table.page(after: after, limit: limit),
    ]..sort((a, b) => a.id.compareTo(b.id));
    return rows.take(limit).toList();
  }

  @override
  Future<Map<String, VectorClock?>> range({
    required String? start,
    required String? end,
  }) async => {
    for (final table in _tables) ...await table.range(start: start, end: end),
  };

  @override
  Future<int> enqueueCurrent(
    Set<String> ids, {
    required Set<String> withMedia,
  }) async {
    if (ids.isEmpty) return 0;
    var sent = 0;
    for (final table in _tables) {
      final rows = await table.serializedByIds(ids);
      for (final serialized in rows.values) {
        await _outboxService.enqueueMessage(
          SyncMessage.entityDefinition(
            entityDefinition: EntityDefinition.fromJson(
              jsonDecode(serialized) as Map<String, dynamic>,
            ),
            status: SyncEntryStatus.update,
          ),
        );
        sent++;
      }
    }
    return sent;
  }
}
