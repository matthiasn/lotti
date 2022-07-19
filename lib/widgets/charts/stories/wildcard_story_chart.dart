import 'dart:core';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/charts/story_chart_info_cubit.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/charts/story_data.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/utils.dart';

class WildcardStoryChart extends StatefulWidget {
  const WildcardStoryChart({
    super.key,
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
  });

  final WildcardStoryTimeItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  State<WildcardStoryChart> createState() => _WildcardStoryChartState();
}

class _WildcardStoryChartState extends State<WildcardStoryChart> {
  final _chartState = charts.UserManagedState<DateTime>();
  final JournalDb _db = getIt<JournalDb>();
  final TagsService tagsService = getIt<TagsService>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final defaultRenderer = charts.BarRendererConfig<DateTime>();
    final subString = widget.chartConfig.storySubstring;
    final title = subString;

    return BlocProvider<StoryChartInfoCubit>(
      create: (BuildContext context) => StoryChartInfoCubit(),
      child: StreamBuilder<List<JournalEntity?>>(
        stream: _db.watchJournalByTagIds(
          match: subString,
          rangeStart: widget.rangeStart,
          rangeEnd: widget.rangeEnd,
        ),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<JournalEntity?>> snapshot,
        ) {
          final data = aggregateStoryTimeSum(
            snapshot.data ?? [],
            rangeStart: widget.rangeStart,
            rangeEnd: widget.rangeEnd,
            timeframe: AggregationTimeframe.daily,
          );

          final seriesList = [
            charts.Series<MeasuredObservation, DateTime>(
              id: widget.chartConfig.storySubstring,
              domainFn: (MeasuredObservation val, _) => val.dateTime,
              measureFn: (MeasuredObservation val, _) => val.value,
              data: data,
            )
          ];

          void _infoSelectionModelUpdated(
            charts.SelectionModel<DateTime> model,
          ) {
            if (model.hasDatumSelection) {
              final newSelection =
                  model.selectedDatum.first.datum as MeasuredObservation;
              context.read<StoryChartInfoCubit>().setSelected(newSelection);
              _chartState.selectionModels[charts.SelectionModelType.info] =
                  charts.UserManagedSelectionModel(model: model);
            } else {
              context.read<StoryChartInfoCubit>().clearSelected();
              _chartState.selectionModels[charts.SelectionModelType.info] =
                  charts.UserManagedSelectionModel();
            }
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                key: Key('${widget.chartConfig.hashCode}'),
                color: Colors.white,
                height: 120,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Stack(
                  children: [
                    charts.TimeSeriesChart(
                      seriesList,
                      animate: false,
                      defaultRenderer: defaultRenderer,
                      selectionModels: [
                        charts.SelectionModelConfig(
                          updatedListener: _infoSelectionModelUpdated,
                        )
                      ],
                      behaviors: [
                        chartRangeAnnotation(
                          widget.rangeStart,
                          widget.rangeEnd,
                        )
                      ],
                      domainAxis: timeSeriesAxis,
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
                    InfoWidget(title),
                  ],
                ),
              ),
            ),
          );
        },
      ),
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
    return BlocBuilder<StoryChartInfoCubit, StoryChartInfoState>(
      builder: (BuildContext context, StoryChartInfoState state) {
        final selected = state.selected;
        final duration = minutesToHhMmSs(selected?.value ?? 0);

        return Positioned(
          top: 0,
          left: MediaQuery.of(context).size.width / 4,
          child: SizedBox(
            width: MediaQuery.of(context).size.width / 2,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width / 2,
                    ),
                    child: Text(
                      title,
                      style: chartTitleStyle(),
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                  if (selected != null) ...[
                    const Spacer(),
                    Padding(
                      padding: AppTheme.chartDateHorizontalPadding,
                      child: Text(
                        ' ${ymd(selected.dateTime)}',
                        style: chartTitleStyle(),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      ' $duration',
                      style: chartTitleStyle()
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                  const Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class WildcardStoryWeeklyChart extends StatefulWidget {
  const WildcardStoryWeeklyChart({
    super.key,
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
  });

  final WildcardStoryTimeItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  State<WildcardStoryWeeklyChart> createState() =>
      _WildcardStoryWeeklyChartState();
}

class _WildcardStoryWeeklyChartState extends State<WildcardStoryWeeklyChart> {
  final _chartState = charts.UserManagedState<String>();
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

    return BlocProvider<WeeklyStoryChartInfoCubit>(
      create: (BuildContext context) => WeeklyStoryChartInfoCubit(),
      child: StreamBuilder<List<JournalEntity?>>(
        stream: _db.watchJournalByTagIds(
          match: subString,
          rangeStart: widget.rangeStart,
          rangeEnd: widget.rangeEnd,
        ),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<JournalEntity?>> snapshot,
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
              labelAccessorFn: (byWeek, _) =>
                  byWeek.value > 0 ? minutesToHhMm(byWeek.value) : '',
            ),
          ];

          void _infoSelectionModelUpdated(
            charts.SelectionModel<String> model,
          ) {
            if (model.hasDatumSelection) {
              final newSelection =
                  model.selectedDatum.first.datum as WeeklyAggregate;
              context
                  .read<WeeklyStoryChartInfoCubit>()
                  .setSelected(newSelection);
              _chartState.selectionModels[charts.SelectionModelType.info] =
                  charts.UserManagedSelectionModel(model: model);
            } else {
              context.read<WeeklyStoryChartInfoCubit>().clearSelected();
              _chartState.selectionModels[charts.SelectionModelType.info] =
                  charts.UserManagedSelectionModel();
            }
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                key: Key('${widget.chartConfig.hashCode}2'),
                color: Colors.white,
                height: 120,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Stack(
                  children: [
                    charts.BarChart(
                      seriesList,
                      animate: false,
                      selectionModels: [
                        charts.SelectionModelConfig(
                          updatedListener: _infoSelectionModelUpdated,
                        )
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
                    InfoWidget2(title),
                  ],
                ),
              ),
            ),
          );
        },
      ),
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
    return BlocBuilder<WeeklyStoryChartInfoCubit, WeeklyStoryChartInfoState>(
      builder: (BuildContext context, WeeklyStoryChartInfoState state) {
        final selected = state.selected;
        final duration = minutesToHhMmSs(selected?.value ?? 0);

        return Positioned(
          top: 0,
          left: MediaQuery.of(context).size.width / 4,
          child: SizedBox(
            width: MediaQuery.of(context).size.width / 2,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width / 2,
                    ),
                    child: Text(
                      title,
                      style: chartTitleStyle(),
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                  if (selected != null) ...[
                    const Spacer(),
                    Padding(
                      padding: AppTheme.chartDateHorizontalPadding,
                      child: Text(
                        selected.isoWeek,
                        style: chartTitleStyle(),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      ' $duration',
                      style: chartTitleStyle()
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                  const Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
