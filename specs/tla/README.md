# Formal specs

TLA+ models of the protocols in this app that are too concurrent to trust to
prose, model-checked with TLC. A spec here describes the code as it is: a
change to the modelled code updates the spec in the same pull request, and CI
(`.github/workflows/tla-model-check.yml`) re-checks it whenever either moves.
[LEDGER.md](LEDGER.md) records which pull request added each spec, what it
caught, and the running totals.

## Running

```sh
make tla_check                      # every configuration
specs/tla/tlc.sh SyncSequenceCrash  # one configuration
```

`tlc.sh` needs Java 11 or newer (`JAVA=/path/to/java` if it is not on `PATH`).
It downloads the pinned `tla2tools.jar` once, verifies its SHA-256, and caches
it in `TLA_TOOLS_DIR` (default `~/.cache/lotti-tla`). A configuration
`<Spec><Variant>.cfg` checks `<Spec>.tla`.

CI packs every checked-in `.cfg` into eight shards (`shards.py`), balanced by
each configuration's measured runtime, and runs them with `fail-fast: false`.
A shard checks all of its configurations even after one fails, and lists each
result in the job summary. A new configuration joins a shard automatically,
counted at a pessimistic five minutes until its runtime is added to
`SECONDS`; `python3 specs/tla/shards.py --table` prints the plan. The
aggregate `TLC` check passes only when planning and every shard succeed; local
`make tla_check` still runs all configurations sequentially.

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

