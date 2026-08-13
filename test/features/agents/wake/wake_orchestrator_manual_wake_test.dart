import 'wake_orchestrator_test_harness.dart';

void main() {
  configureWakeOrchestratorTestSuite();

  // Owns manual wake enqueueing, run-key counters, and queued-wake cleanup.
  group('WakeOrchestrator', () {
    group('enqueueManualWake', () {
      test('enqueues a job and triggers processNext', () {
        fakeAsync((async) {
          (orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            wakeExecutor: noOpExecutor,
          )).enqueueManualWake(
            agentId: 'agent-1',
            reason: 'creation',
            triggerTokens: {'task-1'},
          );

          async.flushMicrotasks();

          // The job should have been executed (run persisted + completed).
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);
          verify(
            () => mockRepository.updateWakeRunStatus(
              any(),
              'completed',
              completedAt: any(named: 'completedAt'),
              errorMessage: any(named: 'errorMessage'),
            ),
          ).called(1);
        });
      });

      test(
        'supersede:false accumulates a second same-workspace wake instead of '
        'dropping the first still-queued one',
        () {
          fakeAsync((async) {
            orchestrator = WakeOrchestrator(
              repository: mockRepository,
              queue: queue,
              runner: runner,
              wakeExecutor: noOpExecutor,
            );
            // Hold single-flight so neither wake can drain; both stay queued
            // and we can observe whether the second superseded the first.
            late bool locked;
            runner.tryAcquire('planner').then((v) => locked = v);
            async.flushMicrotasks();
            expect(locked, isTrue);

            orchestrator.enqueueManualWake(
              agentId: 'planner',
              reason: 'capture_submitted',
              triggerTokens: {'capture_submitted:capX'},
              workspaceKey: 'day:dayplan-2026-06-08',
              supersede: false,
            );
            // Distinct wall-clock → distinct runKey, so the second job is not
            // deduplicated into the first.
            async.elapse(const Duration(seconds: 1));
            orchestrator.enqueueManualWake(
              agentId: 'planner',
              reason: 'capture_submitted',
              triggerTokens: {'capture_submitted:capY'},
              workspaceKey: 'day:dayplan-2026-06-08',
              supersede: false,
            );
            async.flushMicrotasks();

            // Both capture parses survive — neither dropped the other. With the
            // default (supersede:true) the second would have removed the first.
            expect(queue.length, 2);
          });
        },
      );

      test('uses the provided reason in the wake job', () {
        fakeAsync((async) {
          (orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            wakeExecutor: noOpExecutor,
          )).enqueueManualWake(
            agentId: 'agent-1',
            reason: 'reanalysis',
          );

          async.flushMicrotasks();

          final captured = verify(
            () => mockRepository.insertWakeRun(
              entry: captureAny(named: 'entry'),
            ),
          ).captured;
          final entry = captured.first as WakeRunLogData;
          expect(entry.reason, 'reanalysis');
          expect(entry.agentId, 'agent-1');
        });
      });

      test('bypasses self-notification suppression', () {
        fakeAsync((async) {
          orchestrator =
              WakeOrchestrator(
                  repository: mockRepository,
                  queue: queue,
                  runner: runner,
                  wakeExecutor: noOpExecutor,
                )
                // Record mutations for agent-1 that include task-1.
                ..recordMutatedEntities('agent-1', {
                  'task-1': const VectorClock({}),
                })
                // Manual wake should still go through despite suppression state.
                ..enqueueManualWake(
                  agentId: 'agent-1',
                  reason: 'creation',
                  triggerTokens: {'task-1'},
                );

          async.flushMicrotasks();

          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);
        });
      });
      test('removes pending subscription jobs for the same agent', () {
        fakeAsync((async) {
          final capturedEntries = stubInsertCapture(mockRepository);

          orchestrator.wakeExecutor = noOpExecutor;
          orchestrator.addSubscription(
            makeSub(matchEntityIds: {'task-1'}),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Emit a notification that enqueues a subscription job.
          controller.add({'task-1'});
          async.flushMicrotasks();

          // The job is deferred (not yet executed). Queue should have 1 job.
          expect(queue.length, 1);

          // Manual wake should remove the pending subscription job and
          // enqueue only the manual one → single execution.
          orchestrator.enqueueManualWake(
            agentId: 'agent-1',
            reason: 'manual',
          );
          async.flushMicrotasks();

          // Only one wake run should have been executed (the manual one).
          expect(capturedEntries, hasLength(1));
          expect(capturedEntries.first.reason, 'manual');

          controller.close();
        });
      });
    });
    group('monotonic wake counter', () {
      test('identical notifications produce different run keys', () {
        fakeAsync((async) {
          final capturedEntries = stubInsertCapture(mockRepository);

          orchestrator.wakeExecutor = noOpExecutor;
          orchestrator.addSubscription(makeSub());

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Defer-first: first notification enqueues + defers; drain executes.
          emitAndDrain(async, controller, {'entity-1'});

          // Advance past the 5s suppression TTL so the second notification
          // is not suppressed by the confirmed suppression record.
          async.elapse(const Duration(seconds: 6));

          // Clear throttle so the second notification is not blocked.
          orchestrator.clearThrottle('agent-1');

          // Second identical notification — must produce a different run key
          emitAndDrain(async, controller, {'entity-1'});

          expect(capturedEntries.length, equals(2));
          expect(
            capturedEntries[0].runKey,
            isNot(equals(capturedEntries[1].runKey)),
            reason:
                'Identical notifications must produce distinct run keys '
                'via the monotonic wake counter',
          );

          controller.close();
        });
      });

      test('removeSubscriptions resets counter for agent', () {
        fakeAsync((async) {
          final capturedEntries = stubInsertCapture(mockRepository);

          orchestrator.wakeExecutor = noOpExecutor;
          orchestrator.addSubscription(makeSub());

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Fire twice to increment counter to 1 (defer-first: drain each).
          emitAndDrain(async, controller, {'entity-1'});
          // Advance past the 5s suppression TTL so the second notification
          // is not suppressed by the confirmed suppression record.
          async.elapse(const Duration(seconds: 6));
          orchestrator.clearThrottle('agent-1');
          emitAndDrain(async, controller, {'entity-1'});
          expect(capturedEntries.length, equals(2));

          // Remove and re-add subscription (counter resets, throttle clears).
          orchestrator.removeSubscriptions('agent-1');
          // ignore: cascade_invocations
          orchestrator.addSubscription(makeSub());

          // Fire again — counter is back to 0 after reset, so both
          // invocations after the reset should succeed (not be deduped).
          emitAndDrain(async, controller, {'entity-1'});
          expect(capturedEntries.length, equals(3));

          controller.close();
        });
      });
    });
    group('enqueueManualWake deferred-drain cleanup', () {
      test('clears pending subscription jobs for agent', () {
        fakeAsync((async) {
          final controller = StreamController<Set<String>>.broadcast();
          final executedRunKeys = <String>[];

          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = (agentId, runKey, tokens, threadId) async {
              executedRunKeys.add(runKey);
              return null;
            };

          orchestrator.start(controller.stream);

          // Emit a notification to enqueue a subscription job
          emitTokens(async, controller, {'entity-1'});

          // Queue should have the subscription job
          expect(queue.isEmpty, isFalse);

          // Manual wake supersedes the subscription job.
          // enqueueManualWake calls removeByAgent (clearing the subscription
          // job) then enqueues a manual job and calls processNext.
          orchestrator.enqueueManualWake(
            agentId: 'agent-1',
            reason: 'user_trigger',
          );
          async.flushMicrotasks();

          // Only one execution should have occurred (the manual wake),
          // not the subscription job. The manual wake's processNext
          // consumes the manual job.
          expect(executedRunKeys, hasLength(1));

          // The deferred drain should not fire the removed subscription job
          // when the throttle window elapses.
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          // Still only one execution — the subscription job was removed.
          expect(executedRunKeys, hasLength(1));

          controller.close();
        });
      });
    });
  });
}
