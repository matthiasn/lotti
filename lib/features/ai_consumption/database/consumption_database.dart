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
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(consumptionEvents, consumptionEvents.attributionId);
        await m.createTable(aiWorkAttributions);

        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_consumption_attribution '
          'ON consumption_events(attribution_id, created_at) '
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
      }
      if (from < 3) {
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_consumption_agent_created '
          'ON consumption_events(agent_id, created_at) '
          'WHERE agent_id IS NOT NULL',
        );
      }
      if (from < 4) {
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_attribution_output_latest '
          'ON ai_work_attributions(primary_output_type, primary_output_id, '
          'completed_at DESC, id DESC)',
        );
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
