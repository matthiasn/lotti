import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_chart.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/helpers.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// Detail-view summary for a quantitative (health) entry: an optional health
/// chart plus the formatted `type: value unit` line. Pass `showChart: false`
/// for the compact list-card variant.
class HealthSummary extends StatelessWidget {
  const HealthSummary(
    this.qe, {
    this.showChart = true,
    super.key,
  });

  final QuantitativeEntry qe;
  final bool showChart;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // Lead with the summary value (the one fact users scan for); the trend
    // chart is secondary context below it. No outer bottom padding — the card
    // shell owns the symmetric inset.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EntryTextWidget(entryTextForQuant(qe), padding: EdgeInsets.zero),
        if (showChart) SizedBox(height: tokens.spacing.cardItemSpacing),
        if (showChart)
          DashboardHealthChart(
            chartConfig: DashboardHealthItem(
              color: '#82E6CE',
              healthType: qe.data.dataType,
            ),
            rangeStart: getRangeStart(context: context),
            rangeEnd: getRangeEnd(),
          ),
      ],
    );
  }
}
