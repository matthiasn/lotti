part of 'agent_sync_service_test.dart';

// Model conformance: three replicas of one synced agent entity, each a real
// AgentSyncService over its own in-memory store, exchange their writes in
// generated orders through the real receive-path decision
// (resolveAgentEntityVersions). They must keep the invariants
// `specs/tla/AgentReplication.tla` model-checks: once every write has reached
// every replica, all hold the same row (Converged); a row is never a version
// that a write it received causally replaced (NoLostSuccessor); and no
// G-counter increment is lost (OwnCountKept, NoLostIncrement). Writes build
// on the persisted row, on a wake-start snapshot, or on no clock at all, and
// a replica's clock may lag the others'.

enum _ReplicaOp {
  write,
  snapshotWrite,
  unclockedWrite,
  snapshot,
  deliver,
  tick,
}

class _ReplicaStep {
  const _ReplicaStep(this.op, this.replica, this.arg);

  factory _ReplicaStep.decode(int code) => _ReplicaStep(
    _ReplicaOp.values[code % _ReplicaOp.values.length],
    (code ~/ _ReplicaOp.values.length) % 3,
    code ~/ (_ReplicaOp.values.length * 3),
  );

  final _ReplicaOp op;
  final int replica;

  /// Picks the message to deliver, the edit, and the clock lag.
  final int arg;

  @override
  String toString() => '${op.name}(r$replica, $arg)';
}

extension _AnyReplicaTrace on glados.Any {
  glados.Generator<List<_ReplicaStep>> get replicaTrace => glados.ListAnys(this)
      .listWithLengthInRange(
        1,
        16,
        glados.IntAnys(this).intInRange(0, _ReplicaOp.values.length * 3 * 8),
      )
      .map((codes) => [for (final code in codes) _ReplicaStep.decode(code)]);
}

/// The entity family under test: how its first version looks and how a
/// local write edits a base version.
abstract class _ReplicatedKind {
  AgentDomainEntity get initial;

  /// An edit of [base] made at [at]. [bump] asks for a G-counter increment
  /// by [host] (only ever on the persisted row).
  AgentDomainEntity edit(
    AgentDomainEntity base, {
    required DateTime at,
    required int serial,
    required int arg,
    required String host,
    required bool bump,
  });
}

class _StateKind implements _ReplicatedKind {
  @override
  AgentDomainEntity get initial => makeTestState(
    agentId: 'agent-1',
    vectorClock: const VectorClock({'seed': 1}),
  );

  @override
  AgentDomainEntity edit(
    AgentDomainEntity base, {
    required DateTime at,
    required int serial,
    required int arg,
    required String host,
    required bool bump,
  }) {
    final state = base as AgentStateEntity;
    return state.copyWith(
      updatedAt: at,
      revision: serial,
      wakeCounter: bump ? state.wakeCounter.increment(host) : state.wakeCounter,
    );
  }
}

/// Planner knowledge: retraction outranks the timestamp. A write keeps the
/// retraction it built on — leaving it is the RankDrop residual.
class _KnowledgeKind implements _ReplicatedKind {
  @override
  AgentDomainEntity get initial => AgentDomainEntity.plannerKnowledge(
    id: 'k1',
    agentId: 'agent-1',
    key: 'deep-work',
    hook: 'no deep work before 10',
    statementText: 'v0',
    source: KnowledgeSource.userStated,
    status: KnowledgeStatus.confirmed,
    createdAt: _replicaEpoch,
    updatedAt: _replicaEpoch,
    vectorClock: const VectorClock({'seed': 1}),
  );

  @override
  AgentDomainEntity edit(
    AgentDomainEntity base, {
    required DateTime at,
    required int serial,
    required int arg,
    required String host,
    required bool bump,
  }) {
    final entry = base as PlannerKnowledgeEntity;
    return entry.copyWith(
      updatedAt: at,
      statementText: 'v$serial',
      status: entry.status == KnowledgeStatus.retracted || arg.isEven
          ? KnowledgeStatus.retracted
          : KnowledgeStatus.confirmed,
    );
  }
}

final _replicaEpoch = DateTime(2026, 9, 24, 9);

