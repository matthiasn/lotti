import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_wake_progress.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_wake_trace.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';

const _dayId = 'dayplan-2026-11-04';

/// A clock the test advances by hand.
class _Clock {
  _Clock(this.now);

  DateTime now;

  void advance(int milliseconds) =>
      now = now.add(Duration(milliseconds: milliseconds));

  Clock get clock => Clock(() => now);
}

void main() {
  setUpAll(registerAllFallbackValues);

  late _Clock time;
  late DayAgentWakeProgressBus bus;
  late MockDomainLogger logger;

  setUp(() {
    time = _Clock(DateTime(2026, 11, 3, 21));
    bus = DayAgentWakeProgressBus();
    logger = MockDomainLogger();
    when(
      () => logger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
        level: any(named: 'level'),
      ),
    ).thenReturn(null);
  });
  tearDown(() => bus.dispose());

  DayAgentWakeTrace newTrace() => withClock(
    time.clock,
    () => DayAgentWakeTrace(
      dayId: _dayId,
      runKey: 'run-1',
      bus: bus,
      domainLogger: logger,
    ),
  );

  T at<T>(T Function() body) => withClock(time.clock, body);

  test('publishes itself on creation, in the context step', () {
    newTrace();

    final wake = bus.statusFor(_dayId).wake!;
    expect(wake.step, DayAgentWakeStep.preparingContext);
    expect(wake.runKey, 'run-1');
  });

  test('records each step with the time spent in it', () {
    final trace = newTrace();
    time.advance(120);
    at(() => trace.enter(DayAgentWakeStep.compactingMemory));
    time.advance(30);
    at(() => trace.enter(DayAgentWakeStep.assemblingPrompt));
    time.advance(50);
    // Re-entering the active step changes nothing.
    at(() => trace.enter(DayAgentWakeStep.assemblingPrompt));
    time.advance(10);
    at(() => trace.enter(DayAgentWakeStep.saving));

    final steps = bus.statusFor(_dayId).wake!.completedSteps;
    expect(
      [for (final s in steps) (s.step, s.elapsed.inMilliseconds)],
      [
        (DayAgentWakeStep.preparingContext, 120),
        (DayAgentWakeStep.compactingMemory, 30),
        (DayAgentWakeStep.assemblingPrompt, 60),
      ],
    );
  });

  test('records model turns: first chunk, usage, duration, failure', () {
    final trace = newTrace()..recordModel('deepseek-v4-1-flash-1017');
    final first = at(trace.turnStarted);
    time.advance(400);
    at(() => trace.turnFirstChunk(first));
    time.advance(100);
    // A later first-chunk report never overwrites the measured one.
    at(() => trace.turnFirstChunk(first));
    at(
      () => trace
        ..turnUsage(first, inputTokens: 4000, outputTokens: 10)
        ..turnUsage(
          first,
          inputTokens: 4000,
          outputTokens: 900,
          reasoningTokens: 300,
        ),
    );
    time.advance(2500);
    at(() => trace.turnFinished(first));
    final second = at(trace.turnStarted);
    time.advance(1000);
    at(() => trace.turnFinished(second, failed: true));

    final wake = bus.statusFor(_dayId).wake!;
    expect(wake.step, DayAgentWakeStep.callingModel);
    expect(wake.modelId, 'deepseek-v4-1-flash-1017');
    final turn = wake.turns.first;
    expect(turn.timeToFirstChunk, const Duration(milliseconds: 400));
    expect(turn.elapsed, const Duration(milliseconds: 3000));
    expect(
      (turn.inputTokens, turn.outputTokens, turn.reasoningTokens),
      (
        4000,
        900,
        300,
      ),
    );
    expect(wake.turns.last.failed, isTrue);
    expect(wake.turns.last.elapsed, const Duration(seconds: 1));
  });

  test('traceTool times a call and records its verdict', () async {
    final trace = newTrace();

    final result = await at(
      () => trace.traceTool(
        'draft_day_plan',
        () async {
          time.advance(40);
          return false;
        },
        succeeded: (ok) => ok,
      ),
    );

    expect(result, isFalse);
    final wake = bus.statusFor(_dayId).wake!;
    expect(wake.step, DayAgentWakeStep.runningTool);
    final call = wake.toolCalls.single;
    expect(call.name, 'draft_day_plan');
    expect(call.elapsed, const Duration(milliseconds: 40));
    expect(call.succeeded, isFalse);
  });

  test('traceTool records a throwing call as failed and rethrows', () async {
    final trace = newTrace();

    await expectLater(
      at(
        () => trace.traceTool<bool>(
          'search_memory',
          () async => throw StateError('db gone'),
          succeeded: (ok) => ok,
        ),
      ),
      throwsStateError,
    );

    final call = bus.statusFor(_dayId).wake!.toolCalls.single;
    expect(call.succeeded, isFalse);
    expect(call.isRunning, isFalse);
  });

  test('finish logs one PII-free timing line and freezes the trace', () {
    final trace = newTrace()
      ..recordModel('model-a')
      ..wakeKind = 'draft'
      ..recordPrompt(2853);
    time.advance(200);
    final turn = at(trace.turnStarted);
    at(() => trace.turnUsage(turn, inputTokens: 4926, outputTokens: 1217));
    time.advance(3000);
    at(() => trace.turnFinished(turn));
    at(() => trace.finish(succeeded: true));
    // Anything after finish is ignored, including a second finish.
    at(() => trace.enter(DayAgentWakeStep.saving));
    at(() => trace.finish(succeeded: false, error: 'late'));

    final line = verify(
      () => logger.log(
        LogDomain.agentWorkflow,
        captureAny(),
        subDomain: 'wakeTrace',
      ),
    ).captured.cast<String>().singleWhere((l) => l.startsWith('wake trace:'));
    expect(line, startsWith('wake trace: ok '));
    expect(line, contains('kind=draft'));
    expect(line, contains('model=model-a'));
    expect(line, contains('totalMs=3200'));
    expect(line, contains('preparingContext=200'));
    expect(line, contains('callingModel=3000'));
    expect(line, contains('promptChars=2853'));
    expect(line, contains('tokensIn=4926 tokensOut=1217'));
    expect(line, contains('run=[id:'), reason: 'run keys are sanitized');
    final wake = bus.statusFor(_dayId).wake!;
    expect(wake.step, DayAgentWakeStep.completed);
    expect(wake.error, isNull);
  });

  test('logs every transition, so a hung wake names the step and turn it is '
      'stuck in', () {
    final trace = newTrace();
    time.advance(40);
    at(() => trace.enter(DayAgentWakeStep.compactingMemory));
    time.advance(5);
    at(() => trace.enter(DayAgentWakeStep.assemblingPrompt));
    at(trace.turnStarted);
    time.advance(900);
    at(() => trace.toolStarted('search_memory'));
    time.advance(30);
    // The second model turn hangs: no finish ever comes.
    at(trace.turnStarted);

    final lines = verify(
      () => logger.log(
        LogDomain.agentWorkflow,
        captureAny(),
        subDomain: 'wakeTrace',
      ),
    ).captured.cast<String>();
    const prefix = 'wake step: run=[id:run-1] day=$_dayId';
    expect(lines, [
      '$prefix preparingContext',
      '$prefix compactingMemory after preparingContext=40ms',
      '$prefix assemblingPrompt after compactingMemory=5ms',
      '$prefix callingModel #0 after assemblingPrompt=0ms',
      '$prefix runningTool search_memory after callingModel=900ms',
      '$prefix callingModel #1 after runningTool=30ms',
    ]);
  });

  test('back-to-back turns and back-to-back tool calls are each logged', () {
    final trace = newTrace();
    final first = at(trace.turnStarted);
    at(() => trace.turnFinished(first));
    // A forced retry: a second turn with no tool call in between.
    at(trace.turnStarted);
    at(() => trace.toolStarted('search_memory'));
    at(() => trace.toolStarted('draft_day_plan'));

    final lines = verify(
      () => logger.log(
        LogDomain.agentWorkflow,
        captureAny(),
        subDomain: 'wakeTrace',
      ),
    ).captured.cast<String>();
    expect(
      lines.skip(1).map((line) => line.split(' ').skip(4).take(2).join(' ')),
      [
        'callingModel #0',
        'callingModel #1',
        'runningTool search_memory',
        'runningTool draft_day_plan',
      ],
    );
    expect(trace.progress.turns, hasLength(2));
    expect(trace.progress.toolCalls, hasLength(2));
  });

  test('a failed finish carries the error to the progress', () {
    final trace = newTrace();
    at(() => trace.finish(succeeded: false, error: 'deadline'));

    final wake = bus.statusFor(_dayId).wake!;
    expect(wake.step, DayAgentWakeStep.failed);
    expect(wake.error, 'deadline');
    expect(
      trace.summaryLine(succeeded: false),
      startsWith('wake trace: failed'),
    );
  });

  test('turn and tool reports for unknown indices are ignored', () {
    final trace = newTrace()
      ..turnFirstChunk(3)
      ..turnFinished(3)
      ..turnUsage(3, inputTokens: 1)
      ..toolFinished(2, succeeded: true);

    expect(trace.progress.turns, isEmpty);
    expect(trace.progress.toolCalls, isEmpty);
  });

  group('DayAgentWakeTraceSlot', () {
    test('finish before start is a no-op; start is idempotent', () {
      final slot = DayAgentWakeTraceSlot(bus: bus, domainLogger: logger)
        ..finish(succeeded: true);
      expect(slot.trace, isNull);
      expect(bus.statusFor(_dayId).wake, isNull);

      final first = at(() => slot.start(dayId: _dayId, runKey: 'run-1'));
      final again = at(() => slot.start(dayId: _dayId, runKey: 'run-2'));
      at(() => slot.finish(succeeded: false, error: 'x'));

      expect(identical(first, again), isTrue);
      expect(bus.statusFor(_dayId).wake!.step, DayAgentWakeStep.failed);
    });
  });
}
