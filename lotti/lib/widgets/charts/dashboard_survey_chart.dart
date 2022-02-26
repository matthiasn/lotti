import 'dart:core';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/surveys/calculate.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/dashboard_survey_data.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/pages/add/survey_page.dart';
import 'package:research_package/model.dart';

class DashboardSurveyChart extends StatelessWidget {
  final DashboardSurveyItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  DashboardSurveyChart({
    Key? key,
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
  }) : super(key: key);

  final JournalDb _db = getIt<JournalDb>();

  @override
  Widget build(BuildContext context) {
    String dataType = chartConfig.surveyType;

    charts.SeriesRendererConfig<DateTime>? defaultRenderer =
        charts.LineRendererConfig<DateTime>(
      includePoints: false,
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
        List<JournalEntity?>? items = snapshot.data;

        if (items == null || items.isEmpty) {
          return const SizedBox.shrink();
        }

        void onDoubleTap() async {
          RPOrderedTask? task = surveyTasks[chartConfig.surveyType];
          Map<String, Set<String>>? scoreDefinitions =
              surveyScoreDefinitions[chartConfig.surveyType];

          if (task == null || scoreDefinitions == null) {
            return;
          }

          void Function(RPTaskResult) resultCallback = createResultCallback(
            scoreDefinitions: scoreDefinitions,
            context: context,
          );

          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            clipBehavior: Clip.antiAliasWithSaveLayer,
            builder: (BuildContext context) {
              return SurveyWidget(task, resultCallback);
            },
          );
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
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Stack(
                  children: [
                    charts.TimeSeriesChart(
                      surveySeries(
                        entities: items,
                        dashboardSurveyItem: chartConfig,
                      ),
                      animate: true,
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
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(chartConfig.surveyName,
                                style: chartTitleStyle),
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
