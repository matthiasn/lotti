/// Data structures the mock day-agent surface returns to the UI.
///
/// These mirror the eventual real agent contract documented in
/// `docs/implementation_plans/2026-05-25_day_agent_layer.md` (§E).
/// When the real `DayAgentWorkflow` lands, these structures stay; only
/// the implementation behind `DayAgentInterface` changes.
library;

import 'package:flutter/foundation.dart';

/// Identifier for a single capture submission (one spoken check-in).
@immutable
class CaptureId {
  const CaptureId(this.value);
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaptureId &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'CaptureId($value)';
}

/// How confident the agent is in a parsed item. Used to drive
/// the warning tint + "low confidence" label on parsed cards.
enum ParsedItemConfidence {
  high,
  low,
}

/// What kind of corpus reconciliation a parsed item represents.
enum ParsedItemKind {
  /// New task — no existing match found.
  newTask,

  /// Linked to an existing task in the corpus.
  matched,

  /// Updates state on an existing task (e.g. "I finished the deck").
  update,
}

/// A category exposed to the day-agent layer. Mirrors the shape of
/// the real `CategoryDefinition` but stays minimal so the mock does
/// not depend on the categories feature directly.
@immutable
class DayAgentCategory {
  const DayAgentCategory({
    required this.id,
    required this.name,
    required this.colorHex,
  });

  final String id;
  final String name;

  /// Hex string in `RRGGBB` form. The UI maps this to a real color
  /// at render time so the data layer stays platform-agnostic.
  final String colorHex;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayAgentCategory &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          colorHex == other.colorHex;

  @override
  int get hashCode => Object.hash(id, name, colorHex);
}

/// A single parsed unit pulled out of a capture transcript.
///
/// `kind == matched` carries a `matchedTaskId` + `matchedTaskTitle`.
/// `kind == newTask` carries a synthesised task title only.
/// `kind == update` carries the matched task plus the proposed
/// state change (free-text for now; the real agent will produce a
/// structured `state_update` payload).
@immutable
class ParsedItem {
  const ParsedItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.category,
    required this.confidence,
    this.spokenPhrase,
    this.matchedTaskId,
    this.matchedTaskTitle,
    this.matchedTaskState,
    this.estimateMinutes,
    this.timeAnchor,
    this.proposedUpdate,
  });

  final String id;
  final ParsedItemKind kind;
  final String title;
  final DayAgentCategory category;
  final ParsedItemConfidence confidence;

  /// What the user actually said (verbatim slice of the transcript).
  /// Shown italicised on matched cards so the link is auditable.
  final String? spokenPhrase;

  final String? matchedTaskId;
  final String? matchedTaskTitle;

  /// Short human label like "In progress · 2 sessions" / "Overdue · 3d".
  final String? matchedTaskState;

  final int? estimateMinutes;

  /// Free-form time anchor like "before 11am". When non-null the
  /// card surfaces a warning-tinted constraint chip.
  final String? timeAnchor;

  /// Human-readable description of the proposed update for the
  /// matched task (kind == update only).
  final String? proposedUpdate;
}

/// Why a corpus item is being surfaced for triage on Reconcile.
enum PendingItemReason {
  overdue,
  inProgress,
  recurringMissed,
  dueToday,
}

/// Triage action a user can take on a pending item or on a
/// parsed-NEW item the agent surfaced.
enum TriageAction {
  /// Add to today's draft set.
  today,

  /// Mark done immediately (escape hatch).
  doNow,

  /// Defer to a chosen day.
  defer,

  /// Set state = done without adding to today.
  done,

  /// Set state = archived with the user-declined flag.
  drop,
}

/// A task the agent surfaced as needing a decision today.
@immutable
class PendingItem {
  const PendingItem({
    required this.taskId,
    required this.title,
    required this.category,
    required this.reason,
    this.note,
    this.overdueByDays,
    this.sessionCount,
  });

  final String taskId;
  final String title;
  final DayAgentCategory category;
  final PendingItemReason reason;

  /// Optional contextual note, e.g. "Last skipped Thursday".
  final String? note;

  /// Populated when reason == overdue.
  final int? overdueByDays;

  /// Populated when reason == inProgress.
  final int? sessionCount;
}

/// Result of applying a triage action — the UI uses this to render
/// the confirmation pill that replaces the action row.
@immutable
class TriageResult {
  const TriageResult({
    required this.taskId,
    required this.action,
    this.deferredTo,
  });

  final String taskId;
  final TriageAction action;
  final DateTime? deferredTo;
}

/// What surface produced a [TimeBlock].
enum TimeBlockType {
  /// Agent-drafted block.
  ai,

  /// Real calendar event imported from the device calendar.
  cal,

  /// Buffer between focus blocks (transition / commute / decompression).
  buffer,

  /// User-placed manually.
  manual,
}

/// Visual state used by the Day timeline to distinguish drafted from
/// committed plans. Mirrors `Day.state` from the prototype: while a
/// plan is drafted, blocks render with a dashed outline.
enum TimeBlockState {
  drafted,
  committed,
  inProgress,
  completed,
  dropped,
}

