import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/agents/agent_database.dart';
import 'package:lotti/database/agents/agent_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';

/// The agent database instance (singleton via GetIt).
final agentDatabaseProvider = Provider<AgentDatabase>(
  agentDatabase,
  name: 'agentDatabaseProvider',
);
AgentDatabase agentDatabase(Ref ref) {
  return getIt<AgentDatabase>();
}

/// The agent repository wrapping the database.
final agentRepositoryProvider = Provider<AgentRepository>(
  agentRepository,
  name: 'agentRepositoryProvider',
);
AgentRepository agentRepository(Ref ref) {
  return AgentRepository(
    ref.watch(agentDatabaseProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  );
}
