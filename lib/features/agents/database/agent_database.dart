import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:lotti/database/common.dart';

part 'agent_database.g.dart';

const agentDbFileName = 'agent.sqlite';

@DriftDatabase(include: {'agent_database.drift'})
class AgentDatabase extends _$AgentDatabase {
  AgentDatabase({
    this.inMemoryDatabase = false,
    bool background = true,
    int readPool = 2,
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? tempDirectoryProvider,
  }) : super(
         openDbConnection(
           agentDbFileName,
           inMemoryDatabase: inMemoryDatabase,
           background: background,
           readPool: readPool,
           documentsDirectoryProvider: documentsDirectoryProvider,
           tempDirectoryProvider: tempDirectoryProvider,
         ),
       );

  final bool inMemoryDatabase;

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) => m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await customStatement(
            'ALTER TABLE wake_run_log ADD COLUMN user_rating REAL',
          );
          await customStatement(
            'ALTER TABLE wake_run_log ADD COLUMN rated_at DATETIME',
          );
        }
        if (from < 3) {
          // Soft-delete duplicate improver_target rows before creating
          // the unique index, keeping only the earliest row per to_id.
          await customStatement('''
            UPDATE agent_links
            SET
              deleted_at = CURRENT_TIMESTAMP,
              updated_at = CURRENT_TIMESTAMP
            WHERE type = 'improver_target'
              AND deleted_at IS NULL
              AND rowid NOT IN (
                SELECT MIN(rowid)
                FROM agent_links
                WHERE type = 'improver_target' AND deleted_at IS NULL
                GROUP BY to_id
              )
          ''');
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS '
            'idx_unique_improver_per_template '
            "ON agent_links(to_id) WHERE type = 'improver_target' "
            'AND deleted_at IS NULL',
          );
        }
        if (from < 4) {
          await customStatement(
            'ALTER TABLE wake_run_log ADD COLUMN resolved_model_id TEXT',
          );
        }
        if (from < 5) {
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_agent_links_active_from_type_to '
            'ON agent_links(from_id, type, to_id) '
            'WHERE deleted_at IS NULL',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_wake_run_log_agent_thread '
            'ON wake_run_log(agent_id, thread_id, created_at DESC)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_saga_log_status_created_at '
            'ON saga_log(status, created_at ASC)',
          );
        }
        if (from < 6) {
          await customStatement(
            'ALTER TABLE wake_run_log ADD COLUMN soul_id TEXT',
          );
          await customStatement(
            'ALTER TABLE wake_run_log ADD COLUMN soul_version_id TEXT',
          );
          // Soft-delete duplicate soul_assignment links per template,
          // keeping the most recently created link per from_id. Uses
          // created_at (then id as tiebreaker) rather than rowid for
          // deterministic results across SQLite configurations.
          await customStatement('''
            UPDATE agent_links
            SET
              deleted_at = CURRENT_TIMESTAMP,
              updated_at = CURRENT_TIMESTAMP
            WHERE type = 'soul_assignment'
              AND deleted_at IS NULL
              AND id NOT IN (
                SELECT id FROM (
                  SELECT id, ROW_NUMBER() OVER (
                    PARTITION BY from_id
                    ORDER BY created_at DESC, id DESC
                  ) AS rn
                  FROM agent_links
                  WHERE type = 'soul_assignment' AND deleted_at IS NULL
                ) ranked WHERE rn = 1
              )
          ''');
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS '
            'idx_unique_soul_per_template '
            "ON agent_links(from_id) WHERE type = 'soul_assignment' "
            'AND deleted_at IS NULL',
          );
        }
        if (from < 7) {
          // Expression partial for `getDueScheduledAgentStates` —
          // the JSON predicate previously degraded into a heap
          // probe per matching `idx_agent_entities_type` row.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_agent_entities_due_wake '
            r"ON agent_entities(json_extract(serialized, '$.scheduledWakeAt') ASC) "
            "WHERE type = 'agentState' "
            'AND deleted_at IS NULL '
            r"AND json_extract(serialized, '$.scheduledWakeAt') IS NOT NULL",
          );
        }
        if (from < 8) {
          // `getWakeRunsInWindow` filters on `created_at` and orders
          // by `created_at DESC`; the pre-v8 indices were all
          // leaded by `agent_id`, `template_id`, or `status` so the
          // planner fell back to `SCAN wake_run_log` + `USE TEMP
          // B-TREE FOR ORDER BY` (2026-05-10 desktop super_slow
          // log: 11 hits/day at 305–408 ms). A bare-`created_at`
          // index turns the window query into an in-order index
          // walk and lets the LIMIT stop without a sort step.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_wake_run_log_created_at '
            'ON wake_run_log(created_at DESC)',
          );
          await customStatement('ANALYZE');
        }
        if (from < 9) {
          // Partial active-row indexes for the agent.sqlite desktop slow
          // paths captured on 2026-05-15..21. The older broad indexes can
          // seek by type/agent but cannot avoid every temp sort or deleted-row
          // probe in list and batch-hydration queries.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_agent_entities_active_agent_type_created '
            'ON agent_entities(agent_id, type, created_at DESC) '
            'WHERE deleted_at IS NULL',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_agent_entities_active_type_created '
            'ON agent_entities(type, created_at DESC) '
            'WHERE deleted_at IS NULL',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_agent_links_active_to_type '
            'ON agent_links(to_id, type) '
            'WHERE deleted_at IS NULL',
          );
          await customStatement('ANALYZE');
        }
        if (from < 10) {
          // The v9 active agent/type index still left the windowed
          // `_latestEntitiesByAgentIds` batch path with `USE TEMP B-TREE FOR
          // LAST TERM OF ORDER BY` because the query ranks rows by
          // `(created_at DESC, id DESC)`. These replacement indexes include
          // the tie-breaker used by both report-head variants captured in the
          // 2026-05-22..24 desktop slow-query logs.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_agent_entities_active_agent_type_created_id '
            'ON agent_entities(agent_id, type, created_at DESC, id DESC) '
            'WHERE deleted_at IS NULL',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS '
            'idx_agent_entities_active_agent_type_sub_created_id '
            'ON agent_entities '
            '(agent_id, type, subtype, created_at DESC, id DESC) '
            'WHERE deleted_at IS NULL',
          );
          await customStatement(
            'DROP INDEX IF EXISTS idx_agent_entities_active_agent_type_created',
          );
          await customStatement('ANALYZE');
        }
        if (from < 11) {
          // Drop the table-level UNIQUE(from_id, to_id, type): it is correct
          // for assignment-style links and DAG edges but WRONG for
          // `message_payload` capture events (ADR 0020) — content addressing
          // dedupes identical content into one shared payload, so two sources
          // rendering the same bytes each need their own link to the SAME
          // digest (first hit in production: two empty text entries on one
          // task → SqliteException 2067 → every capture failing). SQLite
          // cannot drop a table constraint in place, so rebuild the table and
          // recreate every index, replacing the constraint with a partial
          // unique index that exempts `message_payload`.
          await customStatement('''
            CREATE TABLE agent_links_v11 (
              id TEXT NOT NULL PRIMARY KEY,
              from_id TEXT NOT NULL,
              to_id TEXT NOT NULL,
              type TEXT NOT NULL,
              created_at DATETIME NOT NULL,
              updated_at DATETIME NOT NULL,
              deleted_at DATETIME,
              serialized TEXT NOT NULL,
              schema_version INTEGER NOT NULL DEFAULT 1
            )
          ''');
          await customStatement(
            'INSERT INTO agent_links_v11 '
            'SELECT id, from_id, to_id, type, created_at, updated_at, '
            'deleted_at, serialized, schema_version FROM agent_links',
          );
          await customStatement('DROP TABLE agent_links');
          await customStatement(
            'ALTER TABLE agent_links_v11 RENAME TO agent_links',
          );
          // Recreate every agent_links index (dropped with the old table) —
          // keep in sync with agent_database.drift.
          await customStatement(
            'CREATE INDEX idx_agent_links_from ON agent_links(from_id, type)',
          );
          await customStatement(
            'CREATE INDEX idx_agent_links_to ON agent_links(to_id, type)',
          );
          await customStatement(
            'CREATE INDEX idx_agent_links_type ON agent_links(type)',
          );
          await customStatement(
            'CREATE UNIQUE INDEX idx_unique_improver_per_template '
            "ON agent_links(to_id) WHERE type = 'improver_target' "
            'AND deleted_at IS NULL',
          );
          await customStatement(
            'CREATE UNIQUE INDEX idx_unique_soul_per_template '
            "ON agent_links(from_id) WHERE type = 'soul_assignment' "
            'AND deleted_at IS NULL',
          );
          await customStatement(
            'CREATE INDEX idx_agent_links_active_from_type_to '
            'ON agent_links(from_id, type, to_id) WHERE deleted_at IS NULL',
          );
          await customStatement(
            'CREATE INDEX idx_agent_links_active_to_type '
            'ON agent_links(to_id, type) WHERE deleted_at IS NULL',
          );
          await customStatement(
            'CREATE UNIQUE INDEX idx_agent_links_unique_from_to_type '
            'ON agent_links(from_id, to_id, type) '
            "WHERE type != 'message_payload'",
          );
          await customStatement('ANALYZE');
        }
      },
    );
  }

  /// Stream agent entities with their vector clocks for populating the
  /// sequence log. Yields batches of records with entity ID and vector
  /// clock map. Uses lightweight SQL + JSON extraction to avoid full
  /// deserialization.
  Stream<List<({String id, Map<String, int>? vectorClock})>>
  streamAgentEntitiesWithVectorClock({int batchSize = 1000}) async* {
    var offset = 0;

    while (true) {
      final rows = await customSelect(
        'SELECT id, serialized FROM agent_entities '
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

  /// Stream agent links with their vector clocks for populating the
  /// sequence log. Yields batches of records with link ID and vector
  /// clock map.
  Stream<List<({String id, Map<String, int>? vectorClock})>>
  streamAgentLinksWithVectorClock({int batchSize = 1000}) async* {
    var offset = 0;

    while (true) {
      final rows = await customSelect(
        'SELECT id, serialized FROM agent_links '
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

  /// Count total agent entities for progress reporting.
  Future<int> countAllAgentEntities() => _countAll('agent_entities');

  /// Count total agent links for progress reporting.
  Future<int> countAllAgentLinks() => _countAll('agent_links');

  Future<int> _countAll(String tableName) async {
    final result = await customSelect(
      'SELECT COUNT(*) AS cnt FROM $tableName',
    ).getSingle();
    return result.read<int>('cnt');
  }

  /// Lightweight extraction of vector clock from serialized JSON.
  /// Agent entities and links store vectorClock at JSON root level.
  /// Returns null for any malformed data rather than throwing.
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
