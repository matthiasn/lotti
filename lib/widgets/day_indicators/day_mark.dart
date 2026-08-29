import 'package:flutter/foundation.dart';

/// What the app measured for one day.
///
/// [full] means the requirement held as of that day; [partial] means the user
/// did everything within their control (the routine was kept) while a window
/// target was still building — rendered as a lighter wash of the same success
/// hue. [skipped] and [missed] are recorded outcomes a habit day can carry:
/// deciding a day was missed and never looking at it are different facts, so
/// [missed] is never the neutral grey of [none].
enum DayMarkState { none, partial, full, skipped, missed }

/// How a day turned out, in the user's own judgement.
///
/// [improving] is the case a three-way verdict could not express: some of it
/// was missed, but the day moved the right way. Without it a day like that
/// had to be filed as [mixed] alongside days that simply stalled, and a strip
/// could not show "not perfect, but on the right track".
///
/// Ordered best to worst. Persisted by `name`, so the order is free to change
/// but the names are not.
enum DayVerdict { met, improving, mixed, missed }

/// Whether the user rated the day directly or accepted the deterministic
/// suggestion derived from the day's own evidence.
enum DayVerdictProvenance { ratedByUser, suggestedAndAccepted }

/// One day on a day-indicator surface: the measured [state], the user's
/// [verdict] where one was recorded, and whether the day is still open.
///
/// A recorded verdict outranks the measured state wherever both are shown. The
/// measurement is evidence about a day; the reflection is the user's ruling on
/// it, and a cell that kept showing grey after they filed the day as missed
/// would be contradicting them.
@immutable
class DayMark {
  const DayMark({
    required this.state,
    this.day,
    this.verdict,
    this.verdictProvenance,
    this.isToday = false,
  });

  /// The calendar day, at midnight UTC. Null on an undated strip — a loading
  /// placeholder row, or a figure whose cells carry no dates and therefore no
  /// weekday letters.
  final DateTime? day;

  final DayMarkState state;
  final DayVerdict? verdict;
  final DayVerdictProvenance? verdictProvenance;

  /// Whether the mark stands for the current day. An empty today is drawn as
  /// "not yet" — the dashed unresolved outline — rather than as the neutral
  /// fill a past day nobody kept wears, so a streak that is alive does not
  /// look broken at its last square.
  final bool isToday;

  /// An empty current day: nothing recorded, nothing ruled, still open.
  bool get pending => isToday && state == DayMarkState.none && verdict == null;

  /// Whether the day counts toward a "successful days" tally: a verdict of
  /// [DayVerdict.met] where one exists, otherwise any measured state that is
  /// not an empty or missed day.
  bool get successful => switch (verdict) {
    final verdict? => verdict == DayVerdict.met,
    null => switch (state) {
      DayMarkState.full || DayMarkState.partial => true,
      DayMarkState.none || DayMarkState.skipped || DayMarkState.missed => false,
    },
  };

  @override
  bool operator ==(Object other) =>
      other is DayMark &&
      other.day == day &&
      other.state == state &&
      other.verdict == verdict &&
      other.verdictProvenance == verdictProvenance &&
      other.isToday == isToday;

  @override
  int get hashCode =>
      Object.hash(day, state, verdict, verdictProvenance, isToday);

  @override
  String toString() =>
      'DayMark(day: $day, state: $state, verdict: $verdict, '
      'provenance: $verdictProvenance, isToday: $isToday)';
}
