# Formal specs

TLA+ models of the protocols in this app that are too concurrent to trust to
prose, model-checked with TLC. A spec here describes the code as it is: a
change to the modelled code updates the spec in the same pull request, and CI
(`.github/workflows/tla-model-check.yml`) re-checks it whenever either moves.

## Running

```sh
make tla_check                      # every configuration
specs/tla/tlc.sh SyncSequenceCrash  # one configuration
```

`tlc.sh` needs Java 11 or newer (`JAVA=/path/to/java` if it is not on `PATH`).
It downloads the pinned `tla2tools.jar` once, verifies its SHA-256, and caches
it in `TLA_TOOLS_DIR` (default `~/.cache/lotti-tla`). A configuration
`<Spec><Variant>.cfg` checks `<Spec>.tla`.

CI discovers all checked-in `.cfg` files and runs each on its own runner with
`fail-fast: false`. Adding a configuration automatically adds a shard. The
aggregate `TLC` check passes only when discovery and every shard succeed;
local `make tla_check` still runs all configurations sequentially.

## `SyncSequence` — the sync sequence log and backfill

One originating device and its peers: counter reservation, the payload write,
the outbox bind, releases and burns, startup reconciliation, backfill requests
and responses, and gap detection on the receivers. The mapping from each action
to the Dart code is in the spec's header; the protocol itself is described in
[Sequence log and backfill](../../knowledge/features/sync/sequence-and-backfill.md)
and the decision in [ADR 0065](../../docs/adr/0065-model-checked-sync-sequence-reservations.md).

| Property | Kind | Says |
|----------|------|------|
| `NoFalseBurn` | invariant | no device ever burns a counter whose payload committed |
| `ReceivedIsReal` | invariant | a peer's `received`/`backfilled` row is backed by that data or newer |
| `BoundRowsHavePayload` | invariant | the originator only answers from rows whose payload is on disk — the write that reserved the counter, not merely whatever the row names |
| `BurnedIsTerminal` | action | `burned` has no outgoing edge on any device |
| `EventuallyDelivered` | liveness | every committed write reaches every peer |
| `NoStuckRequest` | liveness | every backfill request is settled by the protocol, not by giving up |

| Configuration | Crashes | Faults | Unnamed reservations | Checks |
|---------------|---------|--------|----------------------|--------|
| `SyncSequence` | 0 | none | allowed | all |
| `SyncSequenceCrash` | 1, anywhere | none | no | all |
| `SyncSequenceCrashUnnamed` | 1, anywhere | none | allowed | safety |
| `SyncSequenceCrashFault` | 1, anywhere | any one of the faults below | no | safety |
| `SyncSequenceFaults` | 0 | any two of: reserved-row insert (settings fallback taken), reserved-row insert and fallback both, bind, post-commit throw, enqueue, burn broadcast, event loss | no | safety |

All five pass with two entities, three counters and one peer — between 0.8 and
4.4 million distinct states each (`SyncSequence` 1,015,081,
`SyncSequenceCrash` 777,611, `SyncSequenceCrashUnnamed` 3,022,767,
`SyncSequenceCrashFault` 4,357,689, `SyncSequenceFaults` 3,015,653), a few
minutes in total.

The name a reservation records is modelled separately from the entity its
write targets (`named` versus `ent`), because settlement can only look the
payload up by the name. `MisnamedReservations = TRUE` lets a reservation name
another entity — what `createTaskEntry`, `createAiResponseEntry` and
`createRelationship` did when they swapped a caller's id in after reserving
([ADR 0077](../../docs/adr/0077-a-reservation-names-the-id-written.md)). With
one crash, TLC breaks `NoFalseBurn` in five steps (reserve counter 1 for `e1`
naming `e2`, commit, crash, settle: `e2` does not cover 1, so the committed
counter is burned) and `BoundRowsHavePayload` in seven (counter 2 of `e2`
commits, so settlement binds counter 1 to `e2` although `e1` never landed).
Every checked-in configuration sets it `FALSE`; the naming rule is what the
code now guarantees.

What the configurations deliberately leave out:

- **Delivery under faults.** A swallowed enqueue failure or an event a peer
  abandons for good is not retried, so `EventuallyDelivered` is only claimed
  without faults.
- **Unnamed reservations after a crash.** They cannot be settled, so a request
  for one stays open until the requester gives up — which is why
  `SyncSequenceCrashUnnamed` checks safety only.
- **Counter 0.** Counters start at 1, as `VectorClockService` has since
  [ADR 0080](../../docs/adr/0080-a-present-counter-ranks-above-an-absent-host.md).
  Hosts that older builds created handed out a counter 0 first. It lies
  outside gap detection and the contiguous-prefix watermark, so if its
  message is lost it is never requested; the next version of the same
  payload carries its clock.

## `OwnCounterSettlement` — recovery interleavings

This focused safety model expands the atomic settlement and fallback migration
in `SyncSequence`. It separates the sequence-row read, settings read, migration
insert/removal, durable enqueue and binding. An earlier answer in the same batch
may silently fail to enqueue, or enqueue version 2 before version 3 commits.

The configuration checks `TypeOK`, `NoFalseBurn` and `BoundHasQueuedPayload`
across 160 distinct states. It models one named, inactive reservation and two
payload versions. No write can still commit the requested counter after the
settlement reads start. Payload purges, unavailable stores, retries, peers and
crashes are outside this focused model; it claims safety, not delivery liveness.

The recovery guards have mutation switches. In a temporary copy of the configuration,
set one switch to `FALSE` and run TLC against `OwnCounterSettlement.tla`:

| Mutation | Expected counterexample |
|----------|-------------------------|
| `RecheckSequence = FALSE` | `NoFalseBurn`: the first row read misses, migration inserts the row and removes the settings fallback, the second read misses, settlement burns the committed counter |
| `RequireDurableEnqueue = FALSE` | `BoundHasQueuedPayload`: an earlier batch answer attempts a resend, its enqueue fails (or queues an older version), settlement skips its own enqueue and binds |
| `RequireFreshDescriptor = FALSE` | `BoundHasQueuedPayload`: journal descriptor refresh fails, enqueue uses an older sidecar and settlement binds the newer counter |

Keep mutation configurations outside this directory: CI runs every checked-in
configuration and expects each to pass. The handler suite has deterministic
regressions for both races, newer payload versions, migrated unnamed/already
settled rows, and a failed sequence-log recheck. Reverting the Dart guards makes
those regressions fail. The outbox enqueue suite also checks that descriptor
refresh failure prevents both ordinary and durable enqueue, then verifies a
successful retry queues the refreshed version.

## `WakeRuntime` — agent wakes

This model covers generic wakes. Daily OS processing jobs are recovered by
their own durable outbox and never replayed by `WakeIntentStore`.

Triggers become queued jobs, the drain dispatches a job when its agent's runner
lease is free, and an executor runs the wake. An abort — a cancel, the
ten-minute run cap, a stale-drain reset — releases the lease, but a Dart future
cannot be cancelled, so the executor runs on. Wake intents persist until a run
covering them completes, and startup restores them. A run covers some of its
agent's queued triggers, not necessarily all: the queue can hold several jobs
for one agent. The decision is
[ADR 0066](../../docs/adr/0066-model-checked-agent-wakes-and-confirmations.md);
the runtime is described in
[Wake orchestration](../../knowledge/features/agents/wake-orchestration.md).

| Property | Kind | Says |
|----------|------|------|
| `SingleFlight` | invariant | at most one live executor per agent, short of one declared hung |
| `HungOnlyWhenDetached` | invariant | only an executor that lost its lease is ever declared hung |
| `NoLostWake` | liveness | every trigger is eventually covered by a run that completes |

| Configuration | Agents | Triggers | Crashes | Aborts | Distinct states |
|---------------|--------|----------|---------|--------|-----------------|
| `WakeRuntime` | 2 | 4 | 0 | 2 | 46,073 |
| `WakeRuntimeCrash` | 2 | 4 | 1 | 1 | 437,257 |

## `ChangeSetConfirm` — confirming a proposed change

One change-set item, confirmed or rejected by concurrent callers — a double
tap, a "Confirm all" racing a single confirm, a swipe-reject racing either, a
retry — through the claim, the post-commit outbox flush, the tool dispatch
and the post-confirm hook. A
reject claims the item the same way a confirm does. The ghost `applied` counts
how often the change actually took effect.

| Property | Kind | Says |
|----------|------|------|
| `AtMostOnceApply` | invariant | a confirmed change takes effect at most once |
| `RejectedMeansNotApplied` | invariant | an item shown rejected never took effect |
| `ConfirmedMeansApplied` | invariant | an item shown confirmed, with no confirm in flight, took effect |

| Configuration | Callers | Faults | Crashes | Checks | Distinct states |
|---------------|---------|--------|---------|--------|-----------------|
| `ChangeSetConfirm` | 2 | outbox flush fails, dispatch fails, hook throws | 0 | all three | 117 |
| `ChangeSetConfirmFaults` | 2 | outbox flush fails, dispatch fails, hook throws | 1 | all but `ConfirmedMeansApplied` | 220 |

