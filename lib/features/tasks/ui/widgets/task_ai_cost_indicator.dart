import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/agent_maintenance_section.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/ai_cost_indicator.dart';
import 'package:lotti/features/tasks/ui/header/task_meta_flyout.dart';
import 'package:material_ui/material_ui.dart';

/// The task-bound [AiCostIndicator]: watches one task's lifetime consumption
/// and renders the leaf-and-amount read-out on the task's own surfaces — its
/// header lane and its metadata section.
///
/// Nothing renders until the task has recorded AI calls, so a task that has
/// never been near the machine carries no chrome for it. The totals provider
/// is throttled and auto-disposing, so the watch ends with the surface.
///
/// A tap opens the task agent's internals — the per-model token breakdown
/// with input, output and cached tokens and the cache-hit rate — because that
/// is what a reader tapping a cost wants to see, and no task surface shows it.
/// The task details stay one tap away on their own affordance (the header's
/// Details button), not on this read-out.
///
/// A task without an agent has no internals. There the default constructor
/// falls back to the task details, where the AI spend is shown in full, and
/// [TaskAiCostIndicator.inDetails] — for surfaces that already *are* those
/// details — is a plain read-out with no tap.
class TaskAiCostIndicator extends ConsumerWidget {
  const TaskAiCostIndicator({
    required this.taskId,
    this.density = AiCostDensity.compact,
    this.foregroundColor,
    this.onTap,
    super.key,
  }) : _hostedInDetails = false;

  const TaskAiCostIndicator.inDetails({
    required this.taskId,
    this.density = AiCostDensity.compact,
    this.foregroundColor,
    super.key,
  }) : onTap = null,
       _hostedInDetails = true;

  final String taskId;
  final AiCostDensity density;
  final Color? foregroundColor;

  /// Overrides the default drill-down (agent internals, else task details).
  final VoidCallback? onTap;

  /// Whether the indicator sits inside the task details, which it must then
  /// not open again when the task has no agent.
  final bool _hostedInDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value`: a background refetch (a sync notification, another AI call
    // landing) must not blink an established read-out out of the row.
    final totals = ref.watch(taskConsumptionTotalsProvider(taskId)).value;
    if (totals == null || totals.callCount == 0) return const SizedBox.shrink();

    final agent = ref
        .watch(taskAgentProvider(taskId))
        .value
        ?.mapOrNull(agent: (e) => e);

    return AiCostIndicator(
      totals: totals,
      density: density,
      foregroundColor: foregroundColor,
      onTap:
          onTap ??
          (agent != null
              ? () => AgentInternalsPanel.show(
                  context: context,
                  agentId: agent.agentId,
                  agentName: agent.displayName,
                  maintenance: AgentMaintenanceScope(
                    kind: AgentMaintenanceKind.task,
                    entityId: taskId,
                  ),
                )
              : _hostedInDetails
              ? null
              : () => TaskMetaFlyout.show(context, taskId: taskId)),
    );
  }
}
