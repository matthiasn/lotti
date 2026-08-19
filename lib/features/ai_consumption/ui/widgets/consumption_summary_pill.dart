import 'package:flutter/material.dart';
import 'package:lotti/features/ai_consumption/logic/consumption_formatting.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/insights/ui/widgets/insights_format.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The canonical lifetime consumption pill shared by task and agent surfaces.
///
/// Measured Melious calls show credits, energy, and carbon. Other providers
/// fall back to tokens, while the tooltip retains the complete available
/// breakdown including water usage.
class ConsumptionSummaryPill extends StatelessWidget {
  const ConsumptionSummaryPill({
    required this.totals,
    required this.foregroundColor,
    this.cornerRadius,
    super.key,
  });

  final ConsumptionTotals totals;
  final Color foregroundColor;

  /// Corner radius override, passed through to [DsPill]. Surfaces that
  /// reserve full rounding for clickable elements pass their small-chip
  /// radius here — this pill informs, it does not act.
  final double? cornerRadius;

  @override
  Widget build(BuildContext context) {
    if (totals.callCount == 0) return const SizedBox.shrink();

    return Tooltip(
      message: consumptionSummaryTooltip(context, totals),
      child: DsPill(
        variant: DsPillVariant.filled,
        // A read-out, not a control: the tight tag corners keep it from
        // masquerading as a button (corner-radius convention).
        shape: DsPillShape.tag,
        bordered: true,
        cornerRadius: cornerRadius,
        label: consumptionSummaryLabel(context, totals),
        labelColor: foregroundColor,
        leading: Icon(
          Icons.eco_outlined,
          size: IconSizes.xs,
          color: foregroundColor,
        ),
      ),
    );
  }
}

/// Compact label shared by every lifetime consumption surface.
String consumptionSummaryLabel(
  BuildContext context,
  ConsumptionTotals totals,
) {
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

/// Full available consumption breakdown shared by every tooltip.
String consumptionSummaryTooltip(
  BuildContext context,
  ConsumptionTotals totals,
) {
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
    if (totals.durationMs > 0)
      messages.aiConsumptionDurationLine(
        formatConsumptionDuration(context, totals.durationMs),
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

/// Locale-aware compact duration shared by consumption governance surfaces.
String formatConsumptionDuration(BuildContext context, int durationMs) {
  if (durationMs > 0 && durationMs < Duration.millisecondsPerMinute) {
    return context.messages.aiConsumptionDurationLessThanMinute;
  }
  return formatDurationSummary(durationMs ~/ Duration.millisecondsPerSecond);
}
