import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/widgets/charts/dashboard_health_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class HealthSummary extends StatelessWidget {
  final QuantitativeEntry qe;

  const HealthSummary(
    this.qe, {
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          DashboardHealthChart(
            chartConfig: DashboardHealthItem(
              color: '#0000FF',
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
