part of 'agent_entity_receive_test.dart';

// Model conformance with the removal kind of `specs/tla/AgentReplication.tla`:
// a day plan on three devices — each a real agent database, repository and
// sync service — that is edited, deleted and drafted again, with every write
// delivered through the real receive decision in generated orders, any
// delivery lost and recovered by backfill, and one device whose clock runs
// ahead. The writers are the product's: an edit or a deletion of the row
// `getEntity` reads, which hides a tombstone, so a draft over a deleted plan
// is built afresh; and a stale edit or deletion from a snapshot read earlier.
// The trace checks the model's invariants: a row is never a version that a
// write it received causally replaced (NoLostSuccessor) — a deleted plan is
// never brought back by a late copy; a plan drafted again keeps its fields on
// the drafting device (LocalWriteTakesEffect); and once every write has
// arrived, directly or by backfill, all devices hold the same row
// (Converged).

enum _RemovalOp { edit, remove, snapshot, staleWrite, deliver, lose, backfill }

class _RemovalStep {
  const _RemovalStep(this.op, this.device, this.arg);

  factory _RemovalStep.decode(int code) => _RemovalStep(
    _RemovalOp.values[code % _RemovalOp.values.length],
    (code ~/ _RemovalOp.values.length) % 3,
    code ~/ (_RemovalOp.values.length * 3),
  );

  final _RemovalOp op;
  final int device;

  /// Picks the delivery, the lost write to recover, or the stale write.
  final int arg;

  @override
  String toString() => '${op.name}(d$device, $arg)';
}

extension _AnyRemovalTrace on glados.Any {
  glados.Generator<List<_RemovalStep>> get removalTrace => glados.ListAnys(this)
      .listWithLengthInRange(
        1,
        20,
        glados.IntAnys(this).intInRange(0, _RemovalOp.values.length * 24),
      )
      .map((codes) => [for (final code in codes) _RemovalStep.decode(code)]);
}

/// Local writes per trace, as the model bounds them (`MaxWrites`), plus a few:
/// traces are shorter than the model's exhaustive search.
const _maxRemovalWrites = 6;

class _RemovalBench {
  _RemovalBench() {
    devices = [network.join('hA'), network.join('hB'), network.join('hC')];
  }

  final network = ReplicaNetwork();
  late final List<AgentReplica> devices;
  final _snapshots = <AgentDomainEntity?>[null, null, null];

  /// Per device: writes whose delivery the network dropped, not yet
  /// recovered by backfill.
  final _lost = [<int>{}, <int>{}, <int>{}];

  /// Per device: the versions backfill answered with.
  final _answers = [<VectorClock>[], <VectorClock>[], <VectorClock>[]];

  var _now = DateTime(2026, 9, 25, 9);
  var _serial = 0;
  var _writes = 0;

  final String _planId = makeTestDayPlan().id;

  /// The second device's clock runs ahead, so a removal it stamps can sort
  /// after a draft made later on another device.
  DateTime _clockOf(int device) =>
      device == 1 ? _now.add(const Duration(minutes: 2)) : _now;

  Future<void> setUp() async {
    await devices[0].syncService.upsertEntity(
      makeTestDayPlan(updatedAt: _now),
    );
    await network.deliverAll();
  }

  Future<AgentDomainEntity?> _read(int device) =>
      devices[device].repository.getEntity(_planId);

  Future<AgentDomainEntity?> stored(int device) =>
      devices[device].repository.getEntityIncludingDeleted(_planId);

  Future<void> _write(int device, AgentDomainEntity entity) async {
    _writes++;
    _now = _now.add(const Duration(minutes: 1));
    await devices[device].syncService.upsertEntity(entity);
  }

