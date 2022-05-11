import 'dart:core';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/widgets.dart';
import 'package:lotti/classes/journal_entities.dart';

class MeasuredObservation {
  final DateTime dateTime;
  final num value;
  MeasuredObservation(this.dateTime, this.value);

  @override
  String toString() {
    return '$dateTime $value';
  }
}

const days = 30;
const defaultChartDuration = Duration(days: days + 1);

String ymd(DateTime day) {
  return day.toIso8601String().substring(0, 10);
}

List<MeasuredObservation> aggregateSumByDay(
  List<JournalEntity?> entities, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  Map<String, num> sumsByDay = {};

  Duration range = rangeEnd.difference(rangeStart);
  List<String> dayStrings = List<String>.generate(range.inDays, (days) {
    DateTime day = rangeStart.add(Duration(days: days));
    return ymd(day);
  });

  for (final dayString in dayStrings) {
    sumsByDay[dayString] = 0;
  }

  for (final entity in entities) {
    String dayString = ymd(entity!.meta.dateFrom);
    num n = sumsByDay[dayString] ?? 0;
    if (entity is MeasurementEntry) {
      sumsByDay[dayString] = n + entity.data.value;
    }
  }

  List<MeasuredObservation> aggregated = [];
  for (final dayString in sumsByDay.keys) {
    DateTime day = DateTime.parse(dayString);
    aggregated.add(MeasuredObservation(day, sumsByDay[dayString] ?? 0));
  }

  return aggregated;
}

List<MeasuredObservation> aggregateMeasurementNone(
    List<JournalEntity?> entities) {
  List<MeasuredObservation> aggregated = [];

  for (JournalEntity? entity in entities) {
    entity?.maybeMap(
      measurement: (MeasurementEntry entry) {
        aggregated.add(MeasuredObservation(
          entry.data.dateFrom,
          entry.data.value,
        ));
      },
      orElse: () {},
    );
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

DateTime getRangeStart({
  required BuildContext context,
  double scale = 10,
  int daysBack = 0,
}) {
  int durationDays = (MediaQuery.of(context).size.width / scale).ceil();
  final Duration duration = Duration(days: durationDays);
  final DateTime now = DateTime.now();
  final DateTime from = now.subtract(duration);
  return DateTime(from.year, from.month, from.day)
      .subtract(Duration(days: daysBack));
}

DateTime getRangeEnd({int daysBack = 0}) {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 23, 59, 59)
      .subtract(Duration(days: daysBack));
}

String padLeft(num value) {
  return value.toString().padLeft(2, '0');
}

String formatDuration(Duration dur) {
  return '${padLeft(dur.inHours)}:${padLeft(dur.inMinutes.remainder(60))}';
}

String minutesToHhMm(num? minutes) {
  Duration dur = Duration(minutes: minutes?.ceil() ?? 0);
  return formatDuration(dur);
}

String hoursToHhMm(num? hours) {
  int minutes = hours != null ? (hours * 60).ceil() : 0;
  return minutesToHhMm(minutes);
}
