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
  static const assignTaskLabels = 'assign_task_labels';
  static const setTaskLanguage = 'set_task_language';
  static const setTaskStatus = 'set_task_status';

  // Legacy single-item aliases (dispatched to batch handlers).
  static const addChecklistItem = 'add_checklist_item';
  static const updateChecklistItem = 'update_checklist_item';
}

/// Tool name constants used by the evolution agent.
abstract final class EvolutionToolNames {
  static const proposeDirectives = 'propose_directives';
  static const recordEvolutionNote = 'record_evolution_note';
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
  };

  /// Batch tools that should be exploded into individual change item entries.
  ///
  /// Each entry maps a tool name to the JSON key that contains the array of
  /// items. The builder splits the array so each element becomes a separate
  /// confirmable change item.
  static const explodedBatchTools = <String, String>{
    TaskAgentToolNames.addMultipleChecklistItems: 'items',
    TaskAgentToolNames.updateChecklistItems: 'items',
  };

  /// All tools available to the Task Agent.
  static const taskAgentTools = <AgentToolDefinition>[
    AgentToolDefinition(
      name: TaskAgentToolNames.setTaskTitle,
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
      name: TaskAgentToolNames.updateTaskEstimate,
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
      name: TaskAgentToolNames.updateTaskDueDate,
      description: 'Update the due date for the task. '
          'Only call when you want to CHANGE the due date to a different value. '
          'Do NOT call if the task already has the correct due date — check the '
          'current dueDate in the task context first.',
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
      name: TaskAgentToolNames.updateTaskPriority,
      description: 'Update the priority of the task. '
          'Only call when you want to CHANGE the priority to a different value. '
          'Do NOT call if the task already has the correct priority — check the '
          'current priority in the task context first.',
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
      name: TaskAgentToolNames.addMultipleChecklistItems,
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
      name: TaskAgentToolNames.updateChecklistItems,
      description:
          'Update existing checklist items. Each item needs its id and at '
          'least one of isChecked or title. When an item was last toggled by '
          'the user, you must provide a reason citing evidence from AFTER the '
          "user's action to change its checked state. Title updates are "
          'always allowed.',
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
                  'description':
                      'Whether the item is checked. For items last set by '
                          'the user, you must also provide a reason citing '
                          'post-dated evidence.',
                },
                'title': {
                  'type': 'string',
                  'description':
                      'New title for the item (e.g. fix a transcription '
                          'error). Max 400 characters.',
                },
                'reason': {
                  'type': 'string',
                  'description':
                      'Required when changing isChecked on a user-set item. '
                          'Must cite specific evidence (e.g. a recording or '
                          "note) that postdates the user's last toggle.",
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
      name: TaskAgentToolNames.updateReport,
      description:
          'Publish the updated task report. You MUST call this tool exactly '
          'once at the end of every wake. Provide both a short TLDR summary '
          'and the full report content as markdown. Follow the report '
          'structure defined in your report directive. Write in the task '
          'content language. Express your personality and voice from your '
          'directives.',
      parameters: {
        'type': 'object',
        'properties': {
          'tldr': {
            'type': 'string',
            'description': 'A concise 1-3 sentence overview of the task '
                'state. This is shown in the collapsed view. Be punchy and '
                'include 1-2 relevant emojis.',
          },
          'content': {
            'type': 'string',
            'description': 'The full updated report as a markdown document.',
          },
          // Keep legacy parameter name for backwards compatibility with
          // older template versions that still reference `markdown`.
          'markdown': {
            'type': 'string',
            'description': 'Deprecated — use "content" instead. If both are '
                'provided, "content" takes precedence.',
          },
        },
        'required': ['tldr'],
        'additionalProperties': false,
      },
    ),
    AgentToolDefinition(
      name: TaskAgentToolNames.recordObservations,
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
    AgentToolDefinition(
      name: TaskAgentToolNames.assignTaskLabels,
      description: 'Add one or more labels to the task. Only use labels from '
          'the available labels list provided in the context. Do not propose '
          'labels listed as suppressed. Cap to 3 labels per call. If the task '
          'already has 3 or more labels, do not call this tool.',
      parameters: {
        'type': 'object',
        'properties': {
          'labels': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'id': {
                  'type': 'string',
                  'description': 'The label ID (from available labels list).',
                },
                'confidence': {
                  'type': 'string',
                  'enum': ['very_high', 'high', 'medium', 'low'],
                  'description':
                      'Confidence level. Omit low confidence labels.',
                },
              },
              'required': ['id', 'confidence'],
              'additionalProperties': false,
            },
            'maxItems': 3,
            'description': 'Labels to assign, highest confidence first.',
          },
        },
        'required': ['labels'],
        'additionalProperties': false,
      },
    ),
    AgentToolDefinition(
      name: TaskAgentToolNames.setTaskLanguage,
      description: 'Set the detected language for the task. '
          'Only set when the task has no language yet (languageCode is null). '
          'Detect based on the task content (title, transcripts, notes).',
      parameters: {
        'type': 'object',
        'properties': {
          'languageCode': {
            'type': 'string',
            'description': 'ISO 639-1 language code (e.g., "en", "de", "fr").',
          },
          'confidence': {
            'type': 'string',
            'enum': ['high', 'medium', 'low'],
            'description': 'Confidence level of language detection.',
          },
        },
        'required': ['languageCode', 'confidence'],
        'additionalProperties': false,
      },
    ),
    AgentToolDefinition(
      name: TaskAgentToolNames.setTaskStatus,
      description: 'Transition the task to a new status. '
          'Only call when you want to CHANGE the status to a DIFFERENT value. '
          'Do NOT call if the task is already at the target status — check the '
          'current status in the task context first. '
          'Valid statuses: OPEN, IN PROGRESS, GROOMED, BLOCKED, ON HOLD. '
          'BLOCKED and ON HOLD require a reason. '
          'DONE and REJECTED are user-only and cannot be set by the agent. '
          'Only change status when there is clear evidence in the task context.',
      parameters: {
        'type': 'object',
        'properties': {
          'status': {
            'type': 'string',
            'enum': ['OPEN', 'IN PROGRESS', 'GROOMED', 'BLOCKED', 'ON HOLD'],
            'description': 'The target task status.',
          },
          'reason': {
            'type': 'string',
            'description': 'Required for BLOCKED and ON HOLD. '
                'Explanation of why the task is blocked or on hold.',
          },
        },
        'required': ['status'],
        'additionalProperties': false,
      },
    ),
  ];

  /// Tools available to the evolution agent during 1-on-1 sessions.
  static const evolutionAgentTools = <AgentToolDefinition>[
    AgentToolDefinition(
      name: EvolutionToolNames.proposeDirectives,
      description: 'Formally propose a new version of the template directives. '
          'Provide COMPLETE rewritten text for both the general directive '
          '(persona, tools, objectives) and the report directive (report '
          'structure, formatting). Include a brief rationale explaining what '
          'changed and why.',
      parameters: {
        'type': 'object',
        'properties': {
          'general_directive': {
            'type': 'string',
            'description':
                'The complete proposed general directive text (persona, '
                    'tools, objectives).',
          },
          'report_directive': {
            'type': 'string',
            'description':
                'The complete proposed report directive text (report '
                    'structure, formatting rules).',
          },
          'rationale': {
            'type': 'string',
            'description':
                'Brief explanation of what changed and why (1-3 sentences).',
          },
        },
        'required': ['general_directive', 'report_directive', 'rationale'],
        'additionalProperties': false,
      },
    ),
    AgentToolDefinition(
      name: EvolutionToolNames.recordEvolutionNote,
      description:
          'Record a private evolution note for your own future reference. '
          'Use this to capture patterns, hypotheses, decisions, or recurring '
          'themes that will help in future sessions.',
      parameters: {
        'type': 'object',
        'properties': {
          'kind': {
            'type': 'string',
            'enum': ['reflection', 'hypothesis', 'decision', 'pattern'],
            'description':
                'The kind of note: reflection (observation about performance), '
                    'hypothesis (what might improve the template), decision (a '
                    'choice made during the session), pattern (a recurring theme).',
          },
          'content': {
            'type': 'string',
            'description': 'The note content (markdown text).',
          },
        },
        'required': ['kind', 'content'],
        'additionalProperties': false,
      },
    ),
  ];
}
