import 'package:clock/clock.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/relationship_calendar.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;
import 'package:material_ui/material_ui.dart';

/// 24h date-time formatting for the relationships surface: `Today 14:20`,
/// `Fri 15 Aug 19:05`, never `Aug 18, 2026 12:44 PM` in body type. The
/// design plan (§0.5) first set every one of these in Inconsolata; that was
/// the single most foreign thing on the feature — a monospace face spliced
/// into Inter sentences, where the journal and the task timer keep the UI
/// face and stabilise the digits with tabular figures. The dates now do
/// the same, the recorder's running clock included.
///
/// All formatters here are pure functions of a [DateTime] (and the clock),
/// so they are unit-testable without a widget pump.

/// The [TextStyle] for a relationship timestamp: [base], or the
/// design-system caption token when the caller has no host line to match,
/// with the app's tabular-figure features (`numericBadgeFontFeatures`, the
/// journal's and the timer's) so a column of dates lines up digit for digit.
///
/// [base] matters wherever a date sits *inside* a line of prose. The style
/// changes figures and colour and nothing else, so a timestamp in a 16pt
/// sentence stays 16pt — pinning it to the 12pt caption tier dropped the
/// date a size mid-sentence.
TextStyle relationshipTimestampStyle(
  DsTokens tokens, {
  Color? color,
  TextStyle? base,
}) => (base ?? tokens.typography.styles.others.caption).copyWith(
  fontFeatures: numericBadgeFontFeatures,
  color: color ?? tokens.colors.text.lowEmphasis,
);

/// `HH:mm` in 24h — the time component shared by every relationship
/// timestamp.
String _hhMm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';

/// The short weekday + day + month used when the timestamp is not today
/// (e.g. `Fri 15 Aug`, `Fr. 15 Aug.` in German).
///
/// The abbreviations come from the locale's own date symbols rather than a
/// hard-coded English table: a German reader gets `Fr.`, not `Fri`. The
/// order stays weekday-day-month in every locale, because the dates' tabular
/// column has to line up.
String _shortDayMonth(DateTime t, String? locale) =>
    DateFormat('E d MMM', locale).format(t);

/// A timestamp label for a single point in time, anchored to [now].
///
/// Same day → `Today 14:20`. The day before → `Yesterday 19:05`. Otherwise →
/// `Fri 15 Aug 19:05`.
///
/// "Yesterday" earns its own case because it is the single most common
/// non-today value on this surface — a check-in logged the previous evening
/// reads as `Yesterday 18:00` rather than making the reader decode
/// `Wed 12 Aug 18:00` against today's date.
///
/// The two relative words arrive as [todayLabel] and [yesterdayLabel] and
/// the date symbols follow [locale], so the function stays a pure function
/// of its inputs — [relationshipTimestampLabelOf] is the widget-side
/// convenience that reads both off a [BuildContext].
String relationshipTimestampLabel(
  DateTime at, {
  required String todayLabel,
  required String yesterdayLabel,
  String? locale,
  DateTime? now,
}) {
  final anchor = now ?? clock.now();
  if (_isSameDay(at, anchor)) return '$todayLabel ${_hhMm(at)}';
  if (_isSameDay(at, _dayBefore(anchor))) {
    return '$yesterdayLabel ${_hhMm(at)}';
  }
  return '${_shortDayMonth(at, locale)} ${_hhMm(at)}';
}

/// [relationshipTimestampLabel] with the relative words and the date symbols
/// resolved against the widget tree's locale.
String relationshipTimestampLabelOf(
  BuildContext context,
  DateTime at, {
  DateTime? now,
}) => relationshipTimestampLabel(
  at,
  todayLabel: context.messages.relationshipTimestampToday,
  yesterdayLabel: context.messages.relationshipTimestampYesterday,
  locale: Localizations.localeOf(context).toString(),
  now: now,
);

/// The calendar day before [anchor]. Built from components rather than by
/// subtracting a `Duration`, so the 23- and 25-hour days either side of a DST
/// change still resolve to the previous date.
DateTime _dayBefore(DateTime anchor) =>
    DateTime(anchor.year, anchor.month, anchor.day - 1);

/// A time-only label in the feature's 24h clock — `14:20` — for a time whose
/// date is implied, a pure function of the time (no context: nothing about
/// the device or locale changes it): the composer's started chip, the post-call offer, the
/// card's last failed run. The same `HH:mm` every other People timestamp
/// ends in, so a chip reading `Sat 1 Aug · 12:44` and the note stamp
/// beneath it reading `Sat 1 Aug 12:44` agree. It used to follow the
/// device's clock format like the time wheel does, and on a twelve-hour
/// device the check-in page spoke two dialects a few lines apart; the wheel
/// is a transient editor, the page is what the user reads.
String relationshipTimeLabel(DateTime at) => _hhMm(at);

/// A day label without a time (`Thu 23 Jul`), for a date that is a
/// deadline rather than an event — the summary card's next due day, the
/// row's `first due` note.
String relationshipDayLabel(DateTime at, {String? locale}) =>
    _shortDayMonth(at, locale);

