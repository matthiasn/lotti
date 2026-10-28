import 'package:intl/intl.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// When a visit happened, as a history row says it: `Today, 3:45 PM`,
/// `Yesterday, 3:45 PM`, `Mar 12, 3:45 PM` earlier this year and
/// `Mar 12, 2025, 3:45 PM` before it — each in the locale's own date order and
/// clock (`15:45` where the day has 24 hours). The year is left out while it
/// is the current one, so the label fits a phone row.
///
/// Days are compared on the calendar, so a visit just before midnight reads
/// as yesterday however few hours ago it was, and a DST change in between
/// moves nothing.
String historyTimestampLabel(
  DateTime at, {
  required DateTime now,
  required AppLocalizations messages,
  String? locale,
}) {
  final time = DateFormat.jm(locale).format(at);
  final day = DateTime(at.year, at.month, at.day);
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) return messages.historyTimestampToday(time);
  if (day == DateTime(now.year, now.month, now.day - 1)) {
    return messages.historyTimestampYesterday(time);
  }
  final date = at.year == now.year
      ? DateFormat.MMMd(locale)
      : DateFormat.yMMMd(locale);
  return date.add_jm().format(at);
}
