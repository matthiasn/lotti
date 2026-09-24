---
type: Feature Module
title: Vector clocks and conflict resolution
description: How causal order is represented, why coveredVectorClocks is separate from the clock itself, and what the user sees when two devices diverge.
resource: ../../../lib/features/sync/vector_clock.dart
tags: [sync, vector-clock, conflicts, causality]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-09-24T18:00:00Z }
stale_after: 2026-12-24
sources:
  - id: vector-clock
    resource: ../../../lib/features/sync/vector_clock.dart
    title: VectorClock compare and merge
    last_modified: 2026-06-16
  - id: vc-service
    resource: ../../../lib/services/vector_clock_service.dart
    title: VectorClockService
    last_modified: 2026-05-31
  - id: conflict-resolution
    resource: ../../../lib/features/sync/state/conflict_resolution_service.dart
    title: ConflictResolutionService
    last_modified: 2026-06-20
  - id: entry-diff
    resource: ../../../lib/features/sync/ui/widgets/conflicts/entry_field_diff.dart
    title: computeEntryDiff
    last_modified: 2026-06-20
  - id: agent-resolver
    resource: ../../../lib/features/agents/sync/agent_concurrent_resolver.dart
    title: AgentConcurrentResolver — resolveAgentEntityVersions, resolveLocalAgentWrite, resolveConcurrent, mergeAgentStateCounters and mergeConcurrentChangeSets
    last_modified: 2026-09-24
  - id: agent-sync-service
    resource: ../../../lib/features/agents/sync/agent_sync_service.dart
    title: AgentSyncService — the local write path
    last_modified: 2026-09-24
  - id: replication-spec
    resource: ../../../specs/tla/AgentReplication.tla
    title: TLA+ model of agent entity replication
    last_modified: 2026-09-24
  - id: adr-0068
    resource: ../../../docs/adr/0068-model-checked-agent-convergence.md
    title: ADR 0068 — model-checked convergence of synced agent entities
    last_modified: 2026-09-24
  - id: agent-handlers
    resource: ../../../lib/features/sync/matrix/sync_event_processor_agent_handlers.dart
    title: Inbound agent entities, and change sets applied in one transaction
    last_modified: 2026-09-24
  - id: change-set-spec
    resource: ../../../specs/tla/ChangeSetLifecycle.tla
    title: ChangeSetLifecycle — change sets across writers and devices, model-checked
    last_modified: 2026-09-24
  - id: adr-0067
    resource: ../../../docs/adr/0067-model-checked-change-set-lifecycle.md
    title: ADR 0067 — Model-checked change-set lifecycle
    last_modified: 2026-09-24
  - id: message-dag
    resource: ../../../lib/features/agents/sync/agent_message_dag.dart
    title: AgentMessageDag — the head order read before a merge, and the tip an append chains off
    last_modified: 2026-09-24
  - id: message-log-spec
    resource: ../../../specs/tla/AgentMessageLog.tla
    title: AgentMessageLog — the agent's message DAG and head pointer, model-checked
    last_modified: 2026-09-24
  - id: adr-0076
    resource: ../../../docs/adr/0076-model-checked-agent-head.md
    title: ADR 0076 — The agent head is a register over the message DAG
    last_modified: 2026-09-24
---

# What a vector clock is here

A `VectorClock` is a `Map<String, int>` from host id to that host's monotonic
counter. For a locally written payload it answers:

> When this payload version was written, what counters were already present in
> the version it was derived from, plus this host's next counter?

`VectorClockService.getNextVectorClock(previous: ...)` keeps the previous
entries and advances only the current host's counter. A brand-new local payload
with no previous clock contains just the current host's counter.

That is a different question from `originatingHostId`:

| Field | Answers |
|-------|---------|
| `originatingHostId` | Which host produced *this* payload version |
| `vectorClock` | What causal snapshot the version was created from — may mention other hosts |
| `coveredVectorClocks` | Which counters this payload *semantically replaces* |

# Compare rules

`VectorClock.compare(a, b)` yields four outcomes:

