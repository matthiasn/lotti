part of 'agent_wake_coordinator_test.dart';

// Model conformance with `specs/tla/AgentWakeCoordination.tla`: two devices,
// each with a real `AgentWakeCoordinator`, over one agent. Generated traces
// of the model's actions — edits, journal sync (with or without the synced
// audio wake, `WakeOnSync`), dispatch, completion, failure, delivery and loss
// of one message, a crash, and time moving 15 seconds at a time — drive the
// coordinators through a FIFO channel per direction, as the outbox and the
// Matrix room order one sender's rows. The mix leans towards dispatch,
// delivery and time, where the protocol decides anything.
//
// Beside the code, the trace keeps the model's own view of each peer
// (`claimed`, `hash`, `left`, `done`) and updates it by the spec's `Deliver`
// and `Tick`. Every dispatch must decide what the spec's guards decide:
// cancel exactly when `Covered`, defer exactly when `Blocked`, proceed
// otherwise. The view also applies the code's one extension of the spec: a
// peer's completed digests are bounded to the most recent `doneHistoryLimit`.
// Delivery here is unbounded; a late claim is timed from its receipt. After every step `CancelCovered` must hold, and so must the
// sender's side of `Tick`: a live run has claimed within the last heartbeat
// interval. After the trace is played out to quiescence, `NoLostEdit`.

enum _Op {
  edit,
  sync,
  syncWake,
  dispatch,
  complete,
  fail,
  deliver,
  lose,
  crash,
  tick,
}

/// The generated alphabet: each op for either device, weighted.
const List<(_Op, int)> _alphabet = [
  (_Op.edit, 1),
  (_Op.sync, 1),
  (_Op.syncWake, 1),
  (_Op.dispatch, 2),
  (_Op.complete, 1),
  (_Op.fail, 1),
  (_Op.deliver, 2),
  (_Op.lose, 1),
  (_Op.crash, 1),
];
final List<_Step> _steps = [
  for (final (op, weight) in _alphabet)
    for (var i = 0; i < weight; i++) ...[_Step(op, 0), _Step(op, 1)],
  for (var i = 0; i < 4; i++) const _Step(_Op.tick, 0),
];

class _Step {
  const _Step(this.op, this.device);

  final _Op op;
  final int device;

  @override
  String toString() => op == _Op.tick ? 'tick' : '${op.name}(${'ab'[device]})';
}

extension _AnyCoordinationTrace on glados.Any {
  glados.Generator<List<_Step>> get coordinationTrace => glados.ListAnys(this)
      .listWithLengthInRange(
        1,
        40,
        glados.IntAnys(this).intInRange(0, _steps.length),
      )
      .map((codes) => [for (final code in codes) _steps[code]]);
}

const _tick = Duration(seconds: 15);
final int _timeoutTicks =
    AgentWakeCoordinator.coordinationTimeout.inSeconds ~/ _tick.inSeconds;

/// The spec's view of one peer: its claim and its completed digests.
class _ModelView {
  bool claimed = false;
  String hash = '';
  int left = 0;
  final done = <String>{};
}

class _TraceDevice {
  _TraceDevice(this.name);

  final String name;
  final edits = <int>{};
  bool pending = false;
  String? liveRun;
  String? liveHash;
  DateTime? lastClaimAt;
  int runs = 0;
  late AgentWakeCoordinator coordinator;
  _ModelView model = _ModelView();

  /// Messages this device sent, not yet delivered to its peer.
  final outbox = <SyncAgentWakeCoordination>[];

  String get digest => 'state:${(edits.toList()..sort()).join(',')}';
}

class _CoordinationTrace {
  _CoordinationTrace(this.async) {
    devices.forEach(boot);
  }

  final FakeAsync async;
  final devices = [_TraceDevice('a'), _TraceDevice('b')];
  final okHashes = <String>{};
  final cancelled = <String>{};
  int nextEdit = 1;
  int losses = 0;
  int crashes = 0;

  _TraceDevice peerOf(_TraceDevice device) =>
      identical(device, devices[0]) ? devices[1] : devices[0];

  void boot(_TraceDevice device) {
    device
      ..coordinator = AgentWakeCoordinator(
        digestState: (_) async => device.digest,
        send: (message) async {
          message as SyncAgentWakeCoordination;
          if (message.kind == AgentWakeCoordinationKind.claim) {
            device.lastClaimAt = message.sentAt;
          }
          device.outbox.add(message);
        },
        localHostId: () async => device.name,
      )
      ..model = _ModelView();
  }

