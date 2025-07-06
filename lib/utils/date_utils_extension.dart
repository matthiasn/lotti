import 'package:intl/intl.dart';

extension DateUtilsExtension on DateTime {
  DateTime get dayAtNoon => DateTime(year, month, day, 12);

  DateTime get dayAtMidnight => DateTime(year, month, day);

  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59, 999);

  String get ymd => toIso8601String().substring(0, 10);

  String get md => DateFormat(DateFormat.ABBR_MONTH_DAY).format(this);

  String get ymwd => DateFormat(DateFormat.YEAR_MONTH_WEEKDAY_DAY).format(this);
}
