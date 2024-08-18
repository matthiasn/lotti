import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/dashboard_survey_chart.dart';
import 'package:lotti/widgets/charts/dashboard_survey_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

class SurveySummary extends StatelessWidget {
  const SurveySummary(
    this.surveyEntry, {
    super.key,
    this.showChart = true,
  });

  final SurveyEntry surveyEntry;
  final bool showChart;

  @override
  Widget build(BuildContext context) {
    final surveyKey = surveyEntry.data.taskResult.identifier;
    final chartConfig = surveyTypes[surveyKey];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...surveyEntry.data.calculatedScores.entries.map(
            (mapEntry) => Padding(
              padding: const EdgeInsets.only(
                bottom: 5,
              ),
              child: Row(
                children: [
                  Text(
                    '${mapEntry.key}:',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: fontSizeMedium,
                    ),
                  ),
                  Text(
                    ' ${mapEntry.value}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: fontSizeMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showChart)
            Padding(
              padding: const EdgeInsets.all(8),
              child: DashboardSurveyChart(
                chartConfig: chartConfig!,
                rangeStart: getRangeStart(context: context),
                rangeEnd: getRangeEnd(),
              ),
            ),
        ],
      ),
    );
  }
}
