# ADR 0032: Hybrid Understanding Evaluation

- Status: Proposed
- Date: 2026-07-21 (replaces the 2026-07-18 draft)

## Context

Rules can validate structure — identifiers, answer keys, score ranges — but
cannot judge whether free-form prose shows understanding. An LLM can, and the
user explicitly accepts LLM-issued grades for this feature. The 2026-07-18
draft additionally required an independent blueprint-admission audit,
adjudication lattices for disagreeing reviewers, and fail-closed calibration
corpora rated by independent humans before any assessment could exist. For a
personal learning aid that gating made the feature unshippable; it is removed.
The full draft is preserved in git history.

What remains worth defending: questions and grades must be grounded in a fixed
snapshot of the task's content (so the target cannot move and citations can be
checked), model calls must be tool-less and treat all content as untrusted
data, invalid model output must never be presented as a result, and a
one-shot question/answer exchange is often too blunt — the grader should be
able to ask follow-ups before judging, the way a person would.

## Decision

1. **Freeze evidence before generating.** Starting a quiz captures an immutable
   evidence snapshot of the task: title, description/notes, checklist items,
   linked entry text, audio transcripts, and agent reports/summaries when
   present. The snapshot is a bounded bundle of sections with stable IDs and
   digests; truncation and missing sources are recorded, never papered over.
   Generation and grading read only the snapshot, so later task edits cannot
   shift the target mid-quiz.
2. **One tool-less generation call produces the quiz.** The generator receives
   the snapshot as delimited untrusted data and returns a schema-constrained
   quiz definition tailored to the content: an inferred content kind (reading
   notes, coding work, decision log, meeting notes, …), question count scaled
   to content richness and the user's chosen depth, and a mix of item types —
   multiple-choice items (options, exactly one keyed answer, an explanation,
   section citations) and open items (prompt, expected answer points, section
   citations) rotating across explain/predict/apply/debug/compare operations
   where the content supports them.
3. **Deterministic validation gates the quiz, not a second model.** Code checks
   the schema, that every citation resolves to a snapshot section, that each
   multiple-choice key is one of its own options with no duplicate options,
   and that item counts are within bounds. One repair call with the validation
   errors is allowed; if that fails, no quiz is shown and the user gets a
   retry affordance. There is no separate admission-audit model call and no
   adjudication protocol; a bad question is handled by the user skipping or
   regenerating it, and by the feedback affordance in ADR 0034.
4. **Grading is conversational.** Multiple-choice answers are scored
   deterministically against the frozen key. Each open answer goes to a
   tool-less grader call carrying the snapshot, the frozen item, and the full
   item thread so far. The grader returns either a follow-up probe question —
   when the answer is ambiguous, incomplete, or worth pushing deeper — or a
   final item verdict with what was missed. Probes are bounded (default at
   most two per item); at the bound the grader must issue a verdict with what
   it has. The grader may also ask one optional "why did you choose that?"
   probe after a multiple-choice answer when the item is marked as worth
   probing. The user can end probing at any time ("just tell me"), which
   forces a verdict plus the explanation.
5. **The LLM's grade is the grade.** The grader's verdicts and scores are
   accepted as issued, subject only to schema validation and range checks;
   deterministic code computes the session aggregate per ADR 0034. There is no
   calibration corpus, no cleared-slice requirement, and no reliability
   calculus. In exchange, every grade is presented as AI feedback on this
   quiz — see ADR 0034's honesty rules. Optional future calibration (sampling
   sessions for human review, tracking user "this grade seems wrong" reports)
   can be added without changing this contract.
6. **Prompt-injection resistance stays.** Every model call is tool-less, with
   no network, shell, or write capability. Snapshot content, user answers, and
   transcripts are delimited and labeled as untrusted data; instructions found
   inside them are ignored. Outputs are schema-constrained and citation-checked.
   Persisted results contain concise rationales only — no hidden
   chain-of-thought.
7. **Audio answers are first-class.** A spoken answer is recorded and
   transcribed with the existing transcription pipeline; the transcript is
   shown and editable before submission, the submitted transcript is the
   answer of record, and the input modality is stored with the attempt.
8. **Reveals are honest, not punished.** The user may reveal an answer or
   explanation at any time. An item revealed before answering is excluded from
   the session score and marked as revealed, but still gets its explanation.
   There is no carryover-window taxonomy across sessions.
9. **Failures preserve the user's work.** Generation failure produces no quiz
   and a retry option. A grading failure or provider outage preserves the
   submitted answer and offers retry; answers are never lost or silently
   regraded. Invalid model output after repair is a failure event, never a
   displayed result.

## Consequences

- The cost of a quiz is one generation call plus roughly one grading call per
  open item (probe rounds continue the same conversation), instead of the
  earlier draft's generation + admission + evaluation + audit pipeline.
- Grades are uncalibrated model judgment. Occasional unfair grades and flawed
  questions will happen; the mitigations are probing before judgment,
  skip/regenerate controls, the reveal path, and honest AI-feedback labeling —
  not a review bureaucracy.
- Because grading is conversational, an item's record is a thread (answer,
  probes, final verdict), which ADR 0033 persists as ordered events rather
  than a single attempt row.
- The injection surface is narrow and testable: adversarial snapshot fixtures
  (instructions embedded in task text) belong in the standard test suite.

## Related

- [Implementation plan](../implementation_plans/2026-07-18_learning_understanding_verification_agent.md)
- [ADR 0031: Learning Verification Checkpoint Policy](./0031-learning-verification-checkpoint-policy.md)
- [ADR 0033: Learning Verification Session Persistence](./0033-learning-verification-session-persistence.md)
- [ADR 0034: Learning Understanding Rating](./0034-learning-understanding-rating.md)
