// Tool definitions for the event agent.

import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/agent_observations.dart';

/// Tool name constants used by the event agent.
///
/// The event agent reuses the task agent's scope-agnostic narrate/observe
/// contract: `update_report` (oneLiner/tldr/content) and `record_observations`.
/// Keeping the names identical means the seeded directives, the strategy, and
/// any shared report rendering all reference the same wire values.
abstract final class EventAgentToolNames {
  static const updateReport = 'update_report';
  static const recordObservations = 'record_observations';
  static const suggestFollowUpTask = 'suggest_follow_up_task';
  static const listPeople = 'list_people';
  static const suggestPerson = 'suggest_person';
}

/// Wire argument names for `list_people` and `suggest_person`.
abstract final class EventAgentPersonToolArgs {
  static const query = 'query';
  static const personId = 'personId';
  static const mention = 'mention';

  /// Added by the strategy when it queues a suggestion — the person's name
  /// as the directory knew it, for the row the user confirms. Never sent by
  /// the model.
  static const personName = 'personName';
}

/// Wire argument names for the event agent's `update_report` call.
abstract final class EventAgentReportToolArgs {
  static const oneLiner = 'oneLiner';
  static const tldr = 'tldr';
  static const content = 'content';

  static const required = <String>[oneLiner, tldr, content];
}

/// All tools available to the Event Agent.
///
/// Narrating (`update_report`, `record_observations`), one read
/// (`list_people`), and two deferred proposals the user confirms or dismisses
/// (`suggest_follow_up_task`, `suggest_person`). Rating and cover selection
/// are human-only and are deliberately absent — the event agent has no tool
/// that can touch them.
final eventAgentTools = <AgentToolDefinition>[
  const AgentToolDefinition(
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
    parameters: recordObservationsParameters(
      textDescription: 'Observation content.',
    ),
  ),
  const AgentToolDefinition(
    name: EventAgentToolNames.listPeople,
    description:
        'List the people the user keeps on their People page: one line per '
        'person with their id, name and nickname, and whether they are '
        'already with this event, already suggested, or dismissed for it. '
        'Call it when a note, voice memo or photo caption names someone, to '
        'see whether that is a person the user keeps. Pass "query" to narrow '
        'the list to names or nicknames containing it.',
    parameters: {
      'type': 'object',
      'properties': {
        EventAgentPersonToolArgs.query: {
          'type': 'string',
          'description':
              'Optional: only people whose name or nickname contains this.',
        },
      },
    },
  ),
  const AgentToolDefinition(
    name: EventAgentToolNames.suggestPerson,
    description:
        'Suggest adding a person the user keeps to this event, because the '
        "event's notes, voice memos or photo captions show they were there. "
        'Use an id from `list_people`. This is a deferred tool — the user '
        'confirms or dismisses it, and only on confirm is the person linked '
        'to the event (and the event put on their timeline). Only suggest '
        'someone the event clearly names as present; never suggest someone '
        'already with the event, already suggested, or dismissed.',
    parameters: {
      'type': 'object',
      'properties': {
        EventAgentPersonToolArgs.personId: {
          'type': 'string',
          'description': "The person's id, exactly as `list_people` gave it.",
        },
        EventAgentPersonToolArgs.mention: {
          'type': 'string',
          'description':
              'The words in the event that name them, quoted briefly.',
        },
      },
      'required': [EventAgentPersonToolArgs.personId],
    },
  ),
  const AgentToolDefinition(
    name: EventAgentToolNames.suggestFollowUpTask,
    description:
        'Propose a concrete follow-up task the event implies (send a '
        'thank-you, share the album, book the next one). This is a deferred '
        'tool — the task is presented to the user for review and only created '
        'on accept. Only suggest follow-ups that are clearly grounded in the '
        'event; do not invent busywork.',
    parameters: {
      'type': 'object',
      'properties': {
        'title': {
          'type': 'string',
          'description': 'Short, action-oriented title for the follow-up task.',
        },
        'notes': {
          'type': 'string',
          'description': 'Optional context for what the task involves and why.',
        },
      },
      'required': ['title'],
    },
  ),
];

/// Event agent tools whose mutations require user confirmation before being
/// applied (surfaced as accept/reject suggestions).
const eventDeferredTools = <String>{
  EventAgentToolNames.suggestFollowUpTask,
  EventAgentToolNames.suggestPerson,
};
