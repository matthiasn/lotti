part of '../ai_summary_card.dart';

/// Compact taxonomy of proposal kinds used by the AI card. Drives the
/// chip color/label, the activity-row icon, and the activity-row color.
/// Kept private to the `ai_summary_card` library — no other widget in
/// the app should reach into these.
enum _ProposalKind {
  add,
  update,
  remove,
  priority,
  estimate,
  status,
  label,
  due,
}

class _KindMeta {
  const _KindMeta({
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
_ProposalKind _resolveKind(String toolName, Map<String, dynamic> args) {
  switch (toolName) {
    case TaskAgentToolNames.addMultipleChecklistItems:
    case TaskAgentToolNames.addChecklistItem:
    case TaskAgentToolNames.createFollowUpTask:
    case TaskAgentToolNames.createTimeEntry:
    case TaskAgentToolNames.migrateChecklistItems:
    case TaskAgentToolNames.migrateChecklistItem:
      return _ProposalKind.add;
    case TaskAgentToolNames.updateChecklistItems:
    case TaskAgentToolNames.updateChecklistItem:
    case TaskAgentToolNames.updateTimeEntry:
    case TaskAgentToolNames.updateRunningTimer:
    case TaskAgentToolNames.setTaskTitle:
      return _ProposalKind.update;
    case TaskAgentToolNames.updateTaskPriority:
      return _ProposalKind.priority;
    case TaskAgentToolNames.updateTaskEstimate:
      return _ProposalKind.estimate;
    case TaskAgentToolNames.setTaskStatus:
      return _ProposalKind.status;
    case TaskAgentToolNames.assignTaskLabels:
    case TaskAgentToolNames.assignTaskLabel:
      return _ProposalKind.label;
    case TaskAgentToolNames.updateTaskDueDate:
      return _ProposalKind.due;
    default:
      return _ProposalKind.update;
  }
}

/// Resolves a [_KindMeta] for the given [kind], pulling colors from the
/// design-system tokens and labels from `context.messages`.
_KindMeta _kindMeta(BuildContext context, _ProposalKind kind) {
  final palette = context.designTokens.colors.proposalKind;
  final messages = context.messages;
  switch (kind) {
    case _ProposalKind.add:
      return _KindMeta(
        color: palette.add.color,
        surface: palette.add.surface,
        label: messages.aiCardProposalKindAdd,
      );
    case _ProposalKind.update:
      return _KindMeta(
        color: palette.update.color,
        surface: palette.update.surface,
        label: messages.aiCardProposalKindUpdate,
      );
    case _ProposalKind.remove:
      return _KindMeta(
        color: palette.remove.color,
        surface: palette.remove.surface,
        label: messages.aiCardProposalKindRemove,
      );
    case _ProposalKind.priority:
      return _KindMeta(
        color: palette.priority.color,
        surface: palette.priority.surface,
        label: messages.aiCardProposalKindPriority,
      );
    case _ProposalKind.estimate:
      return _KindMeta(
        color: palette.estimate.color,
        surface: palette.estimate.surface,
        label: messages.aiCardProposalKindEstimate,
      );
    case _ProposalKind.status:
      return _KindMeta(
        color: palette.status.color,
        surface: palette.status.surface,
        label: messages.aiCardProposalKindStatus,
      );
    case _ProposalKind.label:
      return _KindMeta(
        color: palette.label.color,
        surface: palette.label.surface,
        label: messages.aiCardProposalKindLabel,
      );
    case _ProposalKind.due:
      return _KindMeta(
        color: palette.due.color,
        surface: palette.due.surface,
        label: messages.aiCardProposalKindDue,
      );
  }
}
