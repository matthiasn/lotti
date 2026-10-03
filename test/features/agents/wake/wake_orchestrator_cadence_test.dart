import 'package:lotti/classes/agent_wake_cadence.dart';

import 'wake_orchestrator_test_harness.dart';

/// How a task agent's wake cadence (ADR-free: see the wake-orchestration
/// concept) shapes when a change runs: the window it waits, the "recordings
/// only" cadence that never wakes on changes, and the two markers — finished
/// work flushes now, an image analysis pulls the run to within a minute.
void main() {
  configureWakeOrchestratorTestSuite();

  const agentId = 'agent-1';
  const taskId = 'task-1';
  const categoryId = 'cat-1';

  late Map<String, AgentWakeCadence> categoryCadences;
  late AgentWakeCadence globalCadence;
  late List<Duration> runOffsets;
  late WakeOrchestrator cadenced;
  late StreamController<Set<String>> controller;
  late DateTime start;

  setUp(() {
    categoryCadences = {};
    globalCadence = AgentWakeCadence.hourly;
    runOffsets = [];
  });

  /// Starts an orchestrator whose task agent [agentId] watches [taskId] and
  /// follows category [categoryId] unless [override] is set. Must run inside
  /// the test's fake zone so its timers are fake.
  void startCadenced({AgentWakeCadence? override, bool taskAgent = true}) {
    cadenced =
        WakeOrchestrator(
          repository: mockRepository,
          queue: queue,
          runner: runner,
          taskWakeCadenceResolver: ({required override, required categoryId}) =>
              resolveAgentWakeCadence(
                task: override,
                category: categoryCadences[categoryId],
                global: globalCadence,
              ),
        )..addSubscription(
          makeSub(matchEntityIds: {taskId}, deferPropagatedMatches: false),
        );
    if (taskAgent) {
      cadenced.setTaskWakeCadenceRuntime(
        agentId,
        override: override,
        categoryId: categoryId,
      );
    }
    start = clock.now();
    cadenced.wakeExecutor = (_, _, _, _) async {
      runOffsets.add(clock.now().difference(start));
      return const {};
    };
    controller = StreamController<Set<String>>.broadcast();
    cadenced.start(controller.stream);
  }

  void stopCadenced(FakeAsync async) {
    unawaited(cadenced.stop());
    unawaited(controller.close());
    async.flushMicrotasks();
  }

  void emit(FakeAsync async, Set<String> tokens) {
    controller.add(tokens);
    async.flushMicrotasks();
  }

  void elapse(FakeAsync async, Duration duration) {
    async
      ..elapse(duration)
      ..flushMicrotasks();
  }

  /// A child edit as `updateDbEntity` emits it for the task.
  Set<String> childEdit() => {taskId, propagatedNotification(taskId)};

  group('coalescing window', () {
    test('an hourly agent runs a change an hour later, not after two '
        'minutes', () {
      fakeAsync((async) {
        startCadenced();
        emit(async, childEdit());

        elapse(async, const Duration(minutes: 59));
        expect(runOffsets, isEmpty);

        elapse(async, const Duration(minutes: 1));
        expect(runOffsets, [const Duration(hours: 1)]);
        stopCadenced(async);
      });
    });

    test('later edits inside the hour share its run', () {
      fakeAsync((async) {
        startCadenced();
        emit(async, childEdit());
        elapse(async, const Duration(minutes: 20));
        emit(async, childEdit());
        elapse(async, const Duration(minutes: 20));
        emit(async, {taskId});

        elapse(async, const Duration(hours: 2));
        expect(runOffsets, [const Duration(hours: 1)]);
        stopCadenced(async);
      });
    });

    test("the task's own cadence beats its category's", () {
      fakeAsync((async) {
        categoryCadences[categoryId] = AgentWakeCadence.hourly;
        startCadenced(override: AgentWakeCadence.live);
        emit(async, childEdit());

        elapse(async, const Duration(minutes: 2));
        expect(runOffsets, [const Duration(minutes: 2)]);
        stopCadenced(async);
      });
    });

    test("a category's cadence beats the app default", () {
      fakeAsync((async) {
        categoryCadences[categoryId] = AgentWakeCadence.live;
        startCadenced();
        emit(async, childEdit());

        elapse(async, const Duration(minutes: 2));
        expect(runOffsets, [const Duration(minutes: 2)]);
        stopCadenced(async);
      });
    });

    test('a changed category cadence applies to the next change', () {
      fakeAsync((async) {
        startCadenced();
        emit(async, childEdit());
        elapse(async, const Duration(hours: 1));
        expect(runOffsets, [const Duration(hours: 1)]);

        categoryCadences[categoryId] = AgentWakeCadence.live;
        emit(async, childEdit());
        elapse(async, const Duration(minutes: 2));

        expect(runOffsets, [
          const Duration(hours: 1),
          const Duration(hours: 1, minutes: 2),
        ]);
        stopCadenced(async);
      });
    });

    test('an agent without cadence inputs keeps the two-minute window', () {
      fakeAsync((async) {
        startCadenced(taskAgent: false);
        expect(cadenced.wakeCadenceFor(agentId), isNull);
        emit(async, childEdit());

        elapse(async, WakeOrchestrator.throttleWindow);
        expect(runOffsets, [WakeOrchestrator.throttleWindow]);
        stopCadenced(async);
      });
    });
  });

  group('recordings only', () {
    test('a change never starts a run on its own', () {
      fakeAsync((async) {
        startCadenced(override: AgentWakeCadence.recordingsOnly);
        emit(async, childEdit());

        expect(queue.isEmpty, isTrue);
        elapse(async, const Duration(hours: 3));
        expect(runOffsets, isEmpty);
        stopCadenced(async);
      });
    });

    test('finished work and images do not start one either', () {
      fakeAsync((async) {
        startCadenced(override: AgentWakeCadence.recordingsOnly);
        emit(async, {
          ...childEdit(),
          wakeFlushNotification(taskId),
          imageAnalysisNotification(taskId),
        });

        elapse(async, const Duration(hours: 3));
        expect(runOffsets, isEmpty);
        stopCadenced(async);
      });
    });
  });

  group('finished work', () {
    test('a flush runs the pending hourly change now', () {
      fakeAsync((async) {
        startCadenced();
        emit(async, childEdit());
        elapse(async, const Duration(minutes: 5));

        // The marker can arrive in a later batch than its write.
        emit(async, {wakeFlushNotification(taskId)});
        expect(runOffsets, [const Duration(minutes: 5)]);

        // The hour-long countdown went with it: nothing runs again.
        elapse(async, const Duration(hours: 2));
        expect(runOffsets, [const Duration(minutes: 5)]);
        stopCadenced(async);
      });
    });

    test('a flush with its write in the same batch runs once, now', () {
      fakeAsync((async) {
        startCadenced();
        emit(async, {...childEdit(), wakeFlushNotification(taskId)});

        expect(runOffsets, [Duration.zero]);
        elapse(async, const Duration(hours: 2));
        expect(runOffsets, [Duration.zero]);
        stopCadenced(async);
      });
    });

    test('an agent without a cadence ignores the marker', () {
      fakeAsync((async) {
        startCadenced(taskAgent: false);
        emit(async, {...childEdit(), wakeFlushNotification(taskId)});

        expect(runOffsets, isEmpty);
        elapse(async, WakeOrchestrator.throttleWindow);
        expect(runOffsets, [WakeOrchestrator.throttleWindow]);
        stopCadenced(async);
      });
    });
  });

  group('image analysis', () {
    Set<String> imageAnalysed() => {
      ...childEdit(),
      imageAnalysisNotification(taskId),
    };

    test('runs within a minute on an hourly agent', () {
      fakeAsync((async) {
        startCadenced();
        emit(async, imageAnalysed());

        elapse(async, const Duration(seconds: 59));
        expect(runOffsets, isEmpty);
        elapse(async, const Duration(seconds: 1));
        expect(runOffsets, [imageAnalysisWindow]);
        stopCadenced(async);
      });
    });

    test('pulls an hour-long countdown forward', () {
      fakeAsync((async) {
        startCadenced();
        emit(async, childEdit());
        elapse(async, const Duration(minutes: 10));

        emit(async, imageAnalysed());
        elapse(async, imageAnalysisWindow);

        expect(runOffsets, [const Duration(minutes: 11)]);
        stopCadenced(async);
      });
    });

    test('images in a row share one run; the minute is never extended', () {
      fakeAsync((async) {
        startCadenced();
        emit(async, imageAnalysed());
        elapse(async, const Duration(seconds: 40));
        emit(async, imageAnalysed());
        elapse(async, const Duration(seconds: 20));

        expect(runOffsets, [imageAnalysisWindow]);
        elapse(async, const Duration(hours: 2));
        expect(runOffsets, [imageAnalysisWindow]);
        stopCadenced(async);
      });
    });

    test('never pushes back a sooner deadline', () {
      fakeAsync((async) {
        startCadenced(override: AgentWakeCadence.live);
        emit(async, childEdit());
        elapse(async, const Duration(seconds: 100));

        // now + 60 s would be 160 s; the live window ends at 120 s.
        emit(async, imageAnalysed());
        elapse(async, const Duration(seconds: 20));

        expect(runOffsets, [WakeOrchestrator.throttleWindow]);
        stopCadenced(async);
      });
    });
  });

  group('runtime inputs', () {
    test('mirrors a task identity: its own cadence and single category', () {
      final o = WakeOrchestrator(
        repository: mockRepository,
        queue: queue,
        runner: runner,
        taskWakeCadenceResolver: ({required override, required categoryId}) =>
            resolveAgentWakeCadence(
              task: override,
              category: const {'c': AgentWakeCadence.live}[categoryId],
            ),
      );
      addTearDown(o.stop);

      o.mirrorTaskWakeCadence(
        makeTestIdentity(agentId: 'a', allowedCategoryIds: const {'c'}),
      );
      expect(o.wakeCadenceFor('a'), AgentWakeCadence.live);

      o.mirrorTaskWakeCadence(
        makeTestIdentity(
          agentId: 'a',
          allowedCategoryIds: const {'c'},
          config: const AgentConfig(
            wakeCadence: AgentWakeCadence.recordingsOnly,
          ),
        ),
      );
      expect(o.wakeCadenceFor('a'), AgentWakeCadence.recordingsOnly);

      // Scoped to several categories: none is "the" category.
      o.mirrorTaskWakeCadence(
        makeTestIdentity(agentId: 'b', allowedCategoryIds: const {'c', 'd'}),
      );
      expect(o.wakeCadenceFor('b'), AgentWakeCadence.hourly);

      // Other kinds have no cadence.
      o.mirrorTaskWakeCadence(
        makeTestIdentity(agentId: 'p', kind: 'project_agent'),
      );
      expect(o.wakeCadenceFor('p'), isNull);

      o.removeSubscriptions('a');
      expect(o.wakeCadenceFor('a'), isNull);
    });

    test('without a resolver no agent has a cadence', () {
      orchestrator.setTaskWakeCadenceRuntime(
        agentId,
        override: AgentWakeCadence.hourly,
        categoryId: null,
      );
      expect(orchestrator.wakeCadenceFor(agentId), isNull);
    });
  });
}
