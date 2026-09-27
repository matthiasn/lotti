part of 'agent_template_seeding_test.dart';

// Model conformance with the seeded kind of `specs/tla/AgentReplication.tla`:
// the default Tom template, the default Tom soul and the seeded assignment
// between them on three devices — each a real agent database, repository
// and sync service — that start (and seed) at any point, while the user
// renames and deletes the template, unassigns the soul and deletes it, with
// every write delivered through the real receive decision in generated
// orders. One device's clock runs ahead, so its seed can be stamped after a
// deletion it has not heard of. The trace checks the model's invariants for
// each of the three rows: a device that has received or made a removal of
// one never holds a live seed of it (SeedYieldsToRemoval); a row is never a
// version that a write it received causally replaced (NoLostSuccessor); and
// once every write has arrived, all devices hold the same row (Converged).

enum _SeedOp { start, rename, deleteTemplate, unassign, deleteSoul, deliver }

class _SeedStep {
  const _SeedStep(this.op, this.device, this.arg);

  factory _SeedStep.decode(int code) => _SeedStep(
    _SeedOp.values[code % _SeedOp.values.length],
    (code ~/ _SeedOp.values.length) % 3,
    code ~/ (_SeedOp.values.length * 3),
  );

  final _SeedOp op;
  final int device;

  /// Picks the delivery.
  final int arg;

  @override
  String toString() => '${op.name}(d$device, $arg)';
}

extension _AnySeedTrace on glados.Any {
  glados.Generator<List<_SeedStep>> get seedTrace => glados.ListAnys(this)
      .listWithLengthInRange(
        1,
        24,
        glados.IntAnys(this).intInRange(0, _SeedOp.values.length * 24),
      )
      .map((codes) => [for (final code in codes) _SeedStep.decode(code)]);
}

/// The three rows a seed writes under a well-known id: the template and the
/// soul, which are entities, and the assignment between them, a link.
final String _seededAssignmentId = seededSoulAssignmentLinkId(tomTemplateId);

class _SeedBench {
  _SeedBench() {
    replicas = [network.join('hA'), network.join('hB'), network.join('hC')];
    devices = [for (final r in replicas) DefaultSeedingDevice(r.device)];
  }

  final network = ReplicaNetwork();
  late final List<AgentReplica> replicas;
  late final List<DefaultSeedingDevice> devices;

  var _now = DateTime(2026, 9, 27, 9);
  var _serial = 0;

  /// Per row id, the clocks of the versions a seed wrote. A version is
  /// identified by its clock, which the receive keeps on the version that
  /// wins; a seed built over a tombstone is found this way even though the
  /// local write resolution raised its timestamp to the removal's.
  final _seedClocks = <String, Set<VectorClock>>{};

  /// The second device's clock runs ahead, so a seed it stamps with the
  /// wall clock would sort after a deletion made later on another device.
  DateTime _clockOf(int device) =>
      device == 1 ? _now.add(const Duration(minutes: 2)) : _now;

  Future<void> _act(int device, Future<void> Function() action) async {
    _now = _now.add(const Duration(minutes: 1));
    await withClock(Clock.fixed(_clockOf(device)), action);
  }

  Future<void> run(_SeedStep step) async {
    final d = step.device;
    final device = devices[d];
    switch (step.op) {
      case _SeedOp.start:
        final before = network.sent.length;
        await _act(d, device.start);
        for (var i = before; i < network.sent.length; i++) {
          for (final id in _rows) {
            final version = _version(network.sent[i].message, id);
            if (version != null) {
              (_seedClocks[id] ??= {}).add(version.clock);
            }
          }
        }
      case _SeedOp.rename:
        if (await device.templates.getTemplate(tomTemplateId) == null) return;
        await _act(
          d,
          () => device.templates.updateTemplate(
            templateId: tomTemplateId,
            displayName: 'Tom ${++_serial}',
          ),
        );
      case _SeedOp.deleteTemplate:
        if (await device.templates.getTemplate(tomTemplateId) == null) return;
        await _act(d, () => device.templates.deleteTemplate(tomTemplateId));
      case _SeedOp.unassign:
        await _act(d, () => device.soulAssignments.unassignSoul(tomTemplateId));
      case _SeedOp.deleteSoul:
        if (await device.souls.getSoul(tomSoulId) == null) return;
        if ((await device.soulAssignments.getTemplatesUsingSoul(
          tomSoulId,
        )).isNotEmpty) {
          return;
        }
        await _act(d, () => device.soulAssignments.deleteSoul(tomSoulId));
      case _SeedOp.deliver:
        final pending = network.pendingFor(replicas[d]);
        if (pending.isEmpty) return;
        await replicas[d].receive(pending[step.arg % pending.length]);
    }
  }

