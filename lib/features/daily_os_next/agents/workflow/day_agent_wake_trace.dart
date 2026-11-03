import 'package:clock/clock.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_wake_progress.dart';
import 'package:lotti/services/domain_logging.dart';

/// Records where one day-agent wake spends its time and publishes each change
/// to a [DayAgentWakeProgressBus].
///
/// The workflow calls [enter] at every phase boundary; the tracing inference
/// repository reports provider turns; the tool dispatcher reports tool calls.
/// [finish] writes one `agentWorkflow`/`wakeTrace` log line with every step
/// duration, turn timing, token count and tool call — names, numbers and
/// durations only, never prompt or response content.
class DayAgentWakeTrace {
  DayAgentWakeTrace({
    required String dayId,
    required String runKey,
    this.bus,
    this.domainLogger,
  }) : _progress = DayAgentWakeProgress(
         dayId: dayId,
         runKey: runKey,
         step: DayAgentWakeStep.preparingContext,
         startedAt: clock.now(),
         stepStartedAt: clock.now(),
       ) {
    _publish();
    _logStep();
  }

  final DayAgentWakeProgressBus? bus;
  final DomainLogger? domainLogger;

  DayAgentWakeProgress _progress;
  String? _wakeKind;
  final _turnStarts = <int, DateTime>{};
  final _toolStarts = <int, DateTime>{};

  /// The current snapshot.
  DayAgentWakeProgress get progress => _progress;

  /// Moves to [step], closing the current one. Re-entering the active step is
  /// a no-op; after [finish] every call is ignored.
  ///
  /// The first entry into each step is also logged, so a wake that hangs —
  /// and therefore never reaches [finish] — still leaves the step it is stuck
  /// in as its last `wakeTrace` line.
  void enter(DayAgentWakeStep step) {
    if (_progress.isFinished || _progress.step == step) return;
    final now = clock.now();
    final previous = _progress.step;
    final previousElapsed = now.difference(_progress.stepStartedAt);
    _progress = _progress.copyWith(
      step: step,
      stepStartedAt: now,
      completedSteps: [
        ..._progress.completedSteps,
        DayAgentWakeStepTiming(
          step: _progress.step,
          elapsed: now.difference(_progress.stepStartedAt),
        ),
      ],
    );
    _publish();
    if (!_progress.isFinished) {
      _logStep(after: (previous, previousElapsed));
    }
  }

  final _loggedSteps = <DayAgentWakeStep>{};

  void _logStep({(DayAgentWakeStep, Duration)? after}) {
    final step = _progress.step;
    if (!_loggedSteps.add(step)) return;
    final since = after == null
        ? ''
        : ' after ${after.$1.name}=${after.$2.inMilliseconds}ms';
    domainLogger?.log(
      LogDomain.agentWorkflow,
      'wake step: run=${DomainLogger.sanitizeId(_progress.runKey)} '
      'day=${_progress.dayId} ${step.name}$since',
      subDomain: 'wakeTrace',
    );
  }

  /// Records the resolved thinking model.
  void recordModel(String modelId) {
    _progress = _progress.copyWith(modelId: modelId);
    _publish();
  }

  /// The wake mode, for the log line only.
  // ignore: avoid_setters_without_getters
  set wakeKind(String kind) => _wakeKind = kind;

  /// Records the assembled user-message length.
  void recordPrompt(int chars) {
    _progress = _progress.copyWith(promptChars: chars);
    _publish();
  }

  /// A provider turn subscribed; returns its index for the other turn calls.
  int turnStarted() {
    final index = _progress.turns.length;
    _turnStarts[index] = clock.now();
    enter(DayAgentWakeStep.callingModel);
    _progress = _progress.copyWith(
      turns: [
        ..._progress.turns,
        DayAgentModelTurn(index: index),
      ],
    );
    _publish();
    return index;
  }

  /// The provider sent the first chunk of turn [index].
  void turnFirstChunk(int index) {
    final start = _turnStarts[index];
    if (start == null) return;
    _updateTurn(
      index,
      (turn) => turn.timeToFirstChunk == null
          ? turn.copyWith(timeToFirstChunk: clock.now().difference(start))
          : turn,
    );
  }

  /// Turn [index] reported usage. Providers repeat cumulative usage chunks,
  /// so the newest report replaces the previous one.
  void turnUsage(
    int index, {
    int? inputTokens,
    int? outputTokens,
    int? reasoningTokens,
  }) {
    _updateTurn(
      index,
      (turn) => turn.copyWith(
        inputTokens: inputTokens,
        outputTokens: outputTokens,
        reasoningTokens: reasoningTokens,
      ),
    );
  }

  /// Turn [index] ended, normally or with an error.
  void turnFinished(int index, {bool failed = false}) {
    final start = _turnStarts.remove(index);
    if (start == null) return;
    _updateTurn(
      index,
      (turn) => turn.copyWith(
        elapsed: clock.now().difference(start),
        failed: failed,
      ),
    );
  }

