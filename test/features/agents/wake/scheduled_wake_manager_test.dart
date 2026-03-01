import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
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
          when(() => repository.getDueScheduledAgentStates(any()))
              .thenThrow(Exception('DB error'));

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
  });
}
