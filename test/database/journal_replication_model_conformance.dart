part of 'database_entity_ops_test.dart';

// Model conformance with specs/tla/JournalReplication.tla: one journal entry
// on three devices, each a real in-memory JournalDb, written by the
// product's writers -- an edit or a deletion of the entry the live read
// returns, an edit of an entry a screen read earlier, a restore of a deleted
// entry, and the user's resolution of an open conflict (the real
// resolveToSide) -- and exchanged in generated orders through the real write
// decision, JournalDb.updateJournalEntity. Deliveries repeat, arrive late or
// are lost and recovered from the writer's stored row, as the backfill
// responder serves it. Every version carries the ghost history the model's
// properties are written in; after every step the trace checks
// NoLostSuccessor, NothingDropped and ConflictNotStale, and once everything
// has arrived, Converged.

enum _ReplicaOp {
  edit,
  delete,
  snapshot,
  staleEdit,
  restore,
  resolve,
  deliver,
  lose,
  backfill,
}

class _ReplicaStep {
  const _ReplicaStep(this.op, this.device, this.arg);

  factory _ReplicaStep.decode(int code) => _ReplicaStep(
    _ReplicaOp.values[code % _ReplicaOp.values.length],
    (code ~/ _ReplicaOp.values.length) % 3,
    code ~/ (_ReplicaOp.values.length * 3),
  );

  final _ReplicaOp op;
  final int device;

  /// Picks the delivery, the lost version to recover, or the side kept.
  final int arg;

  @override
  String toString() => '${op.name}(d$device, $arg)';
}

extension _AnyReplicaTrace on glados.Any {
  glados.Generator<List<_ReplicaStep>> get replicaTrace => glados.ListAnys(this)
      .listWithLengthInRange(
        1,
        18,
        glados.IntAnys(
          this,
        ).intInRange(0, _ReplicaOp.values.length * 3 * 8),
      )
      .map(
        (codes) => [for (final code in codes) _ReplicaStep.decode(code)],
      );
}

/// Local writes per trace, as the model bounds them (`MaxWrites`), plus two:
/// traces are shorter than the model's exhaustive search.
const _maxReplicaWrites = 5;

const _replicaEntryId = 'replicated';

/// A version as the model sees it: its content, which names the write that
/// made it, and its clock.
String _keyOf(JournalEntity v) =>
    '${v.entryText?.plainText}|${v.meta.vectorClock?.vclock}';

/// [a] is covered by [b], component-wise.
bool _clockLeq(VectorClock? a, VectorClock? b) {
  if (a == null || b == null) return false;
  return a.vclock.entries.every((e) => (b.vclock[e.key] ?? 0) >= e.value);
}

class _ReplicaBench {
  _ReplicaBench(this.dbs);

  final List<JournalDb> dbs;
  static const hosts = ['hA', 'hB', 'hC'];

  /// Ghost histories, clocks and deletions, by version key.
  final _hist = <String, Set<int>>{};
  final _clockOf = <String, VectorClock?>{};
  final _deleted = <String, bool>{};

  /// Every version sent, in order, with its writer.
  final _sent = <({int from, JournalEntity version})>[];

  /// Per device: sent versions it received, directly or by backfill.
  final _received = [<int>{}, <int>{}, <int>{}];
  final _lost = [<int>{}, <int>{}, <int>{}];

  /// Per device: keys of the versions received or written there.
  final _seen = [<String>{}, <String>{}, <String>{}];

  /// Per device: conflicts another version displaced (the residual).
  final _displaced = [<String>{}, <String>{}, <String>{}];
  final _snapshots = <JournalEntity?>[null, null, null];
  final _counters = [0, 0, 0];
  var _writes = 0;
  var _serial = 0;

  Future<void> setUp() async {
    final first = JournalEntity.journalEntry(
      meta: Metadata(
        id: _replicaEntryId,
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
        vectorClock: const VectorClock({'h0': 1}),
      ),
      entryText: const EntryText(plainText: 'v0'),
    );
    _register(first, {0});
    for (var d = 0; d < dbs.length; d++) {
      await clearAllTables(dbs[d]);
      await dbs[d].updateJournalEntity(first);
      _seen[d].add(_keyOf(first));
    }
  }

  void _register(JournalEntity v, Set<int> history) {
    final key = _keyOf(v);
    _hist[key] = history;
    _clockOf[key] = v.meta.vectorClock;
    _deleted[key] = v.meta.deletedAt != null;
  }

  Set<int> _histOf(JournalEntity v) => _hist[_keyOf(v)]!;

