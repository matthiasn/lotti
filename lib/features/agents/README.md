# Agents

Agents are Lotti's background assistants. Each one watches a specific thing —
a task, a project, an event, a day — and keeps a short, current summary of it,
proposing concrete changes the user can accept or reject.

The defining rule: **an agent never silently changes the user's data.** Almost
every mutation it wants to make arrives as a proposal in the UI, and nothing is
applied until the user confirms it.

## What it does for the user

- **Keeps a live summary of each task.** A task agent reads the task, its
  checklists, linked entries, voice notes and time entries, and maintains a short
  report: what the goal is, what has been achieved, what is next, what was
  learned.
- **Proposes changes instead of making them.** Add checklist items, set a due
  date, adjust priority or status, assign labels, log a work session, relate the
  task to another ("this is blocked by X", "this supersedes Y") or spin off a
  follow-up task carrying such a relationship — each arrives as a row the user
  can accept, dismiss, or swipe away. *Confirm all* takes the whole batch at
  once.
- **Updates itself when things change**, if the user wants it to. Automatic
  updates are off by default and per-agent; with them off the report is simply
  marked out of date and an *Update now* button appears.
- **Withdraws its own stale suggestions.** When a proposal no longer makes sense,
  the agent retracts it rather than leaving it in the list.
- **Summarizes at other scopes too.** A project agent refreshes its digest after
  relevant project or linked-task activity; an event agent writes a recap of a
  trip or gathering from its photos and notes; the Daily OS planner plans a day.
- **Learns from feedback.** Agents periodically hold a "one-on-one" — a
  conversation where the user's accumulated feedback is reviewed and the agent's
  own instructions are revised, with every change approved by the user first.
- **Shows its work.** An internals panel exposes the agent's reports,
  conversations, observations, token usage and activity, so its behaviour is
  inspectable rather than opaque.

## What it owns

The persisted agent runtime: agent identities and state, wake scheduling and
throttling, the agent's own memory log, change proposals and the review gates in
front of them, template and personality versioning, and the operator surfaces
under *Settings → Agents*.

It does **not** implement inference. Providers, models, prompts and profiles
belong to the [AI feature](../ai/README.md). It also does not own the user's
data: tasks, projects, checklists and time entries live in the journal database,
and agents read them on demand.

## Where the code lives

```text
lib/features/agents/
├── wake/         # orchestrator, queue, runner, scheduling
├── workflow/     # one per agent kind, plus evolution and improver
├── service/      # creation, change-set confirmation, souls, templates
├── memory/       # author-time memory links
├── projection/   # the event log's pure fold, capture and checkpoint selection
├── database/     # agent.sqlite
├── sync/         # vector-clock stamping and outbox buffering
├── model/        # entities, links, enums
├── state/        # Riverpod providers and wiring
└── ui/           # AI summary card, internals panel, settings tabs
```

## What the store forgets, and what it never forgets

**The user's own material is never deleted by retention** — captures, plans, day
summaries, directives, saved knowledge, reports and personalities are kept for
good, as are weekly totals, run history and ratings, and the record behind every
suggestion accepted or rejected.

What the app does forget is the machine's own working residue. Today that means
day-status events older than ninety days (keeping each day's last one) and the
assistant's own working notes older than six months. Deleting
an agent, or forgetting one of those events, now also removes the copy the sync
pipeline kept on disk — previously those files outlived the delete. Tidying runs
in the background after start-up and is safe to interrupt.

The policy, what is deliberately kept and why, how it behaves across devices,
and why pruning the agent's own observations takes more than a `DELETE` are in
[agent persistence and sync](../../../knowledge/features/agents/persistence-and-sync.md).

## How it works

Design decisions behind the runtime are recorded in
[docs/adr/](../../../docs/adr).

The runtime architecture — wake orchestration, the append-only memory log and its
compaction, per-kind workflows, tool policy, the proposal lifecycle, and the UI
choreography — is documented in the knowledge bundle:

**→ [knowledge/features/agents/](../../../knowledge/features/agents/)**
