import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';
import 'package:lotti/features/dashboards/state/health_bmi_data.dart';
import 'package:lotti/features/dashboards/state/health_chart_controller.dart';
import 'package:lotti/features/dashboards/state/health_data.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/date_utils_extension.dart';

class BmiRangeLegend extends StatelessWidget {
  const BmiRangeLegend({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 40,
      left: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(77), //New
              blurRadius: 8,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ColoredBox(
            color: Colors.white.withAlpha(191),
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
                              color: colorFromCssHex(range.hexColor)
                                  .withAlpha(178),
                            ),
                          ),
                          const SizedBox(
                            width: 6,
                          ),
                          Text(
                            range.name,
                            style: chartTitleStyle.copyWith(
                              fontSize: 11,
                              color: Colors.black,
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

class BmiChartInfoWidget extends ConsumerWidget {
  const BmiChartInfoWidget(
    this.chartConfig, {
    required this.minInRange,
    required this.maxInRange,
    super.key,
  });

  final DashboardHealthItem chartConfig;
  final num minInRange;
  final num maxInRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minWeight = '${NumberFormat('#,###.#').format(minInRange)} kg';
    final maxWeight = '${NumberFormat('#,###.#').format(maxInRange)} kg';

    final heightEntries = ref
            .watch(
              healthObservationsControllerProvider(
                healthDataType: 'HealthDataType.HEIGHT',
                rangeStart: DateTime(0),
                rangeEnd:
                    DateTime.now().dayAtMidnight.add(const Duration(days: 1)),
              ),
            )
            .value ??
        [];

    final heightEntry = heightEntries.firstOrNull as QuantitativeEntry?;
    // TODO: use, or remove entire chart
    // ignore: unused_local_variable
    final height = heightEntry?.data.value;

    return Positioned(
      top: 0,
      left: 20,
      child: IgnorePointer(
        child: Container(
          width: MediaQuery.of(context).size.width - 30,
          padding: const EdgeInsets.only(
            right: 10,
            left: 10,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                healthTypes[chartConfig.healthType]?.displayName ??
                    chartConfig.healthType,
                style: chartTitleStyle,
              ),
              const SizedBox(width: 8),
              Text(
                '$minWeight - $maxWeight',
                style: chartTitleStyle.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardHealthBmiChart extends ConsumerWidget {
  const DashboardHealthBmiChart({
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
    this.transformationController,
    super.key,
  });

  final DashboardHealthItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final TransformationController? transformationController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weightData = ref
            .watch(
              healthObservationsControllerProvider(
                healthDataType: 'HealthDataType.WEIGHT',
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              ),
            )
            .value ??
        [];

    final minInRange = findMin(weightData);
    final maxInRange = findMax(weightData);
    return DashboardChart(
      chart: TimeSeriesLineChart(
        data: weightData,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        transformationController: transformationController,
      ),
      chartHeader: BmiChartInfoWidget(
        chartConfig,
        minInRange: minInRange,
        maxInRange: maxInRange,
      ),
      height: 320,
      overlay: const BmiRangeLegend(),
    );
  }
}
