import 'dart:core';

import 'package:lotti/classes/journal_entities.dart';

class SumPerDay {
  final DateTime day;
  final num sum;
  SumPerDay(this.day, this.sum);

  @override
  String toString() {
    return '$day $sum';
  }
}

const days = 15;
const duration = Duration(days: days + 1);

List<SumPerDay> aggregateByDay(List<JournalEntity?> entities) {
  List<String> dayStrings = [];
  Map<String, num> sumsByDay = {};
  DateTime now = DateTime.now();

  String ymd(DateTime day) {
    return day.toIso8601String().substring(0, 10);
  }

  for (int i = days; i >= 0; i--) {
    DateTime day = now.subtract(Duration(days: i));
    String dayString = ymd(day);
    dayStrings.add(dayString);
    sumsByDay[dayString] = 0;
  }

  for (final entity in entities) {
    String dayString = ymd(entity!.meta.dateFrom);
    num n = sumsByDay[dayString] ?? 0;
    if (entity is MeasurementEntry) {
      sumsByDay[dayString] = n + entity.data.value;
    }
  }

  List<SumPerDay> aggregated = [];
  for (final dayString in dayStrings) {
    DateTime day = DateTime.parse(dayString);
    aggregated.add(SumPerDay(day, sumsByDay[dayString] ?? 0));
  }

  return aggregated;
}
