part of 'agent_sync_service_test.dart';

// Model conformance: three replicas of one agent link, each a real
// AgentSyncService over its own in-memory agent database, write the link
// afresh and remove it (`softDeleted` of the row read) under one reused id,
// and exchange the versions in generated orders. A delivery can be lost; the
// receiver then asks the writer, which answers with its stored version, a
// tombstone included, as the backfill responder does. They must keep the
// invariants `specs/tla/AgentLinks.tla` model-checks: a row is never a
// version that a version it received causally replaced (NoLostSuccessor),
// and once every write has reached every replica, directly or by backfill,
// all hold the same version (Converged).
//
// The slot variant (`Slot` in the spec, ADR 0099) assigns one template's
// soul under fresh link ids instead, and removes live assignments. Every
// replica must also show the same soul once quiescent (SlotConverged), show
// exactly the live assignment the slot ranks first, and rank an assignment
// above every assignment its writer held (SuccessorOutranks).

enum _LinkOp { link, unlink, deliver, lose, backfill, tick }

class _LinkStep {
  const _LinkStep(this.op, this.replica, this.arg);

  factory _LinkStep.decode(int code) => _LinkStep(
    _LinkOp.values[code % _LinkOp.values.length],
    (code ~/ _LinkOp.values.length) % 3,
    code ~/ (_LinkOp.values.length * 3),
  );

  final _LinkOp op;
  final int replica;

  /// Picks the version to deliver, lose or recover, and the clock lag.
  final int arg;

  @override
  String toString() => '${op.name}(r$replica, $arg)';
}

extension _AnyLinkTrace on glados.Any {
  glados.Generator<List<_LinkStep>> get linkTrace => glados.ListAnys(this)
      .listWithLengthInRange(
        1,
        16,
        glados.IntAnys(this).intInRange(0, _LinkOp.values.length * 3 * 8),
      )
      .map((codes) => [for (final code in codes) _LinkStep.decode(code)]);
}

const _linkId = 'parsed_item_to_task:item:task';
final _linkEpoch = DateTime(2026, 9, 24, 9);
const _slotTemplate = 'template-slot';
const _slot = AgentLinkSlot.soul(_slotTemplate);
const _maxAssignments = 3;

class _LinkReplica {
  _LinkReplica(String host) : device = AgentTestDevice(host);

  final AgentTestDevice device;

  /// Indices into [_LinkWorld.sent] this replica wrote or received.
  final delivered = <int>{};

  /// Versions the network dropped on the way here, and those backfill has
  /// since answered.
  final lost = <int>{};
  final resolved = <int>{};

  Future<AgentLink?> row([String id = _linkId]) =>
      device.repository.getLinkByIdIncludingDeleted(id);

  /// The soul assignments the slot shows: at most one.
  Future<List<AgentLink>> visible() => device.repository.getLinksFrom(
    _slotTemplate,
    type: AgentLinkTypes.soulAssignment,
  );
}

class _LinkWorld {
  _LinkWorld({this.slot = false});

  /// Assign one slot under fresh ids instead of writing one reused id.
  final bool slot;

  /// Per slot assignment id: the other assignments its writer held.
  final saw = <String, Set<String>>{};
  final List<_LinkReplica> replicas = [
    for (final host in ['hA', 'hB', 'hC']) _LinkReplica(host),
  ];

  /// Every version written, and the replica that wrote it.
  final sent = <AgentLink>[];
  final origin = <int>[];
  DateTime now = _linkEpoch;

  Future<void> close() async {
    for (final replica in replicas) {
      await replica.device.close();
    }
  }

  Future<void> _write(int r, AgentLink link) async {
    final replica = replicas[r];
    await replica.device.sync.upsertLink(link);
    sent.add(replica.device.sentLinks.last);
    origin.add(r);
    replica.delivered.add(sent.length - 1);
  }

  Future<void> _deliver(_LinkReplica replica, int index) async {
    await replica.device.receiveLink(sent[index]);
    replica.delivered.add(index);
  }

  /// BackfillResponseHandler: the writer answers with its stored version.
  Future<void> _backfill(_LinkReplica replica, int index) async {
    final answer = await replicas[origin[index]].row(sent[index].id);
    if (answer != null) {
      await replica.device.receiveLink(answer);
      final answered = sent.indexWhere(
        (v) => v.vectorClock == answer.vectorClock,
      );
      if (answered >= 0) replica.delivered.add(answered);
    }
    replica.lost.remove(index);
    replica.resolved.add(index);
  }

