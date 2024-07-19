extension DateUtils on DateTime {
  DateTime get dayAtNoon => DateTime(year, month, day, 12);

  DateTime get dayAtMidnight => DateTime(year, month, day);

  String get ymd => toIso8601String().substring(0, 10);
}
