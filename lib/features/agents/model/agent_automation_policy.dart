import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

/// Pure wake-permission policy for task agents.
///
/// Automatic updates are subscription-triggered, 120-second-coalesced wakes.
/// Manual and other explicit wake reasons remain available while automation is
/// off, but an explicitly disabled inference setup blocks every inference path.
bool taskAgentWakeAllowed({
  required AgentConfig config,
  required AgentLifecycle lifecycle,
  required WakeInitiator initiator,
}) {
  if (lifecycle == AgentLifecycle.destroyed ||
      lifecycle == AgentLifecycle.created ||
      config.inferenceSetup?.mode == AgentInferenceSetupMode.disabled) {
    return false;
  }
  if (initiator == WakeInitiator.user) return true;
  return config.automaticUpdatesEnabledEffective &&
      lifecycle == AgentLifecycle.active;
}

/// Whether a project agent may schedule subscription or fallback wakes.
///
/// Automatic inference is opt-in: a missing preference reads as off, exactly
/// as the "Automatic updates" switch renders it
/// ([AgentConfigAutomation.automaticUpdatesEnabledEffective]). Project agents
/// once treated a missing value as on, so every agent that was never toggled
/// showed the switch off while still waking on its own — the runaway-wake
/// incident of 2026-10. Inactive lifecycle or disabled inference also block
/// automatic work; user-requested wakes are handled separately.
bool projectAgentAutomaticWakesAllowed({
  required AgentConfig config,
  required AgentLifecycle lifecycle,
}) => projectAgentWakeAllowed(
  config: config,
  lifecycle: lifecycle,
  initiator: WakeInitiator.automation,
);

/// Whether a queued project-agent wake still satisfies the current policy.
///
/// User-requested work bypasses the automatic-updates preference, but neither
/// user nor automation work may run for an inactive agent or disabled setup.
bool projectAgentWakeAllowed({
  required AgentConfig config,
  required AgentLifecycle lifecycle,
  required WakeInitiator initiator,
}) {
  if (lifecycle != AgentLifecycle.active ||
      config.inferenceSetup?.mode == AgentInferenceSetupMode.disabled) {
    return false;
  }
  return initiator == WakeInitiator.user ||
      config.automaticUpdatesEnabledEffective;
}
