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
| `DayProcessingJob` | refine | 2 | 1 | 1 | 6,377,091 |
| `DayProcessingJobDraft` | draft | 2 | 1 | 1 | 6,377,091 |

Each takes about two and a half minutes. Mutations, in a temporary copy:

| Mutation | Counterexample |
|----------|----------------|
| `AttachToLiveWake = FALSE` (the code before ADR 0070) | `AtMostOneLiveWake`: lane 1 claims, enqueues and records its wake, its lease lapses while it waits, lane 2 re-claims and enqueues a second. With a retry tap the trace is claim, `retryNow`, claim; a timed-out wait followed by the retry is the same length |
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

The processing job has one too:
`test/features/daily_os_next/services/day_agent_job_executor_model_conformance.dart`
(a part of the executor's suite) drives the real outbox repository over an
in-memory database, the real processor and the real executor, with two lanes
claiming one refine request, through generated traces of claims, three-minute
steps that lapse the lease and the wait together, wake starts, commits,
failures and aborts, retry taps and crashes (a fresh process whose predecessor
can no longer write). After every step it checks `AtMostOneLiveWake`,
`NoInferenceAfterArtifact` and `AtMostOneArtifact`. Making the executor ignore
the live wake fails it with the trace `claimA, retryNow, claimB`. The digest's
two recovery fixes have direct regressions instead: the digest wake leaves no
intent across a simulated restart in the wake-intent suite, and the drain-held
and held-back windows are probed in the orchestrator suite.

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
