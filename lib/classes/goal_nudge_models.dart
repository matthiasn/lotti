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

/// One rating-prompt outcome for one activation of an ad.
///
/// Ratings are a HISTORY, not a single value (ADR 0055 Decision 7): each
/// re-run ([activation] is the 1-based run index) prompts anew, and the
/// trajectory across runs detects wear-out. A [skipped] entry records that
/// the prompt was shown and declined for that activation — which is what
/// lets the UI prompt exactly once per run instead of nagging or wrongly
/// suppressing the next run.
@freezed
abstract class GoalNudgeRating with _$GoalNudgeRating {
  const factory GoalNudgeRating({
    /// Which run of this ad the outcome belongs to (1-based).
    @JsonKey(fromJson: _decodeActivation) required int activation,
    required DateTime ratedAt,

    /// 1 (useless) .. 5 (loved it); null iff [skipped].
    @JsonKey(fromJson: _decodeRating) int? rating,
    @Default(false) bool skipped,
  }) = _GoalNudgeRating;

  factory GoalNudgeRating.fromJson(Map<String, dynamic> json) =>
      _$GoalNudgeRatingFromJson(json);
}

/// Range- and integrality-enforcing decoder: the generated decoder would
/// truncate `4.9` to 4 and store a lie in the permanent rating history;
/// out-of-contract values must fail the decode instead.
int? _decodeRating(Object? raw) {
  if (raw == null) return null;
  if (raw is num && raw % 1 == 0 && raw >= 1 && raw <= 5) return raw.toInt();
  throw FormatException('rating outside the 1..5 contract: $raw');
}

int _decodeActivation(Object? raw) {
  if (raw is num && raw % 1 == 0 && raw >= 1) return raw.toInt();
  throw FormatException('activation must be a 1-based integer: $raw');
}

/// Cross-field issues in a raw rating payload — what the per-field
/// converters cannot see. Constructor assertions are deliberately NOT the
/// boundary (they vanish in release builds); the decode gate in
/// `AgentDbConversions.fromSerialized` calls this and refuses the payload
/// with a [FormatException], and write paths validate at the service layer.
List<String> goalNudgeRatingJsonIssues(Map<String, dynamic> json) {
  final skipped = json['skipped'] == true;
  final rating = json['rating'];
  if (skipped && rating != null) {
    return const ['a skipped outcome must not carry a rating'];
  }
  if (!skipped && rating == null) {
    return const ['an unskipped outcome must carry its rating'];
  }
  return const [];
}
