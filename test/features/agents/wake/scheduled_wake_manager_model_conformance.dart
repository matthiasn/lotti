part of 'scheduled_wake_manager_test.dart';

// Model conformance with `specs/tla/ScheduledWakeLease.tla`: one goal
// escalation record on two devices. Each device is a real agent database,
// sync service, wake orchestrator, wake-intent store and scheduled-wake
// manager (`WakeDevice`); the escalation is armed by the real goal Phase A;
// sync messages are delivered one at a time through the real receive
// decision. Time is fake and moves a minute at a time; the lease settles in
// three and lapses in five, as in the model's configurations.
//
// The trace chooses, besides the model's actions, when the steps the code
// awaits come back: the host lookup the lease awaits (so sync can land
// between it and the re-read before firing) and the coalesced wake-intent
// write (`FlushIntent`). A crash is the next process over the same stores.
// `poll` is the manager's hourly tick, whose phase is arbitrary: a record
// that synced in is only scanned on it, or on a re-check the device armed.

enum _LeaseOp {
  arm,
  poll,
  land,
  answer,
  deliver,
  finish,
  tick,
  crash,
  restart,
  restore,
  die,
}

class _LeaseStep {
  const _LeaseStep(this.op, this.device, this.arg);

  factory _LeaseStep.decode(int code) {
    // Ticks, deliveries and answers are the common steps; the failures rare.
    const weighted = [
      _LeaseOp.arm,
      _LeaseOp.arm,
      _LeaseOp.poll,
      _LeaseOp.land,
      _LeaseOp.land,
      _LeaseOp.answer,
      _LeaseOp.answer,
      _LeaseOp.deliver,
      _LeaseOp.deliver,
      _LeaseOp.finish,
      _LeaseOp.finish,
      _LeaseOp.tick,
      _LeaseOp.tick,
      _LeaseOp.tick,
      _LeaseOp.tick,
      _LeaseOp.crash,
      _LeaseOp.crash,
      _LeaseOp.restart,
      _LeaseOp.restore,
      _LeaseOp.die,
    ];
    return _LeaseStep(
      weighted[code % weighted.length],
      (code ~/ weighted.length) % 2,
      code ~/ (weighted.length * 2),
    );
  }

  final _LeaseOp op;
  final int device;

  /// Picks the message to deliver, the run to finish, or how many minutes
  /// a tick lasts.
  final int arg;

  @override
  String toString() => '${op.name}(d$device, $arg)';
}

extension _AnyLeaseTrace on glados.Any {
  glados.Generator<List<_LeaseStep>> get leaseTrace => glados.ListAnys(this)
      .listWithLengthInRange(1, 60, glados.IntAnys(this).intInRange(0, 20 * 8))
      .map((codes) => [for (final code in codes) _LeaseStep.decode(code)]);
}

/// Returns a fixed signal window, so Phase A derives the same facts on every
/// device.
class _FixedSignalReader extends GoalSignalReader {
  _FixedSignalReader() : super(journalDb: MockJournalDb());

  @override
  Future<GoalSignalWindow> read({
    required GoalCriterion criteria,
    required DateTime reference,
    int shortTermDays = 3,
    bool includeTimeEntryEvidence = true,
    DateTime? timeEntryEvidenceStart,
    DateTime? timeEntryEndExclusive,
  }) async => const GoalSignalWindow();
}

const _leaseGoalId = 'goal-lease';
final _leaseStart = DateTime(2026, 8, 8, 14, 30);

