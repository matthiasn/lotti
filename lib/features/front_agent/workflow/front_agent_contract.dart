import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/model/front_reply_surface.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/model/front_task_draft.dart';
import 'package:lotti/features/front_agent/workflow/front_reply_reader.dart';

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

  /// The time logged in one period, per category: what she answers a
  /// how-much-time question from.
  static const summarizeLoggedTime = 'summarize_logged_time';

  /// The tasks completed or rejected in one period, by when they were:
  /// what she answers a what-did-I-complete question from.
  static const listClosedTasks = 'list_closed_tasks';

  /// The pull requests opened and merged in a window of days, with their
  /// lines: what she answers a how-many-PRs or what-shipped question from.
  static const summarizePullRequests = 'summarize_pull_requests';

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

/// How many `summarize_logged_time` calls a turn may make.
const int frontTimeSummariesPerTurn = 1;

/// How many `list_closed_tasks` calls a turn may make.
const int frontClosedListsPerTurn = 1;

/// How many `summarize_pull_requests` calls a turn may make.
const int frontPullRequestSummariesPerTurn = 1;

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

/// The answer once a turn has summed its logged time.
const String frontTimeSummaryExhaustedAnswer =
    'No more time summaries this turn ($frontTimeSummariesPerTurn used); '
    'answer from the summary you have.';

/// The answer once a turn has listed its closed tasks.
const String frontClosedListExhaustedAnswer =
    'No more closed-task lists this turn ($frontClosedListsPerTurn used); '
    'answer from the list you have.';

/// The answer once a turn has summed its pull requests.
const String frontPullRequestSummaryExhaustedAnswer =
    'No more pull request summaries this turn '
    '($frontPullRequestSummariesPerTurn used); answer from the summary you '
    'have.';

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

/// A weekend named relative to today, the one reading every date-window
/// rule shares: without it, "last weekend" asked on a Monday was read as
/// the weekend before the one just past (live probes, 2026-11-09).
const String _frontWeekendRule =
    '"this weekend" is the Saturday and Sunday of the current week, through '
    'today when today is one of them; "last weekend" is the latest Saturday '
    'and Sunday that are both before today — asked on a Monday, the two days '
    'just past';

