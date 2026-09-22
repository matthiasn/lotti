import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

/// Tools that record and revise time tracking: creating time entries and
/// editing existing ones, a running timer's text included.
const taskTimeTools = <AgentToolDefinition>[
  AgentToolDefinition(
    name: TaskAgentToolNames.createTimeEntry,
    description:
        'Create a time tracking entry for a work session on the '
        'current task. Use ONLY when the user has JUST NOW (within the last '
        'few minutes to ~1 hour) dictated what they worked on. The '
        'dictation must be from the current recording session — NEVER '
        'create entries based on old transcripts, historical context, or '
        'text from previous wakes. If unsure whether the dictation is '
        'recent, do NOT call this tool. Supports two modes: (1) completed '
        'session with start and end times (any day, past or future, '
        'including spans across midnight), (2) running timer with start '
        'time only (omit endTime; today only, never the future). '
        'IMPORTANT: if the wake context contains an "Active Running Timer" '
        'section for this task, do NOT call this tool to describe the '
        'work covered by that timer — call update_time_entry with its '
        'entryId instead. create_time_entry is for sessions that are '
        'clearly distinct from the active timer.',
    parameters: {
      'type': 'object',
      'properties': {
        'startTime': {
          'type': 'string',
          'description':
              'Start time in local ISO 8601 format with explicit time and '
              "no timezone suffix (e.g., '2026-03-17T14:00:00'). May be "
              'any day for completed sessions; for a running timer '
              "(no endTime) it must be today's date and must not be in "
              'the future. Resolve '
              "spoken times like '2 PM' or '14:00' or 'yesterday at 4 PM' "
              'to a full local timestamp using the current date from '
              'context.',
        },
        'endTime': {
          'type': 'string',
          'description':
              'End time in local ISO 8601 format with explicit time and no '
              'timezone suffix. Omit to start a running timer. Must be '
              'strictly after startTime. No other temporal restrictions '
              'apply to completed sessions.',
        },
        'summary': {
          'type': 'string',
          'maxLength': 500,
          'description':
              'A distilled 1-2 sentence summary of what the user worked '
              'on. Extract the essence from the dictation — do not copy '
              "verbatim. Write in the task's content language.",
        },
      },
      'required': ['startTime', 'summary'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: TaskAgentToolNames.updateTimeEntry,
    description:
        'Revise an existing time entry on this task — text, start time, '
        'end time, or any combination. Two uses: (1) a completed entry '
        'from the "Editable Time Entries" section, when the user has JUST '
        'NOW dictated a correction or addition based on the current '
        'recording session; (2) the timer in the "Active Running Timer" '
        'section, to replace its empty or terse text with a distilled '
        'summary of the work so far — pass ONLY entryId and summary, '
        'since a running timer has no end time yet and its start time '
        'cannot change while it runs. Do NOT use this for entries on '
        'other tasks. Do NOT fabricate IDs — only reference IDs that '
        'appear in those two sections. The proposal is user-gated; the '
        'user reviews the diff before accepting.',
    parameters: {
      'type': 'object',
      'properties': {
        'entryId': {
          'type': 'string',
          'description':
              'The ID of the journal entry to update, taken verbatim from '
              'the "Editable Time Entries" or "Active Running Timer" '
              'section of the wake context.',
        },
        'startTime': {
          'type': 'string',
          'description':
              'Optional new start time in local ISO 8601 format with '
              'explicit time and no timezone suffix (e.g., '
              "'2026-04-15T13:30:00'). Omit to keep the entry's current "
              'dateFrom.',
        },
        'endTime': {
          'type': 'string',
          'description':
              'Optional new end time in local ISO 8601 format with '
              'explicit time and no timezone suffix. Omit to keep the '
              "entry's current dateTo. Must be strictly after the new "
              '(or unchanged) startTime — no other temporal restrictions '
              'apply.',
        },
        'summary': {
          'type': 'string',
          'maxLength': 500,
          'description':
              'Optional revised 1-2 sentence summary of what the user '
              'worked on. Distill from the dictation — do not copy '
              "verbatim. Omit to keep the entry's current text. Write in "
              "the task's content language.",
        },
      },
      'required': ['entryId'],
      'additionalProperties': false,
    },
  ),
];
