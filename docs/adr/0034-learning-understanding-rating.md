# ADR 0034: Learning Understanding Rating

- Status: Proposed
- Date: 2026-07-21 (replaces the 2026-07-18 draft)

## Context

A grade should tell the learner two things: roughly how well this quiz went,
and — much more importantly — exactly what they missed. The 2026-07-18 draft
guarded against overclaiming with a five-dimension rubric lattice, rating
availability states, calibration-gated aggregates, and independent
promotion/schedule decisions. The user has explicitly accepted a simpler
contract: the LLM grades directly, probes with follow-ups before judging, and
explains the gaps. The full draft is preserved in git history.

What must survive the simplification: grades are session-scoped feedback and
never become credentials, comparisons, or gates; skipped and revealed items
must not silently distort scores; and machine grades stay separate from
Lotti's subjective journal ratings (`RatingEntry`), whose semantics are
different.

## Decision

1. **Per-item results.** A multiple-choice item is `correct` or `incorrect` by
   deterministic key comparison. An open item receives a grader verdict of
   `correct`, `partial`, or `missed` plus an item score 0–100, issued after
   any probe rounds conclude (ADR 0032). Every non-correct item gets a
   "what you missed" explanation citing the evidence sections it comes from;
   correct items may get a brief confirmation of what was right. `skipped` and
   `revealed` items are recorded as such, still receive explanations, and are
   excluded from score arithmetic.
2. **Session grade in code.** Deterministic code computes the session score as
   the weighted mean of answered items — multiple-choice weight 1, open-item
   weight 2 — and maps it to a label: **Solid grasp** (≥ 85), **Getting
   there** (60–84), **Needs review** (< 60). Weights and bands are versioned
   hypotheses stored with the assessment, not invariants. A session where
   everything was skipped or revealed has no score, only explanations.
3. **Grading guidance lives in the prompt, not the schema.** The grader is
   instructed to judge correctness, causal mechanism, completeness, and
   boundaries; to assess content rather than grammar, accent, brevity, or
   jargon; to allow stated uncertainty without penalty; and to probe rather
   than guess when an answer is ambiguous. These are quality guidelines for
   one call, not persisted per-dimension ratings.
4. **Feedback-first presentation.** The session result leads with what went
   well and the gap list ("here's what you missed"), then the per-item
   review, then the score and label. Every grade is visibly AI-issued and
   session-scoped — "in this quiz", never "you are X% competent". Users can
   hide numeric scores via a synced preference. A "this grade seems wrong"
   affordance records the disagreement with the session for later review; it
   does not silently regrade.
5. **No comparison, no gating, no streaks.** Grades are never compared across
   users, never surface as leaderboards or streak pressure, never gate any
   workflow, and are not trended across quizzes as if equated — different
   quizzes measure different content.
6. **Separate storage, plain lifecycle.** Machine grades live in the learning
   entities from ADR 0033, never in journal `RatingEntry`. Per-task and
   per-category quiz history is private, exportable, and deletable. Neither
   the generator nor the grader may emit review dates or reminders; "quiz me
   again" and user-created reminders remain user actions.

## Consequences

- Learners get a legible outcome (score, label, gap list) with the depth
  provided by probing, at the cost of psychometric rigor — scores are
  uncalibrated LLM judgment and are labeled as such.
- Dropping per-dimension persisted ratings removes the most detailed feedback
  structure the earlier draft had; the gap explanations carry that weight
  instead.
- Simple exclusion rules (skipped/revealed) keep scores meaningful without an
  assistance-classification taxonomy.
- If scheduled review returns later, schedule policy must be rebuilt on top of
  these session facts; nothing in this contract presumes it.

## Related

- [Implementation plan](../implementation_plans/2026-07-18_learning_understanding_verification_agent.md)
- [ADR 0031: Learning Verification Checkpoint Policy](./0031-learning-verification-checkpoint-policy.md)
- [ADR 0032: Hybrid Understanding Evaluation](./0032-hybrid-understanding-evaluation.md)
- [ADR 0033: Learning Verification Session Persistence](./0033-learning-verification-session-persistence.md)
- [Flexible rating system plan](../implementation_plans/2026-02-09_flexible_rating_system.md)
