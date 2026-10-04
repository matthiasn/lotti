import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:lotti/classes/agents/agent_link.dart' as model;
import 'package:lotti/classes/ai_consumption/ai_consumption_event.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/database/agents/agent_database.dart';
import 'package:lotti/database/agents/agent_db_conversions.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/features/ai_consumption/database/consumption_database.dart';
import 'package:lotti/features/sync/deep_backfill/deep_backfill_store.dart';
import 'package:lotti/features/sync/media/entry_media.dart';
import 'package:lotti/services/outbox_service.dart';
import 'package:lotti/utils/file_utils.dart';

/// Resends one record's current version, decoded from its `serialized`
/// column.
typedef DeepBackfillResend = Future<void> Function(String serialized);

/// A store over one table with a TEXT primary key `id`, a clock at a fixed
/// SQL expression, and the record's JSON in `serialized`. The records merge
/// rather than conflict, and carry no media, so only the payload is resent.
class TableDeepBackfillStore extends DeepBackfillStore {
  const TableDeepBackfillStore({
    required this.payloadType,
    required this.queries,
    required this.resend,
  });

  @override
  final SyncSequencePayloadType payloadType;
  final DeepBackfillTableQueries queries;
  final DeepBackfillResend resend;

  @override
  Future<int> count() => queries.count();

  @override
  Stream<void> get changes => queries.changes;

  @override
  Future<List<DeepBackfillRow>> page({
    required String? after,
    required int limit,
  }) => queries.page(after: after, limit: limit);

  @override
  Future<Map<String, VectorClock?>> range({
    required String? start,
    required String? end,
  }) => queries.range(start: start, end: end);

  @override
  Future<int> enqueueCurrent(
    Set<String> ids, {
    required Set<String> withMedia,
  }) async {
    if (ids.isEmpty) return 0;
    final rows = await queries.serializedByIds(ids);
    for (final serialized in rows.values) {
      await resend(serialized);
    }
    return rows.length;
  }
}

/// Journal entries. A deletion is a row with `deleted` set under the
/// deletion's clock; an open conflict is a row of `conflicts`, one per entry
/// and version (ADR 0092), and travels like the row.
class JournalDeepBackfillStore extends DeepBackfillStore {
  JournalDeepBackfillStore({
    required JournalDb journalDb,
    required OutboxService outboxService,
    required Directory documentsDirectory,
  }) : _db = journalDb,
       _outbox = outboxService,
       _docs = documentsDirectory,
       _queries = DeepBackfillTableQueries(
         db: journalDb,
         table: 'journal',
         clockSql: _clockSql,
       );

  static const String _clockSql =
      r"json_extract(serialized, '$.meta.vectorClock')";

  final JournalDb _db;
  final OutboxService _outbox;
  final Directory _docs;
  final DeepBackfillTableQueries _queries;

  @override
  SyncSequencePayloadType get payloadType =>
      SyncSequencePayloadType.journalEntity;

  @override
  Future<int> count() => _queries.count();

  @override
  Stream<void> get changes => _queries.changes;

  @override
  Future<List<DeepBackfillRow>> page({
    required String? after,
    required int limit,
  }) => _queries.page(after: after, limit: limit);

  @override
  Future<Map<String, VectorClock?>> range({
    required String? start,
    required String? end,
  }) => _queries.range(start: start, end: end);

  @override
  Future<Map<String, List<VectorClock>>> openConflicts({
    required String? start,
    required String? end,
  }) {
    final (where, variables) = DeepBackfillTableQueries.rangeClause(
      start: start,
      end: end,
    );
    return _conflictClocks(
      '${where.isEmpty ? 'WHERE' : '$where AND'} status = ?',
      [...variables, Variable.withInt(ConflictStatus.unresolved.index)],
    );
  }

