import 'package:clock/clock.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// 24h, mono date-time formatting for the relationships surface (design
/// plan §0.5 — "All date/time strings render in `--ff-mono` (Inconsolata)
/// at caption sizes: `Today 14:20`, `Fri 15 Aug 19:05`. Never `Aug 18, 2026
/// 12:44 PM` in body type").
///
/// All formatters here are pure functions of a [DateTime] (and the clock),
/// so they are unit-testable without a widget pump.

/// The mono [TextStyle] for a relationship timestamp: the Inconsolata
/// override on [base], or on the design-system caption token when the
/// caller has no host line to match.
///
/// [base] matters wherever a date sits *inside* a line of prose. The style
/// changes face, tracking and colour and nothing else, so a timestamp in a
/// 16pt sentence stays 16pt — pinning it to the 12pt caption tier dropped
/// the date a size mid-sentence, which is worse than the all-mono line the
/// split replaced.
TextStyle relationshipTimestampStyle(
  DsTokens tokens, {
  Color? color,
  TextStyle? base,
}) => monoMetaStyle(tokens, tokens.colors, base: base, color: color);

/// `HH:mm` in 24h, mono — the time component shared by every relationship
/// timestamp.
String _hhMm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';

/// The short weekday + day + month used when the timestamp is not today
/// (e.g. `Fri 15 Aug`, `Fr. 15 Aug.` in German).
///
/// The abbreviations come from the locale's own date symbols rather than a
/// hard-coded English table: a German reader gets `Fr.`, not `Fri`. The
/// order stays weekday-day-month in every locale, because the design's mono
/// column has to line up.
String _shortDayMonth(DateTime t, String? locale) =>
    DateFormat('E d MMM', locale).format(t);

/// A mono timestamp label for a single point in time, anchored to [now].
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

/// A time-only label in the device's own clock format — `14:20`, or
/// `2:20 PM` where the system prefers twelve hours — for a time whose date
/// is implied: the composer's started chip, the post-call offer, the card's
/// last failed run. Resolved the way `DesignSystemTimeWheel` resolves it, so
/// a chip and the wheel that edits it never disagree.
String relationshipTimeLabelOf(BuildContext context, DateTime at) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(at),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// A mono day label without a time (`Thu 23 Jul`), for a date that is a
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

/// A mono duration read-out for a check-in (`11 min`, `1 h`, `1 h 30`), or
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

/// A mono weekday-only label (`Thu`), used by the cadence due pill, in the
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
/// and the [cadenceDays]. `null` when the person has no cadence.
DateTime? cadenceDueDate({
  required DateTime? lastCheckInAt,
  required DateTime? trackingStartedAt,
  required int? cadenceDays,
  DateTime? now,
}) {
  if (cadenceDays == null || cadenceDays <= 0) return null;
  final anchor = now ?? clock.now();
  final base = lastCheckInAt ?? trackingStartedAt ?? anchor;
  return base.add(Duration(days: cadenceDays));
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
  // days from the due date up to now.
  return _wholeDaysBetween(due, anchor);
}

/// Whole days from [from] to [to], floored (a check-in 6 hours ago is 0
/// days ago, not "today = 1"). Never negative when [from] is before [to].
int _wholeDaysBetween(DateTime from, DateTime to) {
  final fromMidnight = DateTime(from.year, from.month, from.day);
  final toMidnight = DateTime(to.year, to.month, to.day);
  return toMidnight.difference(fromMidnight).inDays;
}

/// A line of prose with a date inside it, where the date — and only the date
/// — wears the mono voice.
///
/// Mono earns its place on a timestamp, which tabulates down a column. It
/// costs measure on the words around one (`Call`, `Weekly`, `last spoke`),
/// and setting a whole line in it is what wrapped `Every two / weeks` onto a
/// ragged second line in the People rail. Splitting the line here keeps the
/// tabular date and gives the prose its proportional face back.
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
            // Same size and weight as the prose around it; only the face,
            // the tracking and nothing else change.
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
