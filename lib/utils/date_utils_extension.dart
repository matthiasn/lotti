extension DateUtilsExtension on DateTime {
  DateTime get dayAtNoon => DateTime(year, month, day, 12);

  DateTime get dayAtMidnight => DateTime(year, month, day);

  /// Removes the time while retaining whether this value is UTC or local.
  DateTime get dateOnly =>
      isUtc ? DateTime.utc(year, month, day) : DateTime(year, month, day);

  /// Copies this calendar day into the timezone kind used by [reference].
  DateTime dateOnlyInZoneOf(DateTime reference) => reference.isUtc
      ? DateTime.utc(year, month, day)
      : DateTime(year, month, day);

  /// Moves by calendar days without assuming every local day is 24 hours.
  DateTime addCalendarDays(int days) => isUtc
      ? DateTime.utc(
          year,
          month,
          day + days,
          hour,
          minute,
          second,
          millisecond,
          microsecond,
        )
      : DateTime(
          year,
          month,
          day + days,
          hour,
          minute,
          second,
          millisecond,
          microsecond,
        );

  /// Compares calendar components without converting either timezone.
  bool isSameCalendarDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  /// Orders calendar components without converting either timezone.
  int compareCalendarDay(DateTime other) {
    final yearComparison = year.compareTo(other.year);
    if (yearComparison != 0) return yearComparison;
    final monthComparison = month.compareTo(other.month);
    return monthComparison != 0 ? monthComparison : day.compareTo(other.day);
  }

  String get ymd => toIso8601String().substring(0, 10);
}
