---
type: Feature Module
title: Coordinator and day-agent protocol
description: Two durable synced entities instead of RPC — binding day directives downward, typed status events upward, and a digest wake that consumes them.
resource: ../../../lib/features/daily_os_next/agents/service/day_agent_directive_service.dart
tags: [daily-os, coordination, directives, digest, rollups]
status: stable
generated: { by: claude-code/opus-5, at: 2026-08-02T12:00:00Z }
stale_after: 2026-11-01
sources:
  - id: agents
    resource: ../../../lib/features/daily_os_next/agents
    title: Directive, status and digest services
    last_modified: 2026-08-02
  - id: adr-0032
    resource: ../../../docs/adr/0032-hierarchical-day-agent-coordination.md
    title: ADR 0032 — Hierarchical day-agent coordination
    last_modified: 2026-07-24
  - id: adr-0048
    resource: ../../../docs/adr/0048-one-device-runs-the-coordinator-digest.md
    title: ADR 0048 — One device runs the coordinator digest
    last_modified: 2026-08-01
  - id: adr-0019
    resource: ../../../docs/adr/0019-attention-negotiation-protocol.md
    title: ADR 0019 — Attention negotiation protocol
    last_modified: 2026-06-06
---

The coordinator and per-day agents coordinate through **two durable, synced
entities — no RPC** (ADR 0016/0018/0019). Everything is an append-only or
last-write-wins register that converges on its own.

## A per-day agent is retired when its day is done

A `day_agent:<dayId>` is created for the day it plans and stays active for
that day plus a **one-day handover**, so it can wake the morning after and give
the coordinator anything its day left unreported. Then
`DayAgentService.retirePastDayAgents` sets it dormant and clears its
`scheduledWakeAt`.

Both halves are load-bearing. The lifecycle flip is what `ScheduledWakeManager`
keys on — its `_isActiveAgent` guard already skips a non-active agent and
clears the stale wake. Clearing the deadline stops the row surfacing at all,
because `getDueScheduledAgentStates` filters on `scheduledWakeAt` **only, not
lifecycle**: a finished day still holding a deadline is otherwise due on every
tick, forever.

Retirement runs **before `ScheduledWakeManager.start()`**, not only from
`restoreSubscriptions`. `start()` checks immediately, and the restore pass is
several awaits further down the provider's init — so a finished agent would
otherwise still be `active` for that first check and fire once per cold start,
which is the spend this exists to stop.

Without this the active set grew by one per day of use and
`restoreSubscriptions` re-hydrated every one of them on each launch — model
spend on days that are over, and the pressure behind much of the bounding work
in `lotti3-hkb`.

```mermaid
stateDiagram-v2
  [*] --> Active: day agent created for its day
  Active --> Active: its own day, plus one handover day
  Active --> Dormant: retirePastDayAgents — lifecycle flip + scheduledWakeAt cleared
  Dormant --> [*]: stays readable, never wakes on its own
```

**Retired is not deleted, and not revived.** The day's artifacts stay where
they are and the day stays readable. `getOrCreateDayAgentForDate` returns a
dormant agent **as-is**: reactivating there looks helpful but cannot tell
retirement apart from a deliberate pause — `AgentService.pauseAgent` writes the
same `dormant` — so it would silently resume an agent the user switched off.

**Both wake paths are guarded, not just one.** `set_next_wake` persists a
*standalone* `ScheduledWakeEntity`, not `AgentStateEntity.scheduledWakeAt`, and
that record path is the one per-day agents actually use for pre-warms. Since
`getDueScheduledWakeRecords` also filters on the deadline alone, the manager
checks lifecycle in **both** loops and marks a non-active agent's due record
consumed. Clearing only the state field would have left retirement doing
nothing for the path that matters.

