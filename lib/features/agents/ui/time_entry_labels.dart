import 'package:clock/clock.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/time_entry_datetime.dart';

/// The two ends of a proposed time entry as a reader sees them.
///
/// A proposal's `startTime` / `endTime` are local wall-clock timestamps, and
/// the day is as much a part of the proposal as the hour: an agent asked to
/// log "last Wednesday" proposes sessions that are not today's, and a row
/// that names only `09:00–12:30` cannot be checked against anything.
///
/// Each end is `null` when its argument is absent (not a string), the
/// argument verbatim when it is present but not an accepted timestamp — what
/// the model actually asked for is still evidence — and otherwise:
///
/// - start: the day and the time, [timeEntryMomentLabel].
/// - end: the time alone when it falls on the start's calendar day, so a
///   same-day session reads `Wed, Jul 8, 09:00–12:30` rather than repeating
///   the day; the day and the time when it does not (a session across
///   midnight) or when there is no parsed start to share a day with.
///
/// `endNamesDay` says which of the two the end is, because a range between
/// two ends that each carry words wants more air around its dash than
/// `09:00–12:30` does.
({String? start, String? end, bool endNamesDay}) timeEntryRangeLabels(
  String locale, {
  required Object? startTime,
  required Object? endTime,
}) {
  final start = startTime is String
      ? parseTimeEntryLocalDateTime(startTime)
      : null;
  final end = endTime is String ? parseTimeEntryLocalDateTime(endTime) : null;

  final String? startLabel;
  if (startTime is! String) {
    startLabel = null;
  } else if (start == null) {
    startLabel = startTime;
  } else {
    startLabel = timeEntryMomentLabel(locale, start);
  }

  final String? endLabel;
  var endNamesDay = false;
  if (endTime is! String) {
    endLabel = null;
  } else if (end == null) {
    endLabel = endTime;
  } else if (start != null && _isSameDay(start, end)) {
    endLabel = DateFormat.Hm(locale).format(end);
  } else {
    endLabel = timeEntryMomentLabel(locale, end);
    endNamesDay = true;
  }

  return (start: startLabel, end: endLabel, endNamesDay: endNamesDay);
}

/// A wall-clock moment with its day, in [locale]'s own date format:
/// `Wed, Jul 8, 09:00` in English, `Mi., 8. Juli, 09:00` in German,
/// `ons. 8. jul. 09.00` in Danish.
///
/// The weekday leads because that is how a session is asked for ("last
/// Wednesday"). The year appears only when it is not the current one, where
/// leaving it out would name the wrong day. Day and time are joined the way
/// the locale joins them — its CLDR medium date-time pattern, `{1}, {0}` or
/// `{1} {0}` — rather than by a separator chosen here.
///
/// The day is one unbreakable unit: its spaces are no-break spaces, so a
/// narrow row wraps before or after `Wed, Jul 8`, never inside it — a line
/// ending on `Wed,` or on German's `8.` reads as a different thing.
String timeEntryMomentLabel(String locale, DateTime at) {
  final day = at.year == clock.now().year
      ? DateFormat.MMMEd(locale)
      : DateFormat.yMMMEd(locale);
  return day.dateSymbols.DATETIMEFORMATS[_mediumDateTime]
      .replaceFirst('{1}', day.format(at).replaceAll(' ', _noBreakSpace))
      .replaceFirst('{0}', DateFormat.Hm(locale).format(at));
}

const _noBreakSpace = '\u00A0';

/// Index of the medium pattern in `DateSymbols.DATETIMEFORMATS`, which runs
/// full, long, medium, short.
const _mediumDateTime = 2;

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
