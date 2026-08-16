import 'wake_orchestrator_test_harness.dart';

void main() {
  configureWakeOrchestratorTestSuite();

  // Owns stale-drain detection, force-reset recovery, and generation bail-out.
  group('WakeOrchestrator', () {
    group('stale drain recovery (Fix B)', () {
      test(
        'does not supersede a valid wake that outlives the old drain cap',
        () {
          fakeAsync((async) {
            final slowCompleter = Completer<Map<String, VectorClock>?>();
            final executedAgentIds = <String>[];

            orchestrator = WakeOrchestrator(
              repository: mockRepository,
              queue: queue,
              runner: runner,
              maxConcurrentWakes: () => 1,
              wakeExecutor: (agentId, runKey, triggers, threadId) {
                executedAgentIds.add(agentId);
                if (agentId == 'slow-agent') return slowCompleter.future;
                return Future.value();
              },
            );

            orchestrator.enqueueManualWake(
              agentId: 'slow-agent',
              reason: 'manual',
            );
            async.flushMicrotasks();
            expect(executedAgentIds, equals(['slow-agent']));

            // The wake is still valid but has outlived the old five-minute
            // stale-drain threshold.
            async
              ..elapse(const Duration(minutes: 6))
              ..flushMicrotasks();

            orchestrator.enqueueManualWake(
              agentId: 'next-agent',
              reason: 'manual',
            );
            async.flushMicrotasks();
            expect(executedAgentIds, equals(['slow-agent']));

            // Completing the valid wake must let its existing drain dispatch
            // the queued follow-up immediately. A premature force-reset leaves
            // next-agent queued until another scheduler trigger arrives.
            slowCompleter.complete(null);
            async.flushMicrotasks();
            expect(executedAgentIds, equals(['slow-agent', 'next-agent']));
          });
        },
      );

      test('does not force-reset when drain is within timeout window', () {
        fakeAsync((async) {
          final stuckCompleter = Completer<Map<String, VectorClock>?>();
          var executionCount = 0;

          orchestrator
            ..wakeExecutor = (agentId, runKey, triggers, threadId) {
              executionCount++;
              if (agentId == 'stuck-agent') return stuckCompleter.future;
              return Future.value();
            }
            ..addSubscription(
              makeSub(
                id: 'sub-stuck',
                agentId: 'stuck-agent',
                matchEntityIds: {'entity-stuck'},
              ),
            );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Trigger stuck agent.
          emitAndDrain(async, controller, {'entity-stuck'});
          expect(executionCount, 1);

          // Advance 60 seconds — well within both the 12-minute drain
          // stale-lock window and the per-cycle wakeRunMaxDuration cap, so
          // the stuck executor is still in flight.
          async.elapse(const Duration(seconds: 60));

          // Enqueue a manual wake — should set _drainRequested, not
          // force-reset.
          orchestrator.enqueueManualWake(
            agentId: 'stuck-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();

          // No new execution should have happened (drain is still stuck,
          // the manual wake is queued for when the drain loops back).
          expect(executionCount, 1);

          // Clean up.
          stuckCompleter.complete(null);
          async.flushMicrotasks();

          controller.close();
        });
      });
    });
  });

  group('_drain(generation) bail-out', () {
    group('processNext stale-lock force-reset', () {
      // These tests drive the force-reset branch that the existing
      // "stale drain recovery" tests never reach: with a normally-completing
      // abort path the stuck drain finishes at the 10-minute hard cap, so
      // _isDraining is already false by the time a later processNext runs.
      // To keep _isDraining stuck past the 12-minute _drainTimeout we hang the
      // *aborted* status write, freezing _executeJob (and thus the drain)
      // inside _safeUpdateStatus.
      test(
        'force-resets the stuck drain lock and the superseded drain bails out',
        () {
          fakeAsync((async) {
            final logger = MockDomainLogger();
            when(
              () => logger.log(
                any(),
                any(),
                subDomain: any(named: 'subDomain'),
                level: any(named: 'level'),
              ),
            ).thenReturn(null);
            when(
              () => logger.error(
                any(),
                any(),
                message: any(named: 'message'),
                subDomain: any(named: 'subDomain'),
                stackTrace: any(named: 'stackTrace'),
              ),
            ).thenReturn(null);

            final repo = MockAgentRepository();
            final stuckQueue = WakeQueue();
            final stuckRunner = WakeRunner();
            // Completer that gates the hung aborted-status write.
            final abortedStatusGate = Completer<void>();
            final replacementDrainGate = Completer<Map<String, VectorClock>?>();
            final executedAgentIds = <String>[];

            when(
              () => repo.insertWakeRun(entry: any(named: 'entry')),
            ).thenAnswer((_) async {});
            when(
              () => repo.getAgentState(any()),
            ).thenAnswer((_) async => null);
            when(() => repo.getEntity(any())).thenAnswer((_) async => null);
            when(() => repo.upsertEntity(any())).thenAnswer((_) async {});
            when(
              () => repo.updateWakeRunStatus(
                any(),
                any(),
                completedAt: any(named: 'completedAt'),
                errorMessage: any(named: 'errorMessage'),
              ),
            ).thenAnswer((invocation) async {
              final status = invocation.positionalArguments[1] as String;
              if (status == WakeRunStatus.aborted.name) {
                // Hang the aborted write so _executeJob never returns and the
                // drain holds the _isDraining lock past _drainTimeout.
                await abortedStatusGate.future;
              }
            });

            final stuck =
                WakeOrchestrator(
                  repository: repo,
                  queue: stuckQueue,
                  runner: stuckRunner,
                  domainLogger: logger,
                  wakeExecutor: (agentId, runKey, triggers, threadId) {
                    executedAgentIds.add(agentId);
                    if (agentId == 'stuck-agent') {
                      return Completer<Map<String, VectorClock>?>().future;
                    }
                    if (agentId == 'new-agent') {
                      return replacementDrainGate.future;
                    }
                    return Future.value();
                  },
                )..addSubscription(
                  makeSub(
                    id: 'sub-stuck',
                    agentId: 'stuck-agent',
                    matchEntityIds: {'entity-stuck'},
                  ),
                );

            final controller = StreamController<Set<String>>.broadcast();
            stuck.start(controller.stream);

            // Start the stuck drain: throttle window elapses, drain begins,
            // executor blocks forever.
            controller.add({'entity-stuck'});
            async
              ..elapse(WakeOrchestrator.throttleWindow)
              ..flushMicrotasks();
            expect(executedAgentIds, equals(['stuck-agent']));

            // The 10-minute hard cap fires, aborts the run, and the aborted
            // status write hangs — the drain stays locked.
            async
              ..elapse(WakeOrchestrator.wakeRunMaxDuration)
              ..flushMicrotasks();
            verify(
              () => repo.updateWakeRunStatus(
                any(),
                WakeRunStatus.aborted.name,
                completedAt: any(named: 'completedAt'),
                errorMessage: any(named: 'errorMessage'),
              ),
            ).called(1);

            // Advance well past the 12-minute stale-drain timeout (total since
            // drain start is now > 16 minutes).
            async
              ..elapse(const Duration(minutes: 6))
              ..flushMicrotasks();

            // A new wake for a different agent triggers processNext, which now
            // detects the stale lock and force-resets it (lines 854-862).
            stuck.enqueueManualWake(agentId: 'new-agent', reason: 'manual');
            async.flushMicrotasks();

            // Observable: the force-reset log fired and the new drain actually
            // executed the new agent's job (proving _isDraining was cleared).
            verify(
              () => logger.log(
                LogDomain.agentRuntime,
                any(that: contains('force-resetting stale drain lock')),
                subDomain: 'drain',
                level: any(named: 'level'),
              ),
            ).called(1);
            expect(executedAgentIds, contains('new-agent'));

            // Now release the hung aborted write so the old (superseded) drain
            // resumes, observes the bumped generation, and bails out (line 883).
            abortedStatusGate.complete();
            async.flushMicrotasks();

            verify(
              () => logger.log(
                LogDomain.agentRuntime,
                'drain superseded, bailing out',
                subDomain: 'drain',
                level: any(named: 'level'),
              ),
            ).called(1);

            // The replacement drain is still waiting on new-agent and has one
            // free global slot. Releasing the old drain must not clear the
            // replacement drain's wake signal, otherwise this newly queued
            // agent would wait for new-agent despite the available capacity.
            stuck.enqueueManualWake(agentId: 'third-agent', reason: 'manual');
            async.flushMicrotasks();
            expect(executedAgentIds, contains('third-agent'));

            replacementDrainGate.complete(null);
            async.flushMicrotasks();

            stuck.stop();
            controller.close();
          });
        },
      );
    });
  });
}
