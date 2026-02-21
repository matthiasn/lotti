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
  int get schemaVersion => 1;
}
