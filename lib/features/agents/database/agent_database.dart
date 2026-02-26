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
  int get schemaVersion => 2;

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
      },
    );
  }
}
