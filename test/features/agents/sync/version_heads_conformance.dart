import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;

import 'agent_replica_bench.dart';

// Model conformance with `specs/tla/VersionHeads.tla`: a versioned document on
// two devices that edit it offline — each device a real agent database,
// repository and sync service — exchanging every row write, one sync message
// at a time, in generated orders through the real receive decision. The
// edits are the real services' (a soul or template version and rollback, a
// goal revision); what differs per document is a [VersionedDocument].

/// A versioned document under test: how the real service creates it, edits
/// it and rolls it back, and how its head and version rows read back.
abstract class VersionedDocument {
  /// The id every row of the document is filed under (`agentId`).
  String get documentId;

  /// Whether the service offers a rollback (soul documents and templates).
  bool get rollsBack;

  /// Creates the document, its first version and its head on [author].
  Future<void> create(AgentReplica author);

  /// Mints a new version on [device]; [serial] makes the content distinct.
  /// A refusal — a goal revision whose head's version has not synced in —
  /// writes nothing.
  Future<void> edit(AgentReplica device, int serial);

  /// Rolls [device]'s document back to [versionId].
  Future<void> rollback(AgentReplica device, String versionId);

  /// The version the head row names on [device], or null without a head.
  Future<String?> headVersionId(AgentReplica device);

  /// Every version row on [device], id to status, oldest first: by ordinal,
  /// then by creation time — never by id, which is random.
  Future<Map<String, String>> versionStatuses(AgentReplica device);

  /// The version the service's read path calls active, or null when it
  /// resolves nothing.
  Future<String?> activeVersionId(AgentReplica device);

  /// Whether [status] is the active one.
  bool isActive(String status);
}

enum _HeadOp { edit, rollback, deliver }

class _HeadStep {
  const _HeadStep(this.op, this.device, this.arg);

  factory _HeadStep.decode(int code) => _HeadStep(
    // Deliveries are twice as common: an edit writes several rows.
    switch (code % 4) {
      0 => _HeadOp.edit,
      1 => _HeadOp.rollback,
      _ => _HeadOp.deliver,
    },
    (code ~/ 4) % 2,
    code ~/ 8,
  );

  final _HeadOp op;
  final int device;

  /// Picks the rollback target or the write to deliver.
  final int arg;

  @override
  String toString() => '${op.name}(d$device, $arg)';
}

extension _AnyHeadTrace on glados.Any {
  glados.Generator<List<_HeadStep>> get headTrace => glados.ListAnys(this)
      .listWithLengthInRange(1, 24, glados.IntAnys(this).intInRange(0, 8 * 8))
      .map((codes) => [for (final code in codes) _HeadStep.decode(code)]);
}

/// Edits per device, as the model bounds them (`EditsPerDevice`), plus one:
/// traces are shorter than the model's exhaustive search, so they can afford
/// it.
const _maxEditsPerDevice = 3;

class _HeadBench {
  _HeadBench(this.doc) {
    devices = [network.join('hA'), network.join('hB')];
  }

  final VersionedDocument doc;
  final network = ReplicaNetwork();
  late final List<AgentReplica> devices;
  final _edits = [0, 0];
  var _now = DateTime(2026, 9, 25, 9);
  var _serial = 0;

  /// Ghost of the model's `clean`: the last edit was made by a device that
  /// had received every write.
  bool clean = false;

  /// The device that made the last edit, which the settling edit at the end
  /// is not made on: the other device's writes are the ones it has to settle.
  int _lastEditor = 1;

  /// Runs [action] on [device]'s clock. The model's clock is shared; here
  /// the second device's runs [_skew] ahead, which is the case the head's
  /// carried clock exists for (ADR 0068 addendum): with it, a later edit can
  /// carry an earlier timestamp than the head it replaces.
  Future<T> _at<T>(int device, Future<T> Function() action) {
    _now = _now.add(const Duration(minutes: 1));
    return withClock(
      Clock.fixed(device == 0 ? _now : _now.add(_skew)),
      action,
    );
  }

  static const _skew = Duration(minutes: 2);

  Future<void> setUp() async {
    await _at(0, () => doc.create(devices[0]));
    await network.deliverAll();
  }

