import 'package:flutter/material.dart';
import 'package:lotti/features/ai_consumption/logic/consumption_formatting.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_table_card.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/series_resolver.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/insights/ui/widgets/insights_format.dart'
    show formatShare;
import 'package:lotti/l10n/app_localizations_context.dart';

/// Exhaustive per-model breakdown of the selected metric, with unit economics.
///
/// Each row carries the model's palette swatch — the same color it wears in
/// the model chart and its legend — plus a secondary line of the actionable
/// numbers a totals column can't answer: how many calls it made and its cost
/// per million tokens (its efficiency). The value/share columns degrade on
/// narrow panes instead of overflowing.
class ImpactModelTable extends StatelessWidget {
  const ImpactModelTable({
    required this.entries,
    required this.resolver,
    required this.metric,
    super.key,
  });

  /// Per-model totals, ranked descending by [metric] — the output of
  /// `rankedModelMetrics`.
  final List<MapEntry<String?, ConsumptionMetrics>> entries;

  /// Resolves model keys to labels and their palette swatch color — the same
  /// resolver the model chart uses, so one model = one color everywhere.
  final SeriesResolver resolver;
  final ConsumptionMetric metric;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final tokens = context.designTokens;
    final messages = context.messages;
    final brightness = Theme.of(context).brightness;
    final total = entries.fold<double>(
      0,
      (sum, e) => sum + metric.valueOf(e.value),
    );

    // "12 calls · €5.00/1M tok" — the cost-per-million is dropped when a model
    // reports no tokens or no cost (e.g. a local transcription model).
    String metaLine(ConsumptionMetrics m) {
      final calls = messages.aiImpactModelCallsLabel(
        formatCallCount(m.callCount),
      );
      if (m.totalTokens <= 0 || m.credits <= 0) return calls;
      final perMillion = m.credits / m.totalTokens * 1000000;
      return '$calls · '
          '${messages.aiImpactModelRatePerMillion(formatCredits(perMillion))}';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final showShare = constraints.maxWidth >= 280;
        final showValue = constraints.maxWidth >= 180;

        return ImpactTableCard(
          title: messages.aiImpactModelTitle,
          childrenBuilder: (context, headerStyle, numberStyle) => [
            _ModelTableRowLayout(
              showValue: showValue,
              showShare: showShare,
              model: Text(messages.aiImpactModelColumn, style: headerStyle),
              value: Text(
                messages.insightsTableTotal,
                style: headerStyle,
                textAlign: TextAlign.right,
              ),
              share: Text(
                messages.insightsTableShare,
                style: headerStyle,
                textAlign: TextAlign.right,
              ),
            ),
            Divider(height: 1, color: tokens.colors.decorative.level01),
            for (final entry in entries)
              _ModelTableRowLayout(
                showValue: showValue,
                showShare: showShare,
                model: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: tokens.spacing.step1),
                      child: Container(
                        width: tokens.spacing.step3,
                        height: tokens.spacing.step3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: resolver.swatchColor(entry.key, brightness),
                        ),
                      ),
                    ),
                    SizedBox(width: tokens.spacing.step3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resolver.labelFor(entry.key),
                            style: tokens.typography.styles.body.bodySmall
                                .copyWith(
                                  color: tokens.colors.text.highEmphasis,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            metaLine(entry.value),
                            style: tokens.typography.styles.others.caption
                                .copyWith(
                                  color: tokens.colors.text.mediumEmphasis,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                value: Text(
                  metric.formatValue(metric.valueOf(entry.value)),
                  style: numberStyle,
                  textAlign: TextAlign.right,
                ),
                share: Text(
                  formatShare(
                    total > 0 ? metric.valueOf(entry.value) / total : 0,
                  ),
                  style: numberStyle.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Fixed column layout shared by the header and data rows:
/// model (flex) · [value] · [share].
class _ModelTableRowLayout extends StatelessWidget {
  const _ModelTableRowLayout({
    required this.model,
    required this.value,
    required this.share,
    required this.showValue,
    required this.showShare,
  });

  final Widget model;
  final Widget value;
  final Widget share;
  final bool showValue;
  final bool showShare;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final numberColumnWidth = tokens.spacing.step10;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
      child: Row(
        children: [
          Expanded(child: model),
          if (showValue) SizedBox(width: numberColumnWidth, child: value),
          if (showShare) ...[
            SizedBox(width: tokens.spacing.step4),
            SizedBox(width: numberColumnWidth, child: share),
          ],
        ],
      ),
    );
  }
}
