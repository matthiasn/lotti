part of 'task_agent_retirement_test.dart';

// Model conformance with `specs/tla/TaskAgentAssignment.tla`: one task on two
// devices, each a real agent database behind the real `TaskAgentService`,
// `AgentService` and `TaskAgentRetirement`, exchanging every write through the
// real receive decision in generated orders. The trace assigns the task
// (the follow-up's auto-assignment, once per device, and by hand), destroys
// and deletes agents, delivers writes, runs the pass a receive schedules,
// crashes a device (the startup pass), and wakes agents through the wake
// gate. After every wake that is let run it checks NoSupersededWake; once
// everything has arrived and every scheduled pass has run it checks
// AtMostOneLive, LiveAgreed and KeepsAgent. The clock only moves forward,
// as in the model without Skew.

enum _AssignOp { auto, manual, destroy, delete, deliver, retire, crash, wake }

class _AssignStep {
  const _AssignStep(this.op, this.device, this.arg);

  factory _AssignStep.decode(int code) => _AssignStep(
    _AssignOp.values[code % _AssignOp.values.length],
    (code ~/ _AssignOp.values.length) % 2,
    code ~/ (_AssignOp.values.length * 2),
  );

  final _AssignOp op;
  final int device;

  /// Picks the agent to destroy, delete or wake, or the write to deliver.
  final int arg;

  @override
  String toString() => '${op.name}(d$device, $arg)';
}

extension _AnyAssignTrace on glados.Any {
  glados.Generator<List<_AssignStep>> get assignTrace => glados.ListAnys(this)
      .listWithLengthInRange(
        1,
        24,
        glados.IntAnys(this).intInRange(0, _AssignOp.values.length * 2 * 6),
      )
      .map((codes) => [for (final code in codes) _AssignStep.decode(code)]);
}

/// The model's bounds: three agent ids, one user destroy, one crash.
const _maxCreations = 3;
const _maxDestroys = 1;
const _maxCrashes = 1;

/// Is [write] about agent [agentId]: its identity, state, or a link from it?
bool _concerns(ReplicaWrite write, String agentId) =>
    write.message.mapOrNull(
      agentEntity: (m) => m.agentEntity?.agentId == agentId,
      agentLink: (m) => m.agentLink?.fromId == agentId,
    ) ??
    false;

/// Does applying [write] schedule the pass, as `SyncEventProcessor` does:
/// a live `agent_task` link, or a task agent's identity?
bool _schedulesPass(ReplicaWrite write) =>
    write.message.mapOrNull(
      agentEntity: (m) {
        final entity = m.agentEntity;
        return entity is AgentIdentityEntity &&
            entity.kind == AgentKinds.taskAgent;
      },
      agentLink: (m) {
        final link = m.agentLink;
        return link is AgentTaskLink && link.deletedAt == null;
      },
    ) ??
    false;

class _AssignDevice {
  _AssignDevice(this.replica) {
    _build();
  }

  final AgentReplica replica;
  final MockWakeOrchestrator orchestrator = _permissiveOrchestrator();
  late AgentService agents;
  late TaskAgentService tasks;

  /// A receive scheduled the pass, which has not run yet.
  bool pending = false;

  /// The follow-up's auto-assignment has run on this device.
  bool autoDone = false;

  void _build() {
    agents = AgentService(
      repository: replica.repository,
      orchestrator: orchestrator,
      syncService: replica.syncService,
    );
    tasks = TaskAgentService(
      agentService: agents,
      repository: replica.repository,
      orchestrator: orchestrator,
      syncService: replica.syncService,
    );
  }

  /// A process death and restart over the same database.
  void reboot() {
    replica.reboot();
    _build();
  }

  /// The task's agents this device holds, by id: identities of every
  /// `agent_task` link to the task that it holds.
  Future<Map<String, AgentIdentityEntity>> held() async {
    final links = await replica.repository.getLinksTo(
      _taskId,
      type: AgentLinkTypes.agentTask,
    );
    final result = <String, AgentIdentityEntity>{};
    for (final link in links) {
      final entity = await replica.repository.getEntity(link.fromId);
      if (entity is AgentIdentityEntity) result[link.fromId] = entity;
    }
    return result;
  }

  Future<Set<String>> live() async => {
    for (final e in (await held()).values)
      if (e.lifecycle != AgentLifecycle.destroyed) e.agentId,
  };

