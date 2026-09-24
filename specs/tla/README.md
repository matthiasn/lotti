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
| `BoundRowsHavePayload` | invariant | the originator only answers from rows whose payload is on disk |
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
4.4 million distinct states each, a few minutes in total.

What the configurations deliberately leave out:

- **Delivery under faults.** A swallowed enqueue failure or an event a peer
  abandons for good is not retried, so `EventuallyDelivered` is only claimed
  without faults.
- **Unnamed reservations after a crash.** They cannot be settled, so a request
  for one stays open until the requester gives up — which is why
  `SyncSequenceCrashUnnamed` checks safety only.

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

Both guards have mutation switches. In a temporary copy of the configuration,
set one switch to `FALSE` and run TLC against `OwnCounterSettlement.tla`:

| Mutation | Expected counterexample |
|----------|-------------------------|
| `RecheckSequence = FALSE` | `NoFalseBurn`: the first row read misses, migration inserts the row and removes the settings fallback, the second read misses, settlement burns the committed counter |
| `RequireDurableEnqueue = FALSE` | `BoundHasQueuedPayload`: an earlier batch answer attempts a resend, its enqueue fails (or queues an older version), settlement skips its own enqueue and binds |

Keep mutation configurations outside this directory: CI runs every checked-in
configuration and expects each to pass. The handler suite has deterministic
regressions for both races, newer payload versions, migrated unnamed/already
settled rows, and a failed sequence-log recheck. Reverting the Dart guards makes
all six new regressions fail.

## `WakeRuntime` — agent wakes

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
retry — through the claim, the tool dispatch and the post-confirm hook. A
reject claims the item the same way a confirm does. The ghost `applied` counts
how often the change actually took effect.

| Property | Kind | Says |
|----------|------|------|
| `AtMostOnceApply` | invariant | a confirmed change takes effect at most once |
| `RejectedMeansNotApplied` | invariant | an item shown rejected never took effect |
| `ConfirmedMeansApplied` | invariant | an item shown confirmed, with no confirm in flight, took effect |

| Configuration | Callers | Faults | Crashes | Checks | Distinct states |
|---------------|---------|--------|---------|--------|-----------------|
| `ChangeSetConfirm` | 2 | dispatch fails, hook throws | 0 | all three | 97 |
| `ChangeSetConfirmFaults` | 2 | dispatch fails, hook throws | 1 | all but `ConfirmedMeansApplied` | 184 |

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
cascade, a staged retraction, a wake's consolidation of an older set — and
the sync that carries each write to the other devices as a message delivered
in any order, applied through the vector-clock comparison and the concurrent
resolver. The ghost `applied` counts, per device, how often each change took
effect. The decision is
[ADR 0067](../../docs/adr/0067-model-checked-change-set-lifecycle.md).

Four switches are the fixes, and each is a mutation point: `AtomicWrites`
(every local write of a set re-reads it in its transaction and changes only
its own item), `AtomicReceive` (sync compares and writes a received set in
one transaction), `ItemMerge` (concurrent versions merge item by item by a
per-item revision) and `PendingCopiesOnly` (consolidation moves only pending
items). `RaceFree` restricts the environment: no item is decided on two
devices before they have synced.

| Property | Kind | Says |
|----------|------|------|
| `AtMostOnceApply` | invariant | a change takes effect at most once, across all devices |
| `AtMostOncePerDevice` | invariant | ... and at most once per device |
| `AppliedStaysDecided` | invariant | a device that applied a change never shows it pending again — no decided item returns to pending except by its own failed dispatch |
| `StatusMatchesEffect` | invariant | once everything is delivered, every device shows `confirmed` exactly when the change was applied, and never `pending` or `rejected` for an applied one |
| `Converged` | invariant | once everything is delivered, the replicas agree |
| `MigrationAfterTarget` | invariant | a checklist migration never runs before its follow-up task exists |