  Future<JournalEntity> _stored(int d) async =>
      (await dbs[d].journalEntityByIdIncludingDeleted(_replicaEntryId))!;

  Future<JournalEntity?> _openConflict(int d) async {
    final conflict = await dbs[d].conflictById(_replicaEntryId);
    if (conflict == null ||
        conflict.status != ConflictStatus.unresolved.index) {
      return null;
    }
    return JournalEntity.fromJson(
      jsonDecode(conflict.serialized) as Map<String, dynamic>,
    );
  }

  /// A new version device [d] writes on [base]: its clock plus the device's
  /// next counter (MetadataService.updateMetadata), named by a fresh id.
  JournalEntity _versionOn(int d, JournalEntity base, {bool? deleted}) {
    final clock = VectorClock({
      ...?base.meta.vectorClock?.vclock,
      hosts[d]: ++_counters[d],
    });
    final id = ++_serial;
    return base.copyWith(
      meta: base.meta.copyWith(
        vectorClock: clock,
        deletedAt: (deleted ?? base.meta.deletedAt != null)
            ? testDate.add(Duration(minutes: id))
            : null,
      ),
      entryText: EntryText(plainText: 'v$id'),
    );
  }

  /// Device [d] writes [version], built over [bases], through the write
  /// decision; an applied version is sent. Its history: its bases', plus
  /// every version the device knows whose clock it covers (on one device the
  /// last save supersedes an earlier one, as the model's `Covered` says).
  Future<void> _write(
    int d,
    JournalEntity version,
    List<JournalEntity> bases,
  ) async {
    _writes++;
    final clock = version.meta.vectorClock;
    _register(version, {
      for (final b in bases) ..._histOf(b),
      for (final key in _seen[d])
        if (_clockLeq(_clockOf[key], clock)) ..._hist[key]!,
      _serial,
    });
    final result = await _decide(d, version);
    _seen[d].add(_keyOf(version));
    if (result.applied) {
      _sent.add((from: d, version: await _stored(d)));
    }
  }

  /// JournalDb.updateJournalEntity on device [d], keeping the ghosts of a
  /// merged deletion and of a displaced conflict.
  Future<JournalUpdateResult> _decide(int d, JournalEntity incoming) async {
    final before = await _stored(d);
    final conflictBefore = await _openConflict(d);
    final result = await dbs[d].updateJournalEntity(incoming);
    final after = await _stored(d);
    if (!_hist.containsKey(_keyOf(after))) {
      // Two deletions merged: the winner's fields under the joined clock.
      _register(after, {..._histOf(before), ..._histOf(incoming)});
    }
    final conflictAfter = await _openConflict(d);
    if (conflictBefore != null &&
        conflictAfter != null &&
        !_histOf(conflictAfter).containsAll(_histOf(conflictBefore))) {
      _displaced[d].add(_keyOf(conflictBefore));
    }
    return result;
  }

  Future<void> _receive(int d, JournalEntity version) async {
    await _decide(d, version);
    _seen[d].add(_keyOf(version));
  }

  List<int> _pendingFor(int d) => [
    for (var i = 0; i < _sent.length; i++)
      if (_sent[i].from != d && !_lost[d].contains(i)) i,
  ];

  Future<void> run(_ReplicaStep step) async {
    final d = step.device;
    final writesLeft = _writes < _maxReplicaWrites;
    switch (step.op) {
      case _ReplicaOp.edit || _ReplicaOp.delete:
        final live = await dbs[d].journalEntityById(_replicaEntryId);
        if (!writesLeft || live == null) return;
        await _write(
          d,
          _versionOn(d, live, deleted: step.op == _ReplicaOp.delete),
          [live],
        );
      case _ReplicaOp.snapshot:
        _snapshots[d] = await dbs[d].journalEntityById(_replicaEntryId);
      case _ReplicaOp.staleEdit:
        final snapshot = _snapshots[d];
        if (!writesLeft || snapshot == null) return;
        await _write(
          d,
          _versionOn(d, snapshot, deleted: step.arg.isOdd),
          [snapshot],
        );
      case _ReplicaOp.restore:
        final stored = await _stored(d);
        if (!writesLeft || stored.meta.deletedAt == null) return;
        await _write(d, _versionOn(d, stored, deleted: false), [stored]);
      case _ReplicaOp.resolve:
        final remote = await _openConflict(d);
        if (!writesLeft || remote == null) return;
        final local = await _stored(d);
        final chosen = resolveToSide(
          local: local,
          remote: remote,
          side: step.arg.isEven ? ConflictSide.local : ConflictSide.remote,
        );
        await _write(d, _versionOn(d, chosen), [local, remote]);
      case _ReplicaOp.deliver:
        final pending = _pendingFor(d);
        if (pending.isEmpty) return;
        final index = pending[step.arg % pending.length];
        _received[d].add(index);
        await _receive(d, _sent[index].version);
      case _ReplicaOp.lose:
        final pending = [
          for (final i in _pendingFor(d))
            if (!_received[d].contains(i)) i,
        ];
        if (pending.isEmpty) return;
        _lost[d].add(pending[step.arg % pending.length]);
      case _ReplicaOp.backfill:
        if (_lost[d].isEmpty) return;
        await _backfill(d, _lost[d].elementAt(step.arg % _lost[d].length));
    }
  }

