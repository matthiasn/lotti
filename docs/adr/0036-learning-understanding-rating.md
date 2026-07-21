# ADR 0036: Learning Understanding Rating

- Status: Proposed
- Date: 2026-07-21

## Context

A grade should tell the learner two things: roughly how the quiz went, and —
more importantly — exactly what they missed. Grades are direct LLM judgment
presented as formative AI feedback about one session. Honesty rules keep
them from reading as credentials, and machine grades stay separate from
Lotti's subjective journal ratings (`RatingEntry`), whose semantics differ.

## Decision

1. **Per-item results.** Multiple choice is `correct` or `incorrect` by key
   comparison. Open items get a grader verdict of `correct`, `partial`, or
   `missed` plus a 0–100 item score, issued after probe rounds conclude.
   Every non-correct item gets a "what you missed" explanation citing the
   evidence sections it comes from. `skipped` and `revealed` items are
   excluded from score arithmetic but still explained.
2. **Session grade in code.** Weighted mean of answered items
   (multiple-choice weight 1, open weight 2), labeled **Solid grasp**
   (≥ 85), **Getting there** (60–84), **Needs review** (< 60). Weights and
   bands are versioned hypotheses stored with the assessment. A session with
   nothing answered gets explanations, no score.
3. **Grading guidance lives in the prompt, not the schema**: judge
   correctness, mechanism, completeness, and boundaries; assess content
   rather than grammar, accent, brevity, or jargon; allow stated uncertainty
   without penalty; probe rather than guess.
4. **Feedback-first presentation.** Strengths, then the gap list, then the
   per-item review, then score and label. Grades are visibly AI-issued and
   session-scoped ("in this quiz"); numeric scores can be hidden by
   preference. **This grade seems wrong** records the disagreement; nothing
   is silently regraded.
5. **No comparison, no gating, no streaks.** Never compared across users,
   never a leaderboard, never gates a workflow, never trended across quizzes
   as if equated.
6. **Separate storage, plain lifecycle.** Grades live in the learning
   entities (ADR 0035), never in `RatingEntry`; history is private,
   exportable, and deletable. Neither generator nor grader may emit review
   dates; re-quizzing and reminders are user actions.

## Consequences

- Learners get a legible outcome (score, label, gap list) with tutor-style
  depth from probing, at the cost of psychometric rigor; results are
  disclosed as AI judgment.
- Gap explanations carry the detailed-feedback weight instead of a
  persisted rubric lattice.
- If scheduled review is ever added, it must be built on these session
  facts; nothing here presumes it.

## Related

- [Implementation plan](../implementation_plans/2026-07-18_learning_understanding_verification_agent.md)
- [ADR 0033: Learning Verification Checkpoint Policy](./0033-learning-verification-checkpoint-policy.md)
- [ADR 0034: Hybrid Understanding Evaluation](./0034-hybrid-understanding-evaluation.md)
- [ADR 0035: Learning Verification Session Persistence](./0035-learning-verification-session-persistence.md)
- [Flexible rating system plan](../implementation_plans/2026-02-09_flexible_rating_system.md)
