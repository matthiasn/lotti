import 'package:clock/clock.dart';
import 'package:intl/intl.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Whether [a] and [b] fall on the same local day.
bool frontChatSameDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

/// The day of [at] in the companion's chat: today and yesterday by name,
/// every other day by date in [locale].
String frontChatDayLabel(BuildContext context, DateTime at, String locale) {
  final day = at.toLocal();
  final today = clock.now().toLocal();
  if (frontChatSameDay(day, today)) return context.messages.calendarTodayLabel;
  // The calendar's day before, not 24 hours before: a day that loses or
  // gains an hour to daylight saving is still one day.
  if (frontChatSameDay(day, DateTime(today.year, today.month, today.day - 1))) {
    return context.messages.frontChatYesterday;
  }
  return DateFormat.yMMMMEEEEd(locale).format(day);
}
