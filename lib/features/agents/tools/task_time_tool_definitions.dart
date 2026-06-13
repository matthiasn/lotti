import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

/// Tools that record and revise time tracking: creating time entries,
/// updating a running timer, and editing existing time entries.
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
        'work covered by that timer — call update_running_timer instead. '
        'create_time_entry is for sessions that are clearly distinct from '
        'the active timer.',
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
    name: TaskAgentToolNames.updateRunningTimer,
    description:
        'Propose a richer text description for the currently running '
        'timer on this task. Call this INSTEAD of create_time_entry when '
        'the wake context contains an "Active Running Timer" section: the '
        'user already started a timer with an empty or terse description, '
        'and the agent should update it with a distilled summary of what '
        'has been worked on so far. The proposal is user-gated; the user '
        'sees a diff between the current text and your proposed text '
        'before accepting. Replaces the timer entry text outright (the '
        'user can still edit before accepting).',
    parameters: {
      'type': 'object',
      'properties': {
        'timerId': {
          'type': 'string',
          'description':
              'The ID of the running timer entry, taken verbatim from the '
              '"Active Running Timer" section of the wake context. Must '
              'match the currently running timer at execution time.',
        },
        'summary': {
          'type': 'string',
          'maxLength': 500,
          'description':
              'A distilled 1-2 sentence summary of what the user has '
              'worked on during the running session so far. Extract the '
              'essence from the dictation — do not copy verbatim. Write '
              "in the task's content language.",
        },
      },
      'required': ['timerId', 'summary'],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: TaskAgentToolNames.updateTimeEntry,
    description:
        'Revise an existing completed time entry on this task — text, '
        'start time, end time, or any combination — when the user has JUST '
        'NOW dictated a correction or addition based on the current '
        "recording session. Use this when the wake context's "
        '"Editable Time Entries" section contains the entry the user is '
        'referring to. Do NOT use this for the currently running timer '
        '(use update_running_timer instead). Do NOT use this for entries '
        'on other tasks. Do NOT fabricate IDs — only reference IDs that '
        'appear in the Editable Time Entries section. The proposal is '
        'user-gated; the user reviews the diff before accepting.',
    parameters: {
      'type': 'object',
      'properties': {
        'entryId': {
          'type': 'string',
          'description':
              'The ID of the journal entry to update, taken verbatim from '
              'the "Editable Time Entries" section of the wake context.',
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
