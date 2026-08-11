import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/consumption_summary_pill.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';

/// Compact AI-consumption pill for the task header's attribute lane.
///
/// Shows the task's lifetime AI cost at a glance — `€0.42 · 12 Wh · 3.4 g`
/// when environmental impact was measured (Melious calls), or the total token
/// count when only tokens are known (other providers). Renders nothing at all
/// for tasks without recorded AI calls, so non-AI tasks carry zero extra
/// chrome.
///
/// The tooltip carries the full detail: call/measured counts, token split,
/// energy/CO₂e/water, and cost. Data comes from
/// [taskConsumptionTotalsProvider], which refreshes on
/// `aiConsumptionNotification` (local writes and inbound sync alike).
class TaskConsumptionChip extends ConsumerWidget {
  const TaskConsumptionChip({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(taskConsumptionTotalsProvider(taskId)).value;
    // No data yet (loading) and no recorded calls look identical on purpose:
    // the chip only ever appears once real consumption exists, so it never
    // flashes in and out during the initial fetch.
    if (totals == null || totals.callCount == 0) {
      return const SizedBox.shrink();
    }

    return ConsumptionSummaryPill(
      totals: totals,
      foregroundColor: TaskShowcasePalette.mediumText(context),
    );
  }
}
