# Front agent

Status: slices 0–2, and slices A, B, C1 and C2 of the voice-first plan
(`docs/implementation_plans/2026-10-31_voice_first_front_agent.md`): she
answers from the journal, the user keeps many conversations with her, a
question asked aloud is answered aloud, and she has a surface of her own over
the app. Behind the `enable_front_agent` flag in Advanced
settings.

The front agent is the one agent the user talks to in one place. It does not
answer for an owner and it never changes the record: it reads a bounded index
of what exists — open tasks, projects, active goals and, when opted in,
people — and decides where each part of what the user said belongs. Its one
artifact is a **dispatch**: ordered, verbatim spans of the input, each with a
destination, a confidence and an intent. A question with up to three
candidates, or a one-line reply, are the only other ways a turn can end.

After the dispatch, the **door walker** takes each segment to its owner: a
task or project question runs the owner's query pipeline headless and the
answer comes back attributed to the owner; a goal or person turn, question
or statement, becomes a turn in that agent's own chat, whose reply the front
thread mirrors. The user sees each answer under the name of the agent that
gave it, never reworded. A question about their records that no single owner
holds — what was decided, where something was noted — she answers herself
from the journal, within the categories she may see (a category named in the
question narrows it), with the passages she relied on, each opening its
source. A question about what is due — today, overdue, this week — is
hers too: she reads only what was asked (due today is never mixed with
overdue) and answers in her own words. So is how much time was logged —
today, yesterday, this week, the past 7 or 30 days, this month or last
month: she sums it per category, with the numbers the Insights page shows,
and says it as text, with the tasks the time went to when asked what was
worked on, and for a week the category most of it went to. A category named
in the question is the only one named, in her words and in the chart; every
other one is a single "other" slice. So is what was completed or
rejected — today, this week, the past 7 days and the other periods she can
sum: each task counts on the day it was completed or rejected, never the
day it was created, and a task reopened and finished again on its latest
completion. She knows the categories by name: one
named in the question narrows the answer — there is nothing to pick. Two
tasks or more — due, overdue, both, or what a search found, projects among
them — come back as preview cards — a task's cover or status, the agent's
one-liner, category, when it is due, its estimate and priority; a project as
the Projects list draws it — rather than a run of links, and an answer about what is due puts a
quiet label over them saying which window she read (*Due today*,
*Overdue*, *Due through …*), taken from the call she made, never from her
words. A
task she names opens on top of her, and back returns to the conversation; a
project she names closes her and opens it. Every
answer is shown as the Markdown it was written in. A statement under a task or a project is a **proposal**: one tap
files the user's words verbatim as an entry under it, and only the tap
writes. A change to today ("move the count to the afternoon") is one too:
its tap takes the words into the Daily OS planning for today. A task the
user dictates ("make a task to fix the gate, high priority, I started ten
minutes ago") waits for its tap too, but filled in: she reads its title,
instructions, category, priority, due day, estimate and start from the
words and says what she read, and *Make it a task* makes it with them —
started only when they said so — with the words linked under it and the
category's agent assigned. A follow-up ("a follow-up to that one") names
the task it follows — any task the conversation named, finished ones too —
and the tap links the two as *follows up on*. The user keeps many **conversations** with her, as in a ChatGPT
or Claude window: each a subject of its own, titled by its first question,
listed newest first by recency behind the header's *Chats* glyph (beside
the conversation on a desktop window), renamed, archived or deleted there. What nothing owns waits in the **inbox** — every conversation,
filtered — with chips that make it a task, start a goal or project with
its words, make it an event titled with them, or save it as a note, or
leave it. What a tap made is drawn under her reply as a **preview card**,
read live so it follows the thing: a task as the same compact card, which
her words do not list again; an event as the event card the app draws
wherever an event is linked; a project as the Projects list's row; a day
replanned through her as that day's blocks — when each runs, what it is
for, the done ones ticked. A person she hands words to is drawn as the
People list's row for them. A long press on a task's card (a secondary
click on desktop) offers *Change status…*, *Reschedule…* and *Move to
project…*, through the pickers the task's own page opens. Whatever a
tap wrote can be
opened or undone,
and a proposal she got wrong goes to the inbox rather than being retyped.

## What it owns

