part of 'day_agent_models.dart';

/// What completed during the day — surfaced in Shutdown's
/// "What you did" column.
@immutable
class CompletedItem {
  const CompletedItem({
    required this.taskId,
    required this.title,
    required this.category,
    required this.durationMinutes,
    this.note,
  });

  final String taskId;
  final String title;
  final DayAgentCategory category;
  final int durationMinutes;

  /// Optional context line ("Logged 3 sessions, 90m total.").
  final String? note;
}

/// What did not finish — surfaced in Shutdown's "Carries forward"
/// column with a primary suggested re-placement chip.
@immutable
class CarryoverItem {
  const CarryoverItem({
    required this.taskId,
    required this.title,
    required this.category,
    required this.reason,
    required this.suggestedTarget,
  });

  final String taskId;
  final String title;
  final DayAgentCategory category;

  /// One-line explanation ("Ran out of time — started, 40m in").
  final String reason;

  /// Human-readable label for the agent's suggested re-placement
  /// (e.g. "→ tomorrow morning", "→ Sunday"). Tapping it triggers
  /// `record_carryover_decision` with the resolved date.
  final String suggestedTarget;
}

/// Action the user takes on a carryover item.
enum CarryoverAction {
  /// Apply the agent's suggested re-placement (tomorrow / picked day).
  tomorrow,

  /// Open a date picker — for the mock this falls through to
  /// tomorrow + 7 days.
  pickDate,

  /// Drop the task (archive).
  drop,
}

/// 2×2 metrics card shown in Shutdown.
@immutable
class ShutdownMetrics {
  const ShutdownMetrics({
    required this.focusMinutes,
    required this.flowSessions,
    required this.contextSwitches,
    required this.contextSwitchesWeekAvg,
    required this.energyScore,
    required this.energyDeltaVsWeek,
  });

  final int focusMinutes;
  final int flowSessions;
  final int contextSwitches;
  final double contextSwitchesWeekAvg;

  /// 1–10 scale; aligns with the user's energy bands.
  final double energyScore;

  /// Difference vs the rolling weekly average — positive means up.
  final double energyDeltaVsWeek;
}

/// One paragraph the agent puts together for the start of tomorrow.
@immutable
class TomorrowNote {
  const TomorrowNote({required this.body, required this.maturity});

  final String body;

  /// 1–3 maturity buckets the prototype copy scales across (day 1 /
  /// month 3 / year 1). The Shutdown card uses this to vary
  /// references to past dates + confirmed preferences.
  final int maturity;
}

/// Source of the Shutdown reflection — typed in or spoken.
enum ReflectionSource { typed, voice }

/// Fields the user-facing corpus browser filters by.
enum TaskCorpusState {
  all,
  inProgress,
  overdue,
  scheduled,
  recurring,
  backlog,
  done,
}

/// One row in the Tasks corpus surface.
@immutable
class TaskCorpusItem {
  const TaskCorpusItem({
    required this.id,
    required this.title,
    required this.category,
    required this.state,
    required this.updatedLabel,
  });

  final String id;
  final String title;
  final DayAgentCategory category;
  final TaskCorpusState state;

  /// Human-readable "updated …" string, e.g. "today", "yesterday",
  /// "May 18", "2 weeks ago". The mock returns these directly so the
  /// UI does not have to compute relative dates.
  final String updatedLabel;
}
