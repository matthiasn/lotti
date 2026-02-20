import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';

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

      test('does not affect queued jobs', () {
        queue
          ..enqueue(makeJob(runKey: 'rk-1'))
          ..enqueue(makeJob(runKey: 'rk-2'))
          ..clearHistory();

        // Jobs are still in the queue
        expect(queue.length, 2);
        expect(queue.dequeue()!.runKey, 'rk-1');
        expect(queue.dequeue()!.runKey, 'rk-2');
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
  });
}
