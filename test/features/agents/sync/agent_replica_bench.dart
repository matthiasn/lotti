import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_database.dart'
    show AgentDatabase;
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/sync/agent_concurrent_resolver.dart';
import 'package:lotti/features/agents/sync/agent_message_dag.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

/// One write a device's outbox sent: an agent entity or an agent link.
typedef ReplicaWrite = ({
  String from,
  AgentDomainEntity? entity,
  AgentLink? link,
});

/// The devices of a model-conformance trace and the writes they exchange.
///
/// Every write a device commits reaches every other device as its own sync
/// message, in whatever order the trace delivers it; a message is never
/// lost, only delayed — the outbox is durable. This is the network of the
/// TLA+ models in `specs/tla/` that replicate agent entities.
class ReplicaNetwork {
  final replicas = <AgentReplica>[];
  final sent = <ReplicaWrite>[];

  /// When each write in [sent] was sent, on the ambient `clock`.
  final sentAt = <DateTime>[];

  /// Adds a device whose store is a fresh in-memory agent database.
  AgentReplica join(String host) {
    final replica = AgentReplica._(host, this);
    replicas.add(replica);
    return replica;
  }

  /// Indices into [sent] still to be delivered to [to].
  List<int> pendingFor(AgentReplica to) => [
    for (var i = 0; i < sent.length; i++)
      if (sent[i].from != to.host && !to.received.contains(i)) i,
  ];

  /// Every device has received every write.
  bool get quiescent => replicas.every((r) => pendingFor(r).isEmpty);

  /// Delivers everything, each device in its own order: the even-numbered
  /// devices oldest first, the odd-numbered newest first.
  Future<void> deliverAll() async {
    while (!quiescent) {
      for (final (i, replica) in replicas.indexed) {
        final pending = pendingFor(replica);
        for (final index in i.isOdd ? pending.reversed : pending) {
          await replica.receive(index);
        }
      }
    }
  }

  Future<void> close() async {
    for (final replica in replicas) {
      await replica.db.close();
    }
  }
}

/// One device's agent store: a real in-memory [AgentDatabase] behind a real
/// [AgentRepository] and [AgentSyncService]. The outbox hands every
/// committed write to the [ReplicaNetwork]; the vector-clock service issues
/// this host's next counter, caught up past whatever the previous clock
/// holds for it, as `VectorClockService.reserveNextVectorClock` does.
///
/// [reboot] is a process death and restart: a fresh repository and sync
/// service over the same database, with the counter — which the real service
/// persists — carried over.
class AgentReplica {
  AgentReplica._(this.host, this.network)
    : db = AgentDatabase(inMemoryDatabase: true, background: false) {
    when(
      () => clocks.getNextVectorClock(
        previous: any(named: 'previous'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((invocation) async {
      final previous = invocation.namedArguments[#previous] as VectorClock?;
      final own = previous?.vclock[host] ?? 0;
      counter = (own > counter ? own : counter) + 1;
      return VectorClock({...?previous?.vclock, host: counter});
    });
    when(() => outbox.enqueueMessage(any())).thenAnswer((invocation) async {
      final message = invocation.positionalArguments.single as SyncMessage;
      final write = message.mapOrNull(
        agentEntity: (m) => m.agentEntity == null
            ? null
            : (from: host, entity: m.agentEntity, link: null),
        agentLink: (m) => m.agentLink == null
            ? null
            : (from: host, entity: null, link: m.agentLink),
      );
      if (write == null) return;
      network.sent.add(write);
      network.sentAt.add(clock.now());
    });
    reboot();
  }

  final String host;
  final ReplicaNetwork network;
  final AgentDatabase db;
  final clocks = MockVectorClockService();
  final outbox = MockOutboxService();
  late AgentRepository repository;
  late AgentSyncService syncService;
  int counter = 0;

  /// Indices into [ReplicaNetwork.sent] this device has received.
  final received = <int>{};

  void reboot() {
    repository = AgentRepository(db);
    syncService = AgentSyncService(
      repository: repository,
      outboxService: outbox,
      vectorClockService: clocks,
    );
  }

  /// The receive path for one write, as `SyncEventProcessor` applies it: the
  /// local row is read and the shared decision ([resolveAgentEntityVersions],
  /// with the message-DAG order of two agent-state heads) picks the row to
  /// keep; a link is kept when the local one dominates or wins the
  /// concurrent tiebreak.
  Future<void> receive(int index) async {
    received.add(index);
    final write = network.sent[index];
    final entity = write.entity;
    final link = write.link;
    await repository.runInTransaction(() async {
      if (entity != null) {
        final local = await repository.getEntity(entity.id);
        if (local == null) {
          await repository.upsertEntity(entity);
          return;
        }
        final isAncestor =
            local is AgentStateEntity && entity is AgentStateEntity
            ? await AgentMessageDag(repository).ancestryOf(
                local.recentHeadMessageId,
                entity.recentHeadMessageId,
              )
            : noKnownAncestry;
        final resolved = resolveAgentEntityVersions(
          local: local,
          incoming: entity,
          isAncestor: isAncestor,
        );
        if (!identical(resolved, local)) {
          await repository.upsertEntity(resolved);
        }
      } else if (link != null) {
        final local = await repository.getLinkById(link.id);
        final localVc = local?.vectorClock;
        final incomingVc = link.vectorClock;
        if (local != null && localVc != null && incomingVc != null) {
          final keepLocal = switch (VectorClock.compare(localVc, incomingVc)) {
            VclockStatus.a_gt_b || VclockStatus.equal => true,
            VclockStatus.b_gt_a => false,
            VclockStatus.concurrent =>
              resolveConcurrent(
                    localVc: localVc,
                    incomingVc: incomingVc,
                    localUpdatedAt: local.updatedAt,
                    incomingUpdatedAt: link.updatedAt,
                  ) ==
                  ConcurrentWinner.local,
          };
          if (keepLocal) return;
        }
        await repository.upsertLink(link);
      }
    });
  }
}
