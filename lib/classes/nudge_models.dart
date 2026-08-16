/// The kind-agnostic nudge vocabulary (ADR 0059).
///
/// Extracted verbatim from the goal-typed originals so a second agent kind
/// can speak through the banner channel. The semantics are recorded in
/// ADR 0055 (lifecycle, dismissal-as-data, ratings) and ADR 0058
/// (procedural text banners); ADR 0059 governs the generalization. The
/// serialized form is unchanged: these are non-union classes (no
/// `runtimeType` marker) and every enum keeps its value names, so rows
/// written under the goal-typed names decode identically.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'nudge_models.freezed.dart';
part 'nudge_models.g.dart';

/// Emotional register of a nudge banner. `roast` is only used when the user
/// has asked for it: sharp humor about the streak, never about the person
/// (ADR 0055).
enum NudgeTone { encourage, nudge, celebrate, roast }

/// Lifecycle of a nudge banner (ADR 0055 Decision 2).
///
/// `draft → ready → active → dismissed | retired | expired | superseded |
/// failed`, with the reuse re-entry `retired → active` (same row, fresh
/// staleAt, full rating and display history kept). The *user dismisses*,
/// the *agent retires*, the *clock expires*, a newer banner *supersedes*,
/// generation/verification *fails*.
enum NudgeStatus {
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
enum NudgeBannerAnimation { steady, typewriter, pulse, wave, marquee, glitch }

/// Accent (background/color) presets from the design system — the visual
/// energy behind the copy, without a single generated pixel.
enum NudgeBannerAccent { calm, ember, tide, neon, aurora }

/// User-selectable banner snooze presets.
///
/// [custom] preserves chat-requested snoozes that do not match one of the
/// fixed UI choices. Their exact length remains in
/// [NudgeSnooze.durationMinutes].
enum NudgeBannerSnoozeDuration {
  oneHour,
  threeHours,
  sixHours,
  eightHours,
  custom,
}

extension NudgeBannerSnoozeDurationValue on NudgeBannerSnoozeDuration {
  Duration? get duration => switch (this) {
    NudgeBannerSnoozeDuration.oneHour => const Duration(hours: 1),
    NudgeBannerSnoozeDuration.threeHours => const Duration(hours: 3),
    NudgeBannerSnoozeDuration.sixHours => const Duration(hours: 6),
    NudgeBannerSnoozeDuration.eightHours => const Duration(hours: 8),
    NudgeBannerSnoozeDuration.custom => null,
  };
}

NudgeBannerSnoozeDuration nudgeBannerSnoozeDurationFor(Duration duration) =>
    NudgeBannerSnoozeDuration.values.firstWhere(
      (preset) => preset.duration == duration,
      orElse: () => NudgeBannerSnoozeDuration.custom,
    );

/// The typed banner brief — everything a nudge banner IS (ADR 0058).
///
/// The model authors the copy and picks presentation presets; the app
/// renders it procedurally. No image provider exists in this channel.
/// Copy fields are the only model text that reaches a surface verbatim,
/// so they are what the leakage lint and evals police (the ADR 0056
/// principle, retargeted at text).
@freezed
abstract class NudgeBrief with _$NudgeBrief {
  const factory NudgeBrief({
    required String headline,
    required NudgeTone tone,
    required NudgeBannerAnimation animation,
    @Default(NudgeBannerAccent.calm) NudgeBannerAccent accent,
    String? tagline,
    String? cta,
  }) = _NudgeBrief;

  factory NudgeBrief.fromJson(Map<String, dynamic> json) =>
      _$NudgeBriefFromJson(json);
}

/// One rating-prompt outcome for one activation of a nudge banner.
///
/// Ratings are a HISTORY, not a single value (ADR 0055 Decision 7): each
/// re-run ([activation] is the 1-based run index) prompts anew, and the
/// trajectory across runs detects wear-out. A [skipped] entry records that
/// the prompt was shown and declined for that activation — which is what
/// lets the UI prompt exactly once per run instead of nagging or wrongly
/// suppressing the next run.
@freezed
abstract class NudgeRating with _$NudgeRating {
  const factory NudgeRating({
    /// Which run of this banner the outcome belongs to (1-based).
    @JsonKey(fromJson: _decodeActivation) required int activation,
    required DateTime ratedAt,

    /// 1 (useless) .. 5 (loved it); null iff [skipped].
    @JsonKey(fromJson: _decodeRating) int? rating,
    @Default(false) bool skipped,
  }) = _NudgeRating;

