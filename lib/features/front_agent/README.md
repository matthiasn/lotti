# Front agent

Status: slice 0 — the dispatcher without a face. No UI, no flag, no door is
walked yet.

The front agent is the one agent the user talks to in one place. It does not
answer for anyone and it never changes the record: it reads a bounded index
of what exists — open tasks, projects, active goals and, when opted in,
people — and decides where each part of what the user said belongs. Its one
artifact is a **dispatch**: ordered, verbatim spans of the input, each with a
destination, a confidence and an intent. A question with up to three
candidates, or a one-line reply, are the only other ways a turn can end.

## What it owns

- `model/` — the fixed identity (`front_agent`), the dispatch shape and its
  thresholds, the routing index and its caps.
- `workflow/` — the tool contract and system prompt, the dispatch validator
  (the rules in code), the conversation strategy (count-and-refuse lookups,
  terminal calls), the model resolution (its own setup, never a category's)
  and the wake workflow that persists the dispatch record.
- `service/` — the index builder over existing reads, the singleton's lazy
  creation, and the chat service that makes a user turn durable and runs
  the wake.
- `state/` — providers, the wake-runner and setup-resolver contributions
  merged in `app_bootstrap.dart`.

## What it delegates

The open-task corpus and the phrase match are `features/agents`
(`open_task_corpus.dart`), shared with the Daily OS day agent. Reports,
one-liners and TL;DRs are the owner agents'. Walking a dispatch's doors — the
query pipeline for a task question, a goal or person chat turn, a filed entry
— is the next slice, and happens in the chat service after the wake
completes, never inside it.

The decisions and the slices are in
[the implementation plan](../../../docs/implementation_plans/2026-10-23_single_agent_entry_point.md);
how a turn actually runs is in
[the front agent concept](../../../knowledge/features/front_agent.md).
