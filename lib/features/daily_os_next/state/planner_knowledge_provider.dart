import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/daily_os_next/agents/domain/planner_knowledge.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart'
    show dailyOsPlannerAgentId;
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';

/// The data the "What I've learned" panel renders: the active confirmed Head
/// set and the proposals still awaiting the user's confirmation (ADR 0022
/// Decision 10).
class PlannerKnowledgeView {
  const PlannerKnowledgeView({required this.confirmed, required this.proposed});

  const PlannerKnowledgeView.empty()
    : confirmed = const [],
      proposed = const [];

  /// The active Head set — most recent confirmed per key.
  final List<PlannerKnowledgeEntity> confirmed;

  /// Proposals awaiting confirmation, newest first.
  final List<PlannerKnowledgeEntity> proposed;

  bool get isEmpty => confirmed.isEmpty && proposed.isEmpty;
}

/// Surfaces the planner's durable knowledge for the "What I've learned" panel.
///
/// Refreshes on planner state notifications (the knowledge service emits the
/// planner agent id on every write).
// ignore: specify_nonobvious_property_types
final plannerKnowledgeProvider =
    FutureProvider.autoDispose<PlannerKnowledgeView>(
      (ref) async {
        ref.watch(agentUpdateStreamProvider(dailyOsPlannerAgentId));
        final service = ref.watch(dayAgentKnowledgeServiceProvider);
        final all = await service.allFor(dailyOsPlannerAgentId);

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

        return PlannerKnowledgeView(confirmed: confirmed, proposed: proposed);
      },
    );