/// The goal every device holds before the trace: its identity, spec and head,
/// as a synced creation left them.
List<AgentDomainEntity> _leaseGoalRows() {
  const seedClock = VectorClock({'seed': 1});
  return [
    AgentDomainEntity.agent(
      id: _leaseGoalId,
      agentId: _leaseGoalId,
      kind: AgentKinds.goalAgent,
      displayName: 'Steps',
      lifecycle: AgentLifecycle.active,
      mode: AgentInteractionMode.autonomous,
      allowedCategoryIds: const {},
      currentStateId: '$_leaseGoalId:state',
      config: const AgentConfig(automaticUpdatesEnabled: true),
      createdAt: DateTime(2026, 8),
      updatedAt: DateTime(2026, 8),
      vectorClock: seedClock,
    ),
    AgentDomainEntity.goalSpecVersion(
      id: '$_leaseGoalId:spec-v1',
      agentId: _leaseGoalId,
      version: 1,
      status: GoalSpecVersionStatus.active,
      authoredBy: AgentAuthors.user,
      title: 'Steps',
      statement: 'Average 10,000 steps a day.',
      criteria: const GoalCriterion.metric(
        criterionId: 'steps',
        dataType: 'cumulative_step_count',
        window: GoalWindow.rollingDays(count: 7),
        aggregation: GoalAggregation.dailySumThenAverage,
        target: 10000,
      ),
      createdAt: DateTime(2026, 8),
      vectorClock: seedClock,
    ),
    AgentDomainEntity.goalSpecHead(
      id: goalSpecHeadId(_leaseGoalId),
      agentId: _leaseGoalId,
      versionId: '$_leaseGoalId:spec-v1',
      updatedAt: DateTime(2026, 8),
      vectorClock: seedClock,
    ),
  ];
}

class _LeaseBench {
  _LeaseBench(this.async) {
    for (final host in ['hA', 'hB']) {
      final replica = network.join(host);
      devices.add(
        WakeDevice(
          replica,
          executor: (device) => (_, runKey, _, _) {
            final run = Completer<Map<String, VectorClock>?>();
            (running[device.host] ??= []).add((runKey: runKey, run: run));
            return run.future;
          },
          requiresLease: (record) =>
              isGoalEscalationWorkspace(record.workspaceKey),
        ),
      );
    }
  }

  final FakeAsync async;
  final network = ReplicaNetwork();
  final devices = <WakeDevice>[];

  /// Per host, the escalation runs executing.
  final running =
      <
        String,
        List<({String runKey, Completer<Map<String, VectorClock>?> run})>
      >{};

  /// Ghosts of the model: completed runs per window and per device and
  /// window; the windows armed; per device, the windows it held consumed.
  final runs = <String, int>{};
  final runsBy = <(String, String), int>{};
  final created = <String>{};

  /// Windows some device armed over once they were consumed: each opens the
  /// next window (`NextWindow`), whatever the code then writes.
  final rearmedOver = <String>{};
  final consumedSeen = <String, Set<String>>{};
  int arms = 0;
  int crashes = 0;
  int deaths = 0;

  /// When each device last came up: a write that waited for it is due from
  /// then on.
  final upSince = <String, DateTime>{};
  final downSince = <String, DateTime>{};

  static const _maxArms = 6;

  /// Longer than the lease: a device can come back to a stale replica
  /// whose claims have all lapsed.
  static const _maxDown = Duration(minutes: 8);
  static final String _recordId = scheduledWakeRecordId(
    _leaseGoalId,
    workspaceKey: goalEscalationWorkspaceKey(
      const GoalWindow.day().periodKey(_leaseStart),
    ),
  );

  void settle() {
    for (var i = 0; i < 4; i++) {
      async
        ..flushMicrotasks()
        ..elapse(Duration.zero);
    }
  }

  void setUp() {
    for (final device in devices) {
      unawaited(
        Future.wait([
          for (final row in _leaseGoalRows())
            device.replica.repository.upsertEntity(row),
        ]),
      );
      upSince[device.host] = clock.now();
    }
    settle();
  }

  Iterable<WakeDevice> get _live =>
      devices.where((d) => d.status != DeviceStatus.dead);

  Future<ScheduledWakeEntity?> _row(WakeDevice device) async {
    final row = await device.replica.repository.getEntity(_recordId);
    return row is ScheduledWakeEntity ? row : null;
  }

  ScheduledWakeEntity? rowOf(WakeDevice device) {
    ScheduledWakeEntity? row;
    unawaited(_row(device).then((r) => row = r));
    settle();
    return row;
  }

  /// Runs the goal's Phase A as a deferred report refresh does, which arms
  /// the period's escalation (`Arm`, `ArmMode = "carry"`).
  void arm(WakeDevice device) {
    if (arms >= _maxArms) return;
    arms++;
    final before = rowOf(device);
    if (before != null && before.status == ScheduledWakeStatus.consumed) {
      rearmedOver.add(scheduledWakeWindow(before));
    }
    unawaited(
      GoalAgentPhaseA(
        repository: device.replica.repository,
        syncService: device.replica.syncService,
        signalReader: _FixedSignalReader(),
        onEscalationArmed: device.manager.requestCheck,
      ).execute(
        agentIdentity: _leaseGoalRows().first as AgentIdentityEntity,
        runKey: 'phase-a-$arms',
        triggerTokens: const {goalDeferredReportRefreshTriggerToken},
        threadId: 'phase-a',
      ),
    );
    settle();
    final row = rowOf(device);
    if (row != null && row.status == ScheduledWakeStatus.pending) {
      created.add(scheduledWakeWindow(row));
    }
  }

