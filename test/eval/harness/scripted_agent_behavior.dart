// Scripted model behaviour for deterministic eval runs.
//
// This is intentionally neutral: both task and planner benches consume it, and
// future live-like scripted tests can use multiple turns without depending on a
// specific agent bench.

import 'package:lotti/features/ai/model/inference_usage.dart';

import 'eval_models.dart';

/// One scripted model response turn.
class ScriptedAgentTurn {
  const ScriptedAgentTurn({
    this.toolCalls = const <ToolCallRecord>[],
    this.finalResponse,
    this.usage = InferenceUsage.empty,
  });

  final List<ToolCallRecord> toolCalls;
  final String? finalResponse;
  final InferenceUsage usage;
}

/// The fixed model behaviour a scripted run replays.
class ScriptedAgentBehavior {
  const ScriptedAgentBehavior({
    this.toolCalls = const <ToolCallRecord>[],
    this.finalResponse,
    this.usage = InferenceUsage.empty,
  }) : turns = const <ScriptedAgentTurn>[];

  const ScriptedAgentBehavior.turns(this.turns)
    : toolCalls = const <ToolCallRecord>[],
      finalResponse = null,
      usage = InferenceUsage.empty;

  /// Back-compat single-response fields used by the existing benches.
  final List<ToolCallRecord> toolCalls;
  final String? finalResponse;
  final InferenceUsage usage;

  /// Optional multi-turn script. When present, these turns are replayed in
  /// order by benches/repositories that support per-invocation behaviour.
  final List<ScriptedAgentTurn> turns;

  bool get isMultiTurn => turns.isNotEmpty;

  List<ToolCallRecord> get firstToolCalls =>
      isMultiTurn ? turns.first.toolCalls : toolCalls;

  String? get firstFinalResponse =>
      isMultiTurn ? turns.first.finalResponse : finalResponse;

  InferenceUsage get firstUsage => isMultiTurn ? turns.first.usage : usage;

  InferenceUsage get totalUsage {
    if (!isMultiTurn) return usage;
    return usageForTurns(turns.length);
  }

  List<ToolCallRecord> toolCallsForTurns(int executedTurns) {
    if (!isMultiTurn) return toolCalls;
    return [
      for (final turn in turns.take(executedTurns)) ...turn.toolCalls,
    ];
  }

  InferenceUsage usageForTurns(int executedTurns) {
    if (!isMultiTurn) return usage;
    return turns
        .take(executedTurns)
        .fold<InferenceUsage>(
          InferenceUsage.empty,
          (total, turn) => total.merge(turn.usage),
        );
  }
}
