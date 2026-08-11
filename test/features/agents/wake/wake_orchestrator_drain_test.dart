import 'package:glados/glados.dart' as glados;

import 'wake_orchestrator_test_harness.dart';

void main() {
  configureWakeOrchestratorTestSuite();

  // Owns drain execution, concurrency, completion events, and pre-wake hooks.
  group('WakeOrchestrator', () {
    group('processNext', () {
      test(
        'automatic task-agent wake is dropped when updates are off',
        () async {
          when(() => mockRepository.getEntity('agent-1')).thenAnswer(
            (_) async => makeTestIdentity(
              id: 'agent-1',
              agentId: 'agent-1',
              config: const AgentConfig(automaticUpdatesEnabled: false),
            ),
          );
          var executions = 0;
          orchestrator.wakeExecutor = (_, _, _, _) async {
            executions++;
            return null;
          };
          queue.enqueue(
            WakeJob(
              runKey: 'automatic-off',
              agentId: 'agent-1',
              reason: WakeReason.subscription.name,
              initiator: WakeInitiator.automation,
              triggerTokens: const {'task-1'},
              createdAt: DateTime(2024, 3, 15),
            ),
          );

          await orchestrator.processNext();

          expect(executions, 0);
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );
        },
      );

      test(
        'user task-agent wake remains allowed when updates are off',
        () async {
          when(() => mockRepository.getEntity('agent-1')).thenAnswer(
            (_) async => makeTestIdentity(
              id: 'agent-1',
              agentId: 'agent-1',
              config: const AgentConfig(automaticUpdatesEnabled: false),
            ),
          );
          var executions = 0;
          orchestrator.wakeExecutor = (_, _, _, _) async {
            executions++;
            return null;
          };
          queue.enqueue(
            WakeJob(
              runKey: 'manual-off',
              agentId: 'agent-1',
              reason: WakeReason.reanalysis.name,
              initiator: WakeInitiator.user,
              triggerTokens: const {},
              createdAt: DateTime(2024, 3, 15),
            ),
          );

          await orchestrator.processNext();

          expect(executions, 1);
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);
        },
      );

      test(
        'repository policy lookup failure does not abort the wake',
        () async {
          when(
            () => mockRepository.getEntity('agent-1'),
          ).thenThrow(StateError('temporary read failure'));
          var executions = 0;
          orchestrator.wakeExecutor = (_, _, _, _) async {
            executions++;
            return null;
          };
          queue.enqueue(
            WakeJob(
              runKey: 'policy-read-failure',
              agentId: 'agent-1',
              reason: WakeReason.reanalysis.name,
              initiator: WakeInitiator.user,
              triggerTokens: const {},
              createdAt: DateTime(2024, 3, 15),
            ),
          );

          await orchestrator.processNext();

          expect(executions, 1);
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);
        },
      );

      test('disabled setup drops user task-agent wake too', () async {
        when(() => mockRepository.getEntity('agent-1')).thenAnswer(
          (_) async => makeTestIdentity(
            id: 'agent-1',
            agentId: 'agent-1',
            lifecycle: AgentLifecycle.dormant,
            config: const AgentConfig(
              inferenceSetup: AgentInferenceSetup(
                mode: AgentInferenceSetupMode.disabled,
                origin: AgentInferenceSetupOrigin.user,
              ),
            ),
          ),
        );
        orchestrator.wakeExecutor = noOpExecutor;
        queue.enqueue(
          WakeJob(
            runKey: 'manual-disabled',
            agentId: 'agent-1',
            reason: WakeReason.reanalysis.name,
            initiator: WakeInitiator.user,
            triggerTokens: const {},
            createdAt: DateTime(2024, 3, 15),
          ),
        );

        await orchestrator.processNext();

        verifyNever(
          () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
        );
      });

      test('a destroyed goal agent cannot execute a queued wake', () async {
        when(() => mockRepository.getEntity('goal-1')).thenAnswer(
          (_) async => makeTestIdentity(
            id: 'goal-1',
            agentId: 'goal-1',
            kind: 'goal_agent',
            lifecycle: AgentLifecycle.destroyed,
          ),
        );
        var executions = 0;
        orchestrator.wakeExecutor = (_, _, _, _) async {
          executions++;
          return null;
        };
        queue.enqueue(
          WakeJob(
            runKey: 'destroyed-goal',
            agentId: 'goal-1',
            reason: WakeReason.userMessage.name,
            initiator: WakeInitiator.user,
            triggerTokens: const {'goal-chat-message:message-1'},
            createdAt: DateTime(2024, 3, 15),
          ),
        );

        await orchestrator.processNext();

        expect(executions, 0);
        verifyNever(
          () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
        );
      });

      glados.Glados(
        glados.any.wakeDrainScenario,
        glados.ExploreConfig(numRuns: 180),
      ).test(
        'matches generated drain persistence, content gates, and requeueing',
        (scenario) {
          fakeAsync((async) {
            final generatedRepository = MockAgentRepository();
            final generatedQueue = WakeQueue();
            final generatedRunner = WakeRunner();
            final entries = <WakeRunLogData>[];
            final statusUpdates = <ObservedWakeDrainStatusUpdate>[];
            final executions = <ObservedWakeDrainExecution>[];
            final upsertedStates = <AgentStateEntity>[];
            final stateByAgent = <String, AgentStateEntity>{};
            final contentSlotByTaskId =
                <String, GeneratedWakeDrainContentSlot>{};

            for (final slot in GeneratedWakeDrainAgentSlot.values) {
              final contentSlot = scenario.contentFor(slot);
              if (contentSlot == GeneratedWakeDrainContentSlot.notAwaiting) {
                continue;
              }

              final taskId =
                  contentSlot == GeneratedWakeDrainContentSlot.awaitingNoTask
                  ? null
                  : generatedWakeDrainTaskId(slot);
              if (taskId != null) {
                contentSlotByTaskId[taskId] = contentSlot;
              }
              final agentId = generatedWakeDrainAgentId(slot);
              stateByAgent[agentId] = makeTestState(
                id: 'generated-drain-state-${slot.name}',
                agentId: agentId,
                awaitingContent: true,
                slots: AgentSlots(activeTaskId: taskId),
              );
            }

            when(
              () => generatedRepository.getAgentState(any()),
            ).thenAnswer((invocation) async {
              final agentId = invocation.positionalArguments.single as String;
              return stateByAgent[agentId];
            });
            when(
              () => generatedRepository.getEntity(any()),
            ).thenAnswer((_) async => null);
            when(
              () => generatedRepository.upsertEntity(any()),
            ).thenAnswer((invocation) async {
              final entity =
                  invocation.positionalArguments.single as AgentDomainEntity;
              if (entity is AgentStateEntity) {
                stateByAgent[entity.agentId] = entity;
                upsertedStates.add(entity);
              }
            });
            when(
              () => generatedRepository.insertWakeRun(
                entry: any(named: 'entry'),
              ),
            ).thenAnswer((invocation) async {
              final entry = invocation.namedArguments[#entry] as WakeRunLogData;
              entries.add(entry);
              final spec = scenario.specForRunKey(entry.runKey)!;
              if (spec.insertThrows) {
                throw StateError('generated insert failure');
              }
            });
            when(
              () => generatedRepository.updateWakeRunStatus(
                any(),
                any(),
                completedAt: any(named: 'completedAt'),
                errorMessage: any(named: 'errorMessage'),
              ),
            ).thenAnswer((invocation) async {
              statusUpdates.add(
                ObservedWakeDrainStatusUpdate(
                  runKey: invocation.positionalArguments[0] as String,
                  status: invocation.positionalArguments[1] as String,
                  errorMessage:
                      invocation.namedArguments[#errorMessage] as String?,
                ),
              );
            });

            final generatedOrchestrator = WakeOrchestrator(
              repository: generatedRepository,
              queue: generatedQueue,
              runner: generatedRunner,
              taskContentChecker: (taskId) async {
                final contentSlot = contentSlotByTaskId[taskId];
                if (contentSlot ==
                    GeneratedWakeDrainContentSlot.checkerThrows) {
                  throw StateError('generated content check failure');
                }
                return contentSlot ==
                    GeneratedWakeDrainContentSlot.awaitingHasContent;
              },
              wakeExecutor: (agentId, runKey, triggers, threadId) async {
                executions.add(
                  ObservedWakeDrainExecution(
                    agentId: agentId,
                    runKey: runKey,
                    triggers: Set<String>.from(triggers),
                    threadId: threadId,
                  ),
                );
                final spec = scenario.specForRunKey(runKey)!;
                if (spec.executorThrows) {
                  throw StateError('generated executor failure');
                }
                if (spec.executorMutates) {
                  return {
                    'generated-mutation-$runKey': const VectorClock({
                      'generated-node': 1,
                    }),
                  };
                }
                return null;
              },
            );

            for (var index = 0; index < scenario.jobs.length; index += 1) {
              generatedQueue.enqueue(scenario.jobs[index].job(index));
            }

            final busyAgentId = scenario.busyAgentId;
            if (busyAgentId != null) {
              generatedRunner.tryAcquire(busyAgentId);
              async.flushMicrotasks();
            }

            generatedOrchestrator.processNext();
            async.flushMicrotasks();

            final expected = scenario.expectedModel();
            expect(
              entries.map((entry) => entry.runKey).toList(),
              unorderedEquals(expected.insertRunKeys),
              reason: '$scenario',
            );
            for (final entry in entries) {
              final spec = scenario.specForRunKey(entry.runKey)!;
              final index = int.parse(entry.runKey.split('-').last);
              expect(entry.agentId, spec.agentId, reason: '$scenario');
              expect(entry.reason, spec.reason, reason: '$scenario');
              expect(entry.threadId, entry.runKey, reason: '$scenario');
              expect(
                entry.createdAt,
                generatedWakeDrainCreatedAt(index),
                reason: '$scenario',
              );
              expect(entry.status, WakeRunStatus.running.name);
            }

            expect(
              executions.map((execution) => execution.runKey).toList(),
              unorderedEquals(expected.executedRunKeys),
              reason: '$scenario',
            );
            for (final execution in executions) {
              final spec = scenario.specForRunKey(execution.runKey)!;
              final index = int.parse(execution.runKey.split('-').last);
              expect(execution.agentId, spec.agentId, reason: '$scenario');
              expect(execution.threadId, execution.runKey, reason: '$scenario');
              expect(
                execution.triggers,
                spec.job(index).triggerTokens,
                reason: '$scenario',
              );
            }

            expect(statusUpdates, hasLength(expected.statusUpdates.length));
            final expectedStatusByRunKey = {
              for (final update in expected.statusUpdates)
                update.runKey: update,
            };
            for (final actual in statusUpdates) {
              final expectedUpdate = expectedStatusByRunKey[actual.runKey]!;
              expect(actual.runKey, expectedUpdate.runKey, reason: '$scenario');
              expect(actual.status, expectedUpdate.status, reason: '$scenario');
              if (expectedUpdate.status == WakeRunStatus.failed.name) {
                expect(actual.errorMessage, isNotNull, reason: '$scenario');
              } else {
                expect(actual.errorMessage, isNull, reason: '$scenario');
              }
            }

            final remainingRunKeys = <String>[];
            while (!generatedQueue.isEmpty) {
              remainingRunKeys.add(generatedQueue.dequeue()!.runKey);
            }
            expect(
              remainingRunKeys,
              expected.requeuedRunKeys,
              reason: '$scenario',
            );

            for (final agentId in expected.clearedAgentIds) {
              expect(
                stateByAgent[agentId]?.awaitingContent,
                isFalse,
                reason: '$scenario',
              );
              expect(
                upsertedStates.any(
                  (state) => state.agentId == agentId && !state.awaitingContent,
                ),
                isTrue,
                reason: '$scenario',
              );
            }

            for (final slot in GeneratedWakeDrainAgentSlot.values) {
              final agentId = generatedWakeDrainAgentId(slot);
              expect(
                generatedRunner.isRunning(agentId),
                agentId == busyAgentId,
                reason: '$scenario',
              );
            }

            generatedOrchestrator.stop();
            async.flushMicrotasks();
            if (busyAgentId != null) {
              generatedRunner.release(busyAgentId);
            }
          });
        },
        tags: 'glados',
      );

      test('does nothing when queue is empty', () {
        fakeAsync((async) {
          orchestrator.processNext();
          async.flushMicrotasks();

          // No repository calls should have been made
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );
        });
      });

      test('acquires runner lock, persists run, and releases lock', () {
        fakeAsync((async) {
          when(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).thenAnswer((_) async {});

          queue.enqueue(makeJob(reasonId: 'sub-1'));

          orchestrator.processNext();
          async.flushMicrotasks();

          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          // Lock should be released after processNext completes
          expect(runner.isRunning('agent-1'), isFalse);
        });
      });

      test('re-enqueues job when agent is already running', () {
        fakeAsync((async) {
          // Pre-lock the agent
          runner.tryAcquire('agent-1');
          async.flushMicrotasks();

          queue.enqueue(makeJob());

          orchestrator.processNext();
          async.flushMicrotasks();

          // Job should be back in the queue (deferred by the loop)
          expect(queue.isEmpty, isFalse);
          expect(queue.dequeue()!.runKey, 'rk-1');

          // No DB call since we couldn't acquire
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          runner.release('agent-1');
        });
      });

      test('persisted entry has correct fields from job', () {
        // Fix the clock so the entry's startedAt (stamped via clock.now() in
        // _executeJob) is deterministic and can be asserted exactly, rather
        // than via a presence-only isNotNull check.
        final startedAt = DateTime(2024, 3, 15, 11);
        withClock(Clock.fixed(startedAt), () {
          fakeAsync((async) {
            final capturedEntries = stubInsertCapture(mockRepository);

            final createdAt = DateTime(2024, 3, 15, 10, 30);
            queue.enqueue(
              makeJob(
                runKey: 'rk-test',
                agentId: 'agent-42',
                reason: 'timer',
                reasonId: 'timer-7',
                createdAt: createdAt,
              ),
            );

            orchestrator.processNext();
            async.flushMicrotasks();

            expect(capturedEntries, hasLength(1));
            final capturedEntry = capturedEntries.first;
            expect(capturedEntry.runKey, 'rk-test');
            expect(capturedEntry.agentId, 'agent-42');
            expect(capturedEntry.reason, 'timer');
            expect(capturedEntry.reasonId, 'timer-7');
            expect(capturedEntry.threadId, 'rk-test');
            expect(capturedEntry.status, 'running');
            expect(capturedEntry.createdAt, createdAt);
            // startedAt is stamped from the (fixed) execution clock — not just
            // present, but exactly the wall-clock at job execution.
            expect(capturedEntry.startedAt, startedAt);
          });
        });
      });

      test('marks run as failed when wakeExecutor is null', () {
        fakeAsync((async) {
          // orchestrator created without wakeExecutor (default null)
          queue.enqueue(makeJob(runKey: 'rk-null'));

          orchestrator.processNext();
          async.flushMicrotasks();

          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          verify(
            () => mockRepository.updateWakeRunStatus(
              'rk-null',
              'failed',
              errorMessage: 'No wake executor registered',
            ),
          ).called(1);

          expect(runner.isRunning('agent-1'), isFalse);
        });
      });

      test('processes multiple agents in one processNext loop', () {
        fakeAsync((async) {
          orchestrator.wakeExecutor = noOpExecutor;

          queue
            ..enqueue(makeJob())
            ..enqueue(
              makeJob(
                runKey: 'rk-2',
                agentId: 'agent-2',
                triggerTokens: {'tok-b'},
              ),
            );

          orchestrator.processNext();
          async.flushMicrotasks();

          // Both jobs processed in one call — no starvation.
          final captured = captureWakeRuns(mockRepository);
          expect(captured.length, equals(2));
          expect(
            captured.map((e) => e.agentId).toSet(),
            containsAll(['agent-1', 'agent-2']),
          );
        });
      });

      test('runs three agents concurrently by default and queues a fourth', () {
        fakeAsync((async) {
          final gates = <String, Completer<Map<String, VectorClock>?>>{
            for (var index = 1; index <= 4; index++)
              'agent-$index': Completer<Map<String, VectorClock>?>(),
          };
          final started = <String>[];
          orchestrator.wakeExecutor = (agentId, runKey, triggers, threadId) {
            started.add(agentId);
            return gates[agentId]!.future;
          };
          for (var index = 1; index <= 4; index++) {
            queue.enqueue(
              makeJob(
                runKey: 'rk-$index',
                agentId: 'agent-$index',
                reason: 'test',
              ),
            );
          }

          unawaited(orchestrator.processNext());
          async.flushMicrotasks();

          expect(started, ['agent-1', 'agent-2', 'agent-3']);
          expect(runner.activeAgentIds, hasLength(3));
          expect(queue.length, 1);

          gates['agent-1']!.complete(null);
          async.flushMicrotasks();

          expect(started, ['agent-1', 'agent-2', 'agent-3', 'agent-4']);
          expect(runner.activeAgentIds, hasLength(3));

          for (final agentId in ['agent-2', 'agent-3', 'agent-4']) {
            gates[agentId]!.complete(null);
          }
          async.flushMicrotasks();
          expect(runner.activeAgentIds, isEmpty);
        });
      });

      test('configured concurrency one preserves sequential execution', () {
        fakeAsync((async) {
          final firstGate = Completer<Map<String, VectorClock>?>();
          final started = <String>[];
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            maxConcurrentWakes: () => 1,
            wakeExecutor: (agentId, runKey, triggers, threadId) {
              started.add(agentId);
              return agentId == 'agent-1' ? firstGate.future : Future.value();
            },
          );
          queue
            ..enqueue(makeJob(reason: 'test'))
            ..enqueue(
              makeJob(
                runKey: 'rk-2',
                agentId: 'agent-2',
                reason: 'test',
              ),
            );

          unawaited(orchestrator.processNext());
          async.flushMicrotasks();

          expect(started, ['agent-1']);
          expect(queue.length, 1);

          firstGate.complete(null);
          async.flushMicrotasks();

          expect(started, ['agent-1', 'agent-2']);
          expect(queue.isEmpty, isTrue);
        });
      });

      test('configured higher concurrency starts four agents together', () {
        fakeAsync((async) {
          final gates = <String, Completer<Map<String, VectorClock>?>>{
            for (var index = 1; index <= 4; index++)
              'agent-$index': Completer<Map<String, VectorClock>?>(),
          };
          final started = <String>[];
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            maxConcurrentWakes: () => 4,
            wakeExecutor: (agentId, runKey, triggers, threadId) {
              started.add(agentId);
              return gates[agentId]!.future;
            },
          );
          for (var index = 1; index <= 4; index++) {
            queue.enqueue(
              makeJob(
                runKey: 'rk-$index',
                agentId: 'agent-$index',
                reason: 'test',
              ),
            );
          }

          unawaited(orchestrator.processNext());
          async.flushMicrotasks();

          expect(started, ['agent-1', 'agent-2', 'agent-3', 'agent-4']);
          expect(runner.activeAgentIds, hasLength(4));
          expect(queue.isEmpty, isTrue);

          for (final gate in gates.values) {
            gate.complete(null);
          }
          async.flushMicrotasks();
          expect(runner.activeAgentIds, isEmpty);
        });
      });

      test('global concurrency keeps each agent single-flight', () {
        fakeAsync((async) {
          final firstAgentGate = Completer<Map<String, VectorClock>?>();
          final otherAgentGate = Completer<Map<String, VectorClock>?>();
          final startedRunKeys = <String>[];
          orchestrator.wakeExecutor = (agentId, runKey, triggers, threadId) {
            startedRunKeys.add(runKey);
            return switch (runKey) {
              'rk-1' => firstAgentGate.future,
              'rk-2' => Future.value(),
              _ => otherAgentGate.future,
            };
          };
          queue
            ..enqueue(makeJob(reason: 'test'))
            ..enqueue(
              makeJob(
                runKey: 'rk-2',
                reason: 'test',
              ),
            )
            ..enqueue(
              makeJob(
                runKey: 'rk-3',
                agentId: 'agent-2',
                reason: 'test',
              ),
            );

          unawaited(orchestrator.processNext());
          async.flushMicrotasks();

          expect(startedRunKeys, ['rk-1', 'rk-3']);
          expect(queue.length, 1);

          firstAgentGate.complete(null);
          async.flushMicrotasks();

          expect(startedRunKeys, ['rk-1', 'rk-3', 'rk-2']);
          otherAgentGate.complete(null);
          async.flushMicrotasks();
          expect(runner.activeAgentIds, isEmpty);
        });
      });

      test('requeues a job when its agent starts during policy lookup', () {
        fakeAsync((async) {
          final policyLookup = Completer<AgentDomainEntity?>();
          when(
            () => mockRepository.getEntity('agent-1'),
          ).thenAnswer((_) => policyLookup.future);
          var executions = 0;
          orchestrator.wakeExecutor = (agentId, runKey, triggers, threadId) {
            executions++;
            return Future.value();
          };
          queue.enqueue(makeJob(reason: 'test'));

          unawaited(orchestrator.processNext());
          async.flushMicrotasks();
          expect(queue.isEmpty, isTrue);

          var acquired = false;
          unawaited(
            runner.tryAcquire('agent-1').then((value) => acquired = value),
          );
          async.flushMicrotasks();
          expect(acquired, isTrue);

          policyLookup.complete(null);
          async.flushMicrotasks();

          expect(executions, 0);
          expect(queue.length, 1);
          expect(queue.dequeue()!.agentId, 'agent-1');
          runner.release('agent-1');
        });
      });

      test('defers a subscription throttled during policy lookup', () {
        fakeAsync((async) {
          final policyLookup = Completer<AgentDomainEntity?>();
          when(
            () => mockRepository.getEntity('agent-1'),
          ).thenAnswer((_) => policyLookup.future);
          var executions = 0;
          orchestrator.wakeExecutor = (agentId, runKey, triggers, threadId) {
            executions++;
            return Future.value();
          };
          queue.enqueue(
            makeJob(reason: WakeReason.subscription.name),
          );

          unawaited(orchestrator.processNext());
          async.flushMicrotasks();
          expect(queue.isEmpty, isTrue);

          orchestrator.setThrottleDeadline(
            'agent-1',
            clock.now().add(WakeOrchestrator.throttleWindow),
          );
          policyLookup.complete(null);
          async.flushMicrotasks();

          expect(executions, 0);
          expect(runner.isRunning('agent-1'), isFalse);
          expect(queue.length, 1);
          expect(queue.dequeue()!.agentId, 'agent-1');
        });
      });

      test('defers busy agent job and processes others', () {
        fakeAsync((async) {
          orchestrator.wakeExecutor = noOpExecutor;

          // Pre-lock agent-1
          runner.tryAcquire('agent-1');
          async.flushMicrotasks();

          queue
            ..enqueue(makeJob())
            ..enqueue(
              makeJob(
                runKey: 'rk-2',
                agentId: 'agent-2',
                triggerTokens: {'tok-b'},
              ),
            );

          orchestrator.processNext();
          async.flushMicrotasks();

          // Only agent-2 processed; agent-1 deferred back to queue.
          final captured = captureWakeRuns(mockRepository);
          expect(captured.length, equals(1));
          expect(captured.first.agentId, 'agent-2');

          // agent-1 job is still in queue
          expect(queue.isEmpty, isFalse);
          expect(queue.dequeue()!.agentId, 'agent-1');

          runner.release('agent-1');
        });
      });

      test('clears history only when queue fully drained', () {
        fakeAsync((async) {
          orchestrator.wakeExecutor = noOpExecutor;

          // Pre-lock agent-1 so its job gets deferred
          runner.tryAcquire('agent-1');
          async.flushMicrotasks();

          queue
            ..enqueue(makeJob())
            ..enqueue(
              makeJob(
                runKey: 'rk-2',
                agentId: 'agent-2',
                triggerTokens: {'tok-b'},
              ),
            );

          orchestrator.processNext();
          async.flushMicrotasks();

          // Queue is not empty (agent-1 deferred), so history not cleared.
          // Re-enqueueing rk-1 should fail (key still seen).
          final reEnqueued = queue.enqueue(makeJob());
          // The deferred job was re-enqueued internally, so rk-1 is already
          // in the queue. A second enqueue with the same key should be rejected.
          expect(reEnqueued, isFalse);

          runner.release('agent-1');
        });
      });

      test('clears mutation history when wake produces no mutations', () {
        fakeAsync((async) {
          // Pre-record mutations, executor returns null (no mutations)
          orchestrator
            ..recordMutatedEntities('agent-1', {
              'entity-1': const VectorClock({'node-1': 1}),
            })
            ..wakeExecutor = noOpExecutor;

          queue.enqueue(makeJob());

          orchestrator.processNext();
          async.flushMicrotasks();

          // Now entity-1 should no longer be suppressed for agent-1
          orchestrator.addSubscription(makeSub());

          // Clear verify history to isolate the next assertion.
          clearInteractions(mockRepository);
          restubWakeRunMethods(mockRepository);

          // Clear throttle set by the first subscription wake so the
          // second notification is not blocked by the cooldown.
          orchestrator.clearThrottle('agent-1');

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1'});

          // Wake should NOT be suppressed since mutation history was cleared.
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test('removeSubscriptions also clears mutation history', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..recordMutatedEntities('agent-1', {
              'entity-1': const VectorClock({'node-1': 1}),
            })
            ..removeSubscriptions('agent-1')
            // Re-add subscription after removal
            ..addSubscription(makeSub(id: 'sub-1b'));

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1'});

          // Wake should NOT be suppressed — mutation history was cleared
          // when subscriptions were removed.
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test('mid-execution signals are queued but suppressed during drain '
          'when they match self-mutations', () {
        fakeAsync((async) {
          // Use a completer to pause the executor mid-flight so we can
          // inject a notification that would match the agent's subscription.
          final gate = Completer<Map<String, VectorClock>?>();

          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = (agentId, runKey, triggers, threadId) {
              return gate.future;
            };

          // Start execution via direct enqueue (bypasses _onBatch deferral).
          queue.enqueue(makeJob(triggerTokens: {'entity-1'}));
          orchestrator.processNext();
          async.flushMicrotasks();

          // Executor is now paused on `gate`. Fire a notification for the
          // same entity while the agent is executing.
          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1'});

          // The notification is NOT suppressed by _onBatch (so external
          // signals during execution are preserved). Instead it is queued
          // and will be suppressed during the drain re-check using the
          // pre-registered suppression data.
          expect(queue.isEmpty, isFalse);

          // Complete the executor — returns the mutation set confirming
          // entity-1 was self-written.
          gate.complete({
            'entity-1': const VectorClock({'node-1': 1}),
          });
          async.flushMicrotasks();

          // The queued job should have been suppressed during drain
          // re-check (pre-registered suppression covers entity-1).
          // Only one wake run should have been persisted (the original).
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test(
        'external signal for different entity during execution '
        'is NOT suppressed after execution completes (only actual '
        'mutations are recorded)',
        () {
          fakeAsync((async) {
            final gate = Completer<Map<String, VectorClock>?>();
            var executionCount = 0;

            orchestrator
              ..addSubscription(
                makeSub(matchEntityIds: {'entity-1', 'entity-2'}),
              )
              ..wakeExecutor = (agentId, runKey, triggers, threadId) {
                executionCount++;
                if (executionCount == 1) return gate.future;
                return Future.value();
              };

            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenAnswer((_) async => null);

            // Start execution via direct enqueue (bypasses _onBatch deferral).
            queue.enqueue(makeJob(triggerTokens: {'entity-1'}));
            orchestrator.processNext();
            async.flushMicrotasks();
            expect(executionCount, 1);

            // While executing, an external change to entity-2 arrives.
            // Since _onBatch sets throttle on first non-throttled match,
            // this will enqueue and set throttle + deferred drain.
            final controller = StreamController<Set<String>>.broadcast();
            orchestrator.start(controller.stream);
            emitTokens(async, controller, {'entity-2'});

            // The signal should be queued.
            expect(queue.isEmpty, isFalse);

            // Complete first execution — only entity-1 was mutated.
            // Only actual mutations (entity-1) are recorded in the
            // confirmed suppression record; entity-2 is NOT suppressed.
            gate.complete({
              'entity-1': const VectorClock({'node-1': 1}),
            });
            async.flushMicrotasks();

            // Only the first wake should have run so far (throttle gate).
            expect(executionCount, 1);

            // After the throttle window expires, the deferred drain fires.
            // entity-2 is NOT in the confirmed suppression set (only
            // entity-1 was mutated), so the queued job proceeds.
            async
              ..elapse(WakeOrchestrator.throttleWindow)
              ..flushMicrotasks();
            expect(executionCount, 2);

            controller.close();
          });
        },
      );

      test('only actual mutations are suppressed after execution '
          '(non-mutated subscribed IDs are not suppressed)', () {
        fakeAsync((async) {
          // Executor mutates entity-1 but not entity-2.
          // Only entity-1 should be in the confirmed suppression record.
          orchestrator
            ..addSubscription(
              makeSub(matchEntityIds: {'entity-1', 'entity-2'}),
            )
            ..wakeExecutor = (agentId, runKey, triggers, threadId) async {
              // Only entity-1 was actually mutated.
              return {
                'entity-1': const VectorClock({'node-1': 1}),
              };
            };

          // Trigger the first execution.
          queue.enqueue(makeJob(triggerTokens: {'entity-1'}));
          orchestrator.processNext();
          async.flushMicrotasks();

          clearInteractions(mockRepository);
          restubWakeRunMethods(mockRepository);

          // Clear throttle set by the first subscription wake so the
          // second notification is not blocked by the cooldown.
          orchestrator.clearThrottle('agent-1');

          // entity-2 was NOT mutated, so it is NOT suppressed — the
          // notification should enqueue a wake job immediately.
          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-2'});
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test(
        'catches insertWakeRun failure, releases lock, and continues drain',
        () {
          fakeAsync((async) {
            var insertCallCount = 0;
            when(
              () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
            ).thenAnswer((_) async {
              insertCallCount++;
              if (insertCallCount == 1) throw Exception('DB failure');
            });

            // Enqueue two jobs for different agents.
            queue
              ..enqueue(makeJob(runKey: 'rk-fail'))
              ..enqueue(
                makeJob(
                  runKey: 'rk-ok',
                  agentId: 'agent-2',
                  triggerTokens: {'tok-b'},
                ),
              );

            // processNext should NOT throw — the error is caught internally.
            orchestrator.processNext();
            async.flushMicrotasks();

            // Both locks should be released.
            expect(runner.isRunning('agent-1'), isFalse);
            expect(runner.isRunning('agent-2'), isFalse);

            // The second job should still have been processed despite the
            // first one failing.
            expect(insertCallCount, 2);
          });
        },
      );

      test(
        'suppresses deferred subscription job that becomes self-mutated',
        () {
          fakeAsync((async) {
            // Agent-1 is busy (pre-locked). A subscription job is enqueued and
            // deferred because the agent is running. While deferred, the
            // orchestrator records mutations that cover all trigger tokens.
            // When the deferred job is re-processed, the drain suppression
            // re-check should skip it.

            final gate = Completer<Map<String, VectorClock>?>();
            orchestrator
              ..addSubscription(makeSub())
              ..wakeExecutor = (agentId, runKey, triggers, threadId) {
                if (runKey.contains('manual')) {
                  return gate.future;
                }
                return Future.value();
              };

            // Enqueue a manual wake that will hold the lock.
            queue.enqueue(
              makeJob(runKey: 'manual-rk', reason: 'manual', triggerTokens: {}),
            );
            orchestrator.processNext();
            async.flushMicrotasks();

            // Agent-1 is now busy executing the manual job.
            // Enqueue a subscription job that will be deferred.
            queue.enqueue(
              makeJob(runKey: 'sub-rk', triggerTokens: {'entity-1'}),
            );
            orchestrator.processNext();
            async.flushMicrotasks();

            // Complete the manual job with mutations covering entity-1.
            gate.complete({
              'entity-1': const VectorClock({'node-1': 1}),
            });
            async.flushMicrotasks();

            // The deferred subscription job should now be suppressed because
            // entity-1 was self-mutated by the manual execution.
            // Only the manual run's insertWakeRun should have been called.
            final captured = captureWakeRuns(mockRepository);

            // Only the manual wake run should have been persisted;
            // the subscription job should have been suppressed at re-check.
            expect(captured.length, 1);
            expect(captured.first.reason, 'manual');
          });
        },
      );

      test('continues drain when an unexpected execution error escapes', () {
        fakeAsync((async) {
          final logger = MockDomainLogger();
          var executionLogCount = 0;
          when(
            () => logger.log(
              any(),
              any(),
              subDomain: any(named: 'subDomain'),
              level: any(named: 'level'),
            ),
          ).thenAnswer((invocation) {
            final message = invocation.positionalArguments[1] as String;
            if (message.startsWith('executing runKey=')) {
              executionLogCount++;
              if (executionLogCount == 1) {
                throw StateError('unexpected logger failure');
              }
            }
          });
          when(
            () => logger.error(
              any(),
              any(),
              message: any(named: 'message'),
              subDomain: any(named: 'subDomain'),
              stackTrace: any(named: 'stackTrace'),
            ),
          ).thenReturn(null);

          final localQueue = WakeQueue();
          final localRunner = WakeRunner();
          final executedAgentIds = <String>[];
          final localOrchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: localQueue,
            runner: localRunner,
            domainLogger: logger,
            wakeExecutor: (agentId, runKey, triggers, threadId) async {
              executedAgentIds.add(agentId);
              return null;
            },
          );

          localQueue
            ..enqueue(makeJob())
            ..enqueue(
              makeJob(
                runKey: 'rk-2',
                agentId: 'agent-2',
                triggerTokens: {'tok-b'},
              ),
            );

          localOrchestrator.processNext();
          async.flushMicrotasks();

          expect(executedAgentIds, ['agent-2']);
          expect(localRunner.activeAgentIds, isEmpty);
          expect(localQueue, hasLength(0));
          verify(
            () => logger.error(
              LogDomain.agentRuntime,
              any(that: isA<StateError>()),
              message: any(
                named: 'message',
                that: contains('unexpected wake execution failure'),
              ),
              subDomain: any(named: 'subDomain'),
              stackTrace: any(named: 'stackTrace'),
            ),
          ).called(1);

          localOrchestrator.stop();
          localRunner.dispose();
        });
      });

      test('continues drain when updateWakeRunStatus throws on completion', () {
        fakeAsync((async) {
          var executorCallCount = 0;
          orchestrator.wakeExecutor =
              (agentId, runKey, triggers, threadId) async {
                executorCallCount++;
                return null;
              };

          // Make updateWakeRunStatus throw on the first call (completion
          // status update for agent-1) but succeed on the second (agent-2).
          var updateCallCount = 0;
          when(
            () => mockRepository.updateWakeRunStatus(
              any(),
              any(),
              completedAt: any(named: 'completedAt'),
              errorMessage: any(named: 'errorMessage'),
            ),
          ).thenAnswer((_) async {
            updateCallCount++;
            if (updateCallCount == 1) throw Exception('DB write failed');
          });

          queue
            ..enqueue(makeJob())
            ..enqueue(
              makeJob(
                runKey: 'rk-2',
                agentId: 'agent-2',
                triggerTokens: {'tok-b'},
              ),
            );

          orchestrator.processNext();
          async.flushMicrotasks();

          // Both executors should have run despite the status update failure.
          expect(executorCallCount, 2);
          // Both locks should be released.
          expect(runner.isRunning('agent-1'), isFalse);
          expect(runner.isRunning('agent-2'), isFalse);
        });
      });

      test('continues drain when updateWakeRunStatus throws on failure', () {
        fakeAsync((async) {
          // Executor throws for agent-1; the subsequent updateWakeRunStatus
          // ('failed') also throws. Agent-2 should still be processed.
          orchestrator.wakeExecutor =
              (agentId, runKey, triggers, threadId) async {
                if (agentId == 'agent-1') throw Exception('Executor error');
                return null;
              };

          var updateCallCount = 0;
          when(
            () => mockRepository.updateWakeRunStatus(
              any(),
              any(),
              completedAt: any(named: 'completedAt'),
              errorMessage: any(named: 'errorMessage'),
            ),
          ).thenAnswer((_) async {
            updateCallCount++;
            // First update is for agent-1's 'failed' status — throw.
            if (updateCallCount == 1) throw Exception('DB write failed');
          });

          queue
            ..enqueue(makeJob())
            ..enqueue(
              makeJob(
                runKey: 'rk-2',
                agentId: 'agent-2',
                triggerTokens: {'tok-b'},
              ),
            );

          orchestrator.processNext();
          async.flushMicrotasks();

          // Both locks should be released.
          expect(runner.isRunning('agent-1'), isFalse);
          expect(runner.isRunning('agent-2'), isFalse);
          // Agent-2's status update should have succeeded.
          expect(updateCallCount, 2);
        });
      });

      test('active drain fills available concurrency with newly queued work', () {
        fakeAsync((async) {
          // Use a completer to pause the first job mid-execution so we can
          // enqueue a second job while the drain is in-flight.
          final gate = Completer<Map<String, VectorClock>?>();
          var executionCount = 0;

          orchestrator.wakeExecutor = (agentId, runKey, triggers, threadId) {
            executionCount++;
            if (executionCount == 1) return gate.future;
            return Future.value();
          };

          // Enqueue and start draining the first job.
          queue.enqueue(makeJob(reason: 'test'));
          orchestrator.processNext();
          async.flushMicrotasks();

          // Drain is blocked on gate. Enqueue a second job for a different
          // agent and call processNext again — the guard should defer it.
          queue.enqueue(
            makeJob(
              runKey: 'rk-2',
              agentId: 'agent-2',
              reason: 'test',
              triggerTokens: {'tok-b'},
            ),
          );
          orchestrator.processNext();
          async.flushMicrotasks();

          // The second agent can start immediately because the default global
          // concurrency is three, while the per-agent lock remains independent.
          expect(executionCount, 2);

          // Complete the first job — the drain should pick up the second.
          gate.complete(null);
          async.flushMicrotasks();

          expect(executionCount, 2);
        });
      });
    });
    group('pre-wake hook (fork healing)', () {
      test('runs onWakeStart before the executor, with the wake context', () {
        fakeAsync((async) {
          final order = <String>[];
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            onWakeStart: (agentId, runKey, threadId) async {
              order.add('hook:$agentId:$runKey:$threadId');
            },
            wakeExecutor: (agentId, runKey, triggers, threadId) async {
              order.add('executor');
              return null;
            },
          );

          queue.enqueue(makeJob());
          orchestrator.processNext();
          async.flushMicrotasks();

          // The hook ran first, with agentId + runKey + threadId (= runKey).
          expect(order, ['hook:agent-1:rk-1:rk-1', 'executor']);
        });
      });

      test('a throwing onWakeStart is non-fatal — the wake still executes and '
          'completes', () {
        fakeAsync((async) {
          var executed = false;
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            onWakeStart: (agentId, runKey, threadId) async {
              throw StateError('fork-heal boom');
            },
            wakeExecutor: (agentId, runKey, triggers, threadId) async {
              executed = true;
              return null;
            },
          );

          queue.enqueue(makeJob());
          orchestrator.processNext();
          async.flushMicrotasks();

          // Healing is an optimization — its failure must not abort the wake.
          expect(executed, isTrue);
          verify(
            () => mockRepository.updateWakeRunStatus(
              'rk-1',
              WakeRunStatus.completed.name,
              completedAt: any(named: 'completedAt'),
              errorMessage: any(named: 'errorMessage'),
            ),
          ).called(1);
        });
      });

      test(
        'a hanging onWakeStart is bounded by its timeout — wake proceeds',
        () {
          fakeAsync((async) {
            var executed = false;
            orchestrator = WakeOrchestrator(
              repository: mockRepository,
              queue: queue,
              runner: runner,
              // Never completes — must be bounded by wakeStartHookTimeout.
              onWakeStart: (agentId, runKey, threadId) =>
                  Completer<void>().future,
              wakeExecutor: (agentId, runKey, triggers, threadId) async {
                executed = true;
                return null;
              },
            );

            queue.enqueue(makeJob());
            orchestrator.processNext();
            async.flushMicrotasks();
            expect(executed, isFalse); // blocked awaiting the hook

            async
              ..elapse(WakeOrchestrator.wakeStartHookTimeout)
              ..flushMicrotasks();
            expect(executed, isTrue); // timeout fired, the wake ran anyway
          });
        },
      );
    });
    group('runCompletions (ADR 0032 phase 1)', () {
      test(
        'enqueueManualWake returns the run key that a completed wake reports '
        'back on',
        () {
          fakeAsync((async) {
            orchestrator = WakeOrchestrator(
              repository: mockRepository,
              queue: queue,
              runner: runner,
              wakeExecutor: noOpExecutor,
            );
            WakeRunCompletion? received;
            orchestrator.runCompletions.listen((event) => received = event);

            final runKey = orchestrator.enqueueManualWake(
              agentId: 'agent-1',
              reason: 'creation',
              triggerTokens: {'task-1'},
            );
            async.flushMicrotasks();

            expect(received, isNotNull);
            expect(received!.runKey, runKey);
            expect(received!.status, WakeRunStatus.completed);
            expect(received!.error, isNull);
          });
        },
      );

      test('a throwing executor emits a failed completion with the error', () {
        fakeAsync((async) {
          final thrown = StateError('boom');
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            wakeExecutor: (agentId, runKey, triggers, threadId) async =>
                throw thrown,
          );
          WakeRunCompletion? received;
          orchestrator.runCompletions.listen((event) => received = event);

          orchestrator.enqueueManualWake(
            agentId: 'agent-1',
            reason: 'creation',
          );
          async.flushMicrotasks();

          expect(received!.status, WakeRunStatus.failed);
          expect(received!.error, thrown);
        });
      });

      test('an aborted wake emits an aborted completion', () {
        fakeAsync((async) {
          final gate = Completer<Map<String, VectorClock>?>();
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            wakeExecutor: (agentId, runKey, triggers, threadId) => gate.future,
          );
          WakeRunCompletion? received;
          orchestrator.runCompletions.listen((event) => received = event);

          queue.enqueue(makeJob());
          unawaited(orchestrator.processNext());
          async.flushMicrotasks();

          orchestrator.abortRunningWake('agent-1');
          async.flushMicrotasks();

          expect(received!.status, WakeRunStatus.aborted);
          gate.complete(const {});
          async.flushMicrotasks();
        });
      });

      test('no executor registered emits a failed completion', () {
        fakeAsync((async) {
          WakeRunCompletion? received;
          orchestrator.runCompletions.listen((event) => received = event);

          orchestrator.enqueueManualWake(
            agentId: 'agent-1',
            reason: 'creation',
          );
          async.flushMicrotasks();

          expect(received!.status, WakeRunStatus.failed);
        });
      });

      test('stop() closes the stream so late listeners see it end', () {
        fakeAsync((async) {
          var done = false;
          orchestrator.runCompletions.listen(null, onDone: () => done = true);

          unawaited(orchestrator.stop());
          async.flushMicrotasks();

          expect(done, isTrue);
        });
      });
    });
  });
}
