part of 'fork_healer_test.dart';

// Model conformance: two real AgentSyncService + ForkHealer replicas, driven
// through generated appends, other state writes, heals and sync deliveries in
// any order, must keep the invariants `specs/tla/AgentMessageLog.tla`
// model-checks. TLC proves the design; this trace checks that the Dart code
// behaves like it. Every row a device writes lands in its outbox and reaches
// the other device once, in whatever order the trace picks; the receiving
// side applies the sync processor's rule — for the state row the shared
// decision (`resolveAgentEntityVersions`, its head ordered by the local DAG
// through `AgentMessageDag.ancestryOf`), for an edge vector clock first, then
// last-writer-wins on (updatedAt, canonical clock). The second device's clock
// runs an hour ahead, so createdAt order can disagree with causal order.

enum _LogOp { append, stateWrite, heal, deliver }

class _LogStep {
  const _LogStep(this.op, this.device, this.arg);

  factory _LogStep.decode(int code) => _LogStep(
    _LogOp.values[code % _LogOp.values.length],
    (code ~/ _LogOp.values.length) % 2,
    code ~/ (_LogOp.values.length * 2),
  );

  final _LogOp op;
  final int device;

  /// Picks among the rows in flight to [device], modulo how many there are.
  final int arg;

  @override
  String toString() => '${op.name}(d$device, $arg)';
}

extension _AnyLogTrace on glados.Any {
  glados.Generator<List<_LogStep>> get messageLogTrace => glados.ListAnys(this)
      .listWithLengthInRange(
        1,
        24,
        glados.IntAnys(this).intInRange(0, _LogOp.values.length * 2 * 6),
      )
      .map((codes) => [for (final code in codes) _LogStep.decode(code)]);
}

