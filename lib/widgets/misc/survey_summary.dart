import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/dashboard_survey_chart.dart';
import 'package:lotti/widgets/charts/dashboard_survey_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

class SurveySummaryWidget extends StatelessWidget {
  final SurveyEntry surveyEntry;
  const SurveySummaryWidget(
    this.surveyEntry, {
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String surveyKey = surveyEntry.data.taskResult.identifier;
    DashboardSurveyItem? chartConfig = surveyTypes[surveyKey];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...surveyEntry.data.calculatedScores.entries
            .map((mapEntry) => Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        '${mapEntry.key}: ',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Lato',
                          color: AppColors.entryTextColor,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        mapEntry.value.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                          color: AppColors.entryTextColor,
                          fontFamily: 'Lato',
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
        DashboardSurveyChart(
          chartConfig: chartConfig!,
          rangeStart: getRangeStart(context: context),
          rangeEnd: getRangeEnd(),
        ),
      ],
    );
  }
}
