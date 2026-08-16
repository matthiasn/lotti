import 'package:lotti/features/agents/wake/run_key_factory.dart';

import 'wake_orchestrator_test_harness.dart';

class _AcquisitionGatedWakeRunner extends WakeRunner {
  _AcquisitionGatedWakeRunner({
    required this.gatedAgentId,
    required this.gate,
  });

  final String gatedAgentId;
  final Completer<void> gate;

  @override
  Future<WakeRunnerLease?> tryAcquireLease(
    String agentId, {
    String? workspaceKey,
  }) async {
    final lease = await super.tryAcquireLease(
      agentId,
      workspaceKey: workspaceKey,
    );
    if (agentId == gatedAgentId) await gate.future;
    return lease;
  }
}

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

      test('starts the stale clock from the executor window', () {
        fakeAsync((async) {
          final finalPolicyGate = Completer<AgentDomainEntity?>();
          final slowExecutionGate = Completer<Map<String, VectorClock>?>();
          final executedAgentIds = <String>[];
          var slowPolicyReads = 0;
          when(() => mockRepository.getEntity(any())).thenAnswer((call) {
            final agentId = call.positionalArguments.first as String;
            if (agentId == 'slow-agent' && ++slowPolicyReads == 2) {
              return finalPolicyGate.future;
            }
            return Future.value();
          });
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            maxConcurrentWakes: () => 1,
            wakeExecutor: (agentId, runKey, triggers, threadId) {
              executedAgentIds.add(agentId);
              if (agentId == 'slow-agent') return slowExecutionGate.future;
              return Future.value();
            },
          );

          orchestrator.enqueueManualWake(
            agentId: 'slow-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(executedAgentIds, isEmpty);

          // Pre-execution work consumes three minutes before the executor's
          // separate ten-minute cap begins.
          async.elapse(const Duration(minutes: 3));
          finalPolicyGate.complete(null);
          async.flushMicrotasks();
          expect(executedAgentIds, equals(['slow-agent']));

          // The drain is 12.5 minutes old, but executor work has only used
          // 9.5 minutes of its valid ten-minute window.
          async.elapse(const Duration(minutes: 9, seconds: 30));
          orchestrator.enqueueManualWake(
            agentId: 'next-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(executedAgentIds, equals(['slow-agent']));

          slowExecutionGate.complete(null);
          async.flushMicrotasks();
          expect(executedAgentIds, equals(['slow-agent', 'next-agent']));
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

      test('does not resurrect a drain-owned superseded manual wake', () {
        fakeAsync((async) {
          final policyLookupGate = Completer<AgentDomainEntity?>();
          final executedRunKeys = <String>[];
          final completions = <WakeRunCompletion>[];
          when(() => mockRepository.getEntity('manual-agent')).thenAnswer(
            (_) => policyLookupGate.future,
          );
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            maxConcurrentWakes: () => 1,
            wakeExecutor: (agentId, runKey, triggers, threadId) {
              executedRunKeys.add(runKey);
              return Future.value();
            },
          );
          final completionSub = orchestrator.runCompletions.listen(
            completions.add,
          );

          final oldRunKey = orchestrator.enqueueManualWake(
            agentId: 'manual-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(executedRunKeys, isEmpty);

          async.elapse(const Duration(minutes: 1));
          final newRunKey = orchestrator.enqueueManualWake(
            agentId: 'manual-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(
            completions,
            contains(
              isA<WakeRunCompletion>()
                  .having((item) => item.runKey, 'runKey', oldRunKey)
                  .having(
                    (item) => item.status,
                    'status',
                    WakeRunStatus.aborted,
                  ),
            ),
          );

          policyLookupGate.complete(null);
          async.flushMicrotasks();
          expect(executedRunKeys, equals([newRunKey]));
          expect(executedRunKeys, isNot(contains(oldRunKey)));

          completionSub.cancel();
          async.flushMicrotasks();
        });
      });

      test('cancels drain-owned automation before policy lookup completes', () {
        fakeAsync((async) {
          final policyLookupGate = Completer<AgentDomainEntity?>();
          final executedRunKeys = <String>[];
          final completions = <WakeRunCompletion>[];
          when(() => mockRepository.getEntity('automation-agent')).thenAnswer(
            (_) => policyLookupGate.future,
          );
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            maxConcurrentWakes: () => 1,
            wakeExecutor: (agentId, runKey, triggers, threadId) {
              executedRunKeys.add(runKey);
              return Future.value();
            },
          );
          final completionSub = orchestrator.runCompletions.listen(
            completions.add,
          );
          final job = WakeJob(
            runKey: 'owned-automation-run',
            agentId: 'automation-agent',
            reason: WakeReason.subscription.name,
            initiator: WakeInitiator.automation,
            triggerTokens: const {'project-1'},
            createdAt: DateTime(2024, 3, 15),
          );

          queue.enqueue(job);
          unawaited(orchestrator.processNext());
          async.flushMicrotasks();
          expect(executedRunKeys, isEmpty);

          orchestrator.cancelPendingAutomaticWakes(job.agentId);
          async.flushMicrotasks();
          expect(
            completions,
            contains(
              isA<WakeRunCompletion>()
                  .having((item) => item.runKey, 'runKey', job.runKey)
                  .having(
                    (item) => item.status,
                    'status',
                    WakeRunStatus.aborted,
                  ),
            ),
          );

          policyLookupGate.complete(null);
          async.flushMicrotasks();
          expect(executedRunKeys, isEmpty);
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          completionSub.cancel();
          async.flushMicrotasks();
        });
      });

      test('cancels only the matching drain-owned workspace', () {
        fakeAsync((async) {
          final policyLookupGate = Completer<AgentDomainEntity?>();
          final executedRunKeys = <String>[];
          final completions = <WakeRunCompletion>[];
          when(() => mockRepository.getEntity('workspace-agent')).thenAnswer(
            (_) => policyLookupGate.future,
          );
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            maxConcurrentWakes: () => 1,
            wakeExecutor: (agentId, runKey, triggers, threadId) {
              executedRunKeys.add(runKey);
              return Future.value();
            },
          );
          final completionSub = orchestrator.runCompletions.listen(
            completions.add,
          );
          final job = WakeJob(
            runKey: 'owned-workspace-run',
            agentId: 'workspace-agent',
            workspaceKey: 'workspace-a',
            reason: WakeReason.reanalysis.name,
            initiator: WakeInitiator.user,
            triggerTokens: const {},
            createdAt: DateTime(2024, 3, 15),
          );

          queue.enqueue(job);
          unawaited(orchestrator.processNext());
          async.flushMicrotasks();
          expect(executedRunKeys, isEmpty);

          final removed = orchestrator.cancelPendingWakes(
            job.agentId,
            workspaceKey: job.workspaceKey,
          );
          async.flushMicrotasks();
          expect(removed.map((item) => item.runKey), equals([job.runKey]));
          expect(
            completions,
            contains(
              isA<WakeRunCompletion>()
                  .having((item) => item.runKey, 'runKey', job.runKey)
                  .having(
                    (item) => item.status,
                    'status',
                    WakeRunStatus.aborted,
                  ),
            ),
          );

          policyLookupGate.complete(null);
          async.flushMicrotasks();
          expect(executedRunKeys, isEmpty);

          completionSub.cancel();
          async.flushMicrotasks();
        });
      });

      test('aborts a persisted handoff cancelled while queued', () {
        fakeAsync((async) {
          final finalPolicyGate = Completer<AgentDomainEntity?>();
          final replacementExecutionGate =
              Completer<Map<String, VectorClock>?>();
          final executedAgentIds = <String>[];
          final completions = <WakeRunCompletion>[];
          var handoffPolicyReads = 0;
          when(() => mockRepository.getEntity(any())).thenAnswer((call) {
            final agentId = call.positionalArguments.first as String;
            if (agentId == 'persisted-handoff-agent' &&
                ++handoffPolicyReads == 2) {
              return finalPolicyGate.future;
            }
            return Future.value();
          });
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            maxConcurrentWakes: () => 1,
            wakeExecutor: (agentId, runKey, triggers, threadId) {
              executedAgentIds.add(agentId);
              if (agentId == 'replacement-agent') {
                return replacementExecutionGate.future;
              }
              return Future.value();
            },
          );
          final completionSub = orchestrator.runCompletions.listen(
            completions.add,
          );

          final oldRunKey = orchestrator.enqueueManualWake(
            agentId: 'persisted-handoff-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(handoffPolicyReads, 2);
          expect(executedAgentIds, isEmpty);

          async.elapse(const Duration(minutes: 13));
          orchestrator.enqueueManualWake(
            agentId: 'replacement-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(executedAgentIds, equals(['replacement-agent']));

          finalPolicyGate.complete(null);
          async.flushMicrotasks();
          expect(queue.hasQueuedJobFor('persisted-handoff-agent'), isTrue);

          final removed = orchestrator.cancelPendingWakes(
            'persisted-handoff-agent',
            allWorkspaces: true,
          );
          async.flushMicrotasks();
          expect(removed.map((job) => job.runKey), equals([oldRunKey]));
          expect(
            completions,
            contains(
              isA<WakeRunCompletion>()
                  .having((item) => item.runKey, 'runKey', oldRunKey)
                  .having(
                    (item) => item.status,
                    'status',
                    WakeRunStatus.aborted,
                  ),
            ),
          );
          verify(
            () => mockRepository.updateWakeRunStatus(
              oldRunKey,
              WakeRunStatus.aborted.name,
              completedAt: any(named: 'completedAt'),
              errorMessage: 'wake cancelled before execution',
            ),
          ).called(1);
          verify(
            () => mockRepository.insertWakeRun(
              entry: any(
                named: 'entry',
                that: isA<WakeRunLogData>().having(
                  (entry) => entry.runKey,
                  'runKey',
                  oldRunKey,
                ),
              ),
            ),
          ).called(1);

          replacementExecutionGate.complete(null);
          completionSub.cancel();
          async.flushMicrotasks();
        });
      });

      test('discards a superseded wake after stale acquisition', () {
        fakeAsync((async) {
          final acquisitionGate = Completer<void>();
          final executedRunKeys = <String>[];
          runner = _AcquisitionGatedWakeRunner(
            gatedAgentId: 'acquisition-agent',
            gate: acquisitionGate,
          );
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            maxConcurrentWakes: () => 1,
            wakeExecutor: (agentId, runKey, triggers, threadId) {
              executedRunKeys.add(runKey);
              return Future.value();
            },
          );

          final oldRunKey = orchestrator.enqueueManualWake(
            agentId: 'acquisition-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(runner.isRunning('acquisition-agent'), isTrue);
          expect(executedRunKeys, isEmpty);

          async.elapse(const Duration(minutes: 13));
          final newRunKey = orchestrator.enqueueManualWake(
            agentId: 'acquisition-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(executedRunKeys, isEmpty);

          acquisitionGate.complete();
          async.flushMicrotasks();
          expect(executedRunKeys, equals([newRunKey]));
          expect(executedRunKeys, isNot(contains(oldRunKey)));
        });
      });

      test('discards a superseded wake after a stale content gate', () {
        fakeAsync((async) {
          final contentGate = Completer<bool>();
          final executedRunKeys = <String>[];
          final contentState = makeTestState(
            id: 'state-content-cancel-agent',
            agentId: 'content-cancel-agent',
            awaitingContent: true,
            slots: const AgentSlots(activeTaskId: 'task-content-cancel'),
          );
          when(() => mockRepository.getAgentState(any())).thenAnswer((call) {
            final agentId = call.positionalArguments.first as String;
            return Future.value(
              agentId == 'content-cancel-agent' ? contentState : null,
            );
          });
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            maxConcurrentWakes: () => 1,
            taskContentChecker: (taskId) => contentGate.future,
            wakeExecutor: (agentId, runKey, triggers, threadId) {
              executedRunKeys.add(runKey);
              return Future.value();
            },
          )..setAwaitingContent('content-cancel-agent', awaiting: true);

          final oldRunKey = orchestrator.enqueueManualWake(
            agentId: 'content-cancel-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(runner.isRunning('content-cancel-agent'), isTrue);
          expect(executedRunKeys, isEmpty);

          async.elapse(const Duration(minutes: 13));
          final newRunKey = orchestrator.enqueueManualWake(
            agentId: 'content-cancel-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(executedRunKeys, isEmpty);

          contentGate.complete(true);
          async.flushMicrotasks();
          expect(executedRunKeys, equals([newRunKey]));
          expect(executedRunKeys, isNot(contains(oldRunKey)));
        });
      });

      test('releases and requeues work superseded during acquisition', () {
        fakeAsync((async) {
          final acquisitionGate = Completer<void>();
          final contentGate = Completer<bool>();
          final replacementGate = Completer<Map<String, VectorClock>?>();
          final originalGate = Completer<Map<String, VectorClock>?>();
          final executedAgentIds = <String>[];
          final contentState = makeTestState(
            id: 'state-acquisition-agent',
            agentId: 'acquisition-agent',
            awaitingContent: true,
            slots: const AgentSlots(activeTaskId: 'task-acquisition'),
          );
          when(() => mockRepository.getAgentState(any())).thenAnswer((call) {
            final agentId = call.positionalArguments.first as String;
            return Future.value(
              agentId == 'acquisition-agent' ? contentState : null,
            );
          });
          runner = _AcquisitionGatedWakeRunner(
            gatedAgentId: 'acquisition-agent',
            gate: acquisitionGate,
          );
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            maxConcurrentWakes: () => 1,
            taskContentChecker: (taskId) => contentGate.future,
            wakeExecutor: (agentId, runKey, triggers, threadId) {
              executedAgentIds.add(agentId);
              if (agentId == 'acquisition-agent') return originalGate.future;
              return replacementGate.future;
            },
          )..setAwaitingContent('acquisition-agent', awaiting: true);

          orchestrator.enqueueManualWake(
            agentId: 'acquisition-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(runner.isRunning('acquisition-agent'), isTrue);
          expect(executedAgentIds, isEmpty);

          async.elapse(const Duration(minutes: 13));
          orchestrator.enqueueManualWake(
            agentId: 'replacement-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(executedAgentIds, isEmpty);

          acquisitionGate.complete();
          async.flushMicrotasks();
          expect(executedAgentIds, equals(['replacement-agent']));
          expect(runner.activeAgentIds, equals({'replacement-agent'}));

          replacementGate.complete(null);
          async.flushMicrotasks();
          expect(executedAgentIds, equals(['replacement-agent']));

          contentGate.complete(true);
          async.flushMicrotasks();
          expect(
            executedAgentIds,
            equals(['replacement-agent', 'acquisition-agent']),
          );

          originalGate.complete(null);
          async.flushMicrotasks();
        });
      });

      test('releases and requeues work superseded during content gating', () {
        fakeAsync((async) {
          final contentGate = Completer<bool>();
          final replacementGate = Completer<Map<String, VectorClock>?>();
          final originalGate = Completer<Map<String, VectorClock>?>();
          final executedAgentIds = <String>[];
          final contentState = makeTestState(
            id: 'state-content-agent',
            agentId: 'content-agent',
            awaitingContent: true,
            slots: const AgentSlots(activeTaskId: 'task-content'),
          );
          when(() => mockRepository.getAgentState(any())).thenAnswer((call) {
            final agentId = call.positionalArguments.first as String;
            return Future.value(
              agentId == 'content-agent' ? contentState : null,
            );
          });

          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            maxConcurrentWakes: () => 1,
            taskContentChecker: (taskId) => contentGate.future,
            wakeExecutor: (agentId, runKey, triggers, threadId) {
              executedAgentIds.add(agentId);
              if (agentId == 'content-agent') return originalGate.future;
              return replacementGate.future;
            },
          )..setAwaitingContent('content-agent', awaiting: true);

          orchestrator.enqueueManualWake(
            agentId: 'content-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(runner.isRunning('content-agent'), isTrue);
          expect(executedAgentIds, isEmpty);

          async.elapse(const Duration(minutes: 13));
          orchestrator.enqueueManualWake(
            agentId: 'replacement-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(executedAgentIds, equals(['replacement-agent']));

          contentGate.complete(true);
          async.flushMicrotasks();
          expect(executedAgentIds, equals(['replacement-agent']));

          replacementGate.complete(null);
          async.flushMicrotasks();
          expect(
            executedAgentIds,
            equals(['replacement-agent', 'content-agent']),
          );

          originalGate.complete(null);
          async.flushMicrotasks();
        });
      });

      test('resumes a persisted wake superseded during run insertion', () {
        fakeAsync((async) {
          final insertGate = Completer<void>();
          final replacementGate = Completer<Map<String, VectorClock>?>();
          final executedAgentIds = <String>[];
          final wakeStartAgentIds = <String>[];
          var insertAgentInsertCount = 0;
          when(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).thenAnswer((call) async {
            final entry = call.namedArguments[#entry] as WakeRunLogData;
            if (entry.agentId == 'insert-agent') {
              insertAgentInsertCount++;
              await insertGate.future;
            }
          });
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            maxConcurrentWakes: () => 1,
            onWakeStart: (agentId, runKey, threadId) async {
              wakeStartAgentIds.add(agentId);
            },
            wakeExecutor: (agentId, runKey, triggers, threadId) {
              executedAgentIds.add(agentId);
              return replacementGate.future;
            },
          );

          orchestrator.enqueueManualWake(
            agentId: 'insert-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(executedAgentIds, isEmpty);

          async.elapse(const Duration(minutes: 13));
          orchestrator.enqueueManualWake(
            agentId: 'replacement-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(executedAgentIds, equals(['replacement-agent']));
          expect(wakeStartAgentIds, equals(['replacement-agent']));

          insertGate.complete();
          async.flushMicrotasks();
          expect(executedAgentIds, equals(['replacement-agent']));
          expect(wakeStartAgentIds, equals(['replacement-agent']));

          replacementGate.complete(null);
          async.flushMicrotasks();
          expect(
            executedAgentIds,
            equals(['replacement-agent', 'insert-agent']),
          );
          expect(
            wakeStartAgentIds,
            equals(['replacement-agent', 'insert-agent']),
          );
          expect(insertAgentInsertCount, 1);
        });
      });

      test(
        'resumes a persisted wake superseded during the final policy read',
        () {
          fakeAsync((async) {
            final finalPolicyGate = Completer<AgentDomainEntity?>();
            final replacementGate = Completer<Map<String, VectorClock>?>();
            final executedAgentIds = <String>[];
            var oldPolicyReads = 0;
            var oldInsertCount = 0;
            when(() => mockRepository.getEntity(any())).thenAnswer((call) {
              final agentId = call.positionalArguments.first as String;
              if (agentId == 'final-policy-agent' && ++oldPolicyReads == 2) {
                return finalPolicyGate.future;
              }
              return Future.value();
            });
            when(
              () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
            ).thenAnswer((call) async {
              final entry = call.namedArguments[#entry] as WakeRunLogData;
              if (entry.agentId == 'final-policy-agent') oldInsertCount++;
            });
            orchestrator = WakeOrchestrator(
              repository: mockRepository,
              queue: queue,
              runner: runner,
              maxConcurrentWakes: () => 1,
              wakeExecutor: (agentId, runKey, triggers, threadId) {
                executedAgentIds.add(agentId);
                return replacementGate.future;
              },
            );

            orchestrator.enqueueManualWake(
              agentId: 'final-policy-agent',
              reason: 'manual',
            );
            async.flushMicrotasks();
            expect(oldPolicyReads, 2);
            expect(executedAgentIds, isEmpty);

            async.elapse(const Duration(minutes: 13));
            orchestrator.enqueueManualWake(
              agentId: 'replacement-agent',
              reason: 'manual',
            );
            async.flushMicrotasks();
            expect(executedAgentIds, equals(['replacement-agent']));

            finalPolicyGate.complete(null);
            async.flushMicrotasks();
            expect(executedAgentIds, equals(['replacement-agent']));

            replacementGate.complete(null);
            async.flushMicrotasks();
            expect(
              executedAgentIds,
              equals(['replacement-agent', 'final-policy-agent']),
            );
            expect(oldPolicyReads, 4);
            expect(oldInsertCount, 1);
          });
        },
      );

      test('aborts a manual wake superseded during run insertion', () {
        fakeAsync((async) {
          final insertGate = Completer<void>();
          final executedRunKeys = <String>[];
          String? oldRunKey;
          var oldInsertCount = 0;
          when(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).thenAnswer((call) async {
            final entry = call.namedArguments[#entry] as WakeRunLogData;
            if (entry.runKey == oldRunKey) {
              oldInsertCount++;
              await insertGate.future;
            }
          });
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            maxConcurrentWakes: () => 1,
            wakeExecutor: (agentId, runKey, triggers, threadId) {
              executedRunKeys.add(runKey);
              return Future.value();
            },
          );

          oldRunKey = orchestrator.enqueueManualWake(
            agentId: 'insert-cancel-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(oldInsertCount, 1);
          expect(executedRunKeys, isEmpty);

          async.elapse(const Duration(milliseconds: 1));
          final newRunKey = orchestrator.enqueueManualWake(
            agentId: 'insert-cancel-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(executedRunKeys, isEmpty);

          insertGate.complete();
          async.flushMicrotasks();
          expect(executedRunKeys, equals([newRunKey]));
          expect(executedRunKeys, isNot(contains(oldRunKey)));
          verify(
            () => mockRepository.updateWakeRunStatus(
              oldRunKey!,
              WakeRunStatus.aborted.name,
              completedAt: any(named: 'completedAt'),
              errorMessage: 'wake superseded by a newer manual request',
            ),
          ).called(1);
        });
      });

      test('keeps an aborted outcome when cancelled insertion fails', () {
        fakeAsync((async) {
          final insertGate = Completer<void>();
          final executedRunKeys = <String>[];
          final completions = <WakeRunCompletion>[];
          String? oldRunKey;
          when(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).thenAnswer((call) async {
            final entry = call.namedArguments[#entry] as WakeRunLogData;
            if (entry.runKey == oldRunKey) {
              await insertGate.future;
              throw StateError('insert failed after cancellation');
            }
          });
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            maxConcurrentWakes: () => 1,
            wakeExecutor: (agentId, runKey, triggers, threadId) {
              executedRunKeys.add(runKey);
              return Future.value();
            },
          );
          final completionSub = orchestrator.runCompletions.listen(
            completions.add,
          );

          oldRunKey = orchestrator.enqueueManualWake(
            agentId: 'failed-insert-cancel-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(executedRunKeys, isEmpty);

          async.elapse(const Duration(milliseconds: 1));
          final newRunKey = orchestrator.enqueueManualWake(
            agentId: 'failed-insert-cancel-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          insertGate.complete();
          async.flushMicrotasks();

          expect(executedRunKeys, equals([newRunKey]));
          final oldCompletions = completions
              .where((completion) => completion.runKey == oldRunKey)
              .toList();
          expect(oldCompletions, hasLength(1));
          expect(oldCompletions.single.status, WakeRunStatus.aborted);

          completionSub.cancel();
          async.flushMicrotasks();
        });
      });

      test('aborts a manual wake superseded during final policy read', () {
        fakeAsync((async) {
          final finalPolicyGate = Completer<AgentDomainEntity?>();
          final executedRunKeys = <String>[];
          var oldPolicyReads = 0;
          when(() => mockRepository.getEntity(any())).thenAnswer((call) {
            final agentId = call.positionalArguments.first as String;
            if (agentId == 'final-policy-cancel-agent' &&
                ++oldPolicyReads == 2) {
              return finalPolicyGate.future;
            }
            return Future.value();
          });
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            maxConcurrentWakes: () => 1,
            wakeExecutor: (agentId, runKey, triggers, threadId) {
              executedRunKeys.add(runKey);
              return Future.value();
            },
          );

          final oldRunKey = orchestrator.enqueueManualWake(
            agentId: 'final-policy-cancel-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(oldPolicyReads, 2);
          expect(executedRunKeys, isEmpty);

          async.elapse(const Duration(milliseconds: 1));
          final newRunKey = orchestrator.enqueueManualWake(
            agentId: 'final-policy-cancel-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(executedRunKeys, isEmpty);

          finalPolicyGate.complete(null);
          async.flushMicrotasks();
          expect(executedRunKeys, equals([newRunKey]));
          expect(executedRunKeys, isNot(contains(oldRunKey)));
          verify(
            () => mockRepository.updateWakeRunStatus(
              oldRunKey,
              WakeRunStatus.aborted.name,
              completedAt: any(named: 'completedAt'),
              errorMessage: 'wake superseded by a newer manual request',
            ),
          ).called(1);
        });
      });

      test('aborts a persisted continuation rejected by current policy', () {
        fakeAsync((async) {
          final finalPolicyGate = Completer<AgentDomainEntity?>();
          final replacementGate = Completer<Map<String, VectorClock>?>();
          final executedAgentIds = <String>[];
          final completions = <WakeRunCompletion>[];
          final enabledIdentity = makeTestIdentity(
            id: 'persisted-policy-agent',
            agentId: 'persisted-policy-agent',
            kind: 'project_agent',
            config: const AgentConfig(automaticUpdatesEnabled: true),
          );
          final disabledIdentity = makeTestIdentity(
            id: 'persisted-policy-agent',
            agentId: 'persisted-policy-agent',
            kind: 'project_agent',
            config: const AgentConfig(automaticUpdatesEnabled: false),
          );
          var policyReads = 0;
          var oldInsertCount = 0;
          when(() => mockRepository.getEntity(any())).thenAnswer((call) {
            final agentId = call.positionalArguments.first as String;
            if (agentId != 'persisted-policy-agent') return Future.value();
            policyReads++;
            if (policyReads == 2) return finalPolicyGate.future;
            return Future.value(
              policyReads < 3 ? enabledIdentity : disabledIdentity,
            );
          });
          when(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).thenAnswer((call) async {
            final entry = call.namedArguments[#entry] as WakeRunLogData;
            if (entry.agentId == 'persisted-policy-agent') oldInsertCount++;
          });
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            maxConcurrentWakes: () => 1,
            wakeExecutor: (agentId, runKey, triggers, threadId) {
              executedAgentIds.add(agentId);
              return replacementGate.future;
            },
          );
          final completionSub = orchestrator.runCompletions.listen(
            completions.add,
          );

          queue.enqueue(
            WakeJob(
              runKey: 'persisted-policy-run',
              agentId: 'persisted-policy-agent',
              reason: WakeReason.scheduled.name,
              initiator: WakeInitiator.automation,
              triggerTokens: const {},
              createdAt: DateTime(2024, 3, 15),
            ),
          );
          unawaited(orchestrator.processNext());
          async.flushMicrotasks();
          expect(policyReads, 2);
          expect(executedAgentIds, isEmpty);

          async.elapse(const Duration(minutes: 13));
          orchestrator.enqueueManualWake(
            agentId: 'replacement-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(executedAgentIds, equals(['replacement-agent']));

          finalPolicyGate.complete(enabledIdentity);
          async.flushMicrotasks();
          expect(executedAgentIds, equals(['replacement-agent']));

          replacementGate.complete(null);
          async.flushMicrotasks();
          expect(executedAgentIds, equals(['replacement-agent']));
          expect(policyReads, 3);
          expect(oldInsertCount, 1);
          expect(
            completions,
            contains(
              isA<WakeRunCompletion>()
                  .having(
                    (item) => item.runKey,
                    'runKey',
                    'persisted-policy-run',
                  )
                  .having(
                    (item) => item.status,
                    'status',
                    WakeRunStatus.aborted,
                  ),
            ),
          );
          verify(
            () => mockRepository.updateWakeRunStatus(
              'persisted-policy-run',
              WakeRunStatus.aborted.name,
              completedAt: any(named: 'completedAt'),
              errorMessage: 'wake dropped by current automation policy',
            ),
          ).called(1);

          completionSub.cancel();
          async.flushMicrotasks();
        });
      });

      test('deduplicates restoration while a stale handoff is owned', () {
        fakeAsync((async) {
          final policyGate = Completer<AgentDomainEntity?>();
          final executedAgentIds = <String>[];
          var restoredInsertCount = 0;
          when(() => mockRepository.getEntity(any())).thenAnswer((call) {
            final agentId = call.positionalArguments.first as String;
            if (agentId == 'restored-agent') return policyGate.future;
            return Future.value();
          });
          when(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).thenAnswer((call) async {
            final entry = call.namedArguments[#entry] as WakeRunLogData;
            if (entry.agentId == 'restored-agent') restoredInsertCount++;
          });
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            maxConcurrentWakes: () => 1,
            wakeExecutor: (agentId, runKey, triggers, threadId) {
              executedAgentIds.add(agentId);
              return Future.value();
            },
          );
          final dueAt = clock.now().subtract(const Duration(minutes: 1));
          const reasonId = 'restore-dedupe';
          final restoredRunKey = RunKeyFactory.forSubscription(
            agentId: 'restored-agent',
            subscriptionId: reasonId,
            batchTokens: const {},
            wakeCounter: 0,
            timestamp: dueAt,
          );

          orchestrator.restorePendingWake(
            agentId: 'restored-agent',
            dueAt: dueAt,
            reasonId: reasonId,
          );
          async.flushMicrotasks();
          expect(executedAgentIds, isEmpty);

          async.elapse(const Duration(minutes: 13));
          orchestrator.enqueueManualWake(
            agentId: 'replacement-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(executedAgentIds, equals(['replacement-agent']));

          expect(
            queue.enqueue(
              WakeJob(
                runKey: restoredRunKey,
                agentId: 'restored-agent',
                reason: WakeReason.subscription.name,
                triggerTokens: const {},
                reasonId: reasonId,
                createdAt: dueAt,
              ),
            ),
            isFalse,
          );
          policyGate.complete(null);
          async.flushMicrotasks();

          expect(
            executedAgentIds,
            equals(['replacement-agent', 'restored-agent']),
          );
          expect(restoredInsertCount, 1);
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

      test('healthy concurrent wakes do not hide a stalled lease', () {
        fakeAsync((async) {
          final abortedStatusGate = Completer<void>();
          final executedAgentIds = <String>[];
          String? firstStuckRunKey;
          var stuckExecutionCount = 0;
          when(
            () => mockRepository.updateWakeRunStatus(
              any(),
              any(),
              completedAt: any(named: 'completedAt'),
              errorMessage: any(named: 'errorMessage'),
            ),
          ).thenAnswer((call) async {
            final runKey = call.positionalArguments.first as String;
            final status = call.positionalArguments[1] as String;
            if (runKey == firstStuckRunKey &&
                status == WakeRunStatus.aborted.name) {
              await abortedStatusGate.future;
            }
          });
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            maxConcurrentWakes: () => 2,
            wakeExecutor: (agentId, runKey, triggers, threadId) {
              executedAgentIds.add(agentId);
              if (agentId == 'stuck-agent' && stuckExecutionCount++ == 0) {
                return Completer<Map<String, VectorClock>?>().future;
              }
              return Future.value();
            },
          );

          firstStuckRunKey = orchestrator.enqueueManualWake(
            agentId: 'stuck-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(executedAgentIds, equals(['stuck-agent']));

          async
            ..elapse(WakeOrchestrator.wakeRunMaxDuration)
            ..flushMicrotasks();
          orchestrator.enqueueManualWake(
            agentId: 'healthy-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(
            executedAgentIds,
            equals(['stuck-agent', 'healthy-agent']),
          );

          // The healthy completion refreshed generation-wide progress only
          // two minutes ago, but the stuck lease has made no progress for
          // more than the full twelve-minute recovery window.
          async.elapse(const Duration(minutes: 2, milliseconds: 1));
          orchestrator.enqueueManualWake(
            agentId: 'stuck-agent',
            reason: 'manual',
          );
          async.flushMicrotasks();
          expect(
            executedAgentIds,
            equals(['stuck-agent', 'healthy-agent', 'stuck-agent']),
          );

          abortedStatusGate.complete();
          async.flushMicrotasks();
        });
      });
    });
  });
}
