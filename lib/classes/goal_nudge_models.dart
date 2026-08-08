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

/// Animation presets a banner may use — a fixed, code-owned catalog
/// (ADR 0058). The model *selects*, code *implements*: presets use
/// design-system tokens, respect reduced motion, and fall back to their
/// plain form where fragment shaders are unavailable (Linux).
enum GoalBannerAnimation { steady, typewriter, pulse, wave, marquee, glitch }

/// Accent (background/color) presets from the design system — the visual
/// energy behind the copy, without a single generated pixel.
enum GoalBannerAccent { calm, ember, tide, neon, aurora }

/// The typed banner brief — everything a goal ad IS (ADR 0058).
///
/// The model authors the copy and picks presentation presets; the app
/// renders it procedurally. No image provider exists in this channel.
/// Copy fields are the only model text that reaches a surface verbatim,
/// so they are what the leakage lint and evals police (the ADR 0056
/// principle, retargeted at text).
@freezed
abstract class GoalNudgeBrief with _$GoalNudgeBrief {
  const factory GoalNudgeBrief({
    required String headline,
    required GoalNudgeTone tone,
    required GoalBannerAnimation animation,
    @Default(GoalBannerAccent.calm) GoalBannerAccent accent,
    String? tagline,
    String? cta,
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