| Outcome | Meaning |
|---------|---------|
| `equal` | Both clocks contain the same counters |
| `a_gt_b` | `a` dominates: every host counter in `a` is ≥ `b`, at least one strictly greater |
| `b_gt_a` | The same relation reversed |
| `concurrent` | Neither dominates |

Implementation facts that decide edge cases:

- A missing host entry compares as `0`.
- A negative counter is invalid and throws `VclockException`.
- `VectorClock.merge(a, b)` takes the per-host maximum.

| A | B | `compare(A, B)` | Why |
|---|---|---|---|
| `{A: 5}` | `{A: 5}` | `equal` | Same counter everywhere |
| `{A: 7}` | `{A: 5}` | `a_gt_b` | `A` moved forward |
| `{A: 5}` | `{A: 7}` | `b_gt_a` | Reverse |
| `{A: 1, B: 1}` | `{A: 1}` | `a_gt_b` | Missing hosts count as `0`, so `B:1 > 0` |
| `{A: 3, B: 1}` | `{A: 1, B: 3}` | `concurrent` | Ahead on one host, behind on another |

```text
merge({A:5, B:1}, {A:3, B:4, C:2}) == {A:5, B:4, C:2}
```

# Three distinct uses

## 1. Freshness and conflict detection

`SyncEventProcessor` and `MatrixMessageSender` compare clocks to decide whether
what is on disk, in memory, or already stored locally is older, newer, equal or
concurrent. A `concurrent` result stores the incoming payload as a `Conflict`
row instead of merging it.

## 2. Gap detection

`SyncSequenceLogService.recordReceivedEntry()` walks **every** host in the
incoming clock except the receiver's own — not only the originator. It converts
those observations into gaps only for the originator and for hosts the receiver
has already seen online.

So a payload written by Alice can reveal that Bob's counter `7` is missing, if
the clock carries Bob at `8` and the receiver already has Bob in host activity.
If Bob has never been seen online by that receiver, the counter is recorded but
gap detection is skipped for Bob.

## 3. Supersession

`coveredVectorClocks` carries what a newer payload replaces, and the receiver
processes it before normal gap detection.

# Why a later clock is not enough

```text
missing counter:    {A:11}
new payload clock:  {A:20}
```

`{A:20}` proves the sender knows about later work. It does **not** prove that
counter `11` was semantically superseded by the payload being received. That
proof must be explicit:

```text
vectorClock        = {A:20}
coveredVectorClocks = [{A:10}, {A:12}, {A:15}, {A:20}]
```

The receiver pre-marks `10`, `12` and `15`, then handles `20` as the current
payload. Non-covered counters in between stay missing and can still trigger
backfill.

**Vector clocks describe causal knowledge. `coveredVectorClocks` describes
semantic replacement.** Conflating the two is the single most likely way to
break offline convergence.

## Worked example: rapid updates on one host

Host `A` updates the same entry three times before the outbox drains — `{A:5}`,
`{A:6}`, `{A:7}`. The outbox merge path collapses them into one pending message:

```text
vectorClock         = {A:7}
coveredVectorClocks = [{A:5}, {A:6}, {A:7}]
```

On receive, the covered clock equal to the current payload clock is filtered out
before pre-marking. Counters `5` and `6` are marked covered, `7` is recorded as
the payload being applied, and the receiver does not strand `5` and `6` as
permanent missing rows.

## Worked example: multi-host clock, single originator

A stored version already carries `{Alice:9, Bob:8}` — Bob edited earlier and
synced, then Alice edited locally. Alice's next local write produces:

```text
originatingHostId = Alice
vectorClock       = {Alice:10, Bob:8}
```

Bob's `8` is inherited causal history, not a counter Alice invented. This is
exactly why gap detection walks all hosts rather than only the originator.

# Conflicts

When detection yields `concurrent`, the payload lands as a `Conflict` row and
the user resolves it in *Settings → Advanced → Conflicts*.

