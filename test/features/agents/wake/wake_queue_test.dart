import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/wake/wake_queue.dart';

enum _GeneratedWakeQueueOperationKind {
  enqueue,
  dequeue,
  mergeTokens,
  removeByAgent,
  requeueLastDequeued,
  clearHistoryWhenEmpty,
}

enum _GeneratedWakeQueueRunKeySlot { first, second, third, fourth }

enum _GeneratedWakeQueueAgentSlot { first, second, third }

enum _GeneratedWakeQueueTokenSlot { first, second, third, fourth }

final _generatedWakeQueueBase = DateTime(2026, 5, 18, 10);

String _generatedWakeQueueRunKey(_GeneratedWakeQueueRunKeySlot slot) =>
    'generated-wake-run-${slot.name}';

String _generatedWakeQueueAgentId(_GeneratedWakeQueueAgentSlot slot) =>
    'generated-wake-agent-${slot.name}';

String _generatedWakeQueueToken(_GeneratedWakeQueueTokenSlot slot) =>
    'generated-wake-token-${slot.name}';

class _GeneratedWakeQueueOperation {
  const _GeneratedWakeQueueOperation({
    required this.kind,
    required this.runKeySlot,
    required this.agentSlot,
    required this.tokenSlot,
  });

  final _GeneratedWakeQueueOperationKind kind;
  final _GeneratedWakeQueueRunKeySlot runKeySlot;
  final _GeneratedWakeQueueAgentSlot agentSlot;
  final _GeneratedWakeQueueTokenSlot tokenSlot;

  String get runKey => _generatedWakeQueueRunKey(runKeySlot);

  String get agentId => _generatedWakeQueueAgentId(agentSlot);

  String get token => _generatedWakeQueueToken(tokenSlot);

  @override
  String toString() {
    return '_GeneratedWakeQueueOperation('
        'kind: $kind, runKeySlot: $runKeySlot, '
        'agentSlot: $agentSlot, tokenSlot: $tokenSlot)';
  }
}

class _GeneratedWakeQueueScenario {
  const _GeneratedWakeQueueScenario({required this.operations});

  final List<_GeneratedWakeQueueOperation> operations;

  @override
  String toString() {
    return '_GeneratedWakeQueueScenario(operations: $operations)';
  }
}

class _GeneratedWakeQueueModelJob {
  _GeneratedWakeQueueModelJob({
    required this.runKey,
    required this.agentId,
    required Set<String> triggerTokens,
  }) : triggerTokens = Set<String>.of(triggerTokens);

  final String runKey;
  final String agentId;
  final Set<String> triggerTokens;
}

class _GeneratedWakeQueueModel {
  final queue = <_GeneratedWakeQueueModelJob>[];
  final seenRunKeys = <String>{};
  _GeneratedWakeQueueModelJob? lastDequeued;
}

extension _AnyGeneratedWakeQueueScenario on glados.Any {
  glados.Generator<_GeneratedWakeQueueOperationKind>
  get wakeQueueOperationKind =>
      glados.AnyUtils(this).choose(_GeneratedWakeQueueOperationKind.values);

  glados.Generator<_GeneratedWakeQueueRunKeySlot> get wakeQueueRunKeySlot =>
      glados.AnyUtils(this).choose(_GeneratedWakeQueueRunKeySlot.values);

  glados.Generator<_GeneratedWakeQueueAgentSlot> get wakeQueueAgentSlot =>
      glados.AnyUtils(this).choose(_GeneratedWakeQueueAgentSlot.values);

  glados.Generator<_GeneratedWakeQueueTokenSlot> get wakeQueueTokenSlot =>
      glados.AnyUtils(this).choose(_GeneratedWakeQueueTokenSlot.values);

  glados.Generator<_GeneratedWakeQueueOperation> get wakeQueueOperation =>
      glados.CombinableAny(this).combine4(
        wakeQueueOperationKind,
        wakeQueueRunKeySlot,
        wakeQueueAgentSlot,
        wakeQueueTokenSlot,
        (
          _GeneratedWakeQueueOperationKind kind,
          _GeneratedWakeQueueRunKeySlot runKeySlot,
          _GeneratedWakeQueueAgentSlot agentSlot,
          _GeneratedWakeQueueTokenSlot tokenSlot,
        ) => _GeneratedWakeQueueOperation(
          kind: kind,
          runKeySlot: runKeySlot,
          agentSlot: agentSlot,
          tokenSlot: tokenSlot,
        ),
      );