Two cases are known residuals rather than checked properties. Adding
`"failsAfterEffect"` to `Faults` — a tool that throws after its effect landed,
which the service reverts to `pending` — breaks `AtMostOnceApply` on retry, and
checking `ConfirmedMeansApplied` with a crash breaks it when the process dies
between the claim and the dispatch. Closing either needs an `applying` status
that sync and the UI understand, or tools that are idempotent per decision id.

## `ChangeSetLifecycle` — a whole change set, across devices

`ChangeSetConfirm` checks one item on one device. This model checks what
happens between the items of a set and between its replicas: every writer of
the set — the claim, a failed dispatch's revert or auto-retraction, the
follow-up task's rewrite of its migration's `targetTaskId`, the migration
cascade, a staged retraction, a wake's consolidation of an older set, the
user's reopen — and the sync that carries each write to the other devices as
a message delivered in any order, applied through the vector-clock comparison
and the concurrent resolver. It also models what a confirmed change does to
the journal on each device: a create-style item creates an entity (modelled
by id), a set-style item writes one task field (a register the user can edit
too), and both replicate by message and are received the way the journal
receives them — a concurrent version is kept aside as a `Conflict` row. Every
user decision runs in its own attempt slot, so a confirm of an item reopened
while an earlier dispatch still runs is a second, concurrent operation. The
ghost `applied` counts, per device, how often each change was dispatched and
took effect. The decisions are
[ADR 0067](../../docs/adr/0067-model-checked-change-set-lifecycle.md) and
[ADR 0075](../../docs/adr/0075-idempotent-change-set-tools.md).

