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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(consumptionEvents, consumptionEvents.attributionId);
        await m.addColumn(consumptionEvents, consumptionEvents.sequenceIndex);
        await m.addColumn(consumptionEvents, consumptionEvents.interactionKind);
        await m.addColumn(
          consumptionEvents,
          consumptionEvents.interactionStatus,
        );
        await m.addColumn(consumptionEvents, consumptionEvents.completedAt);
        await m.addColumn(
          consumptionEvents,
          consumptionEvents.providerRequestId,
        );
        await m.addColumn(consumptionEvents, consumptionEvents.errorCode);
        await m.addColumn(consumptionEvents, consumptionEvents.errorSummary);
        await m.addColumn(consumptionEvents, consumptionEvents.payloadId);
        await m.addColumn(consumptionEvents, consumptionEvents.costId);

        await m.createTable(aiWorkAttributions);
        await m.createTable(aiAttributionLinks);
        await m.createTable(aiInteractionPayloads);
        await m.createTable(aiInteractionCosts);
        await m.createTable(pendingAiAttributions);

        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_consumption_attribution_sequence '
          'ON consumption_events(attribution_id, sequence_index) '
          'WHERE attribution_id IS NOT NULL',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_attribution_output '
          'ON ai_work_attributions(primary_output_type, primary_output_id, '
          'primary_output_sub_id)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_attribution_task_created '
          'ON ai_work_attributions(task_id, completed_at) '
          'WHERE task_id IS NOT NULL',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_attribution_actor_created '
          'ON ai_work_attributions(initiator_id, completed_at)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_attribution_type_created '
          'ON ai_work_attributions(work_type, completed_at)',
        );
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_attribution_link_unique '
          'ON ai_attribution_links(attribution_id, role, artifact_type, '
          "artifact_id, IFNULL(sub_id, ''))",
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_attribution_link_target '
          'ON ai_attribution_links(artifact_type, artifact_id, sub_id)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_cost_interaction_assessed '
          'ON ai_interaction_costs(interaction_id, assessed_at)',
        );
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_cost_external_record '
          'ON ai_interaction_costs(provider_type, billing_account_key, '
          'billing_source, external_record_id) '
          'WHERE external_record_id IS NOT NULL',
        );
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Stream consumption events with their vector clocks for populating the sync
  /// sequence log. Yields batches of `(id, vectorClock)` records using
  /// lightweight SQL + JSON extraction to avoid full deserialization. Mirrors
  /// `AgentDatabase.streamAgentEntitiesWithVectorClock`, but uses keyset
  /// pagination (`id > last`) instead of OFFSET so the scan stays linear as
  /// this high-volume table grows.
  Stream<List<({String id, Map<String, int>? vectorClock})>>
  streamConsumptionEventsWithVectorClock({int batchSize = 1000}) async* {
    String? lastId;
    while (true) {
      final rows = await customSelect(
        'SELECT id, serialized FROM consumption_events '
        '${lastId != null ? 'WHERE id > ? ' : ''}'
        'ORDER BY id LIMIT ?',
        variables: [
          if (lastId != null) Variable(lastId),
          Variable(batchSize),
        ],
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
      lastId = rows.last.read<String>('id');
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
