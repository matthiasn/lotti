import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

/// Facts about a wake that decide which tools can legitimately be called.
///
/// Each field answers one question the app can settle on its own, without
/// spending an inference turn asking the model what it intends to do.
class TaskAgentWakeFacts {
  /// Every fact defaults to permissive.
  ///
  /// Deliberate: a caller that has not been taught to compute a fact gets the
  /// tool, so adding a gate can never silently remove a capability from a wake
  /// that was not updated. A gate has to be asked for.
  const TaskAgentWakeFacts({
    this.hasChecklistItems = true,
    this.hasRunningTimerForTask = true,
    this.hasTimeRecords = true,
    this.hasLabelDefinitions = true,
    this.hasOpenProposals = true,
    this.hasActiveAttentionClaims = true,
    this.hasNewerContentThanReport = true,
  });

  /// Every fact permissive: the tool list is exactly today's.
  ///
  /// The migration default, so gating is opt-in and a caller that has not been
  /// taught the facts yet cannot silently lose a capability.
  static const permissive = TaskAgentWakeFacts();

  /// The task has at least one checklist item to update.
  final bool hasChecklistItems;

  /// A timer is running **and its source is this task**.
  ///
  /// Scoped deliberately. A timer belonging to another task is exposed to the
  /// prompt only as an opaque tracked range, so there is no id for the agent to
  /// update and offering the tool would invite it to invent one.
  final bool hasRunningTimerForTask;

  /// The task has time records, so an existing entry could be edited.
  final bool hasTimeRecords;

  /// Label definitions exist that could be assigned.
  final bool hasLabelDefinitions;

  /// The proposal ledger holds proposals still awaiting the user.
  final bool hasOpenProposals;

  /// This agent holds an active attention claim on the task.
  final bool hasActiveAttentionClaims;

  /// Something in the task or its linked entries is newer than the last report.
  ///
  /// A weak signal on purpose, and the reason `update_report` is *not* gated on
  /// "nothing worth reporting". A note that arrives saying nothing new is still
  /// newer than the report, and whether its content matters is a judgement the
  /// timestamps cannot make. This only withholds `update_report` when literally
  /// nothing has arrived since it was written.
  final bool hasNewerContentThanReport;
}

/// The tools a wake with these [facts] may be offered.
///
/// The default is to offer a tool; a gate removes one only when the fact that
/// makes it usable is absent. Two motivations, and the second matters more:
///
/// * **Payload.** Every wake currently advertises the full registry regardless
///   of relevance, and the lean-payload probe showed Qwen3.6 27B climbing from
///   10/14 to 13/14 purely as the prompt shrank.
/// * **Hallucination surface.** A tool that cannot succeed is an invitation to
///   invent its arguments. `update_running_timer` with no timer running has no
///   real id to pass, and `resolve_attention_request` with no claim has no real
///   claim to resolve — so the model supplies one.
///
/// Tools with no precondition — `set_task_title`, `update_task_estimate`,
/// `update_task_due_date`, `update_task_priority`, `set_task_status`,
/// `set_task_language`, `add_multiple_checklist_items`, `create_follow_up_task`,
/// `link_task`, `record_observations`, `request_attention` — are always offered.
/// `migrate_checklist_items` is deliberately among them: it is only meaningful
/// after `create_follow_up_task`, but that happens mid-wake and the tool list is
/// fixed for the turn.
Set<String> visibleTaskAgentToolNames(TaskAgentWakeFacts facts) {
  final hidden = <String>{
    if (!facts.hasChecklistItems) TaskAgentToolNames.updateChecklistItems,
    if (!facts.hasRunningTimerForTask) TaskAgentToolNames.updateRunningTimer,
    if (!facts.hasTimeRecords) TaskAgentToolNames.updateTimeEntry,
    if (!facts.hasLabelDefinitions) TaskAgentToolNames.assignTaskLabels,
    if (!facts.hasOpenProposals) TaskAgentToolNames.retractSuggestions,
    if (!facts.hasActiveAttentionClaims)
      TaskAgentToolNames.resolveAttentionRequest,
    if (!facts.hasNewerContentThanReport) TaskAgentToolNames.updateReport,
  };

  return {
    for (final definition in AgentToolRegistry.taskAgentTools)
      if (definition.enabled && !hidden.contains(definition.name))
        definition.name,
  };
}
