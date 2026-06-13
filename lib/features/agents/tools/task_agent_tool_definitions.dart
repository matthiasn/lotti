import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

/// Backing list for [AgentToolRegistry.taskAgentTools].
///
/// The definitions are organised by concern into sibling files and
/// concatenated here so the registry exposes a single flat list:
/// - [taskFieldTools] — core task fields and metadata.
/// - [taskChecklistTools] — checklist items and follow-up task splitting.
/// - [taskTimeTools] — time entries and running timers.
/// - [taskPlanningTools] — attention, reporting, and observations.
const taskAgentToolList = <AgentToolDefinition>[
  ...taskFieldTools,
  ...taskChecklistTools,
  ...taskTimeTools,
  ...taskPlanningTools,
];
