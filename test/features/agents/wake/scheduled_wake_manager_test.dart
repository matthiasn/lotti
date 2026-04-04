import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/wake/scheduled_wake_manager.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

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
