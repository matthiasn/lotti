import 'dart:math';

import 'package:clock/clock.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';

part 'habits_state.freezed.dart';

/// Which habit bucket the habits tab shows.
///
/// `openNow` — due and not yet completed today; `pendingLater` — open but
/// scheduled to surface later in the day (per `showHabit`); `completed` —
/// already completed today; `all` — every bucket shown together with section
/// headers.
enum HabitDisplayFilter { openNow, pendingLater, completed, all }

/// Immutable state for the habits page, recomputed by `HabitsController`.
///
/// Holds three layers of data: the habit buckets that drive the list
/// (`openNow`, `pendingLater`, `completed`, already category-filtered), the
/// per-day completion maps that drive the chart (`successfulByDay`,
/// `skippedByDay`, `failedByDay`, `allByDay`, keyed `YYYY-MM-DD` → habit-ID
/// set) and the chart/UI display settings (`timeSpanDays`, `minY`,
/// `zeroBased`, `displayFilter`, `searchString`, `selectedCategoryIds`, the
/// search/time-span visibility toggles). The `*Percentage` fields and
/// `selectedInfoYmd` back the day-detail popover; `selectedInfoYmd` is cleared
/// on a debounce after a tap (see `HabitsController.setInfoYmd`).
@freezed
abstract class HabitsState with _$HabitsState {
  const factory HabitsState({
    required List<HabitDefinition> habitDefinitions,
    required List<HabitDefinition> openHabits,
    required List<HabitDefinition> openNow,
    required List<HabitDefinition> pendingLater,
    required List<HabitDefinition> completed,
    required List<JournalEntity> habitCompletions,
    required Set<String> completedToday,
    required Set<String> successfulToday,
    required Set<String> selectedCategoryIds,
    required List<String> days,
    required Map<String, Set<String>> successfulByDay,
    required Map<String, Set<String>> skippedByDay,
    required Map<String, Set<String>> failedByDay,
    required Map<String, Set<String>> allByDay,
    required int successPercentage,
    required int skippedPercentage,
    required int failedPercentage,
    required String selectedInfoYmd,
    required int shortStreakCount,
    required int longStreakCount,
    required int timeSpanDays,
    required double minY,
    required bool zeroBased,
    required bool showTimeSpan,
    required bool showSearch,
    required String searchString,
    required HabitDisplayFilter displayFilter,
  }) = _HabitsState;

  /// Creates the initial state with default values.
  factory HabitsState.initial() => HabitsState(
    habitDefinitions: [],
    habitCompletions: [],
    completedToday: <String>{},
    openHabits: [],
    openNow: [],
    pendingLater: [],
    completed: [],
    days: getHabitDays(isDesktop ? 14 : 7),
    successfulToday: <String>{},
    successfulByDay: <String, Set<String>>{},
    skippedByDay: <String, Set<String>>{},
    failedByDay: <String, Set<String>>{},
    allByDay: <String, Set<String>>{},
    selectedInfoYmd: '',
    successPercentage: 0,
    skippedPercentage: 0,
    failedPercentage: 0,
    shortStreakCount: 0,
    longStreakCount: 0,
    timeSpanDays: isDesktop ? 14 : 7,
    zeroBased: true,
    minY: 0,
    displayFilter: HabitDisplayFilter.openNow,
    showSearch: false,
    showTimeSpan: false,
    searchString: '',
    selectedCategoryIds: <String>{},
  );
}

/// Completion rate (0–100) for `state`'s selected day, for one completion
/// category.
///
/// [byDay] is one of the per-category maps (`successfulByDay`,
/// `skippedByDay`, `failedByDay`): the count of habit IDs it holds for
/// [HabitsState.selectedInfoYmd] is divided by [totalForDay] for that day and
/// rounded. Returns 0 when no habits are tracked for the day.
int completionRate(
  HabitsState state,
  Map<String, Set<String>> byDay,
) {
  final completionsByTypeOnDay = byDay[state.selectedInfoYmd] ?? {};
  final n = completionsByTypeOnDay.length;
  final total = totalForDay(state.selectedInfoYmd, state);

  if (total == 0) {
    return 0;
  }

  final percentage = (n / total) * 100;
  return percentage.round();
}

