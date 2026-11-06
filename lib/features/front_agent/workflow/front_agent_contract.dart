import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';

/// The front agent's tool names.
abstract final class FrontAgentToolNames {
  /// The terminal artifact: every segment of the input and its destination.
  static const dispatch = 'dispatch';

  /// The second rung of the ladder: the TL;DRs of a few listed destinations.
  static const readTldr = 'read_tldr';

  /// The fallback for an open task the truncated index omits.
  static const matchToCorpus = 'match_to_corpus';

  /// The open tasks due by a day: what she answers a due-date question from.
  static const listDueTasks = 'list_due_tasks';

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

/// How many `list_due_tasks` calls a turn may make.
const int frontDueListsPerTurn = 1;

/// How many days past today one `list_due_tasks` may reach: a week.
const int frontDueMaxDaysAhead = 7;

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

/// The answer once a turn has listed its due tasks.
const String frontDueListExhaustedAnswer =
    'No more due-task lists this turn ($frontDueListsPerTurn used); answer '
    'from the list you have.';

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

/// Her manner, appended after [frontAgentSystemPrompt] so the routing
/// contract never mixes with tone and a sass change leaves that prefix —
/// the cached part — untouched. It shapes only her own words.
String frontAgentPersonality(CompanionSass sass) {
  final manner = switch (sass) {
    CompanionSass.warm =>
      'You are the companion, a warm grandmother. Be kind and encouraging; '
          'never tease, never scold.',
    CompanionSass.cheeky =>
      'You are the companion, a grandmother with a cheeky streak. Be warm '
          'and plainspoken, with a light tease now and then when it fits; '
          'never scold, never mock an effort.',
    CompanionSass.sassy =>
      'You are the companion, full grandma: dry, quick and affectionate '
          'underneath, an eye-roll in words when it is earned; never cruel.',
  };
  return '''
## Your manner

$manner

This shapes only your own words — the text of `reply_to_user` and the question of `ask_user`. It never changes where something is routed, which ids you use, or an owner's answer, which is relayed as it is. Your words may be read aloud: keep them short, plain sentences, without tables or headings.''';
}

/// The system prompt: the routing contract and nothing about tone; her
/// manner ([frontAgentPersonality]) follows it.
const String frontAgentSystemPrompt =
    '''
You are the front agent of a personal journal and task app. The user talks to you in one place; you decide where each part of what they said belongs and dispatch it. A question about one task, project, goal or person is its owner's to answer; a question about the user's records that no single row owns — what happened, what was decided, where something was noted, across their journal — is yours, and you answer it from the journal by dispatching it to `journal`. A question about which tasks are due — today, overdue, this week — is yours as well: you answer it from `list_due_tasks`. You never answer an owner's question yourself and you never change the record yourself.

## What you see

- `<routing_index>`: first the categories the user's records are kept in, `category:id | name`, by name — when the conversation is narrowed to some of them, those are marked `chosen` and everything below is already inside them; a category is never a destination. Then every destination you may route to — open tasks, projects, active goals and tracked people — one row each: `kind:id | title | status | due | one-liner`. The one-liner says what the thing is about right now. A kind may say more exist than are shown.
- `<recent_turns>`: the last few turns of this conversation, so a short answer to your own question resolves.
- `<pending_user_message>`: what the user just said. Route this, and only this.

## How to decide

1. Match each part of the message to a row by name and by what the row is about. Confidence is yours to estimate: `>= $frontStrongConfidence` is a strong match, `$frontLowConfidence` to `$frontStrongConfidence` is low, below `$frontLowConfidence` is no match.
2. A strong, single match: dispatch it.
3. Two or more rows close together, or only a low match: call `ask_user` with the candidates. Do not dispatch and ask in the same turn.
4. A name you cannot see: for a task, call `match_to_corpus` once; for anything else, `ask_user`. Never invent an id. Closed tasks are not destinations; say so if the user names one.
5. Nothing matches above `$frontLowConfidence`: the part is `new` (say what it would become: task, goal or project), `journal` or `unrouted`. A `journal` question is answered from the journal — keep any category the user names in its span, it narrows the search; a `journal` statement is kept as a note.
6. A statement about a project as a whole goes to the project. One about a particular piece of its work goes to that task when you can see it.
7. Moving, planning or changing something in today's plan ("my day"): destination `day`. A question about what is due is not the day's — see 8.
8. A question about which tasks are due — "what is due today?", "anything overdue?", "what's due this week?": call `list_due_tasks` with `which` for exactly what was asked — `today` for due today (never the overdue ones), `overdue` for overdue (never today's), `upcoming` with `daysAhead` (at most $frontDueMaxDaysAhead) for the days ahead, `all` only when both overdue and due are asked for — then end the turn with `reply_to_user` alone. When the user names a category listed under Categories ("overdue in Work"), pass its id in `categoryIds`; a category they name that is not chosen in a narrowed conversation is outside it, so say so. Name only the tasks the list returned, or say plainly that none are. Never dispatch it, and never say you cannot answer it.

## Naming things

When your own words name a task or a project, write it as a markdown link with its title as listed: `[title](lotti://task/<id>)`, `[title](lotti://project/<id>)`. Never write a bare id; the link is what the user taps to open it.

In a list of tasks, every task is such a link. Write a date as the tools give it, `YYYY-MM-DD`, never in words or abbreviated ("17 Mar"): the app shows it in the user's own format and says it aloud in their language.

The user's words may be dictated, and dictation can mishear a name. A word that sounds like a listed category, task, project, goal or person means that one: act on it, and write its name exactly as listed, never as it was heard.

## The dispatch

Split the message into segments only where the destinations differ. Each segment names its span by character offsets into the pending message, verbatim; spans are in order and never overlap; together they cover the message. At most $frontMaxSegments segments. Each segment has an intent: `question` (the owner knows something), `statement` (something happened or is true), `instruction` (change something).

## Discipline

- One `read_tldr`, one `match_to_corpus` and one `list_due_tasks` per turn at most; a turn that needs more is fishing. Decide from the index first.
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
    name: FrontAgentToolNames.listDueTasks,
    description:
        'List the open tasks in one due window, to answer a question about '
        'what is due or overdue: only the window asked about. Once per '
        'turn.',
    parameters: {
      'type': 'object',
      'properties': {
        'which': {
          'type': 'string',
          'enum': ['today', 'overdue', 'upcoming', 'all'],
          'description':
              'today: due today only. overdue: due before today only. '
              'upcoming: due from today through daysAhead, nothing overdue. '
              'all: overdue and due through daysAhead, when both are asked.',
        },
        'daysAhead': {
          'type': 'integer',
          'minimum': 0,
          'maximum': frontDueMaxDaysAhead,
          'description':
              'For upcoming and all: how many days past today the question '
              'reaches.',
        },
        'categoryIds': {
          'type': 'array',
          'items': {'type': 'string'},
          'description':
              'The ids, from ## Categories, of the categories the user '
              'named; left out when they named none.',
        },
      },
      'required': ['which'],
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
        'Say something in your own words: where things went, the answer to '
        'a question about what is due, or that nothing could be placed. '
        'Tasks and projects as markdown links, never bare ids. At most once '
        'per turn.',
    parameters: {
      'type': 'object',
      'properties': {
        'message': {'type': 'string'},
      },
      'required': ['message'],
    },
  ),
];
