import 'dart:core';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/surveys/run_surveys.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/dashboard_survey_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

class DashboardSurveyChart extends StatelessWidget {
  DashboardSurveyChart({
    super.key,
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
  });

  final DashboardSurveyItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final JournalDb _db = getIt<JournalDb>();

  @override
  Widget build(BuildContext context) {
    final charts.SeriesRendererConfig<DateTime> defaultRenderer =
        charts.LineRendererConfig<DateTime>(
      strokeWidthPx: 2.5,
    );

    return StreamBuilder<List<JournalEntity?>>(
      stream: _db.watchSurveysByType(
        type: chartConfig.surveyType,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<JournalEntity?>> snapshot,
      ) {
        final items = snapshot.data ?? [];

        void onTapAdd() {
          if (chartConfig.surveyType == 'cfq11SurveyTask') {
            runCfq11(context: context);
          }
          if (chartConfig.surveyType == 'panasSurveyTask') {
            runPanas(context: context);
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              key: Key('${chartConfig.hashCode}'),
              color: Colors.white,
              height: 120,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: charts.TimeSeriesChart(
                      surveySeries(
                        entities: items,
                        dashboardSurveyItem: chartConfig,
                      ),
                      animate: false,
                      behaviors: [
                        chartRangeAnnotation(rangeStart, rangeEnd),
                      ],
                      domainAxis: timeSeriesAxis,
                      defaultRenderer: defaultRenderer,
                      primaryMeasureAxis: const charts.NumericAxisSpec(
                        tickProviderSpec: charts.BasicNumericTickProviderSpec(
                          zeroBound: false,
                          desiredTickCount: 5,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: MediaQuery.of(context).size.width / 4,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width / 2,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            chartConfig.surveyName,
                            style: chartTitleStyle(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton(
                      padding: const EdgeInsets.only(
                        right: 6,
                        top: 48,
                        left: 16,
                        bottom: 48,
                      ),
                      onPressed: onTapAdd,
                      icon: const Icon(
                        Icons.add_circle_outline,
                        size: 28,
                        color: Color.fromRGBO(0, 0, 0, 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
