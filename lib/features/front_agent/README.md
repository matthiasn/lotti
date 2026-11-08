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
and says it as text. She knows the categories by name: one
named in the question narrows the answer — there is nothing to pick. Two
tasks or more come back as a card of task rows — status, category, when it
is due — rather than a run of links. Every task
or project she names is a link that closes her and opens it, and every
answer is shown as the Markdown it was written in. A statement under a task or a project is a **proposal**: one tap
files the user's words verbatim as an entry under it, and only the tap
writes. A change to today ("move the count to the afternoon") is one too:
its tap takes the words into the Daily OS planning for today. A task the
user asks for ("make a task to fix the gate, high priority, I started ten
minutes ago") is the exception: she reads its title, instructions,
category, priority, due day, estimate and start from the words, and it is
made at once, started when they said so, with the words linked under it and
the category's agent assigned; she says she made it, and *Undo* takes it
back. The user keeps many **conversations** with her, as in a ChatGPT
or Claude window: each a subject of its own, titled by its first question,
listed newest first by recency behind the header's *Chats* button (beside
the conversation on a desktop window), renamed, archived or deleted there. What nothing owns waits in the **inbox** — every conversation,
filtered — with chips that make it a task, start a goal or project with
its words, or save it as a note, or leave it. Whatever a tap wrote can be
opened or undone,
and a proposal she got wrong goes to the inbox rather than being retyped.

## What it owns

- `model/` — the fixed identity (`front_agent`), the dispatch shape and its
  thresholds, the routing index and its caps, what a due-task list and a
  logged-time summary hold,
  the links her words name tasks and projects with
  (`front_reference_links.dart`), the door record, the thread
  projection the chat surface renders, and what a conversation is.
- `workflow/` — the tool contract and system prompt, the dispatch validator
  (the rules in code), the conversation strategy (count-and-refuse lookups,
  terminal calls, her words linked), the model resolution (its own setup, never a category's)
  and the wake workflow that persists the dispatch record.
- `service/` — the index builder over existing reads (and the due-task
  lister behind `list_due_tasks` and the logged-time summarizer behind
  `summarize_logged_time`), the singleton's lazy
  creation, the chat service that makes a user turn durable with a recovery
  record and runs the wake, the door walker, the owner titles, the thread
  builder that mirrors specialists' replies, the conversation service, and
  the filing service behind every tap under a door.
- `runtime/` — the maintenance hook that re-arms an unanswered turn's
  recovery on every device.
- `state/` — providers, the composer controller, the thread providers, the
  picked and active conversation, the spoken turn awaiting her spoken reply
  (`front_voice_providers.dart`), and the wake-runner,
  maintenance and
  setup-resolver contributions merged in `app_bootstrap.dart`.
- `ui/` — her header (her face, her name and the conversation's title, her
  voice's controls), the hero that greets a conversation not begun (her
  bust), the switch that mutes her (`front_voice_switch.dart`), the card her
  lists of tasks are drawn as (`front_task_list.dart`, over
  `model/front_reply_parts.dart`), her voice (`front_chat_voice.dart`: the spoken reply, when
  she may speak, the pose she holds), her voice's control and her stage
  (`front_voice_controls.dart`: stop her, or have her say her latest answer
  again from the start, in the voice she said it in; stand her up full
  screen on any form factor, the conversation beside her on a desktop
  window, where she points at the tasks she lists as she says them —
  `state/front_stage_pointing.dart`), what stands at her feet there
  (`front_stage_controls.dart`: hold the disc to talk to her, let go to
  send, drag off to cancel, or tap for hands free), the
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
