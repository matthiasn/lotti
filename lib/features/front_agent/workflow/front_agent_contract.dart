import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';

/// The front agent's tool names.
abstract final class FrontAgentToolNames {
  /// The terminal artifact: every segment of the input and its destination.
  static const dispatch = 'dispatch';

  /// The second rung of the ladder: the TL;DRs of a few listed destinations.
  static const readTldr = 'read_tldr';

  /// The fallback for an open task the truncated index omits.
  static const matchToCorpus = 'match_to_corpus';

  /// One short clarifying question with up to three candidates; terminal.
  static const askUser = 'ask_user';

  /// Her own words; terminal when nothing is dispatched.
  static const String replyToUser = AgentConversationToolNames.replyToUser;
}

/// How many provider calls one user turn may make: two lookups then the
/// dispatch, or one lookup, an invalid dispatch and its one repair. A
/// repair after two lookups fails closed and the message stays retryable.
const int frontProviderCallsPerTurn = 3;

/// How many `read_tldr` calls a turn may make.
const int frontTldrReadsPerTurn = 1;

/// How many ids one `read_tldr` may name.
const int frontTldrIdsPerRead = 5;

/// How many `match_to_corpus` calls a turn may make.
const int frontCorpusMatchesPerTurn = 1;

/// How many candidates `ask_user` may offer.
const int frontAskUserMaxOptions = 3;

/// The answer once a turn has used its TL;DR read. The tool stays listed —
/// removing it would change the request prefix and void the provider's
/// cache — and the handler refuses instead.
const String frontTldrExhaustedAnswer =
    'No more TL;DR reads this turn ($frontTldrReadsPerTurn used); decide '
    'from the index and what you read, or ask the user.';

/// The answer once a turn has used its corpus match.
const String frontCorpusMatchExhaustedAnswer =
    'No more corpus matches this turn ($frontCorpusMatchesPerTurn used); '
    'decide from the index and what you found, or ask the user.';

/// The instruction after an invalid `dispatch`, or a turn that ended
/// without a terminal call: the one repair the budget allows.
const String frontDispatchRepairInstruction =
    'The turn is not finished. Call dispatch now with ordered, '
    'non-overlapping spans that cover the whole input and only ids from '
    '<routing_index> or a lookup result — or call ask_user, or '
    'reply_to_user if nothing can be placed.';

/// The header above the pending message in the wake's user turn.
const String frontPendingUserMessageHeader = '<pending_user_message>';
const String frontPendingUserMessageFooter = '</pending_user_message>';

/// The system prompt: the routing contract and nothing about tone. The
/// personality block is appended separately (slice 3 of the plan), so the
/// two never mix and a sass change leaves this prefix untouched.
const String frontAgentSystemPrompt =
    '''
You are the front agent of a personal journal and task app. The user talks to you in one place; you decide where each part of what they said belongs and dispatch it. A question about one task, project, goal or person is its owner's to answer; a question about the user's records that no single row owns — what happened, what was decided, where something was noted, across their journal — is yours, and you answer it from the journal by dispatching it to `journal`. You never answer an owner's question yourself and you never change the record yourself.

## What you see

- `<routing_index>`: every destination you may route to — open tasks, projects, active goals and tracked people — one row each: `kind:id | title | status | due | one-liner`. The one-liner says what the thing is about right now. A kind may say more exist than are shown.
- `<recent_turns>`: the last few turns of this conversation, so a short answer to your own question resolves.
- `<pending_user_message>`: what the user just said. Route this, and only this.

## How to decide

1. Match each part of the message to a row by name and by what the row is about. Confidence is yours to estimate: `>= $frontStrongConfidence` is a strong match, `$frontLowConfidence` to `$frontStrongConfidence` is low, below `$frontLowConfidence` is no match.
2. A strong, single match: dispatch it.
3. Two or more rows close together, or only a low match: call `ask_user` with the candidates. Do not dispatch and ask in the same turn.
4. A name you cannot see: for a task, call `match_to_corpus` once; for anything else, `ask_user`. Never invent an id. Closed tasks are not destinations; say so if the user names one.
5. Nothing matches above `$frontLowConfidence`: the part is `new` (say what it would become: task, goal or project), `journal` or `unrouted`. A `journal` question is answered from the journal — keep any category the user names in its span, it narrows the search; a `journal` statement is kept as a note.
6. A statement about a project is not routed to the project: ask which of its tasks it belongs to, or leave it unrouted.
7. "Today", "my day", moving or planning something today: destination `day`.

## The dispatch

Split the message into segments only where the destinations differ. Each segment names its span by character offsets into the pending message, verbatim; spans are in order and never overlap; together they cover the message. At most $frontMaxSegments segments. Each segment has an intent: `question` (the owner knows something), `statement` (something happened or is true), `instruction` (change something).

## Discipline

- One `read_tldr` and one `match_to_corpus` per turn at most; a turn that needs more is fishing. Decide from the index first.
- `dispatch`, `ask_user` and `reply_to_user` end the turn. Call exactly one of them, except that `reply_to_user` may accompany `dispatch` with one line about where things went.
- Keep every visible sentence short and in the user's language.
''';

