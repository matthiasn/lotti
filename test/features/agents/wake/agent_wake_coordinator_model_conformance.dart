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
// The model's state is a set of edits; the code's is vector clocks. Each edit
// is a journal entry written by its device with that host's next counter, a
// device's inputs are the entries of the edits it holds, and its watermark is
// the gap-free prefix of each host's counters it holds — as the sync sequence
// log computes it.
//
// Beside the code, the trace keeps the model's own view of each peer
// (`claimed`, `hash`, `left`, `done`, with each state a set of edits) and
// updates it by the spec's `Deliver` and `Tick`. Every dispatch must decide
// what the spec's guards decide: cancel exactly when `Covered`, defer exactly
// when `Blocked`, proceed otherwise — both through `Covers`, the subset
// relation. The view also applies the code's one extension of the spec: a
// peer's completed runs are bounded to the most recent `doneHistoryLimit`.
// Delivery here is unbounded; a late claim is timed from its receipt. After
// every step `CancelCovered` must hold, and so must the sender's side of
// `Tick`: a live run has claimed within the last heartbeat interval. After the
// trace is played out to quiescence, `NoLostEdit`.

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

/// The spec's view of one peer: its claim and its completed states.
class _ModelView {
  bool claimed = false;
  Set<int> hash = {};
  int left = 0;
  final done = <Set<int>>[];
}

/// Who wrote an edit, with which of its counters.
typedef _Origin = ({String host, int counter});

class _TraceDevice {
  _TraceDevice(this.name);

  final String name;
  final edits = <int>{};
  bool pending = false;
  String? liveRun;
  Set<int>? liveHash;
  DateTime? lastClaimAt;
  int runs = 0;
  late AgentWakeCoordinator coordinator;
  _ModelView model = _ModelView();

  /// Messages this device sent, not yet delivered to its peer.
  final outbox = <SyncAgentWakeCoordination>[];
}

class _CoordinationTrace {
  _CoordinationTrace(this.async) {
    devices.forEach(boot);
  }

  final FakeAsync async;
  final devices = [_TraceDevice('a'), _TraceDevice('b')];
  final origins = <int, _Origin>{};
  final counters = <String, int>{'a': 0, 'b': 0};

  /// The state each run read, by run key: what its claim and done announce.
  final runStates = <String, Set<int>>{};
  final okHashes = <Set<int>>[];
  final cancelled = <Set<int>>[];
  int nextEdit = 1;
  int losses = 0;
  int crashes = 0;

  _TraceDevice peerOf(_TraceDevice device) =>
      identical(device, devices[0]) ? devices[1] : devices[0];

  WakeInputs inputsOf(_TraceDevice device) => WakeInputs(
    clocks: {
      for (final edit in device.edits)
        'entry:edit-$edit': VectorClock({
          origins[edit]!.host: origins[edit]!.counter,
        }),
    },
    readsPrivate: false,
    definitions: _definitions,
  );

  Map<String, int> watermarkOf(_TraceDevice device) {
    final held = {
      for (final edit in device.edits)
        (origins[edit]!.host, origins[edit]!.counter),
    };
    return {
      for (final host in counters.keys)
        host: () {
          var counter = 0;
          while (held.contains((host, counter + 1))) {
            counter++;
          }
          return counter;
        }(),
    };
  }

  void boot(_TraceDevice device) {
    device
      ..coordinator = AgentWakeCoordinator(
        readInputs: (_) async => inputsOf(device),
        readWatermark: (_) async => watermarkOf(device),
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
        final edit = nextEdit++;
        final counter = counters[device.name] = counters[device.name]! + 1;
        origins[edit] = (host: device.name, counter: counter);
        device
          ..edits.add(edit)
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
    for (final state in cancelled) {
      expect(
        okHashes.any((ok) => ok.containsAll(state)),
        isTrue,
        reason: 'CancelCovered',
      );
    }
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
    final state = Set.of(device.edits);
    final model = device.model;
    final covered = model.done.any((done) => done.containsAll(state));
    final blocked =
        model.claimed && model.hash.containsAll(state) && model.left > 0;

    late WakeCoordinationDecision decision;
    device.coordinator.evaluate(_agent).then((value) => decision = value);
    async.flushMicrotasks();

    if (covered) {
      expect(decision, isA<WakeCoordinationCancel>(), reason: 'Covered');
      device.pending = false;
      cancelled.add(state);
    } else if (blocked) {
      expect(decision, isA<WakeCoordinationDefer>(), reason: 'Blocked');
    } else {
      expect(decision, isA<WakeCoordinationProceed>(), reason: 'Dispatch');
      final runKey = '${device.name}-${device.runs++}';
      runStates[runKey] = state;
      device.coordinator.claim(
        agentId: _agent,
        runKey: runKey,
        coverage: (decision as WakeCoordinationProceed).coverage,
      );
      device
        ..liveRun = runKey
        ..liveHash = state
        ..pending = false;
    }
  }

  void deliver(_TraceDevice from, _TraceDevice to) {
    if (from.outbox.isEmpty) return;
    final message = from.outbox.removeAt(0);
    to.coordinator.onMessage(message);

    final state = runStates[message.runKey]!;
    final view = to.model;
    switch (message.kind) {
      case AgentWakeCoordinationKind.claim:
        view
          ..claimed = true
          ..hash = state
          ..left = _timeoutTicks;
      case AgentWakeCoordinationKind.done:
        view
          ..claimed = false
          ..done.removeWhere(
            (done) => done.length == state.length && done.containsAll(state),
          )
          ..done.add(state);
        if (view.done.length > AgentWakeCoordinator.doneHistoryLimit) {
          view.done.removeAt(0);
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
                bench.okHashes.any((state) => state.contains(edit)),
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