| Configuration | Devices | Items | Checks | Distinct states |
|---------------|---------|-------|--------|-----------------|
| `ChangeSetLifecycle` | 1 | follow-up, migration, plain; both failure kinds; retraction | all but `Converged` | 2,115 |
| `ChangeSetLifecycleConsolidate` | 1 | an older set's item and its consolidated copy | all but `Converged`, `MigrationAfterTarget` | 133 |
| `ChangeSetLifecycleSync` | 2 | two plain items, `RaceFree` | all but `MigrationAfterTarget` | 698,263 |
| `ChangeSetLifecycleSyncSplit` | 2 | follow-up and migration, `RaceFree` | all | 47,954 |
| `ChangeSetLifecycleRace` | 2 | one item decided on both devices | `Converged` | 348,513 |

Each switch set to `FALSE` fails a configuration with a short trace (kept
outside this directory, as for `OwnCounterSettlement`):

| Mutation | Configuration | Counterexample |
|----------|---------------|----------------|
| `AtomicWrites = FALSE` | `ChangeSetLifecycle` | `AppliedStaysDecided`: the follow-up task's dispatch fails non-retryably and its auto-retraction reads the set; the plain item is claimed; the retraction writes its copy back, putting the claimed item to pending; the plain item's dispatch applies it. With every switch off, the same shape through a retryable revert ends with a retry applying the plain item a second time (`AtMostOnceApply`, 9 states) |
| `AtomicWrites = FALSE` | `ChangeSetLifecycleSyncSplit` | `AppliedStaysDecided`: the sibling rewrite reads the set, the migration is claimed and applied, the rewrite writes the migration back as pending |
| `PendingCopiesOnly = FALSE` | `ChangeSetLifecycleConsolidate` | `StatusMatchesEffect`: an item is claimed, a wake consolidates and copies it as `confirmed`, the dispatch fails and retracts the original — the copy claims a change that never landed |
| `ItemMerge = FALSE` | `ChangeSetLifecycleSync` | `AppliedStaysDecided`: each device confirms a different item; the whole-row winner drops one device's confirm, which that device then applies |
| `AtomicReceive = FALSE` | `ChangeSetLifecycleSync` | `AppliedStaysDecided`: a device reads its row to apply a peer's version, claims an item meanwhile, and writes the peer's version over the claim. With every switch off, the item is confirmed and applied twice (`AtMostOnceApply`, 8 states) |

What stays open — the residuals, each confirmed by TLC:

- **The same item decided on two devices before they sync.** Both claims
  succeed locally, and both devices dispatch: `ChangeSetLifecycleRace`
  violates `AtMostOnceApply` in 5 states (confirm and apply on each device),
  and, once one of the dispatches fails and reverts, `AppliedStaysDecided`,
  `StatusMatchesEffect` and `AtMostOncePerDevice` too. The replicas still
  converge. No local transaction can close it; it needs coordination — one
  device that applies a set's changes, a lease on the item, or tools that are
  idempotent per decision id. A confirm beating a concurrent rejection or
  retraction (the merge rank) is *not* part of this residual: it is checked.
- **Consolidation on one device racing a decision on another.** A wake that
  folds an older set into the survivor retracts the original and copies it as
  pending; a concurrent confirm of the original on another device wins the
  original back (the merge rank), but the copy stays pending on both, and
  applying it applies the change twice (`ChangeSetLifecycleConsolidate` with
  two devices: `AppliedStaysDecided` in 6 states). Closing it needs the copy
  to know its original — a provenance link checked before the copy is
  claimed — or consolidation that groups sets for display instead of copying
  rows.
- **Concurrent sets whose items do not align** — different proposals at one
  index — fall back to the whole-row winner, as before. The model's items
  are fixed, so it does not cover this.
- **Clients that predate the item revision** strip it when they rewrite a
  set; concurrent merges with such a write fall back to the status rank.

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
a confirm neither side superseded.

## Changing a spec

Keep the header's action-to-code map current. When a change is meant to fix a
hole, first reproduce the hole: run the configuration against the spec of the
old behaviour and keep the counterexample for the pull request. After the fix,
check that the property fails again when the fix is mutated away — a property
that cannot fail proves nothing.
