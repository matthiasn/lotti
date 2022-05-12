import 'dart:core';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health/health.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:intl/intl.dart';
import 'package:lotti/blocs/charts/health_chart_info_cubit.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/dashboard_health_bmi_data.dart';
import 'package:lotti/widgets/charts/dashboard_health_config.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

class DashboardHealthBmiChart extends StatefulWidget {
  final DashboardHealthItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  const DashboardHealthBmiChart({
    Key? key,
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
  }) : super(key: key);

  @override
  State<DashboardHealthBmiChart> createState() =>
      _DashboardHealthBmiChartState();
}

class _DashboardHealthBmiChartState extends State<DashboardHealthBmiChart> {
  final JournalDb _db = getIt<JournalDb>();
  final HealthImport _healthImport = getIt<HealthImport>();
  final _chartState = charts.UserManagedState<DateTime>();

  _DashboardHealthBmiChartState() {
    DateTime now = DateTime.now();
    _healthImport.fetchHealthData(
      dateFrom: now.subtract(const Duration(days: 3650)),
      dateTo: now,
      types: [HealthDataType.HEIGHT],
    );
  }

  @override
  Widget build(BuildContext context) {
    String weightType = 'HealthDataType.WEIGHT';

    charts.SeriesRendererConfig<DateTime>? defaultRenderer =
        charts.LineRendererConfig<DateTime>(
      includePoints: false,
      strokeWidthPx: 2,
    );
    return BlocProvider<HealthChartInfoCubit>(
      create: (BuildContext context) => HealthChartInfoCubit(),
      child: StreamBuilder<List<JournalEntity?>>(
        stream: _db.watchQuantitativeByType(
          type: 'HealthDataType.HEIGHT',
          rangeStart: DateTime(2010),
          rangeEnd: DateTime.now(),
        ),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<JournalEntity?>> snapshot,
        ) {
          void _infoSelectionModelUpdated(
              charts.SelectionModel<DateTime> model) {
            if (model.hasDatumSelection) {
              Observation newSelection =
                  model.selectedDatum.first.datum as Observation;
              context.read<HealthChartInfoCubit>().setSelected(newSelection);

              _chartState.selectionModels[charts.SelectionModelType.info] =
                  charts.UserManagedSelectionModel(model: model);
            } else {
              context.read<HealthChartInfoCubit>().clearSelected();
              _chartState.selectionModels[charts.SelectionModelType.info] =
                  charts.UserManagedSelectionModel();
            }
          }

          QuantitativeEntry? heightEntry =
              snapshot.data?.first as QuantitativeEntry?;
          num? height = heightEntry?.data.value;

          if (height == null) {
            return Text(
              'Missing height entry',
              style: labelStyle,
            );
          }

          return StreamBuilder<List<JournalEntity?>>(
            stream: _db.watchQuantitativeByType(
              type: weightType,
              rangeStart: widget.rangeStart,
              rangeEnd: widget.rangeEnd,
            ),
            builder: (
              BuildContext context,
              AsyncSnapshot<List<JournalEntity?>> snapshot,
            ) {
              List<JournalEntity?>? items = snapshot.data ?? [];
              List<Observation> weightData = aggregateNone(items, weightType);

              num minInRange = findMin(weightData);
              num maxInRange = findMax(weightData);

              List<charts.RangeAnnotationSegment<num>> rangeAnnotationSegments =
                  makeRangeAnnotationSegments(weightData, height);

              int tickCount = rangeAnnotationSegments.length * 2;
              charts.Color blue = charts.MaterialPalette.blue.shadeDefault;

              List<charts.Series<Observation, DateTime>> seriesList = [
                charts.Series<Observation, DateTime>(
                  id: weightType,
                  colorFn: (Observation val, _) => blue,
                  domainFn: (Observation val, _) => val.dateTime,
                  measureFn: (Observation val, _) => val.value,
                  data: weightData,
                ),
              ];

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    key: Key('${widget.chartConfig.hashCode}'),
                    color: Colors.white,
                    height: 320,
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Stack(
                      children: [
                        charts.TimeSeriesChart(
                          seriesList,
                          animate: false,
                          behaviors: [
                            charts.RangeAnnotation([
                              charts.RangeAnnotationSegment(
                                  widget.rangeStart,
                                  widget.rangeEnd,
                                  charts.RangeAnnotationAxisType.domain,
                                  color: charts.Color.white),
                              ...rangeAnnotationSegments,
                            ]),
                          ],
                          domainAxis: timeSeriesAxis,
                          defaultRenderer: defaultRenderer,
                          selectionModels: [
                            charts.SelectionModelConfig(
                              type: charts.SelectionModelType.info,
                              updatedListener: _infoSelectionModelUpdated,
                            ),
                          ],
                          primaryMeasureAxis: charts.NumericAxisSpec(
                            tickProviderSpec:
                                charts.BasicNumericTickProviderSpec(
                              zeroBound: false,
                              dataIsInWholeNumbers: true,
                              desiredTickCount: tickCount,
                            ),
                          ),
                        ),
                        BmiChartInfoWidget(
                          widget.chartConfig,
                          height: height,
                          minInRange: minInRange,
                          maxInRange: maxInRange,
                        ),
                        const BmiRangeLegend(),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class BmiRangeLegend extends StatelessWidget {
  const BmiRangeLegend({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 40,
      left: 40,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3), //New
              blurRadius: 8.0,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: Colors.white.withOpacity(0.75),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...bmiRanges.reversed.map(
                    (range) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              width: 12,
                              height: 12,
                              color: HexColor(range.hexColor).withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(
                            width: 6,
                          ),
                          Text(
                            range.name,
                            style: chartTitleStyle.copyWith(
                              fontSize: 10,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BmiChartInfoWidget extends StatelessWidget {
  const BmiChartInfoWidget(
    this.chartConfig, {
    required this.height,
    required this.minInRange,
    required this.maxInRange,
    Key? key,
  }) : super(key: key);

  final DashboardHealthItem chartConfig;
  final num? height;
  final num minInRange;
  final num maxInRange;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HealthChartInfoCubit, HealthChartInfoState>(
        builder: (BuildContext context, HealthChartInfoState state) {
      final Observation? selected = state.selected;
      num? weight = selected?.value;

      return Positioned(
        top: -1,
        left: MediaQuery.of(context).size.width / 4,
        child: SizedBox(
          width: MediaQuery.of(context).size.width / 2,
          child: IgnorePointer(
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                if (selected == null)
                  Text(
                    healthTypes[chartConfig.healthType]?.displayName ??
                        chartConfig.healthType,
                    style: chartTitleStyle,
                  ),
                if (selected != null) ...[
                  Padding(
                    padding: AppTheme.chartDateHorizontalPadding,
                    child: Text(
                      ' ${ymd(selected.dateTime)}',
                      style: chartTitleStyle,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    ' ${NumberFormat('#,###.##').format(selected.value)} kg ',
                    style: chartTitleStyle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    ' BMI: ${NumberFormat('#.#').format(calculateBMI(height!, weight!))}',
                    style: chartTitleStyle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                if (selected == null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Min: ${NumberFormat('#,###.#').format(minInRange)} kg ',
                    style: chartTitleStyle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Max: ${NumberFormat('#,###.#').format(maxInRange)} kg ',
                    style: chartTitleStyle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }
}