  /// Releases every step [device]'s process awaits, until none is left.
  void unblock(WakeDevice device) {
    for (var i = 0; i < 20 && device.blocked; i++) {
      device
        ..answerHostLookups()
        ..settings.land();
      settle();
    }
  }

  void deliver(WakeDevice device, int index) {
    unawaited(device.replica.receive(index));
    settle();
  }

  /// Completes one of [device]'s runs, and with it lands the settle of its
  /// intent — the model's `FinishJob` settles the window's intent as one
  /// step. Not while a consume of the device's is still waiting for its
  /// intent write: the model assumes a run outlasts the local consume
  /// issued before it (`RunOutlastsConsume`).
  void finish(WakeDevice device, int arg) {
    final mine = running[device.host] ?? [];
    if (mine.isEmpty || device.settings.hasPending) return;
    final (:runKey, :run) = mine.removeAt(arg % mine.length);
    run.complete(const {});
    settle();
    for (var i = 0; i < 4 && device.settings.hasPending; i++) {
      device.settings.land();
      settle();
    }
    for (final window in device.windowsOf[runKey] ?? const <String>{}) {
      runs[window] = (runs[window] ?? 0) + 1;
      runsBy[(device.host, window)] = (runsBy[(device.host, window)] ?? 0) + 1;
    }
  }

  /// Time moves on a minute, as the model's `Tick` allows it: no device is
  /// between a claim's approval and its consume, no write that has waited a
  /// minute for a running device is still in flight, and no device is down
  /// longer than `MaxDown`. While a device's process still awaits a step,
  /// that step comes back first instead — one per tick, so a crash can fall
  /// between any two of them.
  bool tick() {
    for (final device in devices) {
      if (device.status == DeviceStatus.up && device.blocked) {
        if (device.hasHostLookups) {
          device.answerHostLookups();
        } else {
          device.settings.land();
        }
        settle();
        return false;
      }
    }
    final minute = clock.now();
    for (final device in devices) {
      if (device.status != DeviceStatus.up) continue;
      for (final index in network.pendingFor(device.replica)) {
        final due = network.sentAt[index].isAfter(upSince[device.host]!)
            ? network.sentAt[index]
            : upSince[device.host]!;
        if (!due.add(const Duration(minutes: 1)).isAfter(minute)) {
          deliver(device, index);
        }
      }
    }
    for (final device in devices) {
      if (device.status == DeviceStatus.down &&
          !downSince[device.host]!.add(_maxDown).isAfter(minute)) {
        restart(device);
      }
    }
    async.elapse(const Duration(minutes: 1));
    settle();
    return true;
  }

  void restart(WakeDevice device) {
    device.restart();
    upSince[device.host] = clock.now();
    settle();
  }

  void run(_LeaseStep step) {
    final device = devices[step.device];
    final up = device.status == DeviceStatus.up;
    switch (step.op) {
      case _LeaseOp.arm:
        if (up) arm(device);
      case _LeaseOp.poll:
        if (up) device.manager.requestCheck();
      case _LeaseOp.land:
        if (up) device.settings.land();
      case _LeaseOp.answer:
        if (up) device.answerHostLookups();
      case _LeaseOp.deliver:
        final pending = network.pendingFor(device.replica);
        if (up && pending.isNotEmpty) {
          deliver(device, pending[step.arg % pending.length]);
        }
      case _LeaseOp.finish:
        if (up) finish(device, step.arg);
      case _LeaseOp.tick:
        // Up to three minutes; a minute whose timers leave a process
        // awaiting a step ends the run of them.
        for (var i = 0; i <= step.arg % 3; i++) {
          if (!tick()) break;
        }
      case _LeaseOp.crash:
        if (!up || crashes >= 1) break;
        crashes++;
        device.crash();
        running.remove(device.host);
        downSince[device.host] = clock.now();
      case _LeaseOp.restart:
        if (device.status == DeviceStatus.down) restart(device);
      case _LeaseOp.restore:
        if (up && device.restorePending) device.restore();
      case _LeaseOp.die:
        // Between steps, holding at most a claim: nothing it owes a run.
        if (!up ||
            deaths >= 1 ||
            device.blocked ||
            (running[device.host]?.isNotEmpty ?? false) ||
            device.settings.durable.isNotEmpty ||
            !device.orchestrator.queue.isEmpty) {
          break;
        }
        deaths++;
        device.die();
    }
    // Every step takes a second, so no two manual wakes share a run key.
    async.elapse(const Duration(seconds: 1));
    settle();
  }

