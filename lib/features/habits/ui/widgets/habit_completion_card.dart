import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/habits/state/habit_completion_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habit_action_row.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_data.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:material_ui/material_ui.dart';

/// A habit row that carries its own per-day completion history strip — used by
/// the dashboard habit chart, where seeing the chain over the dashboard's range
/// is the point.
///
/// Wraps the shared [HabitActionRow] (swipe + quick-complete + dialog), adding
/// the range-keyed [habitCompletionControllerProvider] watch that feeds the
/// row's history squares and derives the done-state from the latest in-range
/// result. The habits tab does NOT use this card — it renders [HabitActionRow]
/// directly with the week read off `HabitsState`.
class HabitCompletionCard extends ConsumerStatefulWidget {
  const HabitCompletionCard({
    required this.habitId,
    required this.rangeStart,
    required this.rangeEnd,
    super.key,
  });

  final String habitId;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  ConsumerState<HabitCompletionCard> createState() =>
      _HabitCompletionCardState();
}

class _HabitCompletionCardState extends ConsumerState<HabitCompletionCard> {
  /// Last loaded results, retained so changing the time span keeps the card
  /// visible (stale-while-revalidate) instead of blinking to nothing while the
  /// new range-keyed provider loads.
  List<HabitResult>? _lastResults;

  @override
  void didUpdateWidget(HabitCompletionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Drop the cache when the card is rebound to a different habit (callers key
    // by habitId, so this is defensive), otherwise the previous habit's
    // completion squares would flash under the new habit's name until its
    // provider resolves. A range-only change deliberately keeps the stale
    // results visible (see [_lastResults]).
    if (widget.habitId != oldWidget.habitId) {
      _lastResults = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final habitDefinition = getIt<EntitiesCacheService>().getHabitById(
      widget.habitId,
    );

    if (habitDefinition == null) {
      return const SizedBox.shrink();
    }

    final resultsAsync = ref.watch(
      habitCompletionControllerProvider((
        habitId: habitDefinition.id,
        rangeStart: widget.rangeStart,
        rangeEnd: widget.rangeEnd,
      )),
    );
    if (resultsAsync.hasValue) {
      _lastResults = resultsAsync.value;
    }
    final results = _lastResults;

    if (results == null) {
      return const SizedBox.shrink();
    }

    final completedToday =
        results.isNotEmpty &&
        {
          HabitCompletionType.success,
          HabitCompletionType.skip,
        }.contains(results.last.completionType);

    return HabitActionRow(
      habitId: habitDefinition.id,
      completedToday: completedToday,
      currentStreak: _currentStreak(results),
      history: _historyMarks(results),
    );
  }
}

/// The dashboard range as day marks, oldest first, for the row's history
/// strip. Each square opens the completion sheet for its own day; the row
/// body still opens it for today, and the sheet's date field covers any day
/// the range does not show.
List<DayMark> _historyMarks(List<HabitResult> results) {
  final today = clock.now().ymd;
  return [
    for (final result in results)
      DayMark(
        day: DateTime.parse(result.dayString),
        state: habitCompletionDayMarkState(result.completionType),
        isToday: result.dayString == today,
      ),
  ];
}

/// The current unbroken run of successful days at the end of [results]: today
/// still open does not break it, any other non-success day does.
int _currentStreak(List<HabitResult> results) {
  var streak = 0;
  var index = results.length - 1;
  if (index >= 0 &&
      results[index].completionType == HabitCompletionType.open &&
      results[index].dayString == clock.now().ymd) {
    index--;
  }
  while (index >= 0 &&
      results[index].completionType == HabitCompletionType.success) {
    streak++;
    index--;
  }
  return streak;
}

/// The shared day-mark state a recorded habit outcome renders as.
DayMarkState habitCompletionDayMarkState(HabitCompletionType type) =>
    switch (type) {
      HabitCompletionType.success => DayMarkState.full,
      HabitCompletionType.skip => DayMarkState.skipped,
      HabitCompletionType.fail => DayMarkState.missed,
      HabitCompletionType.open => DayMarkState.none,
    };
