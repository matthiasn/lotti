import 'package:lotti/widgets/day_indicators/day_mark.dart';

/// Lines a goal's compact window up with the verdicts the user has recorded
/// for it, producing the [DayMark]s the shared strip renders.
///
/// [states] runs oldest to newest and ends on [lastDay]; every earlier mark
/// counts back from it, which is how a tap resolves to a date without a
/// second parallel list that could fall out of step with the states. The last
/// cell is today's. Without a [lastDay] the marks carry no dates — the strip
/// then renders no weekday letters and cannot be tapped.
///
/// A recorded verdict wins over the measured state for its day: the
/// measurement is evidence about a day, the reflection is the user's ruling
/// on it. Verdicts are keyed by UTC day, as the assessment history stores
/// them.
List<DayMark> goalDayMarks({
  required List<DayMarkState> states,
  DateTime? lastDay,
  Map<DateTime, DayVerdict> verdictsByDay = const {},
}) {
  final length = states.length;
  DateTime? dateAt(int index) =>
      lastDay?.subtract(Duration(days: length - 1 - index));
  DayVerdict? verdictAt(DateTime? date) {
    if (date == null || verdictsByDay.isEmpty) return null;
    return verdictsByDay[DateTime.utc(date.year, date.month, date.day)];
  }

  return [
    for (var index = 0; index < length; index++)
      if (dateAt(index) case final date)
        DayMark(
          day: date,
          state: states[index],
          verdict: verdictAt(date),
          isToday: index == length - 1,
        ),
  ];
}
