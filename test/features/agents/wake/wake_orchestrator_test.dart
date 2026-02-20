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

          expect(queue.isEmpty, isFalse);
          final job = queue.dequeue()!;
          expect(job.agentId, 'agent-1');
          expect(job.reason, 'subscription');
          expect(job.reasonId, 'sub-1');

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

          // Only agent-2's subscription should fire
          expect(queue.length, 1);
          expect(queue.dequeue()!.agentId, 'agent-2');

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

          expect(queue.length, 1);
          final job = queue.dequeue()!;
          expect(job.agentId, 'agent-1');
          expect(job.triggerTokens, equals({'entity-2'}));

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

          expect(queue.length, 2);
          final ids = {queue.dequeue()!.agentId, queue.dequeue()!.agentId};
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

          expect(queue.length, 1);

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

          expect(queue.length, 1);

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

          expect(queue.length, 1);

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

          // agent-1 is suppressed, agent-2 is not
          expect(queue.length, 1);
          expect(queue.dequeue()!.agentId, 'agent-2');

          controller.close();
        });
      });
    });

    group('token merging / coalescing', () {
      test('merges tokens into existing queued job for same agent', () {
        fakeAsync((async) {
          orchestrator.addSubscription(
            AgentSubscription(
              id: 'sub-1',
              agentId: 'agent-1',
              matchEntityIds: {'entity-1', 'entity-2'},
            ),
          );

          final controller = StreamController<Set<String>>.broadcast();
          orchestrator.start(controller.stream);

          // First batch enqueues a new job
          emitTokens(async, controller, {'entity-1'});
          expect(queue.length, 1);

          // Second batch merges into the existing job
          emitTokens(async, controller, {'entity-2'});
          expect(queue.length, 1);

          final job = queue.dequeue()!;
          expect(job.triggerTokens, containsAll(['entity-1', 'entity-2']));

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
          expect(queue.length, 1);

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
          queue
            ..enqueue(job)
            // Clear history so the re-enqueue inside processNext succeeds
            // (the same run key would otherwise be rejected as a duplicate).
            ..clearHistory();

          orchestrator.processNext();
          async.flushMicrotasks();

          // Job should be back in the queue
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
