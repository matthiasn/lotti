# ADR 0090: One Device Wakes a Task Agent over a Given State

- Status: Accepted
- Date: 2026-09-26

## Context

A task agent is replicated on every device, and each device wakes it on its
own local edits (`localUpdateStream`; sync-originated changes deliberately do
not wake agents, ADR 0002). A synced audio entry is the exception: it queues
a content wake on the receiving device as well. So when the user starts a
task update on the desktop and keeps dictating into the phone, both devices
hold a wake for the same task. Each fires after its own throttle window, and
by then sync has usually merged the two devices' edits into the same task
state. Both run the agent over the same inputs: two inferences paid for one
result, and two sets of proposals competing for the same review.

Nothing coordinated them. The only cross-device election, the scheduled-wake
lease (ADR 0069), covers shared scheduled records, not subscription wakes; it
settles a claim for three minutes before firing, which would delay every task
update by as much.

## Decision

Devices coordinate each task-agent wake by broadcast, keyed by a digest of
the state the wake reads. The protocol is `specs/tla/AgentWakeCoordination.tla`,
model-checked before it was implemented; `AgentWakeCoordinator` implements it
action by action.

- **The state digest** is `taskStateDigest`: a `ContentDigest` over the
  vector clock (or `updatedAt`) of every journal entity the task context is
  built from — the task, the entities linked from and to it, its checklists
  and their items, its images' AI analyses. Replicas holding the same versions
  compute the same digest without coordinating. A wake's own journal writes
  are change-set proposals in the agent database, so they leave the digest
  alone.
- **Claim at dispatch.** When the drain dispatches a wake, the device
  broadcasts `claim(h)` at once, and repeats it every 45 seconds while the
  run is live.
- **Defer on a matching claim.** A device about to dispatch a wake over
  digest `h` holds it back while a peer's claim for `h` is live. A claim
  lapses two minutes after the last message from that peer, and every
  message re-arms it; a wake over a different digest is new work and runs.
- **Cancel on completion.** A successful run broadcasts `done(h)`; a device
  whose own digest is `h` drops its pending wake and settles its intent as
  covered. The digests of a peer's completed runs are kept apart from its
  live claim, so its next claim cannot erase them.
- **Release on failure.** A run that fails, is aborted, or never reaches its
  executor broadcasts `release(h)`, so peers proceed at once instead of
  waiting out the timer.
- **Fail open.** A digest that cannot be computed, an agent kind without one,
  a lost message, a crash, or a peer that never returns can cost a duplicate
  run, never a lost one. A wake the user asks for explicitly always runs.
- **Transport.** A new `SyncMessage.agentWakeCoordination`, not
  sequence-tracked, at high outbox priority. A receiver drops a peer's
  message older than the last one it applied, and a claim that arrives after
  it would have lapsed. Older clients skip the unknown variant.

The two-minute timer and the 45-second heartbeat are constants on
`AgentWakeCoordinator`; the model requires the timer to exceed a heartbeat
plus a delivery delay, which leaves 75 seconds for delivery.

## Consequences

- Two devices over the same task state run the agent once; the other
  cancels when the completion arrives.
- TLC found a hole in the first draft: a peer's completion was overwritten
  by its next claim, so a device still at the older state ran it again. The
  completed digests are therefore a separate history.
- **Claims that cross** — two devices dispatching within one delivery delay
  of each other — both run. Excluding them needs a settle before every run,
  which is the latency this design exists to avoid.
- **A long disconnect** makes coordination fall back to today's behaviour: a
  claim delivered more than two minutes late is ignored.
- **The first wake on an untitled task** sets its title directly, which
  changes the digest, so a peer runs once more.
- Coordination state is in memory. A restart forgets the peers' claims,
  which again can only cost a duplicate.
