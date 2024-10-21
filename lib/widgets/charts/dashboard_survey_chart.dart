import 'dart:core';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/surveys/tools/run_surveys.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/dashboard_chart.dart';
import 'package:lotti/widgets/charts/dashboard_survey_data.dart';
import 'package:lotti/widgets/charts/time_series/time_series_multiline_chart.dart';

class DashboardSurveyChart extends StatelessWidget {
  DashboardSurveyChart({
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
    super.key,
  });

  final DashboardSurveyItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final JournalDb _db = getIt<JournalDb>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JournalEntity>>(
      stream: _db.watchSurveysByType(
        type: chartConfig.surveyType,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<JournalEntity>> snapshot,
      ) {
        final items = snapshot.data ?? [];

        void onTapAdd() {
          if (chartConfig.surveyType == cfq11SurveyTaskName) {
            runCfq11(
              context: context,
              themeData: Theme.of(context),
            );
          }
          if (chartConfig.surveyType == panasSurveyTaskName) {
            runPanas(
              context: context,
              themeData: Theme.of(context),
            );
          }
          if (chartConfig.surveyType == ghq12SurveyTaskName) {
            runGhq12(
              context: context,
              themeData: Theme.of(context),
            );
          }
        }

        final lineBarsData = surveyLines(
          entities: items,
          dashboardSurveyItem: chartConfig,
        );

        final allSpots = lineBarsData
            .map((data) => data.spots)
            .expand((spots) => spots)
            .toList();

        final minVal =
            allSpots.isEmpty ? 0 : allSpots.map((spot) => spot.y).reduce(min);
        final maxVal =
            allSpots.isEmpty ? 0 : allSpots.map((spot) => spot.y).reduce(max);

        return DashboardChart(
          topMargin: 10,
          chart: TimeSeriesMultiLineChart(
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            lineBarsData: lineBarsData,
            minVal: minVal,
            maxVal: maxVal,
          ),
          chartHeader: Positioned(
            top: 0,
            left: 20,
            child: SizedBox(
              width: max(MediaQuery.of(context).size.width, 300) - 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    chartConfig.surveyName,
                    style: chartTitleStyle,
                  ),
                  const Spacer(),
                  IconButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onPressed: onTapAdd,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
          ),
          height: 180,
        );
      },
    );
  }
}
