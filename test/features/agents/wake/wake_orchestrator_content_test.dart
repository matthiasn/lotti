import 'wake_orchestrator_test_harness.dart';

void main() {
  configureWakeOrchestratorTestSuite();

  // Owns domain logging, content gates, execution zones, aborts, and timeouts.
  group('domain logging integration', () {
    test('_logError delegates to domainLogger when present', () {
      fakeAsync((async) {
        final mockDomainLogger = MockDomainLogger();
        when(
          () => mockDomainLogger.error(
            any(),
            any(),
            message: any(named: 'message'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).thenReturn(null);

        final loggedRepo = MockAgentRepository();
        final loggedQueue = WakeQueue();
        final loggedRunner = WakeRunner();

        when(
          () => loggedRepo.insertWakeRun(entry: any(named: 'entry')),
        ).thenAnswer((_) async => throw Exception('DB fail'));
        when(
          () => loggedRepo.updateWakeRunStatus(
            any(),
            any(),
            completedAt: any(named: 'completedAt'),
            errorMessage: any(named: 'errorMessage'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => loggedRepo.getAgentState(any()),
        ).thenAnswer((_) async => null);
        when(
          () => loggedRepo.getEntity(any()),
        ).thenAnswer((_) async => null);

        final loggedOrchestrator = WakeOrchestrator(
          repository: loggedRepo,
          queue: loggedQueue,
          runner: loggedRunner,
          domainLogger: mockDomainLogger,
        );

        loggedQueue.enqueue(
          makeJob(
            runKey: 'rk-err',
            agentId: 'agent-err',
            reason: 'manual',
            triggerTokens: {'tok'},
          ),
        );

        loggedOrchestrator.processNext();
        async.flushMicrotasks();

        verify(
          () => mockDomainLogger.error(
            LogDomain.agentRuntime,
            any(),
            message: any(
              named: 'message',
              that: contains('insertWakeRun failed'),
            ),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);

        loggedOrchestrator.stop();
      });
    });

    group('content gating', () {
      test(
        'skips wake when agent is awaitingContent and task has no content',
        () {
          fakeAsync((async) {
            final state = makeTestState(
              agentId: 'agent-cg',
              awaitingContent: true,
              slots: const AgentSlots(activeTaskId: 'task-1'),
            );
            when(
              () => mockRepository.getAgentState('agent-cg'),
            ).thenAnswer((_) async => state);

            var wakeExecuted = false;
            final cg =
                WakeOrchestrator(
                  repository: mockRepository,
                  queue: queue,
                  runner: WakeRunner(),
                  taskContentChecker: (taskId) async => false,
                  wakeExecutor: (agentId, runKey, triggers, threadId) async {
                    wakeExecuted = true;
                    return null;
                  },
                )..enqueueManualWake(
                  agentId: 'agent-cg',
                  reason: 'creation',
                );
            async
              ..elapse(WakeOrchestrator.throttleWindow)
              ..flushMicrotasks();

            expect(wakeExecuted, isFalse);

            cg.stop();
          });
        },
      );

      test('allows wake and clears flag when task has content', () {
        fakeAsync((async) {
          final state = makeTestState(
            agentId: 'agent-cg2',
            awaitingContent: true,
            slots: const AgentSlots(activeTaskId: 'task-2'),
          );
          when(
            () => mockRepository.getAgentState('agent-cg2'),
          ).thenAnswer((_) async => state);

          var wakeExecuted = false;
          final cg =
              WakeOrchestrator(
                repository: mockRepository,
                queue: queue,
                runner: WakeRunner(),
                taskContentChecker: (taskId) async => true,
                wakeExecutor: (agentId, runKey, triggers, threadId) async {
                  wakeExecuted = true;
                  return null;
                },
              )..enqueueManualWake(
                agentId: 'agent-cg2',
                reason: 'creation',
              );
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          expect(wakeExecuted, isTrue);

          // Verify awaitingContent was cleared via raw repository (no
          // syncEntityWriter provided).
          verify(
            () => mockRepository.upsertEntity(
              any(
                that: isA<AgentStateEntity>().having(
                  (s) => s.awaitingContent,
                  'awaitingContent',
                  isFalse,
                ),
              ),
            ),
          ).called(1);

          cg.stop();
        });
      });

      test(
        'skips wake when an event agent is awaitingContent and the event '
        'has no content',
        () {
          fakeAsync((async) {
            final state = makeTestState(
              agentId: 'agent-evt',
              awaitingContent: true,
              slots: const AgentSlots(activeEventId: 'event-1'),
            );
            when(
              () => mockRepository.getAgentState('agent-evt'),
            ).thenAnswer((_) async => state);

            var wakeExecuted = false;
            final cg = WakeOrchestrator(
              repository: mockRepository,
              queue: queue,
              runner: WakeRunner(),
              eventContentChecker: (eventId) async => false,
              wakeExecutor: (agentId, runKey, triggers, threadId) async {
                wakeExecuted = true;
                return null;
              },
            )..enqueueManualWake(agentId: 'agent-evt', reason: 'creation');
            async
              ..elapse(WakeOrchestrator.throttleWindow)
              ..flushMicrotasks();

            expect(wakeExecuted, isFalse);
            cg.stop();
          });
        },
      );

      test('allows wake and clears flag when the event has content', () {
        fakeAsync((async) {
          final state = makeTestState(
            agentId: 'agent-evt2',
            awaitingContent: true,
            slots: const AgentSlots(activeEventId: 'event-2'),
          );
          when(
            () => mockRepository.getAgentState('agent-evt2'),
          ).thenAnswer((_) async => state);

          var wakeExecuted = false;
          final cg = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: WakeRunner(),
            eventContentChecker: (eventId) async => true,
            wakeExecutor: (agentId, runKey, triggers, threadId) async {
              wakeExecuted = true;
              return null;
            },
          )..enqueueManualWake(agentId: 'agent-evt2', reason: 'creation');
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          expect(wakeExecuted, isTrue);
          verify(
            () => mockRepository.upsertEntity(
              any(
                that: isA<AgentStateEntity>().having(
                  (s) => s.awaitingContent,
                  'awaitingContent',
                  isFalse,
                ),
              ),
            ),
          ).called(1);
          cg.stop();
        });
      });

      test(
        'an event slot routes only to the event checker, never the task '
        'checker (no cross-slot fallback)',
        () {
          fakeAsync((async) {
            final state = makeTestState(
              agentId: 'agent-evt3',
              awaitingContent: true,
              slots: const AgentSlots(activeEventId: 'event-3'),
            );
            when(
              () => mockRepository.getAgentState('agent-evt3'),
            ).thenAnswer((_) async => state);

            var taskCheckerCalled = false;
            var wakeExecuted = false;
            final cg = WakeOrchestrator(
              repository: mockRepository,
              queue: queue,
              runner: WakeRunner(),
              // The task checker would let the wake through — but the event
              // slot must never reach it.
              taskContentChecker: (taskId) async {
                taskCheckerCalled = true;
                return true;
              },
              eventContentChecker: (eventId) async => false,
              wakeExecutor: (agentId, runKey, triggers, threadId) async {
                wakeExecuted = true;
                return null;
              },
            )..enqueueManualWake(agentId: 'agent-evt3', reason: 'creation');
            async
              ..elapse(WakeOrchestrator.throttleWindow)
              ..flushMicrotasks();

            expect(taskCheckerCalled, isFalse);
            expect(wakeExecuted, isFalse);
            cg.stop();
          });
        },
      );

      test('uses syncEntityWriter instead of raw repository when provided', () {
        fakeAsync((async) {
          final state = makeTestState(
            agentId: 'agent-cg-sync',
            awaitingContent: true,
            slots: const AgentSlots(activeTaskId: 'task-sync'),
          );
          when(
            () => mockRepository.getAgentState('agent-cg-sync'),
          ).thenAnswer((_) async => state);

          AgentDomainEntity? writtenEntity;
          var wakeExecuted = false;
          final cg =
              WakeOrchestrator(
                repository: mockRepository,
                queue: queue,
                runner: WakeRunner(),
                taskContentChecker: (taskId) async => true,
                syncEntityWriter: (entity) async {
                  writtenEntity = entity;
                },
                wakeExecutor: (agentId, runKey, triggers, threadId) async {
                  wakeExecuted = true;
                  return null;
                },
              )..enqueueManualWake(
                agentId: 'agent-cg-sync',
                reason: 'creation',
              );
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          expect(wakeExecuted, isTrue);

          // syncEntityWriter was called with the cleared state.
          expect(writtenEntity, isA<AgentStateEntity>());
          final cleared = writtenEntity! as AgentStateEntity;
          expect(cleared.awaitingContent, isFalse);
          expect(cleared.agentId, 'agent-cg-sync');

          // Raw repository.upsertEntity should NOT have been called for the
          // content-gate clearing (it may be called for other purposes like
          // wake-run status updates, so we verify the specific entity was not
          // passed to it).
          verifyNever(
            () => mockRepository.upsertEntity(
              any(
                that: isA<AgentStateEntity>().having(
                  (s) => s.awaitingContent,
                  'awaitingContent',
                  isFalse,
                ),
              ),
            ),
          );

          cg.stop();
        });
      });

      test('proceeds normally when awaitingContent is false', () {
        fakeAsync((async) {
          final state = makeTestState(
            agentId: 'agent-cg3',
            slots: const AgentSlots(activeTaskId: 'task-3'),
          );
          when(
            () => mockRepository.getAgentState('agent-cg3'),
          ).thenAnswer((_) async => state);

          var wakeExecuted = false;
          final cg =
              WakeOrchestrator(
                repository: mockRepository,
                queue: queue,
                runner: WakeRunner(),
                taskContentChecker: (taskId) async => false,
                wakeExecutor: (agentId, runKey, triggers, threadId) async {
                  wakeExecuted = true;
                  return null;
                },
              )..enqueueManualWake(
                agentId: 'agent-cg3',
                reason: 'subscription',
              );
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          expect(wakeExecuted, isTrue);

          cg.stop();
        });
      });

      test('proceeds when taskContentChecker is null', () {
        fakeAsync((async) {
          final state = makeTestState(
            agentId: 'agent-cg4',
            awaitingContent: true,
            slots: const AgentSlots(activeTaskId: 'task-4'),
          );
          when(
            () => mockRepository.getAgentState('agent-cg4'),
          ).thenAnswer((_) async => state);

          var wakeExecuted = false;
          final cg =
              WakeOrchestrator(
                repository: mockRepository,
                queue: queue,
                runner: WakeRunner(),
                // taskContentChecker is null
                wakeExecutor: (agentId, runKey, triggers, threadId) async {
                  wakeExecuted = true;
                  return null;
                },
              )..enqueueManualWake(
                agentId: 'agent-cg4',
                reason: 'creation',
              );
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          // No checker → cannot gate, so wake proceeds.
          expect(wakeExecuted, isTrue);

          cg.stop();
        });
      });

      test('proceeds when content check throws (fail-open)', () {
        fakeAsync((async) {
          final state = makeTestState(
            agentId: 'agent-cg5',
            awaitingContent: true,
            slots: const AgentSlots(activeTaskId: 'task-5'),
          );
          when(
            () => mockRepository.getAgentState('agent-cg5'),
          ).thenAnswer((_) async => state);

          var wakeExecuted = false;
          final cg =
              WakeOrchestrator(
                repository: mockRepository,
                queue: queue,
                runner: WakeRunner(),
                taskContentChecker: (taskId) async =>
                    throw Exception('DB error'),
                wakeExecutor: (agentId, runKey, triggers, threadId) async {
                  wakeExecuted = true;
                  return null;
                },
              )..enqueueManualWake(
                agentId: 'agent-cg5',
                reason: 'subscription',
              );
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          // Error → fail-open, wake proceeds.
          expect(wakeExecuted, isTrue);

          cg.stop();
        });
      });

      test(
        'proceeds and logs completed run when taskContentChecker throws',
        () {
          fakeAsync((async) {
            final capturedEntries = stubInsertCapture(mockRepository);

            final state = makeTestState(
              agentId: 'agent-cg-throw',
              awaitingContent: true,
              slots: const AgentSlots(activeTaskId: 'task-throw'),
            );
            when(
              () => mockRepository.getAgentState('agent-cg-throw'),
            ).thenAnswer((_) async => state);

            String? executedAgentId;
            final cg =
                WakeOrchestrator(
                  repository: mockRepository,
                  queue: queue,
                  runner: WakeRunner(),
                  taskContentChecker: (taskId) async =>
                      throw StateError('unexpected DB failure'),
                  wakeExecutor: (agentId, runKey, triggers, threadId) async {
                    executedAgentId = agentId;
                    return null;
                  },
                )..enqueueManualWake(
                  agentId: 'agent-cg-throw',
                  reason: 'creation',
                );
            async
              ..elapse(WakeOrchestrator.throttleWindow)
              ..flushMicrotasks();

            // The wake must execute despite the checker throwing.
            expect(executedAgentId, 'agent-cg-throw');

            // A wake run log entry was persisted for the agent.
            expect(capturedEntries, hasLength(1));
            expect(capturedEntries.first.agentId, 'agent-cg-throw');

            // The run completed successfully (not marked as failed).
            verify(
              () => mockRepository.updateWakeRunStatus(
                any(),
                'completed',
                completedAt: any(named: 'completedAt'),
                errorMessage: any(named: 'errorMessage'),
              ),
            ).called(1);

            cg.stop();
          });
        },
      );

      test('proceeds when state has no activeTaskId', () {
        fakeAsync((async) {
          final state = makeTestState(
            agentId: 'agent-cg6',
            awaitingContent: true,
            // No activeTaskId
          );
          when(
            () => mockRepository.getAgentState('agent-cg6'),
          ).thenAnswer((_) async => state);

          var wakeExecuted = false;
          final cg =
              WakeOrchestrator(
                repository: mockRepository,
                queue: queue,
                runner: WakeRunner(),
                taskContentChecker: (taskId) async => false,
                wakeExecutor: (agentId, runKey, triggers, threadId) async {
                  wakeExecuted = true;
                  return null;
                },
              )..enqueueManualWake(
                agentId: 'agent-cg6',
                reason: 'creation',
              );
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          // No activeTaskId → cannot check content → proceeds.
          expect(wakeExecuted, isTrue);

          cg.stop();
        });
      });

      test(
        'drops mirror when persisted state shows the agent is no longer '
        'awaiting content',
        () {
          fakeAsync((async) {
            // Simulate a divergence: the in-memory mirror still says
            // awaiting, but the persisted state has been cleared (e.g.,
            // by another device via sync). The gate must drop the mirror
            // so future notifications surface the normal countdown.
            final clearedState = makeTestState(
              agentId: 'agent-cg-stale',
              slots: const AgentSlots(activeTaskId: 'task-stale'),
            );
            when(
              () => mockRepository.getAgentState('agent-cg-stale'),
            ).thenAnswer((_) async => clearedState);

            final cg =
                WakeOrchestrator(
                    repository: mockRepository,
                    queue: queue,
                    runner: WakeRunner(),
                    taskContentChecker: (taskId) async => true,
                    wakeExecutor: (agentId, runKey, triggers, threadId) async =>
                        null,
                  )
                  ..setAwaitingContent('agent-cg-stale', awaiting: true)
                  ..enqueueManualWake(
                    agentId: 'agent-cg-stale',
                    reason: 'subscription',
                  );

            async
              ..elapse(WakeOrchestrator.throttleWindow)
              ..flushMicrotasks();

            expect(cg.isAwaitingContent('agent-cg-stale'), isFalse);

            cg.stop();
          });
        },
      );

      test('drops mirror when no agent state is persisted', () {
        fakeAsync((async) {
          when(
            () => mockRepository.getAgentState('agent-cg-missing'),
          ).thenAnswer((_) async => null);

          final cg =
              WakeOrchestrator(
                  repository: mockRepository,
                  queue: queue,
                  runner: WakeRunner(),
                  taskContentChecker: (taskId) async => true,
                  wakeExecutor: (agentId, runKey, triggers, threadId) async =>
                      null,
                )
                ..setAwaitingContent('agent-cg-missing', awaiting: true)
                ..enqueueManualWake(
                  agentId: 'agent-cg-missing',
                  reason: 'subscription',
                );

          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          expect(cg.isAwaitingContent('agent-cg-missing'), isFalse);

          cg.stop();
        });
      });

      test(
        'drops mirror when awaiting flag is set but no activeTaskId can '
        'be gated on',
        () {
          fakeAsync((async) {
            final state = makeTestState(
              agentId: 'agent-cg-no-task',
              awaitingContent: true,
            );
            when(
              () => mockRepository.getAgentState('agent-cg-no-task'),
            ).thenAnswer((_) async => state);

            final cg =
                WakeOrchestrator(
                    repository: mockRepository,
                    queue: queue,
                    runner: WakeRunner(),
                    taskContentChecker: (taskId) async => false,
                    wakeExecutor: (agentId, runKey, triggers, threadId) async =>
                        null,
                  )
                  ..setAwaitingContent('agent-cg-no-task', awaiting: true)
                  ..enqueueManualWake(
                    agentId: 'agent-cg-no-task',
                    reason: 'creation',
                  );

            async
              ..elapse(WakeOrchestrator.throttleWindow)
              ..flushMicrotasks();

            expect(cg.isAwaitingContent('agent-cg-no-task'), isFalse);

            cg.stop();
          });
        },
      );

      test(
        'leaves mirror untouched when taskContentChecker is null (fail-open)',
        () {
          fakeAsync((async) {
            final state = makeTestState(
              agentId: 'agent-cg-fail-open',
              awaitingContent: true,
              slots: const AgentSlots(activeTaskId: 'task-fail-open'),
            );
            when(
              () => mockRepository.getAgentState('agent-cg-fail-open'),
            ).thenAnswer((_) async => state);

            final cg =
                WakeOrchestrator(
                    repository: mockRepository,
                    queue: queue,
                    runner: WakeRunner(),
                    // taskContentChecker is null
                    wakeExecutor: (agentId, runKey, triggers, threadId) async =>
                        null,
                  )
                  ..setAwaitingContent('agent-cg-fail-open', awaiting: true)
                  ..enqueueManualWake(
                    agentId: 'agent-cg-fail-open',
                    reason: 'subscription',
                  );

            async
              ..elapse(WakeOrchestrator.throttleWindow)
              ..flushMicrotasks();

            // Indeterminate path — persisted flag still says awaiting, so
            // the mirror should remain so that countdown suppression keeps
            // matching the persisted truth.
            expect(cg.isAwaitingContent('agent-cg-fail-open'), isTrue);

            cg.stop();
          });
        },
      );
    });

    group('agent execution zone', () {
      test('executor runs inside agent execution zone '
          '(isAgentExecution is true)', () {
        fakeAsync((async) {
          bool? capturedIsAgentExecution;

          orchestrator
            ..addSubscription(
              makeSub(
                id: 'sub-zone',
                agentId: 'agent-zone',
                matchEntityIds: {'entity-zone'},
              ),
            )
            ..wakeExecutor = (agentId, runKey, triggers, threadId) async {
              capturedIsAgentExecution = isAgentExecution;
              return null;
            };

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-zone'});

          expect(
            capturedIsAgentExecution,
            isTrue,
            reason: 'The executor should run inside the agent execution zone',
          );

          controller.close();
        });
      });

      test('isAgentExecution is false outside of executor', () {
        // Verify that outside the executor context, the zone flag is false.
        expect(isAgentExecution, isFalse);
      });
    });

    group('abort and timeout', () {
      test(
        'pending-work probe tracks queued, running, and detached execution',
        () {
          fakeAsync((async) {
            const workspaceKey = 'coordinator:digest';
            final gate = Completer<Map<String, VectorClock>?>();
            orchestrator.wakeExecutor = (agentId, runKey, triggers, threadId) =>
                gate.future;

            queue.enqueue(makeJob(workspaceKey: workspaceKey));
            expect(
              orchestrator.hasPendingOrActiveWake(
                'agent-1',
                workspaceKey: workspaceKey,
              ),
              isTrue,
            );
            expect(
              orchestrator.hasPendingOrActiveWake(
                'agent-1',
                workspaceKey: 'another-workspace',
              ),
              isFalse,
            );
            unawaited(orchestrator.processNext());
            async.flushMicrotasks();

            expect(runner.isRunning('agent-1'), isTrue);
            expect(
              orchestrator.hasPendingOrActiveWake(
                'agent-1',
                workspaceKey: workspaceKey,
              ),
              isTrue,
            );

            final aborted = orchestrator.abortRunningWake('agent-1');
            async.flushMicrotasks();

            expect(aborted, isTrue);
            expect(runner.isRunning('agent-1'), isFalse);
            expect(
              orchestrator.hasPendingOrActiveWake(
                'agent-1',
                workspaceKey: workspaceKey,
              ),
              isTrue,
              reason: 'the uncancellable executor is still active',
            );

            // The wake-run row was finalised with status `aborted` and the
            // 'cancelled' error message (timeout would set 'timeout').
            verify(
              () => mockRepository.updateWakeRunStatus(
                any(),
                WakeRunStatus.aborted.name,
                completedAt: any(named: 'completedAt'),
                errorMessage: 'cancelled',
              ),
            ).called(1);

            // Reset the recorded interactions so we can assert that the
            // late-arriving executor result is fully ignored — no second
            // `updateWakeRunStatus` call (would re-classify as completed),
            // no fresh entity writes, no other repository activity.
            clearInteractions(mockRepository);

            // Even though we stopped awaiting it, the underlying future is
            // still pending — completing it now must not throw or re-mutate
            // suppression state.
            gate.complete(const {});
            async.flushMicrotasks();

            expect(
              orchestrator.hasPendingOrActiveWake(
                'agent-1',
                workspaceKey: workspaceKey,
              ),
              isFalse,
            );

            verifyNever(
              () => mockRepository.updateWakeRunStatus(
                any(),
                any(),
                completedAt: any(named: 'completedAt'),
                errorMessage: any(named: 'errorMessage'),
              ),
            );
            verifyNever(() => mockRepository.upsertEntity(any()));
            verifyNever(
              () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
            );
          });
        },
      );

      test(
        'wakeRunMaxDuration fires an automatic abort when the executor stalls',
        () {
          fakeAsync((async) {
            expect(
              WakeOrchestrator.wakeRunMaxDuration,
              const Duration(minutes: 10),
            );

            final gate = Completer<Map<String, VectorClock>?>();
            orchestrator.wakeExecutor = (agentId, runKey, triggers, threadId) =>
                gate.future;

            queue.enqueue(makeJob());
            unawaited(orchestrator.processNext());
            async.flushMicrotasks();
            expect(runner.isRunning('agent-1'), isTrue);

            // Advance just under the cap — still running.
            async
              ..elapse(
                WakeOrchestrator.wakeRunMaxDuration -
                    const Duration(seconds: 1),
              )
              ..flushMicrotasks();
            expect(runner.isRunning('agent-1'), isTrue);

            // Cross the cap — timer fires the abort signal.
            async
              ..elapse(const Duration(seconds: 2))
              ..flushMicrotasks();

            expect(runner.isRunning('agent-1'), isFalse);
            verify(
              () => mockRepository.updateWakeRunStatus(
                any(),
                WakeRunStatus.aborted.name,
                completedAt: any(named: 'completedAt'),
                errorMessage: 'timeout',
              ),
            ).called(1);

            gate.complete(const {});
            async.flushMicrotasks();
          });
        },
      );

      test(
        'abortRunningWake on an idle agent returns false and does not '
        'persist a wake-run row',
        () {
          fakeAsync((async) {
            final aborted = orchestrator.abortRunningWake('agent-cold');
            async.flushMicrotasks();

            expect(aborted, isFalse);
            verifyNever(
              () => mockRepository.updateWakeRunStatus(
                any(),
                any(),
                completedAt: any(named: 'completedAt'),
                errorMessage: any(named: 'errorMessage'),
              ),
            );
          });
        },
      );
    });
  });
}
