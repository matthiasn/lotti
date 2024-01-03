import 'dart:core';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/charts/story_data.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/charts/dashboard_chart.dart';
import 'package:lotti/widgets/charts/time_series/time_series_bar_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';

class WildcardStoryChart extends StatefulWidget {
  const WildcardStoryChart({
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
    super.key,
  });

  final WildcardStoryTimeItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  State<WildcardStoryChart> createState() => _WildcardStoryChartState();
}

class _WildcardStoryChartState extends State<WildcardStoryChart> {
  final JournalDb _db = getIt<JournalDb>();
  final TagsService tagsService = getIt<TagsService>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final subString = widget.chartConfig.storySubstring;
    final title = subString;

    return StreamBuilder<List<JournalEntity>>(
      stream: _db.watchJournalByTagIds(
        match: subString,
        rangeStart: widget.rangeStart,
        rangeEnd: widget.rangeEnd.add(const Duration(days: 1)),
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<JournalEntity>> snapshot,
      ) {
        final data = aggregateStoryTimeSum(
          snapshot.data ?? [],
          rangeStart: widget.rangeStart,
          rangeEnd: widget.rangeEnd.add(const Duration(days: 1)),
          timeframe: AggregationTimeframe.daily,
        );

        return DashboardChart(
          chart: TimeSeriesBarChart(
            data: data,
            valueInMinutes: true,
            rangeStart: widget.rangeStart,
            rangeEnd: widget.rangeEnd,
            colorByValue: (Observation observation) =>
                colorFromCssHex(widget.chartConfig.color),
          ),
          chartHeader: InfoWidget(title),
          height: 120,
        );
      },
    );
  }
}

class InfoWidget extends StatelessWidget {
  const InfoWidget(
    this.title, {
    super.key,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: IgnorePointer(
          child: Row(
            children: [
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width / 2,
                ),
                child: Text(
                  title,
                  style: chartTitleStyle,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class WildcardStoryWeeklyChart extends StatefulWidget {
  const WildcardStoryWeeklyChart({
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
    super.key,
  });

  final WildcardStoryTimeItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  State<WildcardStoryWeeklyChart> createState() =>
      _WildcardStoryWeeklyChartState();
}

class _WildcardStoryWeeklyChartState extends State<WildcardStoryWeeklyChart> {
  final JournalDb _db = getIt<JournalDb>();
  final TagsService tagsService = getIt<TagsService>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final subString = widget.chartConfig.storySubstring;
    final title = subString;

    return StreamBuilder<List<JournalEntity>>(
      stream: _db.watchJournalByTagIds(
        match: subString,
        rangeStart: widget.rangeStart,
        rangeEnd: widget.rangeEnd,
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<JournalEntity>> snapshot,
      ) {
        final data = aggregateStoryWeeklyTimeSum(
          snapshot.data ?? [],
          rangeStart: widget.rangeStart,
          rangeEnd: widget.rangeEnd,
        );

        final seriesList = [
          charts.Series<WeeklyAggregate, String>(
            id: widget.chartConfig.storySubstring,
            domainFn: (WeeklyAggregate val, _) => val.isoWeek.substring(5),
            measureFn: (WeeklyAggregate val, _) => val.value,
            data: data,
            colorFn: (_, __) => charts.Color.fromHex(code: '#82E6CE'),
            labelAccessorFn: (byWeek, _) =>
                byWeek.value > 0 ? minutesToHhMm(byWeek.value) : '',
          ),
        ];

        void infoSelectionModelUpdated(
          charts.SelectionModel<String> model,
        ) {}

        return DashboardChart(
          chart: charts.BarChart(
            seriesList,
            animate: false,
            selectionModels: [
              charts.SelectionModelConfig(
                updatedListener: infoSelectionModelUpdated,
              ),
            ],
            barRendererDecorator: charts.BarLabelDecorator<String>(
              insideLabelStyleSpec: const charts.TextStyleSpec(
                fontSize: 8,
                color: charts.Color.white,
              ),
              outsideLabelStyleSpec: const charts.TextStyleSpec(
                fontSize: 8,
              ),
            ),
            domainAxis: const charts.OrdinalAxisSpec(),
            primaryMeasureAxis: const charts.NumericAxisSpec(
              tickFormatterSpec: charts.BasicNumericTickFormatterSpec(
                minutesToHhMm,
              ),
              tickProviderSpec: charts.BasicNumericTickProviderSpec(
                zeroBound: true,
                dataIsInWholeNumbers: false,
                desiredMinTickCount: 4,
                desiredMaxTickCount: 5,
              ),
            ),
          ),
          chartHeader: InfoWidget2(title),
          height: 120,
        );
      },
    );
  }
}

class InfoWidget2 extends StatelessWidget {
  const InfoWidget2(
    this.title, {
    super.key,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 20,
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: IgnorePointer(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width / 2,
                ),
                child: Text(
                  '$title [weekly]',
                  style: chartTitleStyle,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
