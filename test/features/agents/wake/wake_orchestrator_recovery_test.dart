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

      test('measures staleness from the latest sequential wake', () {
        fakeAsync((async) {
          final firstCompleter = Completer<Map<String, VectorClock>?>();
          final secondCompleter = Completer<Map<String, VectorClock>?>();
          final executedAgentIds = <String>[];

          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            maxConcurrentWakes: () => 1,
            wakeExecutor: (agentId, runKey, triggers, threadId) {
              executedAgentIds.add(agentId);
              return switch (agentId) {
                'first-agent' => firstCompleter.future,
                'second-agent' => secondCompleter.future,
                _ => Future.value(),
              };
            },
          );

          orchestrator.enqueueManualWake(
            agentId: 'first-agent',
            reason: 'manual',
          );
          async
            ..flushMicrotasks()
            ..elapse(const Duration(minutes: 7))
            ..flushMicrotasks();
          orchestrator.enqueueManualWake(
            agentId: 'second-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          firstCompleter.complete(null);
          async.flushMicrotasks();
          expect(executedAgentIds, equals(['first-agent', 'second-agent']));

          // The drain is 13 minutes old, but its active wake only started six
          // minutes ago and remains within the ten-minute execution cap.
          async
            ..elapse(const Duration(minutes: 6))
            ..flushMicrotasks();
          orchestrator.enqueueManualWake(
            agentId: 'next-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();

          secondCompleter.complete(null);
          async.flushMicrotasks();
          expect(
            executedAgentIds,
            equals(['first-agent', 'second-agent', 'next-agent']),
          );
        });
      });

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

      test('requeues work superseded during a policy lookup', () {
        fakeAsync((async) {
          final policyLookupGate = Completer<AgentDomainEntity?>();
          final replacementExecutionGate =
              Completer<Map<String, VectorClock>?>();
          final originalExecutionGate = Completer<Map<String, VectorClock>?>();
          final executedAgentIds = <String>[];
          var activeExecutions = 0;
          var maxActiveExecutions = 0;

          when(() => mockRepository.getEntity(any())).thenAnswer((invocation) {
            final agentId = invocation.positionalArguments.first as String;
            if (agentId == 'policy-agent') return policyLookupGate.future;
            return Future.value();
          });

          Future<Map<String, VectorClock>?> execute(
            String agentId,
            Completer<Map<String, VectorClock>?> gate,
          ) async {
            executedAgentIds.add(agentId);
            activeExecutions++;
            if (activeExecutions > maxActiveExecutions) {
              maxActiveExecutions = activeExecutions;
            }
            try {
              return await gate.future;
            } finally {
              activeExecutions--;
            }
          }

          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            maxConcurrentWakes: () => 1,
            wakeExecutor: (agentId, runKey, triggers, threadId) {
              return switch (agentId) {
                'policy-agent' => execute(agentId, originalExecutionGate),
                _ => execute(agentId, replacementExecutionGate),
              };
            },
          );

          orchestrator.enqueueManualWake(
            agentId: 'policy-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(executedAgentIds, isEmpty);

          // Supersede the drain while its dequeued job is still awaiting the
          // policy lookup, then occupy the only global execution slot.
          async.elapse(const Duration(minutes: 13));
          orchestrator.enqueueManualWake(
            agentId: 'replacement-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(executedAgentIds, equals(['replacement-agent']));

          // The stale continuation must hand its owned job back instead of
          // acquiring a second runner slot from the old loop iteration.
          policyLookupGate.complete(null);
          async.flushMicrotasks();
          expect(executedAgentIds, equals(['replacement-agent']));
          expect(maxActiveExecutions, 1);

          replacementExecutionGate.complete(null);
          async.flushMicrotasks();
          expect(
            executedAgentIds,
            equals(['replacement-agent', 'policy-agent']),
          );
          expect(maxActiveExecutions, 1);

          originalExecutionGate.complete(null);
          async.flushMicrotasks();
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
        'releases the stale slot without releasing its replacement',
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
            var stuckExecutionCount = 0;

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
                  maxConcurrentWakes: () => 1,
                  wakeExecutor: (agentId, runKey, triggers, threadId) {
                    executedAgentIds.add(agentId);
                    if (agentId == 'stuck-agent') {
                      stuckExecutionCount++;
                      if (stuckExecutionCount == 1) {
                        return Completer<Map<String, VectorClock>?>().future;
                      }
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

            // Queue follow-up work before the drain becomes stale. The hung
            // terminal status write cannot make progress, so the safety net
            // must re-check and recover once the 12-minute threshold passes.
            async
              ..elapse(const Duration(minutes: 1))
              ..flushMicrotasks();
            stuck.enqueueManualWake(agentId: 'stuck-agent', reason: 'manual');
            async.flushMicrotasks();
            expect(executedAgentIds, equals(['stuck-agent']));

            async
              ..elapse(const Duration(minutes: 2))
              ..flushMicrotasks();

            // Observable: the safety net re-entered processNext and fired the
            // stale-lock recovery without needing another enqueue.
            verify(
              () => logger.log(
                LogDomain.agentRuntime,
                any(that: contains('force-resetting stale drain lock')),
                subDomain: 'drain',
                level: any(named: 'level'),
              ),
            ).called(1);
            expect(executedAgentIds, equals(['stuck-agent', 'stuck-agent']));
            expect(stuckRunner.isRunning('stuck-agent'), isTrue);

            // Now release the hung aborted write so the old (superseded) drain
            // resumes and bails out. Its stale lease must not release the
            // replacement wake's lock.
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
            expect(stuckRunner.isRunning('stuck-agent'), isTrue);

            // Concurrency one remains enforced while the replacement runs.
            stuck.enqueueManualWake(agentId: 'third-agent', reason: 'manual');
            async.flushMicrotasks();
            expect(executedAgentIds, isNot(contains('third-agent')));

            replacementDrainGate.complete(null);
            async.flushMicrotasks();
            expect(
              executedAgentIds,
              equals(['stuck-agent', 'stuck-agent', 'third-agent']),
            );

            stuck.stop();
            controller.close();
          });
        },
      );
    });
  });
}
