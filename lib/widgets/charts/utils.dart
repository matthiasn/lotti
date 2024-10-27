import 'dart:collection';
import 'dart:core';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/date_utils_extension.dart';

class Observation extends Equatable {
  const Observation(this.dateTime, this.value);

  final DateTime dateTime;
  final num value;

  @override
  String toString() {
    return '$dateTime $value';
  }

  @override
  List<Object?> get props => [dateTime, value];
}

String ymdh(DateTime dt) {
  final beginningOfHour = DateTime(dt.year, dt.month, dt.day, dt.hour);
  return beginningOfHour.toIso8601String();
}

List<Observation> aggregateSumByDay(
  List<JournalEntity> entities, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final sumsByDay = <String, num>{};
  final range = rangeEnd.difference(rangeStart);
  final dayStrings = getDayStrings(range.inDays, rangeStart);

  for (final dayString in dayStrings) {
    sumsByDay[dayString] = 0;
  }

  for (final entity in entities) {
    final dayString = entity.meta.dateFrom.ymd;
    final n = sumsByDay[dayString] ?? 0;
    if (entity is MeasurementEntry) {
      sumsByDay[dayString] = n + entity.data.value;
    }
  }

  final aggregated = <Observation>[];
  for (final dayString in sumsByDay.keys) {
    final day = DateTime.parse(dayString);
    // final midDay = day.add(const Duration(hours: 12));
    aggregated.add(Observation(day, sumsByDay[dayString] ?? 0));
  }

  return aggregated;
}

String chartDateFormatter(String ymd) {
  if (ymd.isEmpty) {
    return '';
  }

  final day = DateTime.parse(ymd);
  return DateFormat('MMM dd').format(day);
}

String chartDateFormatterMmDd(num millis) {
  final day = DateTime.fromMillisecondsSinceEpoch(millis.toInt());
  return DateFormat('MMM dd').format(day);
}

String chartDateFormatterYMD(num millis) {
  final day = DateTime.fromMillisecondsSinceEpoch(millis.toInt());
  return DateFormat.yMMMd().format(day);
}

String chartDateFormatterFull(num millis) {
  final day = DateTime.fromMillisecondsSinceEpoch(millis.toInt());
  return DateFormat('MMM dd, HH:mm').format(day);
}

List<Observation> aggregateSumByHour(
  List<JournalEntity> entities, {
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
    final beginningOfHour = ymdh(entity.meta.dateFrom);
    final n = sumsByHour[beginningOfHour] ?? 0;
    if (entity is MeasurementEntry) {
      sumsByHour[beginningOfHour] = n + entity.data.value;
    }
  }

  final aggregated = <Observation>[];
  for (final beginningOfHour in sumsByHour.keys) {
    final dt = DateTime.parse(beginningOfHour);
    aggregated.add(Observation(dt, sumsByHour[beginningOfHour] ?? 0));
  }

  return aggregated;
}

List<String> getDayStrings(int rangeDays, DateTime rangeStart) {
  return List<String>.generate(rangeDays, (days) {
    final day = rangeStart.add(Duration(days: days));
    return day.ymd;
  });
}

List<String> daysInRange({
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final range = rangeEnd.difference(rangeStart);
  return LinkedHashSet<String>.from(
    getDayStrings(range.inDays + 1, rangeStart),
  ).toList();
}

List<Observation> aggregateMaxByDay(
  List<JournalEntity> entities, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final sumsByDay = <String, num>{};

  final range = rangeEnd.difference(rangeStart);
  final dayStrings = getDayStrings(range.inDays, rangeStart);

  for (final dayString in dayStrings) {
    sumsByDay[dayString] = 0;
  }

  for (final entity in entities) {
    final dayString = entity.meta.dateFrom.ymd;
    final n = sumsByDay[dayString] ?? 0;
    if (entity is MeasurementEntry) {
      sumsByDay[dayString] = max(n, entity.data.value);
    }
  }

  final aggregated = <Observation>[];
  for (final dayString in sumsByDay.keys) {
    final day = DateTime.parse(dayString);
    aggregated.add(Observation(day, sumsByDay[dayString] ?? 0));
  }

  return aggregated;
}

List<Observation> aggregateMeasurementNone(
  List<JournalEntity> entities,
) {
  final aggregated = <Observation>[];

  for (final entity in entities) {
    entity.maybeMap(
      measurement: (MeasurementEntry entry) {
        aggregated.add(
          Observation(
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

int minutesSinceMidnight(DateTime? dt) {
  final hoursPastMidnight = dt?.hour ?? 0;
  return hoursPastMidnight * 60 + (dt?.minute ?? 0);
}

bool showHabit(HabitDefinition item) {
  final showFrom = item.habitSchedule.mapOrNull(daily: (d) => d.showFrom);
  final showFromMinuteOfDay = minutesSinceMidnight(showFrom);
  final actualMinuteOfDay = minutesSinceMidnight(DateTime.now());
  return actualMinuteOfDay >= showFromMinuteOfDay;
}

int habitSorter(HabitDefinition a, HabitDefinition b) {
  return <Comparator<HabitDefinition>>[
    (o1, o2) {
      final prio1 = o1.priority ?? false ? 1 : 0;
      final prio2 = o2.priority ?? false ? 1 : 0;
      return prio2.compareTo(prio1);
    },
    (o1, o2) {
      final showFrom1 = o1.habitSchedule.mapOrNull(daily: (d) => d.showFrom) ??
          getEndOfToday();
      final showFrom2 = o2.habitSchedule.mapOrNull(daily: (d) => d.showFrom) ??
          getEndOfToday();

      return minutesSinceMidnight(showFrom1)
          .compareTo(minutesSinceMidnight(showFrom2));
    },
    (o1, o2) => o1.name.compareTo(o2.name),
  ].map((e) => e(a, b)).firstWhere(
        (e) => e != 0,
        orElse: () => 0,
      );
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
