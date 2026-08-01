import 'package:flutter/material.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Compact taxonomy of proposal kinds used by the AI card. Drives the
/// chip color/label, the activity-row icon, and the activity-row color.
/// Internal to the `ai_summary_card` library — exposed via the card's
/// barrel so its sibling row widgets can share one source of truth.
enum ProposalKind {
  add,
  update,
  remove,
  priority,
  estimate,
  status,
  label,
  due,
}

class KindMeta {
  const KindMeta({required this.label});

  final String label;
}

/// Resolves the proposal kind from a tool name. Tool names ending up in
/// the agent's change-set ledger come from
/// [`TaskAgentToolNames`](../tools/agent_tool_registry.dart); this maps
/// each one onto the closest visual kind.
ProposalKind resolveKind(String toolName, Map<String, dynamic> args) {
  switch (toolName) {
    case TaskAgentToolNames.addMultipleChecklistItems:
    case TaskAgentToolNames.addChecklistItem:
    case TaskAgentToolNames.createFollowUpTask:
    case TaskAgentToolNames.createTimeEntry:
    case TaskAgentToolNames.migrateChecklistItems:
    case TaskAgentToolNames.migrateChecklistItem:
    case TaskAgentToolNames.linkTask:
      return ProposalKind.add;
    case TaskAgentToolNames.updateChecklistItems:
    case TaskAgentToolNames.updateChecklistItem:
    case TaskAgentToolNames.updateTimeEntry:
    case TaskAgentToolNames.updateRunningTimer:
    case TaskAgentToolNames.setTaskTitle:
      return ProposalKind.update;
    case TaskAgentToolNames.updateTaskPriority:
      return ProposalKind.priority;
    case TaskAgentToolNames.updateTaskEstimate:
      return ProposalKind.estimate;
    case TaskAgentToolNames.setTaskStatus:
      return ProposalKind.status;
    case TaskAgentToolNames.assignTaskLabels:
    case TaskAgentToolNames.assignTaskLabel:
      return ProposalKind.label;
    case TaskAgentToolNames.updateTaskDueDate:
      return ProposalKind.due;
    case TaskAgentToolNames.retractSuggestions:
      return ProposalKind.remove;
    default:
      return ProposalKind.update;
  }
}

/// Resolves the localized taxonomy label for [kind].
KindMeta kindMeta(BuildContext context, ProposalKind kind) {
  final messages = context.messages;
  switch (kind) {
    case ProposalKind.add:
      return KindMeta(
        label: messages.aiCardProposalKindAdd,
      );
    case ProposalKind.update:
      return KindMeta(
        label: messages.aiCardProposalKindUpdate,
      );
    case ProposalKind.remove:
      return KindMeta(
        label: messages.aiCardProposalKindRemove,
      );
    case ProposalKind.priority:
      return KindMeta(
        label: messages.aiCardProposalKindPriority,
      );
    case ProposalKind.estimate:
      return KindMeta(
        label: messages.aiCardProposalKindEstimate,
      );
    case ProposalKind.status:
      return KindMeta(
        label: messages.aiCardProposalKindStatus,
      );
    case ProposalKind.label:
      return KindMeta(
        label: messages.aiCardProposalKindLabel,
      );
    case ProposalKind.due:
      return KindMeta(
        label: messages.aiCardProposalKindDue,
      );
  }
}
