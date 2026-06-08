part of 'agent_tool_registry.dart';

/// Tools for planning, attention negotiation, reporting, and observations:
/// related-task lookups, attention requests, report publishing, suggestion
/// retraction, and recording private observations.
const _taskPlanningTools = <AgentToolDefinition>[
  AgentToolDefinition(
    name: TaskAgentToolNames.getRelatedTaskDetails,
    description:
        'Fetch full details for one related task in the same parent '
        'project. Use only when a task from the related-tasks directory is '
        'directly relevant to the current task. Use sparingly.',
    enabled: false,
    parameters: {
      'type': 'object',
      'properties': {
        'taskId': {
          'type': 'string',
          'description':
              "The ID of a task listed in the current wake's related-tasks "
              'directory.',
        },
      },
      'required': ['taskId'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: TaskAgentToolNames.requestAttention,
    description:
        'Ask the day planner to reserve attention/time for this task. '
        'Use this when the task needs scheduled work soon, has a deadline, '
        'or should compete for planner attention. Do not use it for vague '
        'interest; make a concrete evidence-backed claim. Check the '
        'Attention Requests section in the task context first and do not '
        'repeat an equivalent active request.',
    parameters: {
      'type': 'object',
      'properties': {
        'title': {
          'type': 'string',
          'description':
              'Short planner-facing label. Omit to use the task title.',
        },
        'requestedMinutes': {
          'type': 'integer',
          'minimum': 1,
          'maximum': 1440,
          'description': 'Minutes of planner time requested for the task.',
        },
        'impact': {
          'type': 'integer',
          'minimum': 1,
          'maximum': 5,
          'description':
              'How valuable it is to schedule this task now, 1 low to 5 high.',
        },
        'urgency': {
          'type': 'integer',
          'minimum': 1,
          'maximum': 5,
          'description': 'How time-sensitive the request is, 1 low to 5 high.',
        },
        'energyFit': {
          'type': 'string',
          'enum': ['low', 'neutral', 'high'],
          'description':
              'Energy level needed for a good slot: low, neutral, or high.',
        },
        'earliestStart': {
          'type': 'string',
          'description':
              'Optional earliest acceptable ISO-8601 start time/date.',
        },
        'latestEnd': {
          'type': 'string',
          'description': 'Optional latest acceptable ISO-8601 end time/date.',
        },
        'deadline': {
          'type': 'string',
          'description':
              'Optional hard or meaningful ISO-8601 deadline for the work.',
        },
        'nextReviewAt': {
          'type': 'string',
          'description':
              'Optional ISO-8601 time when the planner should reconsider.',
        },
        'scopeKind': {
          'type': 'string',
          'enum': ['day', 'dateRange', 'deadline', 'recurrence'],
          'description':
              'Optional explicit planning scope. Usually omit and let the '
              'tool infer it from latestEnd/deadline.',
        },
        'rationale': {
          'type': 'string',
          'description':
              'Brief evidence-backed reason the planner should consider it.',
        },
      },
      'required': [
        'requestedMinutes',
        'impact',
        'urgency',
        'energyFit',
        'rationale',
      ],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: TaskAgentToolNames.resolveAttentionRequest,
    description:
        "Resolve one of this task agent's own active attention requests "
        'when it is no longer an accurate planner ask. Use this after '
        'checking the Attention Requests section. If the task is done, mark '
        'the request satisfied. If the task no longer needs calendar time, '
        'withdraw it. If the task still needs attention but the ask changed, '
        'call request_attention with the new concrete ask instead; that '
        'supersedes the old own request.',
    parameters: {
      'type': 'object',
      'properties': {
        'requestId': {
          'type': 'string',
          'description':
              'The active attention request id from the Attention Requests '
              'section. Must belong to this task agent.',
        },
        'status': {
          'type': 'string',
          'enum': [
            'withdrawn',
            'satisfied',
            'partiallySatisfied',
            'deferred',
          ],
          'description':
              'How to resolve the active request: withdrawn when no time is '
              'needed, satisfied when completed by actual work, '
              'partiallySatisfied when some need remains, or deferred when '
              'it should be reconsidered later.',
        },
        'reason': {
          'type': 'string',
          'minLength': 1,
          'maxLength': 500,
          'description':
              'One concise evidence-backed sentence explaining why the '
              'request is being resolved.',
        },
        'nextReviewAt': {
          'type': 'string',
          'description':
              'Optional ISO-8601 time for reconsideration, mainly for '
              'deferred or partiallySatisfied requests.',
        },
      },
      'required': ['requestId', 'status', 'reason'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: TaskAgentToolNames.updateReport,
    description:
        'Publish the updated task report. You MUST call this tool exactly '
        'once at the end of every wake. Provide a compact one-liner '
        'tagline, a short TLDR summary, and the full report content as '
        'markdown. Follow the report structure defined in your report '
        'directive. Write in the task content language. Express your '
        'personality and voice from your directives.',
    parameters: {
      'type': 'object',
      'properties': {
        'oneLiner': {
          'type': 'string',
          'description':
              'A concise task tagline for compact task-card subtitles. '
              'Keep it to a short single sentence or phrase that captures '
              'the current state, next step, or risk clearly.',
        },
        'tldr': {
          'type': 'string',
          'description':
              'A concise 1-3 sentence overview of the task '
              'state. This is shown in the collapsed view. Be punchy and '
              'include 1-2 relevant emojis.',
        },
        'content': {
          'type': 'string',
          'description': 'The full updated report as a markdown document.',
        },
      },
      'required': ['oneLiner', 'tldr', 'content'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: TaskAgentToolNames.retractSuggestions,
    description:
        'Withdraw one or more of your own previously-proposed changes that '
        'are no longer relevant (the current task state already matches '
        'them, or they duplicate another open proposal). The user is NOT '
        'prompted — the retraction is recorded in your decision history '
        'and the items disappear from the active suggestion list. Use this '
        'to keep the user-facing list free of stale proposals. Only '
        'already-pending items can be retracted; items already confirmed, '
        'rejected, or retracted are no-ops.',
    parameters: {
      'type': 'object',
      'properties': {
        'proposals': {
          'type': 'array',
          'minItems': 1,
          'items': {
            'type': 'object',
            'properties': {
              'fingerprint': {
                'type': 'string',
                'description':
                    'The fingerprint shown in the proposal ledger for the '
                    'item you want to withdraw. Must exactly match an '
                    "`fp=...` value from the ledger's Open section.",
              },
              'reason': {
                'type': 'string',
                'minLength': 1,
                'maxLength': 500,
                'description':
                    'One short sentence explaining why this proposal is '
                    'no longer relevant (e.g. "priority is already P1", '
                    '"user added this item manually", "duplicate of '
                    'open proposal fp=a7c…").',
              },
            },
            'required': ['fingerprint', 'reason'],
            'additionalProperties': false,
          },
          'description':
              'One entry per proposal you want to retract in this call.',
        },
      },
      'required': ['proposals'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: TaskAgentToolNames.recordObservations,
    description:
        'Record private observations for future wakes. Use this to note '
        'patterns, insights, failure notes, or anything worth remembering. '
        'For grievances and excellence notes, set priority to "critical" '
        'and include a full paragraph of context explaining the situation.',
    parameters: {
      'type': 'object',
      'properties': {
        'observations': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'text': {
                'type': 'string',
                'description':
                    'The observation text. For critical '
                    'priority, write a full paragraph explaining the '
                    'situation, what went wrong (or right), and why '
                    'it matters.',
              },
              'priority': {
                'type': 'string',
                'enum': ['routine', 'notable', 'critical'],
                'description':
                    'Priority level. Use "critical" for user '
                    'grievances, excellence notes, and template '
                    'improvement requests. Default: "routine".',
              },
              'category': {
                'type': 'string',
                'enum': [
                  'grievance',
                  'excellence',
                  'template_improvement',
                  'operational',
                ],
                'description':
                    'Category of observation. Required for '
                    '"critical" and "notable" priorities.',
              },
              'target': {
                'type': 'string',
                'enum': ['template', 'soul', 'both'],
                'description':
                    'Where this observation applies: "template" for '
                    'skill/operational issues, "soul" for personality '
                    'issues, "both" for issues spanning both.',
              },
            },
            'required': ['text'],
          },
          'description': 'List of observations to persist.',
        },
      },
      'required': ['observations'],
      'additionalProperties': false,
    },
  ),
];
