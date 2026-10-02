part of 'scheduled_wake_manager_test.dart';

// The lease rules `specs/tla/ProjectWakeGovernor.tla` added for project
// update slots, each on a real agent database, sync service, orchestrator and
// manager (`WakeDevice`) under fake time: the sync gate, the claim that a
// lost connection taints, and the earliest-slot rule.

const _slotAgentId = 'project-agent-slots';

/// A controllable sync gate: whether the device is connected, whether its
/// inbox drains, and the connectivity changes the gate counts losses from.
class _GateControl {
  _GateControl() {
    gate = SyncLeaseGate(
      syncEnabled: () async => true,
      connected: () => connected,
      connectivityChanges: changes.stream,
      waitForInboxDrained: (_) async {
        drainWaits++;
        if (!drained) throw TimeoutException('inbox busy');
      },
    );
  }

  final changes = StreamController<bool>.broadcast(sync: true);
  late final SyncLeaseGate gate;
  bool connected = true;
  bool drained = true;

  /// How often the manager waited for the inbox, each wait up to the drain
  /// timeout in the app.
  int drainWaits = 0;

  void drop() {
    connected = false;
    changes.add(false);
  }

  void restore() {
    connected = true;
    changes.add(true);
  }
}

class _SlotBench {
  _SlotBench(this.async) {
    final replica = network.join('hA');
    device = WakeDevice(
      replica,
      holdSteps: false,
      executor: (_) => (_, runKey, _, _) async {
        runs.add(runKey);
        return const {};
      },
      requiresLease: (record) => isProjectUpdateWorkspace(record.workspaceKey),
      syncGate: control.gate,
      requiresSyncGate: (record) =>
          isProjectUpdateWorkspace(record.workspaceKey),
      exclusiveGroupOf: (record) =>
          isProjectUpdateWorkspace(record.workspaceKey) ? record.agentId : null,
    );
  }

  final FakeAsync async;
  final network = ReplicaNetwork();
  final control = _GateControl();
  late final WakeDevice device;
  final runs = <String>[];

  void settle() {
    for (var i = 0; i < 6; i++) {
      async
        ..flushMicrotasks()
        ..elapse(Duration.zero);
    }
  }

  /// The project agent, and one pending slot per instant in [slots].
  void seed(List<DateTime> slots) {
    unawaited(
      Future.wait([
        device.replica.repository.upsertEntity(
          makeTestIdentity(
            id: _slotAgentId,
            agentId: _slotAgentId,
            kind: AgentKinds.projectAgent,
            config: const AgentConfig(automaticUpdatesEnabled: true),
          ),
        ),
        for (final slot in slots)
          device.replica.repository.upsertEntity(
            AgentDomainEntity.scheduledWake(
              id: projectUpdateSlotRecordId(_slotAgentId, slot),
              agentId: _slotAgentId,
              scheduledAt: slot.toUtc(),
              status: ScheduledWakeStatus.pending,
              reason: WakeReason.scheduled.name,
              updatedAt: slot,
              vectorClock: null,
              workspaceKey: projectUpdateWorkspaceKey(slot),
              triggerTokens: const [ProjectUpdateSlots.triggerToken],
            ),
          ),
      ]),
    );
    settle();
  }

  ScheduledWakeEntity slot(DateTime at) {
    AgentDomainEntity? row;
    unawaited(
      device.replica.repository
          .getEntity(projectUpdateSlotRecordId(_slotAgentId, at))
          .then((value) => row = value),
    );
    settle();
    return row! as ScheduledWakeEntity;
  }

  void scan() {
    device.manager.requestCheck();
    settle();
  }

  void elapse(Duration duration) {
    async.elapse(duration);
    settle();
  }

  void dispose() {
    device.die();
    unawaited(control.gate.dispose());
    unawaited(network.close());
    settle();
  }
}

