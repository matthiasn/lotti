# ADR 0143: A Goal Agent Answers What the User Said

- Status: Accepted
- Date: 2026-10-29
- Builds on: [ADR 0057](./0057-decade-scale-agent-memory.md) (check-in
  compaction), [ADR 0140](./0140-a-goal-is-constituted-by-its-charter-entries.md)
  (the charter), [ADR 0141](./0141-a-goal-agent-keeps-a-fact-only-from-the-users-own-turn.md)
  (remembered facts)

## Context

By ADR 0141 a goal wake carried everything the user had said about a goal:
the charter, the confirmed facts, and the compacted check-ins as `userVoice`.
Its output did not use them. A journaling goal — one measured by the time
spent checking in — reported whether the user had checked in and nothing
about what they wrote. Four things in the contract made that the expected
outcome rather than a model failure:

- The system prompt and every slot of `update_goal_report` were about
  measured evidence. The report schema called its prose slots "facts only";
  the user's words were invited only into `nextActions.later` on the day's
  briefing.
- The check-in compactor kept "only what matters to THIS goal" in "one or two
  sentences". Against a goal like "journal ten minutes a day" that is the fact
  that an entry happened. The span digests led with "what happened to the
  numbers".
- `materialChangeSinceLastReport` was the status transition or the briefing,
  and the prompt's last rule said to write nothing otherwise.
- A recording's minutes changed the register; its transcript, landing
  afterwards, changed no number, so nothing woke the agent until the next
  morning. Every wake Phase A armed was also told the *user* had requested a
  refresh, and a forced retry that a habit-day edit had prompted it.

## Decision

1. **The report has a reflection.** `update_goal_report` gains a
   `reflection` slot, the one prose slot that is not a restatement of FACTS:
   two to four sentences engaging with `userVoice`, the charter and
   `knowledge`. The system prompt says what the user's words are for. The
   goal page shows the reflection with the summary, above what comes next,
   not behind "Show more".
2. **A report records what it was shown; the next wake asks what is new.** A
   report persists, for each check-in its wake showed verbatim, the entry id
   and the digest of its words (`goal_report_check_ins_reflected`). A later
   automatic wake compares its own verbatim check-ins against that record,
   marks the new ones `sinceLastReport`, counts them in `reporting`, and
   treats any count above zero as a material change. Comparison is by entry
   and digest, not by time: a transcript recorded before the report but read
   after it is new, and so is a re-transcription — and two check-ins saying
   the same thing word for word are two. On such a wake the strategy refuses a report whose
   reflection is empty.
3. **A goal measured by its check-ins compacts them for substance.**
   `GoalCheckInWeight` is `substance` for a goal with a `checkInTime` leaf
   and `context` otherwise. A substance summary keeps up to five sentences of
   themes, insights, decisions and questions; a substance digest keeps
   themes, their movement and commitments instead of numbers. The weight is
   part of the summary's fingerprint, so such a goal re-reads its check-ins
   once — newest first, at most eight a wake — while `context` keeps the
   fingerprint every summary was stored with.
4. **A write to the goal's own journal row refreshes such a goal's report.**
   Phase A already ran for it; it now queues the coalesced refresh even when
   no number moved, so the words reach a report minutes after they land, not
   the next morning.
5. **A wake says why it reports.** The refresh cause is read from the wake —
   no escalation period means the user asked, one means Phase A armed it —
   and the appended text and the forced retry name that cause.

## Consequences

- A journaling goal's report talks about what the user wrote. A goal
  measured by anything else reflects check-ins when they arrive and may leave
  the reflection empty when nothing new was said.
- A check-in on a journaling goal now costs a Phase B inference minutes
  later, coalesced behind the existing countdown. ADR 0057's "a check-in
  marks the report stale, never a wake" holds only for other goals.
- Longer summaries leave fewer check-ins in the 1,200-token verbatim tail.
  Sizing that tail by goal kind is a measured follow-up through the
  compaction evaluation, not part of this decision.
- The reflection is the one model-authored slot that may quote the user. It
  passes the same sanitizer and status-token rule as every other slot.
- Live goal-agent evaluations have not been re-run against this contract.

## Related

- [ADR 0055](./0055-banner-nudge-attention-channel.md)
- [ADR 0057](./0057-decade-scale-agent-memory.md)
- [ADR 0140](./0140-a-goal-is-constituted-by-its-charter-entries.md)
- [ADR 0141](./0141-a-goal-agent-keeps-a-fact-only-from-the-users-own-turn.md)
