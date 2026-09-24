# ADR 0068: Model-Checked Convergence of Synced Agent Entities

- Status: Accepted
- Date: 2026-09-24

## Context

Every agent entity — state rows, knowledge, scheduled wakes, nudges, version
heads — is replicated across devices and resolved on arrival by one rule:
causal dominance by vector clock, then, for concurrent versions, a
type-specific override, `updatedAt` last-writer-wins and a canonical clock
tiebreak, with agent-state G-counters joined (ADR 0022). The resolver is pure,
and the claim was that purity makes every device pick the same winner. A pure
*pairwise* rule is not enough: the result must not depend on the order in
which a replica receives the versions, and the writes being compared are not
only the ones the resolver sees — local writes, device-local bookkeeping and
snapshot writers all shape the row.

After ADR 0065 and ADR 0066 we wrote the replication down in TLA+ —
`specs/tla/AgentReplication.tla` (three replicas, any delivery order,
duplication), `specs/tla/AgentStateWrites.tla` (the writers of one state row)
and `specs/tla/VersionHeads.tla` (version rows and their head) — and
model-checked them with TLC. The holes came back as concrete traces:

1. **The throttle split replicas for good.** `WakeThrottleCoordinator` wrote
   its device-local `nextWakeAt` straight to the repository and stamped
   `updatedAt` with the local clock. Peers never saw that timestamp, so a
   concurrent version that every other replica took lost on this one.
2. **A causal successor erased merged increments.** A concurrent conflict
   joined agent-state G-counters into the row but kept the winner's clock;
   a later version that succeeded the winner alone — without the loser's
   increments — then replaced the row by causal dominance, and the increment
   was gone.
3. **Stale and unclocked local writes diverged.** A local write replaced the
   row unconditionally, under the clock it was built on. Built on a
   wake-start snapshot or on `vectorClock: null`, it was concurrent with the
   row it replaced; the writer kept it while every peer resolved the pair the
   other way — a retraction revived on one device only, an own increment
   dropped.
4. **A successor could sort before its predecessor.** A write on a lagging
   clock carried an older `updatedAt` than the row it succeeded, so a third
   concurrent version could beat it but not its predecessor, and the arrival
   order decided the result.
5. **The end-of-wake state write erased what happened during the wake.** The
   task agent wrote its outcome (failure count, wake counter, `lastWakeAt`)
   as a copy of the state it read when the wake started, putting back the
   report-stale watermark that a subscription event had moved meanwhile — the
   report then read as fresh although something changed while it was being
   written. Its failure path did the same.
6. **A goal revision left a disconnected twin active for ever.** Two devices
   can each mint an active v2; the head resolver keeps one, and a revision
   superseded only the head's version, so the twin stayed active through
   every later revision and its banners were never swept.

## Decision

1. **Device-local writes never touch the synced timestamp.** The throttle
   writes `nextWakeAt` without `updatedAt`, like every other device-local
   scheduling write already did.
2. **One receive-path decision, shared.** `resolveAgentEntityVersions` is the
   whole decision the sync processor applies, and it joins agent-state
   G-counters and report watermarks on every delivery, causal or concurrent
   (`joinConvergentAgentFields`). The winner keeps its own clock.
3. **A local write succeeds the row it replaces.** For every mutable register
   (a variant ordered by `updatedAt`) `AgentSyncService._upsertEntityRaw`
   reads the persisted row in the write's transaction, stamps the write with
   a clock covering both, and persists what `resolveLocalAgentWrite` returns:
   a write built on the row keeps its fields; a write built on a stale
   snapshot or on no clock is resolved against the row as if concurrent —
   which is what every peer holding the row decides too; G-counters and
   report watermarks never go down; and `updatedAt` never moves back. What
   the writer keeps is what the replicas converge on.
4. **State outcomes are transforms of the current row.** The task agent's
   success and failure writes, the day agent's failure write and the project
   agent's dormant skip go through `AgentSyncService.updateAgentState`, which
   re-reads the row in the transaction and applies a field-scoped change.
5. **A goal revision supersedes every active version,** as soul and template
   edits already archive every non-archived one.
6. **The models gate the code**, as in ADR 0065: the specs live in
   `specs/tla/`, CI model-checks them whenever they or the code they describe
   change, and a Glados trace drives three real `AgentSyncService` replicas
   through generated writes and arrival orders and checks the same
   invariants.