  /// Reads the file size of every live image and audio entry in the range,
  /// resolved as the payload sender resolves it: the size advertised is the
  /// size of the file an answer would carry.
  @override
  Future<Map<String, int>> mediaSizes({
    required String? start,
    required String? end,
  }) async {
    final (where, variables) = DeepBackfillTableQueries.rangeClause(
      start: start,
      end: end,
    );
    final rows = await _db
        .customSelect(
          'SELECT id, serialized FROM journal '
          '${where.isEmpty ? 'WHERE' : '$where AND'} deleted = 0 '
          'AND type IN (?, ?)',
          variables: [
            ...variables,
            Variable.withString('JournalImage'),
            Variable.withString('JournalAudio'),
          ],
        )
        .get();
    final sizes = <String, int>{};
    for (final row in rows) {
      final media = entryMedia(
        fromSerialized(row.read<String>('serialized')),
        documentsDirectory: _docs,
      );
      if (media == null) continue;
      sizes[row.read<String>('id')] = await mediaFileLength(media.file);
    }
    return sizes;
  }

  /// The open conflict clocks of [ids], in chunks.
  Future<Map<String, List<VectorClock>>> _openConflictsOf(
    List<String> ids,
  ) async {
    final result = <String, List<VectorClock>>{};
    for (var i = 0; i < ids.length; i += DeepBackfillTableQueries.inListChunk) {
      final chunk = ids.sublist(
        i,
        i + DeepBackfillTableQueries.inListChunk > ids.length
            ? ids.length
            : i + DeepBackfillTableQueries.inListChunk,
      );
      result.addAll(
        await _conflictClocks(
          'WHERE id IN (${List.filled(chunk.length, '?').join(', ')}) '
          'AND status = ?',
          [
            for (final id in chunk) Variable.withString(id),
            Variable.withInt(ConflictStatus.unresolved.index),
          ],
        ),
      );
    }
    return result;
  }

  Future<Map<String, List<VectorClock>>> _conflictClocks(
    String where,
    List<Variable<Object>> variables,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT id, $_clockSql AS vc FROM conflicts $where',
          variables: variables,
        )
        .get();
    final result = <String, List<VectorClock>>{};
    for (final row in rows) {
      final clock = DeepBackfillTableQueries.parseClock(
        row.readNullable<String>('vc'),
      );
      if (clock == null) continue;
      (result[row.read<String>('id')] ??= []).add(clock);
    }
    return result;
  }

  /// Resends each entry's row, loaded through the journal's own decoding
  /// (which patches denormalized columns into legacy JSON), and every open
  /// conflict version of it: a peer may ask for either, and a request names
  /// the record, not the version.
  @override
  Future<int> enqueueCurrent(
    Set<String> ids, {
    required Set<String> withMedia,
  }) async {
    if (ids.isEmpty) return 0;
    final entities = await _db.journalEntityMapForIdsIncludingDeleted(ids);
    final conflicts = await _openConflictsOf(entities.keys.toList());
    for (final entity in entities.values) {
      final id = entity.meta.id;
      await _enqueue(entity, entity.meta.vectorClock, withMedia.contains(id));
      for (final clock in conflicts[id] ?? const <VectorClock>[]) {
        await _enqueue(entity, clock, withMedia.contains(id));
      }
    }
    return entities.length;
  }

  /// The payload is read at send time: the row, or the open conflict of
  /// exactly [vectorClock] when the row does not cover it.
  Future<void> _enqueue(
    JournalEntity entity,
    VectorClock? vectorClock,
    bool withMedia,
  ) => _outbox.enqueueMessage(
    SyncMessage.journalEntity(
      id: entity.meta.id,
      jsonPath: relativeEntityPath(entity),
      vectorClock: vectorClock,
      status: SyncEntryStatus.update,
      includeAttachments: withMedia,
    ),
  );
}

/// Entry links: a removal is a row whose `deletedAt` is set (ADR 0078).
TableDeepBackfillStore entryLinkDeepBackfillStore({
  required JournalDb journalDb,
  required OutboxService outboxService,
}) => TableDeepBackfillStore(
  payloadType: SyncSequencePayloadType.entryLink,
  queries: DeepBackfillTableQueries(
    db: journalDb,
    table: 'linked_entries',
    clockSql: r"json_extract(serialized, '$.vectorClock')",
  ),
  resend: (serialized) => outboxService.enqueueMessage(
    SyncMessage.entryLink(
      entryLink: EntryLink.fromJson(
        jsonDecode(serialized) as Map<String, dynamic>,
      ),
      status: SyncEntryStatus.update,
    ),
  ),
);

