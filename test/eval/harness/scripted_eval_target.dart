// Scripted real-workflow implementation of the evaluation target seam.
//
// This file intentionally stays out of `eval_harness.dart`: it imports the
// real workflow benches, and those benches depend on the centralized test mocks.

import 'eval_models.dart';
import 'eval_target.dart';
import 'planner_eval_bench.dart';
import 'scripted_agent_behavior.dart';
import 'task_agent_eval_bench.dart';

/// Runs an eval scenario through the real workflow benches with scripted model
/// behaviour.
class ScriptedEvalTarget extends EvalTarget {
  /// Creates a target that resolves scripted model behaviour per scenario.
  ScriptedEvalTarget(this.behaviorFor, {this.profileName = 'scripted'});

  /// Creates a target backed by a side map keyed by `EvalScenario.id`.
  ///
  /// Keeping the scripted behaviour outside `EvalScenario` preserves the plain
  /// JSON scenario model and avoids pulling bench/mock dependencies into the
  /// pure harness barrel.
  factory ScriptedEvalTarget.fromMap(
    Map<String, ScriptedAgentBehavior> behaviors, {
    String profileName = 'scripted',
  }) {
    final scriptedBehaviors = Map<String, ScriptedAgentBehavior>.unmodifiable(
      behaviors,
    );
    return ScriptedEvalTarget(
      (scenario, _) {
        final behavior = scriptedBehaviors[scenario.id];
        if (behavior == null) {
          throw StateError(
            'No scripted behavior registered for "${scenario.id}"',
          );
        }
        return behavior;
      },
      profileName: profileName,
    );
  }

  /// Creates a target backed by a side map keyed by scenario id, then profile
  /// name. Use this when local/frontier scripted baselines intentionally differ.
  factory ScriptedEvalTarget.fromProfileMap(
    Map<String, Map<String, ScriptedAgentBehavior>> behaviors, {
    String profileName = 'scripted',
  }) {
    final scriptedBehaviors =
        Map<String, Map<String, ScriptedAgentBehavior>>.unmodifiable(
          behaviors.map(
            (scenarioId, byProfile) => MapEntry(
              scenarioId,
              Map<String, ScriptedAgentBehavior>.unmodifiable(byProfile),
            ),
          ),
        );
    return ScriptedEvalTarget(
      (scenario, profile) {
        final behavior = scriptedBehaviors[scenario.id]?[profile.name];
        if (behavior == null) {
          throw StateError(
            'No scripted behavior registered for "${scenario.id}" '
            'under profile "${profile.name}"',
          );
        }
        return behavior;
      },
      profileName: profileName,
    );
  }

  /// Resolves the scripted model behaviour for a scenario.
  final ScriptedAgentBehavior Function(
    EvalScenario scenario,
    EvalProfile profile,
  )
  behaviorFor;

  @override
  final String profileName;

  @override
  String get targetKind => 'scripted';

  @override
  Future<AgentRunOutput> run(
    EvalScenario scenario,
    EvalProfile profile, {
    EvalTargetRunContext context = EvalTargetRunContext.direct,
  }) async {
    final behavior = behaviorFor(scenario, profile);
    return switch (scenario.agentKind) {
      AgentKind.planningAgent => PlannerEvalBench.runWake(
        scenario,
        profile,
        behavior,
        context: context,
      ),
      AgentKind.taskAgent => TaskAgentEvalBench.runWake(
        scenario,
        profile,
        behavior,
        context: context,
      ),
    };
  }
}
