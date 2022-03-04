import 'dart:core';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

List<Observation> aggregateStoryDailyTimeSum(
  List<JournalEntity?> entities, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  Map<String, num> hoursByDay = {};

  Duration range = rangeEnd.difference(rangeStart);
  List<String> dayStrings = List<String>.generate(range.inDays, (days) {
    DateTime day = rangeStart.add(Duration(days: days));
    return ymd(day);
  });

  for (final dayString in dayStrings) {
    hoursByDay[dayString] = 0;
  }

  for (final entity in entities) {
    String dayString = ymd(entity!.meta.dateFrom);
    num n = hoursByDay[dayString] ?? 0;
    num duration =
        entity.meta.dateTo.difference(entity.meta.dateFrom).inSeconds / 3600;
    hoursByDay[dayString] = n + duration;
  }

  List<Observation> aggregated = [];
  for (final dayString in hoursByDay.keys) {
    DateTime day = DateTime.parse(dayString);
    aggregated.add(Observation(day, hoursByDay[dayString] ?? 0));
  }

  return aggregated;
}
