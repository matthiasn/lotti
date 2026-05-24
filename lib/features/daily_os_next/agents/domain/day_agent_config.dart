import 'package:lotti/features/agents/model/agent_config.dart';

/// Daily OS planning defaults layered on top of the shared [AgentConfig].
class DayAgentConfig {
  /// Creates a Daily OS day-agent configuration.
  const DayAgentConfig({
    this.capacityMinutes = 480,
    this.workingHoursStart = '09:00',
    this.workingHoursEnd = '17:00',
    this.energyBands = const ['morning', 'afternoon', 'evening'],
    this.maxRefinementRounds = 3,
    this.agentConfig = const AgentConfig(),
  });

  /// Target planning capacity for the day.
  final int capacityMinutes;

  /// Local working-hours lower bound in HH:mm form.
  final String workingHoursStart;

  /// Local working-hours upper bound in HH:mm form.
  final String workingHoursEnd;

  /// Energy bands the day agent should consider while drafting.
  final List<String> energyBands;

  /// Maximum voice-refinement rounds once refine tools are enabled.
  final int maxRefinementRounds;

  /// Shared inference/runtime configuration used by the agent infrastructure.
  final AgentConfig agentConfig;

  /// JSON-ready payload for prompts and diagnostics.
  Map<String, Object?> toJson() => {
    'capacityMinutes': capacityMinutes,
    'workingHoursStart': workingHoursStart,
    'workingHoursEnd': workingHoursEnd,
    'energyBands': energyBands,
    'maxRefinementRounds': maxRefinementRounds,
  };
}