```mermaid
sequenceDiagram
  participant SWM as ScheduledWakeManager
  participant Coord as Coordinator (digest wake)
  participant Dir as DayDirectiveEntity
  participant Day as Per-day agent
  participant Status as DayStatusEventEntity

  SWM->>Coord: due digest record fires (06:00, workspace coordinator:digest)
  Coord->>Coord: ensureWeekRollups (last 4 complete weeks) -> <recent_weeks>
  Coord->>Coord: <digest> = status events since last digest + directives + attention window
  Coord->>Dir: issue_day_directive (today + tomorrow, revisable register)
  Coord->>Coord: dailyWakeCompleted milestone + re-arm tomorrow's digest record
  Day->>Dir: read newest revision at wake start -> <day_directive> section
  Day->>Day: draft/refine bound by the commitment contract
  Day->>Status: raise_day_status(attentionNeeded | dayClosed) when warranted
  Status-->>Coord: getDayStatusEventsSince(watermark) at the next digest
```

# Downward: `DayDirectiveEntity`

One **revisable register per day** (`day_directive:<dayId>`), coordinator-authored
only — `DayAgentDirectiveService` rejects other issuers, and the tool is only
*offered* on coordinator wakes.

It carries distilled commitments (source, window, minutes, evidence refs), a
capacity budget (available and already-scheduled minutes, energy bands),
carry-over items, bounded constraints and attention notes — **never transcripts**.

Bounded by validation: ≤12 commitments and carry-over items, ≤8 notes and
constraints, 280-character strings, windows inside the day. Revisions upsert the
deterministic id with a fresh `directiveRevisionId` under last-write-wins,
preserving `createdAt`.

The per-day wake reads it **by primary key — no projection table** — and renders
`<day_directive>` in the byte-stable prompt prefix, after `<knowledge_index>`.

**The drafting contract makes it binding.** Every commitment is either placed,
traded away in a diff naming the collision, or escalated via `raise_day_status`
with `status: attentionNeeded` and `directiveUnsatisfiable` among its `reasons`.
Requested minutes reconcile against the capacity budget before drafting.

# Upward: `DayStatusEventEntity`

Append-only typed events (`day_status:<dayId>:<uuid>`):

| Status | Reasons |
|--------|---------|
| `onTrack` | — |
| `attentionNeeded` | `overCommitted`, `directiveUnsatisfiable`, `userDivergence`, `processingBlocked` |
| `dayClosed` | — |

`raise_day_status` may only target **the wake's own day** (`wakeDayId` threaded
through the tool dispatch), caps at one event per wake via a per-`runKey` guard,
requires typed reasons with `attentionNeeded`, and bounds notes at 500
characters.

It is a **new entity variant, not an `AgentMessageKind`**, so status stays out of
the compaction fold and scans via the type/subtype index — `getDayStatusEventsSince`
is cross-agent, oldest-first, served by `idx_agent_entities_active_type_created`.

# The digest wake

The coordinator's consumption point: a `digest:<dayId>` token wake on the
`coordinator:digest` workspace — **its own lane, never coalescing with day
work**.

It assembles `<digest>` from status events since the last digest (watermark = the
newest `dailyWakeCompleted` milestone, with a 48-hour fallback), today's and
tomorrow's current directives, and the two-day attention window.

**Digest rules: react by revising directives — never by drafting plans.**

Completion writes the watermark milestone and deterministically re-arms
tomorrow's digest record. `DayAgentService.restoreSubscriptions` bootstraps the
first record, and recovers a missed re-arm, whenever the coordinator identity is
active.

## One device per window, elected by the register itself

The digest record is one synced entity with a deterministic id, so **every**
device saw it come due and every device ran the inference — N devices, N charges,
one result. The writes converge (week rollups are registers recomputed from
source), so this was spend and battery rather than correctness, but it recurred
every window forever.

`ScheduledWakeManager` leases any record its `requiresLease` predicate marks as
shared work; the coordinator digest is the only one today. The cycle is
claim → settle → confirm:

```mermaid
stateDiagram-v2
  [*] --> Unclaimed: record due
  Unclaimed --> Claimed: write leaseHostId = me, leaseUntil = now + 30m
  Claimed --> Claimed: settle not elapsed — wait
  Claimed --> Fires: after 3m, the surviving claim is still mine
  Claimed --> Skips: after 3m, another host survived
  Claimed --> Unclaimed: leaseUntil passed — claimant went away
  Fires --> [*]: status flips to consumed, every device stops
```

**No coordinator is needed because the record is already a last-write-wins
register** (ADR 0048). Concurrent claims converge to exactly one surviving host
— that convergence *is* the election — and the settle is what gives it time to
happen before anyone acts on it. A crossing claim moves the deadline forward,
which restarts the settle for both sides, so the winner is unambiguous.

`leaseUntil` is stored in **UTC**, and the settle is measured from it (minus the
lease duration) rather than from `updatedAt`. Entities cross devices as JSON, and
`toIso8601String()` on a local `DateTime` writes no offset, so a peer would
re-read the same wall-clock components in its own zone: a west-to-east claim
would look already expired and be taken over at once — both devices firing, the
duplicate the lease exists to prevent — while the reverse direction would stretch
thirty minutes into hours.

The lease expires. A device that claims and then crashes or goes offline
*before consuming the record* delays the window rather than dropping it: past
`leaseUntil` any device takes over. A device with no sync host fires unleased —
it has no peers to race.

The lease recovers the **claim**, not the run. A crash after the `consumed` flip
but before the job finishes still loses that day's briefing, because
`_ensurePendingDigestWake` sees a consumed record and arms tomorrow's slot. That
follows from consuming before running and is older than the lease.

**The lease bounds cost, not correctness.** Devices partitioned from sync while
their model providers stay reachable can each hold a locally-consistent claim and
both fire. That is redundant spend rather than a wrong answer — the digest's
writes are registers recomputed from source — and closing the window entirely
would need a consensus round this app has no coordinator for.

## A digest anchors to the day it runs on, not the day it was scheduled for

The record's `digest:<dayId>` token is minted when the *next* digest is armed, so
a record that stays pending through its slot — device asleep, offline, or the app
not running — fires carrying a day that may already be over. `resolvePlannerWakeDay`
would then hand the wake a dead workspace and the coordinator would issue
directives for a day nobody can act on.

`reanchorDigestTriggerTokens` rewrites a stale `digest:` token to today's day id
before the workspace is resolved. A current or future token is left alone: firing
early is clock skew, not staleness, and pulling the anchor backwards would digest
a day twice.

**Missed windows collapse into one run rather than replaying one digest per
skipped day.** The catch-up still sees everything back to its watermark, so a
week offline surfaces that week's escalations in the single catch-up digest —
*provided a previous digest completed*. With no `dailyWakeCompleted` milestone
at all (a fresh install, or every prior attempt failed), the watermark falls
back to 48 hours plus the 12-hour sync slack, and escalations older than that
are not rendered before the watermark advances past them. That bound belongs to
the watermark fallback, not to re-anchoring.

The re-arm is bounded by the day just digested (`nextDigestTimeAfterDay`), not
merely by `now`. A catch-up that runs at 03:00 re-anchors to today, and the plain
next slot would be *today* at 06:00 — a second digest for the day just digested.

**Only a run that actually digested applies that bound** — which is not the same
as a run that reported success. `AgentSyncService` rethrows a buffered outbox
failure *after* its transaction commits, so a digest can be durably complete and
still be reported as failed; the failure path therefore reads the
`dailyWakeCompleted` milestone back from the log for its own run key rather than
trusting the result. When nothing committed it re-arms unbounded and keeps
today's 06:00 retry, because skipping to tomorrow would cost the user today's
briefing over a transient error.

The resulting invariant is **at most one digest per day per record history** —
it is enforced by one device consuming and re-arming the record in sequence, and
says nothing about two devices holding the same pending record before either
`consumed` flip has synced. That second question is the lease's, above: it
narrows the window to the settle period rather than closing it, which bounds
cost rather than establishing exclusion.