  factory NudgeRating.fromJson(Map<String, dynamic> json) =>
      _$NudgeRatingFromJson(json);
}

/// One durable snooze interaction for one banner activation.
///
/// The UTC instants preserve ordering and expiry semantics across devices.
/// [utcOffsetMinutes] preserves the wall-clock context in which the user made
/// the choice. [returnUtcOffsetMinutes] separately preserves the requested
/// return wall time when the snooze crosses a daylight-saving boundary or was
/// requested with another explicit offset.
@freezed
abstract class NudgeSnooze with _$NudgeSnooze {
  const factory NudgeSnooze({
    required String id,
    @JsonKey(fromJson: _decodeActivation) required int activation,
    required DateTime snoozedAt,
    required DateTime snoozedUntil,
    required NudgeBannerSnoozeDuration duration,
    @JsonKey(fromJson: _decodePositiveMinutes) required int durationMinutes,
    @JsonKey(fromJson: _decodeUtcOffsetMinutes) required int utcOffsetMinutes,
    @JsonKey(fromJson: _decodeOptionalUtcOffsetMinutes)
    int? returnUtcOffsetMinutes,
  }) = _NudgeSnooze;

  const NudgeSnooze._();

  factory NudgeSnooze.fromJson(Map<String, dynamic> json) =>
      _$NudgeSnoozeFromJson(json);

  /// The recorded local wall-clock value represented as a zone-free UTC
  /// [DateTime], so consumers can read its components without applying the
  /// current device timezone.
  DateTime get snoozedAtLocal =>
      snoozedAt.toUtc().add(Duration(minutes: utcOffsetMinutes));

  /// The requested return time in the same recorded wall-clock convention as
  /// [snoozedAtLocal]. Older events fall back to the action-time offset.
  DateTime get snoozedUntilLocal => snoozedUntil.toUtc().add(
    Duration(minutes: returnUtcOffsetMinutes ?? utcOffsetMinutes),
  );
}

/// One durable "dismiss for today" interaction for one banner activation.
///
/// The current visibility gate remains on the owning nudge entity; this
/// append-only event preserves how often and at which local times the user
/// chooses the day-scoped escape hatch so future agent wakes can learn from
/// the pattern.
@freezed
abstract class NudgeDayDismissal with _$NudgeDayDismissal {
  const factory NudgeDayDismissal({
    required String id,
    @JsonKey(fromJson: _decodeActivation) required int activation,
    required DateTime dismissedAt,
    required DateTime dismissedUntil,
    @JsonKey(fromJson: _decodeUtcOffsetMinutes) required int utcOffsetMinutes,
  }) = _NudgeDayDismissal;

  const NudgeDayDismissal._();

  factory NudgeDayDismissal.fromJson(Map<String, dynamic> json) =>
      _$NudgeDayDismissalFromJson(json);

  DateTime get dismissedAtLocal =>
      dismissedAt.toUtc().add(Duration(minutes: utcOffsetMinutes));
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

int? _decodeOptionalUtcOffsetMinutes(Object? raw) =>
    raw == null ? null : _decodeUtcOffsetMinutes(raw);

/// Cross-field issues in a raw rating payload — what the per-field
/// converters cannot see. Constructor assertions are deliberately NOT the
/// boundary (they vanish in release builds); the decode gate in
/// `AgentDbConversions.fromSerialized` calls this and refuses the payload
/// with a [FormatException], and write paths validate at the service layer.
List<String> nudgeRatingJsonIssues(Map<String, dynamic> json) {
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

final _explicitIso8601Offset = RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$');

bool _hasExplicitIso8601Offset(String value) =>
    _explicitIso8601Offset.hasMatch(value);

/// Cross-field issues in a raw snooze event payload.
List<String> nudgeSnoozeJsonIssues(Map<String, dynamic> json) {
  final snoozedAtRaw = json['snoozedAt']?.toString() ?? '';
  final snoozedUntilRaw = json['snoozedUntil']?.toString() ?? '';
  if (!_hasExplicitIso8601Offset(snoozedAtRaw) ||
      !_hasExplicitIso8601Offset(snoozedUntilRaw)) {
    return const ['snooze timestamps must include an explicit UTC offset'];
  }
  final snoozedAt = DateTime.tryParse(snoozedAtRaw);
  final snoozedUntil = DateTime.tryParse(snoozedUntilRaw);
  if (snoozedAt == null || snoozedUntil == null) {
    return const ['snooze timestamps must be valid ISO-8601 instants'];
  }
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

/// Cross-field issues in a raw day-dismissal event payload.
List<String> nudgeDayDismissalJsonIssues(Map<String, dynamic> json) {
  final dismissedAtRaw = json['dismissedAt']?.toString() ?? '';
  final dismissedUntilRaw = json['dismissedUntil']?.toString() ?? '';
  if (!_hasExplicitIso8601Offset(dismissedAtRaw) ||
      !_hasExplicitIso8601Offset(dismissedUntilRaw)) {
    return const [
      'day-dismissal timestamps must include an explicit UTC offset',
    ];
  }
  final dismissedAt = DateTime.tryParse(dismissedAtRaw);
  final dismissedUntil = DateTime.tryParse(dismissedUntilRaw);
  if (dismissedAt == null || dismissedUntil == null) {
    return const [
      'day-dismissal timestamps must be valid ISO-8601 instants',
    ];
  }
  if (!dismissedUntil.toUtc().isAfter(dismissedAt.toUtc())) {
    return const ['dismissedUntil must be after dismissedAt'];
  }
  return const [];
}
