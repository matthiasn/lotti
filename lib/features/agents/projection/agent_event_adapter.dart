import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/projection/agent_event.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// Maps a storage-layer [AgentMessageKind] onto the kernel's coarser
/// [AgentEventKind]. Exhaustive over the enum — a new message kind won't compile
/// until it is classified here.
AgentEventKind agentEventKindFromMessageKind(AgentMessageKind kind) =>
    switch (kind) {
      AgentMessageKind.observation => AgentEventKind.observation,
      AgentMessageKind.summary => AgentEventKind.summary,
      AgentMessageKind.user ||
      AgentMessageKind.thought ||
      AgentMessageKind.action ||
      AgentMessageKind.toolResult ||
      AgentMessageKind.system => AgentEventKind.message,
    };

/// Converts a persisted agent message log into kernel [AgentEvent]s.
///
/// This is the bridge from storage (`AgentMessageEntity` + `AgentLink`) to the
/// pure projection kernel — the first production consumer of the kernel (PR 3).
/// It does not read the projection back into any production path; callers use
/// it to compute a shadow projection alongside the live mutable rows.
///
/// Causal parents come from the **`messagePrev` edge graph** (the canonical
/// causal graph per ADR 0016), restricted to active (non-deleted) links;
/// `AgentEvent` normalizes them to sorted-unique. `hostId` is supplied by
/// [hostIdOf] and defaults to the empty string, which makes `canonicalOrder`
/// fall back to an `id`-only tiebreak until an authoring host is persisted on
/// messages (a PR 3 open decision). A null message `vectorClock` maps to an
/// empty clock (valid; compares equal to other empty clocks).
List<AgentEvent> agentEventsFromLog(
  Iterable<AgentMessageEntity> messages,
  Iterable<AgentLink> links, {
  String Function(AgentMessageEntity message)? hostIdOf,
}) {
  final parentsByChild = <String, List<String>>{};
  for (final link in links) {
    if (link is MessagePrevLink && link.deletedAt == null) {
      (parentsByChild[link.fromId] ??= <String>[]).add(link.toId);
    }
  }

  return [
    for (final message in messages)
      AgentEvent(
        id: message.id,
        hostId: hostIdOf?.call(message) ?? '',
        vectorClock: message.vectorClock ?? const VectorClock(<String, int>{}),
        kind: agentEventKindFromMessageKind(message.kind),
        causalParents: parentsByChild[message.id] ?? const <String>[],
      ),
  ];
}
