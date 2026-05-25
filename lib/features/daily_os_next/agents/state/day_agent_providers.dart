import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'day_agent_providers.g.dart';

/// The Daily OS day-agent service.
@Riverpod(keepAlive: true)
DayAgentService dayAgentService(Ref ref) {
  final notifications = ref.watch(updateNotificationsProvider);
  return DayAgentService(
    agentService: ref.watch(agentServiceProvider),
    repository: ref.watch(agentRepositoryProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    templateService: ref.watch(agentTemplateServiceProvider),
    domainLogger: ref.watch(domainLoggerProvider),
    onPersistedStateChanged: persistedStateChangedNotifier(notifications),
  );
}

/// Fetch the active Daily OS day agent for [date], if one exists.
@riverpod
Future<AgentDomainEntity?> dayAgent(
  Ref ref,
  DateTime date,
) async {
  final dayId = dayAgentIdForDate(date);
  ref.watch(agentUpdateStreamProvider(dayId));
  final service = ref.watch(dayAgentServiceProvider);
  return service.getDayAgentForDate(date);
}
