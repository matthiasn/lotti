import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/wake/wake_throttle_coordinator.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_data/entity_factories.dart';

enum _GeneratedThrottleOperationKind { setDeadline, hydrate, clear, elapse }

enum _GeneratedThrottleAgentSlot { first, second, third }

enum _GeneratedHydrationOffset {
  expired,
  immediate,
  soon,
  window,
  later,
}

enum _GeneratedThrottleElapsed {
  none,
  tick,
  short,
  halfWindow,
  window,
  long,
}

enum _GeneratedThrottlePersistedStateSlot { missing, idle, scheduled }

enum _GeneratedThrottleRepositoryFailure { none, getState, upsert }

enum _GeneratedThrottlePersistenceOperationKind {
  setDeadline,
  hydrateExpired,
  hydrateImmediate,
  hydrateFuture,
  clear,
  elapseTick,
  elapseWindow,
  elapseLong,
}

const _generatedThrottleWindow = Duration(seconds: 30);
const _generatedThrottleHydrationDelay = Duration(seconds: 10);
final _generatedThrottleBase = DateTime(2026, 5, 19, 9);

String _generatedThrottleAgentId(_GeneratedThrottleAgentSlot slot) =>
    'generated-throttle-agent-${slot.name}';

Duration _generatedHydrationOffsetDuration(
  _GeneratedHydrationOffset offset,
) {
  return switch (offset) {
    _GeneratedHydrationOffset.expired => const Duration(seconds: -1),
    _GeneratedHydrationOffset.immediate => Duration.zero,
    _GeneratedHydrationOffset.soon => const Duration(seconds: 5),
    _GeneratedHydrationOffset.window => _generatedThrottleWindow,
    _GeneratedHydrationOffset.later => const Duration(seconds: 45),
  };
}

Duration _generatedElapsedDuration(_GeneratedThrottleElapsed elapsed) {
  return switch (elapsed) {
    _GeneratedThrottleElapsed.none => Duration.zero,
    _GeneratedThrottleElapsed.tick => const Duration(seconds: 1),
    _GeneratedThrottleElapsed.short => const Duration(seconds: 5),
    _GeneratedThrottleElapsed.halfWindow => const Duration(seconds: 15),
    _GeneratedThrottleElapsed.window => _generatedThrottleWindow,
    _GeneratedThrottleElapsed.long => const Duration(seconds: 60),
  };
}

class _GeneratedThrottleOperation {
  const _GeneratedThrottleOperation({
    required this.kind,
    required this.agentSlot,
    required this.hydrationOffset,
    required this.elapsed,
  });

  final _GeneratedThrottleOperationKind kind;
  final _GeneratedThrottleAgentSlot agentSlot;
  final _GeneratedHydrationOffset hydrationOffset;
  final _GeneratedThrottleElapsed elapsed;

  String get agentId => _generatedThrottleAgentId(agentSlot);

  @override
  String toString() {
    return '_GeneratedThrottleOperation('
        'kind: $kind, agentSlot: $agentSlot, '
        'hydrationOffset: $hydrationOffset, elapsed: $elapsed)';
  }
}

class _GeneratedThrottleScenario {
  const _GeneratedThrottleScenario({required this.operations});

  final List<_GeneratedThrottleOperation> operations;

  @override
  String toString() => '_GeneratedThrottleScenario($operations)';
}

class _GeneratedThrottlePersistenceAgent {
  const _GeneratedThrottlePersistenceAgent({
    required this.stateSlot,
    required this.failure,
  });

  final _GeneratedThrottlePersistedStateSlot stateSlot;
  final _GeneratedThrottleRepositoryFailure failure;

  @override
  String toString() {
    return '_GeneratedThrottlePersistenceAgent('
        'stateSlot: $stateSlot, failure: $failure)';
  }
}

class _GeneratedThrottlePersistenceOperation {
  const _GeneratedThrottlePersistenceOperation({
    required this.kind,
    required this.agentSlot,
  });

  final _GeneratedThrottlePersistenceOperationKind kind;
  final _GeneratedThrottleAgentSlot agentSlot;

  String get agentId => _generatedThrottleAgentId(agentSlot);

  @override
  String toString() {
    return '_GeneratedThrottlePersistenceOperation('
        'kind: $kind, agentSlot: $agentSlot)';
  }
}

