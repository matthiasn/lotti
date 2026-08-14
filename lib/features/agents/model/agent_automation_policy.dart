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
/// Project agents shipped with event-driven automation before the preference
/// was persisted, so a missing legacy value remains enabled. An explicit
/// opt-out, inactive lifecycle, or disabled inference blocks automatic work;
/// user-requested wakes are handled separately by the orchestrator.
bool projectAgentAutomaticWakesAllowed({
  required AgentConfig config,
  required AgentLifecycle lifecycle,
}) =>
    lifecycle == AgentLifecycle.active &&
    config.automaticUpdatesEnabled != false &&
    config.inferenceSetup?.mode != AgentInferenceSetupMode.disabled;
