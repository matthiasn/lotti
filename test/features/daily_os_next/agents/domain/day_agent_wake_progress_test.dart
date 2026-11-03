import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_wake_progress.dart';

final _t0 = DateTime(2026, 11, 3, 21);

DayAgentWakeProgress _wake({
  String dayId = 'dayplan-2026-11-04',
  DayAgentWakeStep step = DayAgentWakeStep.callingModel,
  DateTime? stepStartedAt,
  List<DayAgentWakeStepTiming> completedSteps = const [],
  List<DayAgentModelTurn> turns = const [],
}) => DayAgentWakeProgress(
  dayId: dayId,
  runKey: 'run-1',
  step: step,
  startedAt: _t0,
  stepStartedAt: stepStartedAt ?? _t0,
  completedSteps: completedSteps,
  turns: turns,
);

DayAgentJobAttempt _attempt(String dayId) => DayAgentJobAttempt(
  dayId: dayId,
  attempts: 1,
  maxAttempts: 5,
  updatedAt: _t0,
  willRetry: true,
);

void main() {
  group('DayAgentWakeProgress', () {
    test('sums tokens over the turns that reported usage', () {
      final wake = _wake(
        turns: const [
          DayAgentModelTurn(index: 0, inputTokens: 1000, outputTokens: 50),
          DayAgentModelTurn(index: 1, inputTokens: 1200),
          DayAgentModelTurn(index: 2),
        ],
      );

      expect(wake.inputTokens, 2200);
      expect(wake.outputTokens, 50);
    });

    test('timeIn adds every visit of a step plus the running one', () {
      final wake = _wake(
        stepStartedAt: _t0.add(const Duration(seconds: 10)),
        completedSteps: const [
          DayAgentWakeStepTiming(
            step: DayAgentWakeStep.callingModel,
            elapsed: Duration(seconds: 4),
          ),
          DayAgentWakeStepTiming(
            step: DayAgentWakeStep.runningTool,
            elapsed: Duration(seconds: 1),
          ),
        ],
      );
      final now = _t0.add(const Duration(seconds: 13));

      expect(
        wake.timeIn(DayAgentWakeStep.callingModel, now: now),
        const Duration(seconds: 7),
      );
      expect(
        wake.timeIn(DayAgentWakeStep.callingModel),
        const Duration(seconds: 4),
        reason: 'without a now, only closed visits count',
      );
      expect(
        wake.timeIn(DayAgentWakeStep.runningTool, now: now),
        const Duration(seconds: 1),
      );
    });

    test('a finished wake no longer accrues time in its last step', () {
      final wake = _wake(step: DayAgentWakeStep.completed);

      expect(wake.isFinished, isTrue);
      expect(
        wake.timeIn(
          DayAgentWakeStep.completed,
          now: _t0.add(const Duration(minutes: 5)),
        ),
        Duration.zero,
      );
    });

    test('copyWith keeps identity fields and replaces the given ones', () {
      final wake = _wake();
      final updated = wake.copyWith(
        step: DayAgentWakeStep.failed,
        modelId: 'model-a',
        promptChars: 120,
        error: 'boom',
      );

      expect(updated.runKey, wake.runKey);
      expect(updated.startedAt, wake.startedAt);
      expect(updated.step, DayAgentWakeStep.failed);
      expect(updated.modelId, 'model-a');
      expect(updated.promptChars, 120);
      expect(updated.error, 'boom');
    });
  });

  group('DayAgentModelTurn', () {
    test('is running until it has an elapsed time', () {
      const turn = DayAgentModelTurn(index: 0);
      final done = turn.copyWith(
        elapsed: const Duration(seconds: 2),
        failed: true,
      );

      expect(turn.isRunning, isTrue);
      expect(done.isRunning, isFalse);
      expect(done.failed, isTrue);
      expect(done.index, 0);
    });
  });

  group('DayAgentWakeProgressBus', () {
    test('watch replays the current status, then only its own day', () async {
      final bus = DayAgentWakeProgressBus();
      addTearDown(bus.dispose);
      bus.publishWake(_wake(step: DayAgentWakeStep.preparingContext));

      final seen = <DayAgentLiveStatus>[];
      final subscription = bus.watch('dayplan-2026-11-04').listen(seen.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      bus
        ..publishWake(_wake(dayId: 'dayplan-2026-11-05'))
        ..publishAttempt(_attempt('dayplan-2026-11-04'));
      await pumpEventQueue();

      expect(seen, hasLength(2));
      expect(seen.first.wake?.step, DayAgentWakeStep.preparingContext);
      expect(seen.first.lastAttempt, isNull);
      expect(seen.last.lastAttempt?.attempts, 1);
      expect(
        seen.last.wake?.dayId,
        'dayplan-2026-11-04',
        reason: "another day's wake must not replace this day's",
      );
    });

    test('statusFor is empty for a day nothing was published for', () {
      final bus = DayAgentWakeProgressBus();
      addTearDown(bus.dispose);

      final status = bus.statusFor('dayplan-2026-11-04');

      expect(status.wake, isNull);
      expect(status.lastAttempt, isNull);
    });

    test('publishing after dispose is ignored instead of throwing', () async {
      final bus = DayAgentWakeProgressBus();
      await bus.dispose();

      bus.publishWake(_wake());

      expect(bus.statusFor('dayplan-2026-11-04').wake, isNotNull);
    });
  });
}
