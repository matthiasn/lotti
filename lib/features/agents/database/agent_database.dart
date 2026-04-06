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
  int get schemaVersion => 6;

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
          // keeping only the most recently created row per from_id.
          await customStatement('''
            UPDATE agent_links
            SET
              deleted_at = CURRENT_TIMESTAMP,
              updated_at = CURRENT_TIMESTAMP
            WHERE type = 'soul_assignment'
              AND deleted_at IS NULL
              AND rowid NOT IN (
                SELECT MAX(rowid)
                FROM agent_links
                WHERE type = 'soul_assignment' AND deleted_at IS NULL
                GROUP BY from_id
              )
          ''');
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS '
            'idx_unique_soul_per_template '
            "ON agent_links(from_id) WHERE type = 'soul_assignment' "
            'AND deleted_at IS NULL',
          );
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