  bool get quiescent => [
    for (final device in _live) network.pendingFor(device.replica),
  ].every((pending) => pending.isEmpty);

  void check(Object trace) {
    for (final entry in runsBy.entries) {
      expect(
        entry.value,
        lessThanOrEqualTo(1),
        reason: 'NoDeviceRunsTwice ${entry.key}: $trace',
      );
    }
    // Across a crash a device can confirm a claim a peer took over while it
    // was down: ADR 0048's partition case, which the model's crash
    // configurations do not check either.
    if (crashes == 0) {
      for (final entry in runs.entries) {
        expect(
          entry.value,
          lessThanOrEqualTo(1),
          reason: 'AtMostOnce ${entry.key}: $trace',
        );
      }
    }
    final rows = <String, ScheduledWakeEntity?>{};
    for (final device in _live) {
      final row = rows[device.host] = rowOf(device);
      if (row == null) continue;
      final seen = consumedSeen[device.host] ??= {};
      final window = scheduledWakeWindow(row);
      if (row.status == ScheduledWakeStatus.consumed) {
        seen.add(window);
      } else {
        expect(
          seen,
          isNot(contains(window)),
          reason: 'WindowTerminal on ${device.host}: $trace',
        );
      }
    }
    if (quiescent) {
      final states = {
        for (final row in rows.values) (row?.status, row?.scheduledAt.toUtc()),
      };
      expect(states, hasLength(1), reason: 'Converged: $trace');
    }
  }

  /// Everyone comes back, every step is released, every write delivered and
  /// every run finished, for two hours — the hourly tick included. Then
  /// every armed window has run (`NoLostWindow`).
  void drain(Object trace) {
    for (final device in devices) {
      if (device.status == DeviceStatus.down) restart(device);
    }
    for (final device in devices) {
      if (device.restorePending) device.restore();
    }
    settle();
    for (var minute = 0; minute < 120; minute++) {
      for (final device in devices) {
        if (device.status != DeviceStatus.up) continue;
        unblock(device);
        for (final index in network.pendingFor(device.replica)) {
          deliver(device, index);
        }
        while (running[device.host]?.isNotEmpty ?? false) {
          unblock(device);
          finish(device, 0);
        }
      }
      async.elapse(const Duration(minutes: 1));
      settle();
      check(trace);
    }
    for (final window in created) {
      expect(
        runs[window] ?? 0,
        greaterThanOrEqualTo(1),
        reason: 'NoLostWindow $window: $trace',
      );
    }
    // A window armed over a consumed one is a window of its own, even where
    // the code wrote nothing a device could fire.
    if (created.isNotEmpty) {
      expect(
        runs.keys.toSet().length,
        greaterThanOrEqualTo(1 + rearmedOver.length),
        reason: 'NoLostWindow after re-arming over $rearmedOver: $trace',
      );
    }
  }

  void close() {
    for (final device in devices) {
      if (device.status != DeviceStatus.dead) device.die();
    }
    unawaited(network.close());
    settle();
  }
}

void _registerLeaseModelConformance() {
  group('model conformance with specs/tla/ScheduledWakeLease.tla', () {
    glados.Glados(
      glados.any.leaseTrace,
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'generated arms, claims, deliveries, crashes and deaths keep '
      'NoDeviceRunsTwice, AtMostOnce, WindowTerminal and Converged, and lose '
      'no window',
      (trace) {
        fakeAsync((async) {
          withClock(async.getClock(_leaseStart), () {
            final bench = _LeaseBench(async);
            try {
              bench.setUp();
              for (final step in trace) {
                bench
                  ..run(step)
                  ..check(trace);
              }
              bench.drain(trace);
            } finally {
              bench.close();
            }
          });
        });
      },
      tags: 'glados',
    );
  });
}
