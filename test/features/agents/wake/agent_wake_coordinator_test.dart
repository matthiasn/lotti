import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/wake/agent_wake_coordinator.dart';
import 'package:lotti/features/sync/model/sync_message.dart';

part 'agent_wake_coordinator_model_conformance.dart';

const _agent = 'agent-1';
const _stateA = 'sha256-v1:state-a';
const _stateB = 'sha256-v1:state-b';

final _start = DateTime(2024, 3, 15, 10);

/// One device's coordinator with a controllable state digest, capturing what
/// it broadcasts.
class _Device {
  _Device(this.host, {String? digest}) : digest = digest ?? _stateA {
    coordinator = AgentWakeCoordinator(
      digestState: (agentId) async {
        final error = digestError;
        if (error != null) throw error;
        return this.digest;
      },
      send: (message) async => sent.add(message as SyncAgentWakeCoordination),
      localHostId: () async => host,
    )..onPeerStateChanged = changed.add;
  }

  final String host;
  String? digest;
  Error? digestError;
  final sent = <SyncAgentWakeCoordination>[];
  final changed = <String>[];
  late final AgentWakeCoordinator coordinator;

  Future<WakeCoordinationDecision> evaluate({bool deferrable = true}) =>
      coordinator.evaluate(_agent, deferrable: deferrable);
}

SyncAgentWakeCoordination _message({
  required AgentWakeCoordinationKind kind,
  String stateHash = _stateA,
  String hostId = 'peer',
  DateTime? sentAt,
  String runKey = 'peer-run',
}) =>
    SyncMessage.agentWakeCoordination(
          agentId: _agent,
          kind: kind,
          stateHash: stateHash,
          runKey: runKey,
          hostId: hostId,
          sentAt: sentAt ?? clock.now(),
        )
        as SyncAgentWakeCoordination;

/// Runs [body] in fake time starting at [_start].
void _fake(void Function(FakeAsync async) body) {
  fakeAsync(body, initialTime: _start);
}

/// Resolves [future] inside fake time.
T _resolve<T>(FakeAsync async, Future<T> future) {
  T? result;
  future.then((value) => result = value);
  async.flushMicrotasks();
  return result as T;
}

