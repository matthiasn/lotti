// The execution seam for the evaluation harness (ADR 0026).
//
// An `EvalTarget` turns a scenario + profile into an `AgentRunOutput`. The same
// scenario is graded by every target so Level 1 (scripted) and Level 2 (live)
// can never drift apart.
//
// Phase 0 ships `FixtureEvalTarget` (returns a pre-baked output) so the example
// test can exercise the full scenario -> output -> assertions -> trace pipeline
// with no live dependencies. The two real targets land later:
//
//   ScriptedEvalTarget (Phase 1)
//     Seeds the agent/journal DB from the scenario using the existing factories
//     (makeTestCapture / makeTestDayPlan / makeTestState / journal Task inserts),
//     runs the real `*.execute(...)` with a `ConversationRepository` subclass
//     whose tool calls are scripted (generalising `_ConversationHarness`), and
//     maps the persisted entities (DayPlanEntity.plannedBlocks, ChangeSetEntity,
//     AgentReportEntity, observations, WakeTokenUsageEntity) into AgentRunOutput.
//     Deterministic, free, CI-safe.
//
//   LiveEvalTarget (Phase 2)
//     Identical seeding, but the workflow's ConversationRepository is the real
//     one wired to a provider resolved by `resolveInferenceProvider` for
//     `profile.modelId` (Ollama when `profile.isLocal`, frontier otherwise).
//     Token usage is the real `InferenceUsage` returned from `sendMessage`.
//     Gated behind LOTTI_EVAL_LIVE=1 + credentials.

import 'eval_models.dart';

/// Runs one scenario under one profile and returns the normalised output.
abstract class EvalTarget {
  String get profileName;

  Future<AgentRunOutput> run(EvalScenario scenario, EvalProfile profile);
}

/// Returns a pre-baked output per scenario id. Used by the example test and as
/// a stand-in until `ScriptedEvalTarget` lands.
class FixtureEvalTarget implements EvalTarget {
  FixtureEvalTarget(this._outputs, {this.profileName = 'fixture'});

  /// Convenience for a single scenario.
  factory FixtureEvalTarget.single(
    String scenarioId,
    AgentRunOutput output, {
    String profileName = 'fixture',
  }) => FixtureEvalTarget(
    <String, AgentRunOutput>{scenarioId: output},
    profileName: profileName,
  );

  final Map<String, AgentRunOutput> _outputs;

  @override
  final String profileName;

  @override
  Future<AgentRunOutput> run(EvalScenario scenario, EvalProfile profile) async {
    final output = _outputs[scenario.id];
    if (output == null) {
      throw StateError('No fixture output registered for "${scenario.id}"');
    }
    return output;
  }
}
