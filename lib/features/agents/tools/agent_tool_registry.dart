import 'dart:convert';

// Registry of tool names and definitions available to agents.

import 'package:lotti/features/agents/tools/evolution_tool_definitions.dart';
import 'package:lotti/features/agents/tools/task_agent_tool_definitions.dart';

export 'package:lotti/features/agents/tools/evolution_tool_definitions.dart';
export 'package:lotti/features/agents/tools/task_agent_tool_definitions.dart';
export 'package:lotti/features/agents/tools/task_checklist_tool_definitions.dart';
export 'package:lotti/features/agents/tools/task_field_tool_definitions.dart';
export 'package:lotti/features/agents/tools/task_link_tool_definitions.dart';
export 'package:lotti/features/agents/tools/task_planning_tool_definitions.dart';
export 'package:lotti/features/agents/tools/task_time_tool_definitions.dart';

/// Metadata describing a single tool that an agent can call.
///
/// Each definition includes the tool's name, a human-readable description, and
/// a JSON Schema object that describes the expected parameters.
class AgentToolDefinition {
  const AgentToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
    this.enabled = true,
  });

  /// The tool name used in function-call messages.
  final String name;

  /// Human-readable description of what the tool does.
  final String description;

  /// JSON Schema object describing the tool's parameters.
  final Map<String, dynamic> parameters;

  /// Whether this tool should be exposed to the LLM right now.
  final bool enabled;
}

/// Tool names models reach for that differ only in their verb prefix.
///
/// The registry mixes `set_task_*` (title, language, status) with
/// `update_task_*` (estimate, due date, priority), and a model that generalises
/// from one to the other invents a name that does not exist. DeepSeek V4 Flash
/// 0731 did this in both directions during the 2026-08-07 evaluation —
/// `set_task_estimate` and `update_task_status` — and did not recover when told
/// the tool was unknown, so the user's requested change was silently lost while
/// the report claimed it had been applied.
///
/// Accepting the near-miss costs nothing and turns a dropped mutation into a
/// correct one. Renaming the tools for consistency would be the deeper fix.
const Map<String, String> taskAgentToolAliases = {
  'set_task_estimate': TaskAgentToolNames.updateTaskEstimate,
  'set_task_due_date': TaskAgentToolNames.updateTaskDueDate,
  'set_task_priority': TaskAgentToolNames.updateTaskPriority,
  'update_task_status': TaskAgentToolNames.setTaskStatus,
  'update_task_title': TaskAgentToolNames.setTaskTitle,
  'update_task_language': TaskAgentToolNames.setTaskLanguage,
};

/// Resolves [toolName] through [taskAgentToolAliases], or returns it unchanged.
String resolveTaskAgentToolAlias(String toolName) =>
    taskAgentToolAliases[toolName] ?? toolName;

/// Decodes arguments a model sent as a JSON string instead of a structure.
///
/// Small models routinely double-encode collection arguments — Qwen3.6 35B A3B
/// sent `{"items": "[{\"id\": …, \"isChecked\": true}]"}` with entirely correct
/// contents, including `reason` fields citing the log evidence, and the handler
/// rejected it on `items is! List`. Correct work should not be discarded over
/// its encoding.
///
/// Only strings that parse to a list or map are converted; anything else is
/// passed through untouched so genuine string arguments keep their type.
Map<String, dynamic> decodeStringifiedJsonArguments(Map<String, dynamic> args) {
  Map<String, dynamic>? decoded;
  for (final entry in args.entries) {
    final value = entry.value;
    if (value is! String) continue;
    final trimmed = value.trim();
    if (!trimmed.startsWith('[') && !trimmed.startsWith('{')) continue;
    try {
      final parsed = jsonDecode(trimmed);
      if (parsed is List || parsed is Map) {
        (decoded ??= Map<String, dynamic>.of(args))[entry.key] = parsed;
      }
    } on FormatException {
      // Leave malformed JSON alone; the handler reports the type mismatch.
    }
  }
  return decoded ?? args;
}

