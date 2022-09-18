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
import 'package:lotti/widgets/charts/dashboard_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';

class DashboardStoryChart extends StatefulWidget {
  const DashboardStoryChart({
    super.key,
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
  });

  final DashboardStoryTimeItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  State<DashboardStoryChart> createState() => _DashboardStoryChartState();
}

class _DashboardStoryChartState extends State<DashboardStoryChart> {
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

    final storyTagId = widget.chartConfig.storyTagId;
    final title = tagsService.getTagById(storyTagId)?.tag ?? storyTagId;

    return BlocProvider<StoryChartInfoCubit>(
      create: (BuildContext context) => StoryChartInfoCubit(),
      child: StreamBuilder<List<JournalEntity?>>(
        stream: _db.watchJournalEntitiesByTag(
          rangeStart: widget.rangeStart,
          rangeEnd: widget.rangeEnd,
          tagId: storyTagId,
        ),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<JournalEntity?>> snapshot,
        ) {
          final items = snapshot.data ?? [];

          final data = aggregateStoryTimeSum(
            items,
            rangeStart: widget.rangeStart,
            rangeEnd: widget.rangeEnd,
            timeframe: AggregationTimeframe.daily,
          );

          final seriesList = [
            charts.Series<MeasuredObservation, DateTime>(
              id: widget.chartConfig.storyTagId,
              domainFn: (MeasuredObservation val, _) => val.dateTime,
              measureFn: (MeasuredObservation val, _) => val.value,
              colorFn: (_, __) => charts.Color.fromHex(code: '#82E6CE'),
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

          return DashboardChart(
            chart: charts.TimeSeriesChart(
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
            chartHeader: InfoWidget(title),
            height: 120,
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
