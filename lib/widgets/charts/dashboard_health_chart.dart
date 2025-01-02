import 'dart:core';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/dashboard_health_bmi_chart.dart';
import 'package:lotti/widgets/charts/dashboard_health_bp_chart.dart';
import 'package:lotti/widgets/charts/dashboard_health_config.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';
import 'package:lotti/widgets/charts/time_series/time_series_bar_chart.dart';
import 'package:lotti/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';

class DashboardHealthChart extends StatefulWidget {
  const DashboardHealthChart({
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
    super.key,
  });

  final DashboardHealthItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  State<DashboardHealthChart> createState() => _DashboardHealthChartState();
}

class _DashboardHealthChartState extends State<DashboardHealthChart> {
  final JournalDb _db = getIt<JournalDb>();
  final HealthImport _healthImport = getIt<HealthImport>();

  @override
  void initState() {
    super.initState();
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }

    Future.delayed(Duration(milliseconds: 200 + Random().nextInt(100)), () {
      _healthImport.fetchHealthDataDelta(widget.chartConfig.healthType);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataType = widget.chartConfig.healthType;

    if (dataType == 'BLOOD_PRESSURE') {
      return DashboardHealthBpChart(
        chartConfig: widget.chartConfig,
        rangeStart: widget.rangeStart,
        rangeEnd: widget.rangeEnd,
      );
    }

    if (dataType == 'BODY_MASS_INDEX') {
      return DashboardHealthBmiChart(
        chartConfig: widget.chartConfig,
        rangeStart: widget.rangeStart,
        rangeEnd: widget.rangeEnd,
      );
    }

    final healthType = healthTypes[dataType];
    final isBarChart = healthType?.chartType == HealthChartType.barChart;

    return StreamBuilder<List<JournalEntity>>(
      stream: _db.watchQuantitativeByType(
        type: widget.chartConfig.healthType,
        rangeStart: widget.rangeStart,
        rangeEnd: widget.rangeEnd,
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<JournalEntity>> snapshot,
      ) {
        final items = snapshot.data ?? [];
        final data = aggregateByType(items, dataType);

        return DashboardChart(
          chart: isBarChart
              ? TimeSeriesBarChart(
                  data: data,
                  rangeStart: widget.rangeStart,
                  rangeEnd: widget.rangeEnd,
                  unit: healthType?.unit ?? '',
                  valueInHours: healthType?.unit == 'h',
                  colorByValue: (Observation observation) =>
                      colorByValueAndType(
                    observation,
                    healthType,
                  ),
                )
              : TimeSeriesLineChart(
                  data: data,
                  rangeStart: widget.rangeStart,
                  rangeEnd: widget.rangeEnd,
                  unit: healthType?.unit ?? '',
                ),
          chartHeader: HealthChartInfoWidget(widget.chartConfig),
          height: isBarChart ? 180 : 150,
        );
      },
    );
  }
}

class HealthChartInfoWidget extends StatelessWidget {
  const HealthChartInfoWidget(
    this.chartConfig, {
    super.key,
  });

  final DashboardHealthItem chartConfig;

  @override
  Widget build(BuildContext context) {
    final healthType = healthTypes[chartConfig.healthType];

    return Positioned(
      top: 0,
      left: 20,
      child: SizedBox(
        width: max(MediaQuery.of(context).size.width, 300) - 20,
        child: IgnorePointer(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                healthType?.displayName ?? chartConfig.healthType,
                style: chartTitleStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
