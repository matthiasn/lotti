import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/wake/scheduled_wake_manager.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

enum _GeneratedScheduledWakeStateKind {
  nonProjectNeverWoken,
  nonProjectPreviouslyWoken,
  projectNeverWoken,
  projectDormant,
  projectPendingActivity,
}

enum _GeneratedScheduledWakeTimeSlot {
  beforeNow,
  exactlyNow,
  afterNow,
  midnight,
  endOfDay,
}

enum _GeneratedScheduledWakeFailureSlot {
  none,
  firstFastForward,
  everyFastForward,
}

enum _GeneratedScheduledWakeManagerOperationKind { start, stop, tick }

final _generatedScheduledWakeNow = DateTime(2026, 5, 20, 10, 30);

class _GeneratedScheduledWakeSpec {
  const _GeneratedScheduledWakeSpec({
    required this.kind,
    required this.timeSlot,
  });

  final _GeneratedScheduledWakeStateKind kind;
  final _GeneratedScheduledWakeTimeSlot timeSlot;

  bool get expectsFastForward =>
      kind == _GeneratedScheduledWakeStateKind.projectDormant;

  bool get expectsEnqueue => !expectsFastForward;

  DateTime get scheduledWakeAt {
    final (hour, minute) = switch (timeSlot) {
      _GeneratedScheduledWakeTimeSlot.beforeNow => (6, 15),
      _GeneratedScheduledWakeTimeSlot.exactlyNow => (10, 30),
      _GeneratedScheduledWakeTimeSlot.afterNow => (16, 45),
      _GeneratedScheduledWakeTimeSlot.midnight => (0, 5),
      _GeneratedScheduledWakeTimeSlot.endOfDay => (23, 55),
    };
    return DateTime(2026, 5, 17, hour, minute);
  }

  DateTime expectedFastForwardWakeAt(DateTime now) {
    final scheduled = scheduledWakeAt;
    var nextWake = DateTime(
      now.year,
      now.month,
      now.day,
      scheduled.hour,
      scheduled.minute,
    );
    if (!nextWake.isAfter(now)) {
      nextWake = DateTime(
        now.year,
        now.month,
        now.day + 1,
        scheduled.hour,
        scheduled.minute,
      );
    }
    return nextWake;
  }

  AgentStateEntity toState(int index) {
    final agentId = 'generated-scheduled-agent-$index';
    final projectId = 'generated-project-$index';
    return makeTestState(
      id: 'generated-scheduled-state-$index',
      agentId: agentId,
      scheduledWakeAt: scheduledWakeAt,
      lastWakeAt: switch (kind) {
        _GeneratedScheduledWakeStateKind.nonProjectNeverWoken ||
        _GeneratedScheduledWakeStateKind.projectNeverWoken => null,
        _GeneratedScheduledWakeStateKind.nonProjectPreviouslyWoken ||
        _GeneratedScheduledWakeStateKind.projectDormant ||
        _GeneratedScheduledWakeStateKind.projectPendingActivity => DateTime(
          2026,
          5,
          17,
          11,
        ),
      },
      slots: switch (kind) {
        _GeneratedScheduledWakeStateKind.nonProjectNeverWoken ||
        _GeneratedScheduledWakeStateKind.nonProjectPreviouslyWoken =>
          const AgentSlots(),
        _GeneratedScheduledWakeStateKind.projectNeverWoken ||
        _GeneratedScheduledWakeStateKind.projectDormant => AgentSlots(
          activeProjectId: projectId,
        ),
        _GeneratedScheduledWakeStateKind.projectPendingActivity => AgentSlots(
          activeProjectId: projectId,
          pendingProjectActivityAt: DateTime(2026, 5, 20, 9),
        ),
      },
    );
  }

  @override
  String toString() {
    return '_GeneratedScheduledWakeSpec('
        'kind: $kind, timeSlot: $timeSlot)';
  }
}

class _GeneratedScheduledWakeBatchScenario {
  const _GeneratedScheduledWakeBatchScenario({
    required this.specs,
    required this.failureSlot,
  });

  final List<_GeneratedScheduledWakeSpec> specs;
  final _GeneratedScheduledWakeFailureSlot failureSlot;

