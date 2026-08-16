import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_phase_a.dart';
import 'package:lotti/features/relationships/runtime/relationship_runtime_maintenance.dart';
import 'package:lotti/features/relationships/service/relationship_agent_service.dart';

/// The deterministic tier of the relationship agent (ADR 0059 Decision 2).
final relationshipAgentPhaseAProvider = Provider<RelationshipAgentPhaseA>(
  (ref) => RelationshipAgentPhaseA(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    relationshipRepository: ref.watch(relationshipRepositoryProvider),
    // A locally armed escalation is processed promptly instead of waiting
    // out the hourly poll (the goal Phase A pattern).
    onEscalationArmed: () =>
        ref.read(scheduledWakeManagerProvider).requestCheck(),
  ),
  name: 'relationshipAgentPhaseAProvider',
);

/// Lazy creation, subscriptions, and the deletion cascade's agent leg.
final relationshipAgentServiceProvider = Provider<RelationshipAgentService>(
  (ref) => RelationshipAgentService(
    agentService: ref.watch(agentServiceProvider),
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
  ),
  name: 'relationshipAgentServiceProvider',
);

/// The relationships contribution to `agentWakeRunnersProvider` — merged
/// in `app_bootstrap.dart`, NEVER left to the silent task-agent fallback
/// in `agent_wiring.dart` (the documented ADR 0054 trap; pinned by
/// regression test).
final relationshipAgentWakeRunnersProvider =
    Provider<Map<String, AgentWakeRunner>>(
      (ref) => <String, AgentWakeRunner>{
        AgentKinds.relationshipAgent:
            ({
              required agentIdentity,
              required runKey,
              required triggerTokens,
              required threadId,
            }) {
              // Every wake takes the deterministic tier for now. Escalation
              // and report-refresh tokens will route to the LLM tier when
              // it ships (plan v2 phase 5); until then a fired escalation
              // re-derives its facts here and consumes itself at €0.
              return ref
                  .read(relationshipAgentPhaseAProvider)
                  .execute(
                    agentIdentity: agentIdentity,
                    runKey: runKey,
                    triggerTokens: triggerTokens,
                    threadId: threadId,
                  );
            },
      },
      name: 'relationshipAgentWakeRunnersProvider',
    );

/// The relationships contribution to `agentRuntimeMaintenanceProvider`.
final relationshipRuntimeMaintenanceProvider =
    Provider<RelationshipRuntimeMaintenance>(
      (ref) => RelationshipRuntimeMaintenance(
        agentService: ref.watch(agentServiceProvider),
        repository: ref.watch(agentRepositoryProvider),
        syncService: ref.watch(agentSyncServiceProvider),
        relationshipAgentService: ref.watch(relationshipAgentServiceProvider),
        domainLogger: ref.watch(domainLoggerProvider),
      ),
      name: 'relationshipRuntimeMaintenanceProvider',
    );
