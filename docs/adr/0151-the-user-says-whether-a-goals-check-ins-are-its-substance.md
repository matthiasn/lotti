# ADR 0151: The User Says Whether a Goal's Check-ins Are Its Substance

- Status: Accepted
- Date: 2026-10-31
- Builds on: [ADR 0143](./0143-a-goal-agent-answers-what-the-user-said.md)
  (a goal agent answers what the user said)

## Context

ADR 0143 made a goal's check-ins its substance — summaries that keep themes
rather than the fact of an entry, a report refreshed minutes after a
transcript lands — exactly when a criterion measures check-in time. That
reads the user's intent off the measurement, and the two come apart:

- A journal is often tracked as a habit: one tick a day for "wrote in my
  journal". Its criteria count ticks, so it got `context` compaction — one or
  two sentences keeping "only what matters to THIS goal", which for such a
  goal is that an entry happened — and its report waited for the next
  scheduled wake. The agent went on noting that the user had checked in and
  saying nothing about what they wrote: the failure ADR 0143 set out to fix,
  intact for every journal not measured in minutes.
- A goal can count minutes of reflection without its words being the goal —
  a practice whose value is the time, not the content.

Nothing in a goal's spec recorded which kind it is, and no rule over the
criteria can recover it.

## Decision

1. **The spec says it.** `GoalSpecVersionEntity` gains
   `checkInsAreSubstance`, a nullable flag. `GoalCheckInWeight.of(spec)` is
   `substance` when it is true, `context` when it is false, and, when it is
   null, what ADR 0143 derived: `substance` exactly when a criterion measures
   check-in time. Every caller that keyed on the criteria — the wake's
   compaction, Phase A's refresh on a write to the goal's row — keys on the
   spec instead.
2. **The goal form asks.** Below the signals sits a switch in the agent's
   voice, "I'll answer what you tell me", showing the value the goal has now. The form stores a value only
   where the user's choice departs from what the criteria imply; a goal
   nobody decided for keeps null and goes on following its criteria.
3. **Only the owner decides.** An owner revision compares the flag like any
   other field and records "check-in weight updated" when only it changed. An
   agent-proposed revision carries the current value over unchanged.
4. **Watching the row and refreshing on it are separate.** The goal's own
   journal row is an immediate trigger when a criterion counts check-in
   minutes *or* the goal is `substance`; only a `substance` goal's Phase A
   queues a report refresh when no number moved. A check-in time goal the
   user says is not a journal still evaluates its minutes the moment they
   land.

## Consequences

- A journal tracked by a habit tick gets ADR 0143's behaviour once the user
  turns the switch on: substance summaries, a reflection required on new
  check-ins, a refresh minutes after a transcript lands. Turning it on costs
  one Phase B inference per check-in, coalesced, as ADR 0143 already does for
  check-in time goals.
- Existing goals keep null and behave exactly as before. A device on an
  older build ignores the unknown field when decoding and compacts such a
  goal as its criteria imply until it updates; the summaries' fingerprints
  carry the weight, so the newer device's next wake re-reads them.
- Changing the flag re-fingerprints the goal's summaries, and the next wakes
  re-read them under the new weight — newest first, at most
  `goalCheckInRecompactionsPerWake` a wake.
- Whether a goal is a journal is now a user statement, not an inference. An
  agent that notices a mismatch can say so in its report or ask; it cannot
  flip the switch.

## Related

- [ADR 0057](./0057-decade-scale-agent-memory.md)
- [ADR 0143](./0143-a-goal-agent-answers-what-the-user-said.md)