```mermaid
stateDiagram-v2
    [*] --> Detected: incoming clock concurrent with local
    Detected: Detected (status = unresolved)
    Detected --> Alerted: ConflictNotificationObserver OS banner
    Alerted --> Reviewing: open conflict detail
    Detected --> Reviewing: open from settings list
    Reviewing --> Edited: shape = edited
    Reviewing --> DeleteVsEdit: shape = deletedOnLocal/Remote
    Edited --> KeepLocal: Keep this device
    Edited --> KeepRemote: Keep from sync
    Edited --> Combine: per-field merge
    DeleteVsEdit --> KeepEdited: keep the edit (recommended)
    DeleteVsEdit --> ConfirmDelete: confirm deletion
    KeepLocal --> Resolved: write winner (merged clock)
    KeepRemote --> Resolved: write winner (merged clock)
    Combine --> Resolved: write merged entity (merged clock)
    KeepEdited --> Resolved
    ConfirmDelete --> Resolved
    Resolved --> [*]
```

## Field-level diff

`ConflictDetailRoute` loads both versions — the local journal row and the remote
payload deserialized from the `Conflict` row — and renders a full field diff.
`computeEntryDiff` walks a registry of comparable fields (title, body, category,
start/end dates, starred, private, flag, audio duration) and returns
`EntryDiff{shape, fields, identicalFieldCount}`.

Two details make it trustworthy:

- **Text fields carry a word-level LCS diff** (`computeTitleDiff`).
- **A JSON completeness guard** emits a single `EntryField.other` entry whenever
  the two versions differ in a field the registry does not model. A change can
  therefore never be silently hidden across any of the 16 entity types — which
  matters because the registry will always lag new fields.

## Resolution

`ConflictResolutionView` offers three paths: **Keep this device**, **Keep from
sync**, or **Combine** — a per-field merge where each independently-mergeable
field gets a non-colour-dependent toggle and everything else follows a chosen
base side. A *recommended* chip marks the no-data-loss option.

When one side was soft-deleted while the other was edited
(`ConflictShape.deletedOnLocal` / `deletedOnRemote`), the diff is replaced by a
safe binary — keep the edited version or confirm the deletion — defaulting to
keeping the edit.

All three paths resolve through `ConflictResolutionService`. `resolveToSide` /
`buildMergedEntity` build the winner and stamp `VectorClock.merge(local,
remote)`, so the written entity dominates both clocks;
`PersistenceLogic.updateJournalEntity` applies it and the `detectConflict`
write-gate auto-resolves the row.

## Proactive surfacing

Conflicts do not have to be discovered by browsing settings.
`ConflictNotificationObserver`, started from `get_it`, watches the
unresolved-conflict stream and raises a single OS banner when *new* conflicts
appear during a session. Conflicts already present at startup are primed
silently, and a burst — a device returning from a long offline stretch — is
coalesced into one alert. `unresolvedConflictCountProvider` exposes the live
count for badges.

# Agent state converges without user involvement

Inbound agent entities are resolved by one pure function,
`resolveAgentEntityVersions` in `agent_concurrent_resolver.dart`, which
`SyncEventProcessor` applies before it overwrites a local `AgentRepository`
row:

| Comparison | Behaviour |
|------------|-----------|
| a clock missing on either side | Apply the incoming version — for agent state with the heads merged (below) |
| `a_gt_b` / `equal` (local wins) | Skip the upsert, restore the local JSON cache when the message came via `jsonPath`, but still record the sequence-log receipt so backfill stops asking |
| `b_gt_a` (incoming wins) | Apply — with agent state's G-counters and report watermarks joined in from the local row, and the local head kept when it is known to descend from the incoming one (below) |
| `concurrent` | The type's override, then last-writer-wins on `updatedAt`, then the canonical clock tiebreak; agent-state G-counters and nudge accumulators merge, the agent head follows the message DAG (below), and change sets merge item by item |

