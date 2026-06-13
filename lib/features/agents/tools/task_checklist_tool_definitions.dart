import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

/// Tools that manage checklist items and split work into follow-up tasks:
/// adding/updating checklist items, creating follow-up tasks, and migrating
/// items between tasks.
const taskChecklistTools = <AgentToolDefinition>[
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
                'description':
                    'Whether the item starts checked. '
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
        'least one of isChecked, title, or isArchived. When an item was '
        'last toggled by the user, you must provide a reason citing '
        "evidence from AFTER the user's action to change its checked "
        'state. Title updates are always allowed. Use isArchived: true to '
        'archive a duplicate or obsolete item — archiving is reversible '
        'and is the right way to deduplicate, never re-titling.',
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
              'isArchived': {
                'type': 'boolean',
                'description':
                    'Archive (true) or restore (false) the item. Archive '
                    'duplicates and obsolete items instead of re-titling '
                    'them; archived items stay recoverable.',
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
    name: TaskAgentToolNames.createFollowUpTask,
    description:
        'Create a follow-up task linked to the current task. Use when the '
        'user describes a distinct new task in audio or notes, especially '
        'when combined with checklist items to migrate. The new task '
        "inherits the source task's category. Returns a placeholder "
        'targetTaskId for use with migrate_checklist_items.',
    parameters: {
      'type': 'object',
      'properties': {
        'title': {
          'type': 'string',
          'description': 'Title for the new follow-up task.',
        },
        'dueDate': {
          'type': 'string',
          'description':
              'Optional due date in YYYY-MM-DD format (e.g., 2024-06-30).',
        },
        'priority': {
          'type': 'string',
          'description':
              'Priority level (P0, P1, P2, P3). Defaults to P2 if omitted.',
        },
        'description': {
          'type': 'string',
          'description':
              'Optional description text for the new task. '
              "Becomes the task's entry text.",
        },
      },
      'required': ['title'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: TaskAgentToolNames.migrateChecklistItems,
    description:
        'Migrate checklist items from the current task to a follow-up task. '
        'Archives items in the source task and creates copies in the target. '
        'Use after create_follow_up_task to move identified items.',
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
                'description': 'The checklist item ID to migrate.',
              },
              'title': {
                'type': 'string',
                'description':
                    'The checklist item title (for display in the '
                    'approval UI).',
              },
            },
            'required': ['id', 'title'],
            'additionalProperties': false,
          },
          'description': 'List of checklist items to migrate.',
        },
        'targetTaskId': {
          'type': 'string',
          'description':
              'The placeholder task ID returned by create_follow_up_task.',
        },
      },
      'required': ['items', 'targetTaskId'],
      'additionalProperties': false,
    },
  ),
];