## Severity ranking, not arrival order

When more events exist than the digest renders (50), selection is severity-ranked
by `selectDigestStatusEvents`:

1. `attentionNeeded` > `dayClosed` > `onTrack`
2. `directiveUnsatisfiable` > `overCommitted` > `processingBlocked` >
   `userDivergence`
3. Newer beats older within a tier
4. Ascending id as the final deterministic tiebreak for equal timestamps

The section then carries `statusEventsTruncated: true`.

**Ranking sees every event since the watermark.** The oldest-first query refetches
with a doubled limit whenever a page fills (ceiling 2000), because a fixed-size
fetch would drop the newest events *pre-ranking* and the advancing watermark
would then skip them forever.

# Weekly rollups

A digest wake first refreshes `WeekRollupEntity` registers
(`week_rollup_v2:<Monday>`, coordinator-owned) for the **last 4 complete weeks**:
planned minutes per category (dropped blocks excluded), recorded minutes per
category (empty-string key = uncategorized), and days-with-plans.

**Every week is recomputed from source on every digest.** That is what makes
plain last-write-wins converge: a late-synced entry, and an incomplete aggregate
that won a concurrent-LWW race on another device, both self-heal at the next
digest.

Cost stays bounded by batching — one plan read and one recorded-time read span
all four weeks, bucketed per week — unchanged aggregates skip the write (steady
state writes nothing), and tombstones are never resurrected.

The rollups render as `<recent_weeks>` (names resolved, newest first), so the
digest can spot month-scale pacing trends without re-reading a month of raw
entities.

## Bucketing is canonical, or LWW does not converge

"Recomputed from source on every digest" only self-heals when every device
computes the *same* value from that source. Device-local bucketing broke that:
`weekStartFor(span.start)` resolved through the reading device's zone, so a
laptop and a phone in different zones produced different totals for the same
past week and flapped the register between them forever — a convergence bug
wearing the costume of a bucketing bug.

Two rules make the computation a property of the data rather than of the reader:

**The fix rests on how `dateFrom` crosses the wire.** It is a local-typed
timestamp serialized with `toIso8601String()`, which emits **no zone suffix**,
and the receiver parses it back as local. Its *components* are therefore the
recording device's wall clock on every device that holds the entry — while the
instant it denotes is reader-relative, because each device resolves those
components in its own zone. Reading the components is what makes the answer a
property of the data; converting first (`toUtc()`, `toLocal()`) turns it back
into a reader-relative instant, which was the bug.

| Input | Canonical rule |
|-------|----------------|
| Recorded minutes | `recordedWallClock(span.start)` — `dateFrom`'s calendar components, read as-is |
| Planned minutes | already stable: keyed by date-only `dayplan-<date>` ids, never by an instant |
| Week key | `canonicalWeekStart` reads calendar **components** and returns a UTC-typed midnight; `weekRollupEntityId` hashes those, never a converted instant |
| Week label | `isoCalendarDate` formats those components; a converting read renders the canonical Monday as the preceding Sunday west of UTC |
| Recorded length | `canonicalRecordedDuration` subtracts the two ends' components. `dateTo - dateFrom` on the parsed values is reader-relative for the same reason the bucket was, so a DST-crossing interval is 60 minutes in one zone and 120 in another — and both would be stamped canonical |
| Planned length | `canonicalWallClockDuration` over the block's `startTime`/`endTime`, which are zone-less for the same reason |

**Canonical durations are confined to the rollup.** The rendered week context is
read on one device, beside a timeline lane that uses elapsed time, so switching
it too would make a DST-crossing entry read as 120 minutes in `<recent_days>`
and 60 in the timeline.

`Metadata.utcOffset` is deliberately **not** consulted. It records the offset at
*creation*, not at `dateFrom`, so a backfilled or cross-DST entry carries an
offset that does not apply to its own timestamp — and it is absent on older
entries, which would put them on a different rule from everything else. The
components need neither.

