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
