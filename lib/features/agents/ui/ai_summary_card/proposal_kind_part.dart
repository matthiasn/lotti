import 'package:flutter/material.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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
  const KindMeta({
    required this.color,
    required this.surface,
    required this.label,
  });

  final Color color;
  final Color surface;
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

/// Resolves a [KindMeta] for the given [kind], pulling colors from the
/// design-system tokens and labels from `context.messages`.
KindMeta kindMeta(BuildContext context, ProposalKind kind) {
  final palette = context.designTokens.colors.proposalKind;
  final messages = context.messages;
  switch (kind) {
    case ProposalKind.add:
      return KindMeta(
        color: palette.add.color,
        surface: palette.add.surface,
        label: messages.aiCardProposalKindAdd,
      );
    case ProposalKind.update:
      return KindMeta(
        color: palette.update.color,
        surface: palette.update.surface,
        label: messages.aiCardProposalKindUpdate,
      );
    case ProposalKind.remove:
      return KindMeta(
        color: palette.remove.color,
        surface: palette.remove.surface,
        label: messages.aiCardProposalKindRemove,
      );
    case ProposalKind.priority:
      return KindMeta(
        color: palette.priority.color,
        surface: palette.priority.surface,
        label: messages.aiCardProposalKindPriority,
      );
    case ProposalKind.estimate:
      return KindMeta(
        color: palette.estimate.color,
        surface: palette.estimate.surface,
        label: messages.aiCardProposalKindEstimate,
      );
    case ProposalKind.status:
      return KindMeta(
        color: palette.status.color,
        surface: palette.status.surface,
        label: messages.aiCardProposalKindStatus,
      );
    case ProposalKind.label:
      return KindMeta(
        color: palette.label.color,
        surface: palette.label.surface,
        label: messages.aiCardProposalKindLabel,
      );
    case ProposalKind.due:
      return KindMeta(
        color: palette.due.color,
        surface: palette.due.surface,
        label: messages.aiCardProposalKindDue,
      );
  }
}