The spanning read still widens a day at each end: for the ordinary local-typed
timestamp the stored instant and the components agree, but a UTC-typed
`dateFrom` (imported data) can sit up to 14 hours off the reader-local range.
Bucketing discards whatever falls outside.

**Which weeks** to compute still follows the reading device's calendar — "recent"
means recent to the user. Two devices straddling a Monday boundary may therefore
compute different *sets*, but never different *values*, so nothing flaps.

```mermaid
stateDiagram-v2
  state "v1 week_rollup:<Monday>" as V1
  state "v2 week_rollup_v2:<Monday>" as V2
  [*] --> V1: written by a build before the canonical rule
  [*] --> V2: written by this build, stamped recordedLocal
  V1 --> V1: never rewritten — inert, and never read again
  V1 --> V2: tombstone only, carried onto the new generation
  V2 --> V2: recompute (write skipped when unchanged and stamped)
```

The generations are **separate rows**, not one row migrated in place: nothing
rewrites a v1 register. A week gets a fresh v2 register computed from source,
and the v1 row is consulted only for its tombstone.

**The register id carries a generation: `week_rollup_v2:<Monday>`.** During a
staggered upgrade a device still on the previous build recomputes the *old* id
with the old reader-local rule and writes it back unstamped; had both
generations shared an id, the two builds would have overwritten each other for
as long as the rollout lasted — the exact loop this change exists to end.
Old-generation rows are inert with one exception: their **tombstones** are
still read, and carried forward. A week the user deliberately deleted must not come back to life
because the id generation changed underneath it, so `ensureWeekRollups` checks
the v1 id's tombstone before creating a v2 register — and, when a peer that had
not yet received that tombstone already created a live v2 row, applies the
deletion to it rather than merely skipping the recompute.

`WeekRollupEntity.bucketingRule` records which rule produced a register:
`recordedLocal` for canonical, null for legacy. The steady-state
skip-when-unchanged check requires the stamp as well as matching numbers —
matching numbers on a legacy register are a coincidence, not evidence.

`recentWeekRollups` renders **canonical registers only**. `ensureWeekRollups` is
fail-soft, so a refresh that threw part-way can leave legacy registers live
beside migrated ones; rendering both would feed the digest two bucketing rules
in one section without saying so. A failed migration therefore shows up as an
absent week rather than as a wrong trend.

# The other two upward channels

They predate this protocol and still carry their own traffic:

- **Day summaries** — `write_day_summary` → `<recent_days>`, carrying the
  distilled narrative. See [wake context](wake-prompt.md).
- **`propose_knowledge`** — coordinator-keyed even on per-day wakes, so durable
  learnings land in the coordinator's confirm loop directly.

# Visibility: the status chip

The Day page header shows a `DayAgentStatusChip` when the day's agent has
something to say.

```mermaid
stateDiagram-v2
  [*] --> idle
  idle --> working: wake for this day starts
  working --> idle: wake ends, no newer status event
  working --> attention: wake ends, newest event attentionNeeded
  working --> celebrating: wake ends, newest event dayClosed
  attention --> working: wake for this day starts
  celebrating --> working: wake for this day starts
  attention --> celebrating: newer dayClosed event
  celebrating --> attention: newer attentionNeeded event
  note right of working
    A running wake always wins;
    otherwise the NEWEST status
    event decides (onTrack or
    none means idle).
  end note
```

Idle renders nothing. The tooltip adds per-day token spend **for per-day
identities only** — coordinator-owned days show none, because the coordinator's
lifetime aggregate would misattribute other days. Tapping opens agent internals,
the same destination as the header menu's "Inspect agent" entry.

Both facts come from `state/day_agent_persona_provider.dart`:
`dayAgentPersonaStateProvider` (the ADR §7 persona contract the character
animation will bind to) and `dayAgentTokenSpendProvider` (`getTokenUsageForAgent`
by agent id — **no new storage**).
