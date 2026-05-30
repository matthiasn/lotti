import 'package:equatable/equatable.dart';
import 'package:lotti/features/agents/projection/agent_event.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// A single vector-clock inconsistency: a present parent edge whose child does
/// not strictly dominate its parent in vector-clock order.
///
/// A well-formed log always has `child.vc` strictly dominating each parent's
/// `vc`. Anything else — equal, dominated, or concurrent — is a data-quality
/// signal for PR 3 to reconcile, not a kernel crash.
class VcInconsistency extends Equatable {
  /// Creates a diagnostic for the [childId] → [parentId] edge, recording the
  /// actual [status] of `compare(child.vc, parent.vc)`.
  const VcInconsistency({
    required this.childId,
    required this.parentId,
    required this.status,
  });

  /// The child event (the one declaring the parent edge).
  final String childId;

  /// The parent event referenced by the edge.
  final String parentId;

  /// The actual comparison result, which is anything other than
  /// [VclockStatus.a_gt_b] (strict child-dominates-parent).
  final VclockStatus status;

  @override
  List<Object?> get props => [childId, parentId, status];

  @override
  String toString() => 'VcInconsistency($childId -> $parentId: ${status.name})';
}

/// Reports every present parent edge whose vector clocks are inconsistent with
/// the declared causal direction.
///
/// Kept deliberately out of the `project` fold so that fold stays clock-free
/// and purely structural. For each event and each *distinct, present* parent,
/// the edge is consistent iff `compare(child.vc, parent.vc)` is
/// [VclockStatus.a_gt_b]; every other result yields a [VcInconsistency].
/// Dangling parents (absent from [events]) are skipped — they surface via
/// `AgentProjection.danglingParentIds` instead. The result is sorted by
/// `(childId, parentId)` for determinism.
List<VcInconsistency> diagnoseVectorClocks(Iterable<AgentEvent> events) {
  final byId = {for (final event in events) event.id: event};
  final inconsistencies = <VcInconsistency>[];

  for (final event in events) {
    // causalParents is normalized sorted-unique by AgentEvent's constructor.
    for (final parentId in event.causalParents) {
      final parent = byId[parentId];
      if (parent == null) continue; // dangling — not a VC concern
      final status = VectorClock.compare(
        event.vectorClock,
        parent.vectorClock,
      );
      if (status != VclockStatus.a_gt_b) {
        inconsistencies.add(
          VcInconsistency(
            childId: event.id,
            parentId: parentId,
            status: status,
          ),
        );
      }
    }
  }

  inconsistencies.sort((a, b) {
    final byChild = a.childId.compareTo(b.childId);
    if (byChild != 0) return byChild;
    return a.parentId.compareTo(b.parentId);
  });
  return inconsistencies;
}
