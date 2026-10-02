# ADR 0113: Project Agents Update in Synced Slots

- Status: Accepted
- Date: 2026-10-03

## Context

ADR 0112 bounded every project-agent wake with a daily budget, which caps the
damage but does not decide *when* work is worth doing. The trigger side was
still the one that ran away:

- **Every change asked for work.** Linked-task activity armed a device-local
  06:00 `scheduledWakeAt`; a direct project edit queued a throttled
  subscription wake; a failed run re-armed the 06:00 fallback; a restart,
  resume, opt-in and every sync arrival of the identity, state or link
  repaired a "missing" fallback. Each path had its own guards.
- **Every device did it.** Deadlines were device-local by design (they must
  not overwrite a peer's), so a change synced to three devices armed three
  fallbacks and, at 06:00, could run three inferences for one report.
- **Staleness and work were the same thing.** The only way the system could
  say "this report is behind" was to schedule the run that would fix it.

The project report is useful context for the task agents of the project, so
it should not drift far behind — but an hour of staleness costs nothing,
while a wake per edit per device costs a model call each.

## Decision

1. **A change marks the report stale; it never schedules work.** Staleness is
   the agent state's two synced watermarks, `reportStaleAt` and
   `reportFreshAt`, each joined by maximum; the report is stale while
   `reportStaleAt >= reportFreshAt`. The activity monitor, the project-agent
   subscriptions (`reportStaleOnly`) and creation only move `reportStaleAt`.

2. **A stale report is refreshed in its agent's next update slot.** Slots cut
   the day at the agent's update interval, anchored at 06:00 local time
   (hourly by default; 1, 2, 4, 8 hours or daily, chosen in agent internals
   and synced on the identity as `updateIntervalMinutes`). A slot is a synced
   `ScheduledWakeEntity` whose id is derived from the agent and the slot's
   start, so every device that arms "the next slot" arms the same row. At
   most one slot is pending per agent; arming is inert and idempotent, so
   every path that may have noticed staleness calls it
   (`ProjectUpdateCadence.arm`).

3. **One device fires a slot.** The scheduled-wake manager leases it like the
   coordinator digest (ADR 0069), with three rules that TLC showed necessary:
   claim and fire only while connected with the sync inbox drained
   (`SyncLeaseGate`); re-claim rather than confirm a claim made before a
   connection loss; fire only an agent's earliest pending slot and consume
   all of them.

4. **Automatic project work runs only in slots.** The drain refuses an
   automatic project wake that does not carry the slot's trigger token
   (`notAnUpdateSlot`), whatever queued it. "Update now" and creation are
   explicit and run at once; the daily budget still bounds both.

5. **A slot over a fresh report runs nothing.** If "Update now" or a peer got
   there first, the drain refuses the slot's wake before the budget is
   claimed, so it costs nothing. A run stamps the report fresh as of its
   start; a change during the run, or a failure, leaves it stale and arms the
   next slot. A slot whose wake the drain refuses is re-armed — for the next
   budget day when the budget refused it — since the manager consumed it
   before the drain decided.

6. **The user sees the state, not the machinery.** The project card reads
   "Out of date" with "Update now · 34:59" counting down to the next slot;
   the projects list marks rows whose summary is out of date and can filter
   to them; agent internals show the countdown, the daily limit and the
   update frequency.

7. **Device-local project deadlines are retired.** A `scheduledWakeAt` or
   `nextWakeAt` an older build left on a project state is cleared — locally,
   keeping the synced timestamp and vector clock — at startup, by the
   manager's due scan (never fired), and on sync arrival.

The design is model-checked in `specs/tla/ProjectWakeGovernor.tla`:
`NoDuplicateScheduledWake` (one run per slot while connected),
`NoDuplicateUnlessWriteDropped` (with partitions: only a device that fired
and lost its connection before its consume left can cause a second run),
`WakeBudgetRespected`, `SharedBudget` (connected devices share one budget for
automatic work), `StaleDoesNotTriggerWork` (every run is a leased slot or a
user's request), `NoWorkWhenFresh`, `PausedRunsNothing` and the liveness
property `NoLostUpdate`. Each rule above has a switch in the spec, and turning
it off produces a counterexample for the property it protects.

## Consequences

- **The bound is structural.** Automatic work for a project agent is at most
  one run per slot across all devices — 24 a day at the hourly default,
  before the budget — instead of one per change per device. With a daily
  interval it is one run a day.
- **A report can be up to one interval behind** without the user acting.
  The card says so, with the countdown, and "Update now" is one tap.
- **Offline devices do not fire.** A device that is not connected, or whose
  inbox has not drained within two minutes, leaves the slot pending; with
  sync disabled the gate is always open, since there are no peers to race.
- **Skip is gone for project agents.** Consuming a slot only to have the next
  change arm another skips nothing; turning automatic updates off is the
  way to stop them.
- **A stale report with automation off stays stale** and shows it; no slot is
  armed until automation is turned back on.
- Explicit runs are not deduplicated across devices: two devices pressing
  "Update now" at once both run, and both count.

## Related

- ADR 0069 — model-checked scheduled-wake leases (the lease this reuses)
- ADR 0112 — the daily wake budget
- `specs/tla/ProjectWakeGovernor.tla`
- `lib/features/agents/service/project_update_cadence.dart`,
  `lib/features/agents/wake/project_update_slots.dart`,
  `lib/features/agents/wake/sync_lease_gate.dart`
