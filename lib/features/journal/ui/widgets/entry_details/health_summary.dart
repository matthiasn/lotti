import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_chart.dart';
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        children: [
          if (showChart)
            DashboardHealthChart(
              chartConfig: DashboardHealthItem(
                color: '#82E6CE',
                healthType: qe.data.dataType,
              ),
              rangeStart: getRangeStart(context: context),
              rangeEnd: getRangeEnd(),
            ),
          const SizedBox(height: 8),
          InfoText(entryTextForQuant(qe)),
        ],
      ),
    );
  }
}
