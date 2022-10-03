import 'dart:core';
import 'dart:math';

import 'package:charts_flutter/flutter.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';

class MeasuredObservation extends Equatable {
  const MeasuredObservation(this.dateTime, this.value);

  final DateTime dateTime;
  final num value;

  @override
  String toString() {
    return '$dateTime $value';
  }

  @override
  List<Object?> get props => [dateTime, value];
}

const days = 30;
const defaultChartDuration = Duration(days: days + 1);

String ymd(DateTime day) {
  return day.toIso8601String().substring(0, 10);
}

String ymdh(DateTime dt) {
  final beginningOfHour = DateTime(dt.year, dt.month, dt.day, dt.hour);
  return beginningOfHour.toIso8601String();
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
    // final midDay = day.add(const Duration(hours: 12));
    aggregated.add(MeasuredObservation(day, sumsByDay[dayString] ?? 0));
  }

  return aggregated;
}

List<MeasuredObservation> aggregateSumByHour(
  List<JournalEntity?> entities, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final sumsByHour = <String, num>{};
  final range = rangeEnd.difference(rangeStart);
  final hourStrings = List<String>.generate(range.inHours, (hours) {
    final beginningOfHour = rangeStart.add(Duration(hours: hours));
    return ymdh(beginningOfHour);
  });

  for (final beginningOfHour in hourStrings) {
    sumsByHour[beginningOfHour] = 0;
  }

  for (final entity in entities) {
    final beginningOfHour = ymdh(entity!.meta.dateFrom);
    final n = sumsByHour[beginningOfHour] ?? 0;
    if (entity is MeasurementEntry) {
      sumsByHour[beginningOfHour] = n + entity.data.value;
    }
  }

  final aggregated = <MeasuredObservation>[];
  for (final beginningOfHour in sumsByHour.keys) {
    final dt = DateTime.parse(beginningOfHour);
    aggregated.add(MeasuredObservation(dt, sumsByHour[beginningOfHour] ?? 0));
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

RangeAnnotation<DateTime> chartRangeAnnotation(
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  return RangeAnnotation([
    RangeAnnotationSegment(
      rangeStart.add(const Duration(days: 1)),
      rangeEnd.subtract(const Duration(days: 1)),
      RangeAnnotationAxisType.domain,
      color: Color.transparent,
    )
  ]);
}

RangeAnnotation<DateTime> measurablesChartRangeAnnotation(
  AggregationType aggregationType,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final shortenRange = aggregationType == AggregationType.dailySum ||
      aggregationType == AggregationType.dailyMax;

  return RangeAnnotation([
    RangeAnnotationSegment(
      shortenRange ? rangeStart.add(const Duration(days: 1)) : rangeStart,
      shortenRange ? rangeEnd.subtract(const Duration(days: 1)) : rangeEnd,
      RangeAnnotationAxisType.domain,
      color: Color.transparent,
    )
  ]);
}

final timeSeriesAxis = DateTimeAxisSpec(
  tickProviderSpec: const AutoDateTimeTickProviderSpec(includeTime: false),
  renderSpec: SmallTickRendererSpec(
    labelStyle: TextStyleSpec(
      fontSize: 10,
      color: Color.fromHex(code: colorToCssHex(styleConfig().chartTextColor)),
    ),
  ),
);

final numericRenderSpec = SmallTickRendererSpec<num>(
  labelStyle: TextStyleSpec(
    fontSize: 10,
    color: Color.fromHex(code: colorToCssHex(styleConfig().chartTextColor)),
  ),
);

final SeriesRendererConfig<DateTime> defaultBarRenderer =
    BarRendererConfig<DateTime>(
  cornerStrategy: const NoCornerStrategy(),
  layoutPaintOrder: 3,
);

final SeriesRendererConfig<DateTime> defaultLineRenderer =
    LineRendererConfig<DateTime>(layoutPaintOrder: 4);

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
  return DateTime(now.year, now.month, now.day + 1)
      .subtract(Duration(days: shiftDays));
}

DateTime getEndOfToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 23, 59, 59);
}

DateTime getStartOfDay(DateTime dt) {
  return DateTime(dt.year, dt.month, dt.day);
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
