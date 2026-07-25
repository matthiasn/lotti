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
  date, adjust priority or status, assign labels, log a work session — each
  arrives as a row the user can accept, dismiss, or swipe away. *Confirm all*
  takes the whole batch at once.
- **Updates itself when things change**, if the user wants it to. Automatic
  updates are off by default and per-agent; with them off the report is simply
  marked out of date and an *Update now* button appears.
- **Withdraws its own stale suggestions.** When a proposal no longer makes sense,
  the agent retracts it rather than leaving it in the list.
- **Summarizes at other scopes too.** A project agent writes a daily digest
  across a project's tasks; an event agent writes a recap of a trip or gathering
  from its photos and notes; the Daily OS planner plans a day.
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
├── memory/       # input capture, event log, compaction
├── database/     # agent.sqlite
├── sync/         # vector-clock stamping and outbox buffering
├── model/        # entities, links, enums
├── state/        # Riverpod providers and wiring
└── ui/           # AI summary card, internals panel, settings tabs
```

## How it works

The runtime architecture — wake orchestration, the append-only memory log and its
compaction, per-kind workflows, tool policy, the proposal lifecycle, and the UI
choreography — is documented in the knowledge bundle:

**→ [knowledge/features/agents/](../../../knowledge/features/agents/)**

Design decisions behind it are recorded in [docs/adr/](../../../docs/adr).
