import 'package:flutter/foundation.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_capture_models.dart';

/// One thing the day's recorded time went to, surfaced in Shutdown's
/// "What you did" column: a task, or untasked recordings grouped by title.
@immutable
class CompletedItem {
  const CompletedItem({
    required this.title,
    required this.category,
    required this.durationMinutes,
    required this.sessionCount,
    required this.doneToday,
    this.taskId,
  });

  final String? taskId;
  final String title;
  final DayAgentCategory category;

  /// Recorded minutes, overlaps counted once.
  final int durationMinutes;

  /// How many recordings the time came from.
  final int sessionCount;

  /// The task was marked done on the day — with or without recorded time.
  final bool doneToday;
}

/// A task meant for the day that is still open, surfaced in Shutdown's
/// "Carries forward" column.
@immutable
class CarryoverItem {
  const CarryoverItem({
    required this.taskId,
    required this.title,
    required this.category,
    required this.loggedMinutes,
    required this.suggestedDate,
  });

  final String taskId;
  final String title;
  final DayAgentCategory category;

  /// Minutes recorded against the task on the day; zero when it was not
  /// started.
  final int loggedMinutes;

  /// Where the primary action re-places the task: the next day.
  final DateTime suggestedDate;
}

/// Action the user takes on a carryover item.
enum CarryoverAction {
  /// Re-place the task on [CarryoverItem.suggestedDate].
  tomorrow,

  /// Re-place the task on a date the user picks.
  pickDate,

  /// Drop the task (rejected).
  drop,
}

/// 2×2 metrics card shown in Shutdown, computed from recorded time and
/// session ratings. The definitions live beside `shutdownMetrics`.
@immutable
class ShutdownMetrics {
  const ShutdownMetrics({
    required this.focusMinutes,
    required this.flowSessions,
    required this.contextSwitches,
    this.contextSwitchesWeekAvg,
    this.energyScore,
    this.energyDeltaVsWeek,
  });

  final int focusMinutes;
  final int flowSessions;
  final int contextSwitches;

  /// Mean switches over the previous seven days that had recorded work;
  /// null when none did.
  final double? contextSwitchesWeekAvg;

  /// Mean session-rating energy on a 0–10 scale; null when no session of
  /// the day was rated.
  final double? energyScore;

  /// [energyScore] minus the previous seven days' mean; null when either
  /// side has no ratings.
  final double? energyDeltaVsWeek;
}

/// One paragraph the planner writes for the start of tomorrow.
@immutable
class TomorrowNote {
  const TomorrowNote({required this.body});

  final String body;
}