/// The tools of the front agent's turn, in the order they are advertised.
/// The list never shrinks mid-conversation (prefix stability) and never
/// drops to one (a single tool makes DeepSeek rewrite `tool_choice`).
final List<AgentToolDefinition> frontAgentTools = [
  AgentToolDefinition(
    name: FrontAgentToolNames.dispatch,
    description:
        'End the turn with where every part of the pending user message '
        'belongs. Spans are character offsets into the pending message, in '
        'order, non-overlapping, covering it; ids come only from '
        '<routing_index> or a lookup result this turn.',
    parameters: {
      'type': 'object',
      'properties': {
        'segments': {
          'type': 'array',
          'minItems': 1,
          'maxItems': frontMaxSegments,
          'items': {
            'type': 'object',
            'properties': {
              'start': {
                'type': 'integer',
                'description': 'Offset of the first character of the span.',
              },
              'end': {
                'type': 'integer',
                'description': 'Offset one past the last character.',
              },
              'text': {
                'type': 'string',
                'description':
                    'The pending message between start and end, verbatim.',
              },
              'intent': {
                'type': 'string',
                'enum': [
                  for (final intent in FrontSegmentIntent.values) intent.name,
                ],
              },
              'destination': {
                'type': 'object',
                'properties': {
                  'kind': {
                    'type': 'string',
                    'enum': [
                      for (final kind in FrontDestinationKind.values)
                        kind.wireName,
                    ],
                  },
                  'id': {
                    'type': 'string',
                    'description':
                        'The owner id for task, project, goal or person, '
                        'exactly as listed.',
                  },
                  'newKind': {
                    'type': 'string',
                    'enum': [for (final kind in FrontNewKind.values) kind.name],
                    'description': 'For kind "new": what it would become.',
                  },
                },
                'required': ['kind'],
              },
              'confidence': {
                'type': 'number',
                'minimum': 0,
                'maximum': 1,
                'description': 'How sure you are of the destination.',
              },
              'note': {
                'type': 'string',
                'description':
                    'One short line you say about this segment, optional.',
              },
            },
            'required': [
              'start',
              'end',
              'text',
              'intent',
              'destination',
              'confidence',
            ],
          },
        },
      },
      'required': ['segments'],
    },
  ),
  const AgentToolDefinition(
    name: FrontAgentToolNames.readTldr,
    description:
        'Read the TL;DR of up to $frontTldrIdsPerRead listed destinations '
        'when their one-liners cannot be told apart. Once per turn.',
    parameters: {
      'type': 'object',
      'properties': {
        'ids': {
          'type': 'array',
          'minItems': 1,
          'maxItems': frontTldrIdsPerRead,
          'items': {
            'type': 'string',
            'description': 'A destination as listed, e.g. "task:<id>".',
          },
        },
      },
      'required': ['ids'],
    },
  ),
  const AgentToolDefinition(
    name: FrontAgentToolNames.matchToCorpus,
    description:
        'Find open tasks whose text matches a phrase, for a task name the '
        'index does not show. Closed tasks are never returned. Once per turn.',
    parameters: {
      'type': 'object',
      'properties': {
        'phrase': {
          'type': 'string',
          'description': 'The words the user used for the task.',
        },
      },
      'required': ['phrase'],
    },
  ),
  const AgentToolDefinition(
    name: FrontAgentToolNames.askUser,
    description:
        'End the turn with one short clarifying question and up to '
        '$frontAskUserMaxOptions candidate destinations as options.',
    parameters: {
      'type': 'object',
      'properties': {
        'question': {'type': 'string'},
        'options': {
          'type': 'array',
          'maxItems': frontAskUserMaxOptions,
          'items': {
            'type': 'object',
            'properties': {
              'kind': {'type': 'string'},
              'id': {'type': 'string'},
              'label': {
                'type': 'string',
                'description': 'The title as listed.',
              },
            },
            'required': ['kind', 'id', 'label'],
          },
        },
      },
      'required': ['question'],
    },
  ),
  const AgentToolDefinition(
    name: FrontAgentToolNames.replyToUser,
    description:
        'Say something in your own words: where things went, or that nothing '
        'could be placed. At most once per turn.',
    parameters: {
      'type': 'object',
      'properties': {
        'message': {'type': 'string'},
      },
      'required': ['message'],
    },
  ),
];
