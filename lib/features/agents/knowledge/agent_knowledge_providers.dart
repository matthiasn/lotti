import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/agents/knowledge/agent_knowledge.dart';
import 'package:lotti/features/agents/knowledge/agent_knowledge_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';

/// The shared durable-knowledge service (ADR 0022, ADR 0057 decision 1) —
/// what the "What I've learned" panel confirms, edits and retracts through,
/// for any agent that keeps knowledge.
final agentKnowledgeServiceProvider = Provider<AgentKnowledgeService>(
  (ref) => AgentKnowledgeService(
    agentRepository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    domainLogger: ref.watch(domainLoggerProvider),
    onPersistedStateChanged: persistedStateChangedNotifier(
      ref.watch(updateNotificationsProvider),
    ),
  ),
  name: 'agentKnowledgeServiceProvider',
);

/// The data the "What I've learned" panel renders: the active confirmed Head
/// set and the proposals still awaiting the user's confirmation (ADR 0022
/// Decision 10).
class AgentKnowledgeView {
  const AgentKnowledgeView({required this.confirmed, required this.proposed});

  /// The active Head set — most recent confirmed per key.
  final List<PlannerKnowledgeEntity> confirmed;

  /// Proposals awaiting confirmation, newest first.
  final List<PlannerKnowledgeEntity> proposed;

  bool get isEmpty => confirmed.isEmpty && proposed.isEmpty;
}

/// One agent's durable knowledge, for its "What I've learned" panel.
///
/// Refreshes on that agent's state notifications: every knowledge write
/// emits the agent id it belongs to.
final FutureProviderFamily<AgentKnowledgeView, String> agentKnowledgeProvider =
    FutureProvider.autoDispose.family<AgentKnowledgeView, String>(
      (ref, agentId) async {
        ref.watch(agentUpdateStreamProvider(agentId));
        final all = await ref
            .watch(agentKnowledgeServiceProvider)
            .allFor(agentId);

        final confirmed = activePlannerKnowledge(all);
        final proposed =
            all
                .where(
                  (e) =>
                      e.deletedAt == null &&
                      e.status == KnowledgeStatus.proposed,
                )
                .toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        return AgentKnowledgeView(confirmed: confirmed, proposed: proposed);
      },
      name: 'agentKnowledgeProvider',
    );
