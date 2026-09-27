import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/wake/agent_wake_coordinator.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

part 'agent_wake_coordinator_model_conformance.dart';

const _agent = 'agent-1';

/// The label and category definitions both devices read.
const _definitions = 'sha256-v1:definitions';

/// The inputs of a task whose rows were last written as host `desktop`'s
/// counter 3 and host `phone`'s counter 5.
const _inputs = WakeInputs(
  clocks: {
    'entry:task-1': VectorClock({'desktop': 3}),
    'entry:item-1': VectorClock({'desktop': 2, 'phone': 5}),
  },
  readsPrivate: false,
  definitions: _definitions,
);

/// A watermark holding exactly what [_inputs] rests on.
const _held = {'desktop': 3, 'phone': 5};

/// A watermark missing phone's counter 5, the checked-off item.
const _behind = {'desktop': 3, 'phone': 4};

final _start = DateTime(2024, 3, 15, 10);

/// One device's coordinator with controllable inputs and watermark,
/// capturing what it broadcasts.
class _Device {
  _Device(this.host, {this.watermark = _held}) {
    coordinator = AgentWakeCoordinator(
      readInputs: (agentId) async {
        final error = inputsError;
        if (error != null) throw error;
        return inputs;
      },
      readWatermark: (hosts) async {
        watermarkHosts.add(hosts);
        return watermark;
      },
      send: (message) async => sent.add(message as SyncAgentWakeCoordination),
      localHostId: () async => host,
      domainLogger: logger,
    )..onPeerStateChanged = changed.add;
  }

  final String host;
  WakeInputs? inputs = _inputs;
  Map<String, int> watermark;
  Error? inputsError;
  final watermarkHosts = <Set<String>>[];
  final sent = <SyncAgentWakeCoordination>[];
  final changed = <String>[];
  final logger = MockDomainLogger();
  late final AgentWakeCoordinator coordinator;

  Future<WakeCoordinationDecision> evaluate({bool deferrable = true}) =>
      coordinator.evaluate(_agent, deferrable: deferrable);

  /// Every coordination line this device logged, in order.
  List<String> get logLines => [
    for (final call in verify(
      () => logger.log(
        LogDomain.agentRuntime,
        captureAny(),
        subDomain: 'coordination',
      ),
    ).captured)
      call as String,
  ];
}

