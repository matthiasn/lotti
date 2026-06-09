import 'package:glados/glados.dart' as glados;

enum GeneratedAgentResolutionOutcome {
  noAgent,
  noTemplate,
  noActiveVersion,
  unresolvedProfile,
  resolvedProfile,
}

enum GeneratedTaskProfileOutcome {
  noProfileId,
  unresolvedProfile,
  resolvedProfile,
}

class GeneratedAutomationResolutionScenario {
  const GeneratedAutomationResolutionScenario({
    required this.agentOutcome,
    required this.taskOutcome,
  });

  final GeneratedAgentResolutionOutcome agentOutcome;
  final GeneratedTaskProfileOutcome taskOutcome;

  bool get reachesTemplate =>
      agentOutcome != GeneratedAgentResolutionOutcome.noAgent;

  bool get reachesVersion =>
      reachesTemplate &&
      agentOutcome != GeneratedAgentResolutionOutcome.noTemplate;

  bool get reachesAgentProfileResolution =>
      reachesVersion &&
      agentOutcome != GeneratedAgentResolutionOutcome.noActiveVersion;

  bool get resolvesViaAgent =>
      agentOutcome == GeneratedAgentResolutionOutcome.resolvedProfile;

  bool get fallsBackToTask => !resolvesViaAgent;

  bool get hasTaskProfileId =>
      taskOutcome != GeneratedTaskProfileOutcome.noProfileId;

  bool get resolvesViaTask =>
      fallsBackToTask &&
      taskOutcome == GeneratedTaskProfileOutcome.resolvedProfile;

  @override
  String toString() {
    return 'GeneratedAutomationResolutionScenario('
        'agentOutcome: $agentOutcome, taskOutcome: $taskOutcome)';
  }
}

extension AnyGeneratedAutomationResolutionScenario on glados.Any {
  glados.Generator<GeneratedAgentResolutionOutcome>
  get agentResolutionOutcome =>
      glados.AnyUtils(this).choose(GeneratedAgentResolutionOutcome.values);

  glados.Generator<GeneratedTaskProfileOutcome> get taskProfileOutcome =>
      glados.AnyUtils(this).choose(GeneratedTaskProfileOutcome.values);

  glados.Generator<GeneratedAutomationResolutionScenario>
  get automationResolutionScenario => glados.CombinableAny(this).combine2(
    agentResolutionOutcome,
    taskProfileOutcome,
    (
      GeneratedAgentResolutionOutcome agentOutcome,
      GeneratedTaskProfileOutcome taskOutcome,
    ) => GeneratedAutomationResolutionScenario(
      agentOutcome: agentOutcome,
      taskOutcome: taskOutcome,
    ),
  );
}
