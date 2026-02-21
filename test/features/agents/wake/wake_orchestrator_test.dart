import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository mockRepository;
  late WakeQueue queue;
  late WakeRunner runner;
  late WakeOrchestrator orchestrator;

  setUp(() {
    mockRepository = MockAgentRepository();
    queue = WakeQueue();
    runner = WakeRunner();

    // Default stubs so that processNext (called automatically from _onBatch)
    // does not fail on unstubbed mock methods.
    when(() => mockRepository.insertWakeRun(entry: any(named: 'entry')))
        .thenAnswer((_) async {});
    when(
      () => mockRepository.updateWakeRunStatus(
        any(),
        any(),
        completedAt: any(named: 'completedAt'),
        errorMessage: any(named: 'errorMessage'),
      ),
    ).thenAnswer((_) async {});

    orchestrator = WakeOrchestrator(
      repository: mockRepository,
      queue: queue,
      runner: runner,
    );
  });

  tearDown(() async {
    await orchestrator.stop();
  });

  /// Helper: sends [tokens] on [controller] and flushes microtasks so that
  /// the orchestrator's listener fires within `fakeAsync`.
  void emitTokens(
    FakeAsync async,
    StreamController<Set<String>> controller,
    Set<String> tokens,
  ) {
    controller.add(tokens);
    async.flushMicrotasks();
  }

  group('WakeOrchestrator', () {
    group('subscription management', () {
      test('addSubscription registers a subscription', () {
        fakeAsync((async) {
          orchestrator.addSubscription(
            AgentSubscription(
              id: 'sub-1',
              agentId: 'agent-1',
              matchEntityIds: {'entity-1'},
            ),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1'});

          // processNext fires automatically from _onBatch, consuming the job
          // and persisting a wake run entry.
          final captured = verify(
            () => mockRepository.insertWakeRun(
              entry: captureAny(named: 'entry'),
            ),
          ).captured.single as WakeRunLogData;
          expect(captured.agentId, 'agent-1');
          expect(captured.reason, 'subscription');
          expect(captured.reasonId, 'sub-1');

          controller.close();
        });
      });

      test('removeSubscriptions removes all subscriptions for an agent', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            )
            ..addSubscription(
              AgentSubscription(
                id: 'sub-2',
                agentId: 'agent-1',
                matchEntityIds: {'entity-2'},
              ),
            )
            ..addSubscription(
              AgentSubscription(
                id: 'sub-3',
                agentId: 'agent-2',
                matchEntityIds: {'entity-1'},
              ),
            )
            ..removeSubscriptions('agent-1');

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1', 'entity-2'});

          // Only agent-2's subscription should fire; processNext consumes it.
          final captured = verify(
            () => mockRepository.insertWakeRun(
              entry: captureAny(named: 'entry'),
            ),
          ).captured.single as WakeRunLogData;
          expect(captured.agentId, 'agent-2');

          controller.close();
        });
      });
    });

    group('notification matching', () {
      test('ignores tokens that do not match any subscription', () {
        fakeAsync((async) {
          orchestrator.addSubscription(
            AgentSubscription(
              id: 'sub-1',
              agentId: 'agent-1',
              matchEntityIds: {'entity-1'},
            ),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-99', 'entity-100'});

          expect(queue.isEmpty, isTrue);

          controller.close();
        });
      });

      test('enqueues job when tokens match subscription', () {
        fakeAsync((async) {
          WakeRunLogData? capturedEntry;
          when(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).thenAnswer((invocation) async {
            capturedEntry = invocation.namedArguments[#entry] as WakeRunLogData;
          });

          orchestrator.addSubscription(
            AgentSubscription(
              id: 'sub-1',
              agentId: 'agent-1',
              matchEntityIds: {'entity-1', 'entity-2'},
            ),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-2', 'other-entity'});

          // processNext consumes the job; verify the persisted entry.
          expect(capturedEntry, isNotNull);
          expect(capturedEntry!.agentId, 'agent-1');

          controller.close();
        });
      });

      test('matches multiple subscriptions in a single batch', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            )
            ..addSubscription(
              AgentSubscription(
                id: 'sub-2',
                agentId: 'agent-2',
                matchEntityIds: {'entity-2'},
              ),
            );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1', 'entity-2'});

          // processNext now loops, processing all ready jobs in one call.
          final captured = verify(
            () => mockRepository.insertWakeRun(
              entry: captureAny(named: 'entry'),
            ),
          ).captured.cast<WakeRunLogData>();

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
            AgentSubscription(
              id: 'sub-1',
              agentId: 'agent-1',
              matchEntityIds: {'entity-1'},
              predicate: (tokens) => false,
            ),
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
            AgentSubscription(
              id: 'sub-1',
              agentId: 'agent-1',
              matchEntityIds: {'entity-1'},
              predicate: (tokens) => tokens.contains('entity-1'),
            ),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1'});

          // processNext consumed the job and persisted a wake run.
          verify(
            () => mockRepository.insertWakeRun(
              entry: any(named: 'entry'),
            ),
          ).called(1);

          controller.close();
        });
      });
    });

    group('self-notification suppression', () {
      test('suppresses wake when all matched tokens were self-mutated', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1', 'entity-2'},
              ),
            )
            ..recordMutatedEntities('agent-1', {
              'entity-1': const VectorClock({'node-1': 1}),
              'entity-2': const VectorClock({'node-1': 2}),
            });

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1', 'entity-2'});

          expect(queue.isEmpty, isTrue);

          controller.close();
        });
      });

      test('allows wake when some matched tokens are external', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1', 'entity-2'},
              ),
            )
            ..recordMutatedEntities('agent-1', {
              'entity-1': const VectorClock({'node-1': 1}),
            });

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          // entity-1 is self-mutated, entity-2 is external
          emitTokens(async, controller, {'entity-1', 'entity-2'});

          // processNext consumed the job and persisted a wake run.
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
          orchestrator.addSubscription(
            AgentSubscription(
              id: 'sub-1',
              agentId: 'agent-1',
              matchEntityIds: {'entity-1'},
            ),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1'});

          // processNext consumed the job and persisted a wake run.
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
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            )
            ..recordMutatedEntities('agent-1', {
              'entity-1': const VectorClock({'node-1': 1}),
            });

          // Advance past the 5-second suppression TTL.
          async.elapse(const Duration(seconds: 6));

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1'});

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
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            )
            ..recordMutatedEntities('agent-1', {
              'entity-1': const VectorClock({'node-1': 1}),
            });

          // Only 2 seconds — within the 5-second TTL.
          async.elapse(const Duration(seconds: 2));

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1'});

          // Should still be suppressed.
          expect(queue.isEmpty, isTrue);

          controller.close();
        });
      });

      test('suppression is per-agent', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            )
            ..addSubscription(
              AgentSubscription(
                id: 'sub-2',
                agentId: 'agent-2',
                matchEntityIds: {'entity-1'},
              ),
            )
            ..recordMutatedEntities('agent-1', {
              'entity-1': const VectorClock({'node-1': 1}),
            });

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1'});

          // agent-1 is suppressed, agent-2 is not; processNext persists
          // only agent-2's run.
          final captured = verify(
            () => mockRepository.insertWakeRun(
              entry: captureAny(named: 'entry'),
            ),
          ).captured.single as WakeRunLogData;
          expect(captured.agentId, 'agent-2');

          controller.close();
        });
      });
    });

    group('token merging / coalescing', () {
      test('merges tokens into existing queued job for same agent', () {
        fakeAsync((async) {
          WakeRunLogData? capturedEntry;
          when(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).thenAnswer((invocation) async {
            capturedEntry = invocation.namedArguments[#entry] as WakeRunLogData;
          });

          orchestrator.addSubscription(
            AgentSubscription(
              id: 'sub-1',
              agentId: 'agent-1',
              matchEntityIds: {'entity-1', 'entity-2'},
            ),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Emit both batches before flushing so that _onBatch processes them
          // synchronously in sequence: the first enqueues, the second merges
          // into the existing queued job before processNext dequeues it.
          controller
            ..add({'entity-1'})
            ..add({'entity-2'});
          async.flushMicrotasks();

          // processNext should have persisted a single run that includes
          // both trigger tokens (merged before dequeue).
          expect(capturedEntry, isNotNull);
          expect(capturedEntry!.agentId, 'agent-1');

          controller.close();
        });
      });
    });

    group('lifecycle', () {
      test('start subscribes to notification stream', () {
        fakeAsync((async) {
          orchestrator.addSubscription(
            AgentSubscription(
              id: 'sub-1',
              agentId: 'agent-1',
              matchEntityIds: {'entity-1'},
            ),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          emitTokens(async, controller, {'entity-1'});

          // processNext consumed the job and persisted a wake run.
          verify(
            () => mockRepository.insertWakeRun(
              entry: any(named: 'entry'),
            ),
          ).called(1);

          controller.close();
        });
      });

      test('stop cancels notification subscription', () {
        fakeAsync((async) {
          orchestrator.addSubscription(
            AgentSubscription(
              id: 'sub-1',
              agentId: 'agent-1',
              matchEntityIds: {'entity-1'},
            ),
          );

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

      test('reconstructSubscriptions completes without error', () {
        fakeAsync((async) {
          orchestrator.reconstructSubscriptions();
          async.flushMicrotasks();
          // Should complete without throwing
        });
      });
    });

    group('processNext', () {
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
          when(() => mockRepository.insertWakeRun(entry: any(named: 'entry')))
              .thenAnswer((_) async {});

          final job = WakeJob(
            runKey: 'rk-1',
            agentId: 'agent-1',
            reason: 'subscription',
            triggerTokens: {'tok-a'},
            reasonId: 'sub-1',
            createdAt: DateTime(2024, 3, 15),
          );
          queue.enqueue(job);

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

          final job = WakeJob(
            runKey: 'rk-1',
            agentId: 'agent-1',
            reason: 'subscription',
            triggerTokens: {'tok-a'},
            createdAt: DateTime(2024, 3, 15),
          );
          queue.enqueue(job);

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
        fakeAsync((async) {
          WakeRunLogData? capturedEntry;
          when(() => mockRepository.insertWakeRun(entry: any(named: 'entry')))
              .thenAnswer((invocation) async {
            capturedEntry = invocation.namedArguments[#entry] as WakeRunLogData;
          });

          final createdAt = DateTime(2024, 3, 15, 10, 30);
          final job = WakeJob(
            runKey: 'rk-test',
            agentId: 'agent-42',
            reason: 'timer',
            triggerTokens: {'tok-a'},
            reasonId: 'timer-7',
            createdAt: createdAt,
          );
          queue.enqueue(job);

          orchestrator.processNext();
          async.flushMicrotasks();

          expect(capturedEntry, isNotNull);
          expect(capturedEntry!.runKey, 'rk-test');
          expect(capturedEntry!.agentId, 'agent-42');
          expect(capturedEntry!.reason, 'timer');
          expect(capturedEntry!.reasonId, 'timer-7');
          expect(capturedEntry!.threadId, 'rk-test');
          expect(capturedEntry!.status, 'running');
          expect(capturedEntry!.createdAt, createdAt);
          expect(capturedEntry!.startedAt, isNotNull);
        });
      });

      test('marks run as failed when wakeExecutor is null', () {
        fakeAsync((async) {
          // orchestrator created without wakeExecutor (default null)
          final job = WakeJob(
            runKey: 'rk-null',
            agentId: 'agent-1',
            reason: 'subscription',
            triggerTokens: {'tok-a'},
            createdAt: DateTime(2024, 3, 15),
          );
          queue.enqueue(job);

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
          orchestrator.wakeExecutor =
              (agentId, runKey, triggers, threadId) async => null;

          final job1 = WakeJob(
            runKey: 'rk-1',
            agentId: 'agent-1',
            reason: 'subscription',
            triggerTokens: {'tok-a'},
            createdAt: DateTime(2024, 3, 15),
          );
          final job2 = WakeJob(
            runKey: 'rk-2',
            agentId: 'agent-2',
            reason: 'subscription',
            triggerTokens: {'tok-b'},
            createdAt: DateTime(2024, 3, 15),
          );
          queue
            ..enqueue(job1)
            ..enqueue(job2);

          orchestrator.processNext();
          async.flushMicrotasks();

          // Both jobs processed in one call — no starvation.
          final captured = verify(
            () => mockRepository.insertWakeRun(
              entry: captureAny(named: 'entry'),
            ),
          ).captured.cast<WakeRunLogData>();
          expect(captured.length, equals(2));
          expect(
            captured.map((e) => e.agentId).toSet(),
            containsAll(['agent-1', 'agent-2']),
          );
        });
      });

      test('defers busy agent job and processes others', () {
        fakeAsync((async) {
          orchestrator.wakeExecutor =
              (agentId, runKey, triggers, threadId) async => null;

          // Pre-lock agent-1
          runner.tryAcquire('agent-1');
          async.flushMicrotasks();

          final job1 = WakeJob(
            runKey: 'rk-1',
            agentId: 'agent-1',
            reason: 'subscription',
            triggerTokens: {'tok-a'},
            createdAt: DateTime(2024, 3, 15),
          );
          final job2 = WakeJob(
            runKey: 'rk-2',
            agentId: 'agent-2',
            reason: 'subscription',
            triggerTokens: {'tok-b'},
            createdAt: DateTime(2024, 3, 15),
          );
          queue
            ..enqueue(job1)
            ..enqueue(job2);

          orchestrator.processNext();
          async.flushMicrotasks();

          // Only agent-2 processed; agent-1 deferred back to queue.
          final captured = verify(
            () => mockRepository.insertWakeRun(
              entry: captureAny(named: 'entry'),
            ),
          ).captured.cast<WakeRunLogData>();
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
          orchestrator.wakeExecutor =
              (agentId, runKey, triggers, threadId) async => null;

          // Pre-lock agent-1 so its job gets deferred
          runner.tryAcquire('agent-1');
          async.flushMicrotasks();

          queue
            ..enqueue(
              WakeJob(
                runKey: 'rk-1',
                agentId: 'agent-1',
                reason: 'subscription',
                triggerTokens: {'tok-a'},
                createdAt: DateTime(2024, 3, 15),
              ),
            )
            ..enqueue(
              WakeJob(
                runKey: 'rk-2',
                agentId: 'agent-2',
                reason: 'subscription',
                triggerTokens: {'tok-b'},
                createdAt: DateTime(2024, 3, 15),
              ),
            );

          orchestrator.processNext();
          async.flushMicrotasks();

          // Queue is not empty (agent-1 deferred), so history not cleared.
          // Re-enqueueing rk-1 should fail (key still seen).
          final reEnqueued = queue.enqueue(
            WakeJob(
              runKey: 'rk-1',
              agentId: 'agent-1',
              reason: 'subscription',
              triggerTokens: {'tok-a'},
              createdAt: DateTime(2024, 3, 15),
            ),
          );
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
            ..wakeExecutor =
                (agentId, runKey, triggers, threadId) async => null;

          queue.enqueue(
            WakeJob(
              runKey: 'rk-1',
              agentId: 'agent-1',
              reason: 'subscription',
              triggerTokens: {'tok-a'},
              createdAt: DateTime(2024, 3, 15),
            ),
          );

          orchestrator.processNext();
          async.flushMicrotasks();

          // Now entity-1 should no longer be suppressed for agent-1
          orchestrator.addSubscription(
            AgentSubscription(
              id: 'sub-1',
              agentId: 'agent-1',
              matchEntityIds: {'entity-1'},
            ),
          );

          // Clear verify history to isolate the next assertion.
          clearInteractions(mockRepository);
          when(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).thenAnswer((_) async {});
          when(
            () => mockRepository.updateWakeRunStatus(
              any(),
              any(),
              completedAt: any(named: 'completedAt'),
              errorMessage: any(named: 'errorMessage'),
            ),
          ).thenAnswer((_) async {});

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1'});

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
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            )
            ..recordMutatedEntities('agent-1', {
              'entity-1': const VectorClock({'node-1': 1}),
            })
            ..removeSubscriptions('agent-1')
            // Re-add subscription after removal
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1b',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1'});

          // Wake should NOT be suppressed — mutation history was cleared
          // when subscriptions were removed.
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test('releases lock even when repository throws', () {
        fakeAsync((async) {
          when(() => mockRepository.insertWakeRun(entry: any(named: 'entry')))
              .thenAnswer((_) async => throw Exception('DB failure'));

          final job = WakeJob(
            runKey: 'rk-1',
            agentId: 'agent-1',
            reason: 'subscription',
            triggerTokens: {'tok-a'},
            createdAt: DateTime(2024, 3, 15),
          );
          queue.enqueue(job);

          // processNext propagates the exception (try/finally, no catch),
          // but the finally block should still release the lock.
          var threwException = false;
          orchestrator.processNext().catchError((_) {
            threwException = true;
          });
          async.flushMicrotasks();

          expect(threwException, isTrue);
          expect(runner.isRunning('agent-1'), isFalse);
        });
      });

      test('single-flight guard processes jobs enqueued during drain', () {
        fakeAsync((async) {
          // Use a completer to pause the first job mid-execution so we can
          // enqueue a second job while the drain is in-flight.
          final gate = Completer<Map<String, VectorClock>?>();
          var executionCount = 0;

          orchestrator.wakeExecutor = (agentId, runKey, triggers, threadId) {
            executionCount++;
            if (executionCount == 1) return gate.future;
            return Future.value(null);
          };

          // Enqueue and start draining the first job.
          queue.enqueue(
            WakeJob(
              runKey: 'rk-1',
              agentId: 'agent-1',
              reason: 'test',
              triggerTokens: {'tok-a'},
              createdAt: DateTime(2024, 3, 15),
            ),
          );
          orchestrator.processNext();
          async.flushMicrotasks();

          // Drain is blocked on gate. Enqueue a second job for a different
          // agent and call processNext again — the guard should defer it.
          queue.enqueue(
            WakeJob(
              runKey: 'rk-2',
              agentId: 'agent-2',
              reason: 'test',
              triggerTokens: {'tok-b'},
              createdAt: DateTime(2024, 3, 15),
            ),
          );
          orchestrator.processNext();
          async.flushMicrotasks();

          // Only the first job should have started so far.
          expect(executionCount, 1);

          // Complete the first job — the drain should pick up the second.
          gate.complete(null);
          async.flushMicrotasks();

          expect(executionCount, 2);
        });
      });
    });

    group('enqueueManualWake', () {
      test('enqueues a job and triggers processNext', () {
        fakeAsync((async) {
          (orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            wakeExecutor: (agentId, runKey, triggers, threadId) async => null,
          ))
              .enqueueManualWake(
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

      test('uses the provided reason in the wake job', () {
        fakeAsync((async) {
          (orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            wakeExecutor: (agentId, runKey, triggers, threadId) async => null,
          ))
              .enqueueManualWake(
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
          orchestrator = WakeOrchestrator(
            repository: mockRepository,
            queue: queue,
            runner: runner,
            wakeExecutor: (agentId, runKey, triggers, threadId) async => null,
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
    });

    group('monotonic wake counter', () {
      test('identical notifications produce different run keys', () {
        fakeAsync((async) {
          final capturedEntries = <WakeRunLogData>[];
          when(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).thenAnswer((invocation) async {
            capturedEntries.add(
              invocation.namedArguments[#entry] as WakeRunLogData,
            );
          });

          orchestrator
            ..wakeExecutor =
                (agentId, runKey, triggers, threadId) async => null;
          orchestrator.addSubscription(
            AgentSubscription(
              id: 'sub-1',
              agentId: 'agent-1',
              matchEntityIds: {'entity-1'},
            ),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // First notification
          emitTokens(async, controller, {'entity-1'});

          // Second identical notification — must produce a different run key
          emitTokens(async, controller, {'entity-1'});

          expect(capturedEntries.length, equals(2));
          expect(
            capturedEntries[0].runKey,
            isNot(equals(capturedEntries[1].runKey)),
            reason: 'Identical notifications must produce distinct run keys '
                'via the monotonic wake counter',
          );

          controller.close();
        });
      });

      test('removeSubscriptions resets counter for agent', () {
        fakeAsync((async) {
          final capturedEntries = <WakeRunLogData>[];
          when(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).thenAnswer((invocation) async {
            capturedEntries.add(
              invocation.namedArguments[#entry] as WakeRunLogData,
            );
          });

          orchestrator
            ..wakeExecutor =
                (agentId, runKey, triggers, threadId) async => null;
          orchestrator.addSubscription(
            AgentSubscription(
              id: 'sub-1',
              agentId: 'agent-1',
              matchEntityIds: {'entity-1'},
            ),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Fire once to increment counter
          emitTokens(async, controller, {'entity-1'});

          // Remove and re-add subscription (counter resets)
          orchestrator.removeSubscriptions('agent-1');
          orchestrator.addSubscription(
            AgentSubscription(
              id: 'sub-1',
              agentId: 'agent-1',
              matchEntityIds: {'entity-1'},
            ),
          );

          // Fire again — counter is back to 0, same as the initial run key
          emitTokens(async, controller, {'entity-1'});

          expect(capturedEntries.length, equals(2));
          // After reset, the counter starts at 0 again, producing the same
          // run key as the first invocation.
          expect(capturedEntries[0].runKey, equals(capturedEntries[1].runKey));

          controller.close();
        });
      });
    });

    group('AgentSubscription', () {
      test('stores all fields correctly', () {
        bool predicateCalled(Set<String> tokens) => true;
        final sub = AgentSubscription(
          id: 'sub-1',
          agentId: 'agent-1',
          matchEntityIds: {'e-1', 'e-2'},
          predicate: predicateCalled,
        );

        expect(sub.id, 'sub-1');
        expect(sub.agentId, 'agent-1');
        expect(sub.matchEntityIds, {'e-1', 'e-2'});
        expect(sub.predicate, isNotNull);
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
