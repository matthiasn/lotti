import 'dart:async';

import 'package:flutter/foundation.dart';

/// The pipeline step a running day-agent wake is in.
///
/// These are the workflow's real phases, in the order a wake moves through
/// them — not a narration. [runningTool] may repeat between [callingModel]
/// turns.
enum DayAgentWakeStep {
  /// Loading agent state, observations, the profile and capture metadata.
  preparingContext,

  /// Folding the agent's event log into a summary checkpoint (an LLM call
  /// when the tail is past its budget) and assembling the compacted log.
  compactingMemory,

  /// Building the planning sections and the user message.
  assemblingPrompt,

  /// Waiting on a provider turn.
  callingModel,

  /// Executing a tool call the model made.
  runningTool,

  /// Persisting the thought, report and wake bookkeeping.
  saving,

  /// The wake finished successfully.
  completed,

  /// The wake failed; see [DayAgentWakeProgress.error].
  failed,
}

/// Wall-clock time one finished [DayAgentWakeStep] took.
@immutable
class DayAgentWakeStepTiming {
  const DayAgentWakeStepTiming({required this.step, required this.elapsed});

  final DayAgentWakeStep step;
  final Duration elapsed;
}

/// One provider turn of a wake.
@immutable
class DayAgentModelTurn {
  const DayAgentModelTurn({
    required this.index,
    this.timeToFirstChunk,
    this.elapsed,
    this.inputTokens,
    this.outputTokens,
    this.reasoningTokens,
    this.failed = false,
  });

  /// Zero-based turn number within the wake.
  final int index;

  /// Time from subscribing to the provider stream to its first chunk, or
  /// null while still waiting for it.
  final Duration? timeToFirstChunk;

  /// Total turn time, or null while the turn is still streaming.
  final Duration? elapsed;
  final int? inputTokens;
  final int? outputTokens;
  final int? reasoningTokens;

  /// Whether the provider stream ended in an error (timeout, output ceiling,
  /// HTTP failure).
  final bool failed;

  bool get isRunning => elapsed == null;

  DayAgentModelTurn copyWith({
    Duration? timeToFirstChunk,
    Duration? elapsed,
    int? inputTokens,
    int? outputTokens,
    int? reasoningTokens,
    bool? failed,
  }) => DayAgentModelTurn(
    index: index,
    timeToFirstChunk: timeToFirstChunk ?? this.timeToFirstChunk,
    elapsed: elapsed ?? this.elapsed,
    inputTokens: inputTokens ?? this.inputTokens,
    outputTokens: outputTokens ?? this.outputTokens,
    reasoningTokens: reasoningTokens ?? this.reasoningTokens,
    failed: failed ?? this.failed,
  );
}

/// One tool call the model made during a wake.
@immutable
class DayAgentToolCallTiming {
  const DayAgentToolCallTiming({
    required this.name,
    this.elapsed,
    this.succeeded,
  });

  /// The tool's wire name, e.g. `draft_day_plan`.
  final String name;

  /// Execution time, or null while the call is still running.
  final Duration? elapsed;

  /// Whether the handler reported success; null while running.
  final bool? succeeded;

  bool get isRunning => elapsed == null;
}

/// A snapshot of one day-agent wake as it runs: which step it is in, the
/// resolved model, every provider turn and tool call so far.
///
/// Device-local and in-memory only. It carries no prompt or response content
/// — names, counts and durations — so nothing here is user data.
@immutable
class DayAgentWakeProgress {
  const DayAgentWakeProgress({
    required this.dayId,
    required this.runKey,
    required this.step,
    required this.startedAt,
    required this.stepStartedAt,
    this.modelId,
    this.promptChars,
    this.completedSteps = const [],
    this.turns = const [],
    this.toolCalls = const [],
    this.error,
  });

  final String dayId;
  final String runKey;
  final DayAgentWakeStep step;
  final DateTime startedAt;
  final DateTime stepStartedAt;

  /// Provider model id of the resolved thinking slot, once resolved.
  final String? modelId;

  /// Length of the assembled user message, once assembled.
  final int? promptChars;

  /// Steps already left, in order, with their durations.
  final List<DayAgentWakeStepTiming> completedSteps;
  final List<DayAgentModelTurn> turns;
  final List<DayAgentToolCallTiming> toolCalls;

  /// Failure summary when [step] is [DayAgentWakeStep.failed].
  final String? error;

