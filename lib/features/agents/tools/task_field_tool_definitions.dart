import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

/// Tools that edit core task fields and metadata: title, estimate, due date,
/// priority, status, language, and labels.
const taskFieldTools = <AgentToolDefinition>[
  AgentToolDefinition(
    name: TaskAgentToolNames.setTaskTitle,
    description:
        'Set the title of the task. When the task has no title yet the '
        'title is applied immediately without user confirmation when '
        'category policy permits it, so the task starts life with a '
        'meaningful name. If policy blocks that immediate write, or when '
        'an existing title is present, the change goes through the '
        'standard user confirmation flow; only call it then if the user '
        'has explicitly asked to rename.',
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
    description:
        'Set the time estimate for completing the task. '
        'Only set or update the estimate when the user explicitly asks '
        'for it, or when no estimate exists and you have high confidence.',
    parameters: {
      'type': 'object',
      'properties': {
        'minutes': {
          'type': 'integer',
          'description':
              'Estimated remaining work in minutes (1–1440). '
              'Examples: 30 for half an hour, 240 for 4 hours.',
        },
      },
      'required': ['minutes'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: TaskAgentToolNames.updateTaskDueDate,
    description:
        'Update the due date for the task. '
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
    description:
        'Update the priority of the task. '
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
    name: TaskAgentToolNames.assignTaskLabels,
    description:
        'Add one or more labels to the task. Only use labels from '
        'the available labels list provided in the context. Do not propose '
        'labels listed as suppressed. Cap to 3 labels per call.',
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
                'description': 'Confidence level. Omit low confidence labels.',
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
    description:
        'Set the detected language for the task. '
        'Only call when the task has NO language set. '
        'Never override a language the user has already set — the handler '
        'will reject it. Detect based on the task content (title, '
        'transcripts, notes).',
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
    description:
        'Transition the task to a new status. '
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
          'description':
              'Required for BLOCKED and ON HOLD. '
              'Explanation of why the task is blocked or on hold.',
        },
      },
      'required': ['status'],
      'additionalProperties': false,
    },
  ),
];
