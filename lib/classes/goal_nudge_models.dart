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

/// User-selectable banner snooze presets.
///
/// [custom] preserves chat-requested snoozes that do not match one of the
/// fixed UI choices. Their exact length remains in
/// [GoalNudgeSnooze.durationMinutes].
enum GoalBannerSnoozeDuration {
  oneHour,
  threeHours,
  sixHours,
  eightHours,
  custom,
}

extension GoalBannerSnoozeDurationValue on GoalBannerSnoozeDuration {
  Duration? get duration => switch (this) {
    GoalBannerSnoozeDuration.oneHour => const Duration(hours: 1),
    GoalBannerSnoozeDuration.threeHours => const Duration(hours: 3),
    GoalBannerSnoozeDuration.sixHours => const Duration(hours: 6),
    GoalBannerSnoozeDuration.eightHours => const Duration(hours: 8),
    GoalBannerSnoozeDuration.custom => null,
  };
}

GoalBannerSnoozeDuration goalBannerSnoozeDurationFor(Duration duration) =>
    GoalBannerSnoozeDuration.values.firstWhere(
      (preset) => preset.duration == duration,
      orElse: () => GoalBannerSnoozeDuration.custom,
    );

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

/// One durable snooze interaction for one banner activation.
///
/// The UTC instants preserve ordering and expiry semantics across devices.
/// [utcOffsetMinutes] preserves the wall-clock context in which the user made
/// the choice, so future timing analysis does not reinterpret an old snooze in
/// the device's current timezone after travel or a daylight-saving change.
@freezed
abstract class GoalNudgeSnooze with _$GoalNudgeSnooze {
  const factory GoalNudgeSnooze({
    required String id,
    @JsonKey(fromJson: _decodeActivation) required int activation,
    required DateTime snoozedAt,
    required DateTime snoozedUntil,
    required GoalBannerSnoozeDuration duration,
    @JsonKey(fromJson: _decodePositiveMinutes) required int durationMinutes,
    @JsonKey(fromJson: _decodeUtcOffsetMinutes) required int utcOffsetMinutes,
  }) = _GoalNudgeSnooze;

  const GoalNudgeSnooze._();

  factory GoalNudgeSnooze.fromJson(Map<String, dynamic> json) =>
      _$GoalNudgeSnoozeFromJson(json);

  /// The recorded local wall-clock value represented as a zone-free UTC
  /// [DateTime], so consumers can read its components without applying the
  /// current device timezone.
  DateTime get snoozedAtLocal =>
      snoozedAt.toUtc().add(Duration(minutes: utcOffsetMinutes));

  /// The requested return time in the same recorded wall-clock convention as
  /// [snoozedAtLocal].
  DateTime get snoozedUntilLocal =>
      snoozedUntil.toUtc().add(Duration(minutes: utcOffsetMinutes));
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

int _decodePositiveMinutes(Object? raw) {
  if (raw is num && raw % 1 == 0 && raw > 0) return raw.toInt();
  throw FormatException('durationMinutes must be a positive integer: $raw');
}

int _decodeUtcOffsetMinutes(Object? raw) {
  if (raw is num && raw % 1 == 0 && raw >= -840 && raw <= 840) {
    return raw.toInt();
  }
  throw FormatException('utcOffsetMinutes outside -840..840: $raw');
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

/// Cross-field issues in a raw snooze event payload.
List<String> goalNudgeSnoozeJsonIssues(Map<String, dynamic> json) {
  final snoozedAt = DateTime.tryParse(json['snoozedAt']?.toString() ?? '');
  final snoozedUntil = DateTime.tryParse(
    json['snoozedUntil']?.toString() ?? '',
  );
  if (snoozedAt == null || snoozedUntil == null) return const [];
  final exact = snoozedUntil.toUtc().difference(snoozedAt.toUtc());
  if (exact <= Duration.zero) {
    return const ['snoozedUntil must be after snoozedAt'];
  }
  final durationMinutes = json['durationMinutes'];
  if (durationMinutes is num && durationMinutes % 1 == 0) {
    final expectedMinutes = (exact.inSeconds + 59) ~/ 60;
    if (durationMinutes.toInt() != expectedMinutes) {
      return const ['durationMinutes must match the snooze interval'];
    }
  }
  return const [];
}
