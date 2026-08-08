import 'package:freezed_annotation/freezed_annotation.dart';

part 'goal_nudge_models.freezed.dart';
part 'goal_nudge_models.g.dart';

/// Emotional register of a goal ad. `roast` is only used when the user has
/// asked for it: sharp humor about the streak, never about the person
/// (ADR 0055).
enum GoalNudgeTone { encourage, nudge, celebrate, roast }

/// Lifecycle of a goal ad (ADR 0055 Decision 2).
///
/// `draft → ready → active → dismissed | retired | expired | superseded |
/// failed`, with the reuse re-entry `retired → active` (same row, fresh
/// staleAt, full rating and display history kept). The *user dismisses*,
/// the *agent retires*, the *clock expires*, a newer ad *supersedes*,
/// generation/verification *fails*.
enum GoalNudgeStatus {
  draft,
  ready,
  active,
  dismissed,
  retired,
  expired,
  superseded,
  failed,
}

/// The typed visual brief — the ONLY payload an image request may be
/// composed from (ADR 0056: the boundary is this field allowlist).
///
/// Every field is model-authored tool output that passes the leakage lint
/// and evals before it gets here. [headline] and [cta] render in the image
/// as banner typography (ADR 0055 Decision 8); [altText] is entity-side
/// only (semantics label, history rendering) and is never sent.
@freezed
abstract class GoalNudgeBrief with _$GoalNudgeBrief {
  const factory GoalNudgeBrief({
    required String sceneConcept,
    required String headline,
    required String altText,
    required GoalNudgeTone tone,
    String? cta,
    String? mood,
    String? stylePreset,
  }) = _GoalNudgeBrief;

  factory GoalNudgeBrief.fromJson(Map<String, dynamic> json) =>
      _$GoalNudgeBriefFromJson(json);
}

/// One rating event for one run of an ad.
///
/// Ratings are a HISTORY, not a single value (ADR 0055 Decision 7): every
/// re-run prompts anew, and the trajectory across runs is what detects
/// wear-out — a five-star ad sliding to two stars retires from the reuse
/// library.
@freezed
abstract class GoalNudgeRating with _$GoalNudgeRating {
  const factory GoalNudgeRating({
    /// 1 (useless) .. 5 (loved it).
    required int rating,
    required DateTime ratedAt,
  }) = _GoalNudgeRating;

  factory GoalNudgeRating.fromJson(Map<String, dynamic> json) =>
      _$GoalNudgeRatingFromJson(json);
}
