import 'package:equatable/equatable.dart';
import 'package:lotti/features/agents/projection/agent_event.dart';

/// Derived state folded from a canonically-ordered event sequence.
///
/// Every field is *structural* — computed from event ids and the
/// [AgentEvent.causalParents] graph alone, with no reference to vector clocks
/// or wall-clock time. Combined with `canonicalOrder`, the projection is a pure
/// function of the underlying event set: two devices holding the same events
/// compute an equal [AgentProjection] regardless of arrival order.
class AgentProjection extends Equatable {
  /// Creates a projection. Callers normally obtain one from [project].
  const AgentProjection({
    required this.headIds,
    required this.latestReportId,
    required this.danglingParentIds,
  });

  /// Ids of events that no *present* event references as a `causalParent` —
  /// the tips of the DAG. A single chain yields one head; a fork yields ≥2.
  /// Listed in canonical order (their position in the ordered input).
  final List<String> headIds;

  /// Id of the last [AgentEventKind.report] event in canonical order, or null
  /// if the set contains no report.
  final String? latestReportId;

  /// Parent ids referenced by some event's [AgentEvent.causalParents] but
  /// absent from the input — a partial sync window or a compacted-away parent.
  /// Surfaced as a structural diagnostic; sorted for determinism. Never causes
  /// a crash.
  final List<String> danglingParentIds;

  @override
  List<Object?> get props => [headIds, latestReportId, danglingParentIds];
}

/// Folds a canonically-ordered event sequence into derived [AgentProjection]
/// state.
///
/// Pure function of the ordered list — no clocks, no I/O. [ordered] is expected
/// to be the output of `canonicalOrder`; the fold preserves that order when
/// emitting [AgentProjection.headIds] and when picking the latest report.
AgentProjection project(Iterable<AgentEvent> ordered) {
  final events = ordered.toList(growable: false);
  final presentIds = {for (final event in events) event.id};

  final referencedAsParent = <String>{};
  final danglingParents = <String>{};
  for (final event in events) {
    for (final parentId in event.causalParents) {
      if (presentIds.contains(parentId)) {
        referencedAsParent.add(parentId);
      } else {
        danglingParents.add(parentId);
      }
    }
  }

  final headIds = <String>[];
  String? latestReportId;
  for (final event in events) {
    if (!referencedAsParent.contains(event.id)) {
      headIds.add(event.id);
    }
    if (event.kind == AgentEventKind.report) {
      latestReportId = event.id;
    }
  }

  return AgentProjection(
    headIds: headIds,
    latestReportId: latestReportId,
    danglingParentIds: danglingParents.toList()..sort(),
  );
}
