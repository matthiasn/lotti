import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';

void main() {
  late WakeRunner runner;

  setUp(() {
    runner = WakeRunner();
  });

  group('WakeRunner', () {
    group('tryAcquire', () {
      test('returns true and acquires lock when no run is active', () {
        fakeAsync((async) {
          late bool acquired;
          runner.tryAcquire('agent-1').then((v) => acquired = v);
          async.flushMicrotasks();

          expect(acquired, isTrue);
          expect(runner.isRunning('agent-1'), isTrue);
        });
      });

      test('returns false when agent is already running', () {
        fakeAsync((async) {
          late bool first;
          late bool second;
          runner.tryAcquire('agent-1').then((v) => first = v);
          async.flushMicrotasks();
          runner.tryAcquire('agent-1').then((v) => second = v);
          async.flushMicrotasks();

          expect(first, isTrue);
          expect(second, isFalse);
        });
      });

      test('allows different agents to acquire independently', () {
        fakeAsync((async) {
          late bool a1;
          late bool a2;
          runner.tryAcquire('agent-1').then((v) => a1 = v);
          runner.tryAcquire('agent-2').then((v) => a2 = v);
          async.flushMicrotasks();

          expect(a1, isTrue);
          expect(a2, isTrue);
          expect(runner.isRunning('agent-1'), isTrue);
          expect(runner.isRunning('agent-2'), isTrue);
        });
      });
    });

    group('release', () {
      test('removes lock so agent can be acquired again', () {
        fakeAsync((async) {
          late bool first;
          late bool second;
          runner.tryAcquire('agent-1').then((v) => first = v);
          async.flushMicrotasks();
          expect(first, isTrue);

          runner.release('agent-1');
          expect(runner.isRunning('agent-1'), isFalse);

          runner.tryAcquire('agent-1').then((v) => second = v);
          async.flushMicrotasks();
          expect(second, isTrue);
        });
      });

      test('release on non-locked agent is safe (no-op)', () {
        // Should not throw
        runner.release('agent-nonexistent');

        expect(runner.isRunning('agent-nonexistent'), isFalse);
      });
    });

    group('waitForCompletion', () {
      test('returns immediately when no run is active', () {
        fakeAsync((async) {
          var completed = false;
          runner.waitForCompletion('agent-1').then((_) => completed = true);
          async.flushMicrotasks();

          expect(completed, isTrue);
        });
      });

      test('suspends until active run is released', () {
        fakeAsync((async) {
          // Acquire lock
          runner.tryAcquire('agent-1');
          async.flushMicrotasks();

          // Start waiting
          var waitCompleted = false;
          runner.waitForCompletion('agent-1').then((_) => waitCompleted = true);
          async.flushMicrotasks();

          expect(waitCompleted, isFalse, reason: 'Still locked');

          // Release lock
          runner.release('agent-1');
          async.flushMicrotasks();

          expect(waitCompleted, isTrue, reason: 'Should resolve after release');
        });
      });

      test('multiple waiters all resolve on release', () {
        fakeAsync((async) {
          runner.tryAcquire('agent-1');
          async.flushMicrotasks();

          var waiter1Done = false;
          var waiter2Done = false;
          runner.waitForCompletion('agent-1').then((_) => waiter1Done = true);
          runner.waitForCompletion('agent-1').then((_) => waiter2Done = true);
          async.flushMicrotasks();

          expect(waiter1Done, isFalse);
          expect(waiter2Done, isFalse);

          runner.release('agent-1');
          async.flushMicrotasks();

          expect(waiter1Done, isTrue);
          expect(waiter2Done, isTrue);
        });
      });
    });

    group('isRunning', () {
      test('returns false for unknown agent', () {
        expect(runner.isRunning('agent-unknown'), isFalse);
      });

      test('returns true after acquire, false after release', () {
        fakeAsync((async) {
          runner.tryAcquire('agent-1');
          async.flushMicrotasks();

          expect(runner.isRunning('agent-1'), isTrue);

          runner.release('agent-1');
          expect(runner.isRunning('agent-1'), isFalse);
        });
      });
    });

    group('activeAgentIds', () {
      test('returns empty set when no agents are running', () {
        expect(runner.activeAgentIds, isEmpty);
      });

      test('returns set of all running agent IDs', () {
        fakeAsync((async) {
          runner
            ..tryAcquire('agent-1')
            ..tryAcquire('agent-2');
          async.flushMicrotasks();

          expect(
            runner.activeAgentIds,
            containsAll(['agent-1', 'agent-2']),
          );
          expect(runner.activeAgentIds, hasLength(2));
        });
      });

      test('removes agent from active set after release', () {
        fakeAsync((async) {
          runner
            ..tryAcquire('agent-1')
            ..tryAcquire('agent-2');
          async.flushMicrotasks();

          runner.release('agent-1');

          expect(runner.activeAgentIds, equals({'agent-2'}));
        });
      });

      test('returned set is unmodifiable', () {
        fakeAsync((async) {
          runner.tryAcquire('agent-1');
          async.flushMicrotasks();

          final ids = runner.activeAgentIds;
          expect(
            () => ids.add('hacked'),
            throwsA(isA<UnsupportedError>()),
          );
        });
      });
    });

    group('runningAgentIds stream', () {
      test('emits updated set on acquire', () {
        fakeAsync((async) {
          final emissions = <Set<String>>[];
          runner.runningAgentIds.listen(emissions.add);

          runner.tryAcquire('agent-1');
          async.flushMicrotasks();

          expect(emissions, hasLength(1));
          expect(emissions.last, equals({'agent-1'}));
        });
      });

      test('emits updated set on release', () {
        fakeAsync((async) {
          final emissions = <Set<String>>[];
          runner.runningAgentIds.listen(emissions.add);

          runner.tryAcquire('agent-1');
          async.flushMicrotasks();
          runner.release('agent-1');
          async.flushMicrotasks();

          expect(emissions, hasLength(2));
          expect(emissions[0], equals({'agent-1'}));
          expect(emissions[1], isEmpty);
        });
      });

      test('emits cumulative set for multiple agents', () {
        fakeAsync((async) {
          final emissions = <Set<String>>[];
          runner.runningAgentIds.listen(emissions.add);

          runner.tryAcquire('agent-1');
          async.flushMicrotasks();
          runner.tryAcquire('agent-2');
          async.flushMicrotasks();

          expect(emissions, hasLength(2));
          expect(emissions[0], equals({'agent-1'}));
          expect(emissions[1], equals({'agent-1', 'agent-2'}));
        });
      });

      test('does not emit on failed acquire (already locked)', () {
        fakeAsync((async) {
          runner.tryAcquire('agent-1');
          async.flushMicrotasks();

          final emissions = <Set<String>>[];
          runner.runningAgentIds.listen(emissions.add);

          runner.tryAcquire('agent-1');
          async.flushMicrotasks();

          expect(emissions, isEmpty);
        });
      });

      test('is broadcast — supports multiple listeners', () {
        fakeAsync((async) {
          final emissions1 = <Set<String>>[];
          final emissions2 = <Set<String>>[];
          runner.runningAgentIds.listen(emissions1.add);
          runner.runningAgentIds.listen(emissions2.add);

          runner.tryAcquire('agent-1');
          async.flushMicrotasks();

          expect(emissions1, hasLength(1));
          expect(emissions2, hasLength(1));
        });
      });
    });

    group('dispose', () {
      test('closes the runningAgentIds stream', () {
        fakeAsync((async) {
          var done = false;
          runner.runningAgentIds.listen(
            (_) {},
            onDone: () => done = true,
          );

          runner.dispose();
          async.flushMicrotasks();

          expect(done, isTrue);
        });
      });
    });
  });
}