  /// The writer of the lost version answers with its stored row, deletion
  /// included, when that still carries the requested counter.
  Future<void> _backfill(int d, int index) async {
    _lost[d].remove(index);
    _received[d].add(index);
    final lost = _sent[index];
    final host = hosts[lost.from];
    final answer = await _stored(lost.from);
    final counter = answer.meta.vectorClock?.vclock[host] ?? 0;
    if (counter < lost.version.meta.vectorClock!.vclock[host]!) return;
    await _receive(d, answer);
  }

  /// Every version reaches every device: the lost ones by backfill, the
  /// rest directly.
  Future<void> settle() async {
    for (var d = 0; d < dbs.length; d++) {
      for (final index in _lost[d].toList()) {
        await _backfill(d, index);
      }
      for (final index in _pendingFor(d)) {
        if (_received[d].add(index)) {
          await _receive(d, _sent[index].version);
        }
      }
    }
  }

  /// [v] keeps the version [key]: it follows it, or both delete the entry.
  bool _keeps(JournalEntity v, String key) =>
      _histOf(v).containsAll(_hist[key]!) ||
      (v.meta.deletedAt != null && _deleted[key]!);

  bool _displacedKeeps(int d, String key) =>
      _displaced[d].any((x) => _hist[x]!.containsAll(_hist[key]!));

  static bool _replaced(Set<int> v, Set<int> m) =>
      v.length < m.length && m.containsAll(v);

  Future<void> checkStep(Object trace) async {
    for (var d = 0; d < dbs.length; d++) {
      final row = await _stored(d);
      final conflict = await _openConflict(d);
      final host = hosts[d];
      for (final key in _seen[d]) {
        expect(
          _replaced(_histOf(row), _hist[key]!),
          isFalse,
          reason: 'NoLostSuccessor on $host ($key): $trace',
        );
        expect(
          _keeps(row, key) ||
              (conflict != null && _keeps(conflict, key)) ||
              _displacedKeeps(d, key),
          isTrue,
          reason: 'NothingDropped on $host ($key): $trace',
        );
        if (conflict != null && _replaced(_histOf(conflict), _hist[key]!)) {
          expect(
            _displacedKeeps(d, key),
            isTrue,
            reason: 'ConflictNotStale on $host ($key): $trace',
          );
        }
      }
      if (conflict != null) {
        expect(
          _histOf(row).containsAll(_histOf(conflict)),
          isFalse,
          reason: 'ConflictNotStale on $host: $trace',
        );
      }
    }
  }

  Future<void> checkConverged(Object trace) async {
    final rows = [for (var d = 0; d < dbs.length; d++) await _stored(d)];
    final open = [for (var d = 0; d < dbs.length; d++) await _openConflict(d)];
    final same = rows.every((r) => _keyOf(r) == _keyOf(rows.first));
    final allDeleted = rows.every((r) => r.meta.deletedAt != null);
    expect(
      same || allDeleted || open.any((c) => c != null),
      isTrue,
      reason: 'Converged: $trace',
    );
  }
}

void registerJournalReplicationConformance(List<JournalDb> Function() dbs) {
  glados.Glados(
    glados.any.replicaTrace,
    glados.ExploreConfig(numRuns: 400),
  ).test(
    'a journal entry edited, deleted, restored and resolved on three devices '
    'never diverges silently, and nothing received is dropped without a '
    'conflict (specs/tla/JournalReplication.tla)',
    (trace) async {
      final bench = _ReplicaBench(dbs());
      await bench.setUp();
      for (final step in trace) {
        await bench.run(step);
        await bench.checkStep(trace);
      }
      await bench.settle();
      await bench.checkStep(trace);
      await bench.checkConverged(trace);
    },
    // Four hundred traces: fewer miss the late copy that regresses an open
    // conflict (KeepNewerConflict).
    timeout: const Timeout(Duration(minutes: 3)),
    tags: 'glados',
  );
}
