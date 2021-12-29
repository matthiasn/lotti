import 'dart:core';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/measurables.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';

class SumPerDay {
  final String day;
  final num sum;
  SumPerDay(this.day, this.sum);

  @override
  String toString() {
    return '$day $sum';
  }
}

class MeasurementBarChart extends StatefulWidget {
  final MeasurableDataType? measurableDataType;

  const MeasurementBarChart({
    Key? key,
    required this.measurableDataType,
  }) : super(key: key);

  @override
  _MeasurementBarChartState createState() => _MeasurementBarChartState();
}

const days = 15;
const duration = Duration(days: days + 1);

List<SumPerDay> aggregateByDay(List<JournalEntity?> entities) {
  List<String> dayStrings = [];
  Map<String, num> sumsByDay = {};
  DateTime now = DateTime.now();

  String ymd(DateTime day) {
    return day.toIso8601String().substring(0, 10);
  }

  for (int i = days; i >= 0; i--) {
    DateTime day = now.subtract(Duration(days: i));
    String dayString = ymd(day);
    dayStrings.add(dayString);
    sumsByDay[dayString] = 0;
  }

  for (final entity in entities) {
    String dayString = ymd(entity!.meta.dateFrom);
    num n = sumsByDay[dayString] ?? 0;
    if (entity is MeasurementEntry) {
      sumsByDay[dayString] = n + entity.data.value;
    }
  }

  List<SumPerDay> aggregated = [];
  for (final dayString in dayStrings) {
    aggregated.add(SumPerDay(dayString, sumsByDay[dayString] ?? 0));
  }

  return aggregated;
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

          List<charts.Series<SumPerDay, String>> seriesList = [
            charts.Series<SumPerDay, String>(
              id: 'Sales',
              colorFn: (SumPerDay val, _) {
                return charts.MaterialPalette.blue.shadeDefault;
              },
              domainFn: (SumPerDay val, _) => val.day.substring(8, 10),
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
                      child: charts.BarChart(
                        seriesList,
                        animate: true,
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