/// Agent entities: a removal keeps its row with `deleted_at` (ADR 0081).
TableDeepBackfillStore agentEntityDeepBackfillStore({
  required AgentDatabase agentDatabase,
  required OutboxService outboxService,
}) => TableDeepBackfillStore(
  payloadType: SyncSequencePayloadType.agentEntity,
  queries: DeepBackfillTableQueries(
    db: agentDatabase,
    table: 'agent_entities',
    clockSql: r"json_extract(serialized, '$.vectorClock')",
  ),
  resend: (serialized) => outboxService.enqueueMessage(
    SyncMessage.agentEntity(
      status: SyncEntryStatus.update,
      agentEntity: AgentDbConversions.fromSerialized(serialized),
    ),
  ),
);

/// Agent links: a removal keeps its row with `deleted_at` (ADR 0081).
TableDeepBackfillStore agentLinkDeepBackfillStore({
  required AgentDatabase agentDatabase,
  required OutboxService outboxService,
}) => TableDeepBackfillStore(
  payloadType: SyncSequencePayloadType.agentLink,
  queries: DeepBackfillTableQueries(
    db: agentDatabase,
    table: 'agent_links',
    clockSql: r"json_extract(serialized, '$.vectorClock')",
  ),
  resend: (serialized) => outboxService.enqueueMessage(
    SyncMessage.agentLink(
      status: SyncEntryStatus.update,
      agentLink: model.AgentLink.fromJson(
        jsonDecode(serialized) as Map<String, dynamic>,
      ),
    ),
  ),
);

/// Notifications: the clock is a column of its own, and the whole record —
/// content and lifecycle — travels as one notification payload.
TableDeepBackfillStore notificationDeepBackfillStore({
  required NotificationsDb notificationsDb,
  required OutboxService outboxService,
}) => TableDeepBackfillStore(
  payloadType: SyncSequencePayloadType.notification,
  queries: DeepBackfillTableQueries(
    db: notificationsDb,
    table: 'notifications',
    clockSql: 'vector_clock',
  ),
  resend: (serialized) => outboxService.enqueueNotification(
    NotificationEntity.fromJson(
      jsonDecode(serialized) as Map<String, dynamic>,
    ),
  ),
);

/// AI consumption events: append-only, so there are no removals to carry.
TableDeepBackfillStore consumptionDeepBackfillStore({
  required ConsumptionDatabase consumptionDatabase,
  required OutboxService outboxService,
}) => TableDeepBackfillStore(
  payloadType: SyncSequencePayloadType.consumptionEvent,
  queries: DeepBackfillTableQueries(
    db: consumptionDatabase,
    table: 'consumption_events',
    clockSql: r"json_extract(serialized, '$.vectorClock')",
  ),
  resend: (serialized) => outboxService.enqueueMessage(
    SyncMessage.consumptionEvent(
      status: SyncEntryStatus.update,
      event: AiConsumptionEvent.fromJson(
        jsonDecode(serialized) as Map<String, dynamic>,
      ),
    ),
  ),
);

/// The store of every synced type, the scope of a deep backfill: journal
/// entries, entry links, agent entities and links, notifications and AI
/// consumption events. One list, so the round and the record counts cannot
/// leave a type out — each store reads its own database, and none depends on
/// another feature's runtime having started.
List<DeepBackfillStore> allDeepBackfillStores({
  required JournalDb journalDb,
  required AgentDatabase agentDatabase,
  required NotificationsDb notificationsDb,
  required ConsumptionDatabase consumptionDatabase,
  required OutboxService outboxService,
  required Directory documentsDirectory,
}) => [
  JournalDeepBackfillStore(
    journalDb: journalDb,
    outboxService: outboxService,
    documentsDirectory: documentsDirectory,
  ),
  entryLinkDeepBackfillStore(
    journalDb: journalDb,
    outboxService: outboxService,
  ),
  agentEntityDeepBackfillStore(
    agentDatabase: agentDatabase,
    outboxService: outboxService,
  ),
  agentLinkDeepBackfillStore(
    agentDatabase: agentDatabase,
    outboxService: outboxService,
  ),
  notificationDeepBackfillStore(
    notificationsDb: notificationsDb,
    outboxService: outboxService,
  ),
  consumptionDeepBackfillStore(
    consumptionDatabase: consumptionDatabase,
    outboxService: outboxService,
  ),
];
