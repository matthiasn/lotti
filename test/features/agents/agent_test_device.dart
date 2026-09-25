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
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';

/// One device's real agent persistence and sync stack, for tests that need
/// what the code actually commits: an in-memory agent database behind the
/// real [AgentRepository] and [AgentSyncService], a vector clock that issues
/// [host]'s counters as `VectorClockService` does, and an outbox that
/// records what the device sends.
///
/// Two failures can be injected. [failClockFor] makes the clock reservation
/// for one payload id throw: a write that fails before its row is stored,
/// which rolls back the transaction around it. [outboxFails] makes the
/// outbox refuse messages: a transaction that commits and then fails
/// flushing, which `AgentSyncService.runInTransaction` reports by throwing.
///
/// `firstCounter` is the first counter the host issues: 1 for a host this
/// build creates (`firstVectorClockCounter`), 0 for one an older build
/// created (ADR 0080).
///
/// `background` runs the database on a background isolate, as the app does;
/// a trace under `fakeAsync` needs it off. [reboot] is a process death and
/// restart: a fresh repository and sync service over the same database,
/// with the counter — which the real service persists — carried over.
/// [onSent] sees every accepted message as it is accepted.
///
/// Callers close the database with [close] (in `addTearDown`).
class AgentTestDevice {
  AgentTestDevice(
    this.host, {
    int firstCounter = firstVectorClockCounter,
    bool background = true,
    this.onSent,
  }) : _counter = firstCounter - 1,
       db = AgentDatabase(inMemoryDatabase: true, background: background) {
    when(
      () => clocks.getNextVectorClock(
        previous: any(named: 'previous'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((invocation) async {
      final payload = invocation.namedArguments[#payload] as VcPayloadRef?;
      if (payload != null && payload.id == failClockFor) {
        throw StateError('clock reservation failed for ${payload.id}');
      }
      // This host's next counter, caught up past whatever the previous
      // clock already holds for it.
      final previous = invocation.namedArguments[#previous] as VectorClock?;
      final own = previous?.vclock[host];
      _counter = (own != null && own > _counter ? own : _counter) + 1;
      return VectorClock({...?previous?.vclock, host: _counter});
    });
    when(() => outbox.enqueueMessage(any())).thenAnswer((invocation) async {
      if (outboxFails) throw StateError('outbox unavailable after commit');
      final message = invocation.positionalArguments.single as SyncMessage;
      sent.add(message);
      onSent?.call(message);
    });
    reboot();
  }

  final String host;
  final AgentDatabase db;
  final void Function(SyncMessage message)? onSent;
  late AgentRepository repository;
  final clocks = MockVectorClockService();
  final outbox = MockOutboxService();
  late AgentSyncService sync;

  void reboot() {
    repository = AgentRepository(db);
    sync = AgentSyncService(
      repository: repository,
      outboxService: outbox,
      vectorClockService: clocks,
    );
  }

  /// Every message the outbox accepted, in order.
  final sent = <SyncMessage>[];

  /// The payload id whose clock reservation throws, or `null`.
  String? failClockFor;

  /// Whether the outbox refuses messages.
  bool outboxFails = false;

  int _counter;

  /// The agent entities this device sent, in order.
  List<AgentDomainEntity> get sentEntities => [
    for (final message in sent)
      ?message.mapOrNull(agentEntity: (m) => m.agentEntity),
  ];

  /// The agent links this device sent, in order.
  List<AgentLink> get sentLinks => [
    for (final message in sent)
      ?message.mapOrNull(agentLink: (m) => m.agentLink),
  ];

  /// Receives [incoming] the way `SyncEventProcessor` applies an agent
  /// entity: the stored row, read and written in one transaction, resolved
  /// by [resolveAgentEntityVersions] — for two agent-state rows, with the
  /// order of their heads in the local message DAG.
  Future<void> receiveEntity(AgentDomainEntity incoming) =>
      repository.runInTransaction(() async {
        final local = await repository.getEntity(incoming.id);
        final isAncestor =
            local is AgentStateEntity && incoming is AgentStateEntity
            ? await AgentMessageDag(repository).ancestryOf(
                local.recentHeadMessageId,
                incoming.recentHeadMessageId,
              )
            : noKnownAncestry;
        final resolved = local == null
            ? incoming
            : resolveAgentEntityVersions(
                local: local,
                incoming: incoming,
                isAncestor: isAncestor,
              );
        if (!identical(resolved, local)) {
          await repository.upsertEntity(resolved);
        }
      });

  /// Receives [incoming] the way `SyncEventProcessor` applies an agent link:
  /// the stored version, a tombstone included, read and written in one
  /// transaction, resolved by [resolveAgentLinkVersions].
  Future<void> receiveLink(AgentLink incoming) =>
      repository.runInTransaction(() async {
        final local = await repository.getLinkByIdIncludingDeleted(
          incoming.id,
        );
        if (local == null ||
            !identical(
              resolveAgentLinkVersions(local: local, incoming: incoming),
              local,
            )) {
          await repository.upsertLink(incoming);
        }
      });

  Future<void> close() => db.close();
}