void main() {
  _registerModelConformance();

  group('evaluate', () {
    test('proceeds with the digest when no peer has spoken', () {
      _fake((async) {
        final device = _Device('me');

        final decision = _resolve(async, device.evaluate());

        expect(
          decision,
          isA<WakeCoordinationProceed>().having(
            (d) => d.stateHash,
            'stateHash',
            _stateA,
          ),
        );
      });
    });

    test('defers while a live peer claim matches the local digest', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator.onMessage(
          _message(kind: AgentWakeCoordinationKind.claim),
        );

        final decision = _resolve(async, device.evaluate());

        expect(
          decision,
          isA<WakeCoordinationDefer>()
              .having((d) => d.peerHostId, 'peerHostId', 'peer')
              .having(
                (d) => d.until,
                'until',
                _start.add(AgentWakeCoordinator.coordinationTimeout),
              ),
        );
      });
    });

    test('proceeds past a peer claim over a different digest', () {
      _fake((async) {
        final device = _Device('me', digest: _stateB);
        device.coordinator.onMessage(
          _message(kind: AgentWakeCoordinationKind.claim),
        );

        final decision = _resolve(async, device.evaluate());

        expect(
          decision,
          isA<WakeCoordinationProceed>().having(
            (d) => d.stateHash,
            'stateHash',
            _stateB,
          ),
        );
      });
    });

    test('cancels once a peer completed a run over the local digest', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator
          ..onMessage(_message(kind: AgentWakeCoordinationKind.claim))
          ..onMessage(_message(kind: AgentWakeCoordinationKind.done));

        final decision = _resolve(async, device.evaluate());

        expect(
          decision,
          isA<WakeCoordinationCancel>()
              .having((d) => d.peerHostId, 'peerHostId', 'peer')
              .having((d) => d.stateHash, 'stateHash', _stateA),
        );
        expect(device.changed, [_agent]);
      });
    });

    test('a completion over another digest does not cancel', () {
      _fake((async) {
        final device = _Device('me', digest: _stateB);
        device.coordinator.onMessage(
          _message(kind: AgentWakeCoordinationKind.done),
        );

        expect(
          _resolve(async, device.evaluate()),
          isA<WakeCoordinationProceed>(),
        );
      });
    });

    test(
      "a peer's next claim does not erase its completed digests "
      '(KeepDoneHistory)',
      () {
        _fake((async) {
          // The peer ran state A, then started a run over state B that this
          // device has not synced yet. This device, still at A, must not run.
          final device = _Device('me');
          device.coordinator
            ..onMessage(_message(kind: AgentWakeCoordinationKind.claim))
            ..onMessage(_message(kind: AgentWakeCoordinationKind.done))
            ..onMessage(
              _message(
                kind: AgentWakeCoordinationKind.claim,
                stateHash: _stateB,
                runKey: 'peer-run-2',
              ),
            );

          expect(
            _resolve(async, device.evaluate()),
            isA<WakeCoordinationCancel>(),
          );
        });
      },
    );

    test('keeps the most recent completed digests per peer, bounded', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator.onMessage(
          _message(kind: AgentWakeCoordinationKind.done),
        );
        for (var i = 0; i < AgentWakeCoordinator.doneHistoryLimit; i++) {
          async.elapse(const Duration(seconds: 1));
          device.coordinator.onMessage(
            _message(kind: AgentWakeCoordinationKind.done, stateHash: 'x-$i'),
          );
        }

        // State A was pushed out by newer completions.
        expect(
          _resolve(async, device.evaluate()),
          isA<WakeCoordinationProceed>(),
        );
        device.digest = 'x-0';
        expect(
          _resolve(async, device.evaluate()),
          isA<WakeCoordinationCancel>(),
        );
      });
    });

    test('a released claim no longer defers', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator
          ..onMessage(_message(kind: AgentWakeCoordinationKind.claim))
          ..onMessage(_message(kind: AgentWakeCoordinationKind.release));

        expect(
          _resolve(async, device.evaluate()),
          isA<WakeCoordinationProceed>(),
        );
        expect(device.changed, [_agent]);
      });
    });

    test('a claim lapses after the timeout and asks for a drain', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator.onMessage(
          _message(kind: AgentWakeCoordinationKind.claim),
        );

        async.elapse(
          AgentWakeCoordinator.coordinationTimeout - const Duration(seconds: 1),
        );
        expect(
          _resolve(async, device.evaluate()),
          isA<WakeCoordinationDefer>(),
        );
        expect(device.changed, isEmpty);

        async.elapse(const Duration(seconds: 1));
        expect(device.changed, [_agent]);
        expect(
          _resolve(async, device.evaluate()),
          isA<WakeCoordinationProceed>(),
        );
      });
    });

    test('every claim from the peer re-arms the timer', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator.onMessage(
          _message(kind: AgentWakeCoordinationKind.claim),
        );
        async.elapse(const Duration(seconds: 90));
        device.coordinator.onMessage(
          _message(kind: AgentWakeCoordinationKind.claim),
        );

        // Past the first claim's deadline, inside the heartbeat's.
        async.elapse(const Duration(seconds: 60));
        expect(
          _resolve(async, device.evaluate()),
          isA<WakeCoordinationDefer>(),
        );
        expect(device.changed, isEmpty);

        async.elapse(const Duration(seconds: 60));
        expect(device.changed, [_agent]);
        expect(
          _resolve(async, device.evaluate()),
          isA<WakeCoordinationProceed>(),
        );
      });
    });

    test('a claim that arrives after it would have lapsed is ignored', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator.onMessage(
          _message(
            kind: AgentWakeCoordinationKind.claim,
            sentAt: _start.subtract(AgentWakeCoordinator.coordinationTimeout),
          ),
        );

        expect(
          _resolve(async, device.evaluate()),
          isA<WakeCoordinationProceed>(),
        );
      });
    });

    test('a late completion still cancels: the state was processed', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator.onMessage(
          _message(
            kind: AgentWakeCoordinationKind.done,
            sentAt: _start.subtract(const Duration(hours: 1)),
          ),
        );

        expect(
          _resolve(async, device.evaluate()),
          isA<WakeCoordinationCancel>(),
        );
      });
    });

    test("drops a peer's message older than the last one applied", () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator
          ..onMessage(_message(kind: AgentWakeCoordinationKind.done))
          // A claim of the same run that a retry delivered after its done.
          ..onMessage(
            _message(
              kind: AgentWakeCoordinationKind.claim,
              stateHash: _stateB,
              sentAt: _start.subtract(const Duration(seconds: 5)),
            ),
          );
        device.digest = _stateB;

        expect(
          _resolve(async, device.evaluate()),
          isA<WakeCoordinationProceed>(),
        );
      });
    });

    test('a wake the user asked for is never deferred or cancelled', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator.onMessage(
          _message(kind: AgentWakeCoordinationKind.claim),
        );
        expect(
          _resolve(async, device.evaluate(deferrable: false)),
          isA<WakeCoordinationProceed>().having(
            (d) => d.stateHash,
            'stateHash',
            _stateA,
          ),
        );

        device.coordinator.onMessage(
          _message(kind: AgentWakeCoordinationKind.done),
        );
        expect(
          _resolve(async, device.evaluate(deferrable: false)),
          isA<WakeCoordinationProceed>(),
        );
      });
    });

    test('an agent without a digest proceeds uncoordinated', () {
      _fake((async) {
        final device = _Device('me')..digest = null;
        device.coordinator.onMessage(
          _message(kind: AgentWakeCoordinationKind.done),
        );

        expect(
          _resolve(async, device.evaluate()),
          isA<WakeCoordinationProceed>().having(
            (d) => d.stateHash,
            'stateHash',
            isNull,
          ),
        );
      });
    });

    test('a failing digest fails open', () {
      _fake((async) {
        final device = _Device('me')..digestError = StateError('db closed');
        device.coordinator.onMessage(
          _message(kind: AgentWakeCoordinationKind.claim),
        );

        expect(
          _resolve(async, device.evaluate()),
          isA<WakeCoordinationProceed>().having(
            (d) => d.stateHash,
            'stateHash',
            isNull,
          ),
        );
      });
    });
  });

  group('claim, complete and settle', () {
    test('a claim is broadcast at once and repeated as a heartbeat', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator.claim(
          agentId: _agent,
          runKey: 'run-1',
          stateHash: _stateA,
        );
        async.flushMicrotasks();

        expect(device.sent, hasLength(1));
        expect(device.sent.single.kind, AgentWakeCoordinationKind.claim);
        expect(device.sent.single.stateHash, _stateA);
        expect(device.sent.single.hostId, 'me');
        expect(device.sent.single.runKey, 'run-1');
        expect(device.sent.single.sentAt, _start);

        async.elapse(AgentWakeCoordinator.heartbeatInterval * 2);
        expect(
          device.sent.map((m) => m.kind),
          List.filled(3, AgentWakeCoordinationKind.claim),
        );
      });
    });

    test('complete broadcasts done and stops the heartbeat', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator
          ..claim(agentId: _agent, runKey: 'run-1', stateHash: _stateA)
          ..complete('run-1')
          // The drain settles every run; after complete that is a no-op.
          ..settle('run-1');
        async.elapse(AgentWakeCoordinator.heartbeatInterval * 3);

        expect(device.sent.map((m) => m.kind), [
          AgentWakeCoordinationKind.claim,
          AgentWakeCoordinationKind.done,
        ]);
        expect(device.sent.last.stateHash, _stateA);
      });
    });

    test('settle without complete releases the claim', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator
          ..claim(agentId: _agent, runKey: 'run-1', stateHash: _stateA)
          ..settle('run-1');
        async.elapse(AgentWakeCoordinator.heartbeatInterval * 3);

        expect(device.sent.map((m) => m.kind), [
          AgentWakeCoordinationKind.claim,
          AgentWakeCoordinationKind.release,
        ]);
      });
    });

    test('a run without a digest broadcasts nothing', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator
          ..claim(agentId: _agent, runKey: 'run-1', stateHash: null)
          ..complete('run-1');
        async.elapse(AgentWakeCoordinator.heartbeatInterval * 2);

        expect(device.sent, isEmpty);
      });
    });

    test('dispose stops the heartbeats and the peer timers', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator
          ..claim(agentId: _agent, runKey: 'run-1', stateHash: _stateA)
          ..onMessage(_message(kind: AgentWakeCoordinationKind.claim));
        async.flushMicrotasks();
        device.coordinator.dispose();

        async.elapse(AgentWakeCoordinator.coordinationTimeout * 2);
        expect(device.sent, hasLength(1));
        expect(device.changed, isEmpty);
        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  group('two devices', () {
    /// Delivers every message [from] broadcast since the last call to [to].
    void deliver(FakeAsync async, _Device from, _Device to) {
      async.flushMicrotasks();
      from.sent.forEach(to.coordinator.onMessage);
      from.sent.clear();
    }

    test('same state: one runs, the other defers and then cancels', () {
      _fake((async) {
        final desktop = _Device('desktop');
        final phone = _Device('phone');

        final desktopDecision = _resolve(async, desktop.evaluate());
        expect(desktopDecision, isA<WakeCoordinationProceed>());
        desktop.coordinator.claim(
          agentId: _agent,
          runKey: 'desktop-run',
          stateHash: (desktopDecision as WakeCoordinationProceed).stateHash,
        );
        deliver(async, desktop, phone);

        expect(_resolve(async, phone.evaluate()), isA<WakeCoordinationDefer>());

        // The run outlasts the timer; the heartbeat keeps the phone waiting.
        for (var i = 0; i < 4; i++) {
          async.elapse(AgentWakeCoordinator.heartbeatInterval);
          deliver(async, desktop, phone);
        }
        expect(_resolve(async, phone.evaluate()), isA<WakeCoordinationDefer>());

        desktop.coordinator.complete('desktop-run');
        deliver(async, desktop, phone);
        expect(
          _resolve(async, phone.evaluate()),
          isA<WakeCoordinationCancel>(),
        );
      });
    });

    test('a device with newer state runs beside the claim', () {
      _fake((async) {
        final desktop = _Device('desktop');
        final phone = _Device('phone', digest: _stateB);
        desktop.coordinator.claim(
          agentId: _agent,
          runKey: 'desktop-run',
          stateHash: _stateA,
        );
        deliver(async, desktop, phone);

        expect(
          _resolve(async, phone.evaluate()),
          isA<WakeCoordinationProceed>().having(
            (d) => d.stateHash,
            'stateHash',
            _stateB,
          ),
        );
      });
    });

    test('a peer that goes silent is waited out, then the wake runs', () {
      _fake((async) {
        final desktop = _Device('desktop');
        final phone = _Device('phone');
        desktop.coordinator.claim(
          agentId: _agent,
          runKey: 'desktop-run',
          stateHash: _stateA,
        );
        deliver(async, desktop, phone);
        // The desktop dies: no heartbeat, no done ever reaches the phone.
        desktop.coordinator.dispose();

        async.elapse(AgentWakeCoordinator.coordinationTimeout);
        expect(phone.changed, [_agent]);
        expect(
          _resolve(async, phone.evaluate()),
          isA<WakeCoordinationProceed>(),
        );
      });
    });
  });
}
