import 'dart:core';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/utils.dart';

class MeasurementBarChart extends StatefulWidget {
  final MeasurableDataType? measurableDataType;

  const MeasurementBarChart({
    Key? key,
    required this.measurableDataType,
  }) : super(key: key);

  @override
  _MeasurementBarChartState createState() => _MeasurementBarChartState();
}

class _MeasurementBarChartState extends State<MeasurementBarChart> {
  final JournalDb _db = getIt<JournalDb>();
  late Stream<List<JournalEntity?>> stream;

  @override
  void initState() {
    super.initState();
    if (widget.measurableDataType != null) {
      stream = _db.watchMeasurementsByType(
        widget.measurableDataType!.name,
        DateTime.now().subtract(duration),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: stream,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<JournalEntity?>> snapshot,
        ) {
          List<JournalEntity?>? measurements = snapshot.data;

          if (measurements == null || measurements.isEmpty) {
            return const SizedBox.shrink();
          }

          List<charts.Series<SumPerDay, DateTime>> seriesList = [
            charts.Series<SumPerDay, DateTime>(
              id: 'Sales',
              colorFn: (SumPerDay val, _) {
                return charts.MaterialPalette.blue.shadeDefault;
              },
              domainFn: (SumPerDay val, _) => val.day,
              measureFn: (SumPerDay val, _) => val.sum,
              data: aggregateByDay(measurements),
            )
          ];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                key: Key(widget.measurableDataType?.description ?? ''),
                color: Colors.white,
                height: 240,
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Text(
                      widget.measurableDataType?.displayName ?? '',
                      style: TextStyle(
                        fontFamily: 'Oswald',
                        fontSize: 16,
                        color: AppColors.bodyBgColor,
                      ),
                    ),
                    Expanded(
                      child: charts.TimeSeriesChart(
                        seriesList,
                        animate: true,
                        defaultRenderer: charts.BarRendererConfig<DateTime>(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }
}
