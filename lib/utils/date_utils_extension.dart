extension DateUtils on DateTime {
  DateTime get noon => DateTime(year, month, day, 12);

  DateTime get previousMidnight => DateTime(year, month, day);

  String get ymd => toIso8601String().substring(0, 10);
}
