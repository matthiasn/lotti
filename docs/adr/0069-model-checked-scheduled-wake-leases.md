# ADR 0069: Model-Checked Scheduled-Wake Leases and Goal Chat Recovery

- Status: Accepted
- Date: 2026-09-24

## Context

Scheduled work that must run on one device — the coordinator digest
([ADR 0048](./0048-one-device-runs-the-coordinator-digest.md)), goal and
relationship escalations ([ADR 0054](./0054-deterministic-first-two-tier-wakes.md),
[ADR 0059](./0059-relationship-agent-runtime-and-nudge-generalization.md)) —
is elected by a lease on its synced scheduled-wake record: claim, settle,
confirm, fire, consume. The claims were that the lease picks exactly one device,
that another device takes over if the claimant dies, and that consumption is
terminal for a wake window. Goal chat was said to need no lease at all: the
typing device answers its own message.

We wrote both down in TLA+ as the code stood —
`specs/tla/ScheduledWakeLease.tla` (devices, one record replicated as a
vector-clocked register, the resolver's scheduled-wake rule, a sync channel
with a delivery bound, wall-clock time, crashes, deaths) and
`specs/tla/GoalChatReply.tla` (who answers one message) — and model-checked
them with TLC. Six holes came back as concrete traces:

1. **A second goal escalation of the day ran on one device, or none.** The
   record id is per period and every arm wrote a fresh row from a null vector
   clock at the period's fixed instant. Once a peer had run the first
   escalation, the re-arm was concurrent with that peer's consumed copy, and at
   one instant `consumed` wins: the peer kept it. The arming device ran the
   escalation alone; if it died first, nobody did (`NoLostWindow`), and the
   replicas disagreed until it wrote again (`Converged`).
2. **Carrying the clock was not enough.** With the consumed row's clock carried
   forward, a peer that missed the consumption and took over past `leaseUntil`
   wrote a claim of the *first* window that was concurrent with the re-arm, at
   the same instant, and won on `updatedAt`: the arming device went back to a
   window that had already run (`WindowTerminal`).
3. **A crash could lose a fired window.** Firing queued the wake — whose intent
   `WakeIntentStore` writes later, coalesced, to the settings database — and
   then consumed the record in the agent database. A crash after the consume
   committed and before the intent landed lost the window everywhere
   (`NoLostWindow`).
4. **A crash could run a fired window twice.** In the other order — intent on
   disk, consume not yet — the restart restored the wake, and the record, still
   pending under this device's lease, fired again (`NoDeviceRunsTwice`).
5. **The consume overwrote newer state.** It was built from the due-query
   snapshot and written over whatever the replica held by then — a newer window
   a peer had armed, for one — so a replica could regress (`Converged`).
6. **Two devices answered one chat message.** Runtime maintenance on every
   device re-enqueued the oldest unanswered goal chat message at startup,
   before every scheduled scan and on identity sync, and the goal wake router
   answered the oldest pending message on *any* goal wake. A peer's cadence
   tick answered a message whose author was still answering it
   (`AtMostOneReply`); reply ids are per run, so nothing collapsed the two.

Two suspected holes did not stand up. The lease has no fencing token, which
ADR 0018 rule 2 calls for; but the model shows that with the settle longer
than twice the sync delay, a claimant that confirms late still cannot fire
beside a taker-over, and where it can — a device that is suspended or offline
across the lease — no token would help, because what a stale claimant spends
is a model call, which has no side that could reject one. And relationship
escalations, armed only if absent under per-episode ids, and re-armed for a
retry at a later instant, check clean.

## Decision

1. **A later window of a goal escalation follows the consumed one.** Arming
   over a pending row writes nothing: that escalation has not run, and a rewrite
   would drop a peer's claim and the original baseline. Arming over a consumed
   row carries its vector clock forward and is due one millisecond after it, so
   the new window causally follows the consumption, and outranks every version
   of the consumed window on the resolver's later-deadline rule. Every device
   computes the same deadline.
2. **A fired record is consumed only once its wake is durable.**
   `ScheduledWakeManager` enqueues the wake, waits for
   `WakeOrchestrator.flushWakeIntents`, then consumes.
