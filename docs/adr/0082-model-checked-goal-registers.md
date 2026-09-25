# ADR 0082: Phase A Takes Turns, Builds on What It Read, and Escalates With Its Register

- Status: Accepted
- Date: 2026-09-25

## Context

ADR 0054 made goal Phase A deterministic and idempotent: every device
recomputes the day's `goalProgress` row from its own journal and writes it
wholesale, so replicas converge instead of coordinating. A recompute carries
the clock of the row it builds on, so it dominates that row. A transition
against the last persisted status makes the LLM tier worth waking. A later
change parked that escalation behind a device-local 120-second countdown.

`specs/tla/GoalRegister.tla` models one goal-day across devices: evidence
written anywhere and synced in any order, Phase A running from two lanes (the
wake orchestrator for local writes, the sync dispatcher for synced ones),
register rows resolved by clock and then by timestamp, the lease-elected
Phase B report, crashes, and devices that never return. With the code as it
was, TLC found the standing report contradicting the day's status with no
fault at all, and four holes behind it:

1. **Interleaved lanes buried evidence.** A local run read the journal, the
   dispatcher's run committed a synced check-off, and the local run then
   committed its older snapshot on top. Carrying the clock made the stale row
   dominate on every device, and nothing re-triggered.
2. **A stale report was never corrected.** The lease can elect a device whose
   journal is still behind. Its report states the old status while every
   register already carries the new one, so no device ever sees a transition.
3. **A crash lost synced evidence.** The dispatcher's queue lives in memory.
   A row applied just before the process died was evaluated by nobody that day.
4. **A dying device took its escalation along.** The countdown was
   device-local. Its peers held the synced register with the new status, and
   saw no transition.

## Decision

1. **Runs of one goal take turns on a device.**
   `GoalAgentPhaseA.runExclusive` serializes the orchestrator, the sync
   dispatcher and Phase B's report refresh per goal.
2. **A commit builds only on the row and the report its derivation read.**
   When the day's row, or today's report, has changed since the derivation,
   `persistDerivation` returns `GoalPersistOutcome.stale` and the run derives
   again, up to `goalPersistAttempts` times. This covers a peer's row that
   syncs in mid-run, which the lock cannot see. A Phase B report refresh that
   exhausts its attempts ends without inference.
3. **A report for today that states another status escalates.**
   `GoalWakeFacts.needsEscalation` is now `statusTransitioned ||
   reportContradicted`. Only a report written today under the same spec
   counts, so a Phase B that failed to write one is not retried on every tick.
4. **Startup recomputes every active goal.**
   `GoalRuntimeMaintenance` runs Phase A directly. It does not go through
   the wake orchestrator, because a manual wake clears the throttle and the
   pending refresh deadline being restored beside it.
5. **An escalation commits with its register.** A status the report does not
   state, or an eligible banner expiry, arms the synced escalation in the
   register's transaction. The deadline stays period-derived, so the lease's
   identical-record guarantee (ADR 0069) holds. Evidence that leaves the
   status alone still coalesces behind the countdown.
6. **An unchanged run writes nothing.** A register row this run would
   reproduce is left alone. So is a cadence record already pending for that
   tick.

**Rejected: recomputing when a peer's register row or report syncs in.** It
would heal a stale row a lagging device left behind. But views legitimately
diverge: a private entry that one device hides, or a time zone that puts an
entry on another day. Under divergence each device answers the other's row
forever (`OnSynced = "recompute"` breaks `Bounded`), and every escalating
round is a paid Phase B run. Damped variants bound the loop but still cannot
heal the case that matters. In that case the harmful write is the lagging
device's *own* recompute, from a journal still missing evidence.

## Consequences

- A status change now wakes Phase B as soon as the lease settles, instead of
  after the 120-second countdown. Skip once skips only the countdown for
  evidence-only changes. With automatic updates off, nothing is armed.
- Devices whose views of the journal disagree can escalate once per organic
  event each, where they used to escalate only on a transition. The cost is
  bounded by events, not by the disagreement (`GoalRegisterDivergent`).
- **Residual:** a device that recomputes, or runs Phase B, from a journal
  still missing evidence and then never comes back leaves a row or a report
  that no peer can tell is stale. A device that returns heals it. Its startup
  recompute and the evidence that syncs in fix the row, and a contradicted
  report re-escalates. Healing it without the device would need evidence
  ordering in the register.

## Verification

Four TLC configurations check the code as it is now, with 3,642,165 distinct
states in total. `GoalRegisterDeath` claims only `EscalationDurable`.
Reverting each decision breaks a property in 6 to 17 steps. The Dart
regressions in `goal_agent_phase_a_test.dart`,
`goal_runtime_maintenance_test.dart` and `goal_agent_providers_test.dart`
each fail with their decision reverted. `specs/tla/README.md` has the traces.
