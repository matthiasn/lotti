# Front agent

Status: slices 0–2, and the first slice of the voice-first plan
(`docs/implementation_plans/2026-10-31_voice_first_front_agent.md`): she
answers from the journal. Behind the `enable_front_agent` flag in Advanced
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
source. A statement under a task is a **proposal**: one tap
files the user's words verbatim as an entry under the task, and only the
tap writes. What nothing owns waits in the **inbox** — the same thread,
filtered — with chips that make it a task, start a goal or project, or save
it as a note, or leave it. Whatever a tap wrote can be opened or undone,
and a proposal she got wrong goes to the inbox rather than being retyped.

## What it owns

- `model/` — the fixed identity (`front_agent`), the dispatch shape and its
  thresholds, the routing index and its caps, the door record, and the
  thread projection the chat surface renders.
- `workflow/` — the tool contract and system prompt, the dispatch validator
  (the rules in code), the conversation strategy (count-and-refuse lookups,
  terminal calls), the model resolution (its own setup, never a category's)
  and the wake workflow that persists the dispatch record.
- `service/` — the index builder over existing reads, the singleton's lazy
  creation, the chat service that makes a user turn durable with a recovery
  record and runs the wake, the door walker, the owner titles, the thread
  builder that mirrors specialists' replies, and the filing service behind
  every tap under a door.
- `runtime/` — the maintenance hook that re-arms an unanswered turn's
  recovery on every device.
- `state/` — providers, the composer controller, the thread provider, and
  the wake-runner, maintenance and setup-resolver contributions merged in
  `app_bootstrap.dart`.
- `ui/` — her header with the inbox chip, the door card with its proposals
  and inbox chips, the clarifying chips, the per-turn cost line, the pane on
  the shared `AgentChatView`, and the app-shell sheet the sidebar row, the
  phone launcher button and the keyboard command open.

## What it delegates

The open-task corpus and the phrase match are `features/agents`
(`open_task_corpus.dart`), shared with the Daily OS day agent. Reports,
one-liners and TL;DRs are the owner agents'. Answers are theirs too: the
query pipeline (`features/agents/query`) for tasks and projects, the goal
and relationship chat services for goals and people. Filing writes through
the journal's own entry and task creation; the goal and project wizards open
as they are. The Daily OS door and the spoken replies are later slices.

The decisions and the slices are in
[the implementation plan](../../../docs/implementation_plans/2026-10-23_single_agent_entry_point.md);
how a turn actually runs is in
[the front agent concept](../../../knowledge/features/front_agent.md).
