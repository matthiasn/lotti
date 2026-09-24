import 'dart:convert';

import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/day_agent_trigger_tokens.dart';
import 'package:lotti/features/agents/wake/wake_intent_store.dart';

import 'wake_orchestrator_test_harness.dart';

enum _WakeOp { trigger, complete, crash }

/// One step of a generated wake trace; `arg` picks the agent of a trigger
/// or, modulo how many there are, the running executor to complete.
class _WakeStep {
  const _WakeStep(this.op, this.arg);

  factory _WakeStep.decode(int code) => _WakeStep(
    // Crashes are rarer than the other two.
    code % 7 == 6 ? _WakeOp.crash : _WakeOp.values[code % 2],
    code ~/ 7,
  );

  final _WakeOp op;
  final int arg;

  @override
  String toString() => '${op.name}($arg)';
}

extension _AnyWakeTrace on glados.Any {
  glados.Generator<List<_WakeStep>> get wakeIntentTrace => glados.ListAnys(this)
      .listWithLengthInRange(1, 16, glados.IntAnys(this).intInRange(0, 28))
      .map((codes) => [for (final code in codes) _WakeStep.decode(code)]);
}

/// Settings storage that outlives a simulated process: every "process" builds
/// a fresh store and orchestrator over the same map.
MockSettingsDb _memorySettingsDb(Map<String, String> values) {
  final db = MockSettingsDb();
  when(() => db.itemByKey(any())).thenAnswer(
    (invocation) async => values[invocation.positionalArguments.first],
  );
  when(() => db.saveSettingsItem(any(), any())).thenAnswer((invocation) async {
    values[invocation.positionalArguments[0] as String] =
        invocation.positionalArguments[1] as String;
    return 1;
  });
  when(() => db.removeSettingsItem(any())).thenAnswer((invocation) async {
    values.remove(invocation.positionalArguments.first);
  });
  return db;
}