  /// The model's `Top(Ranked(d))`: the first link, by the task card's
  /// order, among the links whose identity this device holds.
  Future<String?> first() async {
    final ranked = await held();
    final links = (await replica.repository.getLinksTo(
      _taskId,
      type: AgentLinkTypes.agentTask,
    )).where((link) => ranked.containsKey(link.fromId)).toList();
    return links.isEmpty ? null : links.orderedPrimaryFirst().first.fromId;
  }
}

class _AssignWorld {
  _AssignWorld() {
    devices = [
      _AssignDevice(network.join('hA')),
      _AssignDevice(network.join('hB')),
    ];
  }

  final network = ReplicaNetwork();
  late final List<_AssignDevice> devices;

  var _now = DateTime(2026, 9, 27, 9);

  /// Ghosts: when each agent was created, when the user last destroyed one.
  final born = <String, DateTime>{};
  DateTime? lastDestroy;
  var _destroys = 0;
  var _crashes = 0;

  Future<void> setUp() async {
    for (final device in devices) {
      // Seeded on every device, as default templates are; a profile makes
      // every new agent configured and active.
      await device.replica.repository.upsertEntity(
        makeTestTemplate(profileId: 'profile-1'),
      );
    }
  }

  Future<T> _at<T>(Future<T> Function() body) {
    _now = _now.add(const Duration(minutes: 1));
    return withClock(Clock.fixed(_now), body);
  }

  Future<void> _create(_AssignDevice device) async {
    if (born.length >= _maxCreations) return;
    Future<AgentIdentityEntity> create() => _at(
      () => device.tasks.createTaskAgent(
        taskId: _taskId,
        templateId: kTestTemplateId,
        allowedCategoryIds: const {'category-1'},
        awaitContent: true,
      ),
    );
    final links = await device.replica.repository.getLinksTo(
      _taskId,
      type: AgentLinkTypes.agentTask,
    );
    if (links.isNotEmpty) {
      // The model's guard: refused while the device holds any link.
      await expectLater(create(), throwsStateError);
      return;
    }
    final agent = await create();
    born[agent.agentId] = _now;
  }

  Future<void> _deliver(_AssignDevice device, int index) async {
    await device.replica.receive(index);
    if (_schedulesPass(network.sent[index])) device.pending = true;
  }

  Future<void> run(_AssignStep step, Object trace) async {
    final device = devices[step.device];
    switch (step.op) {
      case _AssignOp.auto:
        if (device.autoDone) return;
        device.autoDone = true;
        await _create(device);
      case _AssignOp.manual:
        await _create(device);
      case _AssignOp.destroy:
        if (_destroys >= _maxDestroys) return;
        final live = (await device.live()).toList()..sort();
        if (live.isEmpty) return;
        _destroys++;
        await _at(
          () => device.agents.destroyAgent(live[step.arg % live.length]),
        );
        lastDestroy = _now;
      case _AssignOp.delete:
        // Only once every write about the agent has arrived (the model's
        // guard; see its residual in the README).
        final pending = network.pendingFor(device.replica);
        final dead = [
          for (final e in (await device.held()).values)
            if (e.lifecycle == AgentLifecycle.destroyed &&
                !pending.any((i) => _concerns(network.sent[i], e.agentId)))
              e.agentId,
        ]..sort();
        if (dead.isEmpty) return;
        await _at(
          () => device.agents.deleteAgent(dead[step.arg % dead.length]),
        );
      case _AssignOp.deliver:
        final pending = network.pendingFor(device.replica);
        if (pending.isEmpty) return;
        await _deliver(device, pending[step.arg % pending.length]);
      case _AssignOp.retire:
        if (!device.pending) return;
        device.pending = false;
        await _at(() => device.tasks.retirement.retireSuperseded(_taskId));
      case _AssignOp.crash:
        if (_crashes >= _maxCrashes) return;
        _crashes++;
        device
          ..pending = false
          ..reboot();
        await _at(device.tasks.restoreSubscriptions);
      case _AssignOp.wake:
        final live = (await device.live()).toList()..sort();
        if (live.isEmpty) return;
        final agentId = live[step.arg % live.length];
        final stopped = await _at(
          () => device.tasks.retirement.retireIfSuperseded(agentId),
        );
        if (!stopped) {
          expect(
            agentId,
            await device.first(),
            reason: 'NoSupersededWake on ${device.replica.host}: $trace',
          );
        }
    }
  }

