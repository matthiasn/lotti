import 'dart:core';
import 'dart:math';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lotti/blocs/charts/measurables_chart_info_cubit.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/pages/create/create_measurement_dialog.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/utils.dart';

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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MeasurablesChartInfoCubit, MeasurablesChartInfoState>(
      builder: (BuildContext context, MeasurablesChartInfoState state) {
        final selected = state.selected;

        Future<void> captureData() async {
          await showDialog<void>(
            context: context,
            builder: (context) {
              return MeasurementDialog(
                measurableId: measurableDataType.id,
              );
            },
          );
        }

        return Positioned(
          top: 0,
          left: 20,
          child: SizedBox(
            width: max(MediaQuery.of(context).size.width, 300) - 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width / 2,
                  ),
                  child: Text(
                    '${measurableDataType.displayName}'
                    '${aggregationType != AggregationType.none ? ' ' : ''}'
                    '${aggregationLabel(aggregationType)}',
                    style: chartTitleStyle,
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
                      style: chartTitleStyle,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    ' ${NumberFormat('#,###.##').format(selected.value)}'
                    ' ${measurableDataType.unitName}',
                    style:
                        chartTitleStyle.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
                const Spacer(),
                if (enableCreate)
                  IconButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onPressed: captureData,
                    icon: const Icon(Icons.add_rounded),
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