- `model/` — the fixed identity (`front_agent`), the dispatch shape and its
  thresholds, the routing index and its caps, what a due-task list, a
  logged-time summary, a closed-task list and a pull request count hold,
  the links her words name tasks and projects with
  (`front_reference_links.dart`), the door record, the thread
  projection the chat surface renders, which entity a preview card is of
  and what it shows (`front_entity_preview.dart`), and what a conversation
  is.
- `workflow/` — the tool contract and system prompt, the dispatch validator
  (the rules in code), the conversation strategy (count-and-refuse lookups,
  terminal calls, her words linked), the model resolution (its own setup, never a category's)
  and the wake workflow that persists the dispatch record.
- `service/` — the index builder over existing reads (and the due-task
  lister behind `list_due_tasks`, the logged-time summarizer behind
  `summarize_logged_time`, whose read her reply's chart of logged time
  shares, the closed-task lister behind `list_closed_tasks`, whose every
  task her reply draws as a card, and the pull
  request counter behind `summarize_pull_requests`, which reads only the
  pull requests the device stores and whose read her reply's charts of
  them share), the
  singleton's lazy
  creation, the chat service that makes a user turn durable with a recovery
  record and runs the wake, the door walker, the owner titles, the thread
  builder that mirrors specialists' replies, the conversation service, and
  the filing service behind every tap under a door.
- `runtime/` — the maintenance hook that re-arms an unanswered turn's
  recovery on every device.
- `state/` — providers, the composer controller, the thread providers, the
  live preview a card reads (`front_entity_preview_provider.dart`), the
  picked and active conversation, the spoken turn awaiting her spoken reply
  (`front_voice_providers.dart`), and the wake-runner,
  maintenance and
  setup-resolver contributions merged in `app_bootstrap.dart`.
- `ui/` — her header (her face in a rounded tile, whose tap shows her glass
  card over the thread in place and which steps aside while the card is out;
  her name and the conversation's title, her voice's controls), the hero that greets a conversation not begun (her
  bust), the switch that mutes her (`front_voice_switch.dart`), the card of
  rows a closed-task answer is drawn as (`front_task_list.dart`), the preview
  cards her lists of tasks and what her turn made are drawn as
  (`front_entity_preview_card.dart`, her lists cut from her words by
  `model/front_reply_parts.dart`, the window over a due list in
  `model/front_due_section.dart`), her voice (`front_chat_voice.dart`: the spoken reply, when
  she may speak, the pose she holds), her voice's control
  (`front_voice_controls.dart`: stop her, or have her say her latest answer
  again from the start, in the voice she said it in), her card
  (`FrontCompanionCard` in `front_chat_hero.dart`: her, head to toe, in a
  glass card floating over the thread, moved and resized by the user,
  pointing at the tasks she lists as she says them
  (`state/front_stage_pointing.dart`)),
  the
  list of conversations with each one's ⋯ on the agent pages' shared menu
  (`front_conversation_actions.dart`), her AI profile choice (`front_profile_choice.dart`: the
  profile she thinks with, whose read-aloud model is her voice), the door
  card with its proposals and inbox chips, the
  clarifying chips, the per-turn cost line, the pane on the shared
  `AgentChatView`, and her surface over the app (`front_chat_surface.dart`)
  that the sidebar row, the phone launcher button and the keyboard command
  open.

## What it delegates

The open-task corpus and the phrase match are `features/agents`
(`open_task_corpus.dart`), shared with the Daily OS day agent. Reports,
one-liners and TL;DRs are the owner agents'. Answers are theirs too: the
query pipeline (`features/agents/query`) for tasks and projects, the goal
and relationship chat services for goals and people. Filing writes through
the journal's own entry and task creation; the goal wizard and the project
form open with the user's words in them. A change to today goes to the Daily
OS planning (`features/daily_os_next`), which proposes the change and asks
before it touches the plan. What she hears is transcribed on the Settings
default profile's transcription slot (`features/ai`,
`settingsDefaultDictationTargetProvider`), the words as heard. Her voice is the shared read-aloud
(`features/tts`) and the companion's lip-synced bust (`features/companion`).

The decisions and the slices are in
[the implementation plan](../../../docs/implementation_plans/2026-10-23_single_agent_entry_point.md);
how a turn actually runs is in
[the front agent concept](../../../knowledge/features/front_agent.md).