  /// A tool call started; returns its index for [toolFinished].
  int toolStarted(String name) {
    final index = _progress.toolCalls.length;
    _toolStarts[index] = clock.now();
    enter(DayAgentWakeStep.runningTool);
    _progress = _progress.copyWith(
      toolCalls: [
        ..._progress.toolCalls,
        DayAgentToolCallTiming(name: name),
      ],
    );
    _publish();
    return index;
  }

  /// Tool call [index] returned.
  void toolFinished(int index, {required bool succeeded}) {
    final start = _toolStarts.remove(index);
    if (start == null || index >= _progress.toolCalls.length) return;
    final calls = [..._progress.toolCalls];
    calls[index] = DayAgentToolCallTiming(
      name: calls[index].name,
      elapsed: clock.now().difference(start),
      succeeded: succeeded,
    );
    _progress = _progress.copyWith(toolCalls: calls);
    _publish();
  }

  /// Runs one tool call under the trace, recording its duration and whether
  /// [succeeded] judged the result a success. A throwing call counts as
  /// failed and is rethrown.
  Future<T> traceTool<T>(
    String name,
    Future<T> Function() run, {
    required bool Function(T result) succeeded,
  }) async {
    final index = toolStarted(name);
    try {
      final result = await run();
      toolFinished(index, succeeded: succeeded(result));
      return result;
    } catch (_) {
      toolFinished(index, succeeded: false);
      rethrow;
    }
  }

  /// Ends the trace and logs its summary. Idempotent.
  void finish({required bool succeeded, String? error}) {
    if (_progress.isFinished) return;
    enter(succeeded ? DayAgentWakeStep.completed : DayAgentWakeStep.failed);
    if (!succeeded && error != null) {
      _progress = _progress.copyWith(error: error);
      _publish();
    }
    domainLogger?.log(
      LogDomain.agentWorkflow,
      summaryLine(succeeded: succeeded),
      subDomain: 'wakeTrace',
    );
  }

  /// The one-line timing summary [finish] logs.
  String summaryLine({required bool succeeded}) {
    final p = _progress;
    final total = clock.now().difference(p.startedAt);
    final steps = p.completedSteps
        .where(
          (timing) =>
              timing.step != DayAgentWakeStep.completed &&
              timing.step != DayAgentWakeStep.failed,
        )
        .map((timing) => '${timing.step.name}=${timing.elapsed.inMilliseconds}')
        .join(' ');
    final turns = p.turns
        .map(
          (turn) =>
              '[#${turn.index} ttfc=${turn.timeToFirstChunk?.inMilliseconds} '
              'ms=${turn.elapsed?.inMilliseconds} in=${turn.inputTokens} '
              'out=${turn.outputTokens} reasoning=${turn.reasoningTokens}'
              '${turn.failed ? ' failed' : ''}]',
        )
        .join(' ');
    final tools = p.toolCalls
        .map(
          (call) =>
              '${call.name}:${call.elapsed?.inMilliseconds}ms'
              '${call.succeeded == false ? ':failed' : ''}',
        )
        .join(',');
    return 'wake trace: ${succeeded ? 'ok' : 'failed'} '
        'run=${DomainLogger.sanitizeId(p.runKey)} kind=${_wakeKind ?? '-'} '
        'model=${p.modelId ?? '-'} totalMs=${total.inMilliseconds} '
        'stepsMs={$steps} promptChars=${p.promptChars ?? -1} '
        'tokensIn=${p.inputTokens} tokensOut=${p.outputTokens} '
        'turns=${p.turns.length} $turns tools=[$tools]';
  }

  void _updateTurn(
    int index,
    DayAgentModelTurn Function(DayAgentModelTurn turn) update,
  ) {
    if (index >= _progress.turns.length) return;
    final turns = [..._progress.turns];
    turns[index] = update(turns[index]);
    _progress = _progress.copyWith(turns: turns);
    _publish();
  }

  void _publish() => bus?.publishWake(_progress);
}

/// Holds the trace of one wake from the moment its day is resolved, so the
/// caller that owns the wake's every exit can finish it.
class DayAgentWakeTraceSlot {
  DayAgentWakeTraceSlot({this.bus, this.domainLogger});

  final DayAgentWakeProgressBus? bus;
  final DomainLogger? domainLogger;
  DayAgentWakeTrace? _trace;

  /// The started trace, or null before [start].
  DayAgentWakeTrace? get trace => _trace;

  /// Starts the trace for the wake's resolved [dayId].
  DayAgentWakeTrace start({required String dayId, required String runKey}) =>
      _trace ??= DayAgentWakeTrace(
        dayId: dayId,
        runKey: runKey,
        bus: bus,
        domainLogger: domainLogger,
      );

  /// Finishes the trace, if one was started.
  void finish({required bool succeeded, String? error}) =>
      _trace?.finish(succeeded: succeeded, error: error);
}
