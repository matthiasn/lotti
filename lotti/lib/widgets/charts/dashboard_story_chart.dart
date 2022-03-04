import 'dart:core';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';
import 'package:lotti/widgets/charts/dashboard_story_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

class DashboardStoryChart extends StatefulWidget {
  final DashboardStoryTimeItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  const DashboardStoryChart({
    Key? key,
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
  }) : super(key: key);

  @override
  State<DashboardStoryChart> createState() => _DashboardStoryChartState();
}

class _DashboardStoryChartState extends State<DashboardStoryChart> {
  final JournalDb _db = getIt<JournalDb>();
  final TagsService tagsService = getIt<TagsService>();
  final HealthImport _healthImport = getIt<HealthImport>();

  @override
  void initState() {
    super.initState();
    _healthImport.getWorkoutsHealthDataDelta();
  }

  @override
  Widget build(BuildContext context) {
    charts.SeriesRendererConfig<DateTime>? defaultRenderer =
        charts.BarRendererConfig<DateTime>();

    String storyTagId = widget.chartConfig.storyTagId;
    String title = tagsService.getTagById(storyTagId)?.tag ?? storyTagId;

    return StreamBuilder<List<JournalEntity?>>(
      stream: _db.watchJournalEntitiesByTag(
        rangeStart: widget.rangeStart,
        rangeEnd: widget.rangeEnd,
        tagId: storyTagId,
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<JournalEntity?>> snapshot,
      ) {
        List<JournalEntity?>? items = snapshot.data;

        if (items == null || items.isEmpty) {
          return const SizedBox.shrink();
        }

        List<charts.Series<Observation, DateTime>> seriesList = [
          charts.Series<Observation, DateTime>(
            id: widget.chartConfig.storyTagId,
            domainFn: (Observation val, _) => val.dateTime,
            measureFn: (Observation val, _) => val.value,
            data: aggregateStoryDailyTimeSum(items, widget.chartConfig),
          )
        ];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              key: Key('${widget.chartConfig.hashCode}'),
              color: Colors.white,
              height: 120,
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Stack(
                children: [
                  charts.TimeSeriesChart(
                    seriesList,
                    animate: true,
                    behaviors: [
                      chartRangeAnnotation(widget.rangeStart, widget.rangeEnd),
                    ],
                    domainAxis: timeSeriesAxis,
                    defaultRenderer: defaultRenderer,
                    primaryMeasureAxis: const charts.NumericAxisSpec(
                      tickProviderSpec: charts.BasicNumericTickProviderSpec(
                        zeroBound: false,
                        desiredTickCount: 5,
                        dataIsInWholeNumbers: true,
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
                          Text(
                            title,
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
        );
      },
    );
  }
}
