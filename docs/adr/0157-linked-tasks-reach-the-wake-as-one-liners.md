# ADR 0157: Linked Tasks Reach the Wake as One-Liners, Deeper on Demand

- Status: Accepted
- Date: 2026-11-02
- Concepts: [task agents](../../knowledge/features/agents/task-agents.md#linked-and-related-tasks-are-read-on-demand)
- Builds on: [ADR 0155](0155-the-task-agent-finds-related-tasks-on-demand.md)

## Context

Every task-agent wake carried a `## Linked Tasks` section with each linked
task's metadata plus its agent's one-liner *and* TL;DR, for every linked task,
with no bound on how many. A task linked to dozens of others paid for all of
those TL;DRs on every wake, whether or not the wake had anything to do with
them — the same pollution that had switched off injecting sibling tasks'
TL;DRs (ADR 0155).

ADR 0155 then gave the agent a drill-down, `get_related_task_details`, but only
for tasks a `find_related_tasks` search of the same wake returned. A linked
task — the most relevant other work there is — could be read no deeper than
what the wake had already injected.

## Decision

1. **Linked tasks enter the wake as one-liners only.** A row keeps the linked
   task's metadata, its `relations` and its agent's one-liner. The TL;DR and
   the report body stay out.
2. **The section is budgeted.** `LinkedTaskDirectory` holds it to at most 30
   rows and 12,000 characters, clipping titles (160) and one-liners (240),
   one compact JSON row per line. Over budget, open tasks come before closed,
   newer before older, the id breaking ties so the choice is stable across
   wakes; an `omitted` entry counts the rest.
3. **Two depths, each its own tool.** `get_task_tldr {taskId}` reads a task's
   TL;DR, `get_task_report {taskId}` its whole latest report. They replace
   `get_related_task_details` and its `includeFullReport` flag: a separate,
   explicitly more expensive tool makes the cost of the deeper read visible
   in the tool list, and lets the prompt order them — TL;DR first, report
   only when the TL;DR is not enough.
4. **Only what the wake showed can be read.** Both tools read a task the
   Linked Tasks section lists or one a search of this wake returned
   (`RelatedTaskLookup.canRead`), never another id. A linked task the budget
   left out is not listed, so it cannot be read in that wake either.
5. **The row and the drill-down read the same report.**
   `getUsableTaskReportsForTaskIds` takes a task's agent links newest first
   and the first agent with a non-empty current report. A primary-link-only
   lookup would let a row show an older agent's one-liner and then answer
   "no report yet" to `get_task_tldr` for the same task.
6. **Gated by wake facts, like the search.** `find_related_tasks` needs
   search by meaning (`hasRelatedTaskSearch`); the drill-down needs search or
   a listed linked task (`hasLinkedTasks`). Both are computed on every wake.
   There is no `enabled` flag (ADR 0155, point 7).

## Consequences

- A wake costs a bounded amount for linked tasks however many there are, and
  less than before for every task that has any.
- A wake that needs a linked task's TL;DR now spends a tool call on it. The
  one-liner is enough for most wakes; the prompt says so.
- Linked tasks outside the agent's allowed categories were already in its
  context, TL;DR included. They remain readable through the drill-down, now
  only on request; what leaves the device for them shrinks rather than grows.
- `get_related_task_details` no longer exists. Persisted tool messages keep
  the old name in history; no live code reads them.
