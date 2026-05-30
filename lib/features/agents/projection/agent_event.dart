import 'package:equatable/equatable.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:meta/meta.dart';

/// Kind of an agent-log event, as the projection kernel sees it.
///
/// This is intentionally decoupled from the storage-layer `AgentMessageKind`:
/// the kernel only needs the coarse categories its fold reasons about. A thin
/// adapter (PR 3) maps storage rows onto these.
enum AgentEventKind {
  /// A conversational/log message (user, thought, action, tool result, …).
  message,

  /// A published report snapshot.
  report,

  /// An agent observation (private working note).
  observation,

  /// A compaction summary spanning a range of earlier events.
  summary,
}

/// Minimal, storage-independent causal view of one agent-log event.
///
/// The projection kernel operates exclusively on sets of [AgentEvent]s; heavy
/// payloads stay out (referenced by [id]). Causality is carried by
/// [causalParents] — the canonical `messagePrev` graph — while [vectorClock] is
/// *consistency metadata* that the kernel diagnoses but never orders by. See
/// `canonical_order.dart` for the ordering contract.
///
/// Two [AgentEvent]s are equal iff every field is equal (value semantics via
/// [Equatable]); identical events therefore collapse when unioned into a set,
/// while two events sharing an [id] but differing elsewhere remain distinct and
/// are rejected as a duplicate id by the kernel.
@immutable
class AgentEvent extends Equatable {
  /// Creates an immutable event view. [causalParents] is **normalized to a
  /// sorted, de-duplicated, unmodifiable list**: parent order carries no
  /// meaning (it is a *set* of parents), so two events that differ only in
  /// parent ordering or repeated parents are the same logical event and compare
  /// equal — otherwise the same graph synced from two devices would falsely
  /// trip duplicate-id rejection in `canonicalOrder`.
  AgentEvent({
    required this.id,
    required this.hostId,
    required this.vectorClock,
    required this.kind,
    List<String> causalParents = const [],
  }) : causalParents = causalParents.isEmpty
           ? const <String>[]
           : List.unmodifiable(causalParents.toSet().toList()..sort());

  /// Stable, globally-unique identifier (a UUID in production).
  final String id;

  /// Authoring host — the secondary key in the `(hostId, id)` tiebreak used to
  /// order concurrent events deterministically.
  final String hostId;

  /// Causal stamp. Consistency metadata only: the kernel reports edges whose
  /// vector clocks are inconsistent (see `projection_diagnostics.dart`) but
  /// does not order by it.
  final VectorClock vectorClock;

  /// Ids of this event's `messagePrev` parents (0..n; n > 1 denotes a join),
  /// normalized to sorted-unique by the constructor. This is the single source
  /// of truth for causal ordering and head detection.
  final List<String> causalParents;

  /// The coarse category this event folds into.
  final AgentEventKind kind;

  @override
  List<Object?> get props => [id, hostId, vectorClock, causalParents, kind];
}