The switches are the fixes, and each is a mutation point. From ADR 0067:
`AtomicWrites` (every local write of a set re-reads it in its transaction and
changes only its own item), `AtomicReceive` (sync compares and writes a
received set in one transaction), `ItemMerge` (concurrent versions merge item
by item by a per-item revision), `PendingCopiesOnly` (consolidation moves only
pending items) and `RevisionGuard` (a failed dispatch moves its item only
while the item holds the revision its claim wrote). From ADR 0075:
`ClaimResolvesTarget` (a migration resolved from the in-memory mapping is
claimed with its resolved target), `DerivedIds` (a create-style tool derives
its entity's id from the item's effect key and does nothing when the entity
exists), `CopyCarriesKey` (a consolidated copy carries its original's key) and
`CasGuard` (a set-style tool writes only while the field holds the value the
proposal was made against) and `ReuseLive` (where a created entity and its
link to a parent sync apart — a checklist and the task update listing it — a
device holding the entity without its link writes nothing, since the
creator's link is on its way; switched on by `SeparateAttach`).
`CrashBeforeLink` is not a fix: it lets the creator stop between the entity
and its link. `RaceFree` restricts the environment: no item is
decided on two devices before they have synced. `UserRestoresBase` lets the
user's edit restore the base value, the ABA a value compare-and-set cannot
see.

| Property | Kind | Says |
|----------|------|------|
| `AtMostOnceApply` | invariant | a change is dispatched and takes effect at most once, across all devices |
| `AtMostOncePerDevice` | invariant | ... and at most once per device |
| `AppliedStaysDecided` | invariant | a device that applied a change never shows it pending again — no decided item returns to pending except by its own failed dispatch |
| `StatusMatchesEffect` | invariant | once everything is delivered, every device shows `confirmed` exactly when the change was applied, and never `pending` or `rejected` for an applied one |
| `Converged` | invariant | once everything is delivered, the replicas of the set agree |
| `MigrationAfterTarget` | invariant | a checklist migration never runs before its follow-up task exists |
| `NoDuplicateEffects` | invariant | every change creates at most one entity id, across all replicas and the messages in flight |
| `NoClobber` | invariant | no dispatch overwrites a value the user wrote into the field |
| `EffectsConverge` | invariant | once everything, entities and fields included, is delivered, every replica holds the same entities, the field agrees unless a `Conflict` row holds a concurrent version, and a change's entity exists exactly when the change was applied somewhere |
| `SucceededClaimStands` | invariant | an item whose latest claim's dispatch succeeded reads `confirmed` |
| `EffectsLinked` | invariant | with `SeparateAttach`: once everything is delivered, every created entity is linked to its parent on every device |

| Configuration | Devices | Items | Checks | Distinct states |
|---------------|---------|-------|--------|-----------------|
| `ChangeSetLifecycle` | 1 | follow-up, migration, plain; both failure kinds; retraction | `AtMostOnceApply`, `AppliedStaysDecided`, `StatusMatchesEffect`, `MigrationAfterTarget`, `NoDuplicateEffects` | 2,643 |
| `ChangeSetLifecycleConsolidate` | 1 | an older set's item and its consolidated copy | as above, without `MigrationAfterTarget` | 133 |
| `ChangeSetLifecycleSync` | 2 | two plain items, `RaceFree` | as `ChangeSetLifecycle` without `MigrationAfterTarget`, plus `Converged`, `EffectsConverge` | 847,082 |
| `ChangeSetLifecycleSyncSplit` | 2 | follow-up and migration, `RaceFree` | all but `NoClobber`, `SucceededClaimStands` | 79,082 |
| `ChangeSetLifecycleRace` | 2 | one create-style item decided on both devices, retryable failures | `Converged`, `NoDuplicateEffects`, `EffectsConverge` | 491,402 |
| `ChangeSetLifecycleRaceSet` | 2 | one set-style item decided on both devices, one user edit per device, retryable failures | `Converged`, `NoClobber`, `EffectsConverge` | 852,966 |
| `ChangeSetLifecycleReopen` | 1 | one item, two confirms, one reopen, both failure kinds | `SucceededClaimStands`, `NoDuplicateEffects` | 90 |
| `ChangeSetLifecycleConsolidateSync` | 2 | an item consolidated on one device while confirmed on the other, `RaceFree` | `NoDuplicateEffects`, `EffectsConverge` | 147,557 |
| `ChangeSetLifecycleRaceLink` | 2 | one create-style item decided on both devices, whose entity and link to its parent sync apart | `Converged`, `NoDuplicateEffects`, `EffectsConverge`, `EffectsLinked` | 241 |

Every configuration also checks `TypeOK`. Each switch set to `FALSE` fails a
configuration with a short trace (kept outside this directory, as for
`OwnCounterSettlement`):

| Mutation | Configuration | Counterexample |
|----------|---------------|----------------|
| `AtomicWrites = FALSE` | `ChangeSetLifecycle` | `AppliedStaysDecided` (8 states): the follow-up task's dispatch fails and its revert reads the set; the plain item is claimed and applied; the revert writes its copy back, putting the applied item to pending. With every switch off, a retry applies the plain item a second time (`AtMostOnceApply`, 10 states) |
| `AtomicWrites = FALSE` | `ChangeSetLifecycleSyncSplit` | `AppliedStaysDecided` (7 states): the sibling rewrite reads the set, the migration is claimed and applied, the rewrite writes the migration back as pending |
| `PendingCopiesOnly = FALSE` | `ChangeSetLifecycleConsolidate` | `StatusMatchesEffect` (5 states): an item is claimed, a wake consolidates and copies it as `confirmed`, the dispatch fails and reverts the original — the copy claims a change that never landed |
| `ItemMerge = FALSE` | `ChangeSetLifecycleSync` | `AppliedStaysDecided` (5 states): one device rejects an item while the other confirms a different one; receiving the rejecting device's row, the whole-row winner drops the confirm, and the confirming device then applies a change its row shows pending |
| `AtomicReceive = FALSE` | `ChangeSetLifecycleSync` | `AppliedStaysDecided` (6 states): a device reads its row to apply a peer's version, claims an item meanwhile, and writes the peer's version over the claim |
| `RevisionGuard = FALSE` | `ChangeSetLifecycleReopen` | `SucceededClaimStands` (7 states): the first confirm's dispatch runs, the item is reopened and confirmed again, the first dispatch fails and reverts the second claim, whose dispatch then succeeds on a pending item |
| `ClaimResolvesTarget = FALSE` | `ChangeSetLifecycle` | `StatusMatchesEffect` (7 states): the follow-up task is applied and mapped in memory, the migration is claimed through the mapping, the sibling rewrite bumps the claimed item's revision, and the migration's failed dispatch can no longer revert its own claim — confirmed, never applied |
| `DerivedIds = FALSE` | `ChangeSetLifecycleRace` | `NoDuplicateEffects` (6 states): both devices confirm and dispatch the item; each mints its own id |
| `DerivedIds = FALSE` | `ChangeSetLifecycleReopen` | `NoDuplicateEffects` (6 states): confirm, apply, reopen, confirm, apply — two entities |
| `CopyCarriesKey = FALSE` | `ChangeSetLifecycleConsolidateSync` | `NoDuplicateEffects` (7 states): one device confirms and applies the original, the other consolidates it into a copy of its own key; the copy is confirmed and creates a second entity |
| `ReuseLive = FALSE` | `ChangeSetLifecycleRaceLink` | `NoDuplicateEffects` (6 states): one device confirms, creates the checklist and lists it; the other receives the checklist but not the task update listing it, confirms, and creates a second checklist |
| `CasGuard = FALSE` | `ChangeSetLifecycleRaceSet` | `NoClobber` (4 states): the change is confirmed, the user edits the field, and the dispatch overwrites the edit |

What stays open — the residuals, each confirmed by TLC:

- **The same item decided on two devices before they sync** is still
  dispatched on both — no local transaction can prevent it — but for the
  tools ADR 0075 covers it no longer applies twice. `ChangeSetLifecycleRace` checking `AtMostOnceApply` still
  fails in 5 states (confirm and dispatch on each device), while
  `NoDuplicateEffects`, `NoClobber` and `EffectsConverge` hold. What the
  effects do not cover:
  - **Both devices create before either has the other's entity.** One id,
    and the journal keeps the other version as a `Conflict` row for the user,
    because the two versions differ in their creation timestamps. A silent
    merge would need identical content and a journal rule that merges
    identical concurrent versions — a product decision. Two concurrent
    applications of a field change land as a conflict the same way.
  - **The field's ABA.** A user who restores the field to the proposal's base
    between the two applications gets the proposed value again
    (`ChangeSetLifecycleRaceSet` with `UserRestoresBase = TRUE` violates
    `NoClobber` in 4 states).
  - **The status records the dispatch, not the effect.** When one device's
    dispatch fails and reverts while the other's applied, the merged item
    reads pending though its change landed; confirming it again applies
    nothing. `StatusMatchesEffect` and `AppliedStaysDecided` are therefore
    not checked under the race. A confirm beating a concurrent rejection or
    retraction (the merge rank) is *not* part of this residual: it is
    checked.
  - Tools without an effect key or a base — label assignment (a set-add, so
    a late add can bring back a label removed in between), checklist item
    updates, time entry updates, and the project agent's tools — are listed
    per tool in ADR 0075.
- **Consolidation on one device racing a decision on another** no longer
  applies anything twice: the copy carries its original's key. It stays
  pending beside the original applied elsewhere
  (`ChangeSetLifecycleConsolidateSync` checking `StatusMatchesEffect` fails in
  7 states); confirming it is a no-op. A set holding a migration whose follow-up is
  unresolved is not folded at all (`ChangeSetDependency`), so only plain
  pending items are ever copied, and a retained group's items keep their
  position as their effect key.
- **Concurrent sets whose items do not align** — different proposals at one
  index — fall back to the whole-row winner, as before, and with three or
  more versions that fallback can depend on arrival order (the joined clock
  under the canonical tiebreak, as for nudges in `AgentReplication`). The
  aligned merge cannot: `MergeItem` breaks an exact tie by content, never by
  the clock order. The model's items are fixed and it runs two devices, so
  it covers neither case.
- **A checklist its creator never linked.** With `CrashBeforeLink = TRUE`,
  `ChangeSetLifecycleRaceLink` violates `EffectsLinked` in 5 states: the
  creator writes the checklist and stops before the task update that lists
  it, and the other device, holding the checklist, has nothing to add and
  writes nothing. The code matches: only a replay that still creates an item
  lists the checklist (`derivedChecklistFor`), and that listing can raise a
  task conflict when it races the creator's own — chosen over leaving the new
  item in a checklist the task never shows. A replay with nothing to add
  stays a no-op, because a relink would conflict with the creator's listing
  in the common case.
- **Clients that predate the item revision, `effectKey` and `base`** strip
  them when they rewrite a set. An item without a revision is merged by
  status alone — never as revision 0, which would let a newer-build target
  rewrite beat a confirm the older build applied — so a newer-build revert
  racing an older build's confirm keeps the confirm. A copy without its key
  falls back to its own position, and a field change without a base applies
  unconditionally.
- **The model's steps are coarser than the code's** in one place TLC used:
  `ClaimResolvesTarget`'s counterexample needs the sibling rewrite's
  transaction to start after the migration's claim, which today's scheduling
  does not allow — the capture and that transaction request run in one
  continuation. The fix removes the dependence on it.

## `ChangeSetDependency` — consolidation preserves follow-up ownership

A follow-up and its pending migration share one set. Completing the follow-up
rewrites that set's migration target; rejecting it cascades to that set's
migration. Moving the migration while either operation is in flight would
leave the copy pointing at an unresolved placeholder, away from the sibling
that makes the confirmation service recognize it as a placeholder.

| Configuration | Scope | Checks | Distinct states |
|---------------|-------|--------|-----------------|
| `ChangeSetDependency` | one device, pending/claimed/rejected follow-up, completion/cascade and consolidation into a newer set | `MigrationAfterTarget`, `DependencyOwned`, `CompletionReachesMigration` | 14 |

`KeepDependenciesTogether = TRUE` keeps the group at its original set id until
its pending migration has a resolved target. Setting it to `FALSE` restores
moving the migration away and violates `DependencyOwned`; the mutation config
is run outside the checked-in CI configuration set. This is one-device
dependency ownership, not a fix for the cross-device duplicate-application
residual above.

The builder's Dart regressions cover pending, claimed and rejected follow-ups,
the placeholder guard, completion's durable target rewrite, later
consolidation and successful migration, and incremental appends that keep the
original set id. Restoring consolidation of unresolved groups fails all three
parent-status regressions.

## `ScheduledWakeLease` — one device per scheduled window

One scheduled-wake record that must run on exactly one device — a goal or
relationship escalation, the coordinator digest, a goal chat recovery —
replicated on every device as a vector-clocked register. A device claims the
due record, waits out the settle, confirms its claim survived, queues the wake
and consumes the record; a lapsed claim may be taken over. The model carries
wall-clock time (a message is delivered within `MaxDelay` of being sent to a
running device, and the manager's timers act as soon as they can), the
resolver's scheduled-wake rule, the wake's intent in the settings database,
crashes with restart, and devices that never return. A window is ordinal:
arming over a consumed row of window k opens k + 1. The decision is
[ADR 0069](../../docs/adr/0069-model-checked-scheduled-wake-leases.md); the
runtime is described in
[the coordination protocol](../../knowledge/features/daily_os_next/coordination-protocol.md#one-device-per-window-elected-by-the-register-itself).

| Property | Kind | Says |
|----------|------|------|
| `AtMostOnce` | invariant | no window runs to completion twice |
| `NoDeviceRunsTwice` | invariant | no device runs a window twice |
| `WindowTerminal` | invariant | a replica that held a window consumed never holds it pending again |
| `Converged` | invariant | once every write is delivered, the live replicas agree |
| `NoLostWindow` | liveness | every armed window is run to completion by some device |

| Configuration | Devices | Arms | Crashes | Deaths | Arm | Checks | Distinct states |
|---------------|---------|------|---------|--------|-----|--------|-----------------|
| `ScheduledWakeLease` | 2 | 2 | 0 | 1 | goal | all | 414,857 |
| `ScheduledWakeLeaseCrash` | 2 | 1 | 1 | 0 | goal | all but `AtMostOnce` | 192,707 |
| `ScheduledWakeLeaseCrashRearm` | 2 | 2 | 1 | 0 | goal | safety but `AtMostOnce` | 6,640,286 |
| `ScheduledWakeLeaseThree` | 3 | 2 | 0 | 1 | relationship (if absent) | safety | 4,202,509 |

The settle is three time units, the lease five and the sync delay one: the
settle must exceed twice the delay — a crossing claim sent just before the
first claim arrives lands one delay later — as three minutes exceed any
connected sync. Each fix has a switch; in a temporary copy of a configuration
outside this directory, set it to the old behaviour and run TLC against
`ScheduledWakeLease.tla`:

| Mutation | Configuration | Counterexample |
|----------|---------------|----------------|
| `ArmMode = "fresh"` (a null clock at the period's instant) | `ScheduledWakeLease` | `NoLostWindow`: B arms, claims, runs and consumes window 1; A re-arms window 2 from a null clock, which is concurrent with B's consumed copy, so B keeps it; A claims and dies — window 2 never runs. `Converged` fails on the way |
| carried clock, same instant (`ArmAt(r) == 1`, a spec copy) | `ScheduledWakeLeaseCrashRearm` | `WindowTerminal`: B is down across A's lease; A runs and consumes window 1 and arms window 2; B restarts, takes window 1 over on its stale replica, and its claim, concurrent with window 2 and newer, wins on A |
| `FlushBeforeConsume = FALSE` | `ScheduledWakeLeaseCrash` | `NoLostWindow`: A fires and consumes, then crashes before the intent write lands |
| `OwedCheck = FALSE` | `ScheduledWakeLeaseCrash` | `NoDeviceRunsTwice`: A fires, flushes the intent and crashes before consuming; after the restart the record fires again beside the restored wake |
| `ConsumeCurrentRow = FALSE` | `ScheduledWakeLeaseCrashRearm` | `Converged`: a restarted device consumes the window it fired from its snapshot over the next window that had synced in |

`FlushIntent` represents a successful settings write. A failed write leaves
the intent pending, so `FlushBeforeConsume` also requires failures to propagate
through the Dart durability barrier; every consume of an owed wake waits for
that barrier. The store and scheduler regression tests cover failure and retry.

Two residuals are properties the design does not claim, each shown by a
configuration kept out of this directory:

- **`AtMostOnce` across a crash.** A device back from a crash acts on its own
  replica before sync has caught up: it confirms its settled claim and runs a
  window a peer took over and ran while it was down. That is ADR 0048's
  partition case, and a device resuming from sleep is the same. It is why the
  crash configurations check `NoDeviceRunsTwice` instead.
- **A run that settles before its own consume commits.** With
  `RunOutlastsConsume = FALSE`, a crash in between leaves the record pending
  and nothing owed, and the window runs again on the same device. The checked
  configurations assume an inference outlasts a local write.

A fencing token (ADR 0018 rule 2) was a suspected gap and is not one TLC can
show: with the settle above twice the sync delay a late confirmation cannot
fire beside a takeover, and where a device is suspended or offline across the
lease, what it spends is a model call, which has no side that could reject a
stale token.

## `GoalChatReply` — who answers a goal chat message

One message typed on its author device and synced to its peers. The author's
own wake answers it; a synced recovery record, due a grace later and elected
by the lease above (taken as given here), lets one device answer instead if
that never succeeds. Runs commit within `RunCap` unless their device is paused.

| Property | Kind | Says |
|----------|------|------|
| `AtMostOneReply` | invariant | the message is answered at most once |
| `Answered` | liveness | while a device lives, the message is answered |

| Configuration | Devices | Failed runs | Deaths | Distinct states |
|---------------|---------|-------------|--------|-----------------|
| `GoalChatReply` | 2 | 1 | 1 | 5,148 |
| `GoalChatReplyThree` | 3 | 1 | 1 | 99,268 |

`Recovery = "eager"` models the code before ADR 0069 — every device's
maintenance enqueued the oldest unanswered message, and any goal wake answered
it — and breaks `AtMostOneReply` in four steps: the author starts answering,
the peer's maintenance queues the same message, both commit. A first draft of
the fix re-armed the next recovery window at the last deadline plus the grace,
which can already be past; TLC found the second window firing while the first
recovery's run was still in flight on another device. The next window is now
due when the last one's lease lapses. The residuals mirror the lease's: a device
paused past the run cap (`MaxPauses = 1`), or one that crashes and restarts
before sync delivers the reply it missed (`MaxCrashes = 1`), answers beside
the device that took over.

## `AgentReplication` — converging synced agent entities

Three replicas of one synced agent entity. Local writes build on the
persisted row, on a wake-start snapshot, or on no clock at all
(`vectorClock: null`); a write's `updatedAt` may lag the wall clock, as
another device's can; the throttle coordinator writes device-local
bookkeeping; and the network delivers every write to every replica in any
order, any number of times. The receive path is
`resolveAgentEntityVersions` in `agent_concurrent_resolver.dart`, which
`SyncEventProcessor` applies; the local write path is
`AgentSyncService._upsertEntityRaw` with `resolveLocalAgentWrite`. `Kind`
picks the entity family: `"state"` is `AgentStateEntity` (whole-row
last-writer-wins plus per-host G-counters), `"terminal"` a type whose status
override outranks the timestamp (retracted knowledge, a consumed wake window,
a dismissed nudge). The decision is
[ADR 0068](../../docs/adr/0068-model-checked-agent-convergence.md).

| Property | Kind | Says |
|----------|------|------|
| `Converged` | invariant | once every write has reached every replica, all hold the same row |
| `NoLostSuccessor` | invariant | a row is never a version that a write it received causally replaced |
| `OwnCountKept` | invariant | a host always sees all of its own G-counter increments |
| `NoLostIncrement` | invariant | once everything is delivered, every replica sees every increment |
| `LocalWriteTakesEffect` | invariant | a write meant to move the row against the resolver's order keeps its fields on the writing device |

| Configuration | Kind | Replicas | Writes | Clock skew | Checks | Distinct states |
|---------------|------|----------|--------|------------|--------|-----------------|
| `AgentReplication` | state | 3 | 3 | 1 tick | all four | 17,318,265 |
| `AgentReplicationTerminal` | terminal | 3 | 3 | 1 tick | `Converged`, `NoLostSuccessor` | 9,544,635 |
| `AgentReplicationIntent` | state, with `Intend` writes | 3 | 3 | 1 tick | all five | 17,959,029 |
| `AgentReplicationIntentTerminal` | terminal, with `Intend` writes | 3 | 3 | 1 tick | `LocalWriteTakesEffect` | 16,350,444 |
| `AgentReplicationLegacyCounter` | state, with `Intend` writes; every host's first counter is 0 | 3 | 3 | 1 tick | all five | 17,959,029 |
| `AgentReplicationLegacyReceiver` | terminal; received by a build that reads an absent host as 0 | 3 | 3 | 1 tick | `Converged`, `NoLostSuccessor` | 9,544,635 |

A clock maps each replica to a counter or to `Absent`, and the properties use
the causal order, in which a present entry, 0 included, ranks above an absent
one. `FirstCounter` is a new host's first counter: 1 since
[ADR 0080](../../docs/adr/0080-a-present-counter-ranks-above-an-absent-host.md),
0 on every host an older build created. The two legacy configurations cover
the two halves of a fleet in which not every device has updated: this build
receiving clocks from hosts that started at 0, and an older build receiving
clocks from hosts that start at 1. The configurations with `FirstCounter = 1`
have the same state counts as before the clocks could hold `Absent`.

The design switches are the fixes, and each has a counterexample when set to
`FALSE` (run a copy of the configuration outside this directory):

| Switch | Old behaviour | Counterexample |
|--------|---------------|----------------|
| `ThrottleKeepsTimestamp` | the throttle stamped `updatedAt` on a row it never syncs | `Converged`: A writes v1 at t0, its throttle stamps t2 locally, B writes v2 at t1; A keeps v1 against v2 for ever, B and C keep v2 |
| `CountersJoinAlways` | G-counters were joined only on a concurrent conflict | `OwnCountKept`: B increments, merges A's v1 keeping both counts under v1's clock, then A's successor of v1 — which never saw B's count — replaces the row by causal dominance |
| `ResolveLocalWrites` | a write replaced the row whatever it was built on, under the clock it was built on | terminal: `Converged` — B receives A's retraction, then writes an edit from a stale snapshot or a null clock; B keeps the edit, A and C the retraction. state: `OwnCountKept` — a snapshot write drops the host's own increment |
| `ClampTimestamp` | a successor's `updatedAt` could be older than its predecessor's | `Converged`: a successor written on a lagging clock loses to a third concurrent version that its predecessor beat, so arrival order decides |
| `IntentCarriesClock` | a writer meant to replace the row built on `vectorClock: null` | `LocalWriteTakesEffect`, two steps: A writes a row, then moves it — out of the terminal status (terminal), or to new fields at the row's own timestamp (state) — and the local write resolution, judging the clockless write concurrent, hands the row back |
| `AbsentBelowZero` (ADR 0080) | `VectorClock.compare` read an absent host as counter 0 | with `FirstCounter = 0`, `NoLostSuccessor` in two steps: B writes its first version, `{B: 0}`; C receives it and keeps the row it had, which it reads as equal |
| `CanonAbsentBelowZero` (ADR 0080) | the canonical tiebreak read an absent host as 0 | with `FirstCounter = 0`, `Converged`: A and B each write their first version at the same instant, `{A: 0}` and `{B: 0}`; the tiebreak reads both as all zeros, and each replica keeps the one it received first |

`Intend` (ADR 0068's addendum) is the class the local write resolution
opened: a write built on the row whose point is to move it against the
resolver — a pre-warm moved earlier, a report head moved at the stamp of the
head it replaces, a soul or template head moved past a peer's clock that
runs ahead. The terminal configuration claims only `LocalWriteTakesEffect`:
such a write is a successor that ranks below its predecessor, the `RankDrop`
residual below.

What the model leaves out, deliberately or as a residual:

- **`RankDrop` — a successor that leaves the terminal status it built on.**
  The day agent's digest retry re-arms its own consumed window as `pending`
  at the same instant; `_resumeConfiguredEscalations` moves a pending
  relationship retry to an earlier instant. The resolver ranks those
  successors below their predecessors, so a third concurrent version can
  beat the successor but not the predecessor, and arrival order decides:
  with `RankDrop = TRUE` TLC finds `Converged` violated (A consumes, A
  re-arms the same instant, B consumes concurrently: B keeps its consume, A
  and C the retry). Closing it needs the rank to grow along every causal
  edge — a generation field that sync carries and older clients preserve, or
  re-arming under a new record id — which is a protocol decision.
- **Nudges on an exact `updatedAt` tie.** The nudge merge stores the join of
  both clocks, and the canonical-clock tiebreak then compares a history-
  dependent clock: two concurrent nudge versions with the same `updatedAt`
  can resolve differently on different replicas. Agent state keeps the
  winner's own clock and joins its G-counters on every delivery instead,
  which is what this model checks; the nudge variant is not modelled.
- **Devices that have not updated** still read an absent host as 0 (ADR
  0080). Over clocks that carry a counter 0 from a host an older build
  created, two such devices compare that host's first write equal, and an
  older and a newer device can keep different rows (`{h0: 0, h1: 1}` against
  `{h1: 2}`: concurrent here, the second newer there) until a later write
  succeeds both. The legacy configurations check each half of a mixed fleet;
  one that mixes both readings over counter-0 clocks is not modelled. No
  receiver can change what an older build does; it ends as devices update.
- Agent links (`AgentLink`) are `AgentLinks` below.
- **Journal entry links** (`JournalDb.upsertEntryLink`) are ordered by one
  lexicographic key: `updatedAt`, then the clock under
  `VectorClock.compareCanonically` (an absent host below counter 0), then the
  content
  ([ADR 0078](../../docs/adr/0078-entry-link-versions-are-ordered.md)). A
  total order converges in any arrival order. The writers meet
  `IntentCarriesClock` (an edit reserves with the stored link's clock as
  `previous`) and `ClampTimestamp` (`linkEditTimestamp`), which is what makes
  the key agree with causality (`NoLostSuccessor`). Before that change the
  receive applied whatever arrived last, and an edit's clock held only its own
  host's counter.

## `AgentStateWrites` — the writers of one agent-state row

One agent's state row on one device: a single-flight wake that records its
outcome when it ends, and the report-freshness watermarks that subscription
events and finished refreshes move while it runs.

| Property | Kind | Says |
|----------|------|------|
| `NoLostWatermark` | invariant | every recorded event survives in `reportStaleAt` |
| `FreshIsHonest` | invariant | a report refreshed before the newest event never reads as fresh |
| `FailureStreakExact` | invariant | `consecutiveFailureCount` counts the failures since the last success |
| `NoLostWake` | invariant | the wake counter counts every successful wake |

| Configuration | Wakes | Events | Distinct states |
|---------------|-------|--------|-----------------|
| `AgentStateWrites` | 3 | 3 | 604 |

With `TransformWrites = FALSE` — the outcome written as a copy of the row the
wake started from, as the task agent did — TLC breaks `NoLostWatermark` in
four steps (event, wake start, event, wake end) and `FreshIsHonest` in
three. The failure streak itself is never lost on one device, because wakes
are single-flight; across devices it is a last-writer-wins value, which is
what this model leaves out.

## `VersionHeads` — version rows and the head that names one

A versioned document on two devices that edit it offline, two edits each:
its version rows, each with a status, and the head row, each resolved as its
own synced entity. `"soul"` is soul documents and agent templates (a new
version archives every non-archived version, a rollback reactivates its
target, the head is last-writer-wins); `"goal"` is goal specs (a revision
supersedes and mints the next ordinal, the head resolver prefers the higher
ordinal).

| Property | Kind | Says |
|----------|------|------|
| `Converged` | invariant | both devices end with the same rows |
| `HeadResolves` | invariant | the head names a version the device has |
| `SettlesAfterCleanEdit` | invariant | after an edit made with everything received, exactly one version is active and the head names it |
| `OneActive` | invariant (residual) | the same, unconditionally |

| Configuration | Kind | Edits | Rollback | Distinct states |
|---------------|------|-------|----------|-----------------|
| `VersionHeadsSoul` | soul | 2 per device | yes | 8,713,361 |
| `VersionHeadsGoal` | goal | 2 per device | no | 754,881 |

`SupersedeAll = FALSE` — a goal revision superseding only the head's version,
as it did — breaks `SettlesAfterCleanEdit`: two devices each mint an active
v2, the head keeps one, and the other stays active through every later
revision. `OneActive` is violated by concurrent edits in both kinds (twin
v2s; a head that names a version another device concurrently archived), and
stays a residual: the active version is defined by the head, every read
resolves through it (`getActiveSoulDocumentVersion`, the goal workflow's
fences), and the next edit settles the statuses.

## `AgentMessageLog` — the agent's message DAG

One agent's causal message log on two devices, one of whose clocks runs
ahead: appends chained off the head pointer, other writes of the agent-state
row, the fork healer's join planned from one read and committed in a later
transaction (an append may run in between — the wake-start hook timed out
and the executor went ahead), a crash between the two, and sync delivering
every message, edge and state version once, in any order. The head is a
field of the state row: the other fields of a state version are resolved by
vector clock and then last-writer-wins, the head by the local message DAG,
and an append first advances the head to a tip past it. The runtime is
described in
[Agent memory and log compaction](../../knowledge/features/agents/memory-and-compaction.md)
and the decisions in
[ADR 0071](../../docs/adr/0071-model-checked-agent-message-log.md) and
[ADR 0076](../../docs/adr/0076-model-checked-agent-head.md).

| Property | Kind | Says |
|----------|------|------|
| `Acyclic` | invariant | no device's `messagePrev` graph holds a cycle |
| `EdgesImmutable` | invariant | an edge id names one parent, whoever writes it |
| `NoJoinOverNonTip` | invariant | a join is planned only over rows with no child on that device (short of the residual below) |
| `Converged` | invariant | once every row is delivered, both devices hold the same edges |
| `SettledHead` | invariant | once every row is delivered and the log has one head, that head is what each device's next append chains off |
| `LocalHeadAdvances` | action | a device's own write moves its head only to a descendant of the old one |
| `HeadNeverRegresses` | action | no step — a delivered state version above all — moves a head pointer to a known ancestor of the one it replaces |
| `AppendsOffTips` | action | an append never chains off a row that already has a child on that device |
| `EventuallySingleHead` | liveness | with fair delivery and healing, every device ends with one head |

`PointersConverge` — the head pointers themselves agree once sync settles —
is written down but not claimed: a merge made before the rows that order two
heads arrived leaves a pointer on the older head until the next append
advances past it, which `SettledHead` covers.

| Configuration | Appends | Other state writes | Joins | Crashes | Checks | Distinct states |
|---------------|---------|--------------------|-------|---------|--------|-----------------|
| `AgentMessageLog` | 2 + 1 | 0 | 1 per device | 0 | safety | 1,922,129 |
| `AgentMessageLogStale` | 2 + 1 | 1, on the fast device, possibly from an older build with no clock | 0 | 0 | safety | 72,446 |
| `AgentMessageLogLiveness` | 1 + 1 | 1, on the fast device | 1 per device | 1 | all | 688,421 |

Each fix has a switch that is `TRUE` in the checked-in configurations. Set to
`FALSE` in a temporary copy, TLC reproduces the hole:

| Switch | Configuration | Counterexample |
|--------|---------------|----------------|
| `SafeRecovery` | `AgentMessageLogStale` | `Acyclic`, six steps: the fast device writes its state row with no head, appends a root `b1`; the other device receives `b1`, chains `a1` off it (older `createdAt`), receives the headless state row, which wins last-writer-wins, and its next append re-chains the log by `createdAt`: `msgprev-b1 → a1` closes a cycle |
| `ChainEdgeGate` | `AgentMessageLog` | `NoJoinOverNonTip`, five steps: `a1` is chained off `b1`; the other device receives `a1` but not its edge and joins `{a1, b1}` |
| `JoinEdgeGate` | `AgentMessageLog` | `NoJoinOverNonTip`, ten steps: a join of `{a1, b1}` and its device's state row reach the other device without the join's edges; that device appends `a2` off the join, so the join is no longer a head, and joins `{a1, a2, b1}` |
| `HeadMerge` | `AgentMessageLogStale` | `HeadNeverRegresses`, four steps: the fast device appends a root `b1`; the other device receives `b1`, chains `a1` off it, and receives the fast device's state row, concurrent with its own and later on the skewed clock: last-writer-wins moves the head back to `b1` |
| `TipAppend` | `AgentMessageLogStale` | `AppendsOffTips`, six steps: one device appends `a1` and `a2`; the other receives `a2` and its edge to `a1`, then the state version naming `a1`, and appends `b1` off `a1`, which already has a child there |
| — (`HeadMerge` off only for a version with no clock) | `AgentMessageLogStale` | `HeadNeverRegresses`, five steps: the fast device appends `b1`, and an older build there writes its state row with no clock; the other device receives `b1`, chains `a1` off it, then receives that row, which applies whatever the clocks — and with it the head `b1` |
| `AtomicReceive` | `AgentMessageLogStale` | `HeadNeverRegresses`, five steps: a device reads its state row (no head yet) and resolves the fast device's version (head `b1`) against it; its executor appends `a1` off `b1`; the receive then writes the row it resolved, moving the head back to `b1` |

`appendJoin`'s head guard — move the head onto the join only while it sits
on a joined parent — was already right; it is what the timed-out heal needs.
Dropping it from `HealCommit` fails `LocalHeadAdvances` in six steps: the
healer plans `{a1, b1}`, the executor appends `a2` off `a1`, and the join
commits and moves the head back, orphaning `a2`.

Without `TipAppend` the settled state is wrong too: with every row
delivered and one head in the log, a device's pointer can still sit on a row
with a child, and `SettledHead` fails (nine steps; eight with all three
switches `FALSE`, the receive and append paths before ADR 0076). The merge
alone cannot settle it: it orders two heads only as far as the rows it holds
show.

Residuals:

- **A child ahead of its own edge.** The tip walk follows `messagePrev`
  edges, so a message whose own edge has not synced yet is not seen as its
  parent's child, and an append in that window forks off the parent — the
  same window the fork healer's chain-edge gate waits out. The message and
  its edge are written in one transaction and travel together in practice.
  `AppendsOffTips` counts children by edges, as the code does.
- **A join row does not name its parents.** A join still missing the edge
  to a parent that is not a head on this device — not arrived, or with
  another child — cannot be told from one whose parent the observation sweep
  deleted, so waiting for it could block healing for good. The healer goes
  ahead and may join over that join's parents again: a redundant node, never
  a cycle. `NoJoinOverNonTip` does not count this case (`BlindJoin`). The
  healer also stops testing a join against subsets of the other heads once
  there are more than twelve (one digest per subset). Carrying the sorted
  parent ids on the join row would close both.
- **The legacy spine** is written only for a log with no `messagePrev` edge,
  no message minted with a `prevMessageId` and no join. Two devices whose
  first appends each met a different set of such roots write different
  spines; that takes three devices and is not modelled.
- The observation sweep, which deletes messages and the edges into them, is
  not modelled; the healer's gates read a `prevMessageId` naming an absent
  row as a deleted parent rather than an unsynced one for that reason.

## `LogCompaction` — summary checkpoints

Two devices capture versions of two sources — a capture link and its payload
sync separately — and fold the oldest part of their uncovered tail into a
checkpoint that extends the active one. Captures, payloads and checkpoints
arrive late and in any order. A wake shows the active checkpoint's prose and,
verbatim, every event after its cutoff. The ghost `saw` is what the prose
actually folded.

| Property | Kind | Says |
|----------|------|------|
| `NoLostContext` | invariant | every event is after the active cutoff, folded into the prose, or superseded by a newer version that is one of the two |
| `NoDeadCheckpoint` | invariant | a device never writes a checkpoint its own log already rejects |
| `Converged` | invariant | devices holding the same rows select the same checkpoint |

`LogCompaction` (device 1 captures three times and folds twice, device 2
captures and folds once) passes with 590,909 distinct states.

| Switch | Counterexample |
|--------|----------------|
| `DigestCoverage` | `NoLostContext`, six steps: device 1 captures `s1`, device 2 edits `s1`, device 1 captures twice more and folds `s1`'s first version with a cutoff past the edit; the edit arrives and the checkpoint, keyed by source alone, stays active. With `FoldStopsAtGap` also `FALSE` — the code before ADR 0071 — the same trace |
| `FoldStopsAtGap` | `NoDeadCheckpoint`, five steps: device 1 receives device 2's capture without its payload, captures once more and folds past the unresolved event |

Left out: inline events (retractions, verdicts, day captures) carry unique
ids and have no versions, so they only exercise the unknown-source path the
model already covers; a checkpoint whose own payload has not arrived is
simply not a candidate yet; summarizer failures write nothing.

## `DigestRecovery` — the coordinator digest across crashes

One device and one day window: the wake manager claims, settles and fires the
digest record, the wake runtime runs it, and the process may die anywhere.
Startup then repairs the record — from the wake manager's pre-check and from
`restoreSubscriptions` — while `restoreWakeIntents` replays wake intents after
the subscription passes. The run commits its milestone and next-day re-arm in
one transaction; the manager's consume write can land after it. The decision
is [ADR 0070](../../docs/adr/0070-model-checked-digest-recovery-and-processing-jobs.md);
the protocol is described in
[the coordination protocol](../../knowledge/features/daily_os_next/coordination-protocol.md).

| Property | Kind | Says |
|----------|------|------|
| `AtMostOneDigest` | invariant | the day is digested at most once |
| `NoInferenceAfterBriefing` | invariant | no digest inference starts once the day's briefing exists |
| `InferencesBounded` | invariant | every inference beyond the first was paid for a run a crash killed |
| `EventuallyBriefed` | liveness | the day is digested at least once, across crashes |

| Configuration | Crashes | Lease | Clock steps | Distinct states |
|---------------|---------|-------|-------------|-----------------|
| `DigestRecovery` | 1 | claim and settle | 0 | 156 |
| `DigestRecoveryCrash` | 2 | none (no sync host) | 1 backward | 430 |

Three switches describe the design, `TRUE` in both configurations. Setting one
to `FALSE` in a temporary copy reproduces the design before ADR 0070:

| Switch `FALSE` | Counterexample |
|----------------|----------------|
| `DigestOwnsRecovery` | `NoInferenceAfterBriefing`: the digest completes, the process dies before its wake intent's settle reaches disk, and startup replays it. With the settle made atomic, the next trace is the one the two paths produce: after a crash `restoreSubscriptions` retries the consumed record, the record fires and completes, then `restoreWakeIntents` runs the interrupted digest again |
| `ProbeSeesLimbo` | `NoInferenceAfterBriefing`: the record fires and is consumed, the drain takes the job out of the queue, the pre-check sees no live work and re-arms the record, which fires again — no crash needed |
| `WindowFromDayStart` | `NoInferenceAfterBriefing`: the run completes before the consume write lands, stamping its milestone before `consumedAt` after a backward clock step; the pre-check reads that as no digest and retries |

Left out: peers (ADR 0048's lease is a cost bound, and a partitioned peer can
still fire), transient run failures (which re-arm the next slot), and the
two-restore poison guard of `WakeIntentStore`.

## `DayProcessingJob` — one request, at most one inference

One `refinePlan` (or `draftPlan`) request in the processing outbox, claimed by
two agent lanes — the runtime's, and one a provider rebuild left running —
through the single-statement claim, executed by `DayAgentJobExecutor` through
agent wakes that keep single flight, can fail, or be aborted and run on. The
claim's lease lapses only while its holder waits for a wake, since only that
wait takes three minutes. Users can cancel or retry; the process can crash,
taking its wakes with it. Past `MaxWakes`, an enqueue stands for a wake that
fails at once, so the bound cannot block progress.

| Property | Kind | Says |
|----------|------|------|
| `AtMostOneLiveWake` | invariant | at most one inference of the request is queued or running |
| `NoInferenceAfterArtifact` | invariant | no inference starts once the request's plan or ChangeSet exists |
| `AtMostOneArtifact` | invariant | the request yields at most one artifact |
| `Fenced` | invariant | no fenced write lands under a revoked claim |
| `EventuallySettled` | liveness | the job ends succeeded, cancelled or failed |

| Configuration | Kind | Lanes | Crashes | User taps | Distinct states |
|---------------|------|-------|---------|-----------|-----------------|
| `DayProcessingJob` | refine | 2 | 1 | 1 | 6,585,351 |
| `DayProcessingJobDraft` | draft | 2 | 1 | 1 | 6,585,351 |

Each takes about three and a half minutes. An attempt looks for a live wake before its reads and again, atomically with the enqueue, after them; the model assumes a whole model call cannot fit inside those reads (`NoneChecking`). Mutations, in a temporary copy:

| Mutation | Counterexample |
|----------|----------------|
| `AttachToLiveWake = FALSE` (the code before ADR 0070) | `AtMostOneLiveWake`: lane 1 claims, enqueues and records its wake, its lease lapses while it waits, lane 2 re-claims and enqueues a second. With a retry tap the trace is claim, `retryNow`, claim; a timed-out wait followed by the retry is the same length |
| `RecheckBeforeEnqueue = FALSE` | `AtMostOneLiveWake`: lane 1 claims and finds no live wake, a retry tap re-queues, lane 2 claims and finds none, and both enqueue |
| the `claim_token` check removed from `Report` | `Fenced`: a lane times out, a retry tap re-queues, the other lane claims, and the first lane's failure lands on the new claim |
| `ProvenanceRace = TRUE` | `NoInferenceAfterArtifact` — a residual, below |

Two cases stay open:

- **A wake that commits before its run key is recorded.** If the artifact lands
  before `recordRunKey` and the process then crashes, a never-attempted refine
  has no provenance and no time-window fallback, so its re-claim runs it again
  (`ProvenanceRace`). The window is one local write against a model call.
  Closing it means stamping the artifact with the processing-intent id instead
  of the run key.
- **A hung executor.** Past `hungExecutorAfter` a wake no longer counts as live,
  so its request can run again, the boundary `WakeRuntime` accepts for single
  flight. The model does not declare executors hung.

## `EvolutionSession` — a 1-on-1 and the version it adopts

One evolution session (a template or soul 1-on-1) on three replicas.
Replica 1 owns it: only the owner holds the conversation in memory, so only
the owner approves, and an approval creates a template or soul version.
Every replica can abandon the session. `startSession` and every approval
sweep the sessions a device reads as active (`_abandonStaleActiveSessions`),
and the owner abandons it when the user leaves the chat. The version rows
and the head they update are `VersionHeads`; here version creation is one
atomic step. The session row is received like any agent register
(`resolveAgentEntityVersions`), and a local write goes through
`resolveLocalAgentWrite`. The decision is
[ADR 0081](../../docs/adr/0081-model-checked-evolution-sessions-and-agent-links.md).

| Property | Kind | Says |
|----------|------|------|
| `Converged` | invariant | once every write has reached every replica, all hold the same row |
| `OneVersion` | invariant | the session creates at most one version |
| `AdoptionRecorded` | invariant | once the owner is done, a session that created a version is completed, naming it, everywhere |
| `CompletedNamesVersion` | invariant | a completed row names a version the session created |
| `CompletedStays` | action property | a replica that holds the session completed keeps it completed |
| `NeverReactivated` | action property | no terminal row becomes active again |

| Configuration | Replicas | Session-row writes | Owner crashes | Clock skew | Distinct states |
|---------------|----------|--------------------|---------------|------------|-----------------|
| `EvolutionSession` | 3 | 4 | yes | 1 tick | 243,264 |

The three design switches are the fixes, and each has a counterexample when
set to `FALSE` (run a copy of the configuration outside this directory):

| Switch | Old behaviour | Counterexample |
|--------|---------------|----------------|
| `CompletedOutranks` | a concurrent completion and abandonment went to `updatedAt` | `CompletedStays`, five steps: the owner approves, the peer starts its own session a minute later and sweeps this one, and the owner receives the sweep. `AdoptionRecorded` follows: every replica ends with the session abandoned while its version is in effect |
| `AtomicApprove` | the version committed on its own, then the notes, the recap and the row | template (`VersionCache = TRUE`): `AdoptionRecorded`, the version commits, the completion fails, the user leaves the chat, and the session is abandoned under its own version. After a crash between the steps the session stays active until a sweep abandons it (two steps). soul (`VersionCache = FALSE`): `OneVersion` in three steps, create, fail, and create again |
| `AtomicReceive` | the receive read the row and wrote after an await | `CompletedStays`, four steps: the owner reads its active row to apply a peer's sweep, the approval commits, and the receive writes the sweep over it. Peers keep the completion |

Suspected but not confirmed: a completed session is never reopened
(`NeverReactivated`). `active` is written only at creation, and the
override ranks it below both terminal statuses. What the model leaves out:

- `approveSoulProposal`, the mid-session soul approval that does not complete
  the session, still creates its version in its own transaction. A retry
  after a failed outbox flush can create a second soul version.
- The session's notes and recap are advisory rows written in the approval's
  transaction. They are not modelled.

## `AgentLinks` — a link written, removed and written again

One agent link on three replicas: written afresh (`vectorClock: null`) and
removed (`softDeleted` of the row read) under one reused id, which covers the
Daily OS links' deterministic ids, the planner's template assignment,
`msgprev` edges and any link written again after a removal. Versions are
delivered in any order and any number of times. In the lossy configuration
a delivery can also be lost, and the receiver then recovers it by backfill
from the writer's stored version. The receive is
`SyncEventProcessor._resolveAndPersistAgentLink`, which calls
`resolveAgentLinkVersions`: dominance, then `updatedAt`, then the canonical
clock. The local write is `AgentSyncService.upsertLink`. The decision is
[ADR 0081](../../docs/adr/0081-model-checked-evolution-sessions-and-agent-links.md).

| Property | Kind | Says |
|----------|------|------|
| `Converged` | invariant | once every write has reached every replica, directly or by backfill, all hold the same version |
| `NoLostSuccessor` | invariant | a row is never a version that a version it received causally replaced: a removal is not undone by a late copy of the link |

| Configuration | Replicas | Writes | Losses | Clock | Distinct states |
|---------------|----------|--------|--------|-------|-----------------|
| `AgentLinks` | 3 | 3 | none | 0..2, 1 tick skew | 169,899 |
| `AgentLinksLossy` | 3 | 3 | any, recovered by backfill | 0..1, 1 tick skew | 10,940,570 |

| Switch | Old behaviour | Counterexample |
|--------|---------------|----------------|
| `ReceiveSeesTombstones` | the receive read the local link with `getLinkById`, which filters tombstones | `NoLostSuccessor` in three steps (link, remove, a late copy of the link). `Converged` in six: C receives the removal before the link and keeps the link |
| `BackfillServesTombstones` | the backfill responder read the same way and answered `deleted` | `Converged`, seven steps: C loses the removal, asks for it, gets `deleted`, and keeps the link |
| `WriteSucceedsRow` | a write's clock was its own base plus this host's counter, and it overwrote the row | `Converged` with no clock skew: B links, A removes, and B links again afresh. `{B:2}` is concurrent with A's `{A:1, B:1}`, and the canonical order prefers the removal, so A and C keep the removal and B keeps the link |
| `ClampTimestamp` | a successor's `updatedAt` could be older than its predecessor's | `Converged`: a write on a lagging clock loses to a third concurrent version that its predecessor beat |
| `AtomicReceive` | the receive read the link and wrote the incoming version after an await | `NoLostSuccessor`, seven steps: a local write commits between the receive's read and its write and is overwritten |

What the model leaves out, deliberately or as a residual:

- **Two concurrent reassignments of one slot swap.** A template has at most
  one live soul assignment, and a template has at most one improver. When a
  live assignment arrives, `AgentRepoLinks.upsertLink` tombstones the other
  live one locally, without a clock bump or a sync message. A copy of this
  model with that handoff (not checked in) finds the swap in five steps: A
  and B reassign the template's soul concurrently, each receives the
  other's link and keeps it, and A ends with B's soul and B with A's until
  the next assignment. The same handoff hard-deletes a row that shares the
  slot's natural key. The fix needs a decision. The options are one
  deterministic link id per slot, which makes the assignment a register but
  needs a migration and a plan for older clients; a slot rule every replica
  applies the same way, ranking assignments by `(createdAt, id)` over every
  version known, with writers clamping `createdAt`; or emitting the
  handoff's tombstones as synced writes.
- **Agent entities have the tombstone hole too.** `getEntity` filters
  tombstones for the entity receive and its backfill, so a soft-deleted
  entity can come back when a late copy arrives. It is left for its own
  change.
- `VectorClock.compare` reads an absent host as counter 0, so a new host's
  first write can compare *equal* to the version it succeeds. ADR 0080
  fixes that globally. The model's clocks have no absent hosts.

## From the model to the code

TLC checks the design, not the Dart that implements it. The gap is narrowed by
a generated conformance test,
`test/features/sync/backfill/backfill_response_handler_model_conformance.dart`
(a part of the handler's suite). It drives the real `VectorClockService`,
sequence log and `BackfillResponseHandler` over in-memory databases through
Glados-generated traces of reservations, commits, outbox binds, releases,
crashes (a fresh service stack over the same stores), backfill requests and
outbox outages, and checks `NoFalseBurn`, `BoundRowsHavePayload` and
`BurnedIsTerminal` after every step, and after a final restart, that every
committed write was bound and actually reached the outbox. Reverting the
settlement fix, or binding before the resend is durably queued, makes it fail
with a shrunk trace of four or five steps.

The name itself is checked end to end in `test/logic/persistence_logic_test.dart`
("an explicit id survives a crash before the outbox binds"): a task and an AI
response are created under a caller-chosen id through the real
`PersistenceLogic`, `MetadataService`, `VectorClockService`, journal and
sequence-log databases, the outbox never binds, and a fresh reservation service
runs startup settlement. The counter must end `received` under that id and be
resent, never burned. With the id swapped in after the reservation, as before
ADR 0077, it ends `burned`.

The agent specs have the same kind of check. In
`test/features/agents/wake/wake_orchestrator_intents_test.dart`, generated
traces of triggers, run completions and a crash drive the real orchestrator and
intent store, and after a final restart every trigger must have been covered
by a run that completed (`NoLostWake`). It found that the first
implementation, which settled an agent's intents up to a sequence cutoff, lost
a trigger queued in a second job of the same agent. In
`test/features/agents/service/change_set_confirmation_service_model_conformance.dart`,
generated interleavings of confirms, rejects, dispatch outcomes, throwing
hooks and crashes drive the real confirmation service, which must keep
`AtMostOnceApply`, `RejectedMeansNotApplied` and `ConfirmedMeansApplied`.
Removing the claim's `pending` check, reverting a confirmed item when the hook
throws, or letting a reject write its status unconditionally fails it within
three steps.

For the message log, `test/features/agents/sync/agent_message_log_model_conformance.dart`
(a part of the fork healer's suite) drives two real `AgentSyncService` and
`ForkHealer` replicas over in-memory stores, the second an hour ahead,
through generated appends, other state writes, heals and deliveries of
single outbox rows in any order — a state version through the shared
`resolveAgentEntityVersions` with its head ordered by
`AgentMessageDag.ancestryOf`, an edge by vector clock and then
last-writer-wins. After every step it checks `Acyclic`, `EdgesImmutable`,
`NoJoinOverNonTip`, `HeadNeverRegresses` and `AppendsOffTips`; after
delivering everything and healing, `Converged`, one head and `SettledHead`.
Reverting head recovery fails it in six steps (the second device's
first append over a partly synced chain rewrites `msgprev-h1-m3`), removing
the chain-edge gate in eight. Dropping the head merge on a concurrent or a
dominating version fails `HeadNeverRegresses` (`h1-m1 -> h2-m1`), and
dropping the tip walk fails `AppendsOffTips` (`h1-m2` chained off `h1-m1`,
which already had a child there). The receive transaction is covered by an
example in the sync processor's suite, since the trace delivers one row at
a time. The join gate's interleaving is too specific for
random traces; its regressions are examples in the same suite. In
`test/features/agents/projection/compaction_summary_test.dart`, generated
histories of versions on two devices, a fold over what the folding device
held and any subset the observing device holds check `NoLostContext`
against `selectActiveSummary`; keying coverage by source alone fails it.

The processing job has one too:
`test/features/daily_os_next/services/day_agent_job_executor_model_conformance.dart`
(a part of the executor's suite) drives the real outbox repository over an
in-memory database, the real processor and the real executor, with two lanes
claiming one refine request, through generated traces of claims, three-minute
steps that lapse the lease and the wait together, wake starts, commits,
failures and aborts, retry taps and crashes (a fresh process whose predecessor
can no longer write). After every step it checks `AtMostOneLiveWake`,
`NoInferenceAfterArtifact` and `AtMostOneArtifact`. Making the executor ignore
the live wake fails it with the trace `claimA, retryNow, claimB`, and dropping
the look-again before the enqueue fails it on a retry tap raced between the
two lanes' claims. The digest's two recovery fixes have direct regressions
instead: the digest wake leaves no
intent across a simulated restart in the wake-intent suite, and the drain-held
and held-back windows are probed in the orchestrator suite.

The confirmation model separates the committed claim from the post-commit
outbox flush. `FlushFails` still permits dispatch after the caller verifies its
unique persisted decision. Changing that transition to `done` reproduces the
stranded confirmation as a `ConfirmedMeansApplied` counterexample. Service
regressions exercise the real sync service and Drift transactions with a
throwing outbox, for both confirmation and rejection.

The lease and chat models have no generated trace yet; their counterexamples
are pinned as deterministic regressions instead, each failing with its fix
reverted. `scheduled_wake_manager_test.dart` (group *firing and consuming a
record*) checks that the intent is flushed before the consume, that an owed
record is consumed rather than claimed or fired — before the claim and after
the lease wait — and that the consume carries the current row and leaves a
newer window alone. `goal_agent_phase_a_test.dart` checks that a second
escalation carries the consumed clock at a later deadline, outranking a late
takeover claim of the first window, and leaves a pending one untouched.
`goal_chat_service_test.dart` and `goal_agent_providers_test.dart` check that a
sent turn arms its recovery before its wake and the answering wake consumes it,
that maintenance arms records and enqueues nothing, that the next window waits
for the last lease to lapse, and that a goal wake not for a message leaves it
alone.

`ChangeSetLifecycle` has two. In
`test/features/agents/service/change_set_confirmation_service_lifecycle_conformance.dart`,
generated interleavings of confirms, rejects, staged retractions, dispatch
outcomes of both failure kinds and — the part that matters — the delivery of
each read of the set drive the real confirmation and retraction services over
a follow-up task, its migration and a plain item. A read outside a
transaction returns the state as it was when it was made, only when the trace
delivers it, so another writer can land between a writer's read and its
write; after every step `AtMostOnceApply`, `AppliedStaysDecided`,
`RejectedMeansNotApplied`, `ConfirmedMeansApplied` (when nothing runs) and
`MigrationAfterTarget` must hold. Putting back the whole-set read-modify-write
for the dispatch-failure revert, the sibling rewrite or the retraction fails
it with a shrunk trace of two to six steps; the cascade's is caught by its
own regression in the resolution store's suite. In
`test/features/agents/sync/agent_concurrent_resolver_merge_test.dart`,
generated concurrent histories of a two-item set on two devices must merge to
the same row in either direction, keeping the item a device changed last and
a confirm neither side superseded. ADR 0075's effects have a third, in
`test/features/agents/workflow/task_tool_dispatcher_idempotency.dart` (a part
of the dispatcher's real-database suite): generated sequences apply five
confirmed items — a follow-up task, a time entry, a checklist item, a title
and an estimate — any number of times, on a real journal database, with the
user editing the title and the estimate in between. A second application on a
replica that already holds the first's writes is what the late device runs,
so after every step the journal must hold one entity per applied create
(`NoDuplicateEffects`) and each field must hold the user's latest edit, or
else the proposed value if applied, or else its base (`NoClobber`). Reverting
the compare-and-set, or deriving random ids for the follow-up task, the time
entry or the checklist item, fails it; each tool also has its own regression
there, and the migration's claim with its resolved target has one in the
confirmation service's suite that holds the sibling rewrite back until the
migration is claimed.

Convergence has its own trace. In
`test/features/agents/sync/agent_replication_model_conformance.dart` (a part
of the `AgentSyncService` suite), three replicas — each a real
`AgentSyncService` over its own store — write agent state and planner
knowledge on their rows, on wake-start snapshots and on null clocks, with a
lagging clock, and exchange the writes in generated orders through
`resolveAgentEntityVersions`. After every step no replica holds a version a
received write causally replaced, and each host sees its own increments;
after everything is delivered, all three rows are equal and every increment
is counted. Joining counters only on concurrency, writing without resolving
against the persisted row, or not clamping `updatedAt` each fail it within
three or four steps; dropping the counter join of a covered write is caught
by the resolver's unit regression instead. One replica's host starts its
counters at 0, as a host an older build created does
(`AgentReplicationLegacyCounter`), and the causal check is the model's own
order rather than `VectorClock.compare`. Reading an absent host as 0 again
fails both traces.

Links and sessions have theirs. In
`test/features/agents/sync/agent_links_model_conformance.dart` (a part of the
`AgentSyncService` suite), three replicas, each a real `AgentSyncService`
over its own in-memory agent database, write one link afresh under a reused
id and remove it. They exchange the versions in generated orders through
`resolveAgentLinkVersions` and the tombstone-inclusive read, lose deliveries
and recover them from the writer's stored version, as the backfill responder
does. After every step `NoLostSuccessor` must hold, and after everything,
`Converged`. Stamping the write without the stored clock, dropping the
`updatedAt` clamp, or filtering tombstones out of
`getLinkByIdIncludingDeleted` fails it. The replication trace above now also
has an evolution-session kind whose writes only move the status up. Without
the completion override a replica that held the session completed ends with
it abandoned (`CompletedStays`) in three steps. The receive transactions of
links and sessions are examples in the sync processor's suite. The approval's
transaction is an example over a real agent database in the template and
soul workflow suites, where a failure after the version rolls it back and a
retry adopts exactly one.

## Changing a spec

Keep the header's action-to-code map current. When a change is meant to fix a
hole, first reproduce the hole: run the configuration against the spec of the
old behaviour and keep the counterexample for the pull request. After the fix,
check that the property fails again when the fix is mutated away — a property
that cannot fail proves nothing.

## `DayJobPreparation` — an inference finishes between preparation reads

Two attempts can both read an absent artifact before either enqueues. One
may then finish while the other is still resolving the agent; the final live
wake probe sees nothing and used to start a second inference. This focused
model checks `OneInference` with arbitrary preparation delays. Setting
`Coalesce = FALSE` in a temporary configuration reproduces the duplicate.

`DayAgentJobExecutions` shares the full attempt across the old and rebuilt
processing runtimes. Executor regression tests pause one lookup while another
attempt runs, using the same executor and separate executors sharing the
registry. This removes the runtime timing assumption represented by
`NoneChecking` in the broader `DayProcessingJob` model; that model retains its
existing claim, retry and crash exploration.