  glados.Generator<_GeneratedWakeQueueScenario> get wakeQueueScenario =>
      glados.ListAnys(this)
          .listWithLengthInRange(0, 40, wakeQueueOperation)
          .map(
            (operations) => _GeneratedWakeQueueScenario(
              operations: operations,
            ),
          );
}

void main() {
  late WakeQueue queue;

  final testDate = DateTime(2024, 3, 15, 10, 30);

  WakeJob makeJob({
    String runKey = 'run-key-1',
    String agentId = 'agent-1',
    String reason = 'subscription',
    Set<String>? triggerTokens,
    String? reasonId,
    DateTime? createdAt,
  }) {
    return WakeJob(
      runKey: runKey,
      agentId: agentId,
      reason: reason,
      triggerTokens: triggerTokens ?? {'tok-a'},
      reasonId: reasonId,
      createdAt: createdAt ?? testDate,
    );
  }

  setUp(() {
    queue = WakeQueue();
  });

  group('WakeJob', () {
    test('stores all fields correctly', () {
      final tokens = {'tok-a', 'tok-b'};
      final job = WakeJob(
        runKey: 'rk-1',
        agentId: 'agent-1',
        reason: 'timer',
        triggerTokens: tokens,
        reasonId: 'timer-1',
        createdAt: testDate,
      );

      expect(job.runKey, 'rk-1');
      expect(job.agentId, 'agent-1');
      expect(job.reason, 'timer');
      expect(job.triggerTokens, tokens);
      expect(job.reasonId, 'timer-1');
      expect(job.createdAt, testDate);
    });

    test('reasonId is optional and defaults to null', () {
      final job = makeJob();

      expect(job.reasonId, isNull);
    });
  });

  group('WakeQueue', () {
    group('enqueue', () {
      test('adds job and returns true on first enqueue', () {
        final result = queue.enqueue(makeJob());

        expect(result, isTrue);
        expect(queue.length, 1);
        expect(queue.isEmpty, isFalse);
      });

      test('rejects duplicate run key and returns false', () {
        queue.enqueue(makeJob(runKey: 'rk-1'));
        final result = queue.enqueue(makeJob(runKey: 'rk-1'));

        expect(result, isFalse);
        expect(queue.length, 1);
      });

      test('allows different run keys', () {
        queue.enqueue(makeJob(runKey: 'rk-1'));
        final result = queue.enqueue(makeJob(runKey: 'rk-2'));

        expect(result, isTrue);
        expect(queue.length, 2);
      });
    });

    group('dequeue', () {
      test('returns null when queue is empty', () {
        expect(queue.dequeue(), isNull);
      });

      test('returns jobs in FIFO order', () {
        queue
          ..enqueue(makeJob(runKey: 'rk-1', agentId: 'first'))
          ..enqueue(makeJob(runKey: 'rk-2', agentId: 'second'))
          ..enqueue(makeJob(runKey: 'rk-3', agentId: 'third'));

        expect(queue.dequeue()!.agentId, 'first');
        expect(queue.dequeue()!.agentId, 'second');
        expect(queue.dequeue()!.agentId, 'third');
        expect(queue.dequeue(), isNull);
      });

      test('decrements length after dequeue', () {
        queue
          ..enqueue(makeJob(runKey: 'rk-1'))
          ..enqueue(makeJob(runKey: 'rk-2'));

        expect(queue.length, 2);
        queue.dequeue();
        expect(queue.length, 1);
        queue.dequeue();
        expect(queue.length, 0);
        expect(queue.isEmpty, isTrue);
      });
    });

    group('mergeTokens', () {
      test('merges tokens into first matching job and returns true', () {
        final job = makeJob(
          runKey: 'rk-1',
          triggerTokens: {'tok-a'},
        );
        queue.enqueue(job);

        final result = queue.mergeTokens('agent-1', {'tok-b', 'tok-c'});

        expect(result, isTrue);
        final dequeued = queue.dequeue()!;
        expect(
          dequeued.triggerTokens,
          containsAll(['tok-a', 'tok-b', 'tok-c']),
        );
      });

      test('returns false when no matching agent is queued', () {
        queue.enqueue(makeJob());

        final result = queue.mergeTokens('agent-99', {'tok-x'});

        expect(result, isFalse);
      });

      test('returns false on empty queue', () {
        final result = queue.mergeTokens('agent-1', {'tok-x'});

        expect(result, isFalse);
      });

      test('merges into the first matching job only', () {
        final job1 = makeJob(
          runKey: 'rk-1',
          triggerTokens: {'tok-a'},
        );
        final job2 = makeJob(
          runKey: 'rk-2',
          triggerTokens: {'tok-b'},
        );
        queue
          ..enqueue(job1)
          ..enqueue(job2)
          ..mergeTokens('agent-1', {'tok-c'});

        final first = queue.dequeue()!;
        final second = queue.dequeue()!;
        expect(first.triggerTokens, containsAll(['tok-a', 'tok-c']));
        expect(second.triggerTokens, equals({'tok-b'}));
      });
    });

    group('isEmpty and length', () {
      test('reports empty on fresh queue', () {
        expect(queue.isEmpty, isTrue);
        expect(queue.length, 0);
      });

      test('reports non-empty after enqueue', () {
        queue.enqueue(makeJob());

        expect(queue.isEmpty, isFalse);
        expect(queue.length, 1);
      });
    });

    group('clearHistory', () {
      test('allows previously seen run key to be re-enqueued', () {
        queue
          ..enqueue(makeJob(runKey: 'rk-1'))
          ..dequeue();

        // Before clearing, re-enqueue is rejected
        expect(queue.enqueue(makeJob(runKey: 'rk-1')), isFalse);

        queue.clearHistory();

        // After clearing, re-enqueue succeeds
        expect(queue.enqueue(makeJob(runKey: 'rk-1')), isTrue);
        expect(queue.length, 1);
      });

      test('asserts when called with pending jobs', () {
        queue
          ..enqueue(makeJob(runKey: 'rk-1'))
          ..enqueue(makeJob(runKey: 'rk-2'));

        // Calling clearHistory with pending jobs is a programming error.
        expect(queue.clearHistory, throwsA(isA<AssertionError>()));
      });
    });

    group('deduplication survives dequeue', () {
      test('dequeued run key is still in seen history', () {
        queue
          ..enqueue(makeJob(runKey: 'rk-1'))
          ..dequeue();

        // The run key is still "seen" even after dequeue
        final result = queue.enqueue(makeJob(runKey: 'rk-1'));

        expect(result, isFalse);
        expect(queue.isEmpty, isTrue);
      });
    });

    group('requeue', () {
      test('adds job back without dedup check', () {
        final job = makeJob(runKey: 'rk-1');
        queue.enqueue(job);
        final dequeued = queue.dequeue()!;

        // Normal enqueue would be rejected (key already seen)
        expect(queue.enqueue(makeJob(runKey: 'rk-1')), isFalse);

        // Requeue bypasses dedup
        queue.requeue(dequeued);
        expect(queue.isEmpty, isFalse);
        expect(queue.dequeue()!.runKey, 'rk-1');
      });

      test('requeued job preserves original fields', () {
        final job = makeJob(runKey: 'rk-1', agentId: 'agent-42');
        queue
          ..enqueue(job)
          ..dequeue()
          ..requeue(job);

        final result = queue.dequeue()!;
        expect(result.runKey, 'rk-1');
        expect(result.agentId, 'agent-42');
      });
    });

    group('removeByAgent', () {
      test('removes all jobs for the given agent', () {
        queue
          ..enqueue(makeJob(runKey: 'r1'))
          ..enqueue(makeJob(runKey: 'r2', agentId: 'agent-2'))
          ..enqueue(makeJob(runKey: 'r3'));

        final removed = queue.removeByAgent('agent-1');

        expect(removed, hasLength(2));
        expect(removed.map((j) => j.runKey), containsAll(['r1', 'r3']));
        expect(queue.length, 1);
        expect(queue.dequeue()!.agentId, 'agent-2');
      });

      test('returns empty list when no jobs match', () {
        queue.enqueue(makeJob(runKey: 'r1'));

        final removed = queue.removeByAgent('agent-99');

        expect(removed, isEmpty);
        expect(queue.length, 1);
      });

      test('returns empty list on empty queue', () {
        final removed = queue.removeByAgent('agent-1');
        expect(removed, isEmpty);
      });
    });

    glados.Glados(
      glados.any.wakeQueueScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test('matches generated operation sequence semantics', (scenario) {
      final generatedQueue = WakeQueue();
      final model = _GeneratedWakeQueueModel();
      WakeJob? lastDequeued;

      for (final (index, operation) in scenario.operations.indexed) {
        switch (operation.kind) {
          case _GeneratedWakeQueueOperationKind.enqueue:
            final expectedAccepted = model.seenRunKeys.add(operation.runKey);
            if (expectedAccepted) {
              model.queue.add(
                _GeneratedWakeQueueModelJob(
                  runKey: operation.runKey,
                  agentId: operation.agentId,
                  triggerTokens: {operation.token},
                ),
              );
            }

            final accepted = generatedQueue.enqueue(
              WakeJob(
                runKey: operation.runKey,
                agentId: operation.agentId,
                reason: 'subscription',
                triggerTokens: {operation.token},
                createdAt: _generatedWakeQueueBase.add(
                  Duration(seconds: index),
                ),
              ),
            );

            expect(accepted, expectedAccepted, reason: '$scenario');

          case _GeneratedWakeQueueOperationKind.dequeue:
            final expected = model.queue.isEmpty
                ? null
                : model.queue.removeAt(0);
            model.lastDequeued = expected;

            final actual = generatedQueue.dequeue();
            lastDequeued = actual;

            expect(actual?.runKey, expected?.runKey, reason: '$scenario');
            expect(actual?.agentId, expected?.agentId, reason: '$scenario');
            expect(
              actual?.triggerTokens,
              expected?.triggerTokens,
              reason: '$scenario',
            );

          case _GeneratedWakeQueueOperationKind.mergeTokens:
            final expected = model.queue
                .where((job) => job.agentId == operation.agentId)
                .firstOrNull;
            expected?.triggerTokens.add(operation.token);

            final merged = generatedQueue.mergeTokens(
              operation.agentId,
              {operation.token},
            );

            expect(merged, expected != null, reason: '$scenario');

          case _GeneratedWakeQueueOperationKind.removeByAgent:
            final removed = <_GeneratedWakeQueueModelJob>[];
            model.queue.removeWhere((job) {
              if (job.agentId == operation.agentId) {
                removed.add(job);
                return true;
              }
              return false;
            });

            final actual = generatedQueue.removeByAgent(operation.agentId);

            expect(
              actual.map((job) => job.runKey).toList(),
              removed.map((job) => job.runKey).toList(),
              reason: '$scenario',
            );

          case _GeneratedWakeQueueOperationKind.requeueLastDequeued:
            final expected = model.lastDequeued;
            if (expected != null && lastDequeued != null) {
              model.queue.add(expected);
              generatedQueue.requeue(lastDequeued);
            }

          case _GeneratedWakeQueueOperationKind.clearHistoryWhenEmpty:
            if (model.queue.isEmpty) {
              model.seenRunKeys.clear();
              generatedQueue.clearHistory();
            }
        }

        expect(generatedQueue.length, model.queue.length, reason: '$scenario');
        expect(
          generatedQueue.isEmpty,
          model.queue.isEmpty,
          reason: '$scenario',
        );
      }

      final drained = <WakeJob>[];
      WakeJob? next;
      while ((next = generatedQueue.dequeue()) != null) {
        drained.add(next!);
      }

      expect(
        drained.map((job) => job.runKey).toList(),
        model.queue.map((job) => job.runKey).toList(),
        reason: '$scenario',
      );
      expect(
        drained.map((job) => job.agentId).toList(),
        model.queue.map((job) => job.agentId).toList(),
        reason: '$scenario',
      );
      expect(
        drained.map((job) => job.triggerTokens).toList(),
        model.queue.map((job) => job.triggerTokens).toList(),
        reason: '$scenario',
      );
    });
  });
}
