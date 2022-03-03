import 'dart:core';

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';

List<Observation> aggregateStoryDailyTimeSum(
  List<JournalEntity?> entities,
  DashboardStoryTimeItem chartConfig,
) {
  Map<String, num> timeSumsByDay = {};

  List<Observation> aggregated = [];
  for (final dayString in timeSumsByDay.keys) {
    DateTime day = DateTime.parse(dayString);
    aggregated.add(Observation(day, timeSumsByDay[dayString] ?? 0));
  }

  return aggregated;
}