The concurrent case picks the strictly-newer `updatedAt`, falling back to a
replica-independent canonical clock comparison on ties. Type overrides run
first: a retraction is terminal, a scheduled wake with a later target beats
an earlier one, a day summary keeps its earliest testimony, a goal spec head
prefers the higher ordinal, and a nudge's dismissal, supersession and higher
activation outrank the timestamp. The cumulative counters on
`AgentStateEntity` — `wakeCounter`, `slots.totalSessionsCompleted`,
`slots.weeklyReviewCount` — are merged as a CRDT join via
`mergeAgentStateCounters`, and so are the report freshness watermarks. The
join also runs when the incoming version *dominates*: a concurrent merge joins
counters into a row without moving its clock, so a version that succeeds only
the merge's winner need not carry the loser's increments. Unlike journal
entries, agent-derived state never raises a user-facing `Conflict`.

Links (`AgentLink`) keep plain dominance plus last-writer-wins.

## A local write succeeds the row it replaces

Convergence is not only about the receive path: a pure pairwise rule still
diverges when a device keeps something its peers reject. So local writes of
mutable registers (the variants last-writer-wins orders by `updatedAt`) go
through the same decision (ADR 0068). `AgentSyncService._upsertEntityRaw`
reads the persisted row in the write's transaction and stamps the write with a
clock that covers both — every peer takes it as that row's successor — and
`resolveLocalAgentWrite` fixes its fields:

```mermaid
flowchart TD
  W[local write of a mutable register] --> R[read the persisted row in the transaction]
  R --> P{persisted row?}
  P -- no --> S[stamp with the write's own clock]
  P -- yes --> C{write's clock covers the row's?}
  C -- yes --> F[keep the write's fields]
  C -- "no: stale snapshot or vectorClock null" --> M[resolve against the row as if concurrent]
  F --> J[join agent-state G-counters and watermarks with the row]
  M --> J
  J --> T[raise updatedAt to at least the row's]
  T --> V["stamp with join(write clock, row clock) + own counter"]
  V --> O[persist and send]
  S --> O
```

A write built on a stale snapshot therefore loses locally exactly where it
loses on every peer — an edit older than a retraction cannot revive it — and
a successor never sorts before its predecessor, whatever the writing device's
clock says. Append-only variants are written as given.

The flip side: a writer that *means* to replace the row must build on it. A
write with `vectorClock: null` over an existing id is resolved as concurrent,
and one that moves the row against the resolver's order — an earlier
deadline under the scheduled-wake override, a new report at the instant the
standing head was stamped, a new version while a peer's clock runs ahead —
is handed the row back, here and on every peer. So report heads, soul and
template heads and goal-progress registers carry the clock
of the row they read in the same transaction (ADR 0068 addendum;
`AgentReplication.tla`'s `Intend` write and `LocalWriteTakesEffect`).

The scheduling fields (`nextWakeAt`, `sleepUntil`, `scheduledWakeAt`) are
device-local: the receive path overlays this device's values onto every
incoming state row. Maintenance writes that change only those fields go
straight to the repository without a clock or a sync message and leave
`updatedAt` alone — the throttle's `nextWakeAt`, and the project and
scheduled-wake cleanups of `scheduledWakeAt` — because a local timestamp
peers never see would let this device keep a row that every other device
rejects. Workflow outcome writes that also set `scheduledWakeAt` (the day
and project agents) go through `AgentSyncService` like any other state write.

## Change sets merge item by item

A change set is one synced row that every device showing it edits — the user
confirms an item on the phone while a wake on the desktop retracts another.
Picking one whole version dropped the other device's decisions (a change set's
last-writer-wins timestamp is its `createdAt`, so the canonical clock order
decided), and an item confirmed and applied on one device read `pending`
everywhere again. The receive decision therefore merges two concurrent
versions item by item — the change-set case of `resolveAgentEntityVersions`'
concurrent branch (`mergeConcurrentChangeSets`):

| Per item | Kept |
|----------|------|
| different `revision` | the version that changed the item last |
| a side without a `revision` (an older build wrote it, and drops the field) | judged by status, as below — not as revision 0; on a status tie, the side with a revision, which changed the item |
| same revision, different status | the more final status: `confirmed` over `rejected` over `retracted` over `pending` — a confirm took effect, a concurrent rejection or retraction did not |
| same revision and status | a fixed order on the item's content — never the clock order |