class _Replica {
  _Replica(this.host, this.world, AgentDomainEntity initial) {
    repo.seed([initial]);
    when(
      () => clocks.getNextVectorClock(
        previous: any(named: 'previous'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((invocation) async {
      // VectorClockService.reserveNextVectorClock: this host's next counter,
      // caught up past whatever the previous clock already holds for it.
      final previous = invocation.namedArguments[#previous] as VectorClock?;
      final own = previous?.vclock[host] ?? 0;
      counter = (own > counter ? own : counter) + 1;
      return VectorClock({...?previous?.vclock, host: counter});
    });
    when(() => outbox.enqueueMessage(any())).thenAnswer((invocation) async {
      final message = invocation.positionalArguments.single as SyncMessage;
      final entity = message.mapOrNull(agentEntity: (m) => m.agentEntity);
      if (entity == null) return;
      world.sent.add(entity);
      delivered.add(world.sent.length - 1);
    });
    service = AgentSyncService(
      repository: repo,
      outboxService: outbox,
      vectorClockService: clocks,
    );
  }

  final String host;
  final _ReplicaWorld world;
  final repo = InMemoryAgentRepository();
  final clocks = MockVectorClockService();
  final outbox = MockOutboxService();
  late final AgentSyncService service;
  int counter = 0;
  AgentDomainEntity? snapshot;

  /// Indices into [_ReplicaWorld.sent] this replica wrote or received.
  final delivered = <int>{};

  Future<AgentDomainEntity> row() async =>
      (await repo.getEntity(world.kind.initial.id))!;

  /// The receive path: SyncEventProcessor applies exactly this decision.
  Future<void> deliver(int index) async {
    final incoming = world.sent[index];
    final local = await repo.getEntity(incoming.id);
    final resolved = local == null
        ? incoming
        : resolveAgentEntityVersions(local: local, incoming: incoming);
    if (!identical(resolved, local)) await repo.upsertEntity(resolved);
    delivered.add(index);
  }
}

class _ReplicaWorld {
  _ReplicaWorld(this.kind) {
    replicas = [
      for (final host in ['hA', 'hB', 'hC']) _Replica(host, this, kind.initial),
    ];
  }

  final _ReplicatedKind kind;
  late final List<_Replica> replicas;
  final sent = <AgentDomainEntity>[];

  /// Ghost: G-counter increments each host made.
  final increments = <String, int>{};
  DateTime now = _replicaEpoch;
  int serial = 0;

  Future<void> run(_ReplicaStep step) async {
    final replica = replicas[step.replica];
    switch (step.op) {
      case _ReplicaOp.tick:
        now = now.add(const Duration(minutes: 1));
      case _ReplicaOp.snapshot:
        replica.snapshot = await replica.row();
      case _ReplicaOp.deliver:
        if (sent.isEmpty) return;
        await replica.deliver(step.arg % sent.length);
      case _ReplicaOp.write:
      case _ReplicaOp.snapshotWrite:
      case _ReplicaOp.unclockedWrite:
        final row = await replica.row();
        final base = switch (step.op) {
          _ReplicaOp.snapshotWrite => replica.snapshot ?? row,
          _ReplicaOp.unclockedWrite => row.copyWith(vectorClock: null),
          _ => row,
        };
        // Only an edit of the row the writer just read bumps a counter; the
        // snapshot writers that bumped one are AgentStateWrites.tla.
        final bump = step.op == _ReplicaOp.write && step.arg.isOdd;
        if (bump) {
          increments[replica.host] = (increments[replica.host] ?? 0) + 1;
        }
        // Another device's clock can run behind: up to a minute of lag.
        final lag = Duration(minutes: (step.arg ~/ 2) % 2);
        await replica.service.upsertEntity(
          kind.edit(
            base,
            at: now.subtract(lag),
            serial: ++serial,
            arg: step.arg,
            host: replica.host,
            bump: bump,
          ),
        );
    }
  }

  /// Every write reaches every replica, each in its own order.
  Future<void> deliverAll() async {
    for (final (i, replica) in replicas.indexed) {
      final order = [for (var k = 0; k < sent.length; k++) k];
      final rotated = [
        ...order.skip(i % (sent.isEmpty ? 1 : sent.length)),
        ...order.take(i % (sent.isEmpty ? 1 : sent.length)),
      ];
      for (final index in i.isOdd ? rotated.reversed : rotated) {
        await replica.deliver(index);
      }
    }
  }

  Future<void> checkStep(List<_ReplicaStep> trace) async {
    for (final replica in replicas) {
      final row = await replica.row();
      for (final index in replica.delivered) {
        final m = sent[index].vectorClock!;
        final status = VectorClock.compare(m, row.vectorClock!);
        expect(
          status,
          isNot(VclockStatus.a_gt_b),
          reason: 'NoLostSuccessor on ${replica.host}: $trace',
        );
      }
      if (row is AgentStateEntity) {
        expect(
          row.wakeCounter.byHost[replica.host] ?? 0,
          increments[replica.host] ?? 0,
          reason: 'OwnCountKept on ${replica.host}: $trace',
        );
      }
    }
  }

  Future<void> checkConverged(List<_ReplicaStep> trace) async {
    final rows = [for (final replica in replicas) await replica.row()];
    for (final row in rows.skip(1)) {
      expect(
        row.toJson(),
        rows.first.toJson(),
        reason: 'Converged: $trace',
      );
    }
    final first = rows.first;
    if (first is AgentStateEntity) {
      expect(
        first.wakeCounter.byHost,
        {
          for (final entry in increments.entries)
            if (entry.value > 0) entry.key: entry.value,
        },
        reason: 'NoLostIncrement: $trace',
      );
    }
  }
}

void _registerReplicationModelConformance() {
  group('model conformance with specs/tla/AgentReplication.tla', () {
    for (final (label, kind) in [
      ('agent state (G-counters)', _StateKind()),
      ('planner knowledge (retraction override)', _KnowledgeKind()),
    ]) {
      glados.Glados(
        glados.any.replicaTrace,
        glados.ExploreConfig(numRuns: 150),
      ).test(
        '$label: generated writes and arrival orders converge without '
        'losing a successor or an increment',
        (trace) async {
          final world = _ReplicaWorld(kind);
          for (final step in trace) {
            await world.run(step);
            await world.checkStep(trace);
          }
          await world.deliverAll();
          await world.checkStep(trace);
          await world.checkConverged(trace);
        },
        tags: 'glados',
      );
    }
  });
}
