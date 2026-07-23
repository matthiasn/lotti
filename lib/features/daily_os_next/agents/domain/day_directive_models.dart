// Structured models carried by the ADR 0032 phase-3 coordination entities:
// the coordinator-issued day directive (downward) and per-day status events
// (upward). See docs/implementation_plans/
// 2026-07-22_day_agent_directive_status_protocol.md.

import 'package:collection/collection.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:meta/meta.dart';

/// Where a directive commitment originates (ADR 0032 §2).
enum DayCommitmentSource {
  /// A proposed/accepted attention award (ADR 0019/0021).
  attentionAward,

  /// A standing agreement's cadence obligation.
  standingAgreement,

  /// A commitment the user stated explicitly.
  userCommitment,

  /// Carried over from an earlier day.
  carryOver,
}

/// Overall day status raised by the day-owner agent (ADR 0032 §2).
enum DayStatusKind {
  /// The day is proceeding per plan/directive.
  onTrack,

  /// The coordinator (and user) should look — see the typed reasons.
  attentionNeeded,

  /// The day is done; distilled artifacts are final.
  dayClosed,
}

/// Typed reason accompanying [DayStatusKind.attentionNeeded].
enum DayStatusReason {
  /// Requested work exceeds the day's capacity budget.
  overCommitted,

  /// A directive commitment cannot be represented, traded, or satisfied.
  directiveUnsatisfiable,

  /// The user's recorded activity diverges materially from the plan.
  userDivergence,

  /// A processing dependency (transcription, parsing) is blocked.
  processingBlocked,
}

/// One commitment the coordinator distilled into the day's directive.
///
/// Binding, not a hint: the per-day agent's contract requires each commitment
/// to be represented in the plan, explicitly traded away in a proposed diff,
/// or escalated via a status event — never silently dropped.
@immutable
class DayDirectiveCommitment {
  /// Creates a directive commitment.
  const DayDirectiveCommitment({
    required this.id,
    required this.source,
    required this.title,
    this.windowStart,
    this.windowEnd,
    this.minutes,
    this.evidenceRefs = const [],
  });

  /// Creates a commitment from JSON.
  factory DayDirectiveCommitment.fromJson(Map<String, dynamic> json) {
    return DayDirectiveCommitment(
      id: json['id'] as String,
      source: DayCommitmentSource.values.byName(json['source'] as String),
      title: json['title'] as String,
      windowStart: json['windowStart'] == null
          ? null
          : DateTime.parse(json['windowStart'] as String),
      windowEnd: json['windowEnd'] == null
          ? null
          : DateTime.parse(json['windowEnd'] as String),
      minutes: json['minutes'] as int?,
      evidenceRefs:
          (json['evidenceRefs'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  /// Stable id of the underlying source record (award id, agreement id,
  /// task id, …) so revisions of the directive keep referring to the same
  /// commitment.
  final String id;

  /// Origin of the commitment.
  final DayCommitmentSource source;

  /// Human-readable commitment title.
  final String title;

  /// Optional window the commitment must land in.
  final DateTime? windowStart;

  /// Optional window end.
  final DateTime? windowEnd;

  /// Estimated minutes the commitment consumes, when known.
  final int? minutes;

  /// Entity ids evidencing the commitment (awards, agreements, tasks).
  final List<String> evidenceRefs;

  /// Converts this commitment to JSON.
  Map<String, Object?> toJson() => {
    'id': id,
    'source': source.name,
    'title': title,
    if (windowStart != null) 'windowStart': windowStart!.toIso8601String(),
    if (windowEnd != null) 'windowEnd': windowEnd!.toIso8601String(),
    if (minutes != null) 'minutes': minutes,
    'evidenceRefs': evidenceRefs,
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DayDirectiveCommitment &&
            other.id == id &&
            other.source == source &&
            other.title == title &&
            other.windowStart == windowStart &&
            other.windowEnd == windowEnd &&
            other.minutes == minutes &&
            const ListEquality<String>().equals(
              other.evidenceRefs,
              evidenceRefs,
            );
  }

  @override
  int get hashCode => Object.hash(
    id,
    source,
    title,
    windowStart,
    windowEnd,
    minutes,
    const ListEquality<String>().hash(evidenceRefs),
  );
}

/// The day's capacity budget as distilled by the coordinator.
@immutable
class DayCapacityBudget {
  /// Creates a capacity budget.
  const DayCapacityBudget({
    required this.availableMinutes,
    this.alreadyScheduledMinutes = 0,
    this.energyBands = const [],
  });

  /// Creates a capacity budget from JSON.
  factory DayCapacityBudget.fromJson(Map<String, dynamic> json) {
    return DayCapacityBudget(
      availableMinutes: json['availableMinutes'] as int,
      alreadyScheduledMinutes: json['alreadyScheduledMinutes'] as int? ?? 0,
      energyBands:
          (json['energyBands'] as List<dynamic>?)
              ?.map(
                (band) =>
                    DayAgentEnergyBand.fromJson(band as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }

  /// Total plannable minutes for the day.
  final int availableMinutes;

  /// Minutes already consumed by committed blocks when the directive was
  /// issued.
  final int alreadyScheduledMinutes;

  /// Expected energy contour, when the coordinator knows it.
  final List<DayAgentEnergyBand> energyBands;

  /// Converts this budget to JSON.
  Map<String, Object?> toJson() => {
    'availableMinutes': availableMinutes,
    'alreadyScheduledMinutes': alreadyScheduledMinutes,
    'energyBands': [for (final band in energyBands) band.toJson()],
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DayCapacityBudget &&
            other.availableMinutes == availableMinutes &&
            other.alreadyScheduledMinutes == alreadyScheduledMinutes &&
            const ListEquality<DayAgentEnergyBand>().equals(
              other.energyBands,
              energyBands,
            );
  }

  @override
  int get hashCode => Object.hash(
    availableMinutes,
    alreadyScheduledMinutes,
    const ListEquality<DayAgentEnergyBand>().hash(energyBands),
  );
}

/// One item the coordinator carries over into this day's directive.
@immutable
class DayCarryOverItem {
  /// Creates a carry-over item.
  const DayCarryOverItem({
    required this.title,
    required this.reason,
    this.taskId,
    this.itemId,
  });

  /// Creates a carry-over item from JSON.
  factory DayCarryOverItem.fromJson(Map<String, dynamic> json) {
    return DayCarryOverItem(
      title: json['title'] as String,
      reason: json['reason'] as String,
      taskId: json['taskId'] as String?,
      itemId: json['itemId'] as String?,
    );
  }

  /// Display title of the carried-over work.
  final String title;

  /// Why it carries over (bounded freeform).
  final String reason;

  /// Backing task id, when the work is a real task.
  final String? taskId;

  /// Backing parsed-item id, when the work never became a task.
  final String? itemId;

  /// Converts this item to JSON.
  Map<String, Object?> toJson() => {
    'title': title,
    'reason': reason,
    if (taskId != null) 'taskId': taskId,
    if (itemId != null) 'itemId': itemId,
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DayCarryOverItem &&
            other.title == title &&
            other.reason == reason &&
            other.taskId == taskId &&
            other.itemId == itemId;
  }

  @override
  int get hashCode => Object.hash(title, reason, taskId, itemId);
}
