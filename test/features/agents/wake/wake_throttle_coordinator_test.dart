import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/wake/wake_throttle_coordinator.dart';
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

const _generatedThrottleWindow = Duration(seconds: 30);
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
    });
  });
}
