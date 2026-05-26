import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';

/// Foundation-phase tools exposed to the Daily OS day agent.
const dayAgentTools = <AgentToolDefinition>[
  AgentToolDefinition(
    name: DayAgentToolNames.recordObservations,
    description:
        'Record private observations for future Daily OS wakes and template '
        'evolution. Use this for timing preferences, uncertainty, capacity '
        'patterns, and wake outcome notes.',
    parameters: {
      'type': 'object',
      'properties': {
        'observations': {
          'type': 'array',
          'items': {
            'oneOf': [
              {'type': 'string'},
              {
                'type': 'object',
                'properties': {
                  'text': {
                    'type': 'string',
                    'description': 'Observation content.',
                  },
                  'priority': {
                    'type': 'string',
                    'enum': ['routine', 'notable', 'critical'],
                  },
                  'category': {
                    'type': 'string',
                    'enum': [
                      'grievance',
                      'excellence',
                      'templateImprovement',
                      'operational',
                    ],
                  },
                },
                'required': ['text'],
                'additionalProperties': false,
              },
            ],
          },
        },
      },
      'required': ['observations'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: DayAgentToolNames.setNextWake,
    description:
        'Schedule the next useful Daily OS wake. Use ISO-8601 local date-time '
        'for at and include a concise reason. Do not schedule noisy or '
        'repetitive wakes.',
    parameters: {
      'type': 'object',
      'properties': {
        'at': {
          'type': 'string',
          'description': 'ISO-8601 local date-time for the next wake.',
        },
        'reason': {
          'type': 'string',
          'description': 'Why this wake will be useful to the user.',
        },
      },
      'required': ['at', 'reason'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: DayAgentToolNames.submitCapture,
    description:
        'Persist a user capture transcript and enqueue parsing. capturedAt '
        'must be an ISO-8601 date-time.',
    parameters: {
      'type': 'object',
      'properties': {
        'transcript': {
          'type': 'string',
          'description': 'Pre-transcribed capture text.',
        },
        'capturedAt': {
          'type': 'string',
          'description': 'ISO-8601 date-time when the user captured it.',
        },
        'audioRef': {
          'type': 'string',
          'description': 'Optional JournalAudio id once STT is wired.',
        },
      },
      'required': ['transcript', 'capturedAt'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: DayAgentToolNames.parseCaptureToItems,
    description:
        'Persist parsed items for the capture currently being reconciled. '
        'Use confidenceScore >= 0.75 for strong matches, 0.5-0.75 for '
        'low-confidence matches, and <0.5 for new items.',
    parameters: {
      'type': 'object',
      'properties': {
        'captureId': {'type': 'string'},
        'items': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'kind': {
                'type': 'string',
                'enum': ['newTask', 'matched', 'update'],
              },
              'title': {'type': 'string'},
              'categoryId': {'type': 'string'},
              'confidenceScore': {
                'type': 'number',
                'minimum': 0,
                'maximum': 1,
              },
              'spokenPhrase': {'type': 'string'},
              'matchedTaskId': {'type': 'string'},
              'estimateMinutes': {'type': 'integer'},
              'timeAnchor': {'type': 'string'},
              'proposedUpdate': {'type': 'string'},
            },
            'required': ['kind', 'title', 'categoryId', 'confidenceScore'],
            'additionalProperties': false,
          },
        },
      },
      'required': ['captureId', 'items'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: DayAgentToolNames.matchToCorpus,
    description:
        'Find existing task candidates for a capture phrase. Use for cheap '
        'did-you-mean follow-ups, not for the initial parse.',
    parameters: {
      'type': 'object',
      'properties': {
        'phrase': {'type': 'string'},
        'categoryHint': {'type': 'string'},
      },
      'required': ['phrase'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: DayAgentToolNames.linkCapturePhraseToTask,
    description: 'Attach a parsed capture item to an existing task.',
    parameters: {
      'type': 'object',
      'properties': {
        'captureItemId': {'type': 'string'},
        'taskId': {'type': 'string'},
      },
      'required': ['captureItemId', 'taskId'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: DayAgentToolNames.breakCaptureLink,
    description: 'Remove a parsed capture item task link.',
    parameters: {
      'type': 'object',
      'properties': {
        'captureItemId': {'type': 'string'},
      },
      'required': ['captureItemId'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: DayAgentToolNames.surfacePendingDecisions,
    description:
        'List overdue, in-progress, missed-recurring, and due-today task '
        'decisions for a Daily OS day.',
    parameters: {
      'type': 'object',
      'properties': {
        'dayId': {'type': 'string'},
      },
      'required': ['dayId'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: DayAgentToolNames.applyTriage,
    description:
        'Apply a reconcile triage action. Actions: today, doNow, defer, '
        'done, drop. defer requires deferTo.',
    parameters: {
      'type': 'object',
      'properties': {
        'taskId': {'type': 'string'},
        'action': {
          'type': 'string',
          'enum': ['today', 'doNow', 'defer', 'done', 'drop'],
        },
        'deferTo': {
          'type': 'string',
          'description': 'ISO-8601 date-time for deferred tasks.',
        },
      },
      'required': ['taskId', 'action'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: DayAgentToolNames.createTaskFromPhrase,
    description:
        'Propose a new task from a capture phrase. This creates a pending '
        'change set; it does not directly create the task.',
    parameters: {
      'type': 'object',
      'properties': {
        'phrase': {'type': 'string'},
        'category': {'type': 'string'},
        'estimate': {'type': 'integer'},
        'dueAnchor': {'type': 'string'},
        'captureItemId': {'type': 'string'},
      },
      'required': ['phrase', 'category'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: DayAgentToolNames.draftDayPlan,
    description:
        'Persist a drafted day plan. The model supplies blocks and optional '
        'energy bands. Every ai block must include a non-empty reason.',
    parameters: {
      'type': 'object',
      'properties': {
        'dayId': {'type': 'string'},
        'dayDate': {
          'type': 'string',
          'description': 'ISO-8601 date-time for the local day being drafted.',
        },
        'captureId': {'type': 'string'},
        'decidedTaskIds': {
          'type': 'array',
          'items': {'type': 'string'},
        },
        'capacityMinutes': {'type': 'integer'},
        'dayLabel': {'type': 'string'},
        'blocks': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'id': {'type': 'string'},
              'title': {'type': 'string'},
              'taskId': {'type': 'string'},
              'categoryId': {'type': 'string'},
              'start': {
                'type': 'string',
                'description': 'ISO-8601 block start time.',
              },
              'end': {
                'type': 'string',
                'description': 'ISO-8601 block end time.',
              },
              'type': {
                'type': 'string',
                'enum': ['ai', 'cal', 'buffer', 'manual'],
              },
              'state': {
                'type': 'string',
                'enum': [
                  'drafted',
                  'committed',
                  'inProgress',
                  'completed',
                  'dropped',
                ],
              },
              'reason': {
                'type': 'string',
                'minLength': 1,
                'description':
                    'Why this block belongs here. Required for ai blocks.',
              },
              'note': {'type': 'string'},
            },
            'required': ['title', 'categoryId', 'start', 'end', 'type'],
            'additionalProperties': false,
            'if': {
              'properties': {
                'type': {'const': 'ai'},
              },
            },
            'then': {
              'required': ['reason'],
            },
          },
        },
        'energyBands': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'start': {'type': 'string'},
              'end': {'type': 'string'},
              'level': {
                'type': 'string',
                'enum': ['high', 'low', 'secondWind'],
              },
              'label': {'type': 'string'},
            },
            'required': ['start', 'end', 'level', 'label'],
            'additionalProperties': false,
          },
        },
      },
      'required': ['dayId', 'blocks'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: DayAgentToolNames.summarizeRecentPatterns,
    description:
        'Return transient learning-card payloads from recent day-agent '
        'drafts. Use before or during day-plan drafting.',
    parameters: {
      'type': 'object',
      'properties': {
        'asOf': {
          'type': 'string',
          'description': 'ISO-8601 date-time anchoring the lookback window.',
        },
        'lookbackDays': {'type': 'integer'},
      },
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: DayAgentToolNames.proposePlanDiff,
    description:
        'Propose a structured diff against an existing day plan. Emits a '
        'ChangeSet of moved/added/dropped block changes for the user to '
        'accept or revert. Every change must include a non-empty reason.',
    parameters: {
      'type': 'object',
      'properties': {
        'dayId': {'type': 'string'},
        'baselinePlanId': {
          'type': 'string',
          'description':
              'ID of the DayPlanEntity this diff was computed against. '
              'Optional — when supplied, the handler rejects the diff if the '
              'live plan id has shifted (stale-baseline guard).',
        },
        'captureId': {
          'type': 'string',
          'description':
              'ID of the refinement-transcript CaptureEntity, if persisted.',
        },
        'changes': {
          'type': 'array',
          'minItems': 1,
          'items': {
            'type': 'object',
            'properties': {
              'action': {
                'type': 'string',
                'enum': ['moved', 'added', 'dropped'],
              },
              'blockId': {
                'type': 'string',
                'description':
                    'Required for moved/dropped; absent for added '
                    '(server assigns the new id).',
              },
              'from': {
                'type': 'object',
                'description':
                    'Original block snapshot. Required for moved/dropped.',
                'properties': {
                  'start': {'type': 'string'},
                  'end': {'type': 'string'},
                  'title': {'type': 'string'},
                  'categoryId': {'type': 'string'},
                },
                'additionalProperties': false,
              },
              'to': {
                'type': 'object',
                'description': 'Desired block shape. Required for moved/added.',
                'properties': {
                  'start': {'type': 'string'},
                  'end': {'type': 'string'},
                  'title': {'type': 'string'},
                  'categoryId': {'type': 'string'},
                  'taskId': {'type': 'string'},
                  'type': {
                    'type': 'string',
                    'enum': ['ai', 'cal', 'buffer', 'manual'],
                  },
                  'reason': {'type': 'string', 'minLength': 1},
                },
                'additionalProperties': false,
              },
              'reason': {
                'type': 'string',
                'minLength': 1,
                'description': 'Why this change. Required for every change.',
              },
            },
            'required': ['action', 'reason'],
            'additionalProperties': false,
          },
        },
      },
      'required': ['dayId', 'changes'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: DayAgentToolNames.acceptDiff,
    description:
        'Apply a previously proposed plan diff. Omit itemIndices to accept '
        'every change in the ChangeSet.',
    parameters: {
      'type': 'object',
      'properties': {
        'changeSetId': {'type': 'string'},
        'itemIndices': {
          'type': 'array',
          'items': {'type': 'integer', 'minimum': 0},
          'description':
              'Zero-based indices of the changes to accept. Omit to accept '
              'all pending changes.',
        },
      },
      'required': ['changeSetId'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: DayAgentToolNames.revertDiff,
    description:
        'Retract a previously proposed plan diff without mutating the live '
        'plan entity. Omit itemIndices to retract every change in the '
        'ChangeSet.',
    parameters: {
      'type': 'object',
      'properties': {
        'changeSetId': {'type': 'string'},
        'itemIndices': {
          'type': 'array',
          'items': {'type': 'integer', 'minimum': 0},
          'description':
              'Zero-based indices of the changes to retract. Omit to '
              'retract all pending changes.',
        },
      },
      'required': ['changeSetId'],
      'additionalProperties': false,
    },
  ),
];