  Set<String> failingFastForwardAgentIds(List<AgentStateEntity> states) {
    final fastForwardIds = <String>[
      for (var i = 0; i < specs.length; i++)
        if (specs[i].expectsFastForward) states[i].agentId,
    ];
    return switch (failureSlot) {
      _GeneratedScheduledWakeFailureSlot.none => const <String>{},
      _GeneratedScheduledWakeFailureSlot.firstFastForward =>
        fastForwardIds.isEmpty ? const <String>{} : {fastForwardIds.first},
      _GeneratedScheduledWakeFailureSlot.everyFastForward =>
        fastForwardIds.toSet(),
    };
  }

  @override
  String toString() {
    return '_GeneratedScheduledWakeBatchScenario('
        'specs: $specs, failureSlot: $failureSlot)';
  }
}

class _GeneratedScheduledWakeManagerOperation {
  const _GeneratedScheduledWakeManagerOperation({required this.kind});

  final _GeneratedScheduledWakeManagerOperationKind kind;

  @override
  String toString() {
    return '_GeneratedScheduledWakeManagerOperation(kind: $kind)';
  }
}

class _GeneratedScheduledWakeManagerLifecycleScenario {
  const _GeneratedScheduledWakeManagerLifecycleScenario({
    required this.operations,
  });

  final List<_GeneratedScheduledWakeManagerOperation> operations;

  @override
  String toString() {
    return '_GeneratedScheduledWakeManagerLifecycleScenario('
        'operations: $operations)';
  }
}

extension _AnyGeneratedScheduledWakeScenario on glados.Any {
  glados.Generator<_GeneratedScheduledWakeStateKind>
  get scheduledWakeStateKind =>
      glados.AnyUtils(this).choose(_GeneratedScheduledWakeStateKind.values);

  glados.Generator<_GeneratedScheduledWakeTimeSlot> get scheduledWakeTimeSlot =>
      glados.AnyUtils(this).choose(_GeneratedScheduledWakeTimeSlot.values);

  glados.Generator<_GeneratedScheduledWakeSpec> get scheduledWakeSpec =>
      glados.CombinableAny(this).combine2(
        scheduledWakeStateKind,
        scheduledWakeTimeSlot,
        (
          _GeneratedScheduledWakeStateKind kind,
          _GeneratedScheduledWakeTimeSlot timeSlot,
        ) => _GeneratedScheduledWakeSpec(kind: kind, timeSlot: timeSlot),
      );

  glados.Generator<_GeneratedScheduledWakeFailureSlot>
  get scheduledWakeFailureSlot =>
      glados.AnyUtils(this).choose(_GeneratedScheduledWakeFailureSlot.values);

  glados.Generator<_GeneratedScheduledWakeBatchScenario>
  get scheduledWakeBatchScenario => glados.CombinableAny(this).combine2(
    glados.ListAnys(this).listWithLengthInRange(0, 8, scheduledWakeSpec),
    scheduledWakeFailureSlot,
    (
      List<_GeneratedScheduledWakeSpec> specs,
      _GeneratedScheduledWakeFailureSlot failureSlot,
    ) => _GeneratedScheduledWakeBatchScenario(
      specs: specs,
      failureSlot: failureSlot,
    ),
  );

  glados.Generator<_GeneratedScheduledWakeManagerOperationKind>
  get scheduledWakeManagerOperationKind => glados.AnyUtils(
    this,
  ).choose(_GeneratedScheduledWakeManagerOperationKind.values);

  glados.Generator<_GeneratedScheduledWakeManagerOperation>
  get scheduledWakeManagerOperation => scheduledWakeManagerOperationKind.map(
    (kind) => _GeneratedScheduledWakeManagerOperation(kind: kind),
  );

