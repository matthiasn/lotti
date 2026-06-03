import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/projection/agent_event_adapter.dart';
import 'package:lotti/features/agents/projection/agent_projection.dart';
import 'package:lotti/features/agents/projection/canonical_order.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/sync/fork_healer.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_data/entity_factories.dart';
import 'in_memory_agent_repository.dart';

/// A real [AgentSyncService] + [ForkHealer] over an [InMemoryAgentRepository],
/// with a per-host counting vector clock and a no-op outbox. The faithful
/// bench for fork-healing tests: the services read and write exactly as they
/// would against the database, so what they emit reads back through the
/// projection. Two benches with different hosts model two devices stamping
/// distinct envelopes on the same content-addressed node.
typedef ForkBench = ({
  AgentSyncService service,
  ForkHealer healer,
  InMemoryAgentRepository repo,
});

ForkBench makeForkBench({String host = 'h1'}) {
  final repo = InMemoryAgentRepository();
  final vc = MockVectorClockService();
  var counter = 0;
  when(
    () => vc.getNextVectorClock(previous: any(named: 'previous')),
  ).thenAnswer((_) async => VectorClock({host: ++counter}));
  final outbox = MockOutboxService();
  when(() => outbox.enqueueMessage(any())).thenAnswer((_) async {});
  final service = AgentSyncService(
    repository: repo,
    outboxService: outbox,
    vectorClockService: vc,
  );
  return (
    service: service,
    healer: ForkHealer(syncService: service),
    repo: repo,
  );
}

/// The DAG heads of an arbitrary message + link log.
List<String> headsOfLog(
  Iterable<AgentMessageEntity> messages,
  Iterable<AgentLink> links,
) => project(canonicalOrder(agentEventsFromLog(messages, links))).headIds;

/// The full projection of the union of [devices]' logs, deduped by id — models
/// the synced DB (`insertOnConflictUpdate`), so two devices' concurrent
/// content-addressed emissions collapse to one event per id before the fold.
AgentProjection projectDeviceUnion(Iterable<InMemoryAgentRepository> devices) {
  final messages = <String, AgentMessageEntity>{
    for (final d in devices)
      for (final m in d.messages) m.id: m,
  };
  final links = <String, AgentLink>{
    for (final d in devices)
      for (final l in d.links) l.id: l,
  };
  return project(
    canonicalOrder(agentEventsFromLog(messages.values, links.values)),
  );
}

/// Seeds a two-head fork `p ← a`, `p ← b` (heads `{a, b}`) into [repo], with the
/// agent's head pointer at [head].
Future<void> seedForkInto(
  InMemoryAgentRepository repo, {
  required String head,
  String agentId = 'agent-1',
}) async {
  repo.seed([
    makeTestState(agentId: agentId).copyWith(recentHeadMessageId: head),
    makeTestMessage(id: 'p', agentId: agentId, createdAt: DateTime(2024)),
    makeTestMessage(id: 'a', agentId: agentId, createdAt: DateTime(2024, 1, 2)),
    makeTestMessage(id: 'b', agentId: agentId, createdAt: DateTime(2024, 1, 2)),
  ]);
  for (final (child, parent) in [('a', 'p'), ('b', 'p')]) {
    await repo.upsertLink(
      AgentLink.messagePrev(
        id: 'mp-$child-$parent',
        fromId: child,
        toId: parent,
        createdAt: DateTime(2024, 1, 2),
        updatedAt: DateTime(2024, 1, 2),
        vectorClock: null,
      ),
    );
  }
}
