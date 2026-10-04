---
type: Feature Module
title: Typed relationships and blockedness
description: Five typed link semantics stored as one row each, presented as one directed choice — and readiness computed at read time rather than stored.
resource: ../../../lib/features/tasks/repository/task_dependency_resolver.dart
tags: [tasks, links, dependencies, adr-0042, adr-0106]
status: stable
generated: { by: claude-code/fable-5, at: 2026-07-26T21:00:00Z }
stale_after: 2027-01-25
sources:
  - id: entry-link
    resource: ../../../lib/classes/entry_link.dart
    title: EntryLink union
    last_modified: 2026-07-26
  - id: resolver
    resource: ../../../lib/features/tasks/repository/task_dependency_resolver.dart
    title: TaskDependencyResolver
    last_modified: 2026-09-27
  - id: adr-0042
    resource: ../../../docs/adr/0042-typed-task-relationship-links.md
    title: ADR 0042 — Typed task relationship links
    last_modified: 2026-07-24
  - id: adr-0106
    resource: ../../../docs/adr/0106-the-task-link-graph-across-devices.md
    title: ADR 0106 — The task link graph across devices
    last_modified: 2026-09-27
  - id: cycles
    resource: ../../../lib/features/tasks/repository/blocks_cycles.dart
    title: findBlockersInCycle
    last_modified: 2026-09-27
  - id: spec
    resource: ../../../specs/tla/TaskLinkGraph.tla
    title: TaskLinkGraph TLA+ spec
    last_modified: 2026-09-27
---

# Five types, one row each

Beyond the plain "belongs with" `BasicLink`, a task-to-task link can carry one of
five typed semantics. Each is an `EntryLink` union variant with **the same shape**
as `BasicLink` — id, `fromId`, `toId`, timestamps, vector clock — so the
relationship lives entirely in the `type` column and every existing
`type = 'BasicLink'` consumer (recorded-time attribution, capture attachment)
stays structurally blind to typed edges.

**One row is stored per relationship.** "Is blocked by" / "has follow-up" are
*rendering labels for the reverse direction of that same row*, never separate
rows.

| Variant | Reading (from → to) | Inverse rendering |
|---|---|---|
| `blocks` | *from* blocks *to* | *to* is blocked by *from* |
| `followsUp` | *from* follows up on *to* | *to* has follow-up *from* |
| `duplicates` | *from* duplicates *to* (canonical) | *to* is duplicated by *from* |
| `fixes` | *from* fixes *to* (the defect) | *to* is fixed by *from* |
| `supersedes` | *from* supersedes *to* (obsolete) | *to* is superseded by *from* |

## Type and direction are one choice, not two

`RelationshipTypeSelector` renders a **single** dropdown completing the sentence
"This task… ⟨Blocks⟩", whose list holds all eleven directed relations: the
symmetric plain link ("Relates to", the default) plus each of the five types in
both directions. A `DirectedRelation` carries the type and its `inverse` flag
together, so callers never reconcile two independent values.

An earlier iteration split this into six type chips plus a separate
primary/inverse toggle. Because a `blocks` link's primary phrase *is* the word
"Blocks", the selected chip and the toggle's first segment displayed the same
word stacked a few pixels apart for four of the five directional types — which
reviewers and test users consistently read as a duplicated or contradictory
control. Every established issue tracker presents relations as one flat list of
directed phrases; this now does too.

Picking an inverse phrase **swaps `fromId`/`toId` before persisting**, so the
canonical stored direction is always the one the table lists — a `blocks` link's
`fromId` is always the blocker.