/// Tool name constants used by the task agent.
///
/// Centralizes magic strings so that the tool registry, dispatcher, deferred
/// tool set, and change-set builder all reference the same values.
abstract final class TaskAgentToolNames {
  static const setTaskTitle = 'set_task_title';
  static const updateTaskEstimate = 'update_task_estimate';
  static const updateTaskDueDate = 'update_task_due_date';
  static const updateTaskPriority = 'update_task_priority';
  static const addMultipleChecklistItems = 'add_multiple_checklist_items';
  static const updateChecklistItems = 'update_checklist_items';
  static const updateReport = 'update_report';
  static const recordObservations = 'record_observations';
  static const retractSuggestions = 'retract_suggestions';
  static const assignTaskLabels = 'assign_task_labels';
  static const setTaskLanguage = 'set_task_language';
  static const setTaskStatus = 'set_task_status';
  static const getRelatedTaskDetails = 'get_related_task_details';
  static const requestAttention = 'request_attention';
  static const resolveAttentionRequest = 'resolve_attention_request';

  // Task splitting tools.
  static const createFollowUpTask = 'create_follow_up_task';
  static const migrateChecklistItems = 'migrate_checklist_items';
  static const migrateChecklistItem = 'migrate_checklist_item';

  // Task relationship tools.
  static const linkTask = 'link_task';

  // Time tracking tools.
  static const createTimeEntry = 'create_time_entry';
  static const updateTimeEntry = 'update_time_entry';
  static const updateRunningTimer = 'update_running_timer';

  // Legacy single-item aliases (dispatched to batch handlers).
  static const addChecklistItem = 'add_checklist_item';
  static const updateChecklistItem = 'update_checklist_item';
  static const assignTaskLabel = 'assign_task_label';
}

/// Tool name constants used by the evolution agent.
abstract final class EvolutionToolNames {
  static const proposeDirectives = 'propose_directives';
  static const proposeSoulDirectives = 'propose_soul_directives';
  static const recordEvolutionNote = 'record_evolution_note';
  static const publishRitualRecap = 'publish_ritual_recap';
}

/// Registry of tool definitions available to agents.
///
/// Each supported agent kind exposes a static list of [AgentToolDefinition]s
/// that can be serialised into the LLM's tool-call format at call time.
class AgentToolRegistry {
  AgentToolRegistry._();

  /// Tools whose mutations require user confirmation before being applied.
  ///
  /// When the strategy encounters one of these tools, it adds the proposed
  /// change to a `ChangeSetBuilder` instead of executing immediately.
  static const deferredTools = <String>{
    TaskAgentToolNames.assignTaskLabels,
    TaskAgentToolNames.setTaskTitle,
    TaskAgentToolNames.updateTaskEstimate,
    TaskAgentToolNames.updateTaskDueDate,
    TaskAgentToolNames.updateTaskPriority,
    TaskAgentToolNames.setTaskStatus,
    TaskAgentToolNames.addMultipleChecklistItems,
    TaskAgentToolNames.updateChecklistItems,
    TaskAgentToolNames.setTaskLanguage,
    TaskAgentToolNames.createFollowUpTask,
    TaskAgentToolNames.linkTask,
    TaskAgentToolNames.migrateChecklistItems,
    TaskAgentToolNames.createTimeEntry,
    TaskAgentToolNames.updateTimeEntry,
    TaskAgentToolNames.updateRunningTimer,
  };

  /// Batch tools that should be exploded into individual change item entries.
  ///
  /// Each entry maps a tool name to the JSON key that contains the array of
  /// items. The builder splits the array so each element becomes a separate
  /// confirmable change item.
  static const explodedBatchTools = <String, String>{
    TaskAgentToolNames.addMultipleChecklistItems: 'items',
    TaskAgentToolNames.updateChecklistItems: 'items',
    TaskAgentToolNames.assignTaskLabels: 'labels',
    TaskAgentToolNames.migrateChecklistItems: 'items',
  };

  /// All tools available to the Task Agent.
  static const List<AgentToolDefinition> taskAgentTools = taskAgentToolList;

  /// Tools available to the soul evolution agent during standalone soul
  /// 1-on-1 sessions. Excludes `propose_directives` since soul sessions
  /// cannot change template skills.
  static final List<AgentToolDefinition> soulEvolutionAgentTools =
      evolutionAgentTools
          .where((t) => t.name != EvolutionToolNames.proposeDirectives)
          .toList(growable: false);

  /// Tools available to the evolution agent during 1-on-1 sessions.
  static const List<AgentToolDefinition> evolutionAgentTools =
      evolutionAgentToolList;
}
