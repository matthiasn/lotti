import 'dart:core';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:jiffy/jiffy.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/widgets/charts/utils.dart';

enum AggregationTimeframe {
  daily,
  weekly,
}

List<String> daysInRange(DateTime rangeStart, DateTime rangeEnd) {
  final range = rangeEnd.difference(rangeStart);
  return List<String>.generate(range.inDays, (days) {
    final day = rangeStart.add(Duration(days: days));
    return ymd(day);
  });
}

List<String> daysInEntryRange(
  DateTime? dateFrom,
  DateTime? dateTo,
) {
  final start = Jiffy(dateFrom).startOf(Units.DAY).dateTime;
  final end = Jiffy(dateTo).endOf(Units.DAY).dateTime.add(
        const Duration(days: 1),
      );
  return daysInRange(start, end);
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

List<MeasuredObservation> aggregateStoryDailyTimeSum(
  List<JournalEntity?> entities, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final minutesByDay = <String, num>{};
  final dayStrings = daysInRange(rangeStart, rangeEnd);
  final days = dayStrings.toSet();

  for (final dayString in dayStrings) {
    minutesByDay[dayString] = 0;
  }

  for (final entity in entities) {
    durationsByDayInRange(
      entity?.meta.dateFrom,
      entity?.meta.dateTo,
    ).forEach((dayString, minutes) {
      if (days.contains(dayString)) {
        final n = minutesByDay[dayString] ?? 0;
        minutesByDay[dayString] = n + minutes;
      }
    });
  }

  final aggregated = <MeasuredObservation>[];

  for (final dayString in minutesByDay.keys) {
    final day = DateTime.parse(dayString);
    aggregated.add(MeasuredObservation(day, minutesByDay[dayString] ?? 0));
  }

  return aggregated;
}

List<MeasuredObservation> aggregateStoryTimeSum(
  List<JournalEntity?> entities, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
  required AggregationTimeframe timeframe,
}) {
  switch (timeframe) {
    case AggregationTimeframe.daily:
      return aggregateStoryDailyTimeSum(
        entities,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
    case AggregationTimeframe.weekly:
      return aggregateStoryDailyTimeSum(
        entities,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
  }
}