/// A scheduled placement on a day. The agent emits these from
/// `drafted_day_plan`; every `ai` block carries a verbatim `reason`
/// string that the UI surfaces in the WhyChip popover.
@immutable
class TimeBlock {
  const TimeBlock({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.type,
    required this.state,
    required this.category,
    this.taskId,
    this.reason,
    this.sessionIndex,
    this.sessionTotal,
    this.location,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final TimeBlockType type;
  final TimeBlockState state;
  final DayAgentCategory category;

  /// Null for buffers, real calendar events without a backing task,
  /// and unbound manual blocks.
  final String? taskId;

  /// The "why" string. **Mandatory** for `type == ai` — the agent
  /// must justify every placement it proposes. Optional for `cal` /
  /// `manual` / `buffer` (those have built-in justifications).
  final String? reason;

  final int? sessionIndex;
  final int? sessionTotal;
  final String? location;

  Duration get duration => end.difference(start);
}

/// A coloured energy band shown behind the Day timeline.
/// The agent emits these so the band positions stay coherent with
/// scheduling decisions ("Pushed to 2pm because of your 9am meeting").
@immutable
class EnergyBand {
  const EnergyBand({
    required this.start,
    required this.end,
    required this.level,
    required this.label,
  });

  final DateTime start;
  final DateTime end;
  final EnergyLevel level;

  /// Short overline shown at the band's top-left, e.g. "HIGH ENERGY".
  final String label;
}

enum EnergyLevel {
  high,
  low,
  secondWind,
}

/// Output of `draft_day_plan`. Carries the placed blocks, the day's
/// energy bands, and the budget metadata the Agenda/Day surfaces need
/// for the capacity donut + summary strip.
@immutable
class DraftPlan {
  const DraftPlan({
    required this.dayDate,
    required this.blocks,
    required this.bands,
    required this.capacityMinutes,
    required this.scheduledMinutes,
    this.agendaItems = const [],
  });

  final DateTime dayDate;
  final List<TimeBlock> blocks;
  final List<EnergyBand> bands;
  final int capacityMinutes;
  final int scheduledMinutes;

  /// Task-grouped projection of [blocks] used by the Agenda surface.
  /// Indexes back to the underlying blocks via
  /// [AgendaItem.linkedBlockIds].
  final List<AgendaItem> agendaItems;

  DraftPlan copyWith({
    DateTime? dayDate,
    List<TimeBlock>? blocks,
    List<EnergyBand>? bands,
    int? capacityMinutes,
    int? scheduledMinutes,
    List<AgendaItem>? agendaItems,
  }) {
    return DraftPlan(
      dayDate: dayDate ?? this.dayDate,
      blocks: blocks ?? this.blocks,
      bands: bands ?? this.bands,
      capacityMinutes: capacityMinutes ?? this.capacityMinutes,
      scheduledMinutes: scheduledMinutes ?? this.scheduledMinutes,
      agendaItems: agendaItems ?? this.agendaItems,
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
}

enum AgendaItemState {
  open,
  inProgress,
  overdue,
  done,
}

/// What the agent's reasoning stream emits one chunk at a time while
/// the plan is being drafted. The UI fades older lines to medium
/// emphasis and pulses a dot next to the currently-active line.
@immutable
class ReasoningLine {
  const ReasoningLine({required this.text, required this.icon});

  final String text;
  final ReasoningIcon icon;
}

/// Iconography the reasoning stream uses. Mapped to real material
/// icons in the UI layer so this model stays platform-agnostic.
enum ReasoningIcon {
  review,
  calendar,
  shield,
  energy,
  balance,
  ready,
}

/// One bullet inside a learning card (Yesterday / This week / Gentle
/// nudge). Tone matches the prototype copy.
@immutable
class LearningBullet {
  const LearningBullet({required this.text, required this.tone});

  final String text;
  final LearningBulletTone tone;
}

enum LearningBulletTone {
  info,
  positive,
  warning,
}

/// One of the three learning-card payloads the agent returns from
/// `summarize_recent_patterns`. The Drafting screen renders these as
/// three side-by-side cards while the plan is being composed.
@immutable
class LearningCard {
  const LearningCard({
    required this.id,
    required this.overline,
    required this.summary,
    required this.bullets,
    this.kind = LearningCardKind.standard,
  });

  final String id;
  final String overline;
  final String summary;
  final List<LearningBullet> bullets;
  final LearningCardKind kind;
}

enum LearningCardKind {
  /// Standard card (Yesterday, This week so far, etc.).
  standard,

  /// "Gentle nudge" — teal-tinted card with a one-line ask + two pill
  /// buttons ("Yes, protect mornings" / "Not today").
  nudge,
}

/// One mutation in a Refine session — moved, added, or dropped block.
/// Maps 1:1 to a row in the Refine right-column DiffRow list and a
/// ping anchored to the affected timeline row.
enum PlanDiffChangeKind { moved, added, dropped }

@immutable
class PlanDiffChange {
  const PlanDiffChange({
    required this.id,
    required this.kind,
    required this.title,
    required this.category,
    required this.reason,
    required this.affectedBlockId,
    this.fromStart,
    this.fromEnd,
    this.toStart,
    this.toEnd,
  });

  final String id;
  final PlanDiffChangeKind kind;
  final String title;
  final DayAgentCategory category;

  /// The agent's verbatim explanation for this individual change.
  final String reason;

  /// Block on the **current** plan the change attaches to. For
  /// `added` the ping anchors to the position the new block would
  /// land at; the mock keeps that simple by pointing at the block
  /// the new one displaces.
  final String affectedBlockId;

  final DateTime? fromStart;
  final DateTime? fromEnd;
  final DateTime? toStart;
  final DateTime? toEnd;
}

/// A proposed reshape of the day plan, returned by
/// `propose_plan_diff`. Persisted as a `ChangeSetEntity` once the
/// real agent layer ships — for now it lives in-memory inside the
/// Refine controller.
@immutable
class PlanDiff {
  const PlanDiff({
    required this.id,
    required this.transcript,
    required this.changes,
    required this.updatedPlan,
  });

  final String id;
  final String transcript;
  final List<PlanDiffChange> changes;

  /// The plan that results from applying every [changes] entry. The
  /// Refine screen renders the diff "applied in place" on the
  /// timeline + the [changes] list on the right column.
  final DraftPlan updatedPlan;
}
