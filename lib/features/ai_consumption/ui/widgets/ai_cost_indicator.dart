import 'package:flutter/material.dart';
import 'package:lotti/features/ai_consumption/logic/consumption_formatting.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/consumption_summary_pill.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// How much of the consumption read-out an [AiCostIndicator] spells out.
enum AiCostDensity {
  /// Cost alone — the leaf glyph plus one amount. For places where the
  /// indicator rides along with other metadata (a task row's meta lane) and
  /// has to survive at a few dozen points of width.
  compact,

  /// Cost, energy and carbon, as the metadata surfaces show them. For a
  /// dedicated read-out row that owns its line.
  detail,
}

/// The canonical **AI cost** read-out: the leaf glyph and an amount.
///
/// One component for every surface that shows what AI has cost — task rows,
/// the task metadata section, and whatever comes next — so the aesthetic
/// (leaf + amount) is defined once. [density] chooses how much of the
/// consumption story is spelled out; the tooltip always carries the full
/// breakdown.
///
/// Renders nothing at all when the subject has no recorded AI calls: an
/// indicator reading "€0.00" would make every task look like it had been
/// through the machine.
///
/// ## Making it a drill-down
///
/// [onTap] is the extension point. It is currently wired to "open the task
/// details", but the widget is deliberately a self-contained, positioned
/// target rather than a span of text inside a row: a future cost **breakdown**
/// (per model, per call, per component) can be anchored to this box — an
/// `OverlayPortal` or `showMenu` at this widget's position — by replacing the
/// callback, with no change to any caller's layout. Tapped or not, the shape
/// follows the corner-radius convention: a fully-rounded shell when it acts,
/// tight tag corners when it only informs.
class AiCostIndicator extends StatelessWidget {
  const AiCostIndicator({
    required this.totals,
    this.density = AiCostDensity.compact,
    this.foregroundColor,
    this.onTap,
    super.key,
  });

  final ConsumptionTotals totals;

  /// How much of the read-out is spelled out. Defaults to [AiCostDensity.compact].
  final AiCostDensity density;

  /// Label and glyph color. Defaults to `text.mediumEmphasis` so the
  /// indicator sits at the same emphasis as the metadata around it.
  final Color? foregroundColor;

  /// What a tap does. Null renders a plain read-out with no hit target.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (totals.callCount == 0) return const SizedBox.shrink();

    final tokens = context.designTokens;
    final color = foregroundColor ?? tokens.colors.text.mediumEmphasis;
    final label = switch (density) {
      AiCostDensity.compact => consumptionCostLabel(context, totals),
      AiCostDensity.detail => consumptionSummaryLabel(context, totals),
    };

    return Semantics(
      label: context.messages.taskMetaAiSpendLabel,
      button: onTap != null,
      child: Tooltip(
        message: consumptionSummaryTooltip(context, totals),
        child: DsPill(
          variant: DsPillVariant.filled,
          // A tap makes it a control, and controls wear the fully-rounded
          // shell; without one it is a fact and keeps the tight tag corners.
          shape: onTap == null ? DsPillShape.tag : DsPillShape.pill,
          bordered: true,
          label: label,
          labelColor: color,
          leading: Icon(
            LottiIcons.eco,
            size: IconSizes.xs,
            color: color,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// The cost alone: credits for measured calls, the token count otherwise.
///
/// The compact sibling of [consumptionSummaryLabel], which additionally
/// spells out energy and carbon.
String consumptionCostLabel(BuildContext context, ConsumptionTotals totals) {
  if (totals.impactCallCount > 0) return formatCredits(totals.credits);
  return context.messages.aiConsumptionTokensLabel(
    formatTokenCount(totals.totalTokens),
  );
}
