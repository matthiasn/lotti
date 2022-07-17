import 'dart:core';
import 'dart:math';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';

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

String formatHhMm(Duration dur) {
  return '${padLeft(dur.inHours)}:${padLeft(dur.inMinutes.remainder(60))}';
}

String formatHhMmSs(Duration dur) {
  return '${padLeft(dur.inHours)}:'
      '${padLeft(dur.inMinutes.remainder(60))}:'
      '${padLeft(dur.inSeconds.remainder(60))}';
}

Duration durationFromMinutes(num? minutes) {
  final value = minutes ?? 0;
  final seconds = value * 60;
  return Duration(seconds: seconds.floor());
}

String minutesToHhMm(num? minutes) {
  return formatHhMm(durationFromMinutes(minutes));
}

String minutesToHhMmSs(num? minutes) {
  return formatHhMmSs(durationFromMinutes(minutes));
}

String hoursToHhMm(num? hours) {
  final value = hours ?? 0;
  return minutesToHhMm(value * 60);
}

String formatDailyAggregate(
  DashboardWorkoutItem chartConfig,
  Observation selected,
) {
  return chartConfig.displayName.contains('time')
      ? minutesToHhMmSs(selected.value)
      : NumberFormat('#,###').format(selected.value);
}
