import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'wake_runner_test_helpers.dart';

void main() {
  group('WakeRunner single-flight property', () {
    glados.Glados(
      glados.any.wakeRunnerScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('matches generated single-flight operation semantics', (scenario) {
      final generatedRunner = WakeRunner();
      final expectedActive = <String, DateTime>{};
      final expectedEmissions = <Set<String>>[];
      final emissions = <Set<String>>[];
      final waiters = <GeneratedWakeRunnerWaiter>[];
      // Set of agentIds whose abort signal has already been fired in the
      // current run. Cleared on release so a fresh acquire starts un-aborted.
      final firedAborts = <String>{};
      // Per-acquire abort waiters: each acquire registers a fresh waiter on
      // the new abort future so we can assert that release (or an explicit
      // abort) completes it.
      final abortWaiters = <GeneratedWakeRunnerWaiter>[];
      var currentTick = 0;

      withClock(
        Clock(
          () => generatedWakeRunnerBase.add(Duration(seconds: currentTick)),
        ),
        () {
          fakeAsync((async) {
            generatedRunner.runningAgentIds.listen(emissions.add);

            for (final (index, operation) in scenario.operations.indexed) {
              currentTick = index;
              final agentId = operation.agentId;

              switch (operation.kind) {
                case GeneratedWakeRunnerOperationKind.acquire:
                  late bool acquired;
                  generatedRunner
                      .tryAcquire(agentId)
                      .then((value) => acquired = value);
                  async.flushMicrotasks();

                  final expectedAcquired = !expectedActive.containsKey(agentId);
                  expect(acquired, expectedAcquired, reason: '$scenario');
                  if (expectedAcquired) {
                    expectedActive[agentId] = clock.now();
                    expectedEmissions.add(expectedActive.keys.toSet());
                    // Subscribe to the freshly-allocated abort future so we
                    // can assert it completes when this run ends (either via
                    // explicit abort or via release).
                    final waiter = GeneratedWakeRunnerWaiter(
                      agentId: agentId,
                      actualCompleted: false,
                      expectedCompleted: false,
                    );
                    generatedRunner.abortFuture(agentId)!.then((_) {
                      waiter.actualCompleted = true;
                    });
                    abortWaiters.add(waiter);
                  }

                case GeneratedWakeRunnerOperationKind.release:
                  final removed = expectedActive.remove(agentId) != null;
                  generatedRunner.release(agentId);
                  if (removed) {
                    expectedEmissions.add(expectedActive.keys.toSet());
                    waiters
                        .where((waiter) => waiter.agentId == agentId)
                        .forEach((waiter) => waiter.expectedCompleted = true);
                    // Release fires any pending abort signal and clears the
                    // fired-abort bookkeeping so the next acquire starts
                    // fresh.
                    abortWaiters
                        .where(
                          (w) => w.agentId == agentId && !w.expectedCompleted,
                        )
                        .forEach((w) => w.expectedCompleted = true);
                    firedAborts.remove(agentId);
                  }
                  async.flushMicrotasks();

                case GeneratedWakeRunnerOperationKind.waitForCompletion:
                  final waiter = GeneratedWakeRunnerWaiter(
                    agentId: agentId,
                    actualCompleted: false,
                    expectedCompleted: !expectedActive.containsKey(agentId),
                  );
                  generatedRunner.waitForCompletion(agentId).then((_) {
                    waiter.actualCompleted = true;
                  });
                  async.flushMicrotasks();

                  if (!expectedActive.containsKey(agentId)) {
                    expect(
                      waiter.actualCompleted,
                      isTrue,
                      reason: '$scenario',
                    );
                  } else {
                    expect(
                      waiter.actualCompleted,
                      isFalse,
                      reason: '$scenario',
                    );
                    waiters.add(waiter);
                  }

                case GeneratedWakeRunnerOperationKind.abort:
                  final isActive = expectedActive.containsKey(agentId);
                  final alreadyFired = firedAborts.contains(agentId);
                  final expectedReturn = isActive && !alreadyFired;
                  final actualReturn = generatedRunner.abort(agentId);
                  expect(actualReturn, expectedReturn, reason: '$scenario');

                  if (expectedReturn) {
                    firedAborts.add(agentId);
                    // The most-recent un-completed abort waiter for this
                    // agent — i.e. the one tied to the current acquire —
                    // should now resolve. Older waiters were already marked
                    // completed by the corresponding release.
                    abortWaiters
                        .where(
                          (w) => w.agentId == agentId && !w.expectedCompleted,
                        )
                        .forEach((w) => w.expectedCompleted = true);
                  }
                  async.flushMicrotasks();

                  // abortFuture(id) is null iff the agent is not running.
                  expect(
                    generatedRunner.abortFuture(agentId) == null,
                    !isActive,
                    reason: '$scenario',
                  );
              }

              expect(
                generatedRunner.activeAgentIds,
                expectedActive.keys.toSet(),
                reason: '$scenario',
              );
              expect(
                generatedRunner.activeStartedAtById,
                expectedActive,
                reason: '$scenario',
              );
              for (final slot in GeneratedWakeRunnerAgentSlot.values) {
                final id = generatedWakeRunnerAgentId(slot);
                expect(
                  generatedRunner.startedAt(id),
                  expectedActive[id],
                  reason: '$scenario',
                );
              }
              expect(emissions, expectedEmissions, reason: '$scenario');
              for (final waiter in waiters) {
                expect(
                  waiter.actualCompleted,
                  waiter.expectedCompleted,
                  reason: '$scenario',
                );
              }
              for (final waiter in abortWaiters) {
                expect(
                  waiter.actualCompleted,
                  waiter.expectedCompleted,
                  reason: '$scenario',
                );
              }
            }

            generatedRunner.dispose();
          });
        },
      );
    }, tags: 'glados');
  });
}