3. **A record whose wake is already owed is consumed, not fired.** Before the
   claim and again after the lease wait, the manager asks
   `WakeOrchestrator.owesWake` whether the wake firing *this window* — the
   record id and its deadline, tagged onto the job's intent when it fires — is
   queued, running or restorable, and if so consumes the record without
   firing it. Matching on the agent, workspace and tokens instead would take
   the record's next window, which often carries the same ones, for the one
   before it, and consume it unrun. The startup scan runs before
   `restoreWakeIntents`, which is what lets it see a restorable wake first.
4. **The consume is built from the current row.** It re-reads the row in a
   transaction and flips it only while it is still the fired window and
   pending, carrying the current row's clock.
5. **Only a message's own wake answers it, and recovery is lease-elected.** The
   router answers a goal chat message only on a wake carrying that message's
   token, and a wake whose message is already answered does nothing. Sending a
   message arms a synced recovery record, `goal-chat:<messageId>`, due
   `goalChatRecoveryGrace` (30 minutes) later; the wake that answers it consumes
   it. Maintenance no longer enqueues anything: it arms a missing record, or,
   after a recovery that did not answer, the next window, due when the last
   window's lease lapses — or a grace past a window the author consumed. The
   lease then picks one device to answer.
6. **The models gate the code**, as in ADR 0065 and ADR 0066: CI model-checks
   every configuration whenever the specs or the code they describe change.

## Consequences

- With two devices, one death or one crash, and two windows, `AtMostOnce`,
  `NoDeviceRunsTwice`, `WindowTerminal`, `Converged` and `NoLostWindow` hold on
  the lease; with three devices arming a relationship episode concurrently the
  safety properties hold. `AtMostOneReply` and eventual answering hold for a
  message with an author and one or two peers, a failing run and a device
  death.
- A message whose author could not answer it is answered half an hour later,
  not at the next scan; a failed recovery is retried when its lease lapses.
- Every scheduled-wake write this ADR introduces carries the clock of the
  row it replaces, so the local write path of
  [ADR 0068](./0068-model-checked-agent-convergence.md), which resolves a
  write against the persisted row, keeps its fields. Under that path alone
  the old null-clock re-arm would not even have pended locally: it is
  resolved into the consumed row it never saw.
- Decisions 2 and 3 cover the records whose wakes are wake intents. The
  coordinator digest's wake is not one
  ([ADR 0070](./0070-model-checked-digest-recovery-and-processing-jobs.md)):
  for it `owesWake` is always false and its consumed record is the single
  recovery path.
- Residuals, documented in `specs/tla/README.md` rather than closed:
  - **A device back from a crash or from sleep acts on its replica before sync
    catches up.** It can confirm its own settled claim, or answer a message
    whose reply it has not seen, beside a device that took over meanwhile —
    ADR 0048's partition case. The crash configuration therefore checks
    `NoDeviceRunsTwice`, not `AtMostOnce`. Closing it needs a round trip to a
    coordinator the app does not have.
  - **A run that finishes before its own consume commits.** If the process
    then dies before the consume, the record is still pending and nothing is
    owed, and the window runs again. The model assumes an inference outlasts a
    local write (`RunOutlastsConsume`).
  - **A failed intent write.** `flushWakeIntents` returns after a write that
    failed and was logged; a crash before the next write loses the window.

## Related

- `specs/tla/ScheduledWakeLease.tla`, `specs/tla/GoalChatReply.tla`,
  `specs/tla/README.md`
- [Coordinator and day-agent protocol](../../knowledge/features/daily_os_next/coordination-protocol.md)
- [Goal agents](../../knowledge/features/goals.md)
- [Wake orchestration](../../knowledge/features/agents/wake-orchestration.md)
- [ADR 0018: Convergent multi-device execution](./0018-convergent-multi-device-execution.md)
- [ADR 0048: One device runs the coordinator digest](./0048-one-device-runs-the-coordinator-digest.md)
- [ADR 0054: Deterministic-first two-tier wakes](./0054-deterministic-first-two-tier-wakes.md)
- [ADR 0066: Model-checked agent wakes and confirmations](./0066-model-checked-agent-wakes-and-confirmations.md)
