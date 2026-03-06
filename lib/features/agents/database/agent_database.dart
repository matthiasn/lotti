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
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? tempDirectoryProvider,
  }) : super(
          openDbConnection(
            agentDbFileName,
            inMemoryDatabase: inMemoryDatabase,
            background: background,
            documentsDirectoryProvider: documentsDirectoryProvider,
            tempDirectoryProvider: tempDirectoryProvider,
          ),
        );

  final bool inMemoryDatabase;

  @override
  int get schemaVersion => 3;

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
        'LIMIT ? OFFSET ?',
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
        'LIMIT ? OFFSET ?',
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
  Future<int> countAllAgentEntities() async {
    final count = agentEntities.id.count();
    final query = selectOnly(agentEntities)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Count total agent links for progress reporting.
  Future<int> countAllAgentLinks() async {
    final count = agentLinks.id.count();
    final query = selectOnly(agentLinks)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Lightweight extraction of vector clock from serialized JSON.
  /// Agent entities and links store vectorClock at JSON root level.
  static Map<String, int>? _extractVectorClock(String serialized) {
    try {
      final json = jsonDecode(serialized) as Map<String, dynamic>;
      final vc = json['vectorClock'] as Map<String, dynamic>?;
      if (vc == null) return null;

      for (final v in vc.values) {
        if (v is! num) return null;
      }
      return vc.map((k, v) => MapEntry(k, (v as num).toInt()));
    } on FormatException catch (_) {
      return null;
    }
  }
}