class _GeneratedThrottlePersistenceScenario {
  const _GeneratedThrottlePersistenceScenario({
    required this.firstAgent,
    required this.secondAgent,
    required this.thirdAgent,
    required this.operations,
  });

  final _GeneratedThrottlePersistenceAgent firstAgent;
  final _GeneratedThrottlePersistenceAgent secondAgent;
  final _GeneratedThrottlePersistenceAgent thirdAgent;
  final List<_GeneratedThrottlePersistenceOperation> operations;

  _GeneratedThrottlePersistenceAgent agent(
    _GeneratedThrottleAgentSlot slot,
  ) {
    return switch (slot) {
      _GeneratedThrottleAgentSlot.first => firstAgent,
      _GeneratedThrottleAgentSlot.second => secondAgent,
      _GeneratedThrottleAgentSlot.third => thirdAgent,
    };
  }

  @override
  String toString() {
    return '_GeneratedThrottlePersistenceScenario('
        'firstAgent: $firstAgent, secondAgent: $secondAgent, '
        'thirdAgent: $thirdAgent, operations: $operations)';
  }
}

@immutable
class _GeneratedThrottlePersistenceWrite {
  const _GeneratedThrottlePersistenceWrite({
    required this.agentId,
    required this.nextWakeAt,
    required this.updatedAt,
  });

  final String agentId;
  final DateTime? nextWakeAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) {
    return other is _GeneratedThrottlePersistenceWrite &&
        other.agentId == agentId &&
        other.nextWakeAt == nextWakeAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(agentId, nextWakeAt, updatedAt);

  @override
  String toString() {
    return '_GeneratedThrottlePersistenceWrite('
        'agentId: $agentId, nextWakeAt: $nextWakeAt, '
        'updatedAt: $updatedAt)';
  }
}

extension _AnyGeneratedThrottleScenario on glados.Any {
  glados.Generator<_GeneratedThrottleOperationKind> get throttleOperationKind =>
      glados.AnyUtils(this).choose(_GeneratedThrottleOperationKind.values);

  glados.Generator<_GeneratedThrottleAgentSlot> get throttleAgentSlot =>
      glados.AnyUtils(this).choose(_GeneratedThrottleAgentSlot.values);

  glados.Generator<_GeneratedHydrationOffset> get hydrationOffset =>
      glados.AnyUtils(this).choose(_GeneratedHydrationOffset.values);

  glados.Generator<_GeneratedThrottleElapsed> get throttleElapsed =>
      glados.AnyUtils(this).choose(_GeneratedThrottleElapsed.values);

  glados.Generator<_GeneratedThrottleOperation> get throttleOperation =>
      glados.CombinableAny(this).combine4(
        throttleOperationKind,
        throttleAgentSlot,
        hydrationOffset,
        throttleElapsed,
        (
          _GeneratedThrottleOperationKind kind,
          _GeneratedThrottleAgentSlot agentSlot,
          _GeneratedHydrationOffset hydrationOffset,
          _GeneratedThrottleElapsed elapsed,
        ) => _GeneratedThrottleOperation(
          kind: kind,
          agentSlot: agentSlot,
          hydrationOffset: hydrationOffset,
          elapsed: elapsed,
        ),
      );

  glados.Generator<_GeneratedThrottleScenario> get throttleScenario =>
      glados.ListAnys(this)
          .listWithLengthInRange(0, 35, throttleOperation)
          .map(
            (operations) => _GeneratedThrottleScenario(
              operations: operations,
            ),
          );

  glados.Generator<_GeneratedThrottlePersistedStateSlot>
  get throttlePersistedStateSlot =>
      glados.AnyUtils(this).choose(_GeneratedThrottlePersistedStateSlot.values);

  glados.Generator<_GeneratedThrottleRepositoryFailure>
  get throttleRepositoryFailure =>
      glados.AnyUtils(this).choose(_GeneratedThrottleRepositoryFailure.values);

  glados.Generator<_GeneratedThrottlePersistenceAgent>
  get throttlePersistenceAgent => glados.CombinableAny(this).combine2(
    throttlePersistedStateSlot,
    throttleRepositoryFailure,
    (
      _GeneratedThrottlePersistedStateSlot stateSlot,
      _GeneratedThrottleRepositoryFailure failure,
    ) => _GeneratedThrottlePersistenceAgent(
      stateSlot: stateSlot,
      failure: failure,
    ),
  );

