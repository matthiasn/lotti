# ADR 0152: A Reflection Names the Check-ins It Answers

- Status: Accepted
- Date: 2026-10-31
- Builds on: [ADR 0143](./0143-a-goal-agent-answers-what-the-user-said.md)
  (a goal agent answers what the user said)

## Context

ADR 0143 held a goal report to the check-ins its wake marked
`sinceLastReport`: on such a wake the strategy refused a report whose
`reflection` was empty. Two gaps remained.

- **Non-empty is not answered.** "Keep going, you are doing well" passes. The
  rule could tell that the model wrote something, not that it engaged with
  any check-in, so the failure ADR 0143 named — the agent counting the
  user's words and answering none of them — survived as long as the slot
  held a sentence.
- **Shown is not answered.** A report recorded every check-in its wake showed
  as reflected. A new check-in the reflection never mentioned stopped being
  new the moment one report was written, so nothing ever held a later report
  to it.

The user could not check either: the card said "From your check-ins" without
saying which.

## Decision

1. **The report names what it answers.** `update_goal_report` gains
   `report.reflectedCheckIns`, the `sourceEntryId`s of the `userVoice`
   entries the reflection answers. It is optional and not a section: an
   absent or malformed list parses as none, and no heading renders for it.
2. **A wake with new check-ins requires one named.** On an automatic wake
   with check-ins marked `sinceLastReport`, the strategy refuses a report
   whose reflection is empty, or whose `reflectedCheckIns` names none of
   those check-ins. The rejection lists the ids it may name.
3. **Only what was answered stops being new.** The report records under
   `goal_report_check_ins_reflected` every shown check-in except the new
   ones its reflection left out (`GoalCheckInReflection.recordedFor`). An
   unanswered check-in stays marked for the next report until it is answered
   or falls out of the verbatim tail.
4. **The card says which.** The report also records, under
   `goal_report_check_ins_answered`, when each named check-in that the wake
   actually showed was recorded. The card names those days under "From your
   check-ins". An id the wake did not show names nothing, so a model cannot
   make the card claim words it never read.

## Consequences

- Naming an id proves the model pointed at a check-in, not that the prose
  answers it well. That remains the evaluations' job; the rule closes the
  cheap failure, and the rejection tells the model the reflection must
  actually answer what it names.
- A wake whose reflection names only some new check-ins leaves the rest
  marked, so the next automatic wake reports again and must name another.
  Each report shrinks the set, so this ends; it costs at most one extra
  report per unanswered check-in still in the tail.
- A chat turn is still not held to reflecting, but it records the same way:
  a check-in a chat-turn report did not name stays new for the next
  automatic wake.
- The tool schema changed. Live goal-agent evaluations have not been re-run
  against it.

## Related

- [ADR 0057](./0057-decade-scale-agent-memory.md)
- [ADR 0143](./0143-a-goal-agent-answers-what-the-user-said.md)
