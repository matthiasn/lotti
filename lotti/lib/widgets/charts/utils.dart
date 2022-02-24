import 'dart:core';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/widgets.dart';
import 'package:lotti/classes/journal_entities.dart';

class SumPerDay {
  final DateTime day;
  final num sum;
  SumPerDay(this.day, this.sum);

  @override
  String toString() {
    return '$day $sum';
  }
}

const days = 30;
const defaultChartDuration = Duration(days: days + 1);

String ymd(DateTime day) {
  return day.toIso8601String().substring(0, 10);
}

List<SumPerDay> aggregateByDay(List<JournalEntity?> entities) {
  Map<String, num> sumsByDay = {};

  for (final entity in entities) {
    String dayString = ymd(entity!.meta.dateFrom);
    num n = sumsByDay[dayString] ?? 0;
    if (entity is MeasurementEntry) {
      sumsByDay[dayString] = n + entity.data.value;
    }
  }

  List<SumPerDay> aggregated = [];
  for (final dayString in sumsByDay.keys) {
    DateTime day = DateTime.parse(dayString);
    aggregated.add(SumPerDay(day, sumsByDay[dayString] ?? 0));
  }

  return aggregated;
}

charts.RangeAnnotation<DateTime> chartRangeAnnotation(
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  return charts.RangeAnnotation([
    charts.RangeAnnotationSegment(
      rangeStart,
      rangeEnd,
      charts.RangeAnnotationAxisType.domain,
    )
  ]);
}

const timeSeriesAxis = charts.DateTimeAxisSpec(
    tickProviderSpec: charts.AutoDateTimeTickProviderSpec(),
    renderSpec: charts.SmallTickRendererSpec(
      labelStyle: charts.TextStyleSpec(
        fontSize: 10,
      ),
    ));

DateTime getRangeStart(BuildContext context) {
  int durationDays = (MediaQuery.of(context).size.width / 10).ceil();
  final Duration duration = Duration(days: durationDays);
  final DateTime now = DateTime.now();
  final DateTime from = now.subtract(duration);
  return DateTime(from.year, from.month, from.day);
}

DateTime getRangeEnd() {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 23, 59, 59);
}
