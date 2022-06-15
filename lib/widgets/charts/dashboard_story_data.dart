import 'dart:core';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

List<Observation> aggregateStoryDailyTimeSum(
  List<JournalEntity?> entities, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) {
  final minutesByDay = <String, num>{};

  final range = rangeEnd.difference(rangeStart);
  final dayStrings = List<String>.generate(range.inDays, (days) {
    final day = rangeStart.add(Duration(days: days));
    return ymd(day);
  });

  for (final dayString in dayStrings) {
    minutesByDay[dayString] = 0;
  }

  for (final entity in entities) {
    final dayString = ymd(entity!.meta.dateFrom);
    final n = minutesByDay[dayString] ?? 0;
    final duration =
        entity.meta.dateTo.difference(entity.meta.dateFrom).inSeconds / 60;
    minutesByDay[dayString] = n + duration;
  }

  final aggregated = <Observation>[];
  for (final dayString in minutesByDay.keys) {
    final day = DateTime.parse(dayString);
    aggregated.add(Observation(day, minutesByDay[dayString] ?? 0));
  }

  return aggregated;
}
