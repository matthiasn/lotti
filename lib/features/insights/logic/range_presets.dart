import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';

/// First epoch day of the fetch window that serves [range]: January 1st of
/// the year containing the range start.
///
/// The window is deliberately wider than the range so every period within
/// the same year is served from the same in-memory buckets — stepping
/// between periods of one year never touches the database.
int windowStartDayFor(InsightsRange range) {
  final start = dayStart(range.startDay);
  return epochDay(DateTime(start.year));
}

/// Fetch-window key for a range: a cheap value-equal record used as the
/// Riverpod family argument.
///
/// The record's `endYear` bounds the fetch for ranges that end in a past
/// year — a 3-day range in 2020 loads only 2020, not every year through
/// today. Current-year ranges all share one key (their fetch end tracks the
/// moving "now"), so stepping within a year stays a pure memory slice.
typedef InsightsWindow = ({int startDay, int endYear});

InsightsWindow insightsWindowFor(InsightsRange range) {
  final lastDay = dayStart(range.endDayExclusive - 1);
  return (startDay: windowStartDayFor(range), endYear: lastDay.year);
}
