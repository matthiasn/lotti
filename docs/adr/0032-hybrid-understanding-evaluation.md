# ADR 0032: Hybrid Understanding Evaluation

- Status: Proposed
- Date: 2026-07-21

## Context

Rules can validate structure but cannot judge free-form prose; an LLM can,
and quiz grades are accepted as clearly-labeled AI feedback rather than
calibrated measurements. What still needs defending: questions and grades
must stay grounded in a fixed snapshot of the task's content, model calls
must be tool-less and treat all content as untrusted data, invalid model
output must never render as a result, and a one-shot question/answer
exchange is often too blunt — the grader should probe before judging, the
way a tutor would.

## Decision

1. **Freeze evidence first.** Starting a quiz captures an immutable snapshot
   of the task's content as sections with stable IDs and digests; truncation
   and missing sources are recorded. Generation and grading read only the
   snapshot.
2. **One tool-less generation call** returns a schema-constrained quiz
   tailored to the content: question count scaled to depth and richness,
   multiple-choice items (options, exactly one keyed answer, explanation,
   citations) and open items across explain/predict/apply/debug/compare.
3. **Deterministic validation gates the quiz**, not a second model: schema,
   citation resolution, key membership, option uniqueness, count bounds. One
   repair call is allowed; then a typed failure event with retry UI.
4. **Grading is conversational.** Multiple choice is scored against the
   frozen key in code. Each open answer goes to a tool-less grader call with
   the snapshot, frozen item, and item thread; it returns either a follow-up
   probe (at most two per item) or a verdict with what was missed. The user
   can end probing ("just tell me"), skip, or reveal; revealed-before-answer
   items are excluded from scores but still explained.
5. **The LLM's grade is the grade**, subject only to schema and range checks;
   there is no calibration corpus or cleared-slice gate. Deterministic code
   computes the session aggregate per ADR 0034.
6. **Injection resistance stays**: no tools, network, or write capability;
   snapshot text, answers, and transcripts are delimited untrusted data;
   outputs are schema-constrained and citation-checked; no chain-of-thought
   is requested or persisted.
7. **Voice answers** use the existing transcription pipeline; the editable
   transcript is the answer of record, with modality stored on the attempt.
8. **Failures preserve answers.** Answers are durably appended before any
   grading call; generation or grading failure produces a typed event and a
   retry affordance, never a lost answer or a fabricated result.

## Consequences

- A quiz costs one generation call plus roughly one grading conversation per
  open item.
- Grades are uncalibrated model judgment; the mitigations are probing before
  verdicts, skip/regenerate/reveal controls, and honest labeling.
- An item's record is a small event thread (answer, probes, verdict) rather
  than a single row.

## Related

- [Implementation plan](../implementation_plans/2026-07-18_learning_understanding_verification_agent.md)
- [ADR 0031: Learning Verification Checkpoint Policy](./0031-learning-verification-checkpoint-policy.md)
- [ADR 0033: Learning Verification Session Persistence](./0033-learning-verification-session-persistence.md)
- [ADR 0034: Learning Understanding Rating](./0034-learning-understanding-rating.md)