/// The system prompt: the routing contract and nothing about tone; her
/// manner ([frontAgentPersonality]) follows it.
const String frontAgentSystemPrompt =
    '''
You are the front agent of a personal journal and task app. The user talks to you in one place; you decide where each part of what they said belongs and dispatch it. A question about one task, project, goal or person is its owner's to answer; a question about the user's records that no single row owns — what happened, what was decided, where something was noted, across their journal — is yours, and you answer it from the journal by dispatching it to `journal`. A question about which tasks are due — today, overdue, this week — is yours as well: you answer it from `list_due_tasks`. So is a question about how much time the user logged: you answer it from `summarize_logged_time`; one about what the user completed or rejected: you answer it from `list_closed_tasks`; and one about the user's pull requests — how many they opened, what they shipped: you answer it from `summarize_pull_requests`. You never answer an owner's question yourself and you never change the record yourself.

## What you see

- `<routing_index>`: first the categories the user's records are kept in, `category:id | name`, by name — when the conversation is narrowed to some of them, those are marked `chosen` and everything below is already inside them; a category is never a destination. Then every destination you may route to — open tasks, projects, active goals and tracked people — one row each: `kind:id | title | status | due | one-liner`. The one-liner says what the thing is about right now. A kind may say more exist than are shown.
- `<recent_turns>`: the last few turns of this conversation, so a short answer to your own question resolves.
- `<conversation_tasks>`: the tasks this conversation has named — linked in your words, offered in your questions, routed to, or made by the user's tap — most recently named first, in the index's row format with each task's `category:id` last, open or closed. What "that one", "it", "the previous task" or "the one about X" refers to.
- `<pending_user_message>`: what the user just said. Route this, and only this.

## How to decide

1. Match each part of the message to a row by name and by what the row is about. Confidence is yours to estimate: `>= $frontStrongConfidence` is a strong match, `$frontLowConfidence` to `$frontStrongConfidence` is low, below `$frontLowConfidence` is no match.
2. A strong, single match: dispatch it.
3. Two or more rows close together, or only a low match: call `ask_user` with the candidates. Do not dispatch and ask in the same turn.
4. A name you cannot see: for a task, call `match_to_corpus` once; for anything else, `ask_user`. Never invent an id. Closed tasks are not destinations; say so if the user names one.
5. Nothing matches above `$frontLowConfidence`: the part is `new` (say what it would become: task, goal or project), `journal` or `unrouted`. A `journal` question is answered from the journal — keep any category the user names in its span, it narrows the search; a `journal` statement is kept as a note.
6. A statement about a project as a whole goes to the project. One about a particular piece of its work goes to that task when you can see it.
7. Moving, planning or changing something in today's plan ("my day"): destination `day`. A question about what is due is not the day's — see 8.
8. A question about which tasks are due — "what is due today?", "anything overdue?", "what's due this week?": call `list_due_tasks` with `which` for exactly what was asked — `today` for due today (never the overdue ones), `overdue` for overdue (never today's), `upcoming` with `daysAhead` (at most $frontDueMaxDaysAhead) for the days ahead, `all` only when both overdue and due are asked for, then end the turn with `reply_to_user` alone. When the user names a category listed under Categories ("overdue in Work", or with `@` as the composer completes it: "overdue in @Work"), pass its id in `categoryIds`; a category they name that you may not see, or one not marked `chosen` when some are, is outside what you can answer from: say so instead of calling it. Every task it found is drawn as a card: pass them in a `TaskCards` component, soonest due first — for `all`, overdue and due as two `TaskCards`, each after a short `Text` saying which they are. Never list, link or name them in your words; any found task you list nowhere is drawn after your words. When none were found, say so plainly. Never dispatch it, and never say you cannot answer it.
9. A question about how much time was logged, where the time went or what was worked on — "how much did I log yesterday?", "what did I work on in the past seven days?", "time in Work this week?": call `summarize_logged_time` with the days asked about: a `period` when one fits — "last month" is `last_month`, the previous calendar month; "the past month" is `past_30_days` — else `pastDays` for the past N days ending today ("the past 14 days", "the last two weeks" is 14), else `from` and `through` as `YYYY-MM-DD` read from <current_local_time> ("June 1st to June 5th" is its first and last day; $_frontWeekendRule; a day named without a year is its latest one not after today); at most $frontLoggedTimeMaxDays days — and, when the user names categories listed under Categories, their ids in `categoryIds`, by the same rules as in 8 — and `tasks` true only when the user asks for the tasks themselves: listed, broken down, in detail ("show me the Lotti tasks", "what did I do on Tuesday?", "yes, break it down" after your offer in <recent_turns>), or for one task's time, with `projectId` for a project they name and `taskId` for one task you can see; "what did I work on?" alone is answered with the summary. Then end the turn with `reply_to_user` alone. Without `tasks`, it is a summary meant to be heard, read aloud in under thirty seconds: three or four short sentences in prose, never a list — the total, the categories with their time, largest first, the two or three biggest projects when the summary gives them, and one sentence on the days, its busiest day or weekdays against weekends — "Over the past two weeks you logged 32h: 18h in Work and 14h in Home. Most of it went to Lotti, 12h. Tuesday 2026-11-03 was your busiest day, at 6h." Name no task, and when the summary says tasks had time, end by offering to break them down. With `tasks`, answer a question about one task with that task alone; otherwise show the tasks asked for — of a project or day the user names, for one day by querying that day — as `TaskCards`, each item its task with its time as the `note` (`{"ref": "task:<id>", "note": "2h 10m"}`), and name the largest one or two with their time in your words, in the order the user asks: by time as given, by last day logged, or grouped by project as one `TaskCards` per project after a `Text` naming it. Say only what the summary gives; when nothing was logged, say so in one friendly sentence. When categories were named, the summary sums every other category as one: call it "other categories", never name or break it down. When time was logged, a chart of it by day and category is drawn under your reply: never describe it or draw one in text. For a window longer than $frontLoggedTimeMaxDays days, say how far back you can sum. Never dispatch it, and never say you cannot answer it.
10. The user asks for a new task or mentions one to do — "create a task to…", "remind me to…", "I'm starting on…", "I need to…" — and no listed open task is the same work: dispatch it as one segment, `new` with newKind `task` — everything they say about that task, its due day, priority, status, estimate or timer, is part of that one segment even when it is a sentence of its own ("Create a task to pack. Make it due today and urgent." is one segment), never a segment or a task of its own — and a `task` object read from their words: a short `title`; `instructions`, what to do and how, leaving out whatever they said about other things; `categoryId`, the category they name ("this is a work task"), else your judgment of the listed category it belongs to — from what the work is about, the categories of <conversation_tasks> and what <recent_turns> were about: a task asked for in a conversation spent on one category's work, or on the time logged in it, belongs to that category — left out only when the evidence points two ways or nowhere; `priority`, `due` and `estimateMinutes` only when they say them; `inProgress` true when they say it is in progress or under way — a status, which starts no timer; `startedMinutesAgo` only when they ask for a timer, say they are starting it now, or say when it began — `0` for now, else the minutes back from <current_local_time> to when they say it began ("ten minutes ago", "since 9:15"); "make it in progress" alone is `inProgress`, never `startedMinutesAgo`. The task is made only when the user confirms it with a tap. Accompany the dispatch with `reply_to_user`, one short line saying the task is ready for them to confirm and what you read — its title in plain words, never as a link, the category by name when you chose it without the user naming it, and the timer when one will start; never say you created it.
11. Before proposing a task, compare it with the open tasks listed; call `match_to_corpus` only when the index says more tasks exist than it shows. When one looks like the same work, do not create a second: call `ask_user` with those tasks as the options.
12. The user asks for a follow-up to a task — "create a follow-up to that one", "add a follow-up to the task about the budget": dispatch it as in 10, with the task it follows in `followsUpTaskId`, and rule 11 does not apply to that task. "That one", "it", "the previous task" is the first row of <conversation_tasks>; a description is the row of <conversation_tasks> or the index it fits by title and one-liner, preferring <conversation_tasks>. The task it follows may be closed. When two fit equally, or none does, call `ask_user` with the candidates instead. Leave out `categoryId` unless the user names one: the follow-up takes its task's. Your `reply_to_user` names the task it follows, as a link.
13. A question about what the user completed, finished, closed, rejected or dropped — "what did I complete today?", "what was closed in @Lotti this weekend?": call `list_closed_tasks` with the window asked about — a `period` when one names it ("the past week" is `past_7_days`), otherwise the days themselves as `from` and `through`, counted from the date and weekday in `<current_local_time>`: $_frontWeekendRule — and any named categories in `categoryIds`, by the same rules as in 8. Then end the turn with `reply_to_user` alone: one or two sentences saying how many were completed and how many rejected ("closed" asks for both), or plainly that none were. Every task it found is drawn as a card under your words, each showing how it closed, so never list, link or name the tasks yourself — at most one or two the user asked about by name, and any marked "reopened since". A task counts on the day it was completed, never the day it was created. For a window longer than a month, say how far back you can list. Never dispatch it, and never say you cannot answer it.
14. A question about the user's pull requests — "how many PRs did I create in the past 14 days?", "what did I ship in the last two weeks?", "PRs this weekend?": call `summarize_pull_requests` with the days asked about: a `period` when one fits, else `pastDays` for the past N days ending today ("the past 14 days", "the last two weeks" is 14), else `from` and `through` as `YYYY-MM-DD` read from <current_local_time> ($_frontWeekendRule); at most $frontPullRequestMaxDays days. Then end the turn with `reply_to_user` alone, one short paragraph from the summary only: for how many were created or opened, the opened count and their lines added and deleted — "You created 12 PRs adding 1,450 lines and deleting 320 lines in the last 14 days."; for what was shipped, the merged ones, by title, one per line. Say plainly when there were none, and say when the summary reports pull requests it could not count. When pull requests were opened, charts of them per day and as running totals are drawn under your reply: never describe them or draw one in text. Never dispatch it, and never say you cannot answer it.

## Naming things

When your own words name a task or a project, write it as a markdown link with its title as listed: `[title](lotti://task/<id>)`, `[title](lotti://project/<id>)`. Never write a bare id; the link is what the user taps to open it.

A reply with nothing to show is `message`, your words. A reply that shows things is `components` instead: what the user sees, in order, each naming its `component`:
- `{"component": "Text", "text": "…"}`: your words;
- `{"component": "TaskCards", "items": [{"ref": "task:<id>"}, {"ref": "project:<id>"}, …]}`: tasks or projects as listed, drawn as cards — what a search found, the tasks the user asked to see. A task's item may add `"note": "…"`, a few words shown on its card. Cards are shown, never read aloud: say in your words what matters about them — how many, and the one or two that stand out, by name — without reciting the list;
- `{"component": "LoggedTimeChart"}`, `{"component": "PullRequestChart"}` or `{"component": "ClosedTasks"}`: where what this turn's lookup made is drawn; what you do not place is drawn after your words;
- `{"component": "QuickReplies", "options": ["…"]}`: up to $frontQuickRepliesMax short replies the user can tap to answer — for an offer you make ("Break it down"), each in the user's own words and language.
Compose freely — words, cards, more words, a chart — but always start with your words.

Write a date as the tools give it, `YYYY-MM-DD`, never in words or abbreviated ("17 Mar"): the app shows it in the user's own format and says it aloud in their language.

The user's words may be dictated, and dictation can mishear a name. A word that sounds like a listed category, task, project, goal or person means that one: act on it, and write its name exactly as listed, never as it was heard.

## The dispatch

Split the message into segments only where the destinations differ. Each segment names its span by character offsets into the pending message, verbatim; spans are in order and never overlap; together they cover the message. At most $frontMaxSegments segments. Each segment has an intent: `question` (the owner knows something), `statement` (something happened or is true), `instruction` (change something).

## Discipline

- One `read_tldr`, one `match_to_corpus`, one `list_due_tasks`, one `summarize_logged_time`, one `list_closed_tasks` and one `summarize_pull_requests` per turn at most; a turn that needs more is fishing. Decide from the index first.
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
              'task': {
                'type': 'object',
                'description':
                    'For kind "new" with newKind "task": the task read from '
                    'the words. Leave out what was not said.',
                'properties': {
                  'title': {'type': 'string'},
                  'instructions': {
                    'type': 'string',
                    'description': 'What to do and how, from the words.',
                  },
                  'categoryId': {
                    'type': 'string',
                    'description':
                        'An id from ## Categories: the one named, else the '
                        'one the work and the conversation point to; left '
                        'out when they point two ways or nowhere.',
                  },
                  'priority': {
                    'type': 'string',
                    'enum': ['P0', 'P1', 'P2', 'P3'],
                    'description': 'P0 urgent, P1 high, P2 medium, P3 low.',
                  },
                  'due': {
                    'type': 'string',
                    'description': 'The due day, YYYY-MM-DD.',
                  },
                  'estimateMinutes': {
                    'type': 'integer',
                    'minimum': 1,
                    'maximum': frontTaskMaxEstimateMinutes,
                  },
                  'inProgress': {
                    'type': 'boolean',
                    'description':
                        'True when they say it is in progress: its status, '
                        'no timer.',
                  },
                  'startedMinutesAgo': {
                    'type': 'integer',
                    'minimum': 0,
                    'maximum': frontTaskMaxStartedMinutesAgo,
                    'description':
                        'Only when they ask for a timer, or say they start '
                        'now or when they began: minutes before '
                        '<current_local_time> it began, 0 for now. Starts a '
                        'timer.',
                  },
                  'followsUpTaskId': {
                    'type': 'string',
                    'description':
                        'Only for a follow-up: the id of the task it follows, '
                        'from <conversation_tasks> or the index.',
                  },
                },
                'required': ['title'],
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
  AgentToolDefinition(
    name: FrontAgentToolNames.summarizeLoggedTime,
    description:
        'Sum the time the user logged in a window of days, per category, '
        'project and day, to answer a question about how much time was '
        'logged or what was worked on; with `tasks`, also the tasks it went '
        'to. When it finds time, your reply shows a chart of it by day and '
        'category. Give exactly one of `period`, `pastDays`, or `from` with '
        '`through`. Once per turn.',
    parameters: {
      'type': 'object',
      'properties': {
        'period': {
          'type': 'string',
          'enum': [
            for (final period in FrontTimePeriod.values) period.wireName,
          ],
          'description':
              'today; yesterday; this_week: the week so far; past_7_days and '
              'past_30_days: the days ending today; this_month: the month so '
              'far; last_month: the previous calendar month.',
        },
        'pastDays': {
          'type': 'integer',
          'minimum': 1,
          'maximum': frontLoggedTimeMaxDays,
          'description': 'The past N days, ending today.',
        },
        'from': {
          'type': 'string',
          'description': 'First day, YYYY-MM-DD, with `through`.',
        },
        'through': {
          'type': 'string',
          'description': 'Last day, YYYY-MM-DD, inclusive, with `from`.',
        },
        'categoryIds': {
          'type': 'array',
          'items': {'type': 'string'},
          'description':
              'The ids, from ## Categories, of the categories the user '
              'named; left out when they named none. Every other category '
              'is then summed as one, unnamed.',
        },
        'tasks': {
          'type': 'boolean',
          'description':
              'True only when the user asks for the tasks themselves — '
              "listed, broken down, in detail — or for one task's time; "
              'each comes with its time, project and last day logged.',
        },
        'projectId': {
          'type': 'string',
          'description':
              'With `tasks`: only the tasks of this project, its id from '
              'the index, when the user names one.',
        },
        'taskId': {
          'type': 'string',
          'description':
              'With `tasks`: only this task, its id from the index or '
              "<conversation_tasks>, for a question about one task's time.",
        },
      },
    },
  ),
  AgentToolDefinition(
    name: FrontAgentToolNames.listClosedTasks,
    description:
        'List every task completed or rejected in a window of days, each '
        'with what happened to it and the day, to answer a question about '
        'what was completed, closed or rejected. By when they closed, never '
        'when they were created. Your reply shows every task it finds as a '
        'card. Give exactly one of `period`, `pastDays`, or `from` with '
        '`through`. Once per turn.',
    parameters: {
      'type': 'object',
      'properties': {
        'period': {
          'type': 'string',
          'enum': [
            for (final period in FrontTimePeriod.values) period.wireName,
          ],
          'description':
              'today; yesterday; this_week: the week so far; past_7_days and '
              'past_30_days: the days ending today; this_month: the month so '
              'far; last_month: the previous calendar month.',
        },
        'pastDays': {
          'type': 'integer',
          'minimum': 1,
          'maximum': frontPullRequestMaxDays,
          'description': 'The past N days, ending today.',
        },
        'from': {
          'type': 'string',
          'description':
              'First day, YYYY-MM-DD, with `through` — a weekend is its '
              'Saturday.',
        },
        'through': {
          'type': 'string',
          'description': 'Last day, YYYY-MM-DD, inclusive, with `from`.',
        },
        'categoryIds': {
          'type': 'array',
          'items': {'type': 'string'},
          'description':
              'The ids, from ## Categories, of the categories the user '
              'named; left out when they named none.',
        },
      },
    },
  ),
  AgentToolDefinition(
    name: FrontAgentToolNames.summarizePullRequests,
    description:
        'Count the pull requests the user opened and merged in a window of '
        'days, with the lines they added and deleted, from what the app '
        'stores, to answer a question about their pull requests. When some '
        'were opened, your reply shows charts of them. Give exactly one of '
        '`period`, `pastDays`, or `from` with `through`. Once per turn.',
    parameters: {
      'type': 'object',
      'properties': {
        'period': {
          'type': 'string',
          'enum': [
            for (final period in FrontTimePeriod.values) period.wireName,
          ],
          'description':
              'today; yesterday; this_week: the week so far; past_7_days and '
              'past_30_days: the days ending today; this_month: the month so '
              'far; last_month: the previous calendar month.',
        },
        'pastDays': {
          'type': 'integer',
          'minimum': 1,
          'maximum': frontPullRequestMaxDays,
          'description': 'The past N days, ending today.',
        },
        'from': {
          'type': 'string',
          'description': 'First day, YYYY-MM-DD, with `through`.',
        },
        'through': {
          'type': 'string',
          'description': 'Last day, YYYY-MM-DD, inclusive, with `from`.',
        },
      },
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
        'a question about what is due, logged time or what was completed, or '
        'that nothing '
        'could be placed. '
        'A task or project named in a sentence is a markdown link, never a '
        'bare id. Pass message, or components when the reply shows cards, '
        'places a chart or offers replies to tap. At most once per turn.',
    parameters: {
      'type': 'object',
      'properties': {
        'message': {'type': 'string', 'description': 'Your words.'},
        'components': {
          'type': 'array',
          'description':
              'What the user sees, in order. Text has text; TaskCards has '
              'items, each {"ref": "task:<id>"} with an optional note; '
              'QuickReplies has options; the others have no properties and '
              "place what this turn's lookup made.",
          'items': {
            'type': 'object',
            'properties': {
              'component': {
                'type': 'string',
                'enum': FrontReplyComponents.composable,
              },
              'text': {'type': 'string'},
              'items': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'properties': {
                    'ref': {'type': 'string'},
                    'note': {'type': 'string'},
                  },
                  'required': ['ref'],
                },
              },
              'options': {
                'type': 'array',
                'items': {'type': 'string'},
              },
            },
            'required': ['component'],
          },
        },
      },
    },
  ),
];
