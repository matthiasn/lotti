// Tool definitions for the project agent.

import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/project_agent_report_contract.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

/// Tool name constants used by the project agent.
abstract final class ProjectAgentToolNames {
  static const updateProjectReport = 'update_project_report';
  static const recordObservations = 'record_observations';
  static const recommendNextSteps = 'recommend_next_steps';
  static const updateProjectStatus = 'update_project_status';
  static const createTask = 'create_task';
  static const retractSuggestions = 'retract_suggestions';
}

/// The canonical `update_project_status` wire value for [raw], or `null` when
/// it is outside the vocabulary.
///
/// One alias table shared by the apply path (which turns the canonical value
/// into a `ProjectStatus`) and the render-time proposal summary (which turns
/// it into the localized status label) — so a proposal can never *display* a
/// different status than accepting it would set.
String? canonicalProjectStatus(String raw) {
  final normalized = raw
      .trim()
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(' ', '_');
  return switch (normalized) {
    'open' => 'open',
    'active' || 'on_track' || 'in_progress' => 'active',
    'monitoring' || 'monitor' => 'monitoring',
    'on_hold' || 'hold' || 'blocked' || 'at_risk' => 'on_hold',
    'completed' || 'complete' || 'done' => 'completed',
    'archived' || 'archive' || 'cancelled' || 'canceled' => 'archived',
    _ => null,
  };
}

/// The canonical `update_project_status` wire value [status] already carries.
///
/// The reverse of [canonicalProjectStatus], and its counterpart: comparing a
/// proposal's canonical value against this one is what tells a wake that
/// "set it to Active" would change nothing on an already-active project.
String canonicalProjectStatusOf(ProjectStatus status) => switch (status) {
  ProjectOpen() => 'open',
  ProjectActive() => 'active',
  ProjectMonitoring() => 'monitoring',
  ProjectOnHold() => 'on_hold',
  ProjectCompleted() => 'completed',
  ProjectArchived() => 'archived',
};

/// The [TaskPriority] a project-agent priority word means, or `null` when the
/// word is outside the vocabulary. A missing priority is medium, the default
/// every new task wears.
///
/// Shared by the `create_task` apply path and the next-steps surface, so a
/// step's priority chip can never show a level different from the task that
/// "Add task" would create.
TaskPriority? parseTaskPriority(Object? rawPriority) {
  if (rawPriority == null) return TaskPriority.p2Medium;
  if (rawPriority is! String) return null;

  return switch (rawPriority.trim().toUpperCase()) {
    'CRITICAL' || 'P0' => TaskPriority.p0Urgent,
    'HIGH' || 'P1' => TaskPriority.p1High,
    'MEDIUM' || 'P2' => TaskPriority.p2Medium,
    'LOW' || 'P3' => TaskPriority.p3Low,
    _ => null,
  };
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

/// Withdraws the agent's own still-open proposals.
///
/// Advertised only on a wake that actually has open proposals — see
/// [projectAgentToolsFor]. Offering it to an agent with nothing to withdraw
/// invites a hallucinated fingerprint and a wasted turn.
const projectRetractSuggestionsTool = AgentToolDefinition(
  name: ProjectAgentToolNames.retractSuggestions,
  description:
      'Withdraw one or more of your own previously-proposed changes that are '
      'no longer relevant (the project already matches them, or they '
      'duplicate another open proposal). The user is NOT prompted — the '
      'retraction is recorded in your decision history and the items '
      'disappear from the "Proposed changes" list. Use this to keep that '
      'list free of stale proposals. Only already-pending items can be '
      'retracted; items already confirmed, rejected, or retracted are '
      'no-ops.',
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
                  'The fingerprint shown in the open-proposal guard for the '
                  'item you want to withdraw. Must exactly match an `fp=...` '
                  'value listed there.',
            },
            'reason': {
              'type': 'string',
              'minLength': 1,
              'maxLength': 500,
              'description':
                  'One short sentence explaining why this proposal is no '
                  'longer relevant (e.g. "the project is already Active", '
                  '"the user created this task by hand").',
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
);

/// The tool surface for one wake.
///
/// [hasOpenProposals] adds [projectRetractSuggestionsTool]; without open
/// proposals there is nothing a retraction could target.
List<AgentToolDefinition> projectAgentToolsFor({
  required bool hasOpenProposals,
}) => [
  ...projectAgentTools,
  if (hasOpenProposals) projectRetractSuggestionsTool,
];

/// Project agent tools whose mutations require user confirmation.
const projectDeferredTools = <String>{
  ProjectAgentToolNames.recommendNextSteps,
  ProjectAgentToolNames.updateProjectStatus,
  ProjectAgentToolNames.createTask,
};
