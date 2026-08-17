import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/sync/g_counter.dart';

/// Sentinel distinguishing "not passed" from "explicitly null" in
/// [NudgeEntityView.copyWith] — the same trick freezed uses, needed here
/// because a day-dismissal clears `snoozedUntil` and a snooze clears
/// `dismissedForDayAt`.
const _unset = Object();

/// A kind-agnostic view over any nudge variant of [AgentDomainEntity]
/// (ADR 0059).
///
/// [GoalNudgeEntity] and [RelationshipNudgeEntity] are siblings in the
/// freezed union with identical banner-facing fields but no shared
/// supertype, so the banner substrate — visibility logic, interactions,
/// widgets — reads and writes through this zero-cost view instead of
/// duplicating itself per variant. `of` is the only gate: a non-nudge
/// entity never becomes a view.
extension type NudgeEntityView._(AgentDomainEntity entity) {
  /// Wraps a nudge variant, or returns null for any other entity.
  static NudgeEntityView? of(AgentDomainEntity entity) => switch (entity) {
    GoalNudgeEntity() || RelationshipNudgeEntity() => NudgeEntityView._(entity),
    _ => null,
  };

  T _fold<T>(
    T Function(GoalNudgeEntity e) goal,
    T Function(RelationshipNudgeEntity e) relationship,
  ) => switch (entity) {
    final GoalNudgeEntity e => goal(e),
    final RelationshipNudgeEntity e => relationship(e),
    // Unreachable: `of` is the only constructor path. The ignore must span
    // every line of the throw — an `ignore-line` on the closing paren leaves
    // the `throw` itself counted, which is what made this arm the patch's
    // only uncovered lines.
    // coverage:ignore-start
    _ => throw StateError('not a nudge variant: ${entity.runtimeType}'),
    // coverage:ignore-end
  };

  String get id => _fold((e) => e.id, (e) => e.id);
  String get agentId => _fold((e) => e.agentId, (e) => e.agentId);
  NudgeStatus get status => _fold((e) => e.status, (e) => e.status);
  NudgeBrief get brief => _fold((e) => e.brief, (e) => e.brief);
  DateTime get createdAt => _fold((e) => e.createdAt, (e) => e.createdAt);
  DateTime? get activatedAt =>
      _fold((e) => e.activatedAt, (e) => e.activatedAt);
  DateTime? get staleAt => _fold((e) => e.staleAt, (e) => e.staleAt);
  DateTime? get snoozedUntil =>
      _fold((e) => e.snoozedUntil, (e) => e.snoozedUntil);
  DateTime? get dismissedForDayAt =>
      _fold((e) => e.dismissedForDayAt, (e) => e.dismissedForDayAt);
  NudgeBannerSnoozeDuration? get lastSnoozeDuration =>
      _fold((e) => e.lastSnoozeDuration, (e) => e.lastSnoozeDuration);
  int get activationCount =>
      _fold((e) => e.activationCount, (e) => e.activationCount);
  List<NudgeRating> get ratings => _fold((e) => e.ratings, (e) => e.ratings);
  List<NudgeSnooze> get snoozeHistory =>
      _fold((e) => e.snoozeHistory, (e) => e.snoozeHistory);
  List<NudgeDayDismissal> get dismissalHistory =>
      _fold((e) => e.dismissalHistory, (e) => e.dismissalHistory);
  GCounter get totalVisibleMs =>
      _fold((e) => e.totalVisibleMs, (e) => e.totalVisibleMs);
  GCounter get impressionCount =>
      _fold((e) => e.impressionCount, (e) => e.impressionCount);
  DateTime? get firstShownAt =>
      _fold((e) => e.firstShownAt, (e) => e.firstShownAt);
  Map<String, String> get provenance =>
      _fold((e) => e.provenance, (e) => e.provenance);

  /// Copies the banner-facing fields onto the underlying variant.
  ///
  /// Only the fields the substrate writes are exposed; `snoozedUntil` and
  /// `dismissedForDayAt` accept an explicit null (see [_unset]).
  AgentDomainEntity copyWith({
    Object? snoozedUntil = _unset,
    Object? dismissedForDayAt = _unset,
    NudgeBannerSnoozeDuration? lastSnoozeDuration,
    List<NudgeSnooze>? snoozeHistory,
    List<NudgeDayDismissal>? dismissalHistory,
    List<NudgeRating>? ratings,
    DateTime? staleAt,
    DateTime? updatedAt,
    Map<String, String>? provenance,
    GCounter? totalVisibleMs,
    GCounter? impressionCount,
    DateTime? firstShownAt,
    DateTime? lastShownAt,
  }) => _fold(
    (e) => e.copyWith(
      snoozedUntil: snoozedUntil == _unset
          ? e.snoozedUntil
          : snoozedUntil as DateTime?,
      dismissedForDayAt: dismissedForDayAt == _unset
          ? e.dismissedForDayAt
          : dismissedForDayAt as DateTime?,
      lastSnoozeDuration: lastSnoozeDuration ?? e.lastSnoozeDuration,
      snoozeHistory: snoozeHistory ?? e.snoozeHistory,
      dismissalHistory: dismissalHistory ?? e.dismissalHistory,
      ratings: ratings ?? e.ratings,
      staleAt: staleAt ?? e.staleAt,
      updatedAt: updatedAt ?? e.updatedAt,
      provenance: provenance ?? e.provenance,
      totalVisibleMs: totalVisibleMs ?? e.totalVisibleMs,
      impressionCount: impressionCount ?? e.impressionCount,
      firstShownAt: firstShownAt ?? e.firstShownAt,
      lastShownAt: lastShownAt ?? e.lastShownAt,
    ),
    (e) => e.copyWith(
      snoozedUntil: snoozedUntil == _unset
          ? e.snoozedUntil
          : snoozedUntil as DateTime?,
      dismissedForDayAt: dismissedForDayAt == _unset
          ? e.dismissedForDayAt
          : dismissedForDayAt as DateTime?,
      lastSnoozeDuration: lastSnoozeDuration ?? e.lastSnoozeDuration,
      snoozeHistory: snoozeHistory ?? e.snoozeHistory,
      dismissalHistory: dismissalHistory ?? e.dismissalHistory,
      ratings: ratings ?? e.ratings,
      staleAt: staleAt ?? e.staleAt,
      updatedAt: updatedAt ?? e.updatedAt,
      provenance: provenance ?? e.provenance,
      totalVisibleMs: totalVisibleMs ?? e.totalVisibleMs,
      impressionCount: impressionCount ?? e.impressionCount,
      firstShownAt: firstShownAt ?? e.firstShownAt,
      lastShownAt: lastShownAt ?? e.lastShownAt,
    ),
  );
}
