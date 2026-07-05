import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_consumption/logic/consumption_formatting.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

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

  /// Chip label: impact triple when measured, token count otherwise.
  String _label(BuildContext context, ConsumptionTotals totals) {
    if (totals.impactCallCount > 0) {
      final credits = formatCredits(totals.credits);
      final energy = formatEnergyKwh(totals.energyKwh);
      final carbon = formatCarbonGrams(totals.carbonGCo2);
      return '$credits · $energy · $carbon';
    }
    return context.messages.aiConsumptionTokensLabel(
      formatTokenCount(totals.totalTokens),
    );
  }

  /// Multi-line tooltip with the full breakdown.
  String _tooltip(BuildContext context, ConsumptionTotals totals) {
    final messages = context.messages;
    final lines = <String>[
      messages.aiConsumptionCallsLine(
        totals.callCount,
        totals.impactCallCount,
      ),
      messages.aiConsumptionTokensLine(
        formatTokenCount(totals.inputTokens),
        formatTokenCount(totals.outputTokens),
      ),
      if (totals.impactCallCount > 0) ...[
        messages.aiConsumptionImpactLine(
          formatEnergyKwh(totals.energyKwh),
          formatCarbonGrams(totals.carbonGCo2),
          formatWaterLiters(totals.waterLiters),
        ),
        messages.aiConsumptionCostLine(formatCredits(totals.credits)),
      ],
    ];
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(taskConsumptionTotalsProvider(taskId)).value;
    // No data yet (loading) and no recorded calls look identical on purpose:
    // the chip only ever appears once real consumption exists, so it never
    // flashes in and out during the initial fetch.
    if (totals == null || totals.callCount == 0) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: _tooltip(context, totals),
      child: DsPill(
        variant: DsPillVariant.filled,
        // Quiet border mirrors the estimate chip so the two data-bearing time
        // and cost pills read at the same visual weight.
        bordered: true,
        label: _label(context, totals),
        labelColor: TaskShowcasePalette.mediumText(context),
        leading: Icon(
          Icons.eco_outlined,
          size: 12,
          color: TaskShowcasePalette.mediumText(context),
        ),
      ),
    );
  }
}
