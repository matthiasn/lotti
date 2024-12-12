import 'dart:core';

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/charts/dashboard_chart.dart';
import 'package:lotti/widgets/charts/dashboard_health_bmi_data.dart';
import 'package:lotti/widgets/charts/dashboard_health_config.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';
import 'package:lotti/widgets/charts/time_series/time_series_line_chart.dart';

class DashboardHealthBmiChart extends StatefulWidget {
  const DashboardHealthBmiChart({
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
    super.key,
  });

  final DashboardHealthItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  State<DashboardHealthBmiChart> createState() =>
      _DashboardHealthBmiChartState();
}

class _DashboardHealthBmiChartState extends State<DashboardHealthBmiChart> {
  _DashboardHealthBmiChartState() {
    final now = DateTime.now();
    _healthImport.fetchHealthData(
      dateFrom: now.subtract(const Duration(days: 3650)),
      dateTo: now,
      types: [HealthDataType.HEIGHT],
    );
  }

  final JournalDb _db = getIt<JournalDb>();
  final HealthImport _healthImport = getIt<HealthImport>();

  @override
  Widget build(BuildContext context) {
    const weightType = 'HealthDataType.WEIGHT';

    return StreamBuilder<List<JournalEntity>>(
      stream: _db.watchQuantitativeByType(
        type: 'HealthDataType.HEIGHT',
        rangeStart: DateTime(2010),
        rangeEnd: DateTime.now(),
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<JournalEntity>> snapshot,
      ) {
        final heightEntry = snapshot.data?.first as QuantitativeEntry?;
        final height = heightEntry?.data.value;

        if (height == null) {
          return const CircularProgressIndicator();
        }

        return StreamBuilder<List<JournalEntity>>(
          stream: _db.watchQuantitativeByType(
            type: weightType,
            rangeStart: widget.rangeStart,
            rangeEnd: widget.rangeEnd,
          ),
          builder: (
            BuildContext context,
            AsyncSnapshot<List<JournalEntity>> snapshot,
          ) {
            if (snapshot.data == null) {
              return const CircularProgressIndicator();
            }

            final items = snapshot.data ?? [];
            final weightData = aggregateNone(items, weightType);

            final minInRange = findMin(weightData);
            final maxInRange = findMax(weightData);

            return DashboardChart(
              chart: TimeSeriesLineChart(
                data: weightData,
                rangeStart: widget.rangeStart,
                rangeEnd: widget.rangeEnd,
              ),
              chartHeader: BmiChartInfoWidget(
                widget.chartConfig,
                height: height,
                minInRange: minInRange,
                maxInRange: maxInRange,
              ),
              height: 320,
              overlay: const BmiRangeLegend(),
            );
          },
        );
      },
    );
  }
}

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

class BmiChartInfoWidget extends StatelessWidget {
  const BmiChartInfoWidget(
    this.chartConfig, {
    required this.height,
    required this.minInRange,
    required this.maxInRange,
    super.key,
  });

  final DashboardHealthItem chartConfig;
  final num? height;
  final num minInRange;
  final num maxInRange;

  @override
  Widget build(BuildContext context) {
    final minWeight = '${NumberFormat('#,###.#').format(minInRange)} kg';
    final maxWeight = '${NumberFormat('#,###.#').format(maxInRange)} kg';

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