/// [relationshipDayLabel] resolved against the widget tree's locale.
String relationshipDayLabelOf(BuildContext context, DateTime at) =>
    relationshipDayLabel(
      at,
      locale: Localizations.localeOf(context).toString(),
    );

/// A duration read-out for a check-in (`11 min`, `1 h`, `1 h 30`), or
/// null for a check-in that has no duration — a message usually has none,
/// and the row must then say nothing rather than `0 min`.
String? relationshipDurationLabelOf(BuildContext context, Duration duration) {
  final minutes = duration.inMinutes;
  // Under a minute is not a duration worth a label — and never "0 min".
  if (minutes <= 0) return null;
  final messages = context.messages;
  if (minutes < 60) return messages.relationshipDurationMinutes(minutes);
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return messages.relationshipDurationHours(hours);
  return messages.relationshipDurationHoursMinutes(
    hours,
    rest.toString().padLeft(2, '0'),
  );
}

/// A weekday-only label (`Thu`), used by the cadence due pill, in the
/// locale's own abbreviation.
String relationshipWeekdayLabel(DateTime at, {String? locale}) =>
    DateFormat.E(locale).format(at);

/// [relationshipWeekdayLabel] resolved against the widget tree's locale.
String relationshipWeekdayLabelOf(BuildContext context, DateTime at) =>
    relationshipWeekdayLabel(
      at,
      locale: Localizations.localeOf(context).toString(),
    );

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The cadence due date: the next date by which a check-in should land,
/// given the [lastCheckInAt] (or [trackingStartedAt] when none exists yet)
/// and the [cadenceDays], as local midnight of that calendar day. `null`
/// when the person has no cadence.
///
/// The same day the agent derives (`deriveCadenceFacts`): the stamp's own
/// calendar day plus the cadence, counted on the calendar
/// ([relationshipDueDay]) rather than by adding twenty-four hours per day,
/// which drifts across a DST transition and can land on the wrong date. A
/// day with no time of day, so two people due the same day compare equal.
DateTime? cadenceDueDate({
  required DateTime? lastCheckInAt,
  required DateTime? trackingStartedAt,
  required int? cadenceDays,
  DateTime? now,
}) {
  if (cadenceDays == null || cadenceDays <= 0) return null;
  final anchor = now ?? clock.now();
  final base = lastCheckInAt ?? trackingStartedAt ?? anchor;
  final due = relationshipDueDay(base, cadenceDays);
  return DateTime(due.year, due.month, due.day);
}

/// Whole days between the cadence due date and [now]. Positive when the
/// cadence is overdue (due in the past), negative when it is still ahead.
/// `null` when there is no cadence.
int? cadenceOverdueDays({
  required DateTime? lastCheckInAt,
  required DateTime? trackingStartedAt,
  required int? cadenceDays,
  DateTime? now,
}) {
  final due = cadenceDueDate(
    lastCheckInAt: lastCheckInAt,
    trackingStartedAt: trackingStartedAt,
    cadenceDays: cadenceDays,
    now: now,
  );
  if (due == null) return null;
  final anchor = now ?? clock.now();
  // Positive when the cadence is overdue (the due date is in the past): the
  // calendar days from the due day up to today. Day keys, not a difference
  // of local midnights: the 23-hour day of a spring-forward counts as one
  // day, where a floored `Duration` made it zero and read "due today" for a
  // person a day over.
  return relationshipCalendarDaysBetween(due, anchor);
}

/// A line of prose with a date inside it, where the date — and only the date
/// — wears the timestamp style.
///
/// Tabular figures earn their place on a timestamp, which lines up down a
/// column; the words around one (`Call`, `Weekly`, `last spoke`) keep the
/// line's own style. The split is kept so the two parts can still differ —
/// the date once wore a monospace face, which is what wrapped `Every two /
/// weeks` onto a ragged second line in the People rail.
///
/// [date] is located by searching [text] for its own substring rather than
/// by index, because each line is assembled from one catalog message and a
/// locale is free to put the date first, last or in the middle. A [date]
/// that is null — or that does not occur in [text] — renders the whole line
/// in [style], so a missing match degrades to the plain line rather than to
/// a wrong one.
class RelationshipLineWithDate extends StatelessWidget {
  const RelationshipLineWithDate({
    required this.text,
    required this.date,
    required this.style,
    this.maxLines,
    super.key,
  });

  /// The whole assembled line, including [date].
  final String text;

  /// The date substring inside [text], or null when the line carries none.
  final String? date;

  /// The proportional style for the line; the date inherits its colour.
  final TextStyle style;

  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final at = date == null ? -1 : text.indexOf(date!);
    if (at < 0) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: style,
      );
    }
    final match = date!;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          if (at > 0) TextSpan(text: text.substring(0, at)),
          TextSpan(
            text: match,
            // Same size and weight as the prose around it; only the figures
            // change.
            style: relationshipTimestampStyle(
              tokens,
              base: style,
              color: style.color,
            ),
          ),
          if (at + match.length < text.length)
            TextSpan(text: text.substring(at + match.length)),
        ],
      ),
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
    );
  }
}