  Future<void> run(_RemovalStep step, Object trace) async {
    final d = step.device;
    final device = devices[d];
    switch (step.op) {
      case _RemovalOp.snapshot:
        _snapshots[d] = await _read(d);
      case _RemovalOp.edit:
        if (_writes >= _maxRemovalWrites) return;
        final row = await _read(d);
        final capacity = 100 + ++_serial;
        final at = _clockOf(d);
        if (row == null) {
          // The planner drafting a day whose plan was deleted.
          await _write(
            d,
            // Built afresh: the writer read no row, so it has no clock.
            makeTestDayPlan(capacityMinutes: capacity, updatedAt: at),
          );
          final drafted = (await stored(d))! as DayPlanEntity;
          expect(
            drafted.deletedAt == null && drafted.capacityMinutes == capacity,
            isTrue,
            reason: 'LocalWriteTakesEffect on ${device.host}: $trace',
          );
        } else {
          await _write(
            d,
            (row as DayPlanEntity).copyWith(
              capacityMinutes: capacity,
              updatedAt: at,
            ),
          );
        }
      case _RemovalOp.remove:
        if (_writes >= _maxRemovalWrites) return;
        final row = await _read(d);
        if (row == null) return;
        final at = _clockOf(d);
        await _write(
          d,
          (row as DayPlanEntity).copyWith(deletedAt: at, updatedAt: at),
        );
      case _RemovalOp.staleWrite:
        final snapshot = _snapshots[d];
        if (_writes >= _maxRemovalWrites || snapshot is! DayPlanEntity) {
          return;
        }
        final at = _clockOf(d);
        await _write(
          d,
          step.arg.isEven
              ? snapshot.copyWith(
                  capacityMinutes: 100 + ++_serial,
                  updatedAt: at,
                )
              : snapshot.copyWith(deletedAt: at, updatedAt: at),
        );
      case _RemovalOp.deliver:
        final pending = network.pendingFor(device);
        if (pending.isEmpty) return;
        await device.receive(pending[step.arg % pending.length]);
      case _RemovalOp.lose:
        final pending = network.pendingFor(device);
        if (pending.isEmpty) return;
        final index = pending[step.arg % pending.length];
        device.received.add(index);
        _lost[d].add(index);
      case _RemovalOp.backfill:
        if (_lost[d].isEmpty) return;
        await _backfill(d, _lost[d].elementAt(step.arg % _lost[d].length));
    }
  }

  /// The writer of the lost write answers with the version it holds for the
  /// id, as the backfill responder reads it: tombstone included.
  Future<void> _backfill(int device, int index) async {
    _lost[device].remove(index);
    final writer = network.replicas.firstWhere(
      (replica) => replica.host == network.sent[index].from,
    );
    final answer = await writer.repository.getEntityIncludingDeleted(_planId);
    if (answer == null) return;
    _answers[device].add(answer.vectorClock!);
    await devices[device].device.receiveEntity(answer);
  }

  /// Everything the network still holds reaches every device: the lost
  /// writes by backfill, the rest directly.
  Future<void> settle() async {
    for (var d = 0; d < devices.length; d++) {
      for (final index in _lost[d].toList()) {
        await _backfill(d, index);
      }
    }
    await network.deliverAll();
  }

  Future<void> checkStep(Object trace) async {
    for (var d = 0; d < devices.length; d++) {
      final device = devices[d];
      final row = (await stored(d))!;
      final seen = [
        for (var i = 0; i < network.sent.length; i++)
          if (network.sent[i].from == device.host ||
              (device.received.contains(i) && !_lost[d].contains(i)))
            network.sent[i].message
                .mapOrNull(agentEntity: (m) => m.agentEntity)!
                .vectorClock!,
        ..._answers[d],
      ];
      for (final clock in seen) {
        expect(
          causallyBefore(row.vectorClock!, clock),
          isFalse,
          reason: 'NoLostSuccessor on ${device.host}: $trace',
        );
      }
    }
  }

  Future<void> checkConverged(Object trace) async {
    final rows = [
      for (var d = 0; d < devices.length; d++) (await stored(d))!.toJson(),
    ];
    for (final row in rows.skip(1)) {
      expect(row, rows.first, reason: 'Converged: $trace');
    }
  }
}

void registerRemovalModelConformance() {
  glados.Glados(
    glados.any.removalTrace,
    glados.ExploreConfig(numRuns: 150),
  ).test(
    'a day plan edited, deleted and drafted again on three devices '
    'converges, and a deletion is never undone by a version it replaced '
    '(specs/tla/AgentReplication.tla, the removal kind)',
    (trace) async {
      final bench = _RemovalBench();
      try {
        await bench.setUp();
        for (final step in trace) {
          await bench.run(step, trace);
          await bench.checkStep(trace);
        }
        await bench.settle();
        await bench.checkStep(trace);
        await bench.checkConverged(trace);
      } finally {
        await bench.network.close();
      }
    },
    tags: 'glados',
  );
}
