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
}
