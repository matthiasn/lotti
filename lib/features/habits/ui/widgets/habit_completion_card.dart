import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/habits/state/habit_completion_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habit_action_row.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_data.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';
import 'package:lotti/widgets/day_indicators/day_mark_strip.dart';

/// A habit row that carries its own per-day completion history strip — used by
/// the dashboard habit chart, where seeing the chain over the dashboard's range
/// is the point.
///
/// Wraps the shared [HabitActionRow] (swipe + quick-complete + dialog), adding
/// the range-keyed [habitCompletionControllerProvider] watch that feeds the
/// [_HistoryStrip] and derives the done-state from the latest in-range result.
/// The habits tab does NOT use this card — it renders [HabitActionRow] directly
/// (history lives in the consistency heatmap).
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
      history: _HistoryStrip(results: results),
    );
  }
}

/// The per-day completion history strip — a compact "don't break the chain"
/// calendar drawn with the shared day-indicator cells, so a habit's chain here
/// wears exactly the language a goal's habit dimension does: the success fill,
/// the skip dash and missed cross as non-color cues, the dashed ring on today.
///
/// The strip is read-only: it's a glanceable record, not a control. Tapping
/// anywhere on the row (or the complete button) opens the dialog, where any
/// past day can be backfilled via the date field — so the strip needs no tiny,
/// swipe-conflicting per-cell tap targets. A range longer than the width can
/// hold pans, anchored on today, like every other day track.
class _HistoryStrip extends StatelessWidget {
  const _HistoryStrip({required this.results});

  final List<HabitResult> results;

  @override
  Widget build(BuildContext context) {
    final today = clock.now().ymd;
    return DayMarkStrip(
      marks: [
        for (final result in results)
          DayMark(
            day: DateTime.parse(result.dayString),
            state: habitCompletionDayMarkState(result.completionType),
            isToday: result.dayString == today,
          ),
      ],
    );
  }
}

/// The shared day-mark state a recorded habit outcome renders as.
DayMarkState habitCompletionDayMarkState(HabitCompletionType type) =>
    switch (type) {
      HabitCompletionType.success => DayMarkState.full,
      HabitCompletionType.skip => DayMarkState.skipped,
      HabitCompletionType.fail => DayMarkState.missed,
      HabitCompletionType.open => DayMarkState.none,
    };