SyncAgentWakeCoordination _message({
  required AgentWakeCoordinationKind kind,
  Map<String, int> watermark = _held,
  bool readsPrivate = false,
  String definitions = _definitions,
  String hostId = 'peer',
  DateTime? sentAt,
  String runKey = 'peer-run',
}) =>
    SyncMessage.agentWakeCoordination(
          agentId: _agent,
          kind: kind,
          watermark: watermark,
          readsPrivate: readsPrivate,
          definitionsDigest: definitions,
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

  group('WakeCoverage.uncovered', () {
    test('is null when every write the inputs rest on is held', () {
      expect(
        const WakeCoverage(
          watermark: _held,
          readsPrivate: false,
          definitions: _definitions,
        ).uncovered(
          _inputs,
        ),
        isNull,
      );
    });

    test('is null for a watermark ahead of the inputs', () {
      expect(
        const WakeCoverage(
          watermark: {'desktop': 40, 'phone': 9, 'tablet': 2},
          readsPrivate: false,
          definitions: _definitions,
        ).uncovered(_inputs),
        isNull,
      );
    });

    test('names the first write above the watermark', () {
      expect(
        const WakeCoverage(
          watermark: _behind,
          readsPrivate: false,
          definitions: _definitions,
        ).uncovered(
          _inputs,
        ),
        'entry [id:item-1] needs [id:phone]:5, peer holds 4',
      );
    });

    test('takes a host missing from the watermark as holding nothing', () {
      expect(
        const WakeCoverage(
          watermark: {'desktop': 3},
          readsPrivate: false,
          definitions: _definitions,
        ).uncovered(_inputs),
        'entry [id:item-1] needs [id:phone]:5, peer holds 0',
      );
    });

    test('never covers a row without a vector clock', () {
      expect(
        const WakeCoverage(
          watermark: _held,
          readsPrivate: false,
          definitions: _definitions,
        ).uncovered(
          const WakeInputs(
            clocks: {'report:report-1': null},
            readsPrivate: false,
            definitions: _definitions,
          ),
        ),
        'report [id:report] has no vector clock',
      );
    });

    test('a run hiding private entries does not cover one reading them', () {
      const reading = WakeInputs(
        clocks: {},
        readsPrivate: true,
        definitions: _definitions,
      );
      expect(
        const WakeCoverage(
          watermark: _held,
          readsPrivate: false,
          definitions: _definitions,
        ).uncovered(
          reading,
        ),
        'private entries',
      );
      expect(
        const WakeCoverage(
          watermark: _held,
          readsPrivate: true,
          definitions: _definitions,
        ).uncovered(
          reading,
        ),
        isNull,
      );
      expect(
        const WakeCoverage(
          watermark: _held,
          readsPrivate: true,
          definitions: _definitions,
        ).uncovered(
          _inputs,
        ),
        isNull,
      );
    });

    test('a run over other label or category definitions does not cover', () {
      expect(
        const WakeCoverage(
          watermark: _held,
          readsPrivate: false,
          definitions: 'sha256-v1:other',
        ).uncovered(_inputs),
        'label or category definitions differ',
      );
    });

    test('is equal by watermark, private flag and definitions', () {
      expect(
        const WakeCoverage(
          watermark: {'a': 1},
          readsPrivate: false,
          definitions: _definitions,
        ),
        WakeCoverage(
          watermark: Map.of({'a': 1}),
          readsPrivate: false,
          definitions: _definitions,
        ),
      );
      expect(
        const WakeCoverage(
          watermark: {'a': 1},
          readsPrivate: false,
          definitions: _definitions,
        ).hashCode,
        WakeCoverage(
          watermark: Map.of({'a': 1}),
          readsPrivate: false,
          definitions: _definitions,
        ).hashCode,
      );
      expect(
        const WakeCoverage(
          watermark: {'a': 1},
          readsPrivate: false,
          definitions: _definitions,
        ),
        isNot(
          const WakeCoverage(
            watermark: {'a': 2},
            readsPrivate: false,
            definitions: _definitions,
          ),
        ),
      );
      expect(
        const WakeCoverage(
          watermark: {'a': 1},
          readsPrivate: false,
          definitions: _definitions,
        ),
        isNot(
          const WakeCoverage(
            watermark: {'a': 1},
            readsPrivate: true,
            definitions: _definitions,
          ),
        ),
      );
      expect(
        const WakeCoverage(
          watermark: {'a': 1},
          readsPrivate: false,
          definitions: _definitions,
        ),
        isNot(
          const WakeCoverage(
            watermark: {'a': 1},
            readsPrivate: false,
            definitions: 'x',
          ),
        ),
      );
    });
  });

  group('evaluate', () {
    test('proceeds with its watermark when no peer has spoken', () {
      _fake((async) {
        final device = _Device('me');

        final decision = _resolve(async, device.evaluate());

        expect(
          decision,
          isA<WakeCoordinationProceed>().having(
            (d) => d.coverage,
            'coverage',
            const WakeCoverage(
              watermark: _held,
              readsPrivate: false,
              definitions: _definitions,
            ),
          ),
        );
        // The watermark is read for at least every host the inputs rest on.
        expect(device.watermarkHosts, [
          {'desktop', 'phone'},
        ]);
        expect(device.logLines, [
          'proceed [id:agent-]: 2 inputs, no peer run known',
        ]);
      });
    });

    test('defers while a live peer claim covers the inputs', () {
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

    test('a peer claim holding more than this device still covers it', () {
      _fake((async) {
        // The peer started after syncing this device's check-off and made
        // an edit of its own; this device, not yet holding that edit, has
        // nothing the peer's run does not read.
        final device = _Device('me');
        device.coordinator.onMessage(
          _message(
            kind: AgentWakeCoordinationKind.claim,
            watermark: const {'desktop': 4, 'phone': 5},
          ),
        );

        expect(
          _resolve(async, device.evaluate()),
          isA<WakeCoordinationDefer>(),
        );
      });
    });

    test('proceeds past a peer claim missing one of its writes, and logs '
        'which', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator.onMessage(
          _message(kind: AgentWakeCoordinationKind.claim, watermark: _behind),
        );

        expect(
          _resolve(async, device.evaluate()),
          isA<WakeCoordinationProceed>(),
        );
        expect(
          device.logLines.last,
          'proceed [id:agent-]: 2 inputs, [id:peer] claim: entry [id:item-1] '
          'needs [id:phone]:5, peer holds 4',
        );
      });
    });

    test('cancels once a peer completed a run covering the inputs', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator
          ..onMessage(_message(kind: AgentWakeCoordinationKind.claim))
          ..onMessage(_message(kind: AgentWakeCoordinationKind.done));

        final decision = _resolve(async, device.evaluate());

        expect(
          decision,
          isA<WakeCoordinationCancel>().having(
            (d) => d.peerHostId,
            'peerHostId',
            'peer',
          ),
        );
        expect(device.changed, [_agent]);
        expect(
          device.logLines.last,
          'cancel [id:agent-]: peer [id:peer] completed a run covering 2 '
          'inputs',
        );
      });
    });

    test('a completion missing one of its writes does not cancel', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator.onMessage(
          _message(kind: AgentWakeCoordinationKind.done, watermark: _behind),
        );

        expect(
          _resolve(async, device.evaluate()),
          isA<WakeCoordinationProceed>(),
        );
        expect(
          device.logLines.last,
          'proceed [id:agent-]: 2 inputs, [id:peer] done: entry [id:item-1] '
          'needs [id:phone]:5, peer holds 4',
        );
      });
    });

    test(
      "a peer's next claim does not erase its completed runs "
      '(KeepDoneHistory)',
      () {
        _fake((async) {
          // The peer completed a run covering this device, then started one
          // this device's newer edit is missing from. The done still covers.
          final device = _Device('me');
          device.coordinator
            ..onMessage(_message(kind: AgentWakeCoordinationKind.done))
            ..onMessage(
              _message(
                kind: AgentWakeCoordinationKind.claim,
                watermark: _behind,
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

    test('keeps the most recent completed runs per peer, bounded', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator.onMessage(
          _message(kind: AgentWakeCoordinationKind.done),
        );
        for (var i = 0; i < AgentWakeCoordinator.doneHistoryLimit; i++) {
          async.elapse(const Duration(seconds: 1));
          device.coordinator.onMessage(
            _message(
              kind: AgentWakeCoordinationKind.done,
              watermark: {'desktop': 2, 'phone': i},
            ),
          );
        }

        // The covering run was pushed out by newer, narrower completions.
        expect(
          _resolve(async, device.evaluate()),
          isA<WakeCoordinationProceed>(),
        );
        device
          ..watermark = const {'desktop': 2, 'phone': 1}
          ..inputs = const WakeInputs(
            clocks: {
              'entry:task-1': VectorClock({'desktop': 2, 'phone': 1}),
            },
            readsPrivate: false,
            definitions: _definitions,
          );
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

    test(
      'a claim with another coverage replaces the held one and asks for a '
      'drain; a repeated one does not',
      () {
        _fake((async) {
          // The done for the covering run was lost; the peer has moved on.
          final device = _Device('me');
          device.coordinator.onMessage(
            _message(kind: AgentWakeCoordinationKind.claim),
          );
          device.coordinator.onMessage(
            _message(kind: AgentWakeCoordinationKind.claim),
          );
          expect(device.changed, isEmpty);
          expect(
            _resolve(async, device.evaluate()),
            isA<WakeCoordinationDefer>(),
          );

          device.coordinator.onMessage(
            _message(kind: AgentWakeCoordinationKind.claim, watermark: _behind),
          );

          expect(device.changed, [_agent]);
          expect(
            _resolve(async, device.evaluate()),
            isA<WakeCoordinationProceed>(),
          );
        });
      },
    );

    test(
      'a peer whose clock runs behind still coordinates: the timer runs '
      'from receipt',
      () {
        _fake((async) {
          final device = _Device('me');
          device.coordinator.onMessage(
            _message(
              kind: AgentWakeCoordinationKind.claim,
              sentAt: _start.subtract(const Duration(minutes: 10)),
            ),
          );

          async.elapse(
            AgentWakeCoordinator.coordinationTimeout -
                const Duration(seconds: 1),
          );
          expect(
            _resolve(async, device.evaluate()),
            isA<WakeCoordinationDefer>(),
          );
          async.elapse(const Duration(seconds: 1));
          expect(
            _resolve(async, device.evaluate()),
            isA<WakeCoordinationProceed>(),
          );
        });
      },
    );

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
          ..onMessage(
            _message(kind: AgentWakeCoordinationKind.done, watermark: _behind),
          )
          // A claim of the same run that a retry delivered after its done.
          ..onMessage(
            _message(
              kind: AgentWakeCoordinationKind.claim,
              sentAt: _start.subtract(const Duration(seconds: 5)),
            ),
          );

        expect(
          _resolve(async, device.evaluate()),
          isA<WakeCoordinationProceed>(),
        );
        expect(
          device.logLines,
          containsAllInOrder([
            'received done from [id:peer] for [id:agent-] run [id:peer-r]',
            'dropped stale claim from [id:peer] for [id:agent-]',
          ]),
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
            (d) => d.coverage,
            'coverage',
            const WakeCoverage(
              watermark: _held,
              readsPrivate: false,
              definitions: _definitions,
            ),
          ),
        );

        device.coordinator.onMessage(
          _message(kind: AgentWakeCoordinationKind.done),
        );
        expect(
          _resolve(async, device.evaluate(deferrable: false)),
          isA<WakeCoordinationProceed>(),
        );
        expect(
          device.logLines.last,
          'proceed [id:agent-]: requested by the user',
        );
      });
    });

    test('an agent without inputs proceeds uncoordinated', () {
      _fake((async) {
        final device = _Device('me')..inputs = null;
        device.coordinator.onMessage(
          _message(kind: AgentWakeCoordinationKind.done),
        );

        expect(
          _resolve(async, device.evaluate()),
          isA<WakeCoordinationProceed>().having(
            (d) => d.coverage,
            'coverage',
            isNull,
          ),
        );
        expect(device.watermarkHosts, isEmpty);
      });
    });

    test('unreadable inputs fail open', () {
      _fake((async) {
        final device = _Device('me')..inputsError = StateError('db closed');
        device.coordinator.onMessage(
          _message(kind: AgentWakeCoordinationKind.claim),
        );

        expect(
          _resolve(async, device.evaluate()),
          isA<WakeCoordinationProceed>().having(
            (d) => d.coverage,
            'coverage',
            isNull,
          ),
        );
        verify(
          () => device.logger.error(
            LogDomain.agentRuntime,
            any(that: isA<StateError>()),
            message: 'wake inputs unreadable; wake proceeds uncoordinated',
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });
  });

  group('claim, complete and settle', () {
    const coverage = WakeCoverage(
      watermark: _held,
      readsPrivate: true,
      definitions: _definitions,
    );

    test('a claim is broadcast at once and repeated as a heartbeat', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator.claim(
          agentId: _agent,
          runKey: 'run-1',
          coverage: coverage,
        );
        async.flushMicrotasks();

        expect(device.sent, hasLength(1));
        expect(device.sent.single.kind, AgentWakeCoordinationKind.claim);
        expect(device.sent.single.watermark, _held);
        expect(device.sent.single.readsPrivate, isTrue);
        expect(device.sent.single.definitionsDigest, _definitions);
        expect(device.sent.single.hostId, 'me');
        expect(device.sent.single.runKey, 'run-1');
        expect(device.sent.single.sentAt, _start);
        expect(device.logLines, [
          'sent claim for [id:agent-] run [id:run-1]',
        ]);

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
          ..claim(agentId: _agent, runKey: 'run-1', coverage: coverage)
          ..complete('run-1')
          // The drain settles every run; after complete that is a no-op.
          ..settle('run-1');
        async.elapse(AgentWakeCoordinator.heartbeatInterval * 3);

        expect(device.sent.map((m) => m.kind), [
          AgentWakeCoordinationKind.claim,
          AgentWakeCoordinationKind.done,
        ]);
        expect(device.sent.last.watermark, _held);
      });
    });

    test('settle without complete releases the claim', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator
          ..claim(agentId: _agent, runKey: 'run-1', coverage: coverage)
          ..settle('run-1');
        async.elapse(AgentWakeCoordinator.heartbeatInterval * 3);

        expect(device.sent.map((m) => m.kind), [
          AgentWakeCoordinationKind.claim,
          AgentWakeCoordinationKind.release,
        ]);
      });
    });

    test('a run without coverage broadcasts nothing', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator
          ..claim(agentId: _agent, runKey: 'run-1', coverage: null)
          ..complete('run-1');
        async.elapse(AgentWakeCoordinator.heartbeatInterval * 2);

        expect(device.sent, isEmpty);
      });
    });

    test('nothing is sent, and that is logged, before the host id exists', () {
      _fake((async) {
        final logger = MockDomainLogger();
        final sent = <SyncMessage>[];
        final coordinator = AgentWakeCoordinator(
          domainLogger: logger,
          readInputs: (_) async => _inputs,
          readWatermark: (_) async => _held,
          send: (message) async => sent.add(message),
          localHostId: () async => null,
        )..claim(agentId: _agent, runKey: 'run-1', coverage: coverage);
        async.flushMicrotasks();

        expect(sent, isEmpty);
        verify(
          () => logger.log(
            LogDomain.agentRuntime,
            'claim not sent: no host id yet',
            subDomain: 'coordination',
          ),
        ).called(1);
        coordinator.dispose();
      });
    });

    test('a failed broadcast is logged and does not hold back the next '
        'one', () {
      _fake((async) {
        final sent = <AgentWakeCoordinationKind>[];
        var failNext = true;
        final logger = MockDomainLogger();
        final coordinator =
            AgentWakeCoordinator(
                domainLogger: logger,
                readInputs: (_) async => _inputs,
                readWatermark: (_) async => _held,
                send: (message) async {
                  if (failNext) {
                    failNext = false;
                    throw StateError('outbox closed');
                  }
                  sent.add((message as SyncAgentWakeCoordination).kind);
                },
                localHostId: () async => 'me',
              )
              ..claim(agentId: _agent, runKey: 'run-1', coverage: coverage)
              ..complete('run-1');
        async.flushMicrotasks();

        expect(sent, [AgentWakeCoordinationKind.done]);
        verify(
          () => logger.error(
            LogDomain.agentRuntime,
            any(that: isA<StateError>()),
            message: 'failed to broadcast wake claim',
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
        coordinator.dispose();
      });
    });

    test('a throwing drain callback does not break message handling', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator.onPeerStateChanged = (_) =>
            throw StateError('orchestrator stopped');

        device.coordinator.onMessage(
          _message(kind: AgentWakeCoordinationKind.done),
        );

        expect(
          _resolve(async, device.evaluate()),
          isA<WakeCoordinationCancel>(),
        );
      });
    });

    test('dispose stops the heartbeats and the peer timers', () {
      _fake((async) {
        final device = _Device('me');
        device.coordinator
          ..claim(agentId: _agent, runKey: 'run-1', coverage: coverage)
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

    void run(FakeAsync async, _Device device, String runKey) {
      final decision = _resolve(async, device.evaluate());
      expect(decision, isA<WakeCoordinationProceed>());
      device.coordinator.claim(
        agentId: _agent,
        runKey: runKey,
        coverage: (decision as WakeCoordinationProceed).coverage,
      );
    }

    test('same state: one runs, the other defers and then cancels', () {
      _fake((async) {
        final desktop = _Device('desktop');
        final phone = _Device('phone');

        run(async, desktop, 'desktop-run');
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

    test(
      'a check-off that reached the desktop before its run cancels the '
      "phone's wake, though the desktop held more",
      () {
        _fake((async) {
          // The desktop's edit is counter 3 of its own; the phone's check-off
          // is phone:5, synced to the desktop before its countdown ran out.
          // The desktop also holds a later edit of its own the phone lacks.
          final desktop = _Device(
            'desktop',
            watermark: const {'desktop': 4, 'phone': 5},
          );
          final phone = _Device('phone');

          run(async, desktop, 'desktop-run');
          desktop.coordinator.complete('desktop-run');
          deliver(async, desktop, phone);

          expect(
            _resolve(async, phone.evaluate()),
            isA<WakeCoordinationCancel>(),
          );
        });
      },
    );

    test('a device holding a write the run lacks runs beside the claim', () {
      _fake((async) {
        final desktop = _Device('desktop', watermark: _behind);
        final phone = _Device('phone');
        run(async, desktop, 'desktop-run');
        deliver(async, desktop, phone);

        expect(
          _resolve(async, phone.evaluate()),
          isA<WakeCoordinationProceed>().having(
            (d) => d.coverage,
            'coverage',
            const WakeCoverage(
              watermark: _held,
              readsPrivate: false,
              definitions: _definitions,
            ),
          ),
        );
      });
    });

    test('a peer that goes silent is waited out, then the wake runs', () {
      _fake((async) {
        final desktop = _Device('desktop');
        final phone = _Device('phone');
        run(async, desktop, 'desktop-run');
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
