import 'dart:core';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/create/fill_survey_page.dart';
import 'package:lotti/theme.dart';
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

        Future<void> onDoubleTap() async {
          if (chartConfig.surveyType == 'cfq11SurveyTask') {
            runCfq11(context: context);
          }
          if (chartConfig.surveyType == 'panasSurveyTask') {
            runPanas(context: context);
          }
        }

        return GestureDetector(
          onDoubleTap: onDoubleTap,
          onLongPress: onDoubleTap,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                key: Key('${chartConfig.hashCode}'),
                color: Colors.white,
                height: 120,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Stack(
                  children: [
                    charts.TimeSeriesChart(
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
                              style: chartTitleStyle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
