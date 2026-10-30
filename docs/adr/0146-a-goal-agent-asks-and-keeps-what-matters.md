# ADR 0146: A Goal Agent Asks, and Keeps What Matters

- Status: Accepted
- Date: 2026-10-30
- Amended by: [ADR 0147](./0147-a-question-banner-names-its-subject-behind-the-private-switch.md)
  (decision 2: the banner's words)
- Builds on: [ADR 0055](./0055-banner-nudge-attention-channel.md) (banners),
  [ADR 0056](./0056-need-to-know-visual-brief-boundary.md) (leakage),
  [ADR 0057](./0057-decade-scale-agent-memory.md) (memory),
  [ADR 0143](./0143-a-goal-agent-answers-what-the-user-said.md) (reflection)

## Context

By ADR 0143 a goal report engages with what the user wrote. The agent still
could not start a conversation: it could only answer one, and its banners
were driven by status alone — a goal on track never raised one, however much
a check-in left open. A journal entry ending "should we wait until after the
physio?" was reflected in a report the user might not open.

Two memory gaps sat under that. A wake read the twelve newest observations,
so an injury or a doctor's advice noted months ago fell out of view once a
dozen routine notes had been written since. And what the user said in the
goal chat reached the agent only as the last few turns of dialogue and
through `search_goal_memory`; it was never compacted into the summaries and
span digests that carry a goal's history forward.

## Decision

1. **`ask_goal_question` lets an automatic wake ask one question.** It is
   offered only when it can be legitimately used: not on a chat turn, only
   when `userVoice` holds check-ins the report has not answered, not while
   the agent's previous question is still unanswered, and not twice in a day.
   The question lands in the goal chat as an agent message marked
   `goal-question:<runKey>`, so reply pairing never mistakes it for an answer
   to a user turn.
2. **A question may raise a banner, and the app writes its words.** The
   banner is seen outside the goal (ADR 0056), so its headline and call to
   action are fixed, localised copy saying a question is waiting; the model
   chooses only its tone (never roast), animation and accent. Told to stay
   generic, glm-5.2 still headed one "A question about your Saturday plan" —
   a rule the model can break is not a boundary.
   Tapping it opens the chat (ADR 0055 D6). Its lifetime is its own: the
   status sweep and the freshness rule that govern ad banners do not retire
   it, a chat turn does, and the dismissal cooldown suppresses the banner but
   not the question.
3. **The agent marks an observation critical.** `record_goal_observation`
   takes `priority: routine | critical`. FACTS carry the newest twelve
   observations and, within a 400-token budget, every critical one in the
   newest 200 — still a bounded read (ADR 0057).
4. **Substantive chat turns are compacted like check-ins.** A user turn of
   twelve words or more becomes a compaction source keyed by its message id,
   enters the summaries and span digests, and appears in `userVoice` marked
   `via: chat`. It never counts as new since the last report: the agent
   already answered it in the chat, so it neither demands a reflection nor
   unlocks a question.

## Consequences

- A goal on track can reach the user when something they wrote deserves a
  follow-up, at most once a day and never stacked.
- Live evaluation (P22): every question followed up the open decision. A
  wake that offered the tool with nothing new to ask about asked anyway until
  the tool description said so outright; production never offers it there.
- A question's banner is not an ad: it never counts as the fresh status
  banner an off-track goal requires, and is never offered for retire or
  rerun. Only its dismissal speaks for the goal's quiet window.
- A goal's history now includes the conversation, at the cost of compacting
  long chat turns on the next automatic wake.

## Related

- [ADR 0055](./0055-banner-nudge-attention-channel.md)
- [ADR 0056](./0056-need-to-know-visual-brief-boundary.md)
- [ADR 0057](./0057-decade-scale-agent-memory.md)
- [ADR 0143](./0143-a-goal-agent-answers-what-the-user-said.md)
