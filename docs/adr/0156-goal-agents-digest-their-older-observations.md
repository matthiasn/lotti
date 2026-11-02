# ADR 0156: Goal Agents Digest Their Older Observations by Month

- Status: Accepted
- Date: 2026-11-02
- Concepts: [goal agents](../../knowledge/features/goals.md#recall),
  [agent memory and compaction](../../knowledge/features/agents/memory-and-compaction.md)
- Amends: [ADR 0146](./0146-a-goal-agent-asks-and-keeps-what-matters.md)
  (critical observations) and implements part of
  [ADR 0057](./0057-decade-scale-agent-memory.md) decision 3 (epoch summaries)
  for goal agents

## Context

A goal agent's observations are its private notes about the person: what
their check-ins and messages show — circumstances, mood, obstacles, what
helps, how the coaching lands. Until now it wrote almost none (its prompt
said only what observations were *not* for); the same change that fixes that
makes the notes pile up, and a journal goal, whose check-ins are its whole
substance, piles them up fastest.

A wake reads the twelve newest notes and the older ones filed `critical`
(ADR 0146). Every other note fell out of view as soon as twelve newer ones
had been written, and out of the store after 180 days — the retention sweep
forgets observations then. The check-ins themselves were already compacted
(ADR 0143: a summary per check-in, digests per month, quarter and year), but
the agent's own reading of them had no long memory at all. The shared
event-log compaction (ADRs 0016/0017) is not a fit: goal agents never capture
their log, and its summarizer is written for tasks.

## Decision

1. **A finished calendar month of observations becomes one digest.** Keyed
   by `(agentId, YYYY-MM)` in the person's local calendar, so two devices
   converge on one row. The month still being written is never digested.
2. **Written with the wake's own model, under a prompt for the goal's
   weight.** `GoalCheckInWeight.substance` — a journal — keeps themes,
   insights, open questions, how thinking and mood moved, what helps them
   reflect; `context` keeps constraints, injuries, medical advice, what
   helps or hinders, patterns and commitments. Minimal reasoning effort, a
   120-word limit, as the check-in digests run.
3. **Only on automatic wakes, and at most two months per wake, newest
   first.** An interactive turn never waits on a digest; a year of notes is
   digested over a few wakes.
4. **Distill, then prune.** A digest records every note id it was written
   from and is rewritten only when a note it has not seen syncs in — folding
   its earlier text into the prompt, so notes pruned since are never lost.
   Notes that disappear never shrink it. Digests are stored as action
   messages (`goal_observation_digest`), which the retention sweep keeps.
5. **A wake reads them beside the verbatim notes.** FACTS gains
   `observationDigests` — month, note count, text — newest month first
   within 600 tokens. A month is shown unless every note of it is already
   listed verbatim; a month whose notes are all pruned still shows its
   digest. Missing digests read as an honest placeholder.
6. **Every goal, not only journals.** The weight changes what a digest
   keeps, not whether it is written; a measured goal's injury noted in March
   matters as much in October.
7. **Never fatal.** A failed read or write logs and costs the wake its
   digests (or that one digest), never the wake.

## Consequences

- One more inference call per finished month with notes, per goal agent,
  spread over automatic wakes and attributed as *Goal observation digest*.
- The goal agent's FACTS grow by up to 600 tokens once it has months of
  notes; the twelve verbatim notes and the critical lane are unchanged.
- A wake reads up to 1,000 observations instead of 200 to group them by
  month; the critical lane still looks only at the newest 200.
- Digests are derived text the model wrote about the model's own notes; they
  can drift from what was noted. The note ids each digest covers keep it
  traceable, and a late note rewrites it.
