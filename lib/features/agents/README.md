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
├── memory/       # author-time memory links
├── projection/   # the event log's pure fold, capture and checkpoint selection
├── database/     # agent.sqlite
├── sync/         # vector-clock stamping and outbox buffering
├── model/        # entities, links, enums
├── state/        # Riverpod providers and wiring
└── ui/           # AI summary card, internals panel, settings tabs
```

## What the store forgets, and what it never forgets

Agents write two kinds of row into the same store. **The user's own material** —
captures, day plans, day summaries, directives, durable knowledge, reports and
personalities — is never deleted by age or volume, however old it gets. **The
machine's working residue** — the observations an agent writes about itself, the
status events it raises, the wake-run log — is bounded, because the coordinator
is long-lived and writes on every wake, forever. Unbounded growth is felt as
database size, sync payload, backup size and slower maintenance long before any
individual query gets slow.

| Row | Kept |
|-----|------|
| Captures, plans, summaries, directives, knowledge, reports, souls | Forever |
| Weekly rollups | Forever — ~52 rows a year, and the digest's only trend source |
| Per-wake token usage | Forever — the template page totals it over all time; compacting it into monthly aggregates is the way to bound it, not deletion |
| Wake-run history | Forever — it carries lifetime counts the app displays and the ratings the user gave |
| Proposal audit trail (change sets, decisions, attention claims) | Forever |
| Observations | Newest 200 per agent **and** 120 days |
| Day-status events | 90 days |

Observations need both bounds. The count alone would not hold: a fresh
`day_agent` identity is created every day and goes cold permanently, so a
per-agent quota lets one more agent, with a full allowance of its own, appear
every day forever. The count bounds the long-lived planner's recency; the age
reaps the accumulating per-day identities.

The sweep runs once per start, off the path to a ready app, in bounded batches.
It is safe to interrupt: the policy is a pure function of the store's contents,
so a pass cut short leaves rows for next time and a pass that runs twice removes
nothing the second time.

What may be forgotten is decided by a classification that is **exhaustive over
the entity model**, so a new kind of row does not compile until someone says
what happens to it — a wildcard would let new machine-derived rows start
accumulating with no test and no compiler failure.

**Across devices it is a hard delete with no tombstone.** A tombstone per pruned
row would grow the sync payload in the exact dimension retention exists to
shrink, and there is nothing to converge on — every device applies the same rule
to the same synced rows and reaches the same conclusion independently. A device
that has been offline past the window therefore comes back carrying rows the
others already forgot; those are dropped on arrival rather than re-materialized,
so reconnecting does not hand the next sweep the same work again. A row sitting
exactly on the boundary may survive a few hours longer on one device than
another, which for observational data is invisible.

**Day-agent identities are deliberately left to accumulate** — roughly one per
day of use. Each is tiny and permanently cold, and merging or archiving them
would cost the property that makes them worth having: a day's history stays
addressable by its own id forever. What scales with their count is enumeration
and sync footprint, and both are already bounded by per-agent reads rather than
by walking the set.

## How it works

Design decisions behind the runtime are recorded in
[docs/adr/](../../../docs/adr).

The runtime architecture — wake orchestration, the append-only memory log and its
compaction, per-kind workflows, tool policy, the proposal lifecycle, and the UI
choreography — is documented in the knowledge bundle:

**→ [knowledge/features/agents/](../../../knowledge/features/agents/)**