  glados.Generator<_GeneratedThrottlePersistenceOperationKind>
  get throttlePersistenceOperationKind => glados.AnyUtils(
    this,
  ).choose(_GeneratedThrottlePersistenceOperationKind.values);

  glados.Generator<_GeneratedThrottlePersistenceOperation>
  get throttlePersistenceOperation => glados.CombinableAny(this).combine2(
    throttlePersistenceOperationKind,
    throttleAgentSlot,
    (
      _GeneratedThrottlePersistenceOperationKind kind,
      _GeneratedThrottleAgentSlot agentSlot,
    ) => _GeneratedThrottlePersistenceOperation(
      kind: kind,
      agentSlot: agentSlot,
    ),
  );

  glados.Generator<_GeneratedThrottlePersistenceScenario>
  get throttlePersistenceScenario => glados.CombinableAny(this).combine4(
    throttlePersistenceAgent,
    throttlePersistenceAgent,
    throttlePersistenceAgent,
    glados.ListAnys(
      this,
    ).listWithLengthInRange(1, 30, throttlePersistenceOperation),
    (
      _GeneratedThrottlePersistenceAgent firstAgent,
      _GeneratedThrottlePersistenceAgent secondAgent,
      _GeneratedThrottlePersistenceAgent thirdAgent,
      List<_GeneratedThrottlePersistenceOperation> operations,
    ) => _GeneratedThrottlePersistenceScenario(
      firstAgent: firstAgent,
      secondAgent: secondAgent,
      thirdAgent: thirdAgent,
      operations: operations,
    ),
  );
}

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository repository;

  setUp(() {
    repository = MockAgentRepository();
    when(() => repository.getAgentState(any())).thenAnswer((invocation) async {
      final agentId = invocation.positionalArguments.first as String;
      return makeTestState(agentId: agentId);
    });
    when(() => repository.upsertEntity(any())).thenAnswer((_) async {});
  });

  WakeThrottleCoordinator createCoordinator({
    required Future<void> Function() onDrainRequested,
    void Function(String agentId)? onPersistedStateChanged,
  }) {
    return WakeThrottleCoordinator(
      repository: repository,
      onDrainRequested: onDrainRequested,
      onPersistedStateChanged: onPersistedStateChanged,
      throttleWindow: _generatedThrottleWindow,
    );
  }

  group('WakeThrottleCoordinator', () {
    test('setDeadline persists next wake timestamp and notifies', () {
      final now = DateTime(2024, 3, 15, 10, 30);
      final persistedAgentIds = <String>[];

      fakeAsync((async) {
        final coordinator = createCoordinator(
          onDrainRequested: () async {},
          onPersistedStateChanged: persistedAgentIds.add,
        );

        try {
          withClock(Clock.fixed(now), () {
            unawaited(coordinator.setDeadline('agent-1'));
          });
          async.flushMicrotasks();

          final captured =
              verify(
                    () => repository.upsertEntity(captureAny()),
                  ).captured.single
                  as AgentStateEntity;

          expect(captured.agentId, 'agent-1');
          expect(captured.nextWakeAt, now.add(_generatedThrottleWindow));
          expect(captured.updatedAt, now);
          expect(persistedAgentIds, ['agent-1']);
        } finally {
          coordinator.dispose();
        }
      });
    });

    test(
      'setDeadline honours customDeadline and persists that exact timestamp '
      'instead of now+throttleWindow',
      () {
        final now = DateTime(2024, 3, 15, 10, 30);
        final morning = DateTime(2024, 3, 16, 6);

        fakeAsync((async) {
          final coordinator = createCoordinator(
            onDrainRequested: () async {},
          );

          try {
            withClock(Clock.fixed(now), () {
              unawaited(
                coordinator.setDeadline('agent-1', customDeadline: morning),
              );
            });
            async.flushMicrotasks();

            final captured =
                verify(
                      () => repository.upsertEntity(captureAny()),
                    ).captured.single
                    as AgentStateEntity;

            expect(
              captured.nextWakeAt,
              morning,
              reason:
                  'customDeadline must be persisted verbatim — propagated '
                  'matches need a precise next-06:00 target',
            );
            expect(
              withClock(
                Clock.fixed(now),
                () => coordinator.isThrottled('agent-1'),
              ),
              isTrue,
            );
            expect(coordinator.deadlineFor('agent-1'), morning);
          } finally {
            coordinator.dispose();
          }
        });
      },
    );

    test(
      'setDeadline silently ignores a customDeadline that is in the past — '
      'a stale timestamp must not collapse a propagated wake into an '
      'immediate fire',
      () {
        final now = DateTime(2024, 3, 15, 10, 30);
        final yesterday = now.subtract(const Duration(days: 1));

        fakeAsync((async) {
          final coordinator = createCoordinator(
            onDrainRequested: () async {},
          );

          try {
            withClock(Clock.fixed(now), () {
              unawaited(
                coordinator.setDeadline(
                  'agent-1',
                  customDeadline: yesterday,
                ),
              );
            });
            async.flushMicrotasks();

            verifyNever(() => repository.upsertEntity(any()));
            expect(coordinator.deadlineFor('agent-1'), isNull);
            expect(
              withClock(
                Clock.fixed(now),
                () => coordinator.isThrottled('agent-1'),
              ),
              isFalse,
            );
          } finally {
            coordinator.dispose();
          }
        });
      },
    );

    test('drains after throttle window even when persistence fails', () {
      final now = DateTime(2024, 3, 15, 10, 30);
      var drainRequests = 0;

      when(
        () => repository.getAgentState('agent-1'),
      ).thenThrow(StateError('database unavailable'));

      fakeAsync((async) {
        final coordinator = createCoordinator(
          onDrainRequested: () async {
            drainRequests += 1;
          },
        );

        try {
          withClock(Clock.fixed(now), () {
            unawaited(coordinator.setDeadline('agent-1'));
          });
          async.flushMicrotasks();

          expect(drainRequests, 0);

          async
            ..elapse(_generatedThrottleWindow)
            ..flushMicrotasks();

          expect(drainRequests, 1);
          expect(
            withClock(
              Clock.fixed(now.add(_generatedThrottleWindow)),
              () => coordinator.isThrottled('agent-1'),
            ),
            isFalse,
          );
        } finally {
          coordinator.dispose();
        }
      });
    });

    test(
      'clearThrottle does not clobber a deadline re-armed during the '
      'persisted-clear getAgentState gap (second containsKey guard)',
      () {
        // Drives the precise race the two `containsKey` guards in
        // `_clearPersistedThrottle` defend against: a stale clear write must
        // not null out `nextWakeAt` when a fresh `setDeadline` lands while the
        // clear is still awaiting `getAgentState`. Guard 1 passes (the
        // deadline was just removed by clearThrottle); the new deadline is
        // injected during the await; guard 2 must catch it and skip the write.
        final now = DateTime(2024, 3, 15, 10, 30);
        final getStateGate = Completer<AgentStateEntity?>();
        final upserts = <AgentStateEntity>[];

        // The clear path's getAgentState is the only call that must suspend on
        // the gate; the initial and re-arming setDeadline reads resolve
        // immediately. `gateClearRead` is flipped on only for the window
        // bracketing clearThrottle, so the right call is the one that hangs.
        var gateClearRead = false;
        when(() => repository.getAgentState('agent-1')).thenAnswer((_) async {
          if (gateClearRead) {
            return getStateGate.future;
          }
          return makeTestState(
            agentId: 'agent-1',
            nextWakeAt: now.add(_generatedThrottleWindow),
          );
        });
        when(() => repository.upsertEntity(any())).thenAnswer((
          invocation,
        ) async {
          upserts.add(
            invocation.positionalArguments.single as AgentStateEntity,
          );
        });

        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            final coordinator = createCoordinator(
              onDrainRequested: () async {},
            );

            try {
              // Arm an initial deadline so the agent has a live throttle, then
              // isolate the write log to just the clear/re-arm interleaving.
              unawaited(coordinator.setDeadline('agent-1'));
              async.flushMicrotasks();
              upserts.clear();

              // clearThrottle removes the in-memory deadline (guard 1 will
              // pass) and starts _clearPersistedThrottle, which suspends inside
              // the gated getAgentState. Gate only this read.
              gateClearRead = true;
              coordinator.clearThrottle('agent-1');
              async.flushMicrotasks();
              gateClearRead = false;
              expect(coordinator.deadlineFor('agent-1'), isNull);

              // Race: a fresh wake re-arms the deadline before the clear's
              // getAgentState resolves.
              unawaited(coordinator.setDeadline('agent-1'));
              async.flushMicrotasks();
              expect(
                coordinator.deadlineFor('agent-1'),
                now.add(_generatedThrottleWindow),
              );

              // Now let the stale clear resume — guard 2 must observe the
              // re-armed deadline and bail out without writing nextWakeAt=null.
              getStateGate.complete(
                makeTestState(
                  agentId: 'agent-1',
                  nextWakeAt: now.add(_generatedThrottleWindow),
                ),
              );
              async.flushMicrotasks();

              expect(
                upserts.where((s) => s.nextWakeAt == null),
                isEmpty,
                reason:
                    'the stale clear must not null out a deadline that was '
                    're-armed during the getAgentState gap',
              );
              expect(
                upserts.single.nextWakeAt,
                now.add(_generatedThrottleWindow),
                reason: 'only the re-arming setDeadline should have persisted',
              );
              expect(
                coordinator.deadlineFor('agent-1'),
                now.add(_generatedThrottleWindow),
                reason: 'the re-armed in-memory deadline survives the race',
              );
            } finally {
              coordinator.dispose();
            }
          });
        });
      },
    );

    glados.Glados(
      glados.any.throttleScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('matches generated deadline and deferred-drain semantics', (
      scenario,
    ) {
      fakeAsync((async) {
        var now = _generatedThrottleBase;
        var actualDrainRequests = 0;
        var expectedDrainRequests = 0;
        final expectedDeadlines = <String, DateTime>{};

        final coordinator = createCoordinator(
          onDrainRequested: () async {
            actualDrainRequests += 1;
          },
        );

        void assertAgentState(String agentId, String reason) {
          final expectedDeadline = expectedDeadlines[agentId];
          expect(
            withClock(
              Clock.fixed(now),
              () => coordinator.deadlineFor(agentId),
            ),
            expectedDeadline,
            reason: reason,
          );
          expect(
            withClock(
              Clock.fixed(now),
              () => coordinator.isThrottled(agentId),
            ),
            expectedDeadline?.isAfter(now) ?? false,
            reason: reason,
          );
        }

        void assertAllAgents(String reason) {
          expect(actualDrainRequests, expectedDrainRequests, reason: reason);
          for (final slot in _GeneratedThrottleAgentSlot.values) {
            assertAgentState(_generatedThrottleAgentId(slot), reason);
          }
        }

        try {
          for (final (index, operation) in scenario.operations.indexed) {
            final reason = '$scenario at operation $index ($operation)';

            switch (operation.kind) {
              case _GeneratedThrottleOperationKind.setDeadline:
                final deadline = now.add(_generatedThrottleWindow);
                expectedDeadlines[operation.agentId] = deadline;
                withClock(Clock.fixed(now), () {
                  unawaited(coordinator.setDeadline(operation.agentId));
                });
                async.flushMicrotasks();

              case _GeneratedThrottleOperationKind.hydrate:
                final offset = _generatedHydrationOffsetDuration(
                  operation.hydrationOffset,
                );
                final deadline = now.add(offset);
                if (deadline.isBefore(now)) {
                  withClock(Clock.fixed(now), () {
                    coordinator.setDeadlineFromHydration(
                      operation.agentId,
                      deadline,
                    );
                  });
                } else if (deadline.isAfter(now)) {
                  expectedDeadlines[operation.agentId] = deadline;
                  withClock(Clock.fixed(now), () {
                    coordinator.setDeadlineFromHydration(
                      operation.agentId,
                      deadline,
                    );
                  });
                } else {
                  expectedDeadlines.remove(operation.agentId);
                  expectedDrainRequests += 1;
                  withClock(Clock.fixed(now), () {
                    coordinator.setDeadlineFromHydration(
                      operation.agentId,
                      deadline,
                    );
                  });
                  async.flushMicrotasks();
                }

              case _GeneratedThrottleOperationKind.clear:
                expectedDeadlines.remove(operation.agentId);
                withClock(Clock.fixed(now), () {
                  coordinator.clearThrottle(operation.agentId);
                });
                async.flushMicrotasks();

              case _GeneratedThrottleOperationKind.elapse:
                final elapsed = _generatedElapsedDuration(operation.elapsed);
                final nextNow = now.add(elapsed);
                final dueAgentIds = expectedDeadlines.entries
                    .where((entry) => !entry.value.isAfter(nextNow))
                    .map((entry) => entry.key)
                    .toList();
                expectedDrainRequests += dueAgentIds.length;
                dueAgentIds.forEach(expectedDeadlines.remove);
                async
                  ..elapse(elapsed)
                  ..flushMicrotasks();
                now = nextNow;
            }

            assertAllAgents(reason);
          }
        } finally {
          coordinator.dispose();
        }
      });
    }, tags: 'glados');

    glados.Glados(
      glados.any.throttlePersistenceScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('matches generated persistence and callback semantics', (
      scenario,
    ) {
      fakeAsync((async) {
        var now = _generatedThrottleBase;
        var actualDrainRequests = 0;
        var expectedDrainRequests = 0;
        final actualChangedAgentIds = <String>[];
        final expectedChangedAgentIds = <String>[];
        final actualWrites = <_GeneratedThrottlePersistenceWrite>[];
        final expectedWrites = <_GeneratedThrottlePersistenceWrite>[];
        final actualStates = <String, AgentStateEntity?>{};
        final expectedStates = <String, AgentStateEntity?>{};
        final expectedDeadlines = <String, DateTime>{};
        final slotByAgentId = {
          for (final slot in _GeneratedThrottleAgentSlot.values)
            _generatedThrottleAgentId(slot): slot,
        };

        AgentStateEntity? initialStateFor(
          _GeneratedThrottleAgentSlot slot,
        ) {
          final agentId = _generatedThrottleAgentId(slot);
          return switch (scenario.agent(slot).stateSlot) {
            _GeneratedThrottlePersistedStateSlot.missing => null,
            _GeneratedThrottlePersistedStateSlot.idle => makeTestState(
              id: 'state-$agentId',
              agentId: agentId,
              updatedAt: _generatedThrottleBase.subtract(
                const Duration(minutes: 1),
              ),
            ),
            _GeneratedThrottlePersistedStateSlot.scheduled => makeTestState(
              id: 'state-$agentId',
              agentId: agentId,
              updatedAt: _generatedThrottleBase.subtract(
                const Duration(minutes: 1),
              ),
              nextWakeAt: _generatedThrottleBase.add(
                const Duration(minutes: 3),
              ),
            ),
          };
        }

        void recordExpectedPersistedState(
          String agentId,
          DateTime? nextWakeAt,
        ) {
          final slot = slotByAgentId[agentId]!;
          final agent = scenario.agent(slot);
          final state = expectedStates[agentId];
          if (agent.failure != _GeneratedThrottleRepositoryFailure.none ||
              state == null) {
            return;
          }

          expectedStates[agentId] = state.copyWith(
            nextWakeAt: nextWakeAt,
            updatedAt: now,
          );
          expectedWrites.add(
            _GeneratedThrottlePersistenceWrite(
              agentId: agentId,
              nextWakeAt: nextWakeAt,
              updatedAt: now,
            ),
          );
          expectedChangedAgentIds.add(agentId);
        }

        void recordExpectedClear(String agentId) {
          final state = expectedStates[agentId];
          if (state?.nextWakeAt == null) return;
          recordExpectedPersistedState(agentId, null);
        }

        void assertPersistence(String reason) {
          expect(
            actualDrainRequests,
            expectedDrainRequests,
            reason: reason,
          );
          expect(actualWrites, unorderedEquals(expectedWrites), reason: reason);
          expect(
            actualChangedAgentIds,
            unorderedEquals(expectedChangedAgentIds),
            reason: reason,
          );

          for (final entry in expectedStates.entries) {
            final actualState = actualStates[entry.key];
            final expectedState = entry.value;
            expect(
              actualState?.nextWakeAt,
              expectedState?.nextWakeAt,
              reason: reason,
            );
            expect(
              actualState?.updatedAt,
              expectedState?.updatedAt,
              reason: reason,
            );
          }
        }

        void flushSetDeadline(Future<void> future, String reason) {
          var completed = false;
          Object? error;
          unawaited(
            future.then<void>(
              (_) {
                completed = true;
              },
              onError: (Object caughtError, StackTrace _) {
                error = caughtError;
                completed = true;
              },
            ),
          );
          async.flushMicrotasks();

          expect(error, isNull, reason: reason);
          expect(completed, isTrue, reason: reason);
        }

        void elapse(Duration elapsed) {
          final nextNow = now.add(elapsed);
          now = nextNow;

          final dueAgentIds = expectedDeadlines.entries
              .where((entry) => !entry.value.isAfter(now))
              .map((entry) => entry.key)
              .toList();
          expectedDrainRequests += dueAgentIds.length;
          for (final agentId in dueAgentIds) {
            expectedDeadlines.remove(agentId);
            recordExpectedClear(agentId);
          }

          async
            ..elapse(elapsed)
            ..flushMicrotasks();
        }

        for (final slot in _GeneratedThrottleAgentSlot.values) {
          final agentId = _generatedThrottleAgentId(slot);
          final state = initialStateFor(slot);
          actualStates[agentId] = state;
          expectedStates[agentId] = state;
        }

        when(() => repository.getAgentState(any())).thenAnswer((
          invocation,
        ) async {
          final agentId = invocation.positionalArguments.first as String;
          final slot = slotByAgentId[agentId]!;
          if (scenario.agent(slot).failure ==
              _GeneratedThrottleRepositoryFailure.getState) {
            throw StateError('generated getAgentState failure for $agentId');
          }
          return actualStates[agentId];
        });
        when(() => repository.upsertEntity(any())).thenAnswer((
          invocation,
        ) async {
          final state =
              invocation.positionalArguments.first as AgentStateEntity;
          final slot = slotByAgentId[state.agentId]!;
          if (scenario.agent(slot).failure ==
              _GeneratedThrottleRepositoryFailure.upsert) {
            throw StateError('generated upsert failure for ${state.agentId}');
          }
          actualStates[state.agentId] = state;
          actualWrites.add(
            _GeneratedThrottlePersistenceWrite(
              agentId: state.agentId,
              nextWakeAt: state.nextWakeAt,
              updatedAt: state.updatedAt,
            ),
          );
        });

        final coordinator = createCoordinator(
          onDrainRequested: () async {
            actualDrainRequests += 1;
          },
          onPersistedStateChanged: actualChangedAgentIds.add,
        );

        try {
          withClock(Clock(() => now), () {
            for (final (index, operation) in scenario.operations.indexed) {
              final agentId = operation.agentId;
              final reason = '$scenario at operation $index ($operation)';

              switch (operation.kind) {
                case _GeneratedThrottlePersistenceOperationKind.setDeadline:
                  final deadline = now.add(_generatedThrottleWindow);
                  expectedDeadlines[agentId] = deadline;
                  recordExpectedPersistedState(agentId, deadline);
                  flushSetDeadline(
                    coordinator.setDeadline(agentId),
                    reason,
                  );

                case _GeneratedThrottlePersistenceOperationKind.hydrateExpired:
                  coordinator.setDeadlineFromHydration(
                    agentId,
                    now.subtract(const Duration(seconds: 1)),
                  );

                case _GeneratedThrottlePersistenceOperationKind
                    .hydrateImmediate:
                  expectedDeadlines.remove(agentId);
                  expectedDrainRequests += 1;
                  recordExpectedClear(agentId);
                  coordinator.setDeadlineFromHydration(agentId, now);
                  async.flushMicrotasks();

                case _GeneratedThrottlePersistenceOperationKind.hydrateFuture:
                  expectedDeadlines[agentId] = now.add(
                    _generatedThrottleHydrationDelay,
                  );
                  coordinator.setDeadlineFromHydration(
                    agentId,
                    now.add(_generatedThrottleHydrationDelay),
                  );

                case _GeneratedThrottlePersistenceOperationKind.clear:
                  expectedDeadlines.remove(agentId);
                  recordExpectedClear(agentId);
                  coordinator.clearThrottle(agentId);
                  async.flushMicrotasks();

                case _GeneratedThrottlePersistenceOperationKind.elapseTick:
                  elapse(const Duration(seconds: 1));

                case _GeneratedThrottlePersistenceOperationKind.elapseWindow:
                  elapse(_generatedThrottleWindow);

                case _GeneratedThrottlePersistenceOperationKind.elapseLong:
                  elapse(const Duration(seconds: 90));
              }

              for (final slot in _GeneratedThrottleAgentSlot.values) {
                final agentId = _generatedThrottleAgentId(slot);
                expect(
                  coordinator.deadlineFor(agentId),
                  expectedDeadlines[agentId],
                  reason: reason,
                );
              }
              assertPersistence(reason);
            }
          });
        } finally {
          coordinator.dispose();
        }
      });
    }, tags: 'glados');
  });
}
