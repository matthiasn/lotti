import 'dart:core';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:jiffy/jiffy.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:week_of_year/week_of_year.dart';

enum AggregationTimeframe {
  daily,
  weekly,
}

List<String> daysInEntryRange(
  DateTime dateFrom,
  DateTime dateTo,
) {
  final start = Jiffy.parseFromDateTime(dateFrom).startOf(Unit.day).dateTime;
  final end = Jiffy.parseFromDateTime(dateTo).endOf(Unit.day).dateTime.add(
        const Duration(days: 1),
      );
  return daysInRange(rangeStart: start, rangeEnd: end);
}

DateTimeRange? overlappingRange(DateTimeRange a, DateTimeRange b) {
  final start = DateTime.fromMillisecondsSinceEpoch(
    max(a.start.millisecondsSinceEpoch, b.start.millisecondsSinceEpoch),
  );
  final end = DateTime.fromMillisecondsSinceEpoch(
    min(a.end.millisecondsSinceEpoch, b.end.millisecondsSinceEpoch),
  );

  if (end.isBefore(start)) {
    return null;
  }

  return DateTimeRange(start: start, end: end);
}

Map<String, num> durationsByDayInRange(
  DateTime? dateFrom,
  DateTime? dateTo,
) {
  final minutesByDay = <String, num>{};

  if (dateFrom == null || dateTo == null) {
    return {};
  }
  for (final dayString in daysInEntryRange(dateFrom, dateTo)) {
    final day = DateTime.parse(dayString);

    final byDay = overlappingRange(
      DateTimeRange(
        start: dateFrom,
        end: dateTo,
      ),
      DateTimeRange(
        start: day,
        end: day.add(const Duration(days: 1)),
      ),
    );

    if (byDay != null) {
      final n = minutesByDay[dayString] ?? 0;
      minutesByDay[dayString] = n + byDay.duration.inSeconds / 60;
    }
  }

  return minutesByDay;
}

List<Observation> aggregateStoryDailyTimeSum(
  List<JournalEntity> entities, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final minutesByDay = <String, num>{};
  final dayStrings = daysInRange(rangeStart: rangeStart, rangeEnd: rangeEnd);
  final days = dayStrings.toSet();

  for (final dayString in dayStrings) {
    minutesByDay[dayString] = 0;
  }

  for (final entity in entities) {
    durationsByDayInRange(
      entity.meta.dateFrom,
      entity.meta.dateTo,
    ).forEach((dayString, minutes) {
      if (days.contains(dayString)) {
        final n = minutesByDay[dayString] ?? 0;
        minutesByDay[dayString] = n + minutes;
      }
    });
  }

  final aggregated = <Observation>[];

  for (final dayString in minutesByDay.keys) {
    final day = DateTime.parse(dayString);
    aggregated.add(Observation(day, minutesByDay[dayString] ?? 0));
  }

  return aggregated;
}

class WeeklyAggregate extends Equatable {
  const WeeklyAggregate(this.isoWeek, this.value);

  final String isoWeek;
  final num value;

  @override
  String toString() {
    return '$isoWeek $value';
  }

  @override
  List<Object?> get props => [isoWeek, value];
}

List<WeeklyAggregate> aggregateStoryWeeklyTimeSum(
  List<JournalEntity> entities, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final minutesByWeek = <String, num>{};

  aggregateStoryDailyTimeSum(
    entities,
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
  ).forEach((byDay) {
    final year = byDay.dateTime.year;
    final weekOfYear = byDay.dateTime.weekOfYear;
    final isoWeek = '$year-W${padLeft(weekOfYear)}';
    final prev = minutesByWeek[isoWeek] ?? 0;
    minutesByWeek[isoWeek] = prev + byDay.value;
  });

  final aggregated = <WeeklyAggregate>[];
  minutesByWeek.forEach((isoWeek, value) {
    aggregated.add(WeeklyAggregate(isoWeek, value));
  });

  return aggregated;
}

List<Observation> aggregateStoryTimeSum(
  List<JournalEntity> entities, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
  required AggregationTimeframe timeframe,
}) {
  aggregateStoryWeeklyTimeSum(
    entities,
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
  );

  return aggregateStoryDailyTimeSum(
    entities,
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
  );
}