Every writer bumps an item's `revision` when it changes the item's status or
arguments (`ChangeItemRevision.withStatus` / `withArgs`). Items only one
version appended are kept, the set status is derived from the merged items,
and the merged row carries the join of both clocks, so the two devices compute
the same row and a later write on either dominates it; a version that
succeeds only one side is concurrent with the merged row and merges again.

Unlike the nudge residual below, the joined clock is safe here. No step of the
item merge reads the canonical clock order: each item is the maximum of a
total order on (revision, status rank, content), so the merged row depends
only on the versions' contents, not on the order a replica received them in.
Two cases fall outside that order and keep the whole-row winner's
history-dependence: versions that disagree on which proposal an index holds
(or a tombstone), which fall back to the whole-row winner, and items an older
build wrote without a revision, which are compared by status alone.

Change sets are append-only for last-writer-wins (`createdAt`), so a local
change-set write is not resolved by `resolveLocalAgentWrite`; every writer
already re-reads the set and changes its own item in one transaction
(ADR 0067).

The receive is also one transaction for change sets: the local row is read,
compared and written together, not compared against the bundle's prefetched
snapshot. Otherwise a local claim committing between the read and the write
is overwritten by a peer version that only covered the row as it was before
the claim.

`specs/tla/ChangeSetLifecycle.tla` model-checks both, and names what they
cannot close: an item decided on two devices before they sync is applied on
both (the rows still converge), and a consolidation on one device racing a
decision on another leaves a pending copy of an applied change — see
[ADR 0067](../../../docs/adr/0067-model-checked-change-set-lifecycle.md).

## The agent head follows the message DAG

An agent-state row carries the agent's head pointer, `recentHeadMessageId`:
the message the next append chains off. Taken from the last writer like the
other fields, it went back whenever an older head won on `updatedAt` — a
version from a device whose clock runs ahead, say — and the next append then
forked the log off the old head (ADR 0071's residual). The head is therefore
merged apart from the other fields, as a register over the message DAG
(ADR 0076, `mergeAgentHeads`):

| Heads | Kept |
|-------|------|
| one unset | the other |
| one known here to descend from the other | the descendant, whichever version wins the other fields |
| no order known here — a true fork, or messages and edges still in flight | the greater id: the same on every device, never the clock or arrival order |

A version with no clock on either side — an older build's — still applies,
with the heads merged the same way. On dominance the incoming head stands
unless the local one is known to descend from it, or the incoming one is
unset: a concurrent merge keeps the winner's
clock, so a replica can hold a head its successor's writer never saw.

The resolver stays pure. `SyncEventProcessor` reads the order of the two heads
in the local DAG first (`AgentMessageDag.ancestryOf`, a forward walk over the
`messagePrev` edges of present rows) and passes it in as `isAncestor`; the
local write path needs none, since every local head writer reads the row in
its own transaction. An agent-state row is also read, resolved and written in
one transaction, as change sets are, and never from the bundle's prefetched
snapshot: a local append committing in between was otherwise overwritten and
the head moved back past it.

What the merge cannot know — an order whose rows have not arrived yet — the
append path settles: `_appendMessage` advances the head to a tip past it
before chaining (`AgentMessageDag.tipFrom`), so a pointer left on a row that
has since received a child does not fork the log — provided the child's
`messagePrev` edge has arrived, since the walk follows edges.
`specs/tla/AgentMessageLog.tla` model-checks both (`HeadNeverRegresses`,
`AppendsOffTips`, `SettledHead`).

## Residuals

The model `specs/tla/AgentReplication.tla` checks this with three replicas,
arbitrary arrival orders, stale and unclocked writes and a lagging clock. Two
cases stay open, recorded in `specs/tla/README.md` and ADR 0068:

- A successor that ranks *below* its predecessor under a type override — the
  day agent's digest retry re-arming its consumed window at the same instant,
  a relationship retry moved to an earlier instant — can still let arrival
  order decide against a third concurrent version.
- Nudges store the join of both clocks after a concurrent merge, so an exact
  `updatedAt` tie between two nudge versions is broken on a history-dependent
  clock.