  void apply(_Step step) {
    final device = devices[step.device];
    switch (step.op) {
      case _Op.edit:
        device
          ..edits.add(nextEdit++)
          ..pending = true;
      case _Op.sync:
        device.edits.addAll(peerOf(device).edits);
      case _Op.syncWake:
        final before = device.edits.length;
        device.edits.addAll(peerOf(device).edits);
        if (device.edits.length > before) device.pending = true;
      case _Op.dispatch:
        dispatch(device);
      case _Op.complete:
        final runKey = device.liveRun;
        if (runKey == null) return;
        device.coordinator.complete(runKey);
        okHashes.add(device.liveHash!);
        device.liveRun = null;
      case _Op.fail:
        final runKey = device.liveRun;
        if (runKey == null) return;
        device
          ..coordinator.settle(runKey)
          ..liveRun = null
          ..pending = true;
      case _Op.deliver:
        deliver(peerOf(device), device);
      case _Op.lose:
        final from = peerOf(device);
        if (from.outbox.isEmpty || losses >= 1) return;
        losses++;
        from.outbox.removeAt(0);
      case _Op.crash:
        if (crashes >= 1) return;
        crashes++;
        device.coordinator.dispose();
        if (device.liveRun != null) device.pending = true;
        device.liveRun = null;
        boot(device);
      case _Op.tick:
        async.elapse(_tick);
        for (final d in devices) {
          if (d.model.left > 0) d.model.left--;
        }
    }
    async.flushMicrotasks();
    expect(
      cancelled.difference(okHashes),
      isEmpty,
      reason: 'CancelCovered',
    );
    for (final d in devices) {
      if (d.liveRun == null) continue;
      expect(
        clock.now().difference(d.lastClaimAt!),
        lessThanOrEqualTo(AgentWakeCoordinator.heartbeatInterval),
        reason: 'a live run keeps claiming (Tick)',
      );
    }
  }

  void dispatch(_TraceDevice device) {
    if (!device.pending || device.liveRun != null) return;
    final digest = device.digest;
    final model = device.model;
    final covered = model.done.contains(digest);
    final blocked = model.claimed && model.hash == digest && model.left > 0;

    late WakeCoordinationDecision decision;
    device.coordinator.evaluate(_agent).then((value) => decision = value);
    async.flushMicrotasks();

    if (covered) {
      expect(decision, isA<WakeCoordinationCancel>(), reason: 'Covered');
      device.pending = false;
      cancelled.add(digest);
    } else if (blocked) {
      expect(decision, isA<WakeCoordinationDefer>(), reason: 'Blocked');
    } else {
      expect(decision, isA<WakeCoordinationProceed>(), reason: 'Dispatch');
      final runKey = '${device.name}-${device.runs++}';
      device.coordinator.claim(
        agentId: _agent,
        runKey: runKey,
        stateHash: digest,
      );
      device
        ..liveRun = runKey
        ..liveHash = digest
        ..pending = false;
    }
  }

  void deliver(_TraceDevice from, _TraceDevice to) {
    if (from.outbox.isEmpty) return;
    final message = from.outbox.removeAt(0);
    to.coordinator.onMessage(message);

    final view = to.model;
    switch (message.kind) {
      case AgentWakeCoordinationKind.claim:
        view
          ..claimed = true
          ..hash = message.stateHash
          ..left = _timeoutTicks;
      case AgentWakeCoordinationKind.done:
        view
          ..claimed = false
          ..done.remove(message.stateHash)
          ..done.add(message.stateHash);
        if (view.done.length > AgentWakeCoordinator.doneHistoryLimit) {
          view.done.remove(view.done.first);
        }
      case AgentWakeCoordinationKind.release:
        view.claimed = false;
    }
  }

  /// Plays the trace out under the model's fairness: every message is
  /// delivered, every run completes, every owed wake is dispatched, and
  /// time passes, until nothing is left to do.
  void settle() {
    for (var round = 0; round < 40; round++) {
      final quiet = devices.every(
        (d) => !d.pending && d.liveRun == null && d.outbox.isEmpty,
      );
      if (quiet) return;
      for (final device in devices) {
        while (peerOf(device).outbox.isNotEmpty) {
          apply(_Step(_Op.deliver, devices.indexOf(device)));
        }
      }
      for (final device in devices) {
        apply(_Step(_Op.complete, devices.indexOf(device)));
        apply(_Step(_Op.dispatch, devices.indexOf(device)));
      }
      apply(const _Step(_Op.tick, 0));
    }
    fail('the trace did not settle');
  }

  void dispose() {
    for (final device in devices) {
      device.coordinator.dispose();
    }
  }
}

void _registerModelConformance() {
  group('model conformance with specs/tla/AgentWakeCoordination.tla', () {
    glados.Glados(
      glados.any.coordinationTrace,
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'every dispatch decides as the spec does; CancelCovered and NoLostEdit '
      'hold',
      (trace) {
        fakeAsync((async) {
          final bench = _CoordinationTrace(async);
          try {
            trace.forEach(bench.apply);
            bench.settle();
            for (var edit = 1; edit < bench.nextEdit; edit++) {
              expect(
                bench.okHashes.any(
                  (hash) => hash
                      .substring('state:'.length)
                      .split(',')
                      .contains('$edit'),
                ),
                isTrue,
                reason: 'NoLostEdit: edit $edit',
              );
            }
          } finally {
            bench.dispose();
          }
        }, initialTime: _start);
      },
      tags: 'glados',
    );
  });
}