  /// Every write reaches every device and every pass it scheduled runs.
  Future<void> settle() async {
    var more = true;
    while (more) {
      more = false;
      for (final (d, device) in devices.indexed) {
        final pending = network.pendingFor(device.replica);
        for (final index in d.isOdd ? pending.reversed : pending) {
          more = true;
          await _deliver(device, index);
        }
        if (device.pending) {
          more = true;
          device.pending = false;
          await _at(() => device.tasks.retirement.retireSuperseded(_taskId));
        }
      }
    }
  }

  Future<void> checkQuiescent(Object trace) async {
    final live = [for (final device in devices) await device.live()];
    for (final (d, set) in live.indexed) {
      expect(
        set.length,
        lessThanOrEqualTo(1),
        reason: 'AtMostOneLive on ${devices[d].replica.host}: $trace',
      );
      expect(set, live.first, reason: 'LiveAgreed: $trace');
    }
    final destroyedAt = lastDestroy;
    final assignedSince = born.values.any(
      (at) => destroyedAt == null || at.isAfter(destroyedAt),
    );
    if (assignedSince) {
      expect(live.first, isNotEmpty, reason: 'KeepsAgent: $trace');
    }
  }

  Future<void> close() => network.close();
}

Future<void> _playAssignTrace(List<_AssignStep> trace) async {
  final world = _AssignWorld();
  try {
    await world.setUp();
    for (final step in trace) {
      await world.run(step, trace);
    }
    await world.settle();
    await world.checkQuiescent(trace);
  } finally {
    await world.close();
  }
}

void _registerTaskAgentAssignmentConformance() {
  group('model conformance with specs/tla/TaskAgentAssignment.tla', () {
    glados.Glados(
      glados.any.assignTrace,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'generated assignments, destroys, deletes, arrival orders, crashes and '
      'wakes leave the task one agent that every device agrees on',
      _playAssignTrace,
      tags: 'glados',
    );

    const auto = _AssignOp.auto;
    const deliver = _AssignOp.deliver;

    test('the counterexample: both devices auto-assign the follow-up, and '
        'after sync one agent is left, the later one, on both', () async {
      final world = _AssignWorld();
      try {
        await world.setUp();
        final trace = [
          const _AssignStep(auto, 0, 0),
          const _AssignStep(auto, 1, 0),
        ];
        for (final step in trace) {
          await world.run(step, trace);
        }
        final later = world.born.keys.last;
        await world.settle();
        await world.checkQuiescent(trace);
        for (final device in world.devices) {
          expect(await device.live(), {later});
        }
      } finally {
        await world.close();
      }
    });

    test('NoSupersededWake: a loser whose pass has not run yet is stopped '
        'by the wake gate', () async {
      final world = _AssignWorld();
      try {
        await world.setUp();
        final trace = [
          const _AssignStep(auto, 0, 0),
          const _AssignStep(auto, 1, 0),
          // Device A receives B's agent — the later one — but its pass has
          // not run.
          const _AssignStep(deliver, 0, 0),
        ];
        for (final step in trace) {
          await world.run(step, trace);
        }
        final a = world.devices[0];
        await world.settleDeliveriesOnly(a);
        final earlier = world.born.keys.first;
        expect(await a.live(), hasLength(2));

        final stopped = await a.tasks.retirement.retireIfSuperseded(earlier);

        expect(stopped, isTrue);
        expect(await a.live(), {world.born.keys.last});
      } finally {
        await world.close();
      }
    });

    test('Legacy: two agents an older build left on both devices are '
        'reduced to one by the startup pass', () async {
      final world = _AssignWorld();
      try {
        await world.setUp();
        // The older build: both assign, and every write arrives, but no pass
        // runs.
        final trace = [
          const _AssignStep(auto, 0, 0),
          const _AssignStep(auto, 1, 0),
        ];
        for (final step in trace) {
          await world.run(step, trace);
        }
        for (final device in world.devices) {
          await world.settleDeliveriesOnly(device);
          device.pending = false;
          expect(await device.live(), hasLength(2));
        }

        // The upgraded app starts on each device.
        for (final device in world.devices) {
          device.reboot();
          await world._at(device.tasks.restoreSubscriptions);
        }
        await world.settle();

        await world.checkQuiescent([...trace, 'startup on both']);
        expect(await world.devices[0].live(), {world.born.keys.last});
      } finally {
        await world.close();
      }
    });
  });
}

extension on _AssignWorld {
  /// Delivers everything pending for [device] without running its pass.
  Future<void> settleDeliveriesOnly(_AssignDevice device) async {
    for (final index in network.pendingFor(device.replica)) {
      await _deliver(device, index);
    }
  }
}
