import 'package:lotti/classes/agents/agent_constants.dart';

// The tokens and workspace keys of the front agent's chat turns.
//
// Here rather than in `features/front_agent` because the agent runtime's
// lease predicate names the recovery workspace, and the runtime ranks below
// the feature in the layer order (the `goal_trigger_tokens.dart` precedent).

const _frontChatMessageTokenPrefix = 'front-chat-message:';

/// How long the device a message was typed on has to route it before its
/// recovery record falls due and the lease elects one device to route it
/// instead (ADR 0069, the goal-chat rule: three run caps).
const frontChatRecoveryGrace = Duration(minutes: 30);

/// Prefix of the per-message chat-recovery workspaces.
const frontChatRecoveryWorkspacePrefix = 'front-chat';

/// The wake token that names the durable user turn a front wake routes.
String frontChatMessageTriggerToken(String messageId) =>
    '$_frontChatMessageTokenPrefix$messageId';

/// The message id a front-chat token carries, or null when [tokens] hold
/// none.
String? frontChatMessageIdFromTriggerTokens(Iterable<String> tokens) {
  for (final token in tokens) {
    if (token.startsWith(_frontChatMessageTokenPrefix)) {
      final id = token.substring(_frontChatMessageTokenPrefix.length);
      if (id.isNotEmpty) return id;
    }
  }
  return null;
}

/// Workspace key of the recovery wake for one user message (ADR 0069).
String frontChatRecoveryWorkspaceKey(String messageId) =>
    '$frontChatRecoveryWorkspacePrefix:$messageId';

/// Whether a scheduled-wake workspace is a front-chat recovery (the lease
/// predicate's test).
bool isFrontChatRecoveryWorkspace(String? workspaceKey) =>
    workspaceKey != null &&
    workspaceKey.startsWith('$frontChatRecoveryWorkspacePrefix:');

/// The id of [messageId]'s recovery record.
String frontChatRecoveryRecordId(String agentId, String messageId) =>
    scheduledWakeRecordId(
      agentId,
      workspaceKey: frontChatRecoveryWorkspaceKey(messageId),
    );