void _registerProjectSlotRules() {
  group('project update slots (ProjectWakeGovernor)', () {
    final slotStart = DateTime(2026, 10, 2, 11);
    final later = DateTime(2026, 10, 2, 12);

    test('a closed sync gate leaves a due slot unclaimed until it opens', () {
      fakeAsync((async) {
        final bench = _SlotBench(async);
        async.elapse(slotStart.difference(clock.now()));
        bench
          ..control.drained = false
          ..seed([slotStart])
          ..scan();

        expect(bench.slot(slotStart).leaseHostId, isNull);

        bench.control.drained = true;
        bench.elapse(const Duration(minutes: 1));

        expect(bench.slot(slotStart).leaseHostId, 'hA');
        expect(bench.runs, isEmpty, reason: 'claimed, not yet settled');
        bench.dispose();
      }, initialTime: DateTime(2026, 10, 2, 10));
    });

    test('one pass waits for the inbox once, however many slots are due', () {
      fakeAsync((async) {
        final bench = _SlotBench(async);
        async.elapse(slotStart.difference(clock.now()));
        bench
          ..control.drained = false
          ..seed([slotStart]);
        // A second project agent with its own due slot.
        const otherAgent = 'project-agent-other';
        unawaited(
          Future.wait([
            bench.device.replica.repository.upsertEntity(
              makeTestIdentity(
                id: otherAgent,
                agentId: otherAgent,
                kind: AgentKinds.projectAgent,
                config: const AgentConfig(automaticUpdatesEnabled: true),
              ),
            ),
            bench.device.replica.repository.upsertEntity(
              AgentDomainEntity.scheduledWake(
                id: projectUpdateSlotRecordId(otherAgent, slotStart),
                agentId: otherAgent,
                scheduledAt: slotStart.toUtc(),
                status: ScheduledWakeStatus.pending,
                reason: WakeReason.scheduled.name,
                updatedAt: slotStart,
                vectorClock: null,
                workspaceKey: projectUpdateWorkspaceKey(slotStart),
                triggerTokens: const [ProjectUpdateSlots.triggerToken],
              ),
            ),
          ]),
        );
        bench
          ..settle()
          ..control.drainWaits = 0
          ..scan();

        // One backlog must not stall the pass once per gated record.
        expect(bench.control.drainWaits, 1);
        expect(bench.slot(slotStart).leaseHostId, isNull);
        bench.dispose();
      }, initialTime: DateTime(2026, 10, 2, 10));
    });

    test('a claim the connection dropped under is made again, not fired', () {
      fakeAsync((async) {
        final bench = _SlotBench(async);
        async.elapse(slotStart.difference(clock.now()));
        bench
          ..seed([slotStart])
          ..scan();
        final firstClaim = bench.slot(slotStart).leaseUntil;
        expect(firstClaim, isNotNull);

        // The connection drops and comes back inside the settle: nobody can
        // be sure the claim reached the peers.
        bench.control
          ..drop()
          ..restore();
        bench.elapse(const Duration(minutes: 3));

        expect(bench.runs, isEmpty);
        final secondClaim = bench.slot(slotStart).leaseUntil;
        expect(secondClaim!.isAfter(firstClaim!), isTrue);

        // A settle in which the claim stayed visible confirms it.
        bench.elapse(const Duration(minutes: 3));
        expect(bench.runs, hasLength(1));
        expect(bench.slot(slotStart).status, ScheduledWakeStatus.consumed);
        bench.dispose();
      }, initialTime: DateTime(2026, 10, 2, 10));
    });

    test('of two pending slots only the earliest fires, and its run '
        'consumes both', () {
      fakeAsync((async) {
        final bench = _SlotBench(async);
        async.elapse(later.difference(clock.now()));
        bench
          ..seed([slotStart, later])
          ..scan()
          ..elapse(const Duration(minutes: 3));

        expect(bench.runs, hasLength(1));
        expect(bench.slot(slotStart).status, ScheduledWakeStatus.consumed);
        expect(bench.slot(later).status, ScheduledWakeStatus.consumed);
        // The later slot was never claimed: it waited behind the earlier.
        expect(bench.slot(later).leaseHostId, isNull);

        bench.elapse(const Duration(minutes: 30));
        expect(bench.runs, hasLength(1));
        bench.dispose();
      }, initialTime: DateTime(2026, 10, 2, 10));
    });

    test('an ungated record is unaffected by a closed gate', () {
      fakeAsync((async) {
        final bench = _SlotBench(async);
        bench.control
          ..connected = false
          ..drop();
        final gated = bench.device.manager;
        expect(gated.syncGate!.epoch, 1);
        // Records outside requiresSyncGate never consult it.
        final digest = AgentDomainEntity.scheduledWake(
          id: 'scheduled_wake:other:global',
          agentId: 'other',
          scheduledAt: DateTime(2026, 10, 2, 9).toUtc(),
          status: ScheduledWakeStatus.pending,
          reason: WakeReason.scheduled.name,
          updatedAt: DateTime(2026, 10, 2, 9),
          vectorClock: null,
        );
        expect(gated.requiresSyncGate!(digest as ScheduledWakeEntity), isFalse);
        bench.dispose();
      }, initialTime: DateTime(2026, 10, 2, 10));
    });
  });
}
