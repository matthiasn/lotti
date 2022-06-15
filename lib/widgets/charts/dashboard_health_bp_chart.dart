import 'dart:core';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lotti/blocs/charts/bp_chart_info_cubit.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

class DashboardHealthBpChart extends StatefulWidget {
  const DashboardHealthBpChart({
    super.key,
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
  });

  final DashboardHealthItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  State<DashboardHealthBpChart> createState() => _DashboardHealthBpChartState();
}

class _DashboardHealthBpChartState extends State<DashboardHealthBpChart> {
  final JournalDb _db = getIt<JournalDb>();
  final _chartState = charts.UserManagedState<DateTime>();

  @override
  Widget build(BuildContext context) {
    const systolicType = 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC';
    const diastolicType = 'HealthDataType.BLOOD_PRESSURE_DIASTOLIC';
    final dataTypes = <String>[systolicType, diastolicType];

    final charts.SeriesRendererConfig<DateTime> defaultRenderer =
        charts.LineRendererConfig<DateTime>();

    return BlocProvider<BpChartInfoCubit>(
      create: (BuildContext context) => BpChartInfoCubit(),
      child: StreamBuilder<List<JournalEntity?>>(
        stream: _db.watchQuantitativeByTypes(
          types: dataTypes,
          rangeStart: widget.rangeStart,
          rangeEnd: widget.rangeEnd,
        ),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<JournalEntity?>> snapshot,
        ) {
          final items = snapshot.data;

          if (items == null || items.isEmpty) {
            return const SizedBox.shrink();
          }

          void _infoSelectionModelUpdated(
            charts.SelectionModel<DateTime> model,
          ) {
            if (model.hasDatumSelection) {
              final data =
                  model.selectedDatum.map((d) => d.datum as Observation);

              context.read<BpChartInfoCubit>().setSelected(
                    systolic: data.reduce(
                      (Observation a, Observation b) =>
                          a.value < b.value ? b : a,
                    ),
                    diastolic: data.reduce(
                      (Observation a, Observation b) =>
                          a.value > b.value ? b : a,
                    ),
                  );

              _chartState.selectionModels[charts.SelectionModelType.info] =
                  charts.UserManagedSelectionModel(model: model);
            } else {
              context.read<BpChartInfoCubit>().clearSelected();
              _chartState.selectionModels[charts.SelectionModelType.info] =
                  charts.UserManagedSelectionModel();
            }
          }

          final systolicData = aggregateNoneFilteredBy(items, systolicType);
          final diastolicData = aggregateNoneFilteredBy(items, diastolicType);

          final blue = charts.MaterialPalette.blue.shadeDefault;
          final red = charts.MaterialPalette.red.shadeDefault;

          final seriesList = <charts.Series<Observation, DateTime>>[
            charts.Series<Observation, DateTime>(
              id: systolicType,
              colorFn: (Observation val, _) => red,
              domainFn: (Observation val, _) => val.dateTime,
              measureFn: (Observation val, _) => val.value,
              data: systolicData,
            ),
            charts.Series<Observation, DateTime>(
              id: diastolicType,
              colorFn: (Observation val, _) => blue,
              domainFn: (Observation val, _) => val.dateTime,
              measureFn: (Observation val, _) => val.value,
              data: diastolicData,
            ),
          ];

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                key: Key('${widget.chartConfig.hashCode}'),
                color: Colors.white,
                height: 200,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Stack(
                  children: [
                    charts.TimeSeriesChart(
                      seriesList,
                      animate: false,
                      behaviors: [
                        charts.RangeAnnotation(
                          [
                            charts.RangeAnnotationSegment(
                              widget.rangeStart,
                              widget.rangeEnd,
                              charts.RangeAnnotationAxisType.domain,
                              color: charts.MaterialPalette.white,
                            ),
                            charts.RangeAnnotationSegment(
                              60,
                              80,
                              charts.RangeAnnotationAxisType.measure,
                              color: charts.Color(
                                r: blue.r,
                                g: blue.g,
                                b: blue.b,
                                a: 24,
                              ),
                            ),
                            charts.RangeAnnotationSegment(
                              90,
                              130,
                              charts.RangeAnnotationAxisType.measure,
                              color: charts.Color(
                                r: red.r,
                                g: red.g,
                                b: red.b,
                                a: 24,
                              ),
                            ),
                          ],
                        )
                      ],
                      domainAxis: timeSeriesAxis,
                      defaultRenderer: defaultRenderer,
                      selectionModels: [
                        charts.SelectionModelConfig(
                          updatedListener: _infoSelectionModelUpdated,
                        ),
                      ],
                      primaryMeasureAxis: const charts.NumericAxisSpec(
                        tickProviderSpec: charts.BasicNumericTickProviderSpec(
                          zeroBound: false,
                          dataIsInWholeNumbers: true,
                          desiredMinTickCount: 11,
                          desiredMaxTickCount: 15,
                        ),
                      ),
                    ),
                    const BpChartInfoWidget(),
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

class BpChartInfoWidget extends StatelessWidget {
  const BpChartInfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BpChartInfoCubit, BpChartInfoState>(
      builder: (BuildContext context, BpChartInfoState state) {
        final systolic = state.systolic;
        final diastolic = state.diastolic;

        return Positioned(
          top: -1,
          left: MediaQuery.of(context).size.width / 4,
          child: SizedBox(
            width: MediaQuery.of(context).size.width / 2,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  if (systolic == null)
                    Text(
                      'Blood Pressure',
                      style: chartTitleStyle,
                    ),
                  if (systolic != null) ...[
                    Padding(
                      padding: AppTheme.chartDateHorizontalPadding,
                      child: Text(
                        ' ${ymd(systolic.dateTime)}',
                        style: chartTitleStyle,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      ' ${NumberFormat('#').format(systolic.value)}/'
                      '${NumberFormat('#').format(diastolic!.value)} mmHg',
                      style: chartTitleStyle.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
