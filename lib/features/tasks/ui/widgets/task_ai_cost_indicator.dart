import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/ai_cost_indicator.dart';
import 'package:lotti/features/tasks/ui/header/task_meta_flyout.dart';

/// The task-bound [AiCostIndicator]: watches one task's lifetime consumption
/// and renders the leaf-and-amount read-out wherever a task is shown.
///
/// Nothing renders until the task has recorded AI calls, so a task that has
/// never been near the machine carries no chrome for it. The totals provider
/// is throttled and auto-disposing, so a row that scrolls out of the list
/// stops watching.
///
/// The default constructor is interactive: a tap opens the task's metadata
/// details, which is where the AI spend is shown in full. See
/// [AiCostIndicator] for how a cost **breakdown** later takes that tap over.
/// [TaskAiCostIndicator.readOnly] is the plain read-out, for surfaces that
/// already *are* the details a tap would open.
class TaskAiCostIndicator extends ConsumerWidget {
  const TaskAiCostIndicator({
    required this.taskId,
    this.density = AiCostDensity.compact,
    this.foregroundColor,
    this.onTap,
    super.key,
  }) : _interactive = true;

  const TaskAiCostIndicator.readOnly({
    required this.taskId,
    this.density = AiCostDensity.compact,
    this.foregroundColor,
    super.key,
  }) : onTap = null,
       _interactive = false;

  final String taskId;
  final AiCostDensity density;
  final Color? foregroundColor;

  /// Overrides the default "open the task details" tap.
  final VoidCallback? onTap;

  final bool _interactive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value`: a background refetch (a sync notification, another AI call
    // landing) must not blink an established read-out out of the row.
    final totals = ref.watch(taskConsumptionTotalsProvider(taskId)).value;
    if (totals == null || totals.callCount == 0) return const SizedBox.shrink();

    return AiCostIndicator(
      totals: totals,
      density: density,
      foregroundColor: foregroundColor,
      onTap: _interactive
          ? (onTap ?? () => TaskMetaFlyout.show(context, taskId: taskId))
          : null,
    );
  }
}
