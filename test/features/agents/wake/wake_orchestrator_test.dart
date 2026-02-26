import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

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
    // Stub getAgentState for throttle deadline persistence.
    when(() => mockRepository.getAgentState(any()))
        .thenAnswer((_) async => null);
    when(() => mockRepository.upsertEntity(any())).thenAnswer((_) async {});

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

      test('addSubscription replaces existing subscription with same id', () {
        fakeAsync((async) {
          // Add a subscription matching entity-1.
          orchestrator
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            )
            // Replace it with one matching entity-2 (same id).
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-2'},
              ),
            );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // entity-1 should no longer match (replaced).
          emitTokens(async, controller, {'entity-1'});
          expect(queue.isEmpty, isTrue);

          // entity-2 should match (the replacement).
          emitTokens(async, controller, {'entity-2'});
          verify(
            () => mockRepository.insertWakeRun(
              entry: any(named: 'entry'),
            ),
          ).called(1);

          controller.close();
        });
      });

      test(
          'addSubscription with same id does not create duplicates '
          'that cause duplicate wake jobs', () {
        fakeAsync((async) {
          // Add the same subscription twice.
          for (var i = 0; i < 2; i++) {
            orchestrator.addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            );
          }

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1'});

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
          // Pre-lock agent-1 so the first job gets deferred (stays in queue).
          // The second batch can then merge into the queued job.
          runner.tryAcquire('agent-1');
          async.flushMicrotasks();

          orchestrator.addSubscription(
            AgentSubscription(
              id: 'sub-1',
              agentId: 'agent-1',
              matchEntityIds: {'entity-1', 'entity-2'},
            ),
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
            reason: 'Second batch tokens should have been merged into the '
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

      // Uses real async (not fakeAsync) because StreamSubscription.cancel()
      // on broadcast streams does not resolve within fakeAsync.flushMicrotasks.
      test('start replaces previous subscription when called twice', () async {
        orchestrator.addSubscription(
          AgentSubscription(
            id: 'sub-1',
            agentId: 'agent-1',
            matchEntityIds: {'entity-1'},
          ),
        );

        final controller1 = StreamController<Set<String>>.broadcast();
        final controller2 = StreamController<Set<String>>.broadcast();

        await orchestrator.start(controller1.stream);
        // Calling start again cancels the first subscription.
        await orchestrator.start(controller2.stream);

        // Emit on the old stream — should NOT trigger a wake.
        controller1.add({'entity-1'});
        await pumpEventQueue();
        verifyNever(
          () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
        );

        // Emit on the new stream — should trigger a wake.
        controller2.add({'entity-1'});
        await pumpEventQueue();
        verify(
          () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
        ).called(1);

        await controller1.close();
        await controller2.close();
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

          // Clear throttle set by the first subscription wake so the
          // second notification is not blocked by the 300s cooldown.
          orchestrator.clearThrottle('agent-1');

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

      test(
          'mid-execution signals are queued but suppressed during drain '
          'when they match self-mutations', () {
        fakeAsync((async) {
          // Use a completer to pause the executor mid-flight so we can
          // inject a notification that would match the agent's subscription.
          final gate = Completer<Map<String, VectorClock>?>();

          orchestrator
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            )
            ..wakeExecutor = (agentId, runKey, triggers, threadId) {
              return gate.future;
            };

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Fire the first notification to start the executor.
          emitTokens(async, controller, {'entity-1'});

          // Executor is now paused on `gate`. Fire a second notification
          // for the same entity while the agent is executing.
          emitTokens(async, controller, {'entity-1'});

          // The second notification is NOT suppressed by _onBatch (so
          // external signals during execution are preserved). Instead it
          // is queued and will be suppressed during the drain re-check
          // using the pre-registered suppression data.
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
          'triggers a second wake', () {
        fakeAsync((async) {
          final gate = Completer<Map<String, VectorClock>?>();

          orchestrator
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1', 'entity-2'},
              ),
            )
            ..wakeExecutor = (agentId, runKey, triggers, threadId) {
              return gate.future;
            };

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // First signal starts execution for entity-1.
          emitTokens(async, controller, {'entity-1'});

          // While executing, an external change to entity-2 arrives.
          emitTokens(async, controller, {'entity-2'});

          // The signal should be queued (not suppressed by _onBatch).
          expect(queue.isEmpty, isFalse);

          // Complete first execution — only entity-1 was mutated.
          gate.complete({
            'entity-1': const VectorClock({'node-1': 1}),
          });
          async.flushMicrotasks();

          // entity-2 was NOT in the mutation set, so it should NOT be
          // suppressed during drain re-check. A second wake should run.
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(2);

          controller.close();
        });
      });

      test(
          'replaces pre-registered suppression with actual mutations '
          'so external changes are not blocked', () {
        fakeAsync((async) {
          // Executor mutates entity-1 but not entity-2.
          orchestrator
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1', 'entity-2'},
              ),
            )
            ..wakeExecutor = (agentId, runKey, triggers, threadId) async {
              // Only entity-1 was actually mutated.
              return {
                'entity-1': const VectorClock({'node-1': 1})
              };
            };

          // Trigger the first execution.
          queue.enqueue(
            WakeJob(
              runKey: 'rk-1',
              agentId: 'agent-1',
              reason: 'subscription',
              triggerTokens: {'entity-1'},
              createdAt: DateTime(2024, 3, 15),
            ),
          );
          orchestrator.processNext();
          async.flushMicrotasks();

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

          // Clear throttle set by the first subscription wake so the
          // second notification is not blocked by the 300s cooldown.
          orchestrator.clearThrottle('agent-1');

          // Now a notification arrives for entity-2 only (external change).
          // It should NOT be suppressed because only entity-1 is in the
          // actual mutation record.
          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-2'});

          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test('catches insertWakeRun failure, releases lock, and continues drain',
          () {
        fakeAsync((async) {
          var insertCallCount = 0;
          when(() => mockRepository.insertWakeRun(entry: any(named: 'entry')))
              .thenAnswer((_) async {
            insertCallCount++;
            if (insertCallCount == 1) throw Exception('DB failure');
          });

          // Enqueue two jobs for different agents.
          queue
            ..enqueue(
              WakeJob(
                runKey: 'rk-fail',
                agentId: 'agent-1',
                reason: 'subscription',
                triggerTokens: {'tok-a'},
                createdAt: DateTime(2024, 3, 15),
              ),
            )
            ..enqueue(
              WakeJob(
                runKey: 'rk-ok',
                agentId: 'agent-2',
                reason: 'subscription',
                triggerTokens: {'tok-b'},
                createdAt: DateTime(2024, 3, 15),
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
      });

      test('suppresses deferred subscription job that becomes self-mutated',
          () {
        fakeAsync((async) {
          // Agent-1 is busy (pre-locked). A subscription job is enqueued and
          // deferred because the agent is running. While deferred, the
          // orchestrator records mutations that cover all trigger tokens.
          // When the deferred job is re-processed, the drain suppression
          // re-check should skip it.

          final gate = Completer<Map<String, VectorClock>?>();
          orchestrator
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            )
            ..wakeExecutor = (agentId, runKey, triggers, threadId) {
              if (runKey.contains('manual')) {
                return gate.future;
              }
              return Future.value();
            };

          // Enqueue a manual wake that will hold the lock.
          final manualJob = WakeJob(
            runKey: 'manual-rk',
            agentId: 'agent-1',
            reason: 'manual',
            triggerTokens: <String>{},
            createdAt: DateTime(2024, 3, 15),
          );
          queue.enqueue(manualJob);
          orchestrator.processNext();
          async.flushMicrotasks();

          // Agent-1 is now busy executing the manual job.
          // Enqueue a subscription job that will be deferred.
          final subJob = WakeJob(
            runKey: 'sub-rk',
            agentId: 'agent-1',
            reason: 'subscription',
            triggerTokens: {'entity-1'},
            createdAt: DateTime(2024, 3, 15),
          );
          queue.enqueue(subJob);
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
          final captured = verify(
            () => mockRepository.insertWakeRun(
              entry: captureAny(named: 'entry'),
            ),
          ).captured.cast<WakeRunLogData>();

          // Only the manual wake run should have been persisted;
          // the subscription job should have been suppressed at re-check.
          expect(captured.length, 1);
          expect(captured.first.reason, 'manual');
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

          // Both locks should be released.
          expect(runner.isRunning('agent-1'), isFalse);
          expect(runner.isRunning('agent-2'), isFalse);
          // Agent-2's status update should have succeeded.
          expect(updateCallCount, 2);
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
            return Future.value();
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

          orchestrator.wakeExecutor =
              (agentId, runKey, triggers, threadId) async => null;
          // ignore: cascade_invocations
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

          // Clear throttle so the second notification is not blocked.
          orchestrator.clearThrottle('agent-1');

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

          orchestrator.wakeExecutor =
              (agentId, runKey, triggers, threadId) async => null;
          // ignore: cascade_invocations
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
          // ignore: cascade_invocations
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

    group('post-execution drain', () {
      test('schedules drain after job completes to pick up deferred work', () {
        fakeAsync((async) {
          final gate = Completer<Map<String, VectorClock>?>();
          var executionCount = 0;

          orchestrator.wakeExecutor =
              (agentId, runKey, triggers, threadId) async {
            executionCount++;
            if (executionCount == 1) return gate.future;
            return null;
          };

          // First job starts executing (holds agent-1's lock).
          queue.enqueue(
            WakeJob(
              runKey: 'rk-1',
              agentId: 'agent-1',
              reason: 'manual',
              triggerTokens: <String>{},
              createdAt: DateTime(2024, 3, 15),
            ),
          );
          orchestrator.processNext();
          async.flushMicrotasks();
          expect(executionCount, 1);

          // While agent-1 is executing, enqueue a second job for agent-1.
          // processNext defers it because agent-1 is busy.
          queue.enqueue(
            WakeJob(
              runKey: 'rk-2',
              agentId: 'agent-1',
              reason: 'manual',
              triggerTokens: <String>{},
              createdAt: DateTime(2024, 3, 15),
            ),
          );
          orchestrator.processNext();
          async.flushMicrotasks();

          // Only the first job has executed.
          expect(executionCount, 1);

          // Complete first execution — deferred job is re-enqueued but not
          // yet picked up (no immediate processNext since drain already ran).
          gate.complete(null);
          async
            ..flushMicrotasks()

            // After 30s, the post-execution timer fires processNext.
            ..elapse(WakeOrchestrator.postExecutionDrainDelay)
            ..flushMicrotasks();

          // The deferred job should now have been processed.
          expect(executionCount, 2);
        });
      });

      test('does not reset existing timer when another job completes', () {
        fakeAsync((async) {
          var executionCount = 0;

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
            )
            ..wakeExecutor = (agentId, runKey, triggers, threadId) async {
              executionCount++;
              return null;
            };

          // Enqueue and process two jobs — both complete, scheduling timer.
          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1', 'entity-2'});
          async.flushMicrotasks();

          // Both executed immediately.
          expect(executionCount, 2);

          // Advance 15 seconds (timer started at ~0s).
          async.elapse(const Duration(seconds: 15));

          // Clear throttle so the next notification is not blocked.
          orchestrator.clearThrottle('agent-1');

          // A new job completes after 15s — timer should NOT be reset.
          emitTokens(async, controller, {'entity-1'});
          async.flushMicrotasks();
          expect(executionCount, 3);

          // Advance remaining 15s to reach original 30s mark.
          async
            ..elapse(const Duration(seconds: 15))
            ..flushMicrotasks();

          // Timer should fire at original 30s, not 30s after the 3rd job.
          // This verifies the timer was not reset.
          controller.close();
        });
      });

      test('stop cancels pending drain timer', () {
        fakeAsync((async) {
          orchestrator.wakeExecutor =
              (agentId, runKey, triggers, threadId) async => null;

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

          // Timer is now pending. Stop the orchestrator.
          orchestrator.stop();
          async.flushMicrotasks();

          // Advance past the drain delay — timer should not fire.
          clearInteractions(mockRepository);
          async
            ..elapse(WakeOrchestrator.postExecutionDrainDelay * 2)
            ..flushMicrotasks();

          // No additional processNext should have been triggered.
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );
        });
      });
    });

    group('throttle gate', () {
      test('subscription wake sets throttle deadline', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            )
            ..wakeExecutor =
                (agentId, runKey, triggers, threadId) async => null;

          // Stub getAgentState for _setThrottleDeadline persistence.
          when(() => mockRepository.getAgentState('agent-1'))
              .thenAnswer((_) async => null);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1'});

          // First wake should execute.
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          // Second notification within 300s should be throttled.
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

          emitTokens(async, controller, {'entity-1'});

          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          controller.close();
        });
      });

      test('manual wake clears throttle and executes immediately', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            )
            ..wakeExecutor =
                (agentId, runKey, triggers, threadId) async => null;

          when(() => mockRepository.getAgentState('agent-1'))
              .thenAnswer((_) async => null);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // First subscription wake sets throttle.
          emitTokens(async, controller, {'entity-1'});

          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          // Manual wake should bypass throttle.
          orchestrator.enqueueManualWake(
            agentId: 'agent-1',
            reason: 'reanalysis',
          );
          async.flushMicrotasks();

          // Manual wake run should have been persisted.
          final captured = verify(
            () => mockRepository.insertWakeRun(
              entry: captureAny(named: 'entry'),
            ),
          ).captured.cast<WakeRunLogData>();
          expect(captured.any((e) => e.reason == 'reanalysis'), isTrue);

          controller.close();
        });
      });

      test('throttle expires after throttleWindow elapses', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            )
            ..wakeExecutor =
                (agentId, runKey, triggers, threadId) async => null;

          when(() => mockRepository.getAgentState('agent-1'))
              .thenAnswer((_) async => null);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // First wake sets throttle.
          emitTokens(async, controller, {'entity-1'});

          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          // Advance past throttle window.
          async
            ..elapse(
              WakeOrchestrator.throttleWindow + const Duration(seconds: 1),
            )
            ..flushMicrotasks();

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
          when(() => mockRepository.getAgentState('agent-1'))
              .thenAnswer((_) async => null);

          // Notification should now proceed.
          emitTokens(async, controller, {'entity-1'});

          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test('deferred timer fires processNext after throttle window', () {
        fakeAsync((async) {
          var executionCount = 0;

          orchestrator
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            )
            ..wakeExecutor = (agentId, runKey, triggers, threadId) async {
              executionCount++;
              return null;
            };

          when(() => mockRepository.getAgentState('agent-1'))
              .thenAnswer((_) async => null);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // First wake executes.
          emitTokens(async, controller, {'entity-1'});
          expect(executionCount, 1);

          // Advance to throttle deadline — deferred timer should fire.
          async
            ..elapse(WakeOrchestrator.throttleWindow)
            ..flushMicrotasks();

          // The deferred drain fired processNext; queue was empty so
          // no additional execution, but the throttle is now cleared.
          // A new notification should now succeed.
          emitTokens(async, controller, {'entity-1'});
          expect(executionCount, 2);

          controller.close();
        });
      });

      test('creation wake does NOT set throttle', () {
        fakeAsync((async) {
          orchestrator.wakeExecutor =
              (agentId, runKey, triggers, threadId) async => null;

          // ignore: cascade_invocations
          orchestrator
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            )
            ..enqueueManualWake(
              agentId: 'agent-1',
              reason: 'creation',
              triggerTokens: {'task-1'},
            );
          async.flushMicrotasks();

          // Subscription notification should still proceed (not throttled).
          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1'});

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
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            )
            ..wakeExecutor =
                (agentId, runKey, triggers, threadId) async => null;

          when(() => mockRepository.getAgentState('agent-1'))
              .thenAnswer((_) async => null);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // First wake sets throttle.
          emitTokens(async, controller, {'entity-1'});

          // Remove and re-add subscription — throttle should be cleared.
          orchestrator
            ..removeSubscriptions('agent-1')
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1b',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            );

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
          when(() => mockRepository.getAgentState('agent-1'))
              .thenAnswer((_) async => null);

          emitTokens(async, controller, {'entity-1'});

          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test('setThrottleDeadline hydrates throttle from persisted state', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            )
            ..wakeExecutor =
                (agentId, runKey, triggers, threadId) async => null;

          // Hydrate a throttle deadline 120 seconds in the future.
          final deadline = clock.now().add(const Duration(seconds: 120));
          orchestrator.setThrottleDeadline('agent-1', deadline);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Notification should be throttled.
          emitTokens(async, controller, {'entity-1'});
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          // Advance past deadline — should no longer be throttled.
          async
            ..elapse(const Duration(seconds: 121))
            ..flushMicrotasks();

          emitTokens(async, controller, {'entity-1'});
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test('setThrottleDeadline ignores past deadlines', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            )
            ..wakeExecutor =
                (agentId, runKey, triggers, threadId) async => null;

          // Set a past deadline — should be ignored.
          final pastDeadline =
              clock.now().subtract(const Duration(seconds: 10));
          orchestrator.setThrottleDeadline('agent-1', pastDeadline);

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // Should NOT be throttled.
          emitTokens(async, controller, {'entity-1'});
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          controller.close();
        });
      });

      test('stop cancels deferred drain timers', () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            )
            ..wakeExecutor =
                (agentId, runKey, triggers, threadId) async => null;

          when(() => mockRepository.getAgentState('agent-1'))
              .thenAnswer((_) async => null);

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
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            )
            ..wakeExecutor =
                (agentId, runKey, triggers, threadId) async => null;

          final existingState = makeTestState(
            id: 'state-agent-1',
            agentId: 'agent-1',
          );
          when(() => mockRepository.getAgentState('agent-1'))
              .thenAnswer((_) async => existingState);
          when(() => mockRepository.upsertEntity(any()))
              .thenAnswer((_) async {});

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1'});

          final captured = verify(
            () => mockRepository.upsertEntity(captureAny()),
          ).captured;
          expect(captured, hasLength(1));

          final persisted = captured.first as AgentStateEntity;
          expect(persisted.agentId, 'agent-1');
          expect(persisted.nextWakeAt, isNotNull);

          // The persisted deadline should be ~300s in the future.
          final expectedDeadline =
              clock.now().add(WakeOrchestrator.throttleWindow);
          expect(
            persisted.nextWakeAt!.difference(expectedDeadline).inSeconds.abs(),
            lessThan(2),
          );

          controller.close();
        });
      });

      test('_setThrottleDeadline still sets in-memory throttle on DB error',
          () {
        fakeAsync((async) {
          orchestrator
            ..addSubscription(
              AgentSubscription(
                id: 'sub-1',
                agentId: 'agent-1',
                matchEntityIds: {'entity-1'},
              ),
            )
            ..wakeExecutor =
                (agentId, runKey, triggers, threadId) async => null;

          // getAgentState throws to simulate DB failure.
          when(() => mockRepository.getAgentState('agent-1'))
              .thenThrow(Exception('DB error'));

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);
          emitTokens(async, controller, {'entity-1'});

          // First wake executes despite DB error in persistence.
          verify(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          ).called(1);

          // In-memory throttle should still be active — second notification
          // should be dropped.
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

          emitTokens(async, controller, {'entity-1'});
          verifyNever(
            () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
          );

          controller.close();
        });
      });

      test(
        'throttle applies per-agent independently',
        () {
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
              ..wakeExecutor =
                  (agentId, runKey, triggers, threadId) async => null;

            when(() => mockRepository.getAgentState(any()))
                .thenAnswer((_) async => null);

            final controller = StreamController<Set<String>>.broadcast();
            orchestrator.start(controller.stream);

            // Both agents execute on the first notification.
            emitTokens(async, controller, {'entity-1'});
            final firstBatch = verify(
              () => mockRepository.insertWakeRun(
                entry: captureAny(named: 'entry'),
              ),
            ).captured.cast<WakeRunLogData>();
            expect(firstBatch.length, 2);

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

            // Both agents should be throttled now.
            emitTokens(async, controller, {'entity-1'});
            verifyNever(
              () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
            );

            // Clear throttle for agent-1 only.
            orchestrator.clearThrottle('agent-1');

            when(() => mockRepository.getAgentState('agent-1'))
                .thenAnswer((_) async => null);

            emitTokens(async, controller, {'entity-1'});

            // Only agent-1 should run.
            final captured = verify(
              () => mockRepository.insertWakeRun(
                entry: captureAny(named: 'entry'),
              ),
            ).captured.cast<WakeRunLogData>();
            expect(captured.length, 1);
            expect(captured.first.agentId, 'agent-1');

            controller.close();
          });
        },
      );
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
