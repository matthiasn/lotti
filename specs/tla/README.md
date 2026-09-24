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

| Configuration | Kind | Replicas | Writes | Clock skew | Checks | Distinct states |
|---------------|------|----------|--------|------------|--------|-----------------|
| `AgentReplication` | state | 3 | 3 | 1 tick | all four | 17,318,265 |
| `AgentReplicationTerminal` | terminal | 3 | 3 | 1 tick | `Converged`, `NoLostSuccessor` | 9,544,635 |

The four design switches are the fixes, and each has a counterexample when
set to `FALSE` (run a copy of the configuration outside this directory):

| Switch | Old behaviour | Counterexample |
|--------|---------------|----------------|
| `ThrottleKeepsTimestamp` | the throttle stamped `updatedAt` on a row it never syncs | `Converged`: A writes v1 at t0, its throttle stamps t2 locally, B writes v2 at t1; A keeps v1 against v2 for ever, B and C keep v2 |
| `CountersJoinAlways` | G-counters were joined only on a concurrent conflict | `OwnCountKept`: B increments, merges A's v1 keeping both counts under v1's clock, then A's successor of v1 — which never saw B's count — replaces the row by causal dominance |
| `ResolveLocalWrites` | a write replaced the row whatever it was built on, under the clock it was built on | terminal: `Converged` — B receives A's retraction, then writes an edit from a stale snapshot or a null clock; B keeps the edit, A and C the retraction. state: `OwnCountKept` — a snapshot write drops the host's own increment |
| `ClampTimestamp` | a successor's `updatedAt` could be older than its predecessor's | `Converged`: a successor written on a lagging clock loses to a third concurrent version that its predecessor beat, so arrival order decides |

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
- Links (`AgentLink`) keep plain last-writer-wins and are not modelled.

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

The confirmation model separates the committed claim from the post-commit
outbox flush. `FlushFails` still permits dispatch after the caller verifies its
unique persisted decision. Changing that transition to `done` reproduces the
stranded confirmation as a `ConfirmedMeansApplied` counterexample. Service
regressions exercise the real sync service and Drift transactions with a
throwing outbox, for both confirmation and rejection.

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
by the resolver's unit regression instead.

## Changing a spec

Keep the header's action-to-code map current. When a change is meant to fix a
hole, first reproduce the hole: run the configuration against the spec of the
old behaviour and keep the counterexample for the pull request. After the fix,
check that the property fails again when the fix is mutated away — a property
that cannot fail proves nothing.
