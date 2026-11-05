import 'package:lotti/features/agents/tools/agent_tool_registry.dart';

/// The array key of a `create_time_entry` call: one element per session.
///
/// The model sends `{"entries": [...]}`; the change-set builder explodes the
/// array so each element is persisted, confirmed and applied as its own
/// `create_time_entry` item carrying that element's flat fields.
const createTimeEntryArrayKey = 'entries';

/// Wraps a pre-batch `create_time_entry` call — the flat `startTime` /
/// `endTime` / `summary` form a model may still echo from an older directive
/// or proposal — into the one-element batch the tool now takes.
///
/// Only a model's call goes through this. A persisted item already has the
/// flat form the dispatcher applies, and must never be wrapped.
Map<String, dynamic> wrapFlatCreateTimeEntryCall(
  String toolName,
  Map<String, dynamic> args,
) {
  if (toolName != TaskAgentToolNames.createTimeEntry ||
      args.containsKey(createTimeEntryArrayKey) ||
      !args.containsKey('startTime')) {
    return args;
  }
  return {
    createTimeEntryArrayKey: [args],
  };
}

/// Tools that record and revise time tracking: creating time entries and
/// editing existing ones, a running timer's text included.
const taskTimeTools = <AgentToolDefinition>[
  AgentToolDefinition(
    name: TaskAgentToolNames.createTimeEntry,
    description:
        'Create one or more NEW time tracking entries on the current task. '
        'This tool only creates: it never edits an entry that already '
        'exists — that is update_time_entry, which needs the entryId of the '
        'entry it revises. Creating needs no id at all: the entries are '
        'recorded on the task this wake is for, so pass neither an entryId '
        'nor a taskId. Put every session in ONE call through "entries" — '
        'when a dictation names several work blocks (e.g. 9:00–10:30, '
        '11:00–12:15 and 14:00–15:30), send all of them in the same call; '
        'each becomes its own suggestion that the user confirms or rejects '
        'separately. Use ONLY when the user has JUST NOW (within the last '
        'few minutes to ~1 hour) dictated what they worked on. The '
        'dictation must be from the current recording session — NEVER '
        'create entries based on old transcripts, historical context, or '
        'text from previous wakes. If unsure whether the dictation is '
        'recent, do NOT call this tool. Each entry is either (1) a '
        'completed session with start and end times (any day, past or '
        'future, including spans across midnight), or (2) a running timer '
        'with a start time only (omit endTime; today only, never the '
        'future) — at most one running timer. '
        'IMPORTANT: if the wake context contains an "Active Running Timer" '
        'section for this task, do NOT create an entry for the work '
        'covered by that timer — call update_time_entry with its entryId '
        'instead. create_time_entry is for sessions that are clearly '
        'distinct from the active timer.',
    parameters: {
      'type': 'object',
      'properties': {
        createTimeEntryArrayKey: {
          'type': 'array',
          'minItems': 1,
          'description':
              'The new time entries, one element per work session the '
              'user dictated, in chronological order.',
          'items': {
            'type': 'object',
            'properties': {
              'startTime': {
                'type': 'string',
                'description':
                    'Start time in local ISO 8601 format with explicit '
                    'time and no timezone suffix (e.g., '
                    "'2026-03-17T14:00:00'). May be any day for completed "
                    'sessions; for a running timer (no endTime) it must '
                    "be today's date and must not be in the future. "
                    "Resolve spoken times like '2 PM' or '14:00' or "
                    "'yesterday at 4 PM' to a full local timestamp using "
                    'the current date from context.',
              },
              'endTime': {
                'type': 'string',
                'description':
                    'End time in local ISO 8601 format with explicit time '
                    'and no timezone suffix. Omit to start a running '
                    'timer. Must be strictly after startTime. No other '
                    'temporal restrictions apply to completed sessions.',
              },
              'summary': {
                'type': 'string',
                'maxLength': 500,
                'description':
                    'A distilled 1-2 sentence summary of what the user '
                    'worked on in this session. Extract the essence from '
                    'the dictation — do not copy verbatim. Write in the '
                    "task's content language.",
              },
            },
            'required': ['startTime', 'summary'],
            'additionalProperties': false,
          },
        },
      },
      'required': [createTimeEntryArrayKey],
      'additionalProperties': false,
    },
  ),
  AgentToolDefinition(
    name: TaskAgentToolNames.updateTimeEntry,
    description:
        'Revise ONE existing time entry on this task — text, start time, '
        'end time, or any combination. Two uses: (1) a completed entry '
        'from the "Editable Time Entries" section, when the user has JUST '
        'NOW dictated a correction or addition based on the current '
        'recording session; (2) the timer in the "Active Running Timer" '
        'section, to replace its empty or terse text with a distilled '
        'summary of the work so far — pass ONLY entryId and summary, '
        'since a running timer has no end time yet and its start time '
        'cannot change while it runs. Do NOT use this for entries on '
        'other tasks, and never to record a new session — that is '
        'create_time_entry, which takes no entryId. Do NOT fabricate '
        'IDs — only reference IDs that appear in those two sections. The '
        'proposal is user-gated; the user reviews the diff before '
        'accepting.',
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