class _Replica {
  _Replica(this.host, {required this.skew}) {
    final vc = MockVectorClockService();
    var counter = 0;
    when(
      () => vc.getNextVectorClock(
        previous: any(named: 'previous'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((invocation) async {
      final previous =
          invocation.namedArguments[#previous] as VectorClock? ??
          const VectorClock(<String, int>{});
      return VectorClock.merge(previous, VectorClock({host: ++counter}));
    });
    final outboxService = MockOutboxService();
    when(() => outboxService.enqueueMessage(any())).thenAnswer((
      invocation,
    ) async {
      outbox.add(invocation.positionalArguments.first as SyncMessage);
    });
    service = AgentSyncService(
      repository: repo,
      outboxService: outboxService,
      vectorClockService: vc,
    );
    healer = ForkHealer(syncService: service);
  }

  final String host;
  final Duration skew;
  final repo = InMemoryAgentRepository();
  final outbox = <SyncMessage>[];
  late final AgentSyncService service;
  late final ForkHealer healer;

  /// Indices of the other replica's outbox this one has received.
  final received = <int>{};
  int appends = 0;
}

class _LogBench {
  _LogBench() {
    // The agent was created on one device and its first state row synced.
    final state = makeTestState(
      agentId: _agentId,
      vectorClock: const VectorClock({'origin': 1}),
      updatedAt: DateTime(2024, 3),
    );
    for (final replica in replicas) {
      replica.repo.seed([state]);
    }
  }

  final replicas = [
    _Replica('h1', skew: Duration.zero),
    _Replica('h2', skew: const Duration(hours: 1)),
  ];

  int tick = 0;

  /// Every messagePrev version any replica wrote: id → the parents it named.
  final edgeTargets = <String, Set<String>>{};

  /// Ghost: the parents each join was minted over.
  final joinParents = <String, Set<String>>{};

  DateTime nowOn(_Replica replica) =>
      DateTime(2024, 3, 2).add(Duration(minutes: ++tick)).add(replica.skew);

  Future<void> run(_LogStep step) async {
    final replica = replicas[step.device];
    final other = replicas[1 - step.device];
    final before = [
      for (final r in replicas)
        (
          head: (await r.repo.getAgentState(_agentId))?.recentHeadMessageId,
          dag: _presentEdges(r.repo),
        ),
    ];
    switch (step.op) {
      case _LogOp.append:
        if (replica.appends >= 3) return;
        replica.appends++;
        final id = '${replica.host}-m${replica.appends}';
        await replica.service.upsertEntity(
          makeTestMessage(
            id: id,
            agentId: _agentId,
            createdAt: nowOn(replica),
            metadata: const AgentMessageMetadata(),
          ),
        );
        // AppendsOffTips: the append chained off a row with no child here.
        final parent =
            ((await replica.repo.getEntity(id))! as AgentMessageEntity)
                .prevMessageId;
        final dag = before[step.device].dag;
        expect(
          [
            for (final MapEntry(key: child, value: parents) in dag.entries)
              if (parents.contains(parent)) child,
          ],
          isEmpty,
          reason: 'AppendsOffTips: $id chained off non-tip $parent',
        );
      case _LogOp.stateWrite:
        // A wake outcome or scheduling write: keeps the persisted head.
        final at = nowOn(replica);
        await replica.service.updateAgentState(
          _agentId,
          (current) => current.copyWith(
            consecutiveFailureCount: current.consecutiveFailureCount + 1,
            updatedAt: at,
          ),
        );
      case _LogOp.heal:
        await _heal(replica);
      case _LogOp.deliver:
        final pending = [
          for (var i = 0; i < other.outbox.length; i++)
            if (!replica.received.contains(i)) i,
        ];
        if (pending.isEmpty) return;
        final index = pending[step.arg % pending.length];
        replica.received.add(index);
        await _receive(replica.repo, other.outbox[index]);
    }
    _recordEdges();
    // HeadNeverRegresses: no step moves a head pointer back to a row the
    // device knew, before the step, to be an ancestor of the old one.
    for (var i = 0; i < replicas.length; i++) {
      final old = before[i].head;
      if (old == null) continue;
      final head = (await replicas[i].repo.getAgentState(
        _agentId,
      ))?.recentHeadMessageId;
      expect(
        _ancestors(before[i].dag, old),
        isNot(contains(head)),
        reason: 'HeadNeverRegresses on ${replicas[i].host}: $old -> $head',
      );
    }
  }

  /// The `messagePrev` edges of present rows, child → parents: the edges the
  /// projection folds.
  static Map<String, Set<String>> _presentEdges(InMemoryAgentRepository repo) {
    final present = {for (final m in repo.messages) m.id};
    final result = <String, Set<String>>{};
    for (final link in repo.links.whereType<MessagePrevLink>()) {
      if (present.contains(link.fromId)) {
        (result[link.fromId] ??= <String>{}).add(link.toId);
      }
    }
    return result;
  }

  static Set<String> _ancestors(Map<String, Set<String>> dag, String id) {
    final seen = <String>{};
    final pending = [...?dag[id]];
    while (pending.isNotEmpty) {
      final next = pending.removeLast();
      if (seen.add(next)) pending.addAll(dag[next] ?? const {});
    }
    return seen;
  }

  Future<void> _heal(_Replica replica) async {
    final before = (
      messages: replica.repo.messages,
      links: replica.repo.links,
    );
    final joinId = await replica.healer.maybeHealFork(
      agentId: _agentId,
      at: nowOn(replica),
    );
    if (joinId == null) return;
    final parents = {
      for (final link in replica.repo.links.whereType<MessagePrevLink>())
        if (link.fromId == joinId) link.toId,
    };
    joinParents[joinId] = parents;
    // NoJoinOverNonTip: no joined parent already had a child here, short of
    // the residual — a join still missing the edge to a parent that is not a
    // head on this device.
    if (_blindJoin(before.messages, before.links)) return;
    for (final parent in parents) {
      final children = [
        for (final message in before.messages)
          if (message.prevMessageId == parent ||
              (joinParents[message.id]?.contains(parent) ?? false))
            message.id,
      ];
      expect(
        children,
        isEmpty,
        reason: 'join $joinId over non-tip $parent (children $children)',
      );
    }
  }

  bool _blindJoin(List<AgentMessageEntity> messages, List<AgentLink> links) {
    final heads = headsOfLog(messages, links).toSet();
    for (final MapEntry(key: join, value: parents) in joinParents.entries) {
      if (!messages.any((m) => m.id == join)) continue;
      final arrived = {
        for (final link in links.whereType<MessagePrevLink>())
          if (link.fromId == join) link.toId,
      };
      final missing = parents.difference(arrived);
      if (missing.isNotEmpty && !heads.containsAll(missing)) return true;
    }
    return false;
  }

  void _recordEdges() {
    for (final replica in replicas) {
      for (final link in replica.repo.links.whereType<MessagePrevLink>()) {
        (edgeTargets[link.id] ??= <String>{}).add(link.toId);
      }
    }
  }

  static Future<void> _receive(
    InMemoryAgentRepository repo,
    SyncMessage message,
  ) async {
    switch (message) {
      case SyncAgentEntity(:final agentEntity?):
        final local = await repo.getEntity(agentEntity.id);
        if (local == null) {
          await repo.upsertEntity(agentEntity);
        } else if (local is AgentStateEntity &&
            agentEntity is AgentStateEntity) {
          final resolved = resolveAgentEntityVersions(
            local: local,
            incoming: agentEntity,
            isAncestor: await AgentMessageDag(repo).ancestryOf(
              local.recentHeadMessageId,
              agentEntity.recentHeadMessageId,
            ),
          );
          if (!identical(resolved, local)) await repo.upsertEntity(resolved);
        } else if (local is! AgentMessageEntity) {
          fail('unexpected agent entity $agentEntity');
        }
      case SyncAgentLink(:final agentLink?):
        final local = await repo.getLinkById(agentLink.id);
        if (local == null ||
            _incomingWins(
              localVc: local.vectorClock,
              incomingVc: agentLink.vectorClock,
              localAt: local.updatedAt,
              incomingAt: agentLink.updatedAt,
            )) {
          await repo.upsertLink(agentLink);
        }
      default:
        fail('unexpected sync message $message');
    }
  }

  static bool _incomingWins({
    required VectorClock? localVc,
    required VectorClock? incomingVc,
    required DateTime? localAt,
    required DateTime? incomingAt,
  }) {
    final local = localVc ?? const VectorClock(<String, int>{});
    final incoming = incomingVc ?? const VectorClock(<String, int>{});
    return switch (VectorClock.compare(local, incoming)) {
      VclockStatus.b_gt_a => true,
      VclockStatus.a_gt_b || VclockStatus.equal => false,
      VclockStatus.concurrent =>
        resolveConcurrent(
              localVc: local,
              incomingVc: incoming,
              localUpdatedAt: localAt ?? DateTime(2024),
              incomingUpdatedAt: incomingAt ?? DateTime(2024),
            ) ==
            ConcurrentWinner.incoming,
    };
  }

  void checkInvariants(List<_LogStep> trace) {
    for (final replica in replicas) {
      // Acyclic (and no duplicate id): the projection folds.
      expect(
        () => headsOfLog(replica.repo.messages, replica.repo.links),
        returnsNormally,
        reason: 'Acyclic on ${replica.host}: $trace',
      );
    }
    for (final MapEntry(key: id, value: targets) in edgeTargets.entries) {
      expect(
        targets,
        hasLength(1),
        reason: 'EdgesImmutable: $id names $targets: $trace',
      );
    }
  }

  /// Delivers everything in flight, heals every replica, and repeats until
  /// nothing moves: the replicas must agree on their edges and hold one head.
  Future<void> settle(List<_LogStep> trace) async {
    for (var round = 0; round < 6; round++) {
      for (var device = 0; device < 2; device++) {
        while (replicas[device].received.length <
            replicas[1 - device].outbox.length) {
          await run(_LogStep(_LogOp.deliver, device, 0));
        }
      }
      for (var device = 0; device < 2; device++) {
        await run(_LogStep(_LogOp.heal, device, 0));
      }
      checkInvariants(trace);
    }
    final [a, b] = replicas;
    expect(
      {for (final l in a.repo.links) l.id: l.toId},
      {for (final l in b.repo.links) l.id: l.toId},
      reason: 'Converged: $trace',
    );
    for (final replica in replicas) {
      final heads = headsOfLog(replica.repo.messages, replica.repo.links);
      expect(
        heads.length,
        lessThanOrEqualTo(1),
        reason: 'EventuallySingleHead on ${replica.host}: $trace',
      );
      // SettledHead: the next append chains off that one head.
      final pointer = (await replica.repo.getAgentState(
        _agentId,
      ))?.recentHeadMessageId;
      if (heads.isEmpty || pointer == null) continue;
      expect(
        await AgentMessageDag(replica.repo).tipFrom(pointer),
        heads.single,
        reason: 'SettledHead on ${replica.host}: $trace',
      );
    }
  }
}

void _registerModelConformance() {
  group('model conformance with specs/tla/AgentMessageLog.tla', () {
    glados.Glados(
      glados.any.messageLogTrace,
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'generated appends, state writes, heals and deliveries keep Acyclic, '
      'EdgesImmutable, NoJoinOverNonTip, HeadNeverRegresses and '
      'AppendsOffTips, and settle to one head every append chains off',
      (trace) async {
        final bench = _LogBench();
        for (final step in trace) {
          await bench.run(step);
          bench.checkInvariants(trace);
        }
        await bench.settle(trace);
      },
      tags: 'glados',
    );
  });
}
