import 'package:equatable/equatable.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/projection/agent_event_adapter.dart';
import 'package:lotti/features/agents/projection/agent_projection.dart';
import 'package:lotti/features/agents/projection/canonical_order.dart';

/// Outcome of comparing the kernel projection against the live mutable state.
enum ShadowProjectionStatus {
  /// Exactly one projected head and it equals the live head pointer — the
  /// projection reproduces live state.
  match,

  /// Two or more projected heads while the live state tracks one of them (a
  /// non-null `recentHeadMessageId`). This is *expected* divergence under
  /// concurrent multi-device appends, not a defect (the projection is the
  /// more-correct view).
  forked,

  /// A genuine mismatch worth surfacing: a single projected head that does not
  /// equal the live head, a live head with no corresponding log, or a non-empty
  /// projection while the live state tracks no head at all (`liveHeadId` null).
  mismatch,

  /// No events and no live head — nothing to compare (e.g. a fresh agent).
  empty,

  /// `canonicalOrder`/`project` threw (duplicate id, cycle) — a structural
  /// upstream defect. Captured rather than thrown so a shadow check never
  /// crashes a production path.
  error,
}

/// A read-only comparison of the shadow projection against live state. Never
/// drives a production read; used as a test assertion and, optionally, a
/// debug-mode runtime check.
class ShadowProjectionReport extends Equatable {
  /// Creates a report. Callers normally obtain one from
  /// [compareShadowProjection].
  const ShadowProjectionReport({
    required this.status,
    required this.projectedHeadIds,
    required this.liveHeadId,
    required this.danglingParentIds,
    this.error,
  });

  /// How the projection compares to live state.
  final ShadowProjectionStatus status;

  /// Heads computed by the projection (the DAG tips), in canonical order.
  final List<String> projectedHeadIds;

  /// The live `AgentStateEntity.recentHeadMessageId` the projection is compared
  /// against (null when the live state has no head yet).
  final String? liveHeadId;

  /// Parent ids referenced by the log but absent from it (diagnostic).
  final List<String> danglingParentIds;

  /// The captured exception string when [status] is
  /// [ShadowProjectionStatus.error]; null otherwise.
  final String? error;

  @override
  List<Object?> get props => [
    status,
    projectedHeadIds,
    liveHeadId,
    danglingParentIds,
    error,
  ];
}

/// Computes the kernel projection from the live agent log ([messages] + their
/// `messagePrev` [links]) and compares it against [liveHeadId] (the live
/// `recentHeadMessageId`). Pure and non-throwing — structural failures are
/// reported as [ShadowProjectionStatus.error].
ShadowProjectionReport compareShadowProjection({
  required Iterable<AgentMessageEntity> messages,
  required Iterable<AgentLink> links,
  required String? liveHeadId,
  String Function(AgentMessageEntity message)? hostIdOf,
}) {
  try {
    // Inside the try: `messages`/`links` may be lazy (DB-backed) iterables and
    // `hostIdOf` is caller-supplied, so building the events can throw too.
    final events = agentEventsFromLog(messages, links, hostIdOf: hostIdOf);
    final projection = project(canonicalOrder(events));
    return ShadowProjectionReport(
      status: _statusFor(projection.headIds, liveHeadId),
      projectedHeadIds: projection.headIds,
      liveHeadId: liveHeadId,
      danglingParentIds: projection.danglingParentIds,
    );
    // Catch everything (Error as well as Exception): canonicalOrder/project
    // throwing here is a structural upstream defect, and a shadow check must
    // never crash a production path. Surfaced as `error` instead.
  } catch (e) {
    return ShadowProjectionReport(
      status: ShadowProjectionStatus.error,
      projectedHeadIds: const [],
      liveHeadId: liveHeadId,
      danglingParentIds: const [],
      error: e.toString(),
    );
  }
}

ShadowProjectionStatus _statusFor(List<String> heads, String? liveHeadId) {
  if (heads.isEmpty) {
    return liveHeadId == null
        ? ShadowProjectionStatus.empty
        : ShadowProjectionStatus.mismatch;
  }
  // The live head must actually be one of the projected tips. A null live head,
  // or one pointing at a non-tip (e.g. a stale parent), is a genuine mismatch —
  // `forked`/`match` only apply when live tracks an actual tip.
  if (liveHeadId == null || !heads.contains(liveHeadId)) {
    return ShadowProjectionStatus.mismatch;
  }
  return heads.length > 1
      ? ShadowProjectionStatus.forked
      : ShadowProjectionStatus.match;
}