`PersistenceLogic.createLink` guards `EntryLinkType.blocks` against cycles,
surfaced as a snackbar on rejection; see [cycles](#cycles-guarded-on-one-device-reported-across-devices).

The candidate list excludes only tasks that already hold *the relation currently
selected*, recomputed as that selection changes — not every task the anchor
already touches. The schema's `UNIQUE(from_id, to_id, type)` lets one pair hold
several relationships, and direction is part of the identity, so the inverse of
an existing link stays offerable.

Committing is **one tap** — picking a candidate creates the link and pops. That
speed is the point, so it is not gated behind a confirm step; instead the commit
is followed by a SnackBar naming the relation written, with an Undo that removes
exactly that `(fromId, toId, type)` triple. Undo can therefore only take back the
edge the message is about, never another relationship the same pair holds.

# Blockedness is derived, not stored

Readiness is computed **at read time from live `blocks` links** (ADR 0042 §4): a
task is blocked iff a non-deleted `blocks` link exists with `toId == task` whose
blocker is neither tombstoned nor closed (`DONE`/`REJECTED`).

Closing or deleting a blocker therefore **releases every dependent implicitly, on
every device, with no unlock write and no sync race.**

```mermaid
stateDiagram-v2
  [*] --> Ready: no live blocks-link
  Ready --> Blocked: blocks edge created to an open blocker
  Blocked --> Ready: blocker closes (DONE/REJECTED) or link tombstoned
  Blocked --> Blocked: blocker link unresolved (conservative, ADR 0042 §4)
```

An **unresolvable** blocker — the link row exists but its `fromId` task cannot be
loaded, typically a sync gap — keeps the dependent blocked conservatively. That is
distinct from a **tombstoned** blocker (`deletedAt` set), which releases it.

## Cycles: guarded on one device, reported across devices

`wouldCreateBlocksCycle` refuses a `blocks` link when its target already
reaches its source along live `blocks` links, over every path — the visited
set bounds the traversal, there is no depth cap. `createLink` runs it before
reserving a clock and **again inside the transaction that writes the link**;
`JournalRepository.updateLinkType` does the same for a retype or a turn-around,
through `updateLink`'s `precondition`, and also requires the link to be stored
as it was read. The user and the task agent's link tool write on the same
device at the same time; only the check inside the transaction sees the other
one's link. So one device never closes a cycle.

Two devices can: each writes one direction while offline, and both arrive.
[ADR 0106](../../../docs/adr/0106-the-task-link-graph-across-devices.md) keeps
both links — each was a sound decision where it was made, and dropping one
would show a task as ready while its Linked Tasks card says it is blocked — and
**reports the cycle** instead. `findBlockersInCycle`
(`../../../lib/features/tasks/repository/blocks_cycles.dart`) follows live
`blocks` links forward from each blocked task, one batch per hop, through tasks
that still block (open, or not synced yet), and marks each blocker the task
reaches back. It reads only the stored links and statuses, so every device
holding the same rows reports the same cycles.

```mermaid
flowchart LR
  A["device A: t1 blocks t2"] --> S[["sync"]]
  B["device B: t2 blocks t1"] --> S
  S --> C["both links live everywhere"]
  C --> R["findBlockersInCycle marks each as the other's cycle blocker"]
  R --> U["chip: Blocked in a cycle"]
  R --> M["resolver: cycle: true"]
  C --> X["close either task"]
  X --> F["the other is released, on every device"]
```

Nothing is written to break a cycle; the user closes a task or removes a link.
`specs/tla/TaskLinkGraph.tla` checks `NoLocalCycle`, `CycleSurfaced` and
`ReleaseOnClose`, and `blocks_cycles_test.dart` runs the same checks against
the real writers on two databases.

# Three readers, two of which resolve blockedness

The UI-facing and model-facing resolvers differ *deliberately*; the third reader
only groups links for display and resolves nothing.

| Reader | Shape | Treats unresolvable blockers |
|--------|-------|------------------------------|
| `TaskBlockersController(taskId)` | Single task, UI-facing, autoDispose Riverpod | **Distinguishes** them — reports `TaskBlockersResult(openBlockers, unresolvedCount)`, with `isBlocked = openBlockers.isNotEmpty \|\| unresolvedCount > 0` |
| `TaskLinkGroupsController` | Display grouping | Drops tombstoned and unresolvable identically — fine for display |
| `TaskDependencyResolver` | Batch, model-facing, stateless plain Dart | Serializes a bare `{"taskId": …}` so "still blocked" is never downgraded |

`TaskBlockersController` resolves blockedness in **two bounded queries** — one
type-scoped link fetch, one batch status load for the distinct blocker ids. No
transitive closure, no per-task fan-out. Only when the task has a blocker does
it follow the links further, for the cycle report (`cycleBlockerIds`); it then
watches every task that search read, since closing any of them can break the
cycle. `TaskDependencyResolver` runs the same report once for all its tasks and
serializes `"cycle": true` on a blocker the task blocks in turn.

`TaskDependencyResolver` is deliberately **not shared code** with it: a UI-facing
single-task controller and a model-facing batch resolver have different call
shapes and failure-representation needs. See
[dependency-aware planning](../daily_os_next/dependency-aware-planning.md).

## The voice surface shares the same directed vocabulary

`DirectedRelation` lives in
`../../../lib/classes/directed_relation.dart` (pure Dart, no
Flutter import) and is re-exported by the picker file, so the UI and the task
agent cannot drift apart on what a phrase means. Beyond the localized picker
labels, each relation carries a stable `wireName`
(`blocks` / `is_blocked_by` / … / `relates_to`) that the task agent's
`link_task` and `create_follow_up_task` tool schemas enumerate, plus
`canonicalEndpoints`, which performs the same inverse swap the picker does
before persisting.

Spoken relationships ("this task is blocked by X", "this supersedes Y") become
**user-confirmable proposals**, never direct writes — see
[task agents](../agents/task-agents.md) for the validation and apply pipeline.

## Where it surfaces

- **`_TaskBlockedByChip`** in the detail header, next to the status pill: hidden
  when not blocked; a **bare untappable "Blocked" pill** when every blocker is
  unresolved (nothing to name or navigate to); otherwise a tappable pill naming
  the single blocker or the count, opening the blocker's detail page directly or
  a list sheet. When the task waits on a task it blocks, the pill reads
  **"Blocked in a cycle"**, and its tooltip says that closing either task or
  removing a link releases the other.
- **The status-enrichment prompt.** When the status picker sets a task's status
  to `BLOCKED` — a change, not a no-op — and the task is not already
  named-blocked, it opens `BlockingTaskPickerModal`: a search picker **fixed** to
  the `blocks` relationship with no type selector, creating a `blocks` link from
  the chosen task to this one. Fully skippable — **the status write already
  committed before the modal opens**, so dismissing persists nothing further.
  The panel the picker was opened from has closed by then
  ([detail composition](detail-composition.md#one-section-two-hosts)), so the
  prompt is presented on the navigator rather than over that panel.

**Manual `TaskStatus.blocked` and link-derived blockedness never write to each
other automatically.** The link layer only *offers* the picker after a manual
status change, and only when the task is not already named-blocked. Many real
blocks are external — a person, a delivery, a decision — and have no task to link.
