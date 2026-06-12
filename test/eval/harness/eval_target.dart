// The execution seam for the evaluation harness (ADR 0029).
//
// An `EvalTarget` turns a scenario + profile into an `AgentRunOutput`. The same
// scenario is graded by every target so Level 1 (scripted) and Level 2 (live)
// can never drift apart.
//
// Phase 0 shipped `FixtureEvalTarget` (returns a pre-baked output) so the example
// test can exercise the full scenario -> output -> assertions -> trace pipeline
// with no live dependencies. The real targets are:
//
//   ScriptedEvalTarget (Phase 1)
//     Seeds the agent/journal DB from the scenario using the existing factories
//     (CaptureEntity / ParsedItemEntity / DayPlanEntity / makeTestState /
//     journal Task inserts),
//     seeds production-style AiConfig profile/model/provider rows from
//     EvalProfile,
//     runs the real `*.execute(...)` with a `ConversationRepository` subclass
//     whose tool calls are scripted (generalising `_ConversationHarness`), and
//     maps the persisted entities (DayPlanEntity.plannedBlocks, ChangeSetEntity,
//     AgentReportEntity, observations, WakeTokenUsageEntity) plus resolved
//     model provenance into AgentRunOutput. Deterministic, free, CI-safe.
//
//   LiveEvalTarget (Phase 2)
//     Identical seeding, but the workflow's ConversationRepository is the real
//     one wired to a provider resolved by `resolveInferenceProvider` for
//     `profile.modelId` (Ollama when `profile.isLocal`, frontier otherwise).
//     Token usage is the real `InferenceUsage` returned from `sendMessage`.
//     Gated behind LOTTI_EVAL_LIVE=1 + credentials.

import 'eval_models.dart';
import 'eval_profile_config.dart';

/// Identifies one concrete scenario/profile/prompt-variant/trial cell.
///
/// Direct unit calls use [direct]; matrix runs always pass the real run
/// context so targets can choose distinct run keys, thread IDs, caches, or
/// random seeds per trial.
class EvalTargetRunContext {
  const EvalTargetRunContext({
    required this.runId,
    required this.scenarioId,
    required this.profileName,
    this.agentDirectiveVariant = const EvalAgentDirectiveVariant(),
    required this.trialIndex,
  });

  static const direct = EvalTargetRunContext(
    runId: 'direct',
    scenarioId: 'direct',
    profileName: 'direct',
    agentDirectiveVariant: EvalAgentDirectiveVariant(),
    trialIndex: 0,
  );

  final String runId;
  final String scenarioId;
  final String profileName;
  final EvalAgentDirectiveVariant agentDirectiveVariant;
  final int trialIndex;

  String get cellId {
    final variantSegment = agentDirectiveVariant.isDefault
        ? ''
        : '::${agentDirectiveVariant.name}';
    return '$runId::$scenarioId::$profileName$variantSegment::$trialIndex';
  }
}

/// Runs one scenario under one profile and returns the normalised output.
abstract class EvalTarget {
  String get profileName;

  String get targetKind => runtimeType.toString();

  List<EvalProfileExecutionBinding> profileExecutionBindings(
    List<EvalProfile> profiles,
  ) => [
    for (final profile in profiles)
      evalProfileConfig(profile).toExecutionBinding(),
  ];

  Future<AgentRunOutput> run(
    EvalScenario scenario,
    EvalProfile profile, {
    EvalTargetRunContext context = EvalTargetRunContext.direct,
  });
}

List<EvalProfileExecutionBinding> profileExecutionBindingsForTarget(
  EvalTarget target,
  List<EvalProfile> profiles,
) => target.profileExecutionBindings(profiles);

/// Returns a pre-baked output per scenario id. Used by the example test and as
/// a stand-in until `ScriptedEvalTarget` lands.
class FixtureEvalTarget extends EvalTarget {
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
  String get targetKind => 'fixture';

  @override
  Future<AgentRunOutput> run(
    EvalScenario scenario,
    EvalProfile profile, {
    EvalTargetRunContext context = EvalTargetRunContext.direct,
  }) async {
    final output = _outputs[scenario.id];
    if (output == null) {
      throw StateError('No fixture output registered for "${scenario.id}"');
    }
    return output;
  }
}