  glados.Generator<_GeneratedScheduledWakeManagerLifecycleScenario>
  get scheduledWakeManagerLifecycleScenario => glados.ListAnys(this)
      .listWithLengthInRange(1, 24, scheduledWakeManagerOperation)
      .map(
        (operations) => _GeneratedScheduledWakeManagerLifecycleScenario(
          operations: operations,
        ),
      );
}

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository repository;
  late MockWakeOrchestrator orchestrator;
  late MockAgentSyncService syncService;

  setUp(() {
    repository = MockAgentRepository();
    orchestrator = MockWakeOrchestrator();
    syncService = MockAgentSyncService();
  });

  ScheduledWakeManager createAndStart({
    Duration checkInterval = const Duration(minutes: 1),
  }) {
    return ScheduledWakeManager(
      repository: repository,
      orchestrator: orchestrator,
      syncService: syncService,
      checkInterval: checkInterval,
    )..start();
  }

  group('ScheduledWakeManager', () {
    glados.Glados(
      glados.any.scheduledWakeBatchScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('matches generated due-batch enqueue and fast-forward semantics', (
      scenario,
    ) {
      final states = [
        for (final (index, spec) in scenario.specs.indexed) spec.toState(index),
      ];
      final failingFastForwardIds = scenario.failingFastForwardAgentIds(states);
      final generatedRepository = MockAgentRepository();
      final generatedOrchestrator = MockWakeOrchestrator();
      final generatedSyncService = MockAgentSyncService();
      final attemptedFastForwardWrites = <AgentStateEntity>[];
      final notifiedAgentIds = <String>[];

      fakeAsync((async) {
        withClock(Clock.fixed(_generatedScheduledWakeNow), () {
          when(
            () => generatedRepository.getDueScheduledAgentStates(any()),
          ).thenAnswer((_) async => states);
          when(() => generatedSyncService.upsertEntity(any())).thenAnswer((
            invocation,
          ) async {
            final entity =
                invocation.positionalArguments.single as AgentStateEntity;
            attemptedFastForwardWrites.add(entity);
            if (failingFastForwardIds.contains(entity.agentId)) {
              throw StateError('generated sync failure');
            }
          });

          final manager = ScheduledWakeManager(
            repository: generatedRepository,
            orchestrator: generatedOrchestrator,
            syncService: generatedSyncService,
            checkInterval: const Duration(minutes: 7),
            onPersistedStateChanged: notifiedAgentIds.add,
          )..start();
          async.flushMicrotasks();

          final expectedEnqueuedIds = <String>[
            for (var i = 0; i < scenario.specs.length; i++)
              if (scenario.specs[i].expectsEnqueue) states[i].agentId,
          ];
          final expectedFastForwardIds = <String>[
            for (var i = 0; i < scenario.specs.length; i++)
              if (scenario.specs[i].expectsFastForward) states[i].agentId,
          ];
          final expectedNotifiedIds = expectedFastForwardIds
              .where((agentId) => !failingFastForwardIds.contains(agentId))
              .toList();

          if (expectedEnqueuedIds.isEmpty) {
            verifyNever(
              () => generatedOrchestrator.enqueueManualWake(
                agentId: any(named: 'agentId'),
                reason: any(named: 'reason'),
              ),
            );
          } else {
            final capturedAgentIds = verify(
              () => generatedOrchestrator.enqueueManualWake(
                agentId: captureAny(named: 'agentId'),
                reason: WakeReason.scheduled.name,
              ),
            ).captured.cast<String>();
            expect(capturedAgentIds, expectedEnqueuedIds, reason: '$scenario');
          }

          expect(
            attemptedFastForwardWrites.map((state) => state.agentId).toList(),
            expectedFastForwardIds,
            reason: '$scenario',
          );

          for (final write in attemptedFastForwardWrites) {
            final index = states.indexWhere(
              (state) => state.agentId == write.agentId,
            );
            expect(index, isNonNegative, reason: '$scenario');
            expect(
              write.scheduledWakeAt,
              scenario.specs[index].expectedFastForwardWakeAt(
                _generatedScheduledWakeNow,
              ),
              reason: '$scenario',
            );
            expect(write.updatedAt, _generatedScheduledWakeNow);
          }

          expect(notifiedAgentIds, expectedNotifiedIds, reason: '$scenario');

          manager.stop();
        });
      });
    });

    glados.Glados(
      glados.any.scheduledWakeManagerLifecycleScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test('matches generated start stop and timer replacement semantics', (
      scenario,
    ) {
      const checkInterval = Duration(minutes: 11);
      final generatedRepository = MockAgentRepository();
      final generatedOrchestrator = MockWakeOrchestrator();
      final generatedSyncService = MockAgentSyncService();
      var repositoryChecks = 0;
      var expectedChecks = 0;
      var running = false;

      fakeAsync((async) {
        withClock(Clock.fixed(_generatedScheduledWakeNow), () {
          when(
            () => generatedRepository.getDueScheduledAgentStates(any()),
          ).thenAnswer((_) async {
            repositoryChecks++;
            return <AgentStateEntity>[];
          });

          final manager = ScheduledWakeManager(
            repository: generatedRepository,
            orchestrator: generatedOrchestrator,
            syncService: generatedSyncService,
            checkInterval: checkInterval,
          );

          for (final operation in scenario.operations) {
            switch (operation.kind) {
              case _GeneratedScheduledWakeManagerOperationKind.start:
                manager.start();
                running = true;
                expectedChecks++;
                async.flushMicrotasks();

              case _GeneratedScheduledWakeManagerOperationKind.stop:
                manager.stop();
                running = false;
                async.flushMicrotasks();

              case _GeneratedScheduledWakeManagerOperationKind.tick:
                async.elapse(checkInterval);
                if (running) expectedChecks++;
                async.flushMicrotasks();
            }

            expect(repositoryChecks, expectedChecks, reason: '$scenario');
          }

          manager.stop();
        });
      });
    });

    test('enqueues wake for agent with scheduledWakeAt in the past', () {
      final now = DateTime(2024, 3, 15, 10, 30);
      final pastSchedule = DateTime(2024, 3, 15, 9);

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [makeTestState(scheduledWakeAt: pastSchedule)],
          );

          final manager = createAndStart();
          async.flushMicrotasks();

          verify(
            () => orchestrator.enqueueManualWake(
              agentId: kTestAgentId,
              reason: WakeReason.scheduled.name,
            ),
          ).called(1);

          manager.stop();
        });
      });
    });

    test('enqueues wake for agent with scheduledWakeAt exactly at now', () {
      final now = DateTime(2024, 3, 15, 10, 30);

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [makeTestState(scheduledWakeAt: now)],
          );

          final manager = createAndStart();
          async.flushMicrotasks();

          verify(
            () => orchestrator.enqueueManualWake(
              agentId: kTestAgentId,
              reason: WakeReason.scheduled.name,
            ),
          ).called(1);

          manager.stop();
        });
      });
    });

    test('does not enqueue wake when no agents are due', () {
      final now = DateTime(2024, 3, 15, 10, 30);

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [],
          );

          final manager = createAndStart();
          async.flushMicrotasks();

          verifyNever(
            () => orchestrator.enqueueManualWake(
              agentId: any(named: 'agentId'),
              reason: any(named: 'reason'),
            ),
          );

          manager.stop();
        });
      });
    });

    test('enqueues wakes for multiple due agents', () {
      final now = DateTime(2024, 3, 15, 10, 30);
      final pastSchedule = DateTime(2024, 3, 15, 8);

      const agentId2 = 'agent-002';

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [
              makeTestState(scheduledWakeAt: pastSchedule),
              makeTestState(
                agentId: agentId2,
                scheduledWakeAt: pastSchedule,
              ),
            ],
          );

          final manager = createAndStart();
          async.flushMicrotasks();

          verify(
            () => orchestrator.enqueueManualWake(
              agentId: kTestAgentId,
              reason: WakeReason.scheduled.name,
            ),
          ).called(1);
          verify(
            () => orchestrator.enqueueManualWake(
              agentId: agentId2,
              reason: WakeReason.scheduled.name,
            ),
          ).called(1);

          manager.stop();
        });
      });
    });

    test('periodic timer fires and checks again', () {
      final now = DateTime(2024, 3, 15, 10, 30);
      final pastSchedule = DateTime(2024, 3, 15, 9);

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [makeTestState(scheduledWakeAt: pastSchedule)],
          );

          final manager = createAndStart();
          async.flushMicrotasks();

          // First immediate check.
          verify(
            () => orchestrator.enqueueManualWake(
              agentId: kTestAgentId,
              reason: WakeReason.scheduled.name,
            ),
          ).called(1);

          // Advance past one check interval.
          async
            ..elapse(const Duration(minutes: 1))
            ..flushMicrotasks();

          // Second check from periodic timer.
          verify(
            () => orchestrator.enqueueManualWake(
              agentId: kTestAgentId,
              reason: WakeReason.scheduled.name,
            ),
          ).called(1);

          manager.stop();
        });
      });
    });

    test('stop cancels the periodic timer', () {
      final now = DateTime(2024, 3, 15, 10, 30);

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [],
          );

          final manager = createAndStart();
          async.flushMicrotasks();

          manager.stop();

          // Clear any previous interactions.
          reset(repository);

          // Advance past check interval — no more calls should happen.
          async
            ..elapse(const Duration(minutes: 2))
            ..flushMicrotasks();

          verifyNever(
            () => repository.getDueScheduledAgentStates(any()),
          );
        });
      });
    });

    test('handles repository errors gracefully without crashing', () {
      final now = DateTime(2024, 3, 15, 10, 30);

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(
            () => repository.getDueScheduledAgentStates(any()),
          ).thenThrow(Exception('DB error'));

          // Should not throw.
          final manager = createAndStart();
          async.flushMicrotasks();

          // Clear invocation history so verify below only sees the recovery
          // call.
          clearInteractions(repository);

          // Timer should still be running — next tick should try again.
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [],
          );

          async
            ..elapse(const Duration(minutes: 1))
            ..flushMicrotasks();

          // Verify it recovered and called again after the error.
          verify(() => repository.getDueScheduledAgentStates(any())).called(1);

          manager.stop();
        });
      });
    });

    test('fast-forwards dormant project agents without enqueuing a wake', () {
      final now = DateTime(2024, 3, 15, 10, 30);
      final pastSchedule = DateTime(2024, 3, 13, 6);
      final dormantState = makeTestState(
        scheduledWakeAt: pastSchedule,
        lastWakeAt: DateTime(2024, 3, 13, 6, 5),
        slots: const AgentSlots(activeProjectId: 'project-1'),
      );

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [dormantState],
          );
          when(
            () => syncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          final manager = createAndStart();
          async.flushMicrotasks();

          verifyNever(
            () => orchestrator.enqueueManualWake(
              agentId: any(named: 'agentId'),
              reason: any(named: 'reason'),
            ),
          );

          final captured =
              verify(
                    () => syncService.upsertEntity(captureAny()),
                  ).captured.single
                  as AgentStateEntity;
          expect(captured.scheduledWakeAt, DateTime(2024, 3, 16, 6));

          manager.stop();
        });
      });
    });

    test(
      'enqueues never-woken project agents even without pending activity',
      () {
        final now = DateTime(2024, 3, 15, 10, 30);
        final pastSchedule = DateTime(2024, 3, 14, 6);
        // lastWakeAt is null → first run, must execute.
        final neverWokenState = makeTestState(
          scheduledWakeAt: pastSchedule,
          slots: const AgentSlots(activeProjectId: 'project-1'),
        );

        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
              (_) async => [neverWokenState],
            );

            final manager = createAndStart();
            async.flushMicrotasks();

            verify(
              () => orchestrator.enqueueManualWake(
                agentId: kTestAgentId,
                reason: WakeReason.scheduled.name,
              ),
            ).called(1);

            manager.stop();
          });
        });
      },
    );

    test('mixed batch: fast-forwards dormant, enqueues active', () {
      final now = DateTime(2024, 3, 15, 10, 30);
      final pastSchedule = DateTime(2024, 3, 13, 6);

      const activeId = 'agent-active';
      const dormantId = 'agent-dormant';

      final dormantState = makeTestState(
        agentId: dormantId,
        scheduledWakeAt: pastSchedule,
        lastWakeAt: DateTime(2024, 3, 13, 6, 5),
        slots: const AgentSlots(activeProjectId: 'project-1'),
      );
      final activeState = makeTestState(
        agentId: activeId,
        scheduledWakeAt: pastSchedule,
        lastWakeAt: DateTime(2024, 3, 13, 6, 5),
        slots: AgentSlots(
          activeProjectId: 'project-2',
          pendingProjectActivityAt: DateTime(2024, 3, 15, 9),
        ),
      );

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [dormantState, activeState],
          );
          when(
            () => syncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          final manager = createAndStart();
          async.flushMicrotasks();

          // Active agent enqueued.
          verify(
            () => orchestrator.enqueueManualWake(
              agentId: activeId,
              reason: WakeReason.scheduled.name,
            ),
          ).called(1);

          // Dormant agent NOT enqueued.
          verifyNever(
            () => orchestrator.enqueueManualWake(
              agentId: dormantId,
              reason: any(named: 'reason'),
            ),
          );

          // Dormant agent fast-forwarded via syncService.
          verify(() => syncService.upsertEntity(any())).called(1);

          manager.stop();
        });
      });
    });

    test('fast-forward fires onPersistedStateChanged callback', () {
      final now = DateTime(2024, 3, 15, 10, 30);
      final dormantState = makeTestState(
        scheduledWakeAt: DateTime(2024, 3, 13, 6),
        lastWakeAt: DateTime(2024, 3, 13, 6, 5),
        slots: const AgentSlots(activeProjectId: 'project-1'),
      );
      String? notifiedAgentId;

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [dormantState],
          );
          when(
            () => syncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          final manager = ScheduledWakeManager(
            repository: repository,
            orchestrator: orchestrator,
            syncService: syncService,
            onPersistedStateChanged: (id) => notifiedAgentId = id,
          )..start();
          async.flushMicrotasks();

          expect(notifiedAgentId, kTestAgentId);

          manager.stop();
        });
      });
    });

    test('enqueues non-project agents even without pending activity', () {
      final now = DateTime(2024, 3, 15, 10, 30);
      final pastSchedule = DateTime(2024, 3, 14, 6);
      // No activeProjectId → not a project agent → always enqueue.
      final improverState = makeTestState(
        scheduledWakeAt: pastSchedule,
        lastWakeAt: DateTime(2024, 3, 14, 6, 5),
      );

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [improverState],
          );

          final manager = createAndStart();
          async.flushMicrotasks();

          verify(
            () => orchestrator.enqueueManualWake(
              agentId: kTestAgentId,
              reason: WakeReason.scheduled.name,
            ),
          ).called(1);

          manager.stop();
        });
      });
    });

    test(
      'enqueues project agents with pending activity even if previously woken',
      () {
        final now = DateTime(2024, 3, 15, 10, 30);
        final pastSchedule = DateTime(2024, 3, 14, 6);
        final activeState = makeTestState(
          scheduledWakeAt: pastSchedule,
          lastWakeAt: DateTime(2024, 3, 14, 6, 5),
          slots: AgentSlots(
            activeProjectId: 'project-1',
            pendingProjectActivityAt: DateTime(2024, 3, 15, 8),
          ),
        );

        fakeAsync((async) {
          withClock(Clock.fixed(now), () {
            when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
              (_) async => [activeState],
            );

            final manager = createAndStart();
            async.flushMicrotasks();

            verify(
              () => orchestrator.enqueueManualWake(
                agentId: kTestAgentId,
                reason: WakeReason.scheduled.name,
              ),
            ).called(1);

            manager.stop();
          });
        });
      },
    );
    test('fast-forward preserves agent schedule hour and keeps today slot', () {
      // now is 5:00 AM, schedule was for 9:00 AM two days ago.
      // Fast-forward should schedule for TODAY at 9:00 AM, not tomorrow.
      final now = DateTime(2024, 3, 15, 5);
      final pastSchedule = DateTime(2024, 3, 13, 9);
      final dormantState = makeTestState(
        scheduledWakeAt: pastSchedule,
        lastWakeAt: DateTime(2024, 3, 13, 9, 5),
        slots: const AgentSlots(activeProjectId: 'project-1'),
      );

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [dormantState],
          );
          when(
            () => syncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          final manager = createAndStart();
          async.flushMicrotasks();

          final captured =
              verify(
                    () => syncService.upsertEntity(captureAny()),
                  ).captured.single
                  as AgentStateEntity;
          // Today at 9:00 AM, not tomorrow.
          expect(captured.scheduledWakeAt, DateTime(2024, 3, 15, 9));

          manager.stop();
        });
      });
    });

    test('per-agent failure does not stop remaining agents', () {
      final now = DateTime(2024, 3, 15, 10, 30);
      final pastSchedule = DateTime(2024, 3, 13, 6);

      const failingId = 'agent-failing';
      const succeedingId = 'agent-succeeding';

      final failingState = makeTestState(
        agentId: failingId,
        scheduledWakeAt: pastSchedule,
        lastWakeAt: DateTime(2024, 3, 13, 6, 5),
        slots: const AgentSlots(activeProjectId: 'project-1'),
      );
      final succeedingState = makeTestState(
        agentId: succeedingId,
        scheduledWakeAt: pastSchedule,
      );

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getDueScheduledAgentStates(any())).thenAnswer(
            (_) async => [failingState, succeedingState],
          );
          // First agent's upsert fails.
          when(
            () => syncService.upsertEntity(any()),
          ).thenThrow(Exception('sync error'));

          final manager = createAndStart();
          async.flushMicrotasks();

          // Second agent should still be enqueued despite first failing.
          verify(
            () => orchestrator.enqueueManualWake(
              agentId: succeedingId,
              reason: WakeReason.scheduled.name,
            ),
          ).called(1);

          manager.stop();
        });
      });
    });
  });
}