void main() {
  configureWakeOrchestratorTestSuite();

  late Map<String, String> settings;
  late List<({String agentId, Set<String> triggers})> executed;

  setUp(() {
    settings = {};
    executed = [];
  });

  /// One process lifetime: a fresh queue, runner, store and orchestrator
  /// over the shared [settings]. Loads the store, as `start` does.
  WakeOrchestrator boot(
    FakeAsync async,
    WakeExecutor executor, {
    int concurrency = 3,
  }) {
    final store = WakeIntentStore(settingsDb: _memorySettingsDb(settings));
    queue = WakeQueue();
    runner = WakeRunner();
    orchestrator = WakeOrchestrator(
      repository: mockRepository,
      queue: queue,
      runner: runner,
      maxConcurrentWakes: () => concurrency,
      wakeExecutor: (agentId, runKey, triggers, threadId) {
        executed.add((agentId: agentId, triggers: {...triggers}));
        return executor(agentId, runKey, triggers, threadId);
      },
      intentStore: store,
    );
    unawaited(store.load());
    async.flushMicrotasks();
    return orchestrator;
  }

  Set<String> owedTokens() {
    final raw = settings[WakeIntentStore.settingsKey];
    if (raw == null) return const {};
    return {
      for (final intent in jsonDecode(raw) as List<dynamic>)
        ...((intent as Map<String, dynamic>)['tokens'] as List).cast<String>(),
    };
  }

  test('outbox-owned wakes execute without a second durable intent', () {
    fakeAsync((async) {
      final gate = Completer<Map<String, VectorClock>?>();
      final current = boot(async, (_, _, _, _) => gate.future);
      final tokens = {
        dayAgentDraftingToken('dayplan-2026-09-24'),
        dayAgentProcessingJobToken(
          'draft-1',
          requestedAt: DateTime(2026, 9, 24),
        ),
      };
      current.enqueueManualWake(
        agentId: 'planner',
        reason: dayAgentDraftingReason,
        triggerTokens: tokens,
        workspaceKey: dayAgentWorkspaceKey('dayplan-2026-09-24'),
      );
      async.flushMicrotasks();
      expect(executed.single.triggers, tokens);
      expect(
        owedTokens(),
        isEmpty,
        reason: 'the processing outbox owns recovery',
      );
      gate.complete(const {});
      async.flushMicrotasks();
    });
  });

  test('restoration keeps ordinary work separate from a queued outbox job', () {
    fakeAsync((async) {
      final first = boot(async, noOpExecutor);
      unawaited(runner.tryAcquire('planner'));
      async.flushMicrotasks();
      first.enqueueManualWake(
        agentId: 'planner',
        reason: 'reanalysis',
        triggerTokens: {'ordinary'},
      );
      async.flushMicrotasks();

      final second = boot(async, noOpExecutor);
      unawaited(runner.tryAcquire('planner'));
      async.flushMicrotasks();
      final outboxTokens = {
        dayAgentProcessingJobToken(
          'draft-1',
          requestedAt: DateTime(2026, 9, 24),
        ),
      };
      second.enqueueManualWake(
        agentId: 'planner',
        reason: dayAgentDraftingReason,
        triggerTokens: outboxTokens,
      );
      async.flushMicrotasks();
      unawaited(second.restoreWakeIntents());
      async.flushMicrotasks();

      expect(queue.length, 2);
      expect(queue.dequeue()!.triggerTokens, outboxTokens);
      expect(queue.dequeue()!.triggerTokens, {'ordinary'});
      expect(owedTokens(), {'ordinary'});
    });
  });

  for (final count in [1, 2]) {
    test('startup retires $count legacy outbox intents without replay', () {
      fakeAsync((async) {
        final jobTokens = {
          for (var i = 0; i < count; i++)
            dayAgentProcessingJobToken(
              'refine-$i',
              requestedAt: DateTime(2026, 9, 24),
            ),
        };
        settings[WakeIntentStore.settingsKey] = jsonEncode([
          for (final (index, token) in jobTokens.indexed)
            {
              'runKey': 'old-$index',
              'agentId': 'planner',
              'workspaceKey': dayAgentWorkspaceKey('dayplan-2026-09-24'),
              'reason': dayAgentRefineReason,
              'initiator': 'user',
              'tokens': [token, dayAgentRefineToken('dayplan-2026-09-24')],
            },
          {
            'runKey': 'ordinary',
            'agentId': 'task-agent',
            'workspaceKey': null,
            'reason': 'reanalysis',
            'initiator': 'user',
            'tokens': ['task-1'],
          },
        ]);
        final current = boot(async, noOpExecutor);
        var restored = -1;
        unawaited(current.restoreWakeIntents().then((n) => restored = n));
        async.flushMicrotasks();
        expect(restored, 1, reason: 'only the ordinary wake is restored');
        expect(executed.map((run) => run.agentId), ['task-agent']);
        expect(executed.single.triggers, {'task-1'});
        expect(owedTokens(), isEmpty);
      });
    });
  }

  test('a queued wake lost to a process death runs at the next start', () {
    // Regression for WakeRuntime.tla NoLostWake: queued jobs lived only in
    // memory, so a crash before the drain dropped them for good.
    fakeAsync((async) {
      final first = boot(async, noOpExecutor);
      // Another run holds the agent, so the manual wake stays queued.
      unawaited(runner.tryAcquire('agent-1'));
      async.flushMicrotasks();
      first.enqueueManualWake(
        agentId: 'agent-1',
        reason: 'creation',
        triggerTokens: {'task-1'},
        initiator: WakeInitiator.user,
      );
      async.flushMicrotasks();
      expect(executed, isEmpty);
      expect(owedTokens(), {'task-1'});

      // The process dies. The next one restores and runs the wake.
      final second = boot(async, noOpExecutor);
      late int restored;
      unawaited(second.restoreWakeIntents().then((n) => restored = n));
      async.flushMicrotasks();

      expect(restored, 1);
      expect(executed.single.agentId, 'agent-1');
      expect(executed.single.triggers, {'task-1'});
      expect(owedTokens(), isEmpty, reason: 'the run settled the intent');
    });
  });

  test('a run interrupted by a process death runs again at the next start', () {
    fakeAsync((async) {
      boot(
        async,
        (_, _, _, _) => Completer<Map<String, VectorClock>?>().future,
      ).enqueueManualWake(
        agentId: 'agent-1',
        reason: 'creation',
        triggerTokens: {'task-1'},
      );
      async.flushMicrotasks();
      expect(executed, hasLength(1));
      expect(owedTokens(), {'task-1'}, reason: 'a started run is still owed');

      final second = boot(async, noOpExecutor);
      unawaited(second.restoreWakeIntents());
      async.flushMicrotasks();

      expect(executed, hasLength(2));
      expect(owedTokens(), isEmpty);
    });
  });

  test('a trigger that arrives mid-run stays owed after that run', () {
    fakeAsync((async) {
      final gates = <Completer<Map<String, VectorClock>?>>[];
      final orchestrator =
          boot(async, (_, _, _, _) {
            final gate = Completer<Map<String, VectorClock>?>();
            gates.add(gate);
            return gate.future;
          })..enqueueManualWake(
            agentId: 'agent-1',
            reason: 'creation',
            triggerTokens: {'early'},
          );
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 1));
      orchestrator.enqueueManualWake(
        agentId: 'agent-1',
        reason: 'creation',
        triggerTokens: {'late'},
        supersede: false,
      );
      async.flushMicrotasks();
      expect(executed, hasLength(1), reason: 'single flight');

      gates.first.complete(const {});
      async.flushMicrotasks();
      // The first run did not cover the late trigger; its follow-up runs.
      expect(owedTokens(), containsAll(<String>{'late'}));
      expect(executed, hasLength(2));
      expect(executed.last.triggers, {'late'});

      gates.last.complete(const {});
      async.flushMicrotasks();
      expect(owedTokens(), isEmpty);
    });
  });

  test('a restored intent merges into a job already queued for it', () {
    fakeAsync((async) {
      final first = boot(async, noOpExecutor);
      unawaited(runner.tryAcquire('agent-1'));
      async.flushMicrotasks();
      first.enqueueManualWake(
        agentId: 'agent-1',
        reason: 'creation',
        triggerTokens: {'lost'},
      );
      async.flushMicrotasks();

      final second = boot(async, noOpExecutor);
      unawaited(runner.tryAcquire('agent-1'));
      async.flushMicrotasks();
      second.enqueueManualWake(
        agentId: 'agent-1',
        reason: 'creation',
        triggerTokens: {'fresh'},
      );
      async.flushMicrotasks();
      unawaited(second.restoreWakeIntents());
      async.flushMicrotasks();

      expect(queue.length, 1);
      expect(queue.dequeue()!.triggerTokens, {'fresh', 'lost'});
    });
  });

  test('a restored user wake does not merge into queued automation', () {
    // Merging would leave the user's tokens on an automation job, which
    // disabling automatic updates drops.
    fakeAsync((async) {
      final first = boot(async, noOpExecutor);
      unawaited(runner.tryAcquire('agent-1'));
      async.flushMicrotasks();
      first.enqueueManualWake(
        agentId: 'agent-1',
        reason: 'creation',
        triggerTokens: {'user-asked'},
        initiator: WakeInitiator.user,
      );
      async.flushMicrotasks();

      final second = boot(async, noOpExecutor);
      unawaited(runner.tryAcquire('agent-1'));
      async.flushMicrotasks();
      second.enqueueManualWake(
        agentId: 'agent-1',
        reason: 'scheduled',
        triggerTokens: {'automatic'},
        initiator: WakeInitiator.automation,
      );
      async.flushMicrotasks();
      unawaited(second.restoreWakeIntents());
      async.flushMicrotasks();

      second.cancelPendingAutomaticWakes('agent-1');
      async.flushMicrotasks();

      final survivor = queue.dequeue()!;
      expect(queue.length, 0);
      expect(survivor.initiator, WakeInitiator.user);
      expect(survivor.triggerTokens, {'user-asked'});
      expect(owedTokens(), {'user-asked'});
    });
  });

  for (final (label, cancel) in <(String, void Function(WakeOrchestrator))>[
    ('cancelled', (o) => o.cancelPendingWakes('agent-1')),
    ('automation-cancelled', (o) => o.cancelPendingAutomaticWakes('agent-1')),
    (
      'superseded',
      (o) => o.enqueueManualWake(
        agentId: 'agent-1',
        reason: 'creation',
        triggerTokens: {'newer'},
      ),
    ),
  ]) {
    test('a $label queued wake does not come back at the next start', () {
      fakeAsync((async) {
        final first = boot(async, noOpExecutor);
        unawaited(runner.tryAcquire('agent-1'));
        async.flushMicrotasks();
        first.enqueueManualWake(
          agentId: 'agent-1',
          reason: 'creation',
          triggerTokens: {'dropped'},
          initiator: WakeInitiator.automation,
        );
        async
          ..elapse(const Duration(seconds: 1))
          ..flushMicrotasks();

        cancel(first);
        async.flushMicrotasks();

        expect(owedTokens(), isNot(contains('dropped')));
      });
    });
  }

  for (final (initiators, expected) in [
    ([WakeInitiator.automation], WakeInitiator.automation),
    ([WakeInitiator.automation, WakeInitiator.user], WakeInitiator.user),
  ]) {
    test('restored intents from $initiators become one '
        '${expected.name} job', () {
      fakeAsync((async) {
        final first = boot(async, noOpExecutor);
        unawaited(runner.tryAcquire('agent-1'));
        async.flushMicrotasks();
        for (final (index, initiator) in initiators.indexed) {
          first.enqueueManualWake(
            agentId: 'agent-1',
            reason: 'creation',
            triggerTokens: {'token-$index'},
            supersede: false,
            initiator: initiator,
          );
          async
            ..elapse(const Duration(seconds: 1))
            ..flushMicrotasks();
        }

        final second = boot(async, noOpExecutor);
        unawaited(runner.tryAcquire('agent-1'));
        async.flushMicrotasks();
        unawaited(second.restoreWakeIntents());
        async.flushMicrotasks();

        // A user's wake must survive disabling automatic updates.
        final job = queue.dequeue()!;
        expect(queue.length, 0);
        expect(job.initiator, expected);
        expect(job.triggerTokens, {
          for (var i = 0; i < initiators.length; i++) 'token-$i',
        });
      });
    });
  }

  test('a job the drain hands back stays owed until it runs', () {
    fakeAsync((async) {
      final insertGate = Completer<void>();
      final replacementGate = Completer<Map<String, VectorClock>?>();
      when(
        () => mockRepository.insertWakeRun(entry: any(named: 'entry')),
      ).thenAnswer((call) async {
        final entry = call.namedArguments[#entry] as WakeRunLogData;
        if (entry.agentId == 'insert-agent') await insertGate.future;
      });
      final orchestrator =
          boot(async, (agentId, _, _, _) async {
            if (agentId == 'replacement-agent') return replacementGate.future;
            return const {};
          }, concurrency: 1)..enqueueManualWake(
            agentId: 'insert-agent',
            reason: 'manual',
            triggerTokens: {'insert'},
          );
      // The insert hangs past the stale-drain threshold; a new drain takes
      // over and the old one hands its job back to the queue.
      async
        ..flushMicrotasks()
        ..elapse(const Duration(minutes: 13));
      orchestrator.enqueueManualWake(
        agentId: 'replacement-agent',
        reason: 'manual',
      );
      async.flushMicrotasks();
      insertGate.complete();
      async.flushMicrotasks();
      expect(executed.map((e) => e.agentId), ['replacement-agent']);
      expect(owedTokens(), contains('insert'), reason: 'handed back, not run');

      replacementGate.complete(null);
      async.flushMicrotasks();
      expect(executed.map((e) => e.agentId), [
        'replacement-agent',
        'insert-agent',
      ]);
      expect(owedTokens(), isEmpty);
    });
  });

  group('model conformance with specs/tla/WakeRuntime.tla', () {
    glados.Glados(
      glados.any.wakeIntentTrace,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'NoLostWake: after a restart every trigger was covered by a run that '
      'completed',
      (trace) {
        settings = {};
        executed = [];
        fakeAsync((async) {
          final triggered = <String>{};
          final covered = <String>{};
          final running =
              <(Set<String>, Completer<Map<String, VectorClock>?>)>[];
          WakeExecutor holding() => (_, _, triggers, _) {
            final run = Completer<Map<String, VectorClock>?>();
            running.add(({...triggers}, run));
            return run.future;
          };

          var current = boot(async, holding());
          var crashed = false;
          for (final (index, step) in trace.indexed) {
            switch (step.op) {
              case _WakeOp.trigger:
                final token = 'token-$index';
                triggered.add(token);
                current.enqueueManualWake(
                  agentId: 'agent-${step.arg % 2}',
                  reason: 'creation',
                  triggerTokens: {token},
                  supersede: false,
                );
              case _WakeOp.complete:
                if (running.isEmpty) break;
                final (triggers, run) = running.removeAt(
                  step.arg % running.length,
                );
                covered.addAll(triggers);
                run.complete(const {});
              case _WakeOp.crash:
                // One crash: a second would let the poison guard drop an
                // intent whose runs keep dying, which is its purpose.
                if (crashed) break;
                crashed = true;
                running.clear();
                current = boot(async, holding());
                unawaited(current.restoreWakeIntents());
            }
            // Distinct wall-clock seconds give every wake its own run key.
            async
              ..elapse(const Duration(seconds: 1))
              ..flushMicrotasks();
          }

          // Restart with executors that finish, and let everything drain.
          final last = boot(async, (_, _, triggers, _) async {
            covered.addAll(triggers);
            return const {};
          });
          unawaited(last.restoreWakeIntents());
          async
            ..elapse(const Duration(minutes: 1))
            ..flushMicrotasks();

          expect(
            triggered.difference(covered),
            isEmpty,
            reason: 'lost wakes after $trace',
          );
          expect(owedTokens(), isEmpty, reason: 'unsettled after $trace');
        });
      },
      tags: 'glados',
    );
  });

  test('without an intent store nothing is restored', () {
    fakeAsync((async) {
      late int restored;
      unawaited(orchestrator.restoreWakeIntents().then((n) => restored = n));
      async.flushMicrotasks();
      expect(restored, 0);
    });
  });

  // specs/tla/ScheduledWakeLease.tla: the scheduled-wake manager consumes a
  // record only once its wake is durable, and consumes rather than re-fires a
  // record whose wake a dead process left owed.
  test('a wake is owed from its flush until its run settles, across a '
      'process death', () {
    const workspace = 'goal-escalation:2026-08-08';
    const window = 'record@2026-08-08T00:00:00.000Z';
    fakeAsync((async) {
      final first = boot(
        async,
        (_, _, _, _) => Completer<Map<String, VectorClock>?>().future,
      );
      final runKey = first.enqueueManualWake(
        agentId: 'agent-1',
        reason: 'scheduled',
        triggerTokens: {workspace},
        workspaceKey: workspace,
      );
      first.markScheduledWindow(runKey, window);
      Set<String>? onDiskAtFlush;
      unawaited(
        first.flushWakeIntents().then((_) => onDiskAtFlush = owedTokens()),
      );
      async.flushMicrotasks();
      expect(onDiskAtFlush, {workspace});

      // The process dies mid-run; the next one owes the wake before it
      // restores it, and no longer once the restored run settles.
      final second = boot(async, noOpExecutor);
      bool? owedBeforeRestore;
      unawaited(
        second.owesWake(window).then((owed) => owedBeforeRestore = owed),
      );
      async.flushMicrotasks();
      expect(owedBeforeRestore, isTrue);

      unawaited(second.restoreWakeIntents());
      async.flushMicrotasks();
      bool? owedAfterRun;
      unawaited(
        second.owesWake(window).then((owed) => owedAfterRun = owed),
      );
      async.flushMicrotasks();
      expect(executed, hasLength(2));
      expect(owedAfterRun, isFalse);
    });
  });

  test('without an intent store no wake is owed and a flush is a no-op', () {
    fakeAsync((async) {
      bool? owed;
      var flushed = false;
      unawaited(
        orchestrator
            .owesWake('record@2026-08-08T00:00:00.000Z')
            .then((value) => owed = value),
      );
      orchestrator.markScheduledWindow('run-1', 'window');
      unawaited(orchestrator.flushWakeIntents().then((_) => flushed = true));
      async.flushMicrotasks();
      expect(owed, isFalse);
      expect(flushed, isTrue);
    });
  });
}
