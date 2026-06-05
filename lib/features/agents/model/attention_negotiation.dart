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
  /// Proposed by deterministic arbitration; still human-gated downstream.
  proposed,

  /// The user accepted the downstream ChangeSet.
  accepted,

  /// The user rejected the downstream ChangeSet.
  rejected,

  /// A newer award superseded this proposal.
  superseded,
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