  Future<void> run(_LinkStep step) async {
    final replica = replicas[step.replica];
    // Another device's clock can run behind: up to a minute of lag.
    final at = now.subtract(Duration(minutes: (step.arg ~/ 2) % 2));
    switch (step.op) {
      case _LinkOp.tick:
        now = now.add(const Duration(minutes: 1));
      case _LinkOp.link when slot:
        // A reassignment under a fresh id, as `assignSoulToTemplate` writes.
        if (saw.length == _maxAssignments) return;
        final id = 'soul-link-${saw.length}';
        saw[id] = {
          for (final held in await replica.device.repository.getSlotLinks(
            _slot,
          ))
            held.id,
        };
        await _write(
          step.replica,
          AgentLink.soulAssignment(
            id: id,
            fromId: _slotTemplate,
            toId: 'soul-${saw.length}',
            createdAt: at,
            updatedAt: at,
            vectorClock: null,
          ),
        );
      case _LinkOp.unlink when slot:
        final live = [
          for (final held in await replica.device.repository.getSlotLinks(
            _slot,
          ))
            if (held.deletedAt == null) held,
        ];
        if (live.isEmpty) return;
        await _write(
          step.replica,
          live[step.arg % live.length].softDeleted(at),
        );
      case _LinkOp.link:
        // `linkCaptureItem`: the link built afresh under its reused id.
        await _write(
          step.replica,
          AgentLink.parsedItemToTask(
            id: _linkId,
            fromId: 'item',
            toId: 'task',
            createdAt: at,
            updatedAt: at,
            vectorClock: null,
          ),
        );
      case _LinkOp.unlink:
        final live = await replica.device.repository.getLinkById(_linkId);
        if (live == null) return;
        await _write(step.replica, live.softDeleted(at));
      case _LinkOp.deliver:
        final candidates = [
          for (var i = 0; i < sent.length; i++)
            if (!replica.lost.contains(i)) i,
        ];
        if (candidates.isEmpty) return;
        await _deliver(replica, candidates[step.arg % candidates.length]);
      case _LinkOp.lose:
        final candidates = [
          for (var i = 0; i < sent.length; i++)
            if (!replica.delivered.contains(i) && !replica.lost.contains(i)) i,
        ];
        if (candidates.isEmpty) return;
        replica.lost.add(candidates[step.arg % candidates.length]);
      case _LinkOp.backfill:
        if (replica.lost.isEmpty) return;
        final lost = replica.lost.toList();
        await _backfill(replica, lost[step.arg % lost.length]);
    }
  }

  /// Every version reaches every replica, directly or by backfill, each in
  /// its own order.
  Future<void> deliverAll() async {
    for (final (r, replica) in replicas.indexed) {
      final order = [for (var i = 0; i < sent.length; i++) i];
      for (final index in r.isOdd ? order.reversed : order) {
        if (replica.delivered.contains(index) ||
            replica.resolved.contains(index)) {
          continue;
        }
        if (replica.lost.contains(index)) {
          await _backfill(replica, index);
        } else {
          await _deliver(replica, index);
        }
      }
    }
  }

  Future<void> checkStep(List<_LinkStep> trace) async {
    for (final replica in replicas) {
      for (final index in replica.delivered) {
        final row = (await replica.row(sent[index].id))!;
        expect(
          VectorClock.compare(sent[index].vectorClock!, row.vectorClock!),
          isNot(VclockStatus.a_gt_b),
          reason:
              'NoLostSuccessor on ${replica.device.host}: $row replaced by '
              '${sent[index]}: $trace',
        );
      }
      if (slot) await _checkSlot(replica, trace);
    }
  }

  /// The slot shows the live assignment ranked first, and ranks each above
  /// every assignment its writer held (SuccessorOutranks).
  Future<void> _checkSlot(_LinkReplica replica, List<_LinkStep> trace) async {
    final live = [
      for (final held in await replica.device.repository.getSlotLinks(_slot))
        if (held.deletedAt == null) held,
    ];
    expect(
      (await replica.visible()).map((l) => l.id),
      live.isEmpty ? isEmpty : [live.selectPrimary().id],
      reason: 'visible link on ${replica.device.host}: $trace',
    );
    final rank = {
      for (final (i, link) in live.orderedPrimaryFirst().indexed) link.id: i,
    };
    for (final link in live) {
      for (final held in saw[link.id]!) {
        if (!rank.containsKey(held)) continue;
        expect(
          rank[link.id]! < rank[held]!,
          isTrue,
          reason:
              'SuccessorOutranks on ${replica.device.host}: ${link.id} '
              'below $held: $trace',
        );
      }
    }
  }

  Future<void> checkConverged(List<_LinkStep> trace) async {
    for (final id in {for (final v in sent) v.id, if (!slot) _linkId}) {
      final rows = [for (final replica in replicas) await replica.row(id)];
      for (final row in rows.skip(1)) {
        expect(
          row?.toJson(),
          rows.first?.toJson(),
          reason: 'Converged: $trace',
        );
      }
    }
    if (!slot) return;
    final shown = [
      for (final replica in replicas)
        (await replica.visible()).map((l) => l.toId).toList(),
    ];
    for (final soul in shown.skip(1)) {
      expect(soul, shown.first, reason: 'SlotConverged: $trace');
    }
  }
}

Future<void> _runLinkTrace(List<_LinkStep> trace, {bool slot = false}) async {
  final world = _LinkWorld(slot: slot);
  try {
    for (final step in trace) {
      await world.run(step);
      await world.checkStep(trace);
    }
    await world.deliverAll();
    await world.checkStep(trace);
    await world.checkConverged(trace);
  } finally {
    await world.close();
  }
}

void _registerLinkModelConformance() {
  group('model conformance with specs/tla/AgentLinks.tla', () {
    glados.Glados(
      glados.any.linkTrace,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'generated links, removals, losses and arrival orders converge without '
      'losing a successor',
      _runLinkTrace,
      tags: 'glados',
    );

    glados.Glados(
      glados.any.linkTrace,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'generated soul reassignments, removals, losses and arrival orders show '
      'one soul everywhere, the one ranked first',
      (trace) => _runLinkTrace(trace, slot: true),
      tags: 'glados',
    );

    test(
      'the TLC counterexample: two devices reassign one soul concurrently '
      'and each receives the other',
      () => _runLinkTrace(slot: true, const [
        // hA and hB assign; hA receives hB's, hB receives hA's; hC both.
        _LinkStep(_LinkOp.link, 0, 0),
        _LinkStep(_LinkOp.link, 1, 0),
        _LinkStep(_LinkOp.deliver, 0, 1),
        _LinkStep(_LinkOp.deliver, 1, 0),
      ]),
    );
  });
}
