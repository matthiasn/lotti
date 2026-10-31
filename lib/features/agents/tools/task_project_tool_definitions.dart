import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

/// Tools for choosing the project the current task belongs to.
///
/// A task belongs to at most one project, and only to one in its own category.
/// The agent first reads that category's projects, then may propose one; the
/// proposal waits for the user like every other task change.
const taskProjectTools = <AgentToolDefinition>[
  AgentToolDefinition(
    name: TaskAgentToolNames.getCategoryProjects,
    description:
        "Read-only. List every project in the current task's category, each "
        'with its id, title, status, the one-liner and TLDR of its latest '
        'project report, and whether the task already belongs to it. Call '
        'this before set_task_project to review the options; it changes '
        'nothing.',
    parameters: {
      'type': 'object',
      'properties': <String, dynamic>{},
      'required': <String>[],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: TaskAgentToolNames.setTaskProject,
    description:
        'Propose moving the current task into a project of its category. The '
        'user must confirm it before anything changes. Only propose a project '
        'when the task clearly belongs to it — its one-liner or TLDR covers '
        "the task's work. Call get_category_projects first; never propose "
        'the project the task already belongs to, and never invent ids. '
        'May be called once per wake.',
    parameters: {
      'type': 'object',
      'properties': {
        'projectId': {
          'type': 'string',
          'description':
              'The id of the project, as returned by get_category_projects. '
              "The project's exact title is accepted too.",
        },
      },
      'required': ['projectId'],
      'additionalProperties': false,
    },
  ),
];