  Future<void> run(_HeadStep step) async {
    final device = devices[step.device];
    switch (step.op) {
      case _HeadOp.deliver:
        final pending = network.pendingFor(device);
        if (pending.isEmpty) return;
        await device.receive(pending[step.arg % pending.length]);
      case _HeadOp.edit:
        if (_edits[step.device] >= _maxEditsPerDevice) return;
        await editOn(step.device);
      case _HeadOp.rollback:
        if (!doc.rollsBack || _edits[step.device] >= _maxEditsPerDevice) {
          return;
        }
        final head = await doc.headVersionId(device);
        final targets = (await doc.versionStatuses(
          device,
        )).keys.where((id) => id != head).toList();
        if (targets.isEmpty) return;
        final isClean = network.pendingFor(device).isEmpty;
        _edits[step.device]++;
        _lastEditor = step.device;
        await _at(
          step.device,
          () => doc.rollback(device, targets[step.arg % targets.length]),
        );
        clean = isClean;
    }
  }

  Future<void> editOn(int index) async {
    final device = devices[index];
    final isClean = network.pendingFor(device).isEmpty;
    final sentBefore = network.sent.length;
    await _at(index, () => doc.edit(device, ++_serial));
    // A refused revision writes nothing and is no edit: it neither counts
    // against the device's budget nor changes the ghost.
    if (network.sent.length != sentBefore) {
      _edits[index]++;
      clean = isClean;
      _lastEditor = index;
    }
  }

  /// The edit that settles what the trace left, made on the device that
  /// did not make the last edit.
  Future<void> settlingEdit() => editOn(1 - _lastEditor);

  /// The model's invariants, which it states over quiescent states: once
  /// every write has reached every device, both hold the same rows
  /// (`Converged`), the head names a version the device has
  /// (`HeadResolves`) and the service's read resolves to it; after an edit
  /// made with everything received, that version is the only active one
  /// (`SettlesAfterCleanEdit`).
  Future<void> check(Object trace) async {
    if (!network.quiescent) return;
    final rows = [
      for (final device in devices)
        [
          for (final entity in await device.repository.getEntitiesByAgentId(
            doc.documentId,
          ))
            jsonEncode(entity.toJson()),
        ]..sort(),
    ];
    expect(rows[1], rows[0], reason: 'Converged: $trace');
    for (final device in devices) {
      final head = await doc.headVersionId(device);
      final statuses = await doc.versionStatuses(device);
      expect(
        statuses.keys,
        contains(head),
        reason: 'HeadResolves on ${device.host}: $trace',
      );
      expect(
        await doc.activeVersionId(device),
        head,
        reason: 'the active read follows the head on ${device.host}: $trace',
      );
      if (clean) {
        expect(
          [
            for (final MapEntry(:key, :value) in statuses.entries)
              if (doc.isActive(value)) key,
          ],
          [head],
          reason: 'SettlesAfterCleanEdit on ${device.host}: $trace',
        );
      }
    }
  }
}

/// Registers the generated trace for [doc] (built fresh per run).
void registerVersionHeadsConformance(
  String label,
  VersionedDocument Function() doc, {
  int numRuns = 150,
}) {
  glados.Glados(
    glados.any.headTrace,
    glados.ExploreConfig(numRuns: numRuns),
  ).test(
    '$label: generated offline edits and arrival orders converge, keep the '
    'head resolving, and settle after a clean edit '
    '(specs/tla/VersionHeads.tla)',
    (trace) async {
      final bench = _HeadBench(doc());
      try {
        await bench.setUp();
        for (final step in trace) {
          await bench.run(step);
          await bench.check(trace);
        }
        // Everything delivered: the model's quiescent state.
        await bench.network.deliverAll();
        await bench.check(trace);
        // And the claim the model checks for the residual concurrent edits
        // leave: the next edit made with everything received settles them.
        await bench.settlingEdit();
        await bench.network.deliverAll();
        expect(bench.clean, isTrue, reason: 'the settling edit was clean');
        await bench.check(trace);
      } finally {
        await bench.network.close();
      }
    },
    tags: 'glados',
  );
}
