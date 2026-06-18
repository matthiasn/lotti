import 'package:equatable/equatable.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// One calendar day in the consistency heatmap.
///
/// [successCount] is how many habits had a `success` completion that day;
/// [activeCount] is the day's denominator — the union of habits that were
/// active on that day and habits that have any recorded completion on it (the
/// same convention as [totalForDay], so the heatmap can never disagree with the
/// completion-rate chart). [intensity] is `success / active`, the value the grid
/// shades; it is `0` when nothing was active (a day before any habit existed),
/// which the grid renders as a quiet neutral, never as a miss.
class HeatmapDay extends Equatable {
  const HeatmapDay({
    required this.ymd,
    required this.successCount,
    required this.activeCount,
    required this.isToday,
  });

  /// `YYYY-MM-DD`.
  final String ymd;
  final int successCount;
  final int activeCount;
  final bool isToday;

  /// Whether any habit counted toward this day. False for days before the
  /// earliest habit existed — those render neutral and carry no "miss" meaning.
  bool get isInActiveRange => activeCount > 0;

  /// Completion fraction in `[0, 1]`. `0` when nothing was active. Clamped so a
  /// back-dated completion can never push it above full.
  double get intensity {
    if (activeCount == 0) {
      return 0;
    }
    return (successCount / activeCount).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [ymd, successCount, activeCount, isToday];
}

/// Builds the ordered (ascending) per-day series for the consistency heatmap.
///
/// [completions] are habit-completion entries (one latest per habit/day, as
/// returned by `getHabitCompletionsInRange`); [habitDefinitions] are the active
/// definitions. [rangeStartYmd]/[rangeEndYmd] bound the inclusive day range and
/// [todayYmd] flags the current day — all passed in as `YYYY-MM-DD` strings so
/// this function is fully deterministic (no wall clock).
///
/// The denominator for each day is the union of [activeBy] (habits whose
/// `activeFrom` is on/before the day) and habits with any recorded completion
/// that day — identical to [totalForDay]. The numerator counts only `success`
/// completions: the heatmap measures actual wins, not avoidance. To fold skips
/// into "done", widen the type guard below to
/// `{HabitCompletionType.success, HabitCompletionType.skip}` — that would match
/// the card's `completedToday` notion but is deliberately not done here.
List<HeatmapDay> buildHeatmapDays({
  required List<JournalEntity> completions,
  required List<HabitDefinition> habitDefinitions,
  required String rangeStartYmd,
  required String rangeEndYmd,
  required Set<String> selectedCategoryIds,
  required String todayYmd,
}) {
  final defs = selectedCategoryIds.isEmpty
      ? habitDefinitions
      : habitDefinitions
            .where((h) => selectedCategoryIds.contains(h.categoryId))
            .toList();
  final allowedHabitIds = defs.map((h) => h.id).toSet();

  final successByDay = <String, Set<String>>{};
  final recordedByDay = <String, Set<String>>{};

  for (final item in completions) {
    if (item is! HabitCompletionEntry) {
      continue;
    }
    final habitId = item.data.habitId;
    if (!allowedHabitIds.contains(habitId)) {
      continue;
    }
    final day = item.meta.dateFrom.ymd;
    recordedByDay.putIfAbsent(day, () => <String>{}).add(habitId);
    if (item.data.completionType == HabitCompletionType.success) {
      successByDay.putIfAbsent(day, () => <String>{}).add(habitId);
    }
  }

  final days = daysInRange(
    rangeStart: DateTime.parse(rangeStartYmd),
    rangeEnd: DateTime.parse(rangeEndYmd),
  );

  return [
    for (final ymd in days)
      HeatmapDay(
        ymd: ymd,
        successCount: (successByDay[ymd] ?? const <String>{}).length,
        activeCount: activeBy(defs, ymd)
            .map((h) => h.id)
            .toSet()
            .union(recordedByDay[ymd] ?? const <String>{})
            .length,
        isToday: ymd == todayYmd,
      ),
  ];
}

/// Groups an ascending [days] series into week columns aligned so each column's
/// row 0 is [firstDayOfWeekIndex] (`0 = Sunday` … `6 = Saturday`, Flutter's
/// convention).
///
/// Every column is exactly 7 slots (weekday rows 0..6). Days before the first
/// week boundary leave leading nulls in the oldest column; the days after the
/// last boundary leave trailing nulls in the newest column. Columns are
/// returned oldest-first; the grid reverses them so the newest week renders on
/// the right.
List<List<HeatmapDay?>> groupIntoWeekColumns(
  List<HeatmapDay> days, {
  required int firstDayOfWeekIndex,
}) {
  if (days.isEmpty) {
    return const [];
  }

  final columns = <List<HeatmapDay?>>[];
  List<HeatmapDay?>? current;

  for (final day in days) {
    final row = _weekdayRowIndex(day.ymd, firstDayOfWeekIndex);
    if (current == null || row == 0) {
      current = List<HeatmapDay?>.filled(7, null);
      columns.add(current);
    }
    current[row] = day;
  }

  return columns;
}

/// The 0..6 row a day occupies in a column whose row 0 is [firstDayOfWeekIndex].
///
/// `DateTime.weekday` is 1 (Mon) … 7 (Sun); `% 7` maps it to 0 (Sun) … 6 (Sat)
/// — the same frame as the first-day index — then the offset rotates it so the
/// first day of the week lands on row 0. Matches `leadingBlankDayCount`.
int _weekdayRowIndex(String ymd, int firstDayOfWeekIndex) {
  final weekdaySundayZero = DateTime.parse(ymd).weekday % 7;
  return (weekdaySundayZero - firstDayOfWeekIndex + 7) % 7;
}

/// Per-habit **current streak**: the number of consecutive days, ending today
/// (or yesterday, if today isn't recorded yet so a still-pending day doesn't
/// read as a break), on which the habit was *kept* — a `success`, a `skip`, or
/// an untyped completion, matching the streak rule used elsewhere (an explicit
/// `fail` or a missing day ends it). Computed over the heatmap's deep history,
/// so it isn't capped by the tab's short fetch window. Streaks are per habit,
/// independent of the category filter.
Map<String, int> currentStreaksByHabit({
  required List<JournalEntity> completions,
  required List<HabitDefinition> habitDefinitions,
  required String todayYmd,
}) {
  final ids = habitDefinitions.map((h) => h.id).toSet();
  final keptByHabit = <String, Set<String>>{};
  for (final item in completions) {
    if (item is! HabitCompletionEntry) {
      continue;
    }
    final id = item.data.habitId;
    if (!ids.contains(id)) {
      continue;
    }
    final type = item.data.completionType;
    if (type == HabitCompletionType.success ||
        type == HabitCompletionType.skip ||
        type == null) {
      keptByHabit.putIfAbsent(id, () => <String>{}).add(item.meta.dateFrom.ymd);
    }
  }

  return {
    for (final habit in habitDefinitions)
      habit.id: _streakFromKeptDays(
        keptByHabit[habit.id] ?? const <String>{},
        todayYmd,
      ),
  };
}

int _streakFromKeptDays(Set<String> keptDays, String todayYmd) {
  var cursor = DateTime.parse(todayYmd);
  if (!keptDays.contains(cursor.ymd)) {
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    if (!keptDays.contains(cursor.ymd)) {
      return 0;
    }
  }
  var streak = 0;
  while (keptDays.contains(cursor.ymd)) {
    streak++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return streak;
}

/// The heatmap controller's published state.
///
/// [days] is the ascending per-day series; the card groups it into week columns
/// once the (async) first-day-of-week index resolves. [hasHabits] reflects
/// whether the user has *any* active habit (independent of the category
/// filter), so an empty filter shows a neutral grid rather than the
/// "add a habit" placeholder. [isLoading] is true only on the very first frame,
/// before the initial recompute — after that the controller never republishes a
/// loading state, so a background refresh never blanks the grid.
class HabitHeatmapData extends Equatable {
  const HabitHeatmapData({
    required this.days,
    required this.hasHabits,
    required this.isLoading,
    this.streaksByHabit = const {},
  });

  factory HabitHeatmapData.empty() =>
      const HabitHeatmapData(days: [], hasHabits: false, isLoading: true);

  final List<HeatmapDay> days;
  final bool hasHabits;
  final bool isLoading;

  /// Per-habit current streak (see [currentStreaksByHabit]); habit id → length.
  final Map<String, int> streaksByHabit;

  HabitHeatmapData copyWith({
    List<HeatmapDay>? days,
    bool? hasHabits,
    bool? isLoading,
    Map<String, int>? streaksByHabit,
  }) {
    return HabitHeatmapData(
      days: days ?? this.days,
      hasHabits: hasHabits ?? this.hasHabits,
      isLoading: isLoading ?? this.isLoading,
      streaksByHabit: streaksByHabit ?? this.streaksByHabit,
    );
  }

  @override
  List<Object?> get props => [days, hasHabits, isLoading, streaksByHabit];
}
