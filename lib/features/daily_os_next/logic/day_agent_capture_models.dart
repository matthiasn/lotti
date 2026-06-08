part of 'day_agent_models.dart';

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

// `ParsedItemConfidence` (low | medium | high) and `ParsedItemKind`
// (newTask | matched | update) are the canonical agent-side enums.
// They live in `lib/features/agents/model/agent_enums.dart` and are
// re-exported by the library file so the UI sees them via this models file.

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
  missedRecurring,
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
    this.referenceDate,
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

  /// Selected plan date used for date-aware due/overdue labels. Null means
  /// the label should use the current-day wording.
  final DateTime? referenceDate;
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
