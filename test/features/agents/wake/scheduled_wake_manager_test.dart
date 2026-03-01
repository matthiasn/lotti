import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/wake/scheduled_wake_manager.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:mocktail/mocktail.dart';

import '../test_utils.dart';

class MockAgentRepository extends Mock implements AgentRepository {}

class MockWakeOrchestrator extends Mock implements WakeOrchestrator {}

void main() {
  late MockAgentRepository repository;
  late MockWakeOrchestrator orchestrator;

  setUp(() {
    repository = MockAgentRepository();
    orchestrator = MockWakeOrchestrator();
  });

  ScheduledWakeManager createAndStart({
    Duration checkInterval = const Duration(minutes: 1),
  }) {
    return ScheduledWakeManager(
      repository: repository,
      orchestrator: orchestrator,
      checkInterval: checkInterval,
    )..start();
  }

  group('ScheduledWakeManager', () {
    test('enqueues wake for agent with scheduledWakeAt in the past', () {
      final now = DateTime(2024, 3, 15, 10, 30);
      final pastSchedule = DateTime(2024, 3, 15, 9);

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getAllAgentIdentities()).thenAnswer(
            (_) async => [makeTestIdentity()],
          );
          when(() => repository.getAgentState(kTestAgentId)).thenAnswer(
            (_) async => makeTestState(scheduledWakeAt: pastSchedule),
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
          when(() => repository.getAllAgentIdentities()).thenAnswer(
            (_) async => [makeTestIdentity()],
          );
          when(() => repository.getAgentState(kTestAgentId)).thenAnswer(
            (_) async => makeTestState(scheduledWakeAt: now),
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

    test('does not enqueue wake for agent with scheduledWakeAt in the future',
        () {
      final now = DateTime(2024, 3, 15, 10, 30);
      final futureSchedule = DateTime(2024, 3, 15, 12);

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getAllAgentIdentities()).thenAnswer(
            (_) async => [makeTestIdentity()],
          );
          when(() => repository.getAgentState(kTestAgentId)).thenAnswer(
            (_) async => makeTestState(scheduledWakeAt: futureSchedule),
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

    test('skips agent with no scheduledWakeAt', () {
      final now = DateTime(2024, 3, 15, 10, 30);

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getAllAgentIdentities()).thenAnswer(
            (_) async => [makeTestIdentity()],
          );
          when(() => repository.getAgentState(kTestAgentId)).thenAnswer(
            (_) async => makeTestState(),
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

    test('skips agent with no state', () {
      final now = DateTime(2024, 3, 15, 10, 30);

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getAllAgentIdentities()).thenAnswer(
            (_) async => [makeTestIdentity()],
          );
          when(() => repository.getAgentState(kTestAgentId)).thenAnswer(
            (_) async => null,
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
          when(() => repository.getAllAgentIdentities()).thenAnswer(
            (_) async => [
              makeTestIdentity(),
              makeTestIdentity(id: agentId2, agentId: agentId2),
            ],
          );
          when(() => repository.getAgentState(kTestAgentId)).thenAnswer(
            (_) async => makeTestState(scheduledWakeAt: pastSchedule),
          );
          when(() => repository.getAgentState(agentId2)).thenAnswer(
            (_) async =>
                makeTestState(agentId: agentId2, scheduledWakeAt: pastSchedule),
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
          when(() => repository.getAllAgentIdentities()).thenAnswer(
            (_) async => [makeTestIdentity()],
          );
          when(() => repository.getAgentState(kTestAgentId)).thenAnswer(
            (_) async => makeTestState(scheduledWakeAt: pastSchedule),
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
          when(() => repository.getAllAgentIdentities()).thenAnswer(
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

          verifyNever(() => repository.getAllAgentIdentities());
        });
      });
    });

    test('handles repository errors gracefully without crashing', () {
      final now = DateTime(2024, 3, 15, 10, 30);

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getAllAgentIdentities())
              .thenThrow(Exception('DB error'));

          // Should not throw.
          final manager = createAndStart();
          async.flushMicrotasks();

          // Clear invocation history so verify below only sees the recovery call.
          clearInteractions(repository);

          // Timer should still be running — next tick should try again.
          when(() => repository.getAllAgentIdentities()).thenAnswer(
            (_) async => [],
          );

          async
            ..elapse(const Duration(minutes: 1))
            ..flushMicrotasks();

          // Verify it recovered and called again after the error.
          verify(() => repository.getAllAgentIdentities()).called(1);

          manager.stop();
        });
      });
    });

    test('only enqueues due agents in a mixed set', () {
      final now = DateTime(2024, 3, 15, 10, 30);
      final pastSchedule = DateTime(2024, 3, 15, 8);
      final futureSchedule = DateTime(2024, 3, 16, 10);

      const dueAgentId = 'agent-due';
      const futureAgentId = 'agent-future';
      const noScheduleAgentId = 'agent-none';

      fakeAsync((async) {
        withClock(Clock.fixed(now), () {
          when(() => repository.getAllAgentIdentities()).thenAnswer(
            (_) async => [
              makeTestIdentity(id: dueAgentId, agentId: dueAgentId),
              makeTestIdentity(id: futureAgentId, agentId: futureAgentId),
              makeTestIdentity(
                id: noScheduleAgentId,
                agentId: noScheduleAgentId,
              ),
            ],
          );
          when(() => repository.getAgentState(dueAgentId)).thenAnswer(
            (_) async => makeTestState(
              agentId: dueAgentId,
              scheduledWakeAt: pastSchedule,
            ),
          );
          when(() => repository.getAgentState(futureAgentId)).thenAnswer(
            (_) async => makeTestState(
              agentId: futureAgentId,
              scheduledWakeAt: futureSchedule,
            ),
          );
          when(() => repository.getAgentState(noScheduleAgentId)).thenAnswer(
            (_) async => makeTestState(agentId: noScheduleAgentId),
          );

          final manager = createAndStart();
          async.flushMicrotasks();

          verify(
            () => orchestrator.enqueueManualWake(
              agentId: dueAgentId,
              reason: WakeReason.scheduled.name,
            ),
          ).called(1);
          verifyNever(
            () => orchestrator.enqueueManualWake(
              agentId: futureAgentId,
              reason: any(named: 'reason'),
            ),
          );
          verifyNever(
            () => orchestrator.enqueueManualWake(
              agentId: noScheduleAgentId,
              reason: any(named: 'reason'),
            ),
          );

          manager.stop();
        });
      });
    });
  });
}
