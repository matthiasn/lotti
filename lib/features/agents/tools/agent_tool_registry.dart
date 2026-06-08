// Registry of tool names and definitions available to agents.

part 'evolution_tool_definitions.dart';
part 'task_agent_tool_definitions.dart';
part 'task_field_tool_definitions.dart';
part 'task_checklist_tool_definitions.dart';
part 'task_time_tool_definitions.dart';
part 'task_planning_tool_definitions.dart';

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
  /// All tools available to the Task Agent.
  static const List<AgentToolDefinition> taskAgentTools = _taskAgentTools;

  /// Tools available to the soul evolution agent during standalone soul
  /// 1-on-1 sessions. Excludes `propose_directives` since soul sessions
  /// cannot change template skills.
  static final List<AgentToolDefinition> soulEvolutionAgentTools =
      evolutionAgentTools
          .where((t) => t.name != EvolutionToolNames.proposeDirectives)
          .toList(growable: false);

  /// Tools available to the evolution agent during 1-on-1 sessions.
  static const List<AgentToolDefinition> evolutionAgentTools =
      _evolutionAgentTools;
}
