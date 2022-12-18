import 'dart:core';

import 'package:beamer/beamer.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/blocs/charts/measurables_chart_info_cubit.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/dashboard_chart.dart';
import 'package:lotti/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';

class DashboardMeasurablesLineChart extends StatelessWidget {
  const DashboardMeasurablesLineChart({
    super.key,
    required this.measurableDataTypeId,
    required this.dashboardId,
    required this.rangeStart,
    required this.rangeEnd,
    this.enableCreate = false,
  });

  final String measurableDataTypeId;
  final String? dashboardId;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final bool enableCreate;

  @override
  Widget build(BuildContext context) {
    final db = getIt<JournalDb>();

    return StreamBuilder<MeasurableDataType?>(
      stream: db.watchMeasurableDataTypeById(measurableDataTypeId),
      builder: (
        BuildContext context,
        AsyncSnapshot<MeasurableDataType?> typeSnapshot,
      ) {
        final measurableDataType = typeSnapshot.data;

        if (measurableDataType == null) {
          return const SizedBox.shrink();
        }

        return BlocProvider<MeasurablesChartInfoCubit>(
          create: (BuildContext context) => MeasurablesChartInfoCubit(),
          child: StreamBuilder<List<JournalEntity>>(
            stream: db.watchMeasurementsByType(
              type: measurableDataType.id,
              rangeStart: rangeStart.subtract(const Duration(hours: 12)),
              rangeEnd: rangeEnd,
            ),
            builder: (
              BuildContext context,
              AsyncSnapshot<List<JournalEntity>> measurementsSnapshot,
            ) {
              final measurements = measurementsSnapshot.data ?? [];

              final aggregationType =
                  measurableDataType.aggregationType ?? AggregationType.none;

              List<Observation> data;
              if (aggregationType == AggregationType.none) {
                data = aggregateMeasurementNone(measurements);
              } else if (aggregationType == AggregationType.dailyMax) {
                data = aggregateMaxByDay(
                  measurements,
                  rangeStart: rangeStart,
                  rangeEnd: rangeEnd,
                );
              } else if (aggregationType == AggregationType.hourlySum) {
                data = aggregateSumByHour(
                  measurements,
                  rangeStart: rangeStart,
                  rangeEnd: rangeEnd,
                );
              } else {
                data = aggregateSumByDay(
                  measurements,
                  rangeStart: rangeStart,
                  rangeEnd: rangeEnd,
                );
              }

              return DashboardChart(
                topMargin: 20,
                chartHeader: MeasurablesChartInfoWidget(
                  measurableDataType,
                  dashboardId: dashboardId,
                  enableCreate: enableCreate,
                  aggregationType: aggregationType,
                ),
                height: 180,
                chart: TimeSeriesLineChart(
                  data: data,
                  rangeStart: rangeStart,
                  rangeEnd: rangeEnd,
                  unit: measurableDataType.unitName,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class MeasurablesChartInfoWidget extends StatelessWidget {
  const MeasurablesChartInfoWidget(
    this.measurableDataType, {
    required this.dashboardId,
    required this.aggregationType,
    required this.enableCreate,
    super.key,
  });

  final MeasurableDataType measurableDataType;
  final AggregationType aggregationType;
  final String? dashboardId;
  final bool enableCreate;

  void onTapAdd() {
    final beamState =
        dashboardsBeamerDelegate.currentBeamLocation.state as BeamState;

    final id =
        beamState.uri.path.contains('carousel') ? 'carousel' : dashboardId;

    beamToNamed(
      '/dashboards/$id/measure/${measurableDataType.id}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MeasurablesChartInfoCubit, MeasurablesChartInfoState>(
      builder: (BuildContext context, MeasurablesChartInfoState state) {
        final selected = state.selected;

        return Positioned(
          top: 0,
          left: 10,
          child: SizedBox(
            width: MediaQuery.of(context).size.width - 20,
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width / 2,
                  ),
                  child: Text(
                    '${measurableDataType.displayName}'
                    '${aggregationType != AggregationType.none ? ' ' : ''}'
                    '${aggregationLabel(aggregationType)}',
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
                    ' ${NumberFormat('#,###.##').format(selected.value)}'
                    ' ${measurableDataType.unitName}',
                    style:
                        chartTitleStyle().copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
                const Spacer(),
                if (enableCreate)
                  IconButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onPressed: onTapAdd,
                    hoverColor: Colors.transparent,
                    icon: SvgPicture.asset(styleConfig().addIcon),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String aggregationLabel(AggregationType? aggregationType) {
  if (aggregationType == null) {
    return '';
  }
  return aggregationType != AggregationType.none
      ? '[${EnumToString.convertToString(aggregationType)}]'
      : '';
}
