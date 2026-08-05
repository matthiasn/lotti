import 'package:glados/glados.dart' as glados;

import 'wake_orchestrator_test_harness.dart';

void main() {
  configureWakeOrchestratorTestSuite();

  // Owns subscription routing, notification matching, suppression, and lifecycle.
  group('WakeOrchestrator', () {
    group('subscription management', () {
      glados.Glados(
        glados.any.wakeRoutingScenario,
        glados.ExploreConfig(numRuns: 180),
      ).test(
        'matches generated subscription routing, replacement, and removal',
        (scenario) {
          fakeAsync((async) {
            final generatedRepository = MockAgentRepository();
            final generatedQueue = WakeQueue();
            final generatedRunner = WakeRunner();
            final generatedOrchestrator = WakeOrchestrator(
              repository: generatedRepository,
              queue: generatedQueue,
              runner: generatedRunner,
            );
            final controller = StreamController<Set<String>>.broadcast();

            stubWakeRepositoryDefaults(generatedRepository);

            for (final spec in scenario.subscriptionSpecs) {
              generatedOrchestrator.addSubscription(spec.toSubscription());
            }
            scenario.removedAgentIds.forEach(
              generatedOrchestrator.removeSubscriptions,
            );

            final busyAgentId = scenario.busyAgentId;
            if (busyAgentId != null) {
              generatedRunner.tryAcquire(busyAgentId);
              async.flushMicrotasks();
            }

            generatedOrchestrator.start(controller.stream);
            emitTokens(async, controller, scenario.batchTokens);

            final actualJobs = <WakeJob>[];
            while (!generatedQueue.isEmpty) {
              actualJobs.add(generatedQueue.dequeue()!);
            }
            final expectedJobs = scenario.expectedJobs;

            expect(actualJobs, hasLength(expectedJobs.length));
            for (var i = 0; i < expectedJobs.length; i++) {
              final actual = actualJobs[i];
              final expected = expectedJobs[i];

              expect(actual.agentId, expected.agentId, reason: '$scenario');
              expect(actual.reason, WakeReason.subscription.name);
              expect(actual.reasonId, expected.reasonId, reason: '$scenario');
              expect(
                actual.triggerTokens,
                expected.triggerTokens,
                reason: '$scenario',
              );
            }

            verifyNever(
              () => generatedRepository.insertWakeRun(
                entry: any(named: 'entry'),
              ),
            );

            if (busyAgentId != null) generatedRunner.release(busyAgentId);
            generatedOrchestrator.stop();
            controller.close();
          });
        },
        tags: 'glados',
      );

      test('addSubscription registers a subscription', () {
        fakeAsync((async) {
          orchestrator.addSubscription(makeSub());

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1'});

          // Deferred drain fires after throttleWindow, consuming the job
          // and persisting a wake run entry.
          final captured = captureSingleWakeRun(mockRepository);
          expect(captured.agentId, 'agent-1');
          expect(captured.reason, 'subscription');
          expect(captured.reasonId, 'sub-1');

          controller.close();
        });
      });

      test('addSubscription replaces existing subscription with same id', () {
        fakeAsync((async) {
          // Add a subscription matching entity-1.
          orchestrator
            ..addSubscription(makeSub())
            // Replace it with one matching entity-2 (same id).
            ..addSubscription(makeSub(matchEntityIds: {'entity-2'}));

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // entity-1 should no longer match (replaced).
          emitTokens(async, controller, {'entity-1'});
          expect(queue.isEmpty, isTrue);

          // entity-2 should match (the replacement).
          emitAndDrain(async, controller, {'entity-2'});
          verify(
            () => mockRepository.insertWakeRun(
              entry: any(named: 'entry'),
            ),
          ).called(1);

          controller.close();
        });
      });

      test('addSubscription with same id does not create duplicates '
          'that cause duplicate wake jobs', () {
        fakeAsync((async) {
          // Add the same subscription twice.
          for (var i = 0; i < 2; i++) {
            orchestrator.addSubscription(makeSub());
          }

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1'});

          // Should produce exactly one wake run, not two.
          verify(
            () => mockRepository.insertWakeRun(
              entry: any(named: 'entry'),
            ),
          ).called(1);

          controller.close();
        });
      });

      test('removeSubscriptions removes all subscriptions for an agent', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..addSubscription(
              makeSub(id: 'sub-2', matchEntityIds: {'entity-2'}),
            )
            ..addSubscription(
              makeSub(id: 'sub-3', agentId: 'agent-2'),
            )
            ..removeSubscriptions('agent-1');

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1', 'entity-2'});

          // Only agent-2's subscription should fire; deferred drain consumes it.
          final captured = captureSingleWakeRun(mockRepository);
          expect(captured.agentId, 'agent-2');

          controller.close();
        });
      });

      test(
        'disableAutomaticUpdatesRuntime drops automation but preserves user job',
        () {
          queue
            ..enqueue(
              WakeJob(
                runKey: 'automatic',
                agentId: 'agent-1',
                reason: WakeReason.subscription.name,
                initiator: WakeInitiator.automation,
                triggerTokens: const {'task-1'},
                createdAt: DateTime(2024, 3, 15),
              ),
            )
            ..enqueue(
              WakeJob(
                runKey: 'user',
                agentId: 'agent-1',
                reason: WakeReason.reanalysis.name,
                initiator: WakeInitiator.user,
                triggerTokens: const {},
                createdAt: DateTime(2024, 3, 15),
              ),
            );

          orchestrator.disableAutomaticUpdatesRuntime('agent-1');

          expect(queue.length, 1);
          expect(queue.dequeue()?.runKey, 'user');

          orchestrator
            ..addSubscription(makeSub())
            ..enableAutomaticUpdatesRuntime('agent-1')
            ..addSubscription(makeSub());
          // Subscription registration is idempotent and never enqueues a wake.
          expect(queue.isEmpty, isTrue);
        },
      );

      test(
        'disabled automation retains subscriptions and marks matching changes '
        'stale without queueing inference',
        () async {
          final signalAt = DateTime(2026, 7, 16, 9, 30);
          var state =
              AgentDomainEntity.agentState(
                    id: 'state-1',
                    agentId: 'agent-1',
                    slots: const AgentSlots(activeTaskId: 'entity-1'),
                    updatedAt: DateTime(2026, 7, 16, 9),
                    vectorClock: null,
                  )
                  as AgentStateEntity;
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => state);
          var refreshNotifications = 0;
          orchestrator =
              WakeOrchestrator(
                  repository: mockRepository,
                  queue: queue,
                  runner: runner,
                  syncEntityWriter: (entity) async {
                    state = entity as AgentStateEntity;
                  },
                  onPersistedStateChanged: (_) => refreshNotifications++,
                )
                ..disableAutomaticUpdatesRuntime('agent-1')
                ..addSubscription(makeSub());
          final controller = StreamController<Set<String>>.broadcast();

          await withClock(Clock.fixed(signalAt), () async {
            await orchestrator.start(controller.stream);
            controller.add({'entity-1'});
            await pumpEventQueue();
          });

          expect(queue.isEmpty, isTrue);
          expect(state.reportStaleAt, signalAt);
          expect(state.isReportStale, isTrue);
          expect(refreshNotifications, 1);
          await controller.close();
        },
      );

      test(
        'requestContentWake marks the report stale without queueing '
        'inference when automatic updates are off',
        () async {
          final transcriptAt = DateTime(2026, 7, 17, 10, 15);
          var state =
              AgentDomainEntity.agentState(
                    id: 'state-1',
                    agentId: 'agent-1',
                    slots: const AgentSlots(activeTaskId: 'entity-1'),
                    updatedAt: DateTime(2026, 7, 17, 10),
                    vectorClock: null,
                  )
                  as AgentStateEntity;
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => state);
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            syncEntityWriter: (entity) async {
              state = entity as AgentStateEntity;
            },
          )..disableAutomaticUpdatesRuntime('agent-1');

          late bool woken;
          await withClock(Clock.fixed(transcriptAt), () async {
            woken = orchestrator.requestContentWake(
              agentId: 'agent-1',
              reason: WakeReason.transcriptionComplete.name,
              triggerTokens: {'entity-1', 'audio-1'},
            );
            await pumpEventQueue();
          });

          expect(woken, isFalse);
          expect(queue.isEmpty, isTrue);
          expect(state.reportStaleAt, transcriptAt);
          expect(state.isReportStale, isTrue);
        },
      );

      test(
        'requestContentWake enqueues an automation-initiated wake when '
        'automatic updates are on',
        () async {
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
          );
          // Hold the single-flight lock so the job stays observable in the
          // queue instead of being drained immediately.
          expect(await runner.tryAcquire('agent-1'), isTrue);

          final woken = orchestrator.requestContentWake(
            agentId: 'agent-1',
            reason: WakeReason.transcriptionComplete.name,
            triggerTokens: {'entity-1', 'audio-1'},
          );
          await pumpEventQueue();

          expect(woken, isTrue);
          expect(queue.length, 1);
          final job = queue.dequeue();
          expect(job?.reason, WakeReason.transcriptionComplete.name);
          expect(job?.triggerTokens, {'entity-1', 'audio-1'});
          // Automation-initiated so a later toggle-off sweeps it from the
          // queue together with other automatic jobs.
          expect(job?.initiator, WakeInitiator.automation);
          runner.release('agent-1');
        },
      );

      test(
        'successful manual wake acknowledges changes seen before it began',
        () async {
          final staleAt = DateTime(2026, 7, 16, 8, 59);
          final refreshStartedAt = DateTime(2026, 7, 16, 9);
          var state =
              AgentDomainEntity.agentState(
                    id: 'state-1',
                    agentId: 'agent-1',
                    slots: const AgentSlots(activeTaskId: 'entity-1'),
                    updatedAt: staleAt,
                    vectorClock: null,
                    reportStaleAt: staleAt,
                  )
                  as AgentStateEntity;
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => state);
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            syncEntityWriter: (entity) async {
              state = entity as AgentStateEntity;
            },
            wakeExecutor: noOpExecutor,
          );
          queue.enqueue(
            WakeJob(
              runKey: 'manual-refresh',
              agentId: 'agent-1',
              reason: WakeReason.reanalysis.name,
              initiator: WakeInitiator.user,
              triggerTokens: const {},
              createdAt: refreshStartedAt,
            ),
          );

          await withClock(
            Clock.fixed(refreshStartedAt),
            orchestrator.processNext,
          );

          expect(state.reportFreshAt, refreshStartedAt);
          expect(state.isReportStale, isFalse);
        },
      );

      test(
        'change observed during a manual wake remains stale afterward',
        () async {
          final refreshStartedAt = DateTime(2026, 7, 16, 9);
          final changeDuringWakeAt = DateTime(2026, 7, 16, 9, 1);
          var now = refreshStartedAt;
          var state =
              AgentDomainEntity.agentState(
                    id: 'state-1',
                    agentId: 'agent-1',
                    slots: const AgentSlots(activeTaskId: 'entity-1'),
                    updatedAt: refreshStartedAt,
                    vectorClock: null,
                  )
                  as AgentStateEntity;
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => state);
          final controller = StreamController<Set<String>>.broadcast();
          orchestrator =
              WakeOrchestrator(
                  repository: mockRepository,
                  queue: queue,
                  runner: runner,
                  syncEntityWriter: (entity) async {
                    state = entity as AgentStateEntity;
                  },
                  wakeExecutor: (_, _, _, _) async {
                    now = changeDuringWakeAt;
                    controller.add({'entity-1'});
                    await pumpEventQueue();
                    return null;
                  },
                )
                ..disableAutomaticUpdatesRuntime('agent-1')
                ..addSubscription(makeSub());
          queue.enqueue(
            WakeJob(
              runKey: 'manual-with-concurrent-change',
              agentId: 'agent-1',
              reason: WakeReason.reanalysis.name,
              initiator: WakeInitiator.user,
              triggerTokens: const {},
              createdAt: refreshStartedAt,
            ),
          );

          await withClock(Clock(() => now), () async {
            await orchestrator.start(controller.stream);
            await orchestrator.processNext();
          });

          expect(state.reportFreshAt, refreshStartedAt);
          expect(state.reportStaleAt, changeDuringWakeAt);
          expect(state.isReportStale, isTrue);
          await controller.close();
        },
      );

      test(
        'freshness writes serialize a delayed stale update before wake success',
        () async {
          final refreshStartedAt = DateTime(2026, 7, 16, 9);
          final changeDuringWakeAt = DateTime(2026, 7, 16, 9, 1);
          final staleWriteStarted = Completer<void>();
          final releaseStaleWrite = Completer<void>();
          var now = refreshStartedAt;
          var state =
              AgentDomainEntity.agentState(
                    id: 'state-1',
                    agentId: 'agent-1',
                    slots: const AgentSlots(activeTaskId: 'entity-1'),
                    updatedAt: refreshStartedAt,
                    vectorClock: null,
                    reportStaleAt: refreshStartedAt,
                  )
                  as AgentStateEntity;
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => state);
          final controller = StreamController<Set<String>>.broadcast();
          orchestrator =
              WakeOrchestrator(
                  repository: mockRepository,
                  queue: queue,
                  runner: runner,
                  syncEntityWriter: (entity) async {
                    final next = entity as AgentStateEntity;
                    if (next.reportStaleAt == changeDuringWakeAt &&
                        next.reportFreshAt == null) {
                      staleWriteStarted.complete();
                      await releaseStaleWrite.future;
                    }
                    state = next;
                  },
                  wakeExecutor: (_, _, _, _) async {
                    now = changeDuringWakeAt;
                    controller.add({'entity-1'});
                    await pumpEventQueue();
                    return null;
                  },
                )
                ..disableAutomaticUpdatesRuntime('agent-1')
                ..addSubscription(makeSub());
          queue.enqueue(
            WakeJob(
              runKey: 'manual-with-delayed-stale-write',
              agentId: 'agent-1',
              reason: WakeReason.reanalysis.name,
              initiator: WakeInitiator.user,
              triggerTokens: const {},
              createdAt: refreshStartedAt,
            ),
          );

          await withClock(Clock(() => now), () async {
            await orchestrator.start(controller.stream);
            final wake = orchestrator.processNext();
            await staleWriteStarted.future;
            releaseStaleWrite.complete();
            await wake;
          });

          expect(state.reportFreshAt, refreshStartedAt);
          expect(state.reportStaleAt, changeDuringWakeAt);
          expect(state.isReportStale, isTrue);
          await controller.close();
        },
      );

      test('removeSubscription removes only the named subscription', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..addSubscription(
              makeSub(id: 'sub-2', matchEntityIds: {'entity-2'}),
            )
            // Drop the second subscription; the first must keep firing so a
            // per-link delete on agent-1 does not silence the agent's other
            // subscriptions or its per-agent throttle/suppression state.
            ..removeSubscription('sub-2');

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1', 'entity-2'});

          final captured = captureSingleWakeRun(mockRepository);
          expect(captured.agentId, 'agent-1');
          expect(captured.reasonId, 'sub-1');

          controller.close();
        });
      });
    });

    group('notification matching', () {
      test('ignores tokens that do not match any subscription', () {
        fakeAsync((async) {
          orchestrator.addSubscription(makeSub());

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-99', 'entity-100'});

          expect(queue.isEmpty, isTrue);

          controller.close();
        });
      });

      test('enqueues job when tokens match subscription', () {
        fakeAsync((async) {
          final capturedEntries = stubInsertCapture(mockRepository);

          orchestrator.addSubscription(
            makeSub(matchEntityIds: {'entity-1', 'entity-2'}),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-2', 'other-entity'});

          // Deferred drain consumes the job; verify the persisted entry.
          expect(capturedEntries, hasLength(1));
          expect(capturedEntries.first.agentId, 'agent-1');

          controller.close();
        });
      });

      test('matches multiple subscriptions in a single batch', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..addSubscription(
              makeSub(
                id: 'sub-2',
                agentId: 'agent-2',
                matchEntityIds: {'entity-2'},
              ),
            );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1', 'entity-2'});

          // Deferred drain processes all ready jobs.
          final captured = captureWakeRuns(mockRepository);

          expect(captured.length, equals(2));
          final ids = captured.map((e) => e.agentId).toSet();
          expect(ids, containsAll(['agent-1', 'agent-2']));

          controller.close();
        });
      });
    });

    group('predicate filtering', () {
      test('skips subscription when predicate returns false', () {
        fakeAsync((async) {
          orchestrator.addSubscription(
            makeSub(predicate: (tokens) => false),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1'});

          expect(queue.isEmpty, isTrue);

          controller.close();
        });
      });

      test('allows subscription when predicate returns true', () {
        fakeAsync((async) {
          orchestrator.addSubscription(
            makeSub(predicate: (tokens) => tokens.contains('entity-1')),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1'});

          // Deferred drain consumed the job and persisted a wake run.
          verify(
            () => mockRepository.insertWakeRun(
              entry: any(named: 'entry'),
            ),
          ).called(1);

          controller.close();
        });
      });

      test('predicate receives only matched tokens, not the full batch', () {
        fakeAsync((async) {
          Set<String>? receivedTokens;

          // Subscription matches only entity-1 and entity-2.
          orchestrator.addSubscription(
            makeSub(
              matchEntityIds: {'entity-1', 'entity-2'},
              predicate: (tokens) {
                receivedTokens = tokens;
                return true;
              },
            ),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Batch contains entity-1 (matches) plus entity-99 and entity-100
          // (do not match the subscription). The predicate should only see
          // the intersection: {entity-1}.
          emitAndDrain(
            async,
            controller,
            {'entity-1', 'entity-99', 'entity-100'},
          );

          expect(
            receivedTokens,
            equals({'entity-1'}),
            reason:
                'Predicate must receive only the tokens that matched '
                "the subscription's entityIds, not the entire batch",
          );

          controller.close();
        });
      });
    });

    group('self-notification suppression', () {
      test('suppresses wake when all matched tokens were self-mutated', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(
              makeSub(matchEntityIds: {'entity-1', 'entity-2'}),
            )
            ..recordMutatedEntities('agent-1', {
              'entity-1': const VectorClock({'node-1': 1}),
              'entity-2': const VectorClock({'node-1': 2}),
            });

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1', 'entity-2'});

          // Prove suppression prevented the wake — not just that the queue
          // drained via processNext.
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          controller.close();
        });
      });

      test('allows wake when some matched tokens are external', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(
              makeSub(matchEntityIds: {'entity-1', 'entity-2'}),
            )
            ..recordMutatedEntities('agent-1', {
              'entity-1': const VectorClock({'node-1': 1}),
            });

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          // entity-1 is self-mutated, entity-2 is external
          emitAndDrain(async, controller, {'entity-1', 'entity-2'});

          // Deferred drain consumed the job and persisted a wake run.
          verify(
            () => mockRepository.insertWakeRun(
              entry: any(named: 'entry'),
            ),
          ).called(1);

          controller.close();
        });
      });

      test('does not suppress when agent has no mutation records', () {
        fakeAsync((async) {
          orchestrator.addSubscription(makeSub());

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1'});

          // Deferred drain consumed the job and persisted a wake run.
          verify(
            () => mockRepository.insertWakeRun(
              entry: any(named: 'entry'),
            ),
          ).called(1);

          controller.close();
        });
      });

      test('expires suppression after TTL elapses', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..recordMutatedEntities('agent-1', {
              'entity-1': const VectorClock({'node-1': 1}),
            });

          // Advance past the 5-second suppression TTL.
          async.elapse(const Duration(seconds: 6));

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1'});

          // Suppression should have expired — wake should proceed.
          verify(
            () => mockRepository.insertWakeRun(
              entry: any(named: 'entry'),
            ),
          ).called(1);

          controller.close();
        });
      });

      test('does not expire suppression within TTL', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..recordMutatedEntities('agent-1', {
              'entity-1': const VectorClock({'node-1': 1}),
            });

          // Only 2 seconds — within the 5-second TTL.
          async.elapse(const Duration(seconds: 2));

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1'});

          // Prove suppression prevented the wake — not just that the queue
          // drained via processNext.
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          controller.close();
        });
      });

      test('suppression is per-agent', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(makeSub())
            ..addSubscription(
              makeSub(id: 'sub-2', agentId: 'agent-2'),
            )
            ..recordMutatedEntities('agent-1', {
              'entity-1': const VectorClock({'node-1': 1}),
            });

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitAndDrain(async, controller, {'entity-1'});

          // agent-1 is suppressed, agent-2 is not; deferred drain persists
          // only agent-2's run.
          final captured = captureSingleWakeRun(mockRepository);
          expect(captured.agentId, 'agent-2');

          controller.close();
        });
      });
    });

    group('token merging / coalescing', () {
      test('merges tokens into existing queued job for same agent', () {
        fakeAsync((async) {
          // Pre-lock agent-1 so the first job gets deferred (stays in queue).
          // The second batch can then merge into the queued job.
          runner.tryAcquire('agent-1');
          async.flushMicrotasks();

          orchestrator.addSubscription(
            makeSub(matchEntityIds: {'entity-1', 'entity-2'}),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // First batch enqueues a job (entity-1 matches).
          emitTokens(async, controller, {'entity-1'});
          // Job is deferred because agent-1 is locked, so it stays in queue.

          // Second batch should merge into the existing queued job.
          emitTokens(async, controller, {'entity-2'});

          // Queue should have exactly one job (merged), not two.
          expect(queue.length, 1);
          final job = queue.dequeue()!;
          expect(job.agentId, 'agent-1');
          expect(
            job.triggerTokens,
            containsAll(['entity-1', 'entity-2']),
            reason:
                'Second batch tokens should have been merged into the '
                'existing queued job',
          );

          // No wake runs should have been persisted (agent was locked).
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          runner.release('agent-1');
          controller.close();
        });
      });
    });

    group('lifecycle', () {
      test('start subscribes to notification stream', () {
        fakeAsync((async) {
          orchestrator.addSubscription(makeSub());

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          emitAndDrain(async, controller, {'entity-1'});

          // Deferred drain consumed the job and persisted a wake run.
          verify(
            () => mockRepository.insertWakeRun(
              entry: any(named: 'entry'),
            ),
          ).called(1);

          controller.close();
        });
      });

      // Uses real async (not fakeAsync) because StreamSubscription.cancel()
      // on broadcast streams does not resolve within fakeAsync.flushMicrotasks.
      // With defer-first throttling, subscription wakes are not dispatched
      // immediately — this test only verifies stream attachment/detachment
      // by checking that _onBatch fires (enqueue) vs not (old stream ignored).
      test('start replaces previous subscription when called twice', () async {
        orchestrator.addSubscription(makeSub());

        final controller1 = StreamController<Set<String>>.broadcast();
        final controller2 = StreamController<Set<String>>.broadcast();

        await orchestrator.start(controller1.stream);
        expect(controller1.hasListener, isTrue);

        // Calling start again cancels the first subscription.
        await orchestrator.start(controller2.stream);

        // The old subscription was actually cancelled, not just ignored.
        expect(controller1.hasListener, isFalse);
        expect(controller2.hasListener, isTrue);

        // Emit on the old stream — should NOT enqueue anything.
        controller1.add({'entity-1'});
        await pumpEventQueue();
        expect(queue.isEmpty, isTrue);

        // Emit on the new stream — should enqueue a job (deferred).
        controller2.add({'entity-1'});
        await pumpEventQueue();
        // Job is enqueued but not yet executed (deferred by throttle).
        expect(queue.length, 1);

        await controller1.close();
        await controller2.close();
      });

      test('stop cancels notification subscription', () {
        fakeAsync((async) {
          orchestrator.addSubscription(makeSub());

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator
            ..start(controller.stream)
            ..stop();
          async.flushMicrotasks();

          emitTokens(async, controller, {'entity-1'});
          expect(queue.isEmpty, isTrue);

          controller.close();
        });
      });
    });
    group('AgentSubscription', () {
      test('stores all fields correctly', () {
        final seenTokens = <Set<String>>[];
        bool recordingPredicate(Set<String> tokens) {
          seenTokens.add(tokens);
          return tokens.contains('e-1');
        }

        final sub = AgentSubscription(
          id: 'sub-1',
          agentId: 'agent-1',
          matchEntityIds: {'e-1', 'e-2'},
          predicate: recordingPredicate,
        );

        expect(sub.id, 'sub-1');
        expect(sub.agentId, 'agent-1');
        expect(sub.matchEntityIds, {'e-1', 'e-2'});
        // Drive the stored predicate instead of a presence-only check: it must
        // be the exact function passed in, receiving the tokens and returning
        // its result verbatim.
        expect(sub.predicate!({'e-1'}), isTrue);
        expect(sub.predicate!({'other'}), isFalse);
        expect(seenTokens, [
          {'e-1'},
          {'other'},
        ]);
      });

      test('predicate is optional and defaults to null', () {
        final sub = AgentSubscription(
          id: 'sub-1',
          agentId: 'agent-1',
          matchEntityIds: {'e-1'},
        );

        expect(sub.predicate, isNull);
      });
    });
  });
}