  bool get isFinished =>
      step == DayAgentWakeStep.completed || step == DayAgentWakeStep.failed;

  /// Prompt tokens summed over every turn that reported usage.
  int get inputTokens => _sum((turn) => turn.inputTokens);

  /// Completion tokens summed over every turn that reported usage.
  int get outputTokens => _sum((turn) => turn.outputTokens);

  int _sum(int? Function(DayAgentModelTurn turn) pick) =>
      turns.fold(0, (total, turn) => total + (pick(turn) ?? 0));

  /// Total time spent in [step] across every visit, including the current
  /// one up to [now] when it is the active step.
  Duration timeIn(DayAgentWakeStep step, {DateTime? now}) {
    var total = Duration.zero;
    for (final timing in completedSteps) {
      if (timing.step == step) total += timing.elapsed;
    }
    if (now != null && this.step == step && !isFinished) {
      total += now.difference(stepStartedAt);
    }
    return total;
  }

  DayAgentWakeProgress copyWith({
    DayAgentWakeStep? step,
    DateTime? stepStartedAt,
    String? modelId,
    int? promptChars,
    List<DayAgentWakeStepTiming>? completedSteps,
    List<DayAgentModelTurn>? turns,
    List<DayAgentToolCallTiming>? toolCalls,
    String? error,
  }) => DayAgentWakeProgress(
    dayId: dayId,
    runKey: runKey,
    step: step ?? this.step,
    startedAt: startedAt,
    stepStartedAt: stepStartedAt ?? this.stepStartedAt,
    modelId: modelId ?? this.modelId,
    promptChars: promptChars ?? this.promptChars,
    completedSteps: completedSteps ?? this.completedSteps,
    turns: turns ?? this.turns,
    toolCalls: toolCalls ?? this.toolCalls,
    error: error ?? this.error,
  );
}

/// The latest outcome of a durable Daily OS agent job attempt — the part of
/// the wait the wake itself cannot see: a failed attempt re-queued with
/// backoff, or one that gave up.
@immutable
class DayAgentJobAttempt {
  const DayAgentJobAttempt({
    required this.dayId,
    required this.attempts,
    required this.maxAttempts,
    required this.updatedAt,
    required this.willRetry,
    this.nextAttemptAt,
    this.lastError,
  });

  final String dayId;

  /// Attempts counted so far (attempts that spent inference).
  final int attempts;
  final int maxAttempts;
  final DateTime updatedAt;

  /// Whether the job is queued for another attempt rather than settled.
  final bool willRetry;
  final DateTime? nextAttemptAt;
  final String? lastError;
}

/// What the drafting screen knows about one day's agent work right now.
@immutable
class DayAgentLiveStatus {
  const DayAgentLiveStatus({this.wake, this.lastAttempt});

  /// The newest wake for the day, running or finished.
  final DayAgentWakeProgress? wake;

  /// The newest durable-job outcome for the day.
  final DayAgentJobAttempt? lastAttempt;
}

/// In-memory fan-out of day-agent wake progress and job outcomes, keyed by
/// day id.
///
/// Written by the day-agent workflow (through `DayAgentWakeTrace`) and the
/// processing outbox's outcome hook; read by the drafting screen. Nothing is
/// persisted or synced — this is live telemetry for the device running the
/// wake.
class DayAgentWakeProgressBus {
  final _wakes = <String, DayAgentWakeProgress>{};
  final _attempts = <String, DayAgentJobAttempt>{};
  final _changes = StreamController<String>.broadcast();

  /// The current status for [dayId].
  DayAgentLiveStatus statusFor(String dayId) => DayAgentLiveStatus(
    wake: _wakes[dayId],
    lastAttempt: _attempts[dayId],
  );

  /// The current status for [dayId], then every change to it.
  Stream<DayAgentLiveStatus> watch(String dayId) async* {
    yield statusFor(dayId);
    yield* _changes.stream
        .where((changed) => changed == dayId)
        .map((_) => statusFor(dayId));
  }

  void publishWake(DayAgentWakeProgress progress) {
    _wakes[progress.dayId] = progress;
    _emit(progress.dayId);
  }

  void publishAttempt(DayAgentJobAttempt attempt) {
    _attempts[attempt.dayId] = attempt;
    _emit(attempt.dayId);
  }

  void _emit(String dayId) {
    if (!_changes.isClosed) _changes.add(dayId);
  }

  Future<void> dispose() => _changes.close();
}
