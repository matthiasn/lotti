import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/service/event_agent_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';

/// The event-agent-specific service.
final eventAgentServiceProvider = Provider<EventAgentService>(
  eventAgentService,
  name: 'eventAgentServiceProvider',
);
EventAgentService eventAgentService(Ref ref) {
  final notifications = ref.watch(updateNotificationsProvider);
  return EventAgentService(
    agentService: ref.watch(agentServiceProvider),
    repository: ref.watch(agentRepositoryProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    domainLogger: ref.watch(domainLoggerProvider),
    onPersistedStateChanged: persistedStateChangedNotifier(notifications),
  );
}

/// Fetch the Event Agent for a given journal-domain eventId.
///
/// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.
/// Watches the update stream so the UI rebuilds when an agent-event link
/// arrives via sync.
final FutureProviderFamily<AgentDomainEntity?, String> eventAgentProvider =
    FutureProvider.autoDispose.family<AgentDomainEntity?, String>(
      eventAgent,
      name: 'eventAgentProvider',
    );
Future<AgentDomainEntity?> eventAgent(
  Ref ref,
  String eventId,
) async {
  ref.watch(agentUpdateStreamProvider(eventId));
  final service = ref.watch(eventAgentServiceProvider);
  return service.getEventAgentForEvent(eventId);
}
