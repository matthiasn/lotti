import 'package:meta/meta.dart';

/// Kind of scarce-attention request an agent is making to the planner.
enum AttentionRequestKind {
  /// A concrete task wants a scheduled focus block.
  task,

  /// A project wants a scheduled focus or review block.
  project,

  /// A project phase emits a recurring or phase-specific request.
  projectPhase,

  /// A long-term outcome wants protection of a leading indicator.
  outcome,

  /// Runtime maintenance, such as review or cleanup.
  maintenance,
}

/// Energy requirement declared by a request.
enum AttentionEnergyFit {
  /// Can be handled in low-energy time.
  low,

  /// No strong energy preference.
  neutral,

  /// Requires a high-focus or second-wind slot.
  high,
}

/// Lifecycle for an attention request event.
enum AttentionRequestStatus {
  /// Awaiting planner arbitration.
  pending,

  /// The requester withdrew the ask before arbitration.
  withdrawn,

  /// A planner emitted an award for this request.
  awarded,

  /// A planner rejected the request.
  rejected,
}

/// Lifecycle for a planner award.
enum AttentionAwardStatus {
  /// Proposed by a planner; still human-gated downstream.
  proposed,

  /// The user accepted the downstream ChangeSet.
  accepted,

  /// The user rejected the downstream ChangeSet.
  rejected,

  /// A newer award superseded this proposal.
  superseded,
}

/// Planning scope for an attention claim.
enum AttentionClaimScopeKind {
  /// Claim is visible across one calendar-day-sized planning window.
  day,

  /// Claim may be scheduled anywhere inside a bounded date/time range.
  dateRange,

  /// Claim must be satisfied before a deadline.
  deadline,

  /// Claim describes a recurring need inside a cadence/range.
  recurrence,
}

/// Projected lifecycle state for an attention claim.
enum AttentionClaimStatus {
  /// Claim is open and can be considered by a planner.
  open,

  /// Claim is included in a planner proposal that has not been accepted yet.
  proposed,

  /// Claim has been fully satisfied by accepted plan changes or actuals.
  satisfied,

  /// Claim has been partly satisfied and may still need planner attention.
  partiallySatisfied,

  /// Planner/user chose not to schedule this claim.
  declined,

  /// Planner deferred this claim for later reconsideration.
  deferred,

  /// A newer claim replaces this one.
  superseded,

  /// Claim's useful scheduling window passed.
  expired,

  /// Originating agent withdrew the claim.
  withdrawn,
}

/// Durable user-agreement domain a planner should consider.
enum StandingAgreementScope {
  /// Fitness, exercise, steps, workouts, or recovery.
  fitness,

  /// Sleep timing, wind-down, and wake consistency.
  sleep,

  /// Paperwork, admin, taxes, finance chores, or filing.
  paperwork,

  /// Focus time for concrete tasks.
  taskWork,

  /// Focus or review time for projects.
  projectWork,

  /// Operational maintenance and lightweight check-ins.
  maintenance,

  /// Money or financial outcome guardrails.
  finances,

  /// Forward-compatible custom agreement.
  custom,
}

/// Lifecycle for a standing agreement.
enum StandingAgreementStatus {
  /// Agreement should be considered by planners.
  active,

  /// Agreement exists but should not currently influence planning.
  paused,

  /// Agreement is kept for audit/history only.
  retired,
}

/// Cadence over which an agreement's quota should be evaluated.
enum StandingAgreementCadence {
  /// Repeats each day.
  daily,

  /// Repeats each week.
  weekly,

  /// Repeats each month.
  monthly,

  /// Repeats each quarter.
  quarterly,

  /// Repeats each year.
  yearly,

  /// Agreement-specific cadence captured in `customCadence`.
  custom,
}

/// How strongly a planner should treat an agreement.
enum StandingAgreementEnforcement {
  /// Preference: useful context, but easy to trade off.
  preference,

  /// Target: planner should try to satisfy this unless there is a good reason.
  target,

  /// Non-negotiable: violating proposals need hard validation/user override.
  nonNegotiable,
}

/// Trust boundary for planner proposals governed by an agreement.
enum StandingAgreementApprovalMode {
  /// Low-risk matching proposals may be accepted without interrupting the user.
  autoAccept,

  /// Matching proposals should be shown to the user for approval.
  ask,

  /// Matching proposals are blocked unless a later override changes policy.
  reject,
}

/// Type of evidence backing an attention request.
enum AttentionEvidenceKind {
  /// Journal task entity.
  task,

  /// Project entity.
  project,

  /// Existing day plan.
  dayPlan,

  /// Agent report or summary.
  report,

  /// Daily OS capture.
  capture,

  /// Generic journal entity.
  journalEntry,

  /// Health/fitness actual.
  health,

  /// Outcome or leading-indicator record.
  outcome,

  /// Forward-compatible custom evidence.
  custom,
}

/// Stable reference to evidence the planner can inspect when ranking a bid.
@immutable
class AttentionEvidenceRef {
  /// Creates an evidence reference.
  const AttentionEvidenceRef({
    required this.kind,
    required this.id,
    this.label,
  });

  /// Creates an evidence reference from JSON.
  factory AttentionEvidenceRef.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind'] as String;
    final kind = AttentionEvidenceKind.values.firstWhere(
      (e) => e.name == kindName,
      orElse: () => AttentionEvidenceKind.custom,
    );
    return AttentionEvidenceRef(
      kind: kind,
      id: json['id'] as String,
      label: json['label'] as String?,
    );
  }

  /// Evidence source kind.
  final AttentionEvidenceKind kind;

  /// Stable source entity id.
  final String id;

  /// Optional short human-readable label captured at request time.
  final String? label;

  /// Converts this evidence reference to JSON.
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'id': id,
    'label': label,
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AttentionEvidenceRef &&
            other.kind == kind &&
            other.id == id &&
            other.label == label;
  }

  @override
  int get hashCode => Object.hash(kind, id, label);
}
