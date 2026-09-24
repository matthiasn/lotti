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

## `AgentMessageLog` — the agent's message DAG

One agent's causal message log on two devices, one of whose clocks runs
ahead: appends chained off the head pointer, other writes of the agent-state
row, the fork healer's join planned from one read and committed in a later
transaction (an append may run in between — the wake-start hook timed out
and the executor went ahead), a crash between the two, and sync delivering
every message, edge and state version once, in any order. The head is a
field of the state row, resolved by vector clock and then last-writer-wins.
The runtime is described in
[Agent memory and log compaction](../../knowledge/features/agents/memory-and-compaction.md)
and the decision in
[ADR 0071](../../docs/adr/0071-model-checked-agent-message-log.md).

| Property | Kind | Says |
|----------|------|------|
| `Acyclic` | invariant | no device's `messagePrev` graph holds a cycle |
| `EdgesImmutable` | invariant | an edge id names one parent, whoever writes it |
| `NoJoinOverNonTip` | invariant | a join is planned only over rows with no child on that device (short of the residual below) |
| `Converged` | invariant | once every row is delivered, both devices hold the same edges |
| `LocalHeadAdvances` | action | a device's own write moves its head only to a descendant of the old one |
| `EventuallySingleHead` | liveness | with fair delivery and healing, every device ends with one head |

| Configuration | Appends | Other state writes | Joins | Crashes | Checks | Distinct states |
|---------------|---------|--------------------|-------|---------|--------|-----------------|
| `AgentMessageLog` | 2 + 1 | 0 | 1 per device | 0 | safety | 1,523,825 |
| `AgentMessageLogStale` | 2 + 1 | 1, on the fast device | 0 | 0 | safety | 22,051 |
| `AgentMessageLogLiveness` | 1 + 1 | 1, on the fast device | 1 per device | 1 | all | 544,627 |

Each fix has a switch that is `TRUE` in the checked-in configurations. Set to
`FALSE` in a temporary copy, TLC reproduces the hole:

| Switch | Configuration | Counterexample |
|--------|---------------|----------------|
| `SafeRecovery` | `AgentMessageLogStale` | `Acyclic`, six steps: the fast device writes its state row with no head, appends a root `b1`; the other device receives `b1`, chains `a1` off it (older `createdAt`), receives the headless state row, which wins last-writer-wins, and its next append re-chains the log by `createdAt`: `msgprev-b1 → a1` closes a cycle |
| `ChainEdgeGate` | `AgentMessageLog` | `NoJoinOverNonTip`, five steps: `a1` is chained off `b1`; the other device receives `a1` but not its edge and joins `{a1, b1}` |
| `JoinEdgeGate` | `AgentMessageLog` | `NoJoinOverNonTip`, ten steps: a join of `{a1, b1}` and its device's state row reach the other device without the join's edges; that device appends `a2` off the join, so the join is no longer a head, and joins `{a1, a2, b1}` |

`appendJoin`'s head guard — move the head onto the join only while it sits
on a joined parent — was already right; it is what the timed-out heal needs.
Dropping it from `HealCommit` fails `LocalHeadAdvances` in six steps: the
healer plans `{a1, b1}`, the executor appends `a2` off `a1`, and the join
commits and moves the head back, orphaning `a2`.

Residuals:

- **The head pointer can still move back.** A state version from another
  device can win last-writer-wins with an ancestor of the local head. A
  temporary configuration checking `HeadNeverRegresses` fails in six steps;
  the next append forks off the old head, and the next wake that heals joins
  the fork. Fork healing is off by default, so the fork can stay. Closing it
  needs a DAG-aware merge of the head on receive, or a check on every append
  that the head has no child yet.
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

For the message log, `test/features/agents/sync/agent_message_log_model_conformance.dart`
(a part of the fork healer's suite) drives two real `AgentSyncService` and
`ForkHealer` replicas over in-memory stores, the second an hour ahead,
through generated appends, other state writes, heals and deliveries of
single outbox rows in any order, received by vector clock and then
last-writer-wins. After every step it checks `Acyclic`, `EdgesImmutable` and
`NoJoinOverNonTip`; after delivering everything and healing, `Converged` and
one head. Reverting head recovery fails it in six steps (the second device's
first append over a partly synced chain rewrites `msgprev-h1-m3`), removing
the chain-edge gate in eight. The join gate's interleaving is too specific for
random traces; its regressions are examples in the same suite. In
`test/features/agents/projection/compaction_summary_test.dart`, generated
histories of versions on two devices, a fold over what the folding device
held and any subset the observing device holds check `NoLostContext`
against `selectActiveSummary`; keying coverage by source alone fails it.

The confirmation model separates the committed claim from the post-commit
outbox flush. `FlushFails` still permits dispatch after the caller verifies its
unique persisted decision. Changing that transition to `done` reproduces the
stranded confirmation as a `ConfirmedMeansApplied` counterexample. Service
regressions exercise the real sync service and Drift transactions with a
throwing outbox, for both confirmation and rejection.

## Changing a spec

Keep the header's action-to-code map current. When a change is meant to fix a
hole, first reproduce the hole: run the configuration against the spec of the
old behaviour and keep the counterexample for the pull request. After the fix,
check that the property fails again when the fix is mutated away — a property
that cannot fail proves nothing.