## Consequences

- `Converged`, `NoLostSuccessor`, `OwnCountKept` and `NoLostIncrement` hold
  for three replicas with stale and unclocked writes and one tick of clock
  skew; `NoLostWatermark`, `FreshIsHonest`, `FailureStreakExact` and
  `NoLostWake` hold for a state row's writers; version heads converge, and
  one clean edit settles their statuses.
- A local write to a mutable register costs one primary-key read in its
  transaction. Append-only variants skip it.
- A stale write can now lose locally, exactly as it loses on every peer: an
  edit built on a snapshot older than a retraction does not revive it, and a
  lease claim built on an old read is resolved against the claim that
  replaced it the way every peer resolves it, so all devices agree on one
  survivor.
- A row's `updatedAt` can be later than the writing device's clock, when a
  peer with a faster clock wrote the row it succeeds.
- Residuals, documented in `specs/tla/README.md`:
  - **A successor that ranks below its predecessor** — the digest retry
    re-arming its consumed window at the same instant, a relationship retry
    moved to an earlier instant — still lets arrival order decide against a
    third concurrent version. Closing it needs the override rank to grow along
    every causal edge: a generation field that sync carries and older clients
    preserve, or re-arming under a new record id. That is a protocol change.
  - **Nudges on an exact `updatedAt` tie** keep the joined clock their merge
    stores, so the canonical tiebreak can resolve them differently on
    different replicas.
  - **Version statuses** can disagree with the head after concurrent edits
    (twin actives, a head naming a version another device archived) until the
    next edit. Every read resolves the active version through the head.
  - `consecutiveFailureCount` across devices stays last-writer-wins.

## Addendum (2026-09-24): writes meant to move the row back

Decision 3 resolves a local write built on a null or stale clock as if it
were concurrent with the persisted row. Under plain last-writer-wins that is
harmless — the clamped, newer `updatedAt` wins — but a write whose whole
point is to move the row *against* the resolver's order is then handed the
row back: under a type override (a pre-warm moved to an earlier deadline,
fixed with ADR 0069), or under last-writer-wins on an equal or skewed
timestamp. An audit of every local writer of the override types and of the
version-head registers found:

- **Report heads** (task, project, event, goal and relationship agents) were
  written with `vectorClock: null` over the head they had just read. A
  second report for the same overdue period stamps the same instant, and a
  head stamped by a peer whose clock runs ahead is newer still; in both the
  new report never became the standing one, on this device or any other.
- **Soul and template heads** moved to a new version the same way, so under
  clock skew an edit created its version but left the head — and every
  prompt — on the old one.
- **Goal-progress registers** carried the row the derivation read, which a
  report refresh reads before its inference; a same-ordinal twin's row that
  synced in meanwhile was judged concurrent, and the goal-progress resolver's
  id order could put the twin's evaluation back until the next tick.

Every one of them now carries the clock of the row it replaces, read in the
same transaction: the write is that row's causal successor, keeps its fields
and still never moves `updatedAt` back. The other writers of override types —
knowledge, day summaries, nudge lifecycle and interactions, goal spec heads,
the scheduled-wake writers outside ADR 0069 — already build on the row they
read, or only move forward in the resolver's order.

`AgentReplication.tla` gains the class as a write kind, `Intend`: a write
built on the row that moves it out of the terminal status, or to new fields
at the row's own timestamp. `LocalWriteTakesEffect` holds when it carries the
row's clock (`IntentCarriesClock`) and fails without it. A successor that
leaves a terminal status still ranks below its predecessor, so the terminal
configuration claims only that property; convergence there remains the
`RankDrop` residual above.

## Related

- `specs/tla/AgentReplication.tla`, `specs/tla/AgentStateWrites.tla`,
  `specs/tla/VersionHeads.tla`, `specs/tla/README.md`
- [Agent persistence and sync](../../knowledge/features/agents/persistence-and-sync.md)
- [Vector clocks and conflicts](../../knowledge/features/sync/vector-clocks-and-conflicts.md)
- [ADR 0022: Long-lived Daily OS planner](./0022-long-lived-daily-os-planner.md)
- [ADR 0065: Model-checked sync sequence reservations](./0065-model-checked-sync-sequence-reservations.md)
- [ADR 0066: Model-checked agent wakes and confirmations](./0066-model-checked-agent-wakes-and-confirmations.md)
