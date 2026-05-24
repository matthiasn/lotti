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
];
