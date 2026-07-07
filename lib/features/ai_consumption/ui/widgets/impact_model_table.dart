import 'package:flutter/material.dart';
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_table_card.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/insights/ui/widgets/insights_format.dart'
    show formatShare;
import 'package:lotti/l10n/app_localizations_context.dart';

/// Exhaustive per-model breakdown of the selected metric.
///
/// Model keys are provider-native ids when available, then configured Lotti
/// model ids, then `null` for calls that reported usage without a model. The
/// table keeps the same value/share columns as the category breakdown and
/// degrades columns on narrow panes instead of overflowing.
class ImpactModelTable extends StatelessWidget {
  const ImpactModelTable({
    required this.entries,
    required this.metric,
    super.key,
  });

  final List<MapEntry<String?, double>> entries;
  final ConsumptionMetric metric;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final tokens = context.designTokens;
    final messages = context.messages;
    final total = entries.fold<double>(0, (sum, e) => sum + e.value);

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
              model: Text(
                messages.aiImpactModelColumn,
                style: headerStyle,
              ),
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
                model: Text(
                  _labelForModel(messages.aiImpactModelUnknown, entry.key),
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                value: Text(
                  metric.formatValue(entry.value),
                  style: numberStyle,
                  textAlign: TextAlign.right,
                ),
                share: Text(
                  formatShare(total > 0 ? entry.value / total : 0),
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

String _labelForModel(String unknownLabel, String? modelId) {
  final trimmed = modelId?.trim();
  if (trimmed == null || trimmed.isEmpty) return unknownLabel;
  return trimmed;
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