/// The success / skipped / failed completion-rate bands for a single day,
/// each an integer percentage in `[0, 100]`.
typedef DayPercentages = ({int success, int skipped, int failed});

/// Computes the [DayPercentages] for `state`'s selected day.
///
/// Pure transformation extracted from `HabitsController.setInfoYmd` so the
/// clamp can be tested in isolation. `success` and `skipped` are the raw
/// completion rates for [HabitsState.selectedInfoYmd]; `failed` is clamped to
/// the remaining headroom (`100 - success - skipped`) so the three bands never
/// sum above 100 — without the clamp, overlapping completion records on a day
/// could push the stacked bar past full.
DayPercentages dayPercentages(HabitsState state) {
  final success = completionRate(state, state.successfulByDay);
  final skipped = completionRate(state, state.skippedByDay);
  final failed = min(
    completionRate(state, state.failedByDay),
    100 - success - skipped,
  );
  return (success: success, skipped: skipped, failed: failed);
}

/// Number of habits that count toward [ymd]'s completion denominator.
///
/// The union of two sources: habits already recorded for the day
/// (`state.allByDay[ymd]`) and habits that were active by [ymd] per
/// [activeBy]. Taking the union means a habit counts whether or not it was
/// scheduled, so back-dated completions of since-inactive habits still
/// contribute, and active-but-untouched habits aren't dropped from the total.
int totalForDay(String ymd, HabitsState state) {
  final activeHabitIds = activeBy(
    state.habitDefinitions,
    ymd,
  ).map((habitDefinition) => habitDefinition.id).toSet();
  final allByDay = state.allByDay[ymd] ?? {};
  return allByDay.union(activeHabitIds).length;
}

/// Filters [habitDefinitions] to those whose `activeFrom` date is on or
/// before [ymd] (a `YYYY-MM-DD` string).
///
/// Comparison is at day granularity. A null `activeFrom` is treated as the
/// epoch (`DateTime(0)`), i.e. always active. Returns an empty list when [ymd]
/// is empty.
List<HabitDefinition> activeBy(
  List<HabitDefinition> habitDefinitions,
  String ymd,
) {
  if (ymd.isEmpty) {
    return [];
  }
  final activeHabits = habitDefinitions.where((habitDefinition) {
    final activeFrom = habitDefinition.activeFrom ?? DateTime(0);
    return !DateTime(
      activeFrom.year,
      activeFrom.month,
      activeFrom.day,
    ).isAfter(DateTime.parse(ymd));
  }).toList();

  return activeHabits;
}

/// Lower Y bound for the completion-rate chart when not zero-based.
///
/// Scans [days], computes each day's success rate (`successfulByDay` count
/// over [totalForDay]) and takes the lowest, then drops 20 points of padding,
/// floored at 0. Days with no tracked habits are ignored. Returns 0 when no
/// day has habits, which keeps the chart zero-based by default.
double habitMinY({
  required List<String> days,
  required HabitsState state,
}) {
  double? lowest;

  for (final day in days) {
    final total = totalForDay(day, state);
    if (total > 0) {
      final n = state.successfulByDay[day]?.length ?? 0;
      final rate = 100 * n / total;
      lowest = lowest == null ? rate : min(lowest, rate);
    }
  }

  // Return 0 if no valid days with habits, otherwise apply the -20 offset
  if (lowest == null) {
    return 0;
  }
  return max(lowest - 20, 0);
}

/// Generates a list of date strings for the given time span.
///
/// Reads the current instant via [clock] (defaults to the wall clock) so
/// callers can pin "today" deterministically in tests with `withClock`.
List<String> getHabitDays(int timeSpanDays) {
  final now = clock.now();
  final days = daysInRange(
    rangeStart: now.dayAtMidnight.subtract(Duration(days: timeSpanDays)),
    rangeEnd: now,
  )..sort();
  return days;
}
