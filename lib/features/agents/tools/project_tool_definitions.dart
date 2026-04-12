// Tool definitions for the project agent.

import 'package:lotti/features/agents/model/project_agent_report_contract.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

/// Tool name constants used by the project agent.
abstract final class ProjectAgentToolNames {
  static const updateProjectReport = 'update_project_report';
  static const recordObservations = 'record_observations';
  static const recommendNextSteps = 'recommend_next_steps';
  static const updateProjectStatus = 'update_project_status';
  static const createTask = 'create_task';
}

/// All tools available to the Project Agent.
const projectAgentTools = <AgentToolDefinition>[
  AgentToolDefinition(
    name: ProjectAgentToolNames.updateProjectReport,
    description:
        'Publish the updated project report. You MUST call this tool at '
        'the end of every wake with the updated markdown report body. '
        'Include a brief tldr (1-3 sentences) summarizing the most '
        'important change since the last report, plus the user-facing '
        'project health band and a concise rationale. The health band is '
        'shown directly in the UI, so choose the best fit based on your '
        'overall assessment of the project. The tldr is shown in the '
        'collapsed report view, so it must stand on its own. Do not repeat '
        'that TLDR inside the markdown body.',
    parameters: {
      'type': 'object',
      'properties': {
        ProjectAgentReportToolArgs.markdown: {
          'type': 'string',
          'description':
              'The markdown body for the expanded project report only. '
              'Do not include a TLDR section or repeat the project title.',
        },
        ProjectAgentReportToolArgs.tldr: {
          'type': 'string',
          'description':
              'A concise 1-3 sentence overview of the project state. This is '
              'shown in the collapsed view, so make it useful on its own.',
        },
        ProjectAgentReportToolArgs.oneLiner: {
          'type': 'string',
          'description':
              'A concise project tagline for compact project-card subtitles '
              'in the project list. One or two short sentences that capture '
              'the current state, next step, or primary risk. Longer than '
              'a task one-liner but much shorter than the tldr.',
        },
        ProjectAgentReportToolArgs.healthBand: {
          'type': 'string',
          'enum': ProjectAgentHealthBandValues.values,
          'description':
              'The overall project health band. Must be one of '
              '`surviving`, `on_track`, `watch`, `at_risk`, or `blocked`.',
        },
        ProjectAgentReportToolArgs.healthRationale: {
          'type': 'string',
          'description':
              'A short user-facing explanation of why this health band fits '
              'right now. This is shown directly in the UI under the band, '
              'so mention the main reason in plain language.',
        },
        ProjectAgentReportToolArgs.healthConfidence: {
          'type': 'number',
          'minimum': 0,
          'maximum': 1,
          'description':
              'Optional confidence in the health assessment, from 0 to 1.',
        },
      },
      'required': ProjectAgentReportToolArgs.required,
    },
  ),
  AgentToolDefinition(
    name: ProjectAgentToolNames.recordObservations,
    description:
        'Record private observations for future wakes. Use structured '
        'format with priority and category for important items.',
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
                        'Urgency level. Use "critical" for blockers or '
                        'risks that need immediate attention.',
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
  AgentToolDefinition(
    name: ProjectAgentToolNames.recommendNextSteps,
    description:
        'Propose recommended next steps for the project. These are '
        'presented to the user for review and are not executed immediately.',
    parameters: {
      'type': 'object',
      'properties': {
        'steps': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'title': {
                'type': 'string',
                'description': 'Short title for the recommended step.',
              },
              'rationale': {
                'type': 'string',
                'description': 'Why this step is recommended.',
              },
              'priority': {
                'type': 'string',
                'enum': ['high', 'medium', 'low'],
                'description': 'Priority of this recommendation.',
              },
            },
            'required': ['title', 'rationale'],
          },
          'description': 'List of recommended next steps.',
        },
      },
      'required': ['steps'],
    },
  ),
  AgentToolDefinition(
    name: ProjectAgentToolNames.updateProjectStatus,
    description:
        'Update the project status. This is a deferred tool — the change '
        'is presented to the user for review before being applied.',
    parameters: {
      'type': 'object',
      'properties': {
        'status': {
          'type': 'string',
          'description': 'The new project status value.',
        },
        'reason': {
          'type': 'string',
          'description': 'Brief explanation of why the status should change.',
        },
      },
      'required': ['status', 'reason'],
    },
  ),
  AgentToolDefinition(
    name: ProjectAgentToolNames.createTask,
    description:
        'Propose a new task to be created under this project. This is a '
        'deferred tool — the task is presented to the user for review '
        'before being created.',
    parameters: {
      'type': 'object',
      'properties': {
        'title': {
          'type': 'string',
          'description': 'Title for the new task.',
        },
        'description': {
          'type': 'string',
          'description': 'Description of what needs to be done.',
        },
        'priority': {
          'type': 'string',
          'enum': ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'],
          'description': 'Priority level for the task.',
        },
      },
      'required': ['title'],
    },
  ),
];

/// Project agent tools whose mutations require user confirmation.
const projectDeferredTools = <String>{
  ProjectAgentToolNames.recommendNextSteps,
  ProjectAgentToolNames.updateProjectStatus,
  ProjectAgentToolNames.createTask,
};
