import 'package:flutter/foundation.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_capture_models.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_plan_models.dart';

/// One bullet inside a learning card (Yesterday / This week / Gentle
/// nudge). Tone matches the prototype copy.
@immutable
class LearningBullet {
  const LearningBullet({required this.text, required this.tone});

  final String text;
  final LearningBulletTone tone;
}

/// Tone of a [LearningBullet], selecting its accent (neutral, encouraging,
/// or cautionary) in the learning card.
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

/// User resolution state for a proposed refine change.
enum PlanDiffChangeDecision { pending, accepted, rejected }

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