A third lies outside the model, which its conformance trace shows (see
[From the model to the code](#from-the-model-to-the-code)): `FinishJob`
settles the window's intent in the same step as the run, while the code
settles it with the next coalesced write to the settings database. A process
that dies after a run completes and before that write lands restores the
intent at the next launch, and the window runs a second time on the same
device — the at-least-once side of `WakeRuntime`'s `NoLostWake`, which the
digest avoids by owning its recovery (ADR 0070). Closing it would take the
run's own writes and its settle in one transaction across two databases; it
is left as a decision.

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

## `HabitDaySettlement` — who decides a habit day

One habit on one day across devices. A person records the day by hand on any
device; a signal the habit's rule reads lands on one device and syncs; the
auto-completion engine on a device that has the signal fills the day if it
holds no completion; sync delivers every row in any order; each replica
settles the day to one row. That settled row is what the habits page,
streaks and every goal habit leaf read. The runtime is described in
[habits](../../knowledge/features/habits.md#one-settled-completion-per-habitday)
and [success semantics](../../knowledge/architecture/success-semantics.md).

| Property | Kind | Says |
|----------|------|------|
| `Converged` | invariant | replicas holding the same rows settle the day to the same one |
| `ManualBeatsAuto` | invariant | once a person recorded the day anywhere, no automatic success replaces it |
| `LatestManualWins` | invariant | among a person's entries, the last one stands |
| `EventuallyRecorded` | liveness | once the signal exists, every device ends up with the day recorded |

| Configuration | Devices | Moments | Manual entries | Distinct states |
|---------------|---------|---------|----------------|-----------------|
| `HabitDaySettlement` | 2 | 3 | 2 | 51,316 |
| `HabitDaySettlementThree` | 3 | 2 | 1 | 122,803 |

`Order = "recency"` models the code before the settlement order ranked the
source: newest write first, whatever wrote it. `Converged` holds under it —
replicas always agreed — but `ManualBeatsAuto` breaks: device 1 records the
day by hand, the signal lands on device 2 before that row does, device 2's
engine sees an empty day and writes an automatic success with a later stamp,
and once it syncs it outranks the person's entry on every replica. With a skip
that is "skip beats data" broken. Ranking a person's entry above any automatic
one, in `compareHabitCompletionPrecedence` and the SQL ranking alike, closes
it; `habit_completion_resolution_test.dart` and
`database_data_queries_test.dart` pin the counterexample, each failing with
the rank removed. Not modelled: clock skew between devices, which reorders any
last-write-wins decision.

## `GoalRegister` — Phase A's register and the report it escalates

One goal, one day, across devices. Evidence written on any device syncs in any
order; each device runs Phase A from two lanes — the wake orchestrator for its
own writes, the sync dispatcher for synced ones — and recomputes the day's
register row from its own journal, carrying the clock of the row it builds on.
A status the standing report does not state arms the synced escalation, whose
lease (`ScheduledWakeLease`, taken as given) elects one live device to derive
and write the report. The model carries crashes that lose in-flight runs and
the dispatcher's in-memory queue, devices that never return, and devices whose
views of the journal never agree (`Hidden`: a private entry one device hides,
or a time zone that moves an entry to another day). The runtime is described
in [goals](../../knowledge/features/goals.md#invariants).

| Property | Kind | Says |
|----------|------|------|
| `Converged` | invariant | once sync is quiet, every live replica holds the same row |
| `Complete` | invariant | once quiet, the row was computed from every item written that day |
| `ReportCurrent` | invariant | once quiet, the standing report states the status the day came to |
| `EscalationDurable` | invariant | an escalation a commit owed never dies with the device that owed it |
| `Bounded` | invariant | devices whose views never agree still stop writing |

| Configuration | Devices | Items | Faults | Distinct states |
|---------------|---------|-------|--------|-----------------|
| `GoalRegister` | 2 | 2 | none | 149,268 |
| `GoalRegisterCrash` | 2 | 2 | one restart | 2,784,300 |
| `GoalRegisterDeath` | 2 | 2 | one device lost (`EscalationDurable` only) | 702,372 |
| `GoalRegisterDivergent` | 2 | 2, one hidden from device 2 | none (`Bounded`) | 6,225 |

Each constant but `Hidden` and `MaxTick` contrasts the code before this spec
with the code now; reverting one fix at a time breaks a property in a few
steps, and the code before breaks `ReportCurrent` in 13 with no fault at all.
Each counterexample is pinned by a Dart regression that fails with its fix
reverted:

| Reverted | Breaks | Trace | Regression |
|----------|--------|-------|------------|
| `Lock` and `Validate` | `Complete`, 17 states | a local run reads the journal, a synced check-off is committed by the dispatcher's run, then the local run commits its older snapshot on top: carrying the clock makes it dominate on every device, and nothing re-triggers | `goal_agent_phase_a_test.dart`: a second run of the same goal waits; a register that moved under the run is derived again; a report published between derivation and commit is seen; `goal_agent_workflow_test.dart`: a refresh whose register keeps moving ends without inference |
| `Escalate` | `ReportCurrent`, 12 states | the lease elects a device whose journal is behind; its report states the old status while every register already carries the new one, so no device sees a transition | `goal_agent_phase_a_test.dart`: a report for today that states another status is escalated |
| `Restart` | `ReportCurrent`, 11 states | a synced row is applied and the process dies before the dispatcher runs; after the restart nothing evaluates it that day | `goal_runtime_maintenance_test.dart`: restoreSubscriptions recomputes every active goal |
| `ArmAt` | `EscalationDurable`, 6 states | a transition is committed and its refresh parked on the device-local countdown; the device dies, and its peers, holding the synced row with the new status, see no transition | `goal_agent_phase_a_test.dart`, `goal_agent_providers_test.dart`: the transition arms its escalation with the register |

`Lock` and `Validate` each close the interleaved-lanes trace alone; both
stay because they differ in cost and reach: the lock keeps a device's own
lanes from re-deriving at all, validation also covers a peer's row that
syncs in mid-run, and validation re-reads today's report as well, since the escalation decision read it too.

`OnSynced = "recompute"` is the design this spec rejected: a synced register
row or report owes the receiver a recompute, which would heal a stale row a
lagging device left behind. Under `Hidden` it never stops — each device answers
the other's row with its own — and breaks `Bounded` in 24 states, every
escalating round a paid Phase B run. Damping it (reacting to organic writes
only) or reacting only to a row that beat this device's own on the timestamp
bounds the loop but still fails with a death, because the harmful write is the
lagging device's own recompute from a journal still missing evidence.

That is the residual, and why `GoalRegisterDeath` claims only
`EscalationDurable`: a device that recomputes, or runs Phase B, from a journal
still missing evidence and then never comes back leaves a row or a report no
peer can tell is stale (`Complete` in 11 states, `ReportCurrent` in 8). A device that
does come back heals both — its startup recompute, the evidence that syncs in,
and a report for today that contradicts the status re-escalates.

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
a dismissed nudge), and `"removal"` a register that is removed and written
again, whose tombstone (`deletedAt`) is ordered like any other field — a day
plan deleted and drafted again, a parsed capture item replaced by a re-parse,
a deleted template or soul. The receive is `resolveReceivedAgentEntity`
(`agent_entity_receive.dart`) inside `SyncEventProcessor`'s receive
transaction. In the lossy configuration a delivery can also be lost, and the
receiver recovers it by backfill from the writer's stored version. The
decisions are
[ADR 0068](../../docs/adr/0068-model-checked-agent-convergence.md) and, for
removals, the addendum of
[ADR 0081](../../docs/adr/0081-model-checked-evolution-sessions-and-agent-links.md).

| Property | Kind | Says |
|----------|------|------|
| `Converged` | invariant | once every write has reached every replica, all hold the same row |
| `NoLostSuccessor` | invariant | a row is never a version that a write it received causally replaced |
| `OwnCountKept` | invariant | a host always sees all of its own G-counter increments |
| `NoLostIncrement` | invariant | once everything is delivered, every replica sees every increment |
| `LocalWriteTakesEffect` | invariant | a write meant to move the row against the resolver's order keeps its fields on the writing device; on the removal kind, a re-creation over a removed row |

| Configuration | Kind | Replicas | Writes | Clock skew | Checks | Distinct states |
|---------------|------|----------|--------|------------|--------|-----------------|
| `AgentReplication` | state | 3 | 3 | 1 tick | all four | 17,318,265 |
| `AgentReplicationTerminal` | terminal | 3 | 3 | 1 tick | `Converged`, `NoLostSuccessor` | 9,544,635 |
| `AgentReplicationIntent` | state, with `Intend` writes | 3 | 3 | 1 tick | all five | 17,959,029 |
| `AgentReplicationIntentTerminal` | terminal, with `Intend` writes | 3 | 3 | 1 tick | `LocalWriteTakesEffect` | 16,350,444 |
| `AgentReplicationLegacyCounter` | state, with `Intend` writes; every host's first counter is 0 | 3 | 3 | 1 tick | all five | 17,959,029 |
| `AgentReplicationLegacyReceiver` | terminal; received by a build that reads an absent host as 0 | 3 | 3 | 1 tick | `Converged`, `NoLostSuccessor` | 9,544,635 |
| `AgentReplicationRemoval` | removal, with re-creations (`Intend`) | 3 | 3 | 1 tick | `Converged`, `NoLostSuccessor`, `LocalWriteTakesEffect` | 13,561,419 |
| `AgentReplicationRemovalLossy` | removal, with re-creations; any delivery lost and recovered by backfill | 2 | 3 | 1 tick | `Converged`, `NoLostSuccessor`, `LocalWriteTakesEffect` | 2,257,939 |

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
| `ReceiveSeesTombstones` (ADR 0081 addendum) | the receive read the stored entity with `getEntity`, which filters tombstones | removal kind, `NoLostSuccessor` in three steps: A writes, A removes, and A receives its own first version late, which replaces the removal |
| `BackfillServesTombstones` (ADR 0081 addendum) | the backfill responder read the same way and answered `deleted` | removal kind, lossy, `Converged` in three steps: A removes, B's delivery is lost, and B's backfill is answered `deleted`, so B keeps the entity |
| `WriteSeesTombstones` (ADR 0081 addendum) | the local write resolution read the persisted row with `getEntity` too | removal kind, `NoLostSuccessor` in six steps: A writes and removes, B receives the removal and writes the row afresh on `{B:1}` alone, and A's first version, arriving late, wins over B's write on the canonical order |
| `RecreateKeepsFields` (ADR 0081 addendum) | a row built afresh over a tombstone was resolved against it as if concurrent | removal kind, `LocalWriteTakesEffect` in two steps: A removes, then writes the row afresh at the same instant, and the tiebreak hands the removal back |
| `AtomicReceive` (ADR 0081 addendum) | every type but agent state, change sets and evolution sessions was read, then written after an await | removal kind, `NoLostSuccessor` in eight steps: B reads the stored row to receive A's version, writes twice locally, and the receive then writes A's version over both |

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
- **A removal ranks at its instant.** `effectiveUpdatedAt` takes the later
  of the variant's timestamp and `deletedAt`, so a removal concurrent with an
  edit goes by last-writer-wins on those instants, and on an append-only
  variant, whose edits never move its `createdAt`, the removal always wins.
  The model stamps a removal at its write time, which is this rule; the old
  rule, where a removal kept the timestamp of the row it removed, converges
  too and so has no counterexample here. It is checked by the resolver's and
  the receive's unit tests.
- **Seeding restores a deleted default.** The default templates and souls are
  seeded at every start, and a default the user deleted is created again
  under its id. That is a re-creation, which this model checks and which now
  wins on every device; whether a deleted default should stay deleted is a
  product decision (ADR 0081, addendum).
- **Hard deletes** (`hardDeleteAgent`, retention pruning) leave no tombstone
  and are not synced, so a late copy can restore such a row.
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
  host's counter. A removal is an edit too: a tombstone with `deletedAt` set,
  written and synced like any other version, and linking the same pair again
  revives it under the same id. A tombstone is not terminal, so a link stays
  one last-writer-wins register and nothing new is checked (ADR 0078,
  2026-09-25 addendum).

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
- **Agent entities had the tombstone hole too.** The entity receive and its
  backfill read with `getEntity`. The addendum of ADR 0081 fixes it; the
  model is `AgentReplication`'s removal kind above.
- The model's clocks have no absent hosts. A host's first write at counter 0
  strictly dominates the version it extends only because `VectorClock.compare`
  ranks an absent host below 0
  ([ADR 0080](../../docs/adr/0080-a-present-counter-ranks-above-an-absent-host.md)).
  The regression for a host's first relink and removal is in the
  `AgentSyncService` suite.

## `Outbox` — append, collapse, claim, send and prune

The outbound queue of one device, which `SyncSequence` treats as a set of
counters per entity that is sent atomically and never fails. Here the box is
open. Enqueue appends one immutable row per version and never merges. One
drain at a time claims a bundle and collapses each entity's rows into one
send of its newest version by clock, covering every other counter and
carrying the attachment if any collapsed row owed it. Every collapsed row is
then marked sent, or all of them are retried up to `maxRetries`, then
`error`. A send also settles the entity's failed rows it supersedes. Sends
fail, time out and land anyway, marks throw, the process dies between the
send and the mark, claim leases run out, the same profile is torn down and
restarted, sent rows are pruned, and the monitor's Retry and Remove act on
failed rows. A key is an entity whose rows collapse — a journal entry, an
entry link, an agent entity or link, a config flag — and its versions are
ordered like its vector clocks; a version in `MediaVersions` owes the
attachment. The design is
[ADR 0086](../../docs/adr/0086-append-only-outbox.md), which supersedes the
enqueue-time merge of
[ADR 0085](../../docs/adr/0085-model-checked-outbox.md) and keeps its
orphan release and dispose quiesce. TLC's fairness check is far slower than
its safety check on this spec, so the two large configurations check safety
and the action properties, and three smaller ones add the liveness
properties.

| Property | Kind | Says |
|----------|------|------|
| `NoLostCounter` | invariant | every enqueued version is on the wire, still in a live row, or removed by the user |
| `CoversOnlyOlder` | invariant | a send never covers a counter newer than the payload it carries, so a peer never marks a version received that it does not hold |
| `RowsImmutable` | action | a row, once appended, keeps its payload (the successor of ADR 0085's `MergeNeverRegresses`) |
| `SentWasDelivered` | invariant | a row is `sent` only after its counter reached the room |
| `MediaNotDropped` | invariant | a row that owed the attachment is `sent` only after a send of its entity carried it |
| `PruneOnlySent` | action | pruning deletes only sent rows |
| `NewestLandsLast` | invariant | with callers enqueuing in order, the last payload of an entity in the room is the newest the room holds |
| `EveryRowSettles` | liveness | every pending or sending row ends sent, failed for good, or removed |
| `EnqueuedIsDelivered` | liveness | every enqueued version reaches the room, unless its row failed for good or was removed |

| Configuration | Enqueue order | Faults | Distinct states |
|---------------|---------------|--------|-----------------|
| `Outbox` | in order, three versions (the first owing the attachment), one simple message, bundles of two | failed sends, a mark that throws, a crash or a teardown; safety only | 945,340 |
| `OutboxConcurrent` | any order, three versions (the first owing the attachment), bundles of two | failed sends, a mark that throws, a crash or a teardown; safety only | 167,990 |
| `OutboxConcurrentLive` | any order, two versions (the first owing the attachment), bundles of two | failed sends, a mark that throws, a crash or a teardown | 4,814 |
| `OutboxOperator` | in order, two versions | failed sends, marks that throw, a crash or a teardown, the monitor's Retry | 5,890 |
| `OutboxGhost` | in order, two versions (the first owing the attachment) | timed-out sends that land late, marks that throw, a crash or a teardown, the monitor's Retry and Remove | 16,097 |

| Switch | Without it | Counterexample |
|--------|------------|----------------|
| `NewestByClock` | the collapse sends the row enqueued last | `CoversOnlyOlder`, five steps: v3 and then v2 are appended and sent as v2 covering 3 |
| `CoverCollapsed` | the send covers nothing it folded in | `NoLostCounter`, seven steps: v1 and v2 go out as v2 alone and both rows are marked sent |
| `CarryMedia` | the send carries the attachment only if its own row owed it | `MediaNotDropped`, seven steps: the audio row and the edit after it go out as the edit, and the audio row is marked sent |
| `AbsorbErrorRows` | a send leaves the entity's failed rows alone | `NewestLandsLast`, fifteen steps: v1 fails to `error`, v2 is sent, the monitor retries v1 and it lands last — ADR 0085's residual 2, which this design resolves |
| `ReleaseBeforeDrain` | a claim a crash left behind waits out its lease | `NewestLandsLast`, ten steps (ADR 0085) |
| `QuiesceOnDispose` | dispose returns while its drain still sends | `NewestLandsLast`, nine steps (ADR 0085) |

What the model leaves out, deliberately or as a residual:

- **A timed-out send can land after a newer one** (ADR 0085's residual 1,
  unchanged). `OutboxGhost` allows it; with `NewestLandsLast` it fails in ten
  steps. Payloads the receiver orders by vector clock drop the late copy; a
  config flag or an AI configuration, applied in arrival order, is
  overwritten on the peer. The options — a stable Matrix transaction id per
  outbox row, a clock or timestamp for those payloads, no timeout while the
  SDK still retries — each change the wire or the protocol.
- **Remove of the newer row, then Retry of an older one**, sends the older
  value last (sixteen steps, with `UserRemoves` in `OutboxOperator`). That is
  the user's own reversal, not a stale retry: Remove is guarded by a
  confirmation that the change will not reach other devices.
- **A bundle does not settle a failed row that owes an attachment.** A bundle
  ships JSON only, so when an entity's other rows owe the attachment, the
  bundled send of a newer version leaves them alone; a later Retry sends
  that older version, with its attachment, after the newer one. Only journal
  entries carry attachments, and their receivers order the JSON by clock, so
  the older JSON is dropped and the attachment lands.
- **Clockless payloads follow the callers' order.** The collapse picks the
  config flag enqueued last; two callers setting one flag at once enqueue in
  whichever order their writes finish.
- The claim and the collapse are one step. Between the Dart claim and its
  collapse lookups only appends (rows the collapse did not read), the
  monitor (guarded by a compare-and-set on status) and pruning (sent rows
  only) can run.
- Claim order is the row id; priority is fixed per message type, and
  `createdAt` follows the id unless the wall clock steps back.
- `Teardown` is a profile switch or a closed-generation restart that brings
  the same profile back; the old generation's late marks hit a closed
  database and are not modelled (ADR 0085).

## `InboundQueue` — Matrix events into the queue, and the marker that resumes them

One room's inbound pipeline: timeline events reaching `inbound_event_queue`
live (`QueuePipelineCoordinator._handleLiveEvent`, in stream order) and
through catch-up walks (`BridgeCoordinator`, `QueueGapRecovery`: forward from
the applied anchor, or backward from the tip), the worker leasing, applying,
retrying and abandoning rows (`InboundWorker`, `InboundQueue`), the per-room
`queue_markers` row — the applied marker (`QueueMarkerAdvancer.advanceIfNewer`)
and the resume floor with its revision compare-and-set — resurrection of
abandoned rows, and stop, start and crash. `SyncSequence` is the layer above:
it models counters and peer backfill, not how timeline events are consumed.

An event's number is both its timeline position and its origin timestamp, so
equal-millisecond collisions are left out. The durable marker decides what
the next catch-up fetches after a crash: the forward walk from the anchor
when `BridgeMarker.anchorIsSafe`, otherwise the backward walk down to
`BridgeMarker.backwardWalkBound`. The decision is
[ADR 0084](../../docs/adr/0084-model-checked-inbound-queue.md).

| Property | Kind | Says |
|----------|------|------|
| `NoSilentLoss` | invariant | every event the homeserver holds is captured (a queue row in any status, abandoned included) or fetched by the catch-up the durable marker selects; a crash at any step loses nothing |
| `HeldIsLeased` | invariant | the worker holds only a row it leased |
| `CapHolds` | invariant | no row is resurrected past its hard cap |
| `MarkerMonotone` | action | `last_applied_ts` and the anchor never move back |
| `AppliedIsFinal` | action | an applied row stays applied: nothing re-arms a committed row, and a duplicate is ignored by the `event_id` UNIQUE constraint |
| `QueuedEventuallySettled` | liveness | every queued event is eventually applied or dead-lettered (abandoned) |
| `EventuallyCaptured` | liveness | every plaintext event the homeserver holds is eventually captured |

| Configuration | Events | Crashes/stops | Faults (one of) | Distinct states |
|---------------|--------|---------------|-----------------|-----------------|
| `InboundQueue` | 3, one on the server at the first start | 1 | failed enqueue, failed claim read, incomplete walk, worker throw; one retry, two resurrection passes (hard cap one), a gap-recovery walk | 40,494,743 |
| `InboundQueueCipher` | 3, event 2 encrypted until its key arrives | 1 | failed resume-floor write, failed enqueue | 1,607,563 |
| `InboundQueueCrash` | 4 | 2 | incomplete walk, failed claim read | 3,484,605 |
| `InboundQueueLiveness` | 3 | 1 | worker throw, incomplete walk, failed enqueue (fairness) | 410,386 |

The fixes are switches, so each one's old behaviour is a configuration away;
every checked-in configuration sets them `TRUE`. "Claiming the range above
the marker" is lowering the resume floor to one millisecond above
`last_applied_ts` (`InboundQueue.claimAboveMarker`): the claim alone keeps the
anchor safe, so the forward walk stays the normal path, but once anything
newer applies past it the next walk goes backward to the claim.

| Switch | Old behaviour | Counterexample |
|--------|---------------|----------------|
| `ClaimOnWalk` | a walk enqueued events newer than the marker before it had fetched all of them | `NoSilentLoss`, 12 steps: a backward walk pages the tip first, its tip event applies and becomes the anchor, and the older pages are never fetched — by a crash's startup walk or by the bridge's retry, which both walk forward from that anchor. A coalesced "Catch up now" pass does the same in 13 steps |
| `ClaimOnGap` | a limited sync only requested a pass | `NoSilentLoss`, 10 steps: a limited sync arrives while a walk is in flight, the post-gap live event applies, the in-flight walk completes and clears the floor, and the rerun walks forward from the new anchor past the gap |
| `ClaimOnStart` | the startup bridge read the marker after the live stream and the worker had started | `NoSilentLoss`, 7 steps: live events apply before the startup walk reads the marker, and the events that arrived while the app was down fall behind the anchor. With ciphertext (`InboundQueueCipher`), 4 steps: a fresh device's startup walk was bounded by the floor of the first live ciphertext, so its older history was never fetched |
| `FailedEnqueueLowersFloor` | `_safeEnqueue` logged and dropped an insert that threw | `NoSilentLoss`, 10 steps: the next live event applies and the dropped one is behind the anchor for good. Lowering the floor alone left `EventuallyCaptured` failing until an unrelated trigger, so the failure also requests a pass |
| `WorkerSurvivesErrors` | a throw in the worker loop ended it; nothing restarted it while the coordinator ran | `QueuedEventuallySettled`: after one worker throw, queued rows stay queued forever |
| `RetainFailedClaim` | a claim whose marker read threw was logged and dropped, and start and the limited-sync handler carried on | `NoSilentLoss`, 5 steps: the start claim's read fails, a live event applies, and what arrived while the app was down is behind the anchor. A retained claim is resolved against the marker as it then is, before any queue insert |
| `GuardedResurrect` | the resurrection UPDATE flipped the selected rows by id | `AppliedIsFinal`, 11 steps: a second pass re-arms the row, the worker applies it, and the first pass's UPDATE flips the applied row back to `enqueued` |
| `ResurrectRechecksCap` | the UPDATE re-checked only `status = 'abandoned'` | `CapHolds`, 12 steps: a second pass re-arms the selected row, the worker abandons it again, and the first pass resurrects it past its hard cap. The same holds for the reason filter of `resurrectByReason`, which the model leaves out |
| `CheckpointForward` | an incomplete forward walk left its claim at the old marker | no violation (14,186,906 states): the checkpoint is efficiency, not safety. Without it, a retry after a capped or failed forward walk whose rows applied walks backward over everything the walk already fetched |

Two spec mutants also pass, and say which parts are load-bearing. Without
`advanceIfNewer`'s clamp (the marker stopping below an older active row)
`NoSilentLoss` still holds: a row held back is already captured, so the
clamp keeps `last_applied_ts` honest but is not what prevents loss. Without
the checkpoint's own compare-and-set it holds as well, so
`checkpointResumeWalk` has none: an observation made during the walk is of
an event the walk has passed or has yet to reach. Without the completion's
compare-and-set it fails in 8 steps (`ClaimOnGap`'s trace, with the claim
cleared).

What the model leaves out, deliberately or as a residual:

- **A limited sync's slice can apply before the bridge sees the sync
  (`SliceRace`).** The Matrix SDK adds the slice's events to
  `onTimelineEvent` before it publishes `onSync`, and awaits database writes
  in between. If the live handler enqueues a post-gap event and the worker
  applies it before `BridgeCoordinator` handles the sync and claims the gap,
  the anchor passes the gap first. `SliceRace = TRUE` finds it in 10 steps,
  and every checked-in configuration sets it `FALSE`. The window is the
  worker's whole apply-and-commit against a few database reads, so it is
  narrow, and the sequence-log backfill (`SyncSequence`) repairs a lost
  sequenced payload from a peer. Closing it needs a decision: take live
  events from `Client.onSync`'s room updates, where the `limited` flag and
  the slice arrive together, so the claim precedes the enqueue; or let only
  walk-contiguous rows move the anchor, with a durable captured-frontier
  column and a migration; or accept the window and rely on backfill.
- **Equal milliseconds.** A claim is one millisecond above the marker and a
  checkpoint one above the walk's newest event. An uncaptured event in the
  same millisecond as the marker or the cursor, later in timeline order, is
  outside a backward walk bounded there. `backwardWalkBound` takes the lower
  of the floor and `last_applied_ts`, so a claim never narrows a walk past the
  applied millisecond, and a backward page that crosses the bound is
  enqueued whole.
- **Timestamps are positions.** The marker, the floor and the walks all
  order by `originServerTs`; homeservers assign it, and the model assumes it
  follows timeline order.
- **The bridge gives up after three incomplete passes in a row.** The model
  retries until a walk completes. In the app the durable floor stays, and the
  next trigger — to-device traffic, a limited sync, a restart, "Catch up now"
  — walks from it.
- **Applying twice.** A crash between the journal write and the queue commit,
  or a transaction that rolls back, re-applies the row after its lease
  expires. The queue guarantees at-least-once apply and one row per event;
  that a second apply changes nothing is `SyncEventProcessor`'s vector-clock
  resolution, which other specs cover.
- **One room.** `pruneStrandedEntries` abandoning another room's rows on a
  room switch, retry backoffs, barriers (`pendingBarrier`) and the
  attachment deadline are outside it; abandoning is one nondeterministic
  outcome, and a resurrected row is queued again.

## `JournalReplication` — a journal entry on every device

One journal entry — a task, a note, a habit completion, a checklist item — on
two or three devices. Local writes edit or soft-delete the entry the live read
returns (`journalEntityById`), or an entry a screen read earlier; a writer that
reads the deletion brings the entry back; label writes race the versions that
sync in; and the user resolves the conflicts the devices raise. Every version
is delivered to every device in any order and any number of times, and in the
lossy configuration a delivery can be lost and recovered by backfill from the
writer's stored row. The write decision for local writes and the receive alike
is `JournalDb.updateJournalEntity` with `detectConflict`
(`database_entity_ops.dart`): newer applies, equal or older is refused, and a
concurrent version is stored as the entry's single `Conflict` row for the user
to decide. Journal entries never merge on their own, so the question is not
only convergence but whether a divergence is ever silent. The sidecar
configurations add the JSON sidecar — the payload a device sends — with a
receive from an older peer, which names only a path, the outbox's refresh, and
a receive rolled back by a failed embedded link. The decision is
[ADR 0083](../../docs/adr/0083-model-checked-journal-replication.md).

| Property | Kind | Says |
|----------|------|------|
| `Converged` | invariant | once every version has reached every device, directly or by backfill, the devices hold the same entry — or all hold a deletion, or one shows the user a conflict: divergence is never silent |
| `NoLostSuccessor` | invariant | a row is never a version that a version the device received or wrote causally replaced: a deletion is not undone by a late copy |
| `NothingDropped` | invariant | every version a device received or wrote is kept by its row or by its open conflict — nothing is dropped without the user choosing so (except a conflict displaced from the one-row table, below) |
| `ConflictNotStale` | invariant | an open conflict never holds a version its row, or a version the device has seen, replaced: a stale copy neither re-opens a resolved conflict nor regresses an open one |
| `ConflictResolvable` | invariant | an open conflict can be opened and resolved, a deletion made here included |
| `SidecarMatchesRow` | invariant | once writes and receives have settled, every sidecar describes its device's stored row |

| Configuration | Devices | Writes | Adds | Checks | Distinct states |
|---------------|---------|--------|------|--------|-----------------|
| `JournalReplication` | 3 | 3 | stale reads, restores, resolutions | all but `SidecarMatchesRow` | 768,439 |
| `JournalReplicationLossy` | 2 | 3 | any delivery lost and recovered by backfill | the same | 98,283 |
| `JournalReplicationLabels` | 2 | 4 | `setLabels` and `suppressLabelOnTask` | the same | 168,713 |
| `JournalReplicationLegacy` | 2 | 3 | an entry created before clocks, a late copy of it in flight | the same | 35,444 |
| `JournalReplicationSidecar` | 2 | 3 | path-only receives, the sidecar queue, the outbox refresh; two queued sidecar writes at most | all six | 6,794,107 |
| `JournalReplicationSidecarRollback` | 2 | 2 | one receive rolled back and retried | all six | 439,585 |

The properties judge the code's decisions, which read clocks, against a ghost
history of the versions each one causally follows. On one device the last
save supersedes an earlier one it did not read whenever its clock covers it —
a screen saving an entry read before another save on the same device — which
is the design, and the ghost history says so too. With `N = 3` and four writes
(27 million states, fifteen minutes) every property holds as well; that run is
not checked in.

The design switches are the fixes, and each has a counterexample when set to
`FALSE` (run a copy of the configuration outside this directory):

| Switch | Old behaviour | Counterexample |
|--------|---------------|----------------|
| `ReceiveSeesTombstones` | the write decision read the stored row with `entityById`, which filters `deleted = false`: a deletion read as no row, and anything replaced it | `NoLostSuccessor`, six steps: A edits the entry and deletes it; B deletes it too and receives A's deletion; A's edit arrives late and brings the entry back on B, while A keeps it deleted. `NothingDropped`, five steps: A deletes, B edits concurrently, and B's edit replaces A's deletion on A without a conflict |
| `BackfillServesTombstones` | the backfill responder read with `journalEntityById` and answered `deleted` for a deleted entry | `Converged`, four steps: A deletes, B's delivery is lost, backfill answers `deleted`, and B keeps the entry |
| `ConflictSeesTombstone` | the conflict page read the local side with `journalEntityById` | `ConflictResolvable`, four steps: B edits, A deletes concurrently and receives B's edit — a delete-versus-edit conflict the page could not open ("entry not found") |
| `ResolveOnlyCovered` | any applied write marked the entry's conflict resolved | `NothingDropped`, five steps: B's concurrent edit is A's open conflict; A edits again, and the conflict is marked resolved though A's edit never included B's. B's edit is gone from A without the user choosing; `Converged` still holds, because B raises the conflict again when A's edit arrives |
| `KeepNewerConflict` | a concurrent version always replaced the conflict row | `ConflictNotStale`, seven steps: A edits twice; B receives the second as a conflict, then the first, late, which replaces it |
| `LabelsRebuild` | `setLabels` forced a refused write with `overrideComparison`; `suppressLabelOnTask` wrote under the stored row's own clock, and then forced it | `NothingDropped`, four steps: A receives B's edit while its label editor holds the version before; the label write is refused as concurrent, then forced over B's edit. `Converged`, three steps: A suppresses a label, B refuses the write as equal to what it holds, and the devices differ for good |
| `RefuseNullClock` | a version without a clock was newer than any row | `NoLostSuccessor`, three steps: A deletes an entry created before clocks, and a late copy of that clockless version replaces the deletion |
| `RestoreSidecar` | a refused path-only receive left the incoming JSON in the sidecar | `SidecarMatchesRow`: the loader saves A's version over B's sidecar, B refuses it as concurrent, and B's sidecar describes a version B does not hold |
| `RefreshThroughQueue` | the outbox refreshed the sidecar with `journalEntityById` and saved it beside the sidecar queue | `SidecarMatchesRow`: A's refresh reads v1, A deletes the entry and writes its sidecar, the refresh then saves v1 over it, and the next refresh, finding no live row, saves nothing |

What the model leaves out, deliberately or as a residual:

- **One conflict row per entry.** `detectConflict` stores the incoming
  version under the entry's id. A second concurrent version — from a third
  device, or this device's own save refused while a conflict is open —
  displaces the first on this device (the ghost `displaced`; `NothingDropped`
  and `ConflictNotStale` are claimed except for it). A displaced version from
  another device stays that device's row, and the next version it receives
  from here raises the conflict there again. A displaced save of this device's
  own was never sent and is gone. The options: a conflict table keyed by entry
  and version, with the page listing every open version; folding a second
  version into the open conflict as a three-way choice; or refusing a local
  save while its entry has an open conflict. Each changes what the user sees,
  so it is a product decision.
- **Concurrent edits never merge on their own.** Every concurrent pair is a
  conflict for the user, however disjoint the fields. Auto-merging disjoint
  fields, or last-writer-wins as agent entities do, is a product decision.
- **Two concurrent deletions merge without the user**: each device keeps the
  canonically greater one's fields under the join of both clocks. A deletion
  displaced from the conflict table on a third device may never meet the
  other, and the devices then hold different deletions — all deleted, which
  `Converged` accepts.
- **A creation under a reused id replaces a deleted row** (`overwrite:
  false`), as before, under a clock that does not cover the deletion. Peers
  then see an edit concurrent with the deletion, and the user decides. Whether
  a re-creation should win, lose, or ask is a product decision.
- **The sidecar is written before the receive commits.** `updateJournalEntity`
  runs nested in the receive's transaction with the embedded links, so a
  rolled-back receive can leave the sidecar describing a version that is not
  stored until the event is retried. The rollback configuration shows the retry
  heals it; a failed `persistEntityJson` is not modelled.
- **Hard deletes** (`purgeDeleted`) remove rows, and backfill then answers
  `deleted`; a device that never received the deletion keeps the entry.
- **Clockless versions** come only from builds that predate vector clocks;
  `RefuseNullClock` assumes no build writes without one today.
- Embedded entry links are ordered by `JournalDb.upsertEntryLink`, the entry
  links of [ADR 0078](../../docs/adr/0078-entry-link-versions-are-ordered.md).

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

The lease, the chat recovery and the version heads have generated traces of
their own, over devices that are each a real agent database, sync service
and — for the first two — wake orchestrator, wake-intent store and
scheduled-wake manager (`test/features/agents/wake/wake_device_bench.dart`,
over `test/features/agents/sync/agent_replica_bench.dart`, a network of
`test/features/agents/agent_test_device.dart` devices). Writes travel as
single sync messages through the real receive decision; a crash is the next
process over the same stores.

In `test/features/agents/wake/scheduled_wake_manager_model_conformance.dart`
(300 runs), the real goal Phase A arms the period's escalation on either of
two devices, the real lease claims, settles and fires it, and the trace
chooses when the host lookup the lease awaits and the coalesced wake-intent
write come back — so sync can land between a claim's approval and the
re-read before firing, and a crash between the intent reaching the disk and
the consume. Time moves a minute at a time with the model's `Tick` guards:
settle three, lease five, delivery within one, a device down up to eight.
After every step it checks `NoDeviceRunsTwice`, `WindowTerminal`, `Converged`
and, until a crash, `AtMostOnce`; after two drained hours every armed window
has run, counting a re-arm over a consumed window as a window even when the
code writes nothing a device could fire (`NoLostWindow`). Each design switch
but one fails it with a shrunk trace: `ArmMode = "fresh"` (`NoLostWindow`) and
the carried clock at the same instant (`WindowTerminal`) in the same seven
steps — arm, the claim, its settle and the fire, re-arm on the same device;
`FlushBeforeConsume = FALSE` (`NoLostWindow`: arm, four ticks, crash);
`OwedCheck = FALSE` (`NoDeviceRunsTwice`: arm, five ticks, a crash after the
intent landed and before the consume, two ticks); the resolver without
`consumed` terminal at one instant (`WindowTerminal`, seven steps: the peer
crashes, the other device fires, the peer restarts on its stale replica and
arms) or without the later deadline (`WindowTerminal`, eleven steps: the same
over the re-armed window); and no settle wait (`NoLostWindow` of the second
window, sixteen steps).
`ConsumeCurrentRow = FALSE` is not reached: a snapshot consume only differs
once the next window syncs in during the fire, which needs a window run on
two devices, and the local write path's resolution (ADR 0068) masks it besides;
its regressions stay in the suite (group *firing and consuming a record*).
Neither are the re-reads after the host lookup and before firing, singly or
together: under the model's timing no consumed or crossing version can
arrive in that gap, and their regressions stay in the lease group. The
consume's transaction cannot be interleaved by a trace at all; a regression
pins its boundary. The trace also found the model's `FinishJob` to be
stronger than the code: the run's intent is settled by the same coalesced
settings write, so a crash between a run completing and that write landing
restores the intent and runs the window again on the same device
(`NoDeviceRunsTwice`: arm, the claim and fire, finish, crash, restart,
restore, finish). The trace lands the settle with the finish, as the model
does; see the residuals above.

In `test/features/goals/service/goal_chat_service_model_conformance.dart`
(200 runs), the author sends through the real `GoalChatService.sendMessage`,
each device's pre-scan maintenance is the real `restoreOldestPendingMessage`,
the recovery record is fired by the real lease rather than taken as given,
and every wake runs the real router (`goalAgentWakeRunnersProvider`), which
hands a message it has to answer to a scripted workflow the trace commits or
fails. Ten minutes are the model's unit (the grace is three, the run cap
one); sync delivers within a minute, below half the lease's settle. After
every step it checks `AtMostOneReply`; after four drained hours, `Answered`.
It found a bug: the due query compared `scheduledAt` as a string with a local
`now`, and a chat recovery is written in UTC, so east of Greenwich the peer
fired the recovery as soon as it synced in and answered beside the author
(`AtMostOneReply`: four minutes, the peer's scan, fourteen minutes), and west
of it the recovery waited hours (`Answered`, after a failed first run). The
read now bounds the range scan in UTC and decides by the instant; a
regression in the repository suite fails with the fix reverted in UTC,
UTC+2 and UTC−7, where the trace fails east and west of UTC but not in it.
A router that answers a message already answered fails it in one
step (a tick; the author's wake and the recovery both answer), and
maintenance that enqueues the message as before ADR 0069
(`Recovery = "eager"`) in one (the author's run fails, and both devices'
maintenance enqueue it). Two switches are not reached: the next window
due at the last deadline plus the grace equals the lease's lapse unless a
claim comes late and a second device then runs the next window inside the
first run's cap, and the author's answering wake not consuming the record is
masked by the router, which finds the message answered. Their regressions
stay in `goal_chat_service_test.dart` and `goal_agent_providers_test.dart`.

The version heads are traced in `test/features/agents/sync/version_heads_conformance.dart`,
registered from the suites of the three services that own them (150 runs
each): `SoulVersionOps`, `AgentTemplateCrud` (`Kind = "soul"`, with
rollbacks) and `GoalSpecRevisionService` (`Kind = "goal"`). Two devices edit
offline, three edits each, the second device's clock two minutes ahead; the
rows are exchanged one message at a time in generated orders. Whenever
everything has been delivered it checks `Converged`, `HeadResolves` — and
that the service's active read resolves to the head — and, after an edit made
with everything received, `SettlesAfterCleanEdit`; at the end, a clean edit
on the device that did not edit last must settle whatever concurrent edits
left. `SupersedeAll = FALSE` fails it in two steps (both devices edit, then
the settling edit), as does a soul or template version that archives only the
head's version; a rollback that archives nothing fails it in two; a head move
built on a null clock (the ADR 0068 addendum) fails it in one, through the
clock skew. The goal head resolver's higher-ordinal rule is not needed by any
of the model's properties, and removing it passes.

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

Removals have theirs. In
`test/features/agents/sync/agent_removal_model_conformance.dart` (a part of
the suite of `agent_entity_receive.dart`), a day plan on three devices of a
`ReplicaNetwork` — each a real agent database, repository and sync service —
is edited, deleted and drafted again by the product's writers: an edit or a
deletion of the row `getEntity` reads, so a draft over a deleted plan is
built afresh, and stale edits and deletions from snapshots. One device's
clock runs ahead. The writes are delivered in generated orders through
`resolveReceivedAgentEntity`, and deliveries are lost and recovered from the
writer's stored version. After every step `NoLostSuccessor` must hold, a
draft must keep its fields on its device (`LocalWriteTakesEffect`), and after
everything, `Converged`. Reading the stored row with `getEntity` in the
receive, reading it with `getEntity` in the write resolution, or resolving a
re-creation as concurrent each fails it. The two-device regressions — a
removal reaching the other device, a late copy restoring nothing, a lost
removal recovered by backfill, a removal concurrent with an edit, a plan
drafted again — are examples in the same suite and in the `AgentSyncService`
suite; the receive transaction of every type, the backfill of a tombstone and
own-counter settlement of a removal are examples in the sync processor's and
the backfill handler's suites.

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

The outbox has one too. `test/features/sync/outbox/outbox_model_conformance.dart`
(a part of the enqueue writer's suite) drives the real `OutboxEnqueueWriter`,
`SyncDatabase` outbox, `DatabaseOutboxRepository` and `OutboxProcessor` over
an in-memory database through generated traces of two entities: an agent
entity appended by the real writer, concurrently, alongside drains, and out
of order (a newer version's enqueue arriving first), and a journal entry
whose first row owes its audio and whose later rows are JSON-only edits.
Drains collapse each entity's rows when they send; they fail, or lose their
marks (the rows stay `sending`, as after a crash between send and mark); time
passes beyond the claim lease; crashes build a fresh writer, repository and
processor; sent rows are pruned; the monitor retries a failed row. A drain
releases orphaned claims first, as `sendNext` does. After every step it
checks `NoLostCounter`, `CoversOnlyOlder`, `RowsImmutable`,
`SentWasDelivered`, `MediaNotDropped`, `PruneOnlySent` and, while enqueues
arrived in order, `NewestLandsLast`; after draining everything, that every
enqueued version reached the wire or a row that failed for good and that no
row is left pending or sending. Collapsing onto the row enqueued last fails
it in one step (`enqueueLatePair`), dropping the covered counters in one,
dropping the attachment in two (`journalEdit` twice), leaving failed rows out
of the collapse in five (a stale Retry), and a release that does nothing in
two. The regressions — concurrent enqueues losing nothing, the newest sent
once with every counter covered, the attachment sent exactly once across the
audio row and its edit, a superseded failed row settled, and pruning only
after the collapse marks — are examples in the processor's and the writer's
suites.

The inbound queue has one. In
`test/features/sync/queue/inbound_event_queue_model_conformance.dart` (a part
of the `InboundQueue` suite), a five-event room drives the real
`InboundQueue` — its enqueue, lease, commit, retry and skip, the marker
advance, the resume floor with its claims, checkpoints and completion
compare-and-set — through generated interleavings of live deliveries,
limited-sync gaps, a late key, claims whose marker read fails, forward and
backward walks that step, fail and complete, worker commits, retries and
skips, and crashes (a fresh queue over
the same database, losing the process-local revisions and retained floors).
The walks and the live stream follow the coordinator's protocol and choose
their direction with the real `BridgeMarker`. After every step
`NoSilentLoss`, `MarkerMonotone` and `AppliedIsFinal` must hold against the
durable marker row. Dropping the completion's compare-and-set, ignoring the
walk's unresolved ciphertext in a checkpoint, or dropping a claim whose
marker read failed fails it; so does leaving out the gap claim in the
driver.
The coordinator's wiring — the claims on start, on a limited sync and at
every walk, the checkpoint and the failed-enqueue floor — has regressions
in the coordinator's and the bridge's suites, each failing with its fix
reverted.

Journal entries have theirs. In
`test/database/journal_replication_model_conformance.dart` (a part of the
`JournalDb` entity-ops suite), one entry on three devices — each a real
in-memory `JournalDb` — is edited, deleted, edited from an entry a screen read
earlier, restored after a deletion, and resolved by the user through the real
`resolveToSide`, and the versions are delivered in generated orders through
`JournalDb.updateJournalEntity`, repeated, late, or lost and recovered from the
writer's stored row. Every version carries the model's ghost history. After
every step `NoLostSuccessor`, `NothingDropped` and `ConflictNotStale` must
hold, and after everything, `Converged`. Reading the stored row with
`entityById` in the write decision, settling any conflict on an applied write,
not merging two concurrent deletions, or letting a late copy replace an open
conflict each fails it; the last needs the trace's four hundred runs. The
two-device regressions of every switch — the late copy refused, the edit
concurrent with a deletion, the clockless copy, the restored sidecar, the
label writes built again on the stored row, the soft-deleted entry served by
backfill, the conflict page over a deletion — are examples in the suites of
`database_entity_ops.dart`, `labels_repository.dart`,
`backfill_response_handler.dart`, `sync_event_processor.dart`,
`outbox_enqueue_writer.dart` (through `OutboxService`),
`persistence_updates.dart` and `conflict_detail_route.dart`, and each fails
with its fix reverted.

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
