// Tool definitions for the event agent.

import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

/// Tool name constants used by the event agent.
///
/// The event agent reuses the task agent's scope-agnostic narrate/observe
/// contract: `update_report` (oneLiner/tldr/content) and `record_observations`.
/// Keeping the names identical means the seeded directives, the strategy, and
/// any shared report rendering all reference the same wire values.
abstract final class EventAgentToolNames {
  static const updateReport = 'update_report';
  static const recordObservations = 'record_observations';
}

/// Wire argument names for the event agent's `update_report` call.
abstract final class EventAgentReportToolArgs {
  static const oneLiner = 'oneLiner';
  static const tldr = 'tldr';
  static const content = 'content';

  static const required = <String>[oneLiner, tldr, content];
}

/// All tools available to the Event Agent (v1: narrate-only).
///
/// Rating and cover selection are human-only and are deliberately absent — the
/// event agent has no tool that can touch them. Status / follow-up write
/// actions arrive later as deferred (accept/reject) tools.
const eventAgentTools = <AgentToolDefinition>[
  AgentToolDefinition(
    name: EventAgentToolNames.updateReport,
    description:
        'Publish the updated event recap. You MUST call this tool exactly '
        'once at the end of every wake. Provide a compact one-liner tagline, '
        'a short TLDR, and the full recap as markdown. Follow the structure '
        'in your report directive. Write a warm, readable narrative grounded '
        'in the linked photos, notes, and voice memos — never invent details, '
        'and never comment on the rating or cover photo.',
    parameters: {
      'type': 'object',
      'properties': {
        EventAgentReportToolArgs.oneLiner: {
          'type': 'string',
          'description':
              'A concise event tagline for the event-card subtitle. A short '
              'single sentence or phrase that captures the essence of the '
              'memory.',
        },
        EventAgentReportToolArgs.tldr: {
          'type': 'string',
          'description':
              'A concise 1-2 sentence recap of the event and its most '
              'memorable moment. Shown in the collapsed view, so make it '
              'stand on its own.',
        },
        EventAgentReportToolArgs.content: {
          'type': 'string',
          'description':
              'The full recap as a markdown document. Do not repeat the event '
              'title as a heading or restate the TLDR.',
        },
      },
      'required': EventAgentReportToolArgs.required,
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: EventAgentToolNames.recordObservations,
    description:
        'Record private observations for future wakes. Use this to note '
        'follow-up ideas, patterns, or anything worth remembering across '
        'recaps. These are never shown to the user.',
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
                    'description':
                        'Urgency level. Use "critical" only for something '
                        'that genuinely needs attention.',
                  },
                  'category': {
                    'type': 'string',
                    'enum': [
                      'grievance',
                      'excellence',
                      'templateImprovement',
                      'operational',
                    ],
                    'description': 'Category of the observation.',
                  },
                },
                'required': ['text'],
              },
            ],
          },
          'description': 'List of observations to record.',
        },
      },
      'required': ['observations'],
    },
  ),
];
