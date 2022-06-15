import 'dart:core';
import 'dart:math';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/widgets.dart';
import 'package:lotti/classes/journal_entities.dart';

class MeasuredObservation {
  MeasuredObservation(this.dateTime, this.value);

  final DateTime dateTime;
  final num value;

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
  final sumsByDay = <String, num>{};
  final range = rangeEnd.difference(rangeStart);
  final dayStrings = List<String>.generate(range.inDays, (days) {
    final day = rangeStart.add(Duration(days: days));
    return ymd(day);
  });

  for (final dayString in dayStrings) {
    sumsByDay[dayString] = 0;
  }

  for (final entity in entities) {
    final dayString = ymd(entity!.meta.dateFrom);
    final n = sumsByDay[dayString] ?? 0;
    if (entity is MeasurementEntry) {
      sumsByDay[dayString] = n + entity.data.value;
    }
  }

  final aggregated = <MeasuredObservation>[];
  for (final dayString in sumsByDay.keys) {
    final day = DateTime.parse(dayString);
    aggregated.add(MeasuredObservation(day, sumsByDay[dayString] ?? 0));
  }

  return aggregated;
}

List<MeasuredObservation> aggregateMaxByDay(
  List<JournalEntity?> entities, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final sumsByDay = <String, num>{};

  final range = rangeEnd.difference(rangeStart);
  final dayStrings = List<String>.generate(range.inDays, (days) {
    final day = rangeStart.add(Duration(days: days));
    return ymd(day);
  });

  for (final dayString in dayStrings) {
    sumsByDay[dayString] = 0;
  }

  for (final entity in entities) {
    final dayString = ymd(entity!.meta.dateFrom);
    final n = sumsByDay[dayString] ?? 0;
    if (entity is MeasurementEntry) {
      sumsByDay[dayString] = max(n, entity.data.value);
    }
  }

  final aggregated = <MeasuredObservation>[];
  for (final dayString in sumsByDay.keys) {
    final day = DateTime.parse(dayString);
    aggregated.add(MeasuredObservation(day, sumsByDay[dayString] ?? 0));
  }

  return aggregated;
}

List<MeasuredObservation> aggregateMeasurementNone(
  List<JournalEntity?> entities,
) {
  final aggregated = <MeasuredObservation>[];

  for (final entity in entities) {
    entity?.maybeMap(
      measurement: (MeasurementEntry entry) {
        aggregated.add(
          MeasuredObservation(
            entry.data.dateFrom,
            entry.data.value,
          ),
        );
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
  ),
);

DateTime getRangeStart({
  required BuildContext context,
  double scale = 10,
  int shiftDays = 0,
}) {
  final durationDays = (MediaQuery.of(context).size.width / scale).ceil();
  final duration = Duration(days: durationDays);
  final now = DateTime.now();
  final from = now.subtract(duration);
  return DateTime(from.year, from.month, from.day)
      .subtract(Duration(days: shiftDays));
}

DateTime getRangeEnd({int shiftDays = 0}) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 23, 59, 59)
      .subtract(Duration(days: shiftDays));
}

String padLeft(num value) {
  return value.toString().padLeft(2, '0');
}

String formatDuration(Duration dur) {
  return '${padLeft(dur.inHours)}:${padLeft(dur.inMinutes.remainder(60))}';
}

String minutesToHhMm(num? minutes) {
  final dur = Duration(minutes: minutes?.ceil() ?? 0);
  return formatDuration(dur);
}

String hoursToHhMm(num? hours) {
  final minutes = hours != null ? (hours * 60).ceil() : 0;
  return minutesToHhMm(minutes);
}
