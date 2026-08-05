import 'package:glados/glados.dart' as glados;

import 'wake_orchestrator_test_harness.dart';

void main() {
  configureWakeOrchestratorTestSuite();

  // Owns throttle persistence, deferred drains, safety nets, and propagation.
  group('WakeOrchestrator', () {
    group('deferred drain via throttle timer', () {
      test('notification during post-execution throttle enqueues for '
          'deferred drain', () {
        fakeAsync((async) {
          var executionCount = 0;

          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = (agentId, runKey, triggers, threadId) async {
              executionCount++;
              return null;
            };

          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => null);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // First wake: defer-first enqueues + defers; drain executes.
          emitAndDrain(async, controller, {'entity-1'});
          expect(executionCount, 1);

          // Advance past the 5s suppression TTL so the next notification
          // for entity-1 is not suppressed by the confirmed suppression record.
          async.elapse(const Duration(seconds: 6));

          // Agent is now throttled (post-execution throttle). An external
          // notification arrives — no queued job to merge into, so a new
          // job is enqueued for the deferred drain.
          emitTokens(async, controller, {'entity-1'});

          // Advance past the post-execution throttle to fire deferred drain.
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          // Second execution — the external change triggers a follow-up wake.
          expect(executionCount, 2);

          controller.close();
        });
      });

      test('stop cancels deferred drain timers', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = noOpExecutor;

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Emit tokens — enqueues job + schedules deferred drain.
          emitTokens(async, controller, {'entity-1'});

          // Stop the orchestrator before the deferred drain fires.
          orchestrator.stop();
          async.flushMicrotasks();

          clearInteractions(mockRepository);
          restubWakeRunMethods(mockRepository);

          // Advance past the throttle window — timer should not fire.
          async
            ..elapse(WakeOrchestrator.throttleWindow * 2)
            ..flushMicrotasks();

          // No wake run should have been persisted after stop.
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          controller.close();
        });
      });
    });
    group('throttle gate', () {
      glados.Glados(
        glados.any.pendingWakeRestoreScenario,
        glados.ExploreConfig(numRuns: 180),
      ).test(
        'matches generated persisted pending-wake restoration semantics',
        (scenario) {
          fakeAsync((async) {
            final generatedRepository = MockAgentRepository();
            final generatedQueue = WakeQueue();
            final generatedRunner = WakeRunner();
            final stateByAgent = <String, AgentStateEntity>{};
            final executions = <String>[];
            final now = clock.now();

            when(
              () => generatedRepository.getAgentState(any()),
            ).thenAnswer((invocation) async {
              final agentId = invocation.positionalArguments.single as String;
              return stateByAgent[agentId];
            });
            when(
              () => generatedRepository.upsertEntity(any()),
            ).thenAnswer((invocation) async {
              final entity =
                  invocation.positionalArguments.single as AgentDomainEntity;
              if (entity is AgentStateEntity) {
                stateByAgent[entity.agentId] = entity;
              }
            });
            restubWakeRunMethods(generatedRepository);

            final generatedOrchestrator = WakeOrchestrator(
              repository: generatedRepository,
              queue: generatedQueue,
              runner: generatedRunner,
              wakeExecutor: (agentId, runKey, triggers, threadId) async {
                executions.add(agentId);
                expect(triggers, isEmpty, reason: '$scenario');
                return null;
              },
            );

            final dueByAgent = <String, DateTime>{};
            for (final (index, spec) in scenario.specs.indexed) {
              final agentId = 'generated-restore-agent-$index';
              final dueAt = spec.dueAt(now);
              dueByAgent[agentId] = dueAt;
              stateByAgent[agentId] = makeTestState(
                agentId: agentId,
                nextWakeAt: dueAt,
              );

              if (scenario.registerSubscriptions) {
                generatedOrchestrator.addSubscription(
                  makeSub(
                    id: 'generated-restore-sub-$index',
                    agentId: agentId,
                    matchEntityIds: {'generated-restore-token-$index'},
                  ),
                );
              }

              final prior = scenario.priorThrottleDeadline(now, dueAt);
              if (prior != null && prior.isAfter(now)) {
                generatedOrchestrator.setThrottleDeadline(agentId, prior);
              }

              generatedOrchestrator.restorePendingWake(
                agentId: agentId,
                dueAt: dueAt,
              );
              if (scenario.duplicateRestoreCalls) {
                generatedOrchestrator.restorePendingWake(
                  agentId: agentId,
                  dueAt: dueAt,
                );
              }
            }

            async.flushMicrotasks();

            final overdueAgentIds = dueByAgent.entries
                .where((entry) => !entry.value.isAfter(now))
                .map((entry) => entry.key)
                .toSet();
            final futureEntries =
                dueByAgent.entries
                    .where((entry) => entry.value.isAfter(now))
                    .toList()
                  ..sort((a, b) => a.value.compareTo(b.value));

            expect(executions.toSet(), overdueAgentIds, reason: '$scenario');
            expect(executions, hasLength(overdueAgentIds.length));
            expect(generatedQueue.length, futureEntries.length);

            for (final agentId in overdueAgentIds) {
              expect(
                stateByAgent[agentId]?.nextWakeAt,
                isNull,
                reason: '$scenario',
              );
            }

            if (futureEntries.isNotEmpty) {
              final firstDueAt = futureEntries.first.value;
              async
                ..elapse(
                  firstDueAt.difference(clock.now()) -
                      const Duration(milliseconds: 1),
                )
                ..flushMicrotasks();
              expect(executions, hasLength(overdueAgentIds.length));

              for (final dueAt
                  in futureEntries.map((entry) => entry.value).toSet()) {
                async
                  ..elapse(dueAt.difference(clock.now()))
                  ..flushMicrotasks();

                final expectedExecuted = dueByAgent.entries
                    .where((entry) => !entry.value.isAfter(dueAt))
                    .map((entry) => entry.key)
                    .toSet();
                expect(
                  executions.toSet(),
                  expectedExecuted,
                  reason: '$scenario',
                );
                expect(executions, hasLength(expectedExecuted.length));
              }
            }

            expect(executions, hasLength(scenario.specs.length));
            for (final agentId in dueByAgent.keys) {
              expect(
                stateByAgent[agentId]?.nextWakeAt,
                isNull,
                reason: '$scenario',
              );
            }
            expect(generatedQueue.isEmpty, isTrue, reason: '$scenario');

            generatedOrchestrator.stop();
            async.flushMicrotasks();
          });
        },
        tags: 'glados',
      );

      glados.Glados(
        glados.any.postRunThrottleScenario,
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'matches generated post-run nextWakeAt decision matrix',
        (scenario) {
          withClock(Clock.fixed(scenario.now), () {
            fakeAsync((async) {
              final generatedRepository = MockAgentRepository();
              final generatedQueue = WakeQueue();
              final generatedRunner = WakeRunner();
              final upsertedStates = <AgentStateEntity>[];
              var state = makeTestState(agentId: 'agent-1');

              when(
                () => generatedRepository.getAgentState(any()),
              ).thenAnswer((_) async => state);
              when(
                () => generatedRepository.upsertEntity(any()),
              ).thenAnswer((invocation) async {
                state =
                    invocation.positionalArguments.single as AgentStateEntity;
                upsertedStates.add(state);
              });
              restubWakeRunMethods(generatedRepository);

              final generatedOrchestrator = WakeOrchestrator(
                repository: generatedRepository,
                queue: generatedQueue,
                runner: generatedRunner,
                wakeExecutor: noOpExecutor,
              );

              generatedQueue.enqueue(
                makeJob(
                  runKey: 'generated-post-run-main',
                  reason: scenario.reason,
                  triggerTokens: {'generated-post-run-main-token'},
                  createdAt: scenario.now,
                ),
              );
              if (scenario.hasFollowUp) {
                generatedQueue.enqueue(
                  WakeJob(
                    runKey: 'generated-post-run-follow-up',
                    agentId: 'agent-1',
                    reason: WakeReason.subscription.name,
                    triggerTokens: const {'generated-post-run-follow-up-token'},
                    reasonId: 'generated-post-run-follow-up-sub',
                    createdAt: scenario.now,
                    hasDirectMatch: scenario.followUpHasDirectMatch,
                  ),
                );
              }

              generatedOrchestrator.processNext();
              async.flushMicrotasks();

              final nextWakeWrites = upsertedStates
                  .map((state) => state.nextWakeAt)
                  .whereType<DateTime>()
                  .toList();
              final expectedDeadline = scenario.expectedDeadline;
              if (expectedDeadline == null) {
                expect(nextWakeWrites, isEmpty, reason: '$scenario');
                expect(generatedQueue.isEmpty, isTrue, reason: '$scenario');
              } else {
                expect(nextWakeWrites, [expectedDeadline], reason: '$scenario');
                expect(
                  generatedQueue.hasQueuedJobFor('agent-1'),
                  isTrue,
                  reason: '$scenario',
                );
                expect(
                  generatedQueue.hasDirectQueuedJobFor('agent-1'),
                  scenario.followUpHasDirectMatch,
                  reason: '$scenario',
                );
              }

              generatedOrchestrator.stop();
              async.flushMicrotasks();
            });
          });
        },
        tags: 'glados',
      );

      test('subscription wake sets throttle deadline', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = noOpExecutor;

          // Stub getAgentState for _setThrottleDeadline persistence.
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => null);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // First notification enqueues job and sets throttle (deferred).
          emitTokens(async, controller, {'entity-1'});

          // No immediate execution — job is deferred.
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          // Second notification within throttle window should be throttled
          // (tokens merged into existing job).
          emitTokens(async, controller, {'entity-1'});

          // Still no execution.
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          // Advance past throttle — deferred drain fires, executes the
          // coalesced job.
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test('manual wake clears throttle and executes immediately', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = noOpExecutor;

          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => null);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // First subscription notification sets throttle (deferred).
          emitTokens(async, controller, {'entity-1'});

          // No immediate execution.
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          // Manual wake should bypass throttle.
          orchestrator.enqueueManualWake(
            agentId: 'agent-1',
            reason: 'reanalysis',
          );
          async.flushMicrotasks();

          // Manual wake run should have been persisted.
          final captured = captureWakeRuns(mockRepository);
          expect(captured.any((e) => e.reason == 'reanalysis'), isTrue);

          controller.close();
        });
      });

      test('throttle expires after throttleWindow elapses', () {
        fakeAsync((async) {
          var executionCount = 0;

          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = (agentId, runKey, triggers, threadId) async {
              executionCount++;
              return null;
            };

          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => null);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // First notification sets throttle + schedules deferred drain.
          emitTokens(async, controller, {'entity-1'});
          expect(executionCount, 0);

          // Advance past initial throttle window — deferred drain fires
          // and executes the first wake. Execution sets a new throttle.
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();
          expect(executionCount, 1);

          // Advance past the post-execution throttle window + 1s.
          async
            ..elapse(
              WakeOrchestrator.throttleWindow + const Duration(seconds: 1),
            )
            ..flushMicrotasks();

          // Second notification should now proceed (throttle expired).
          emitAndDrain(async, controller, {'entity-1'});
          expect(executionCount, 2);

          controller.close();
        });
      });

      test('deferred timer fires processNext after throttle window', () {
        fakeAsync((async) {
          var executionCount = 0;

          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = (agentId, runKey, triggers, threadId) async {
              executionCount++;
              return null;
            };

          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => null);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Notification enqueues + defers.
          emitTokens(async, controller, {'entity-1'});
          expect(executionCount, 0);

          // Advance to throttle deadline — deferred timer fires.
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          expect(executionCount, 1);

          // Execution set a new throttle. Wait for it to expire.
          async
            ..elapse(
              WakeOrchestrator.throttleWindow + const Duration(seconds: 1),
            )
            ..flushMicrotasks();

          // A new notification should now succeed (deferred again).
          emitAndDrain(async, controller, {'entity-1'});
          expect(executionCount, 2);

          controller.close();
        });
      });

      test('creation wake does NOT set throttle', () {
        fakeAsync((async) {
          orchestrator.wakeExecutor = noOpExecutor;

          orchestrator
            ..addSubscription(makeSub())
            ..enqueueManualWake(
              agentId: 'agent-1',
              reason: 'creation',
              triggerTokens: {'task-1'},
            );
          async
            ..flushMicrotasks()
            // Advance past the 5s suppression TTL so the subscription
            // notification is not suppressed by the confirmed suppression record
            // (which merges all subscribed IDs after the creation wake).
            ..elapse(const Duration(seconds: 6));

          // Subscription notification should still proceed (not throttled by
          // the creation wake). It will be deferred by the initial throttle.
          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1'});

          // Both the creation wake and subscription wake should have run.
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(2);

          controller.close();
        });
      });

      test('removeSubscriptions clears throttle', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = noOpExecutor;

          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => null);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Defer-first: emit enqueues + defers; drain executes.
          emitAndDrain(async, controller, {'entity-1'});

          // Remove and re-add subscription — throttle should be cleared.
          orchestrator
            ..removeSubscriptions('agent-1')
            ..addSubscription(makeSub(id: 'sub-1b'));

          clearInteractions(mockRepository);
          restubWakeRunMethods(mockRepository);
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => null);

          emitAndDrain(async, controller, {'entity-1'});

          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test('setThrottleDeadline hydrates throttle from persisted state', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = noOpExecutor;

          // Hydrate a throttle deadline 120 seconds in the future.
          final deadline = clock.now().add(const Duration(seconds: 120));
          orchestrator.setThrottleDeadline('agent-1', deadline);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Notification should be throttled (no immediate execution).
          emitTokens(async, controller, {'entity-1'});
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          // Advance past deadline — deferred drain fires, executing the
          // throttled job.
          async
            ..elapse(const Duration(seconds: 121))
            ..flushMicrotasks();

          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test('setThrottleDeadline ignores past deadlines', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = noOpExecutor;

          // Set a past deadline — should be ignored.
          final pastDeadline = clock.now().subtract(
            const Duration(seconds: 10),
          );
          orchestrator.setThrottleDeadline('agent-1', pastDeadline);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Past deadline is ignored, so the agent is not pre-throttled.
          // Defer-first still applies: emit enqueues + defers, drain executes.
          emitAndDrain(async, controller, {'entity-1'});
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test(
        'restorePendingWake executes overdue persisted deadline immediately',
        () {
          fakeAsync((async) {
            final dueAt = clock.now().subtract(const Duration(hours: 10));
            var executionCount = 0;
            var storedState = makeTestState(
              agentId: 'agent-1',
              nextWakeAt: dueAt,
            );

            orchestrator.wakeExecutor = (agentId, runKey, triggers, threadId) {
              executionCount++;
              expect(agentId, 'agent-1');
              expect(triggers, isEmpty);
              return Future.value();
            };

            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenAnswer((_) async => storedState);
            when(() => mockRepository.upsertEntity(any())).thenAnswer((
              invocation,
            ) async {
              storedState =
                  invocation.positionalArguments.single as AgentStateEntity;
            });

            orchestrator.restorePendingWake(agentId: 'agent-1', dueAt: dueAt);
            async.flushMicrotasks();

            expect(executionCount, 1);
            expect(storedState.nextWakeAt, isNull);

            final captured = captureWakeRuns(mockRepository);
            expect(captured, hasLength(1));
            expect(captured.single.agentId, 'agent-1');
            expect(captured.single.reason, WakeReason.subscription.name);
            expect(captured.single.reasonId, 'restored_pending_wake');
            expect(captured.single.createdAt, dueAt);
          });
        },
      );

      test(
        'restorePendingWake rebuilds future queue job and drains at deadline',
        () {
          fakeAsync((async) {
            const wait = Duration(minutes: 5);
            final dueAt = clock.now().add(wait);
            var executionCount = 0;
            var storedState = makeTestState(
              agentId: 'agent-1',
              nextWakeAt: dueAt,
            );

            orchestrator.wakeExecutor = (agentId, runKey, triggers, threadId) {
              executionCount++;
              return Future.value();
            };

            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenAnswer((_) async => storedState);
            when(() => mockRepository.upsertEntity(any())).thenAnswer((
              invocation,
            ) async {
              storedState =
                  invocation.positionalArguments.single as AgentStateEntity;
            });

            orchestrator.restorePendingWake(agentId: 'agent-1', dueAt: dueAt);
            async.flushMicrotasks();

            expect(executionCount, 0);

            async
              ..elapse(wait - const Duration(milliseconds: 1))
              ..flushMicrotasks();
            expect(executionCount, 0);

            async
              ..elapse(const Duration(milliseconds: 1))
              ..flushMicrotasks();

            expect(executionCount, 1);
            expect(storedState.nextWakeAt, isNull);
            final captured = captureWakeRuns(mockRepository);
            expect(captured.single.reason, WakeReason.subscription.name);
            expect(captured.single.reasonId, 'restored_pending_wake');
          });
        },
      );

      test('stop cancels deferred drain timers', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = noOpExecutor;

          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => null);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Trigger wake (sets throttle + deferred timer).
          emitTokens(async, controller, {'entity-1'});

          // Stop the orchestrator.
          orchestrator.stop();
          async.flushMicrotasks();

          // Advance past throttle — deferred timer should NOT fire.
          clearInteractions(mockRepository);
          async
            ..elapse(WakeOrchestrator.throttleWindow * 2)
            ..flushMicrotasks();

          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          controller.close();
        });
      });

      test('subscription wake persists throttle deadline via upsertEntity', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = noOpExecutor;

          final existingState = makeTestState(
            id: 'state-agent-1',
            agentId: 'agent-1',
          );
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => existingState);
          when(
            () => mockRepository.upsertEntity(any()),
          ).thenAnswer((_) async {});

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Defer-first: emit enqueues + defers, drain executes and
          // _setThrottleDeadline persists the post-execution deadline.
          emitAndDrain(async, controller, {'entity-1'});

          final captured = verify(
            () => mockRepository.upsertEntity(captureAny()),
          ).captured.cast<AgentStateEntity>();

          // Find the persisted throttle deadline (non-null nextWakeAt).
          final withDeadline = captured
              .where((s) => s.nextWakeAt != null)
              .toList();
          expect(withDeadline, isNotEmpty);

          final persisted = withDeadline.last;
          expect(persisted.agentId, 'agent-1');

          // The persisted deadline should be ~120s from the execution time.
          expect(
            persisted.nextWakeAt!.isAfter(clock.now()) ||
                persisted.nextWakeAt!.isAtSameMomentAs(clock.now()),
            isTrue,
          );

          controller.close();
        });
      });

      test(
        'subscription wake clears nextWakeAt when no follow-up job remains',
        () {
          // Fix the clock so the persisted deadline is deterministic. The
          // deferred-drain timer still fires under fakeAsync.elapse because the
          // timer duration is deadline.difference(clock.now()) = throttleWindow,
          // which emitAndDrain advances by exactly.
          final now = DateTime(2024, 3, 15, 11);
          withClock(Clock.fixed(now), () {
            fakeAsync((async) {
              orchestrator
                ..addSubscription(makeSub())
                ..wakeExecutor = noOpExecutor;

              final writes = <AgentStateEntity>[];
              var storedState = makeTestState(
                id: 'state-agent-1',
                agentId: 'agent-1',
              );
              when(
                () => mockRepository.getAgentState(any()),
              ).thenAnswer((_) async => storedState);
              when(() => mockRepository.upsertEntity(any())).thenAnswer((
                invocation,
              ) async {
                storedState =
                    invocation.positionalArguments.single as AgentStateEntity;
                writes.add(storedState);
              });

              final controller = StreamController<Set<String>>.broadcast();
              orchestrator.start(controller.stream);

              emitAndDrain(async, controller, {'entity-1'});

              expect(writes, hasLength(2));
              // The defer-first arm persists a deadline exactly
              // now + throttleWindow (direct match → fast throttle).
              expect(
                writes.first.nextWakeAt,
                now.add(WakeOrchestrator.throttleWindow),
              );
              // With no queued follow-up after execution, the deadline is
              // cleared back to null.
              expect(writes.last.nextWakeAt, isNull);

              controller.close();
            });
          });
        },
      );

      test(
        '_setThrottleDeadline still sets in-memory throttle on DB error',
        () {
          fakeAsync((async) {
            orchestrator
              ..addSubscription(makeSub())
              ..wakeExecutor = noOpExecutor;

            // getAgentState throws to simulate DB failure in persistence.
            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenThrow(Exception('DB error'));

            final controller = StreamController<Set<String>>.broadcast();
            orchestrator.start(controller.stream);

            // Defer-first: emit enqueues + defers, drain executes.
            emitAndDrain(async, controller, {'entity-1'});

            // First wake executes despite DB error in persistence.
            verify(
              () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
            ).called(1);

            // In-memory throttle should still be active (set by
            // _setThrottleDeadline even when DB persistence fails) —
            // second notification should be merged, not executed.
            clearInteractions(mockRepository);
            restubWakeRunMethods(mockRepository);

            emitTokens(async, controller, {'entity-1'});
            verifyNever(
              () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
            );

            controller.close();
          });
        },
      );

      test('clearThrottle persists nextWakeAt null via upsertEntity', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..wakeExecutor = noOpExecutor;

          final existingState = makeTestState(
            id: 'state-agent-1',
            agentId: 'agent-1',
          );
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => existingState);
          when(
            () => mockRepository.upsertEntity(any()),
          ).thenAnswer((_) async {});

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Defer-first: emit enqueues + defers; drain executes and
          // _setThrottleDeadline persists the post-execution deadline.
          emitAndDrain(async, controller, {'entity-1'});

          // Verify _setThrottleDeadline persisted a non-null deadline.
          final setCapture = verify(
            () => mockRepository.upsertEntity(captureAny()),
          ).captured.cast<AgentStateEntity>();
          final withDeadline = setCapture
              .where((s) => s.nextWakeAt != null)
              .toList();
          expect(withDeadline, isNotEmpty);

          // Now clear the throttle.
          clearInteractions(mockRepository);
          when(() => mockRepository.getAgentState('agent-1')).thenAnswer(
            (_) async => existingState.copyWith(
              nextWakeAt: clock.now().add(WakeOrchestrator.throttleWindow),
            ),
          );
          when(
            () => mockRepository.upsertEntity(any()),
          ).thenAnswer((_) async {});

          orchestrator.clearThrottle('agent-1');
          async.flushMicrotasks();

          // Verify _clearPersistedThrottle persisted nextWakeAt: null.
          final clearCapture = verify(
            () => mockRepository.upsertEntity(captureAny()),
          ).captured;
          expect(clearCapture, hasLength(1));
          expect(
            (clearCapture.first as AgentStateEntity).nextWakeAt,
            isNull,
          );

          controller.close();
        });
      });

      test(
        'clearThrottle skips upsert when new throttle set during getAgentState',
        () {
          fakeAsync((async) {
            orchestrator
              ..addSubscription(makeSub())
              ..wakeExecutor = noOpExecutor;

            final existingState = makeTestState(
              id: 'state-agent-1',
              agentId: 'agent-1',
            );
            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenAnswer((_) async => existingState);
            when(
              () => mockRepository.upsertEntity(any()),
            ).thenAnswer((_) async {});

            final controller = StreamController<Set<String>>.broadcast();
            orchestrator.start(controller.stream);

            // Defer-first: emit enqueues + defers; drain executes and
            // _setThrottleDeadline persists the post-execution deadline.
            emitAndDrain(async, controller, {'entity-1'});

            // Clear interactions so we can track only the clear path.
            clearInteractions(mockRepository);

            // Simulate: getAgentState completes, but during the await a new
            // throttle deadline is set (e.g. by another subscription wake).
            when(() => mockRepository.getAgentState('agent-1')).thenAnswer(
              (_) async {
                // While the DB read is in flight, set a new throttle.
                orchestrator.setThrottleDeadline(
                  'agent-1',
                  clock.now().add(WakeOrchestrator.throttleWindow),
                );
                return existingState.copyWith(
                  nextWakeAt: clock.now().add(WakeOrchestrator.throttleWindow),
                );
              },
            );

            orchestrator.clearThrottle('agent-1');
            async.flushMicrotasks();

            // The post-await guard should detect the new deadline and skip
            // the upsert — no upsertEntity call for null nextWakeAt.
            verifyNever(() => mockRepository.upsertEntity(any()));

            controller.close();
          });
        },
      );

      test(
        'clearThrottle still clears in-memory state on DB write failure',
        () {
          fakeAsync((async) {
            orchestrator
              ..addSubscription(makeSub())
              ..wakeExecutor = noOpExecutor;

            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenAnswer((_) async => null);

            final controller = StreamController<Set<String>>.broadcast();
            orchestrator.start(controller.stream);

            // Defer-first: emit enqueues + defers; drain executes.
            emitAndDrain(async, controller, {'entity-1'});
            verify(
              () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
            ).called(1);

            // Advance past the 5s suppression TTL so the next entity-1
            // notification is not suppressed by the confirmed suppression record.
            async.elapse(const Duration(seconds: 6));

            // Make getAgentState throw so clearThrottle's DB write fails.
            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenThrow(Exception('DB unavailable'));

            orchestrator.clearThrottle('agent-1');
            async.flushMicrotasks();

            // In-memory throttle should be cleared despite DB failure,
            // so a new subscription notification should execute after deferral.
            clearInteractions(mockRepository);
            restubWakeRunMethods(mockRepository);
            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenAnswer((_) async => null);

            emitAndDrain(async, controller, {'entity-1'});
            verify(
              () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
            ).called(1);

            controller.close();
          });
        },
      );

      test('natural expiry clears persisted nextWakeAt', () {
        fakeAsync((async) {
          orchestrator.wakeExecutor = noOpExecutor;

          final existingState = makeTestState(
            id: 'state-agent-1',
            agentId: 'agent-1',
          );

          // Provide state with non-null nextWakeAt for the expiry clear.
          when(() => mockRepository.getAgentState('agent-1')).thenAnswer(
            (_) async => existingState.copyWith(
              nextWakeAt: clock.now().add(WakeOrchestrator.throttleWindow),
            ),
          );
          when(
            () => mockRepository.upsertEntity(any()),
          ).thenAnswer((_) async {});

          // Hydrate a throttle via setThrottleDeadline (no enqueued job,
          // so the deferred drain timer fires without racing execution).
          final deadline = clock.now().add(WakeOrchestrator.throttleWindow);
          orchestrator.setThrottleDeadline('agent-1', deadline);

          // Advance past the throttle window to fire the deferred timer.
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          // Verify that _clearPersistedThrottle was called with null.
          final captured = verify(
            () => mockRepository.upsertEntity(captureAny()),
          ).captured;
          expect(captured, isNotEmpty);
          expect(
            (captured.last as AgentStateEntity).nextWakeAt,
            isNull,
          );
        });
      });

      test(
        'throttle applies per-agent independently',
        () {
          fakeAsync((async) {
            orchestrator
              ..addSubscription(makeSub())
              ..addSubscription(
                makeSub(
                  id: 'sub-2',
                  agentId: 'agent-2',
                  matchEntityIds: {'entity-2'},
                ),
              )
              ..wakeExecutor = noOpExecutor;

            when(
              () => mockRepository.getAgentState(any()),
            ).thenAnswer((_) async => null);

            final controller = StreamController<Set<String>>.broadcast();
            orchestrator.start(controller.stream);

            // Both agents execute on separate tokens.
            emitAndDrain(async, controller, {'entity-1', 'entity-2'});
            final firstBatch = captureWakeRuns(mockRepository);
            expect(firstBatch.length, 2);

            // Advance past the 5s suppression TTL so subsequent
            // notifications are not suppressed by the confirmed suppression record.
            async.elapse(const Duration(seconds: 6));

            clearInteractions(mockRepository);
            restubWakeRunMethods(mockRepository);

            // Both agents should be throttled now (post-execution throttle).
            // Only emit entity-1 so agent-2 (which subscribes to entity-2)
            // is not matched and doesn't enqueue during the throttle window.
            emitTokens(async, controller, {'entity-1'});
            verifyNever(
              () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
            );

            // Clear throttle for agent-1 only.
            orchestrator.clearThrottle('agent-1');

            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenAnswer((_) async => null);

            // Only emit entity-1 token so only agent-1 can match.
            emitAndDrain(async, controller, {'entity-1'});

            // Only agent-1 should run.
            final captured = captureWakeRuns(mockRepository);
            expect(captured.length, 1);
            expect(captured.first.agentId, 'agent-1');

            controller.close();
          });
        },
      );
    });
    group('awaiting-content cache', () {
      test(
        'setAwaitingContent suppresses throttle deadline on subscription wakes',
        () {
          fakeAsync((async) {
            orchestrator
              ..addSubscription(makeSub())
              ..setAwaitingContent('agent-1', awaiting: true)
              ..wakeExecutor = noOpExecutor;

            final controller = StreamController<Set<String>>.broadcast();
            orchestrator.start(controller.stream);

            emitTokens(async, controller, {'entity-1'});

            // Advance just shy of the safety-net interval. With no deferred
            // drain timer scheduled (the throttle was skipped), nothing has
            // surfaced a countdown via persisted nextWakeAt and the wake has
            // not been dispatched.
            async
              ..elapse(
                WakeOrchestrator.safetyNetInterval - const Duration(seconds: 1),
              )
              ..flushMicrotasks();

            verifyNever(
              () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
            );
            verifyNever(
              () => mockRepository.upsertEntity(
                any(
                  that: isA<AgentStateEntity>().having(
                    (s) => s.nextWakeAt,
                    'nextWakeAt',
                    isNotNull,
                  ),
                ),
              ),
            );
            expect(orchestrator.isAwaitingContent('agent-1'), isTrue);

            controller.close();
          });
        },
      );

      test(
        'content-gate clears the cache once real content arrives',
        () {
          fakeAsync((async) {
            final state = makeTestState(
              agentId: 'agent-cg-cache',
              awaitingContent: true,
              slots: const AgentSlots(activeTaskId: 'task-cache'),
            );
            when(
              () => mockRepository.getAgentState('agent-cg-cache'),
            ).thenAnswer((_) async => state);

            final cg =
                WakeOrchestrator(
                    repository: mockRepository,
                    queue: queue,
                    runner: WakeRunner(),
                    taskContentChecker: (taskId) async => true,
                    wakeExecutor: (agentId, runKey, triggers, threadId) async {
                      return null;
                    },
                  )
                  ..setAwaitingContent('agent-cg-cache', awaiting: true)
                  ..enqueueManualWake(
                    agentId: 'agent-cg-cache',
                    reason: 'creation',
                  );

            expect(cg.isAwaitingContent('agent-cg-cache'), isTrue);

            async
              ..elapse(WakeOrchestrator.throttleWindow)
              ..flushMicrotasks();

            // After the content gate finds content, the cache is cleared so
            // subsequent subscription wakes get the normal countdown again.
            expect(cg.isAwaitingContent('agent-cg-cache'), isFalse);

            cg.stop();
          });
        },
      );

      test('removeSubscriptions drops the awaiting-content entry', () {
        orchestrator
          ..addSubscription(makeSub())
          ..setAwaitingContent('agent-1', awaiting: true);

        expect(orchestrator.isAwaitingContent('agent-1'), isTrue);

        orchestrator.removeSubscriptions('agent-1');

        expect(orchestrator.isAwaitingContent('agent-1'), isFalse);
      });

      test(
        'setAwaitingContent(awaiting: false) clears the cache entry, '
        'restoring the normal throttle countdown',
        () {
          fakeAsync((async) {
            // A persisted state is required for the throttle coordinator to
            // write nextWakeAt; default stub returns null.
            when(() => mockRepository.getAgentState('agent-1')).thenAnswer(
              (_) async => makeTestState(agentId: 'agent-1'),
            );

            // Arm the awaiting-content flag, then explicitly clear it via the
            // setter's else-branch (not via removeSubscriptions).
            orchestrator
              ..addSubscription(makeSub())
              ..setAwaitingContent('agent-1', awaiting: true);
            expect(orchestrator.isAwaitingContent('agent-1'), isTrue);

            orchestrator.setAwaitingContent('agent-1', awaiting: false);
            expect(orchestrator.isAwaitingContent('agent-1'), isFalse);

            // Clearing an already-absent agent is a harmless no-op.
            orchestrator.setAwaitingContent('agent-other', awaiting: false);
            expect(orchestrator.isAwaitingContent('agent-other'), isFalse);

            // With the flag cleared, a subscription wake now arms the normal
            // throttle deadline (persists nextWakeAt) instead of suppressing
            // the countdown.
            final controller = StreamController<Set<String>>.broadcast();
            orchestrator.start(controller.stream);
            emitTokens(async, controller, {'entity-1'});
            async.flushMicrotasks();

            final persisted =
                verify(
                  () => mockRepository.upsertEntity(captureAny()),
                ).captured.whereType<AgentStateEntity>().where(
                  (s) => s.agentId == 'agent-1' && s.nextWakeAt != null,
                );
            expect(
              persisted,
              isNotEmpty,
              reason:
                  'clearing awaitingContent must restore the throttle '
                  'countdown so the next subscription wake persists nextWakeAt',
            );

            controller.close();
          });
        },
      );
    });
    group('_scheduleDeferredDrain edge cases', () {
      test(
        'setThrottleDeadline with past deadline does not throttle agent',
        () {
          fakeAsync((async) {
            var executionCount = 0;

            orchestrator
              ..addSubscription(makeSub())
              ..wakeExecutor = (agentId, runKey, triggers, threadId) async {
                executionCount++;
                return null;
              };

            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenAnswer((_) async => null);

            final controller = StreamController<Set<String>>.broadcast();
            orchestrator.start(controller.stream);

            // Set a past deadline via public API — should be ignored so the
            // agent is not pre-throttled.
            final pastDeadline = clock.now().subtract(
              const Duration(seconds: 1),
            );
            orchestrator.setThrottleDeadline('agent-1', pastDeadline);

            // Agent should NOT be throttled; emit + drain works normally.
            emitAndDrain(async, controller, {'entity-1'});
            expect(executionCount, 1);

            controller.close();
          });
        },
      );

      test(
        'deadline at exactly clock.now() triggers immediate drain '
        'via scheduleMicrotask',
        () {
          // When setThrottleDeadline is called with deadline == clock.now(),
          // isBefore returns false so the method proceeds, but remaining is
          // Duration.zero. The fix ensures processNext is called immediately
          // via scheduleMicrotask instead of silently dropping.
          fakeAsync((async) {
            var executionCount = 0;

            orchestrator.wakeExecutor =
                (agentId, runKey, triggers, threadId) async {
                  executionCount++;
                  return null;
                };

            final controller = StreamController<Set<String>>.broadcast();
            orchestrator.start(controller.stream);

            // Directly enqueue a job so processNext has work.
            queue.enqueue(
              makeJob(runKey: 'edge-case-key', triggerTokens: {'entity-1'}),
            );

            // Set deadline to exactly now — remaining will be Duration.zero.
            // The fix should clear the throttle and schedule processNext
            // via microtask.
            orchestrator.setThrottleDeadline('agent-1', clock.now());

            // Flush the scheduleMicrotask callback.
            async.flushMicrotasks();

            // The job should have been executed via the immediate drain.
            expect(executionCount, 1);

            controller.close();
          });
        },
      );
    });
    group('safety-net periodic drain', () {
      test('safety-net timer fires processNext for stuck jobs', () {
        fakeAsync((async) {
          var executionCount = 0;

          orchestrator.wakeExecutor =
              (agentId, runKey, triggers, threadId) async {
                executionCount++;
                return null;
              };

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Directly enqueue a "stuck" job — no deferred drain timer is
          // scheduled, simulating the failure mode the safety net catches.
          queue.enqueue(
            makeJob(runKey: 'stuck-job-key', triggerTokens: {'entity-1'}),
          );

          // Advance past the safety-net interval.
          async
            ..elapse(WakeOrchestrator.safetyNetInterval)
            ..flushMicrotasks();

          // The safety-net should have triggered processNext and executed
          // the stuck job.
          expect(executionCount, 1);

          controller.close();
        });
      });

      test('stop cancels safety-net timer', () {
        fakeAsync((async) {
          var executionCount = 0;

          orchestrator.wakeExecutor =
              (agentId, runKey, triggers, threadId) async {
                executionCount++;
                return null;
              };

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator
            ..start(controller.stream)
            // Stop the orchestrator.
            ..stop();
          async
            ..flushMicrotasks()
            // Advance past multiple safety-net intervals.
            ..elapse(WakeOrchestrator.safetyNetInterval * 3)
            ..flushMicrotasks();

          // No execution should have occurred.
          expect(executionCount, 0);

          controller.close();
        });
      });
    });
    group('onPersistedStateChanged callback', () {
      test(
        'invokes callback when throttle deadline is persisted after execution',
        () async {
          fakeAsync((async) {
            final controller = StreamController<Set<String>>.broadcast();
            final agentState = makeTestState(agentId: 'agent-1');
            final changedAgentIds = <String>[];

            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenAnswer((_) async => agentState);

            orchestrator =
                WakeOrchestrator(
                    repository: mockRepository,
                    queue: queue,
                    runner: runner,
                    onPersistedStateChanged: changedAgentIds.add,
                  )
                  ..addSubscription(makeSub())
                  ..wakeExecutor = noOpExecutor;

            orchestrator.start(controller.stream);

            // First wake: triggers execution and then persists throttle deadline.
            emitAndDrain(async, controller, {'entity-1'});
            async.flushMicrotasks();

            expect(changedAgentIds, contains('agent-1'));
            controller.close();
          });
        },
      );

      test(
        'invokes callback when clearThrottle persists null nextWakeAt',
        () async {
          fakeAsync((async) {
            final controller = StreamController<Set<String>>.broadcast();
            final changedAgentIds = <String>[];
            final agentState = makeTestState(
              agentId: 'agent-1',
              nextWakeAt: DateTime(2024),
            );

            when(
              () => mockRepository.getAgentState('agent-1'),
            ).thenAnswer((_) async => agentState);

            orchestrator =
                WakeOrchestrator(
                    repository: mockRepository,
                    queue: queue,
                    runner: runner,
                    onPersistedStateChanged: changedAgentIds.add,
                  )
                  ..addSubscription(makeSub())
                  ..wakeExecutor = noOpExecutor;

            orchestrator.start(controller.stream);

            // Execute once to set a throttle deadline, then clear it.
            emitAndDrain(async, controller, {'entity-1'});
            async.flushMicrotasks();

            orchestrator.clearThrottle('agent-1');
            async.flushMicrotasks();

            expect(changedAgentIds, contains('agent-1'));
            controller.close();
          });
        },
      );
    });
  });

  group('domain logging integration', () {
    group('propagated subscription deferral (next 06:00)', () {
      test(
        'a propagated-only match defers nextWakeAt to the next 06:00 '
        'instead of the standard 120 s throttle window',
        () {
          // Pin the wall clock so the next-06:00 calculation is
          // deterministic regardless of when the test runs.
          final now = DateTime(2026, 5, 10, 21, 30);
          withClock(Clock.fixed(now), () {
            fakeAsync((async) {
              orchestrator
                ..wakeExecutor = noOpExecutor
                ..addSubscription(
                  makeSub(matchEntityIds: {'task-parent'}),
                );

              when(
                () => mockRepository.getAgentState('agent-1'),
              ).thenAnswer(
                (_) async =>
                    AgentDomainEntity.agentState(
                          id: 'state-1',
                          agentId: 'agent-1',
                          slots: const AgentSlots(),
                          updatedAt: now,
                          vectorClock: null,
                        )
                        as AgentStateEntity,
              );

              final controller = StreamController<Set<String>>.broadcast();
              orchestrator.start(controller.stream);
              addTearDown(controller.close);

              // Only the propagated form is in the batch — the agent's
              // entity wasn't directly edited; a child of it was.
              emitTokens(async, controller, {
                propagatedNotification('task-parent'),
              });

              // The persisted nextWakeAt should be tomorrow 06:00 (since
              // the pinned clock is past 06:00 today), NOT now + 120 s.
              final captured = verify(
                () => mockRepository.upsertEntity(captureAny()),
              ).captured;
              final state = captured.last as AgentStateEntity;
              expect(
                state.nextWakeAt,
                DateTime(2026, 5, 11, 6),
                reason: 'propagated-only match must defer to the next 06:00',
              );
            });
          });
        },
      );

      test(
        'a task-agent propagated match can opt out of the 06:00 deferral '
        'and use the standard 120 s throttle window',
        () {
          final now = DateTime(2026, 5, 10, 21, 30);
          withClock(Clock.fixed(now), () {
            fakeAsync((async) {
              orchestrator
                ..wakeExecutor = noOpExecutor
                ..addSubscription(
                  makeSub(
                    matchEntityIds: {'task-child-update'},
                    deferPropagatedMatches: false,
                  ),
                );

              when(
                () => mockRepository.getAgentState('agent-1'),
              ).thenAnswer(
                (_) async =>
                    AgentDomainEntity.agentState(
                          id: 'state-1',
                          agentId: 'agent-1',
                          slots: const AgentSlots(),
                          updatedAt: now,
                          vectorClock: null,
                        )
                        as AgentStateEntity,
              );

              final controller = StreamController<Set<String>>.broadcast();
              orchestrator.start(controller.stream);
              addTearDown(controller.close);

              emitTokens(async, controller, {
                propagatedNotification('task-child-update'),
              });

              final captured = verify(
                () => mockRepository.upsertEntity(captureAny()),
              ).captured;
              final state = captured.last as AgentStateEntity;
              expect(
                state.nextWakeAt,
                now.add(const Duration(seconds: 120)),
                reason:
                    'task-agent child updates should refresh on the normal '
                    'coalesced wake path, not wait until 06:00',
              );
              expect(queue.hasDirectQueuedJobFor('agent-1'), isTrue);
            });
          });
        },
      );

      test(
        'a direct match keeps the existing 120 s throttle window even when '
        'an unrelated propagated token sits alongside it in the same batch',
        () {
          final now = DateTime(2026, 5, 10, 21, 30);
          withClock(Clock.fixed(now), () {
            fakeAsync((async) {
              orchestrator
                ..wakeExecutor = noOpExecutor
                ..addSubscription(
                  makeSub(matchEntityIds: {'task-direct'}),
                );

              when(
                () => mockRepository.getAgentState('agent-1'),
              ).thenAnswer(
                (_) async =>
                    AgentDomainEntity.agentState(
                          id: 'state-1',
                          agentId: 'agent-1',
                          slots: const AgentSlots(),
                          updatedAt: now,
                          vectorClock: null,
                        )
                        as AgentStateEntity,
              );

              final controller = StreamController<Set<String>>.broadcast();
              orchestrator.start(controller.stream);
              addTearDown(controller.close);

              // Direct token matches this subscription; the unrelated
              // propagated token must not switch deferral to morning mode
              // for the matched subscription.
              emitTokens(async, controller, {
                'task-direct',
                propagatedNotification('task-unrelated'),
              });

              final captured = verify(
                () => mockRepository.upsertEntity(captureAny()),
              ).captured;
              final state = captured.last as AgentStateEntity;
              expect(
                state.nextWakeAt,
                now.add(const Duration(seconds: 120)),
              );
            });
          });
        },
      );

      test(
        'when the same id appears as both bare and propagated, the match '
        'is treated as propagated (the legacy bare emission accompanies '
        'the parent fan-out and must not collapse the deferral)',
        () {
          final now = DateTime(2026, 5, 10, 3, 15);
          withClock(Clock.fixed(now), () {
            fakeAsync((async) {
              orchestrator
                ..wakeExecutor = noOpExecutor
                ..addSubscription(
                  makeSub(matchEntityIds: {'task-mixed'}),
                );

              when(
                () => mockRepository.getAgentState('agent-1'),
              ).thenAnswer(
                (_) async =>
                    AgentDomainEntity.agentState(
                          id: 'state-1',
                          agentId: 'agent-1',
                          slots: const AgentSlots(),
                          updatedAt: now,
                          vectorClock: null,
                        )
                        as AgentStateEntity,
              );

              final controller = StreamController<Set<String>>.broadcast();
              orchestrator.start(controller.stream);
              addTearDown(controller.close);

              emitTokens(async, controller, {
                'task-mixed',
                propagatedNotification('task-mixed'),
              });

              // Pinned clock is before 06:00 today, so morning deferral
              // resolves to today's 06:00 (not tomorrow's).
              final captured = verify(
                () => mockRepository.upsertEntity(captureAny()),
              ).captured;
              final state = captured.last as AgentStateEntity;
              expect(state.nextWakeAt, DateTime(2026, 5, 10, 6));
            });
          });
        },
      );

      test(
        'a direct edit arriving on top of a propagated-only morning '
        'deferral escalates the throttle deadline back to now+120s — '
        "the user's edit must not sit waiting until 06:00",
        () {
          final now = DateTime(2026, 5, 10, 21, 30);
          withClock(Clock.fixed(now), () {
            fakeAsync((async) {
              orchestrator
                ..wakeExecutor = noOpExecutor
                ..addSubscription(
                  makeSub(matchEntityIds: {'task-escalate'}),
                );

              when(
                () => mockRepository.getAgentState('agent-1'),
              ).thenAnswer(
                (_) async =>
                    AgentDomainEntity.agentState(
                          id: 'state-1',
                          agentId: 'agent-1',
                          slots: const AgentSlots(),
                          updatedAt: now,
                          vectorClock: null,
                        )
                        as AgentStateEntity,
              );

              final controller = StreamController<Set<String>>.broadcast();
              orchestrator.start(controller.stream);
              addTearDown(controller.close);

              // 1. Propagated-only batch arms a morning-deferred deadline.
              emitTokens(async, controller, {
                propagatedNotification('task-escalate'),
              });

              final firstCapture =
                  verify(
                        () => mockRepository.upsertEntity(captureAny()),
                      ).captured.last
                      as AgentStateEntity;
              expect(firstCapture.nextWakeAt, DateTime(2026, 5, 11, 6));

              // 2. Direct edit arrives while still deferred — must
              //    escalate to now + 120 s.
              emitTokens(async, controller, {'task-escalate'});

              final escalated =
                  verify(
                        () => mockRepository.upsertEntity(captureAny()),
                      ).captured.last
                      as AgentStateEntity;
              expect(
                escalated.nextWakeAt,
                now.add(const Duration(seconds: 120)),
                reason:
                    'a direct match coalescing onto a morning-deferred '
                    'job must reset the throttle to the 120 s window',
              );

              // The queued job's provenance must also flip to direct so
              // the post-execution throttle and any later drain pick the
              // immediate path.
              expect(queue.hasDirectQueuedJobFor('agent-1'), isTrue);
            });
          });
        },
      );

      test(
        'a direct match during a sooner-armed deferral does not move the '
        'deadline — escalation only fires when now+120s is earlier than '
        'the existing deadline',
        () {
          final now = DateTime(2026, 5, 10, 21, 30);
          withClock(Clock.fixed(now), () {
            fakeAsync((async) {
              orchestrator
                ..wakeExecutor = noOpExecutor
                ..addSubscription(makeSub(matchEntityIds: {'task-keep'}))
                // Arm a deadline only 30 s out — already sooner than the
                // 120 s fast-throttle window — together with a queued job,
                // exactly the restart-hydration shape. The queued job makes
                // the direct match below take the merge path, where the
                // escalation guard is evaluated in isolation.
                ..restorePendingWake(
                  agentId: 'agent-1',
                  dueAt: now.add(const Duration(seconds: 30)),
                );

              final controller = StreamController<Set<String>>.broadcast();
              orchestrator.start(controller.stream);
              addTearDown(controller.close);

              // Direct match while throttled: immediate (now+120s) is NOT
              // before the armed deadline, so the guard must skip the
              // escalation and keep the sooner deadline.
              emitTokens(async, controller, {'task-keep'});
              verifyNever(
                () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
              );

              // The drain still fires at the original 30 s deadline. Had
              // the direct match replaced it with now+120s, nothing would
              // execute here yet.
              async
                ..elapse(const Duration(seconds: 31))
                ..flushMicrotasks();
              verify(
                () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
              ).called(1);
            });
          });
        },
      );

      test(
        'post-execution throttle defers to next 06:00 when only '
        'propagated-only jobs are queued during the run — a fan-out that '
        'arrives mid-execution must not coast in on a 120 s drain',
        () {
          final now = DateTime(2026, 5, 10, 21, 30);
          withClock(Clock.fixed(now), () {
            fakeAsync((async) {
              final gate = Completer<Map<String, VectorClock>?>();
              orchestrator
                ..wakeExecutor = ((agentId, runKey, triggers, threadId) =>
                    gate.future)
                ..addSubscription(
                  makeSub(matchEntityIds: {'task-postexec'}),
                );

              when(
                () => mockRepository.getAgentState('agent-1'),
              ).thenAnswer(
                (_) async =>
                    AgentDomainEntity.agentState(
                          id: 'state-1',
                          agentId: 'agent-1',
                          slots: const AgentSlots(),
                          updatedAt: now,
                          vectorClock: null,
                        )
                        as AgentStateEntity,
              );

              // Drive the executor mid-flight by direct-enqueuing a job
              // (bypasses the _onBatch deferral) so the running flag is
              // set before our propagated batch arrives.
              queue.enqueue(
                makeJob(
                  triggerTokens: {'task-postexec'},
                  // ignore: avoid_redundant_argument_values
                  runKey: 'rk-1',
                ),
              );
              unawaited(orchestrator.processNext());
              async.flushMicrotasks();
              expect(runner.isRunning('agent-1'), isTrue);

              final controller = StreamController<Set<String>>.broadcast();
              orchestrator.start(controller.stream);
              addTearDown(controller.close);

              // Propagated-only batch arrives during execution → queued
              // with hasDirectMatch=false.
              emitTokens(async, controller, {
                propagatedNotification('task-postexec'),
              });
              expect(queue.hasDirectQueuedJobFor('agent-1'), isFalse);

              // Finish execution. The post-execution throttle must use
              // morning, not 120 s.
              gate.complete(const {});
              async.flushMicrotasks();

              final captured =
                  verify(
                    () => mockRepository.upsertEntity(captureAny()),
                  ).captured.whereType<AgentStateEntity>().lastWhere(
                    (s) => s.nextWakeAt != null,
                  );
              expect(captured.nextWakeAt, DateTime(2026, 5, 11, 6));
            });
          });
        },
      );
    });
  });
}