  /// The versions of [id] that [device] has made or received.
  List<({VectorClock clock, bool removed})> _seen(int device, String id) {
    final replica = replicas[device];
    return [
      for (var i = 0; i < network.sent.length; i++)
        if (network.sent[i].from == replica.host ||
            replica.received.contains(i))
          ?_version(network.sent[i].message, id),
    ];
  }

  static ({VectorClock clock, bool removed})? _version(
    SyncMessage message,
    String id,
  ) {
    final entity = message.mapOrNull(agentEntity: (m) => m.agentEntity);
    if (entity != null && entity.id == id) {
      return (clock: entity.vectorClock!, removed: entity.deletedAt != null);
    }
    final link = message.mapOrNull(agentLink: (m) => m.agentLink);
    if (link != null && link.id == id) {
      return (clock: link.vectorClock!, removed: link.deletedAt != null);
    }
    return null;
  }

  /// The stored version of [id] on [device]: its clock, whether it is a
  /// live seed, and its synced content.
  Future<({VectorClock clock, bool liveSeed, Object json})?> _stored(
    int device,
    String id,
  ) async {
    final ({VectorClock clock, bool live, Object json})? row;
    if (id == _seededAssignmentId) {
      final link = await devices[device].storedLink(id);
      row = link == null
          ? null
          : (
              clock: link.vectorClock!,
              live: link.deletedAt == null,
              json: link.toJson(),
            );
    } else {
      final entity = await devices[device].stored(id);
      row = entity == null
          ? null
          : (
              clock: entity.vectorClock!,
              live: entity.deletedAt == null,
              json: entity.toJson(),
            );
    }
    if (row == null) return null;
    return (
      clock: row.clock,
      liveSeed: row.live && (_seedClocks[id]?.contains(row.clock) ?? false),
      json: row.json,
    );
  }

  static const List<String> _ids = [tomTemplateId, tomSoulId];

  List<String> get _rows => [..._ids, _seededAssignmentId];

  Future<void> checkStep(Object trace) async {
    for (var d = 0; d < devices.length; d++) {
      for (final id in _rows) {
        final stored = await _stored(d, id);
        final seen = _seen(d, id);
        if (stored == null) {
          expect(seen, isEmpty, reason: '$id lost on d$d: $trace');
          continue;
        }
        if (seen.any((v) => v.removed)) {
          expect(
            stored.liveSeed,
            isFalse,
            reason: 'SeedYieldsToRemoval for $id on d$d: $trace',
          );
        }
        for (final version in seen) {
          expect(
            causallyBefore(stored.clock, version.clock),
            isFalse,
            reason: 'NoLostSuccessor for $id on d$d: $trace',
          );
        }
      }
    }
  }

  Future<void> checkConverged(Object trace) async {
    for (final id in _rows) {
      final rows = [
        for (var d = 0; d < devices.length; d++) (await _stored(d, id))?.json,
      ];
      for (final row in rows.skip(1)) {
        expect(row, rows.first, reason: 'Converged for $id: $trace');
      }
    }
  }
}

void registerSeedingModelConformance() {
  glados.Glados(
    glados.any.seedTrace,
    glados.ExploreConfig(numRuns: 60),
  ).test(
    'a default template, soul and assignment seeded, edited and deleted on '
    'three devices converge, and a deletion is never undone by a seed '
    '(specs/tla/AgentReplication.tla, the seeded kind)',
    (trace) async {
      final bench = _SeedBench();
      try {
        for (final step in trace) {
          await bench.run(step);
          await bench.checkStep(trace);
        }
        await bench.network.deliverAll();
        await bench.checkStep(trace);
        await bench.checkConverged(trace);
      } finally {
        await bench.network.close();
      }
    },
    tags: 'glados',
  );
}
