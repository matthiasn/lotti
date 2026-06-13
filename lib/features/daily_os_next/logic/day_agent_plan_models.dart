import 'package:flutter/foundation.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_capture_models.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_timeline_models.dart';

/// Lifecycle state of a [DraftPlan]. Toggles once when the user
/// signs off in the Commit screen. Day view renders drafted blocks
/// with a dashed outline; committed blocks read solid.
enum DayState { drafted, committed }

/// Output of `draft_day_plan`. Carries the placed blocks, the day's
/// energy bands, and the budget metadata the Agenda/Day surfaces need
/// for the capacity meter + summary strip.
@immutable
class DraftPlan {
  const DraftPlan({
    required this.dayDate,
    required this.blocks,
    required this.bands,
    required this.capacityMinutes,
    required this.scheduledMinutes,
    this.actualBlocks = const [],
    this.agendaItems = const [],
    this.state = DayState.drafted,
  });

  /// Empty aggregate for a day with no drafted plan — lets the Day
  /// surface render tracked time without a plan (handoff v2 item 2).
  /// Capacity mirrors the day-agent config's 480-minute default.
  factory DraftPlan.emptyForDay(
    DateTime dayDate, {
    int capacityMinutes = 480,
  }) {
    return DraftPlan(
      dayDate: dayDate,
      blocks: const [],
      bands: const [],
      capacityMinutes: capacityMinutes,
      scheduledMinutes: 0,
    );
  }

  final DateTime dayDate;
  final List<TimeBlock> blocks;
  final List<EnergyBand> bands;
  final int capacityMinutes;
  final int scheduledMinutes;

  /// Recorded work sessions for the same day. Empty until the real
  /// time-tracking projection is wired in; the Day timeline can still
  /// compare the planned schedule with this list when it is present.
  final List<TimeBlock> actualBlocks;

  /// Task-grouped projection of [blocks] used by the Agenda surface.
  /// Indexes back to the underlying blocks via
  /// [AgendaItem.linkedBlockIds].
  final List<AgendaItem> agendaItems;

  /// Drafted (default) until the user signs off in Commit.
  final DayState state;

  DraftPlan copyWith({
    DateTime? dayDate,
    List<TimeBlock>? blocks,
    List<EnergyBand>? bands,
    int? capacityMinutes,
    int? scheduledMinutes,
    List<TimeBlock>? actualBlocks,
    List<AgendaItem>? agendaItems,
    DayState? state,
  }) {
    return DraftPlan(
      dayDate: dayDate ?? this.dayDate,
      blocks: blocks ?? this.blocks,
      bands: bands ?? this.bands,
      capacityMinutes: capacityMinutes ?? this.capacityMinutes,
      scheduledMinutes: scheduledMinutes ?? this.scheduledMinutes,
      actualBlocks: actualBlocks ?? this.actualBlocks,
      agendaItems: agendaItems ?? this.agendaItems,
      state: state ?? this.state,
    );
  }
}

/// A single row on the Agenda (intent) view — one per real task.
/// Multiple [TimeBlock]s can roll up into the same AgendaItem when a
/// task is split across the day; [linkedBlockIds] tracks those.
@immutable
class AgendaItem {
  const AgendaItem({
    required this.id,
    required this.title,
    required this.category,
    required this.linkedBlockIds,
    this.taskId,
    this.outcome,
    this.totalEstimateMinutes,
    this.progress,
    this.state = AgendaItemState.open,
  });

  final String id;
  final String title;
  final DayAgentCategory category;
  final List<String> linkedBlockIds;

  /// Backing task; null when the AgendaItem only points at calendar /
  /// manual blocks that have no task association.
  final String? taskId;

  /// One-line "what done looks like" sentence — the prototype copy
  /// shows this in `--fg-med` underneath the title.
  final String? outcome;

  final int? totalEstimateMinutes;

  /// 0–1, optional. Drives the bottom progress bar.
  final double? progress;

  final AgendaItemState state;

  AgendaItem copyWith({
    String? id,
    String? title,
    DayAgentCategory? category,
    List<String>? linkedBlockIds,
    String? taskId,
    String? outcome,
    int? totalEstimateMinutes,
    double? progress,
    AgendaItemState? state,
  }) {
    return AgendaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      linkedBlockIds: linkedBlockIds ?? this.linkedBlockIds,
      taskId: taskId ?? this.taskId,
      outcome: outcome ?? this.outcome,
      totalEstimateMinutes: totalEstimateMinutes ?? this.totalEstimateMinutes,
      progress: progress ?? this.progress,
      state: state ?? this.state,
    );
  }
}

enum AgendaItemState {
  open,
  inProgress,
  overdue,
  done,
}
