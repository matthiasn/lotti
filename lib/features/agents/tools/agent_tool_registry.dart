// Registry of tool names and definitions available to agents.

/// Metadata describing a single tool that an agent can call.
///
/// Each definition includes the tool's name, a human-readable description, and
/// a JSON Schema object that describes the expected parameters.
class AgentToolDefinition {
  const AgentToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  /// The tool name used in function-call messages.
  final String name;

  /// Human-readable description of what the tool does.
  final String description;

  /// JSON Schema object describing the tool's parameters.
  final Map<String, dynamic> parameters;
}

/// Registry of tool definitions available to agents.
///
/// Each supported agent kind exposes a static list of [AgentToolDefinition]s
/// that can be serialised into the LLM's tool-call format at call time.
class AgentToolRegistry {
  AgentToolRegistry._();

  /// All tools available to the Task Agent.
  static const taskAgentTools = <AgentToolDefinition>[
    AgentToolDefinition(
      name: 'set_task_title',
      description: 'Set the title of the task. Only use when the task has no '
          'title yet. Do not change an existing title unless the user '
          'explicitly asks for it.',
      parameters: {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': 'The new task title.',
          },
        },
        'required': ['title'],
        'additionalProperties': false,
      },
    ),
    AgentToolDefinition(
      name: 'update_task_estimate',
      description: 'Set the time estimate for completing the task. '
          'Only set or update the estimate when the user explicitly asks '
          'for it, or when no estimate exists and you have high confidence.',
      parameters: {
        'type': 'object',
        'properties': {
          'minutes': {
            'type': 'integer',
            'description': 'Estimated remaining work in minutes (1–1440). '
                'Examples: 30 for half an hour, 240 for 4 hours.',
          },
        },
        'required': ['minutes'],
        'additionalProperties': false,
      },
    ),
    AgentToolDefinition(
      name: 'update_task_due_date',
      description: 'Update the due date for the task.',
      parameters: {
        'type': 'object',
        'properties': {
          'dueDate': {
            'type': 'string',
            'description': 'Due date in YYYY-MM-DD format (e.g., 2024-06-30).',
          },
        },
        'required': ['dueDate'],
        'additionalProperties': false,
      },
    ),
    AgentToolDefinition(
      name: 'update_task_priority',
      description: 'Update the priority of the task.',
      parameters: {
        'type': 'object',
        'properties': {
          'priority': {
            'type': 'string',
            'description': 'Priority level (e.g., "P1", "P2").',
          },
        },
        'required': ['priority'],
        'additionalProperties': false,
      },
    ),
    AgentToolDefinition(
      name: 'add_multiple_checklist_items',
      description: 'Add multiple checklist items to the task.',
      parameters: {
        'type': 'object',
        'properties': {
          'items': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'title': {
                  'type': 'string',
                  'description': 'The checklist item text.',
                },
                'isChecked': {
                  'type': 'boolean',
                  'description': 'Whether the item starts checked. '
                      'Defaults to false.',
                },
              },
              'required': ['title'],
              'additionalProperties': false,
            },
            'description': 'List of checklist items to add.',
          },
        },
        'required': ['items'],
        'additionalProperties': false,
      },
    ),
    AgentToolDefinition(
      name: 'update_checklist_items',
      description:
          'Update existing checklist items. Each item needs its id and at '
          'least one of isChecked or title.',
      parameters: {
        'type': 'object',
        'properties': {
          'items': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'id': {
                  'type': 'string',
                  'description': 'The checklist item ID.',
                },
                'isChecked': {
                  'type': 'boolean',
                  'description': 'Whether the item is checked.',
                },
                'title': {
                  'type': 'string',
                  'description':
                      'New title for the item (e.g. fix a transcription '
                          'error). Max 400 characters.',
                },
              },
              'required': ['id'],
              'additionalProperties': false,
            },
            'description': 'List of checklist item updates.',
          },
        },
        'required': ['items'],
        'additionalProperties': false,
      },
    ),
    AgentToolDefinition(
      name: 'update_report',
      description:
          'Publish the updated task report. You MUST call this tool exactly '
          'once at the end of every wake with the full updated report as '
          'markdown.',
      parameters: {
        'type': 'object',
        'properties': {
          'markdown': {
            'type': 'string',
            'description': 'The full updated report as a markdown document.',
          },
        },
        'required': ['markdown'],
        'additionalProperties': false,
      },
    ),
    AgentToolDefinition(
      name: 'record_observations',
      description:
          'Record private observations for future wakes. Use this to note '
          'patterns, insights, failure notes, or anything worth remembering.',
      parameters: {
        'type': 'object',
        'properties': {
          'observations': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'List of observation strings to persist.',
          },
        },
        'required': ['observations'],
        'additionalProperties': false,
      },
    ),
  ];
}
