part of 'agent_tool_registry.dart';

/// Backing list for [AgentToolRegistry.taskAgentTools].
///
/// The definitions are organised by concern into sibling part files and
/// concatenated here so the registry exposes a single flat list:
/// - [_taskFieldTools] — core task fields and metadata.
/// - [_taskChecklistTools] — checklist items and follow-up task splitting.
/// - [_taskTimeTools] — time entries and running timers.
/// - [_taskPlanningTools] — attention, reporting, and observations.
const _taskAgentTools = <AgentToolDefinition>[
  ..._taskFieldTools,
  ..._taskChecklistTools,
  ..._taskTimeTools,
  ..._taskPlanningTools,
];
