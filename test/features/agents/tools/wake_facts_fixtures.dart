import 'package:lotti/features/agents/tools/task_agent_tool_gate.dart';

/// A wake with nothing to act on: every fact a tool can be gated on is
/// absent. A tool with no precondition must still be offered here.
const nothingAvailableFacts = TaskAgentWakeFacts(
  hasChecklistItems: false,
  hasTimeRecords: false,
  hasLabelDefinitions: false,
  hasOpenProposals: false,
  hasActiveAttentionClaims: false,
  hasNewerContentThanReport: false,
  hasCategoryProjects: false,
  hasPullRequestRepository: false,
  hasLinkedPullRequests: false,
  hasRelatedTaskSearch: false,
);
