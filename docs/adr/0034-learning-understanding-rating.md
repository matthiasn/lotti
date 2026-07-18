# ADR 0034: Learning Understanding Rating

- Status: Proposed
- Date: 2026-07-18

## Context

A single opaque score encourages false precision and gives the learner no path
to improve. Pure prose feedback is harder to track and compare across attempts.
The rating must communicate what the explanation demonstrated without turning a
model judgment into a permanent label, credential, or workflow gate.

Lotti already has a catalog-driven journal rating system for subjective user
ratings. A verifier assessment is evidence-based, model-produced, and carries
citations and evaluator provenance, so reusing `RatingEntry` would blur those
semantics.

## Decision

Use a versioned, multidimensional assessment stored with the verification
session, separate from journal ratings.

1. A pre-response blueprint marks which of five anchored 0–4 dimensions the
   question actually elicits: correctness, causal/mechanistic understanding,
   completeness/relevance, boundaries/trade-offs, and validation/transfer.
   Unelicited dimensions are `notObserved`, not zero.
2. Initial weights (30/25/20/15/10), numeric ranges, and contradiction caps are
   versioned scoring hypotheses. Deterministic code calculates optional 0–100
   detail across observed weights only; the LLM cannot choose the aggregate.
3. Use formative labels: Transfer demonstrated in this check (90–100, only
   after a genuinely novel transfer item with validation/transfer at level 4;
   otherwise cap both displayed score at 89 and label eligibility), Core
   mechanism demonstrated (75–89), Developing explanation (50–74), Core idea
   needs review (0–49). **Not assessed** is a non-scored assessment outcome when
   evidence/evaluator reliability is insufficient, not a formative label.
   `Core mechanism demonstrated` additionally requires observed correctness and
   causal/mechanistic levels of at least 3; other blueprints use
   operation-specific Objective demonstrated/partly demonstrated/needs review
   labels rather than implying an unelicited mechanism.
4. The default result order is evidence scope, assistance condition, assessment
   reliability, specific strength, most consequential gap, and next practice;
   the formative label/dimension profile follows. Numeric detail and citations
   sit under disclosure. Users may hide both label and score.
5. Feedback follows attempt → correct elements → one prioritized gap → cue/source
   → optional revision → always-revealable worked comparison. Safety-critical
   misconceptions are corrected immediately, not withheld for retry.
6. Describe every result as applying to one explanation, blueprint, evidence
   snapshot, and assistance condition. It is not proof of mastery or durable
   retention.
7. Do not compare users, publish leaderboards, gate work, retain a “best score,”
   or trend scores across non-equated blueprint difficulty/operation, evidence
   scope, rubric major, or assistance condition. History shows concepts and
   operations demonstrated in individual checks.
8. Allow appeal, supported practice retries, export, and deletion without
   overwriting prior attempts/assessments.
9. Keep optional user confidence separate from assessed performance and use it
   only for private self-calibration.

## Consequences

- The rating is actionable, inspectable, and comparable across a user's own
  genuinely equated attempts without pretending to measure general intelligence
  or expertise.
- Weighted dimensions and caps require careful rubric versioning and human
  calibration.
- Users may over-focus on labels or numbers; the UI leads with formative
  feedback and supports hiding both.
- Separate storage avoids corrupting the meaning of subjective journal ratings
  but requires dedicated history and visualization components.
- Not assessed becomes a first-class outcome, preventing missing evidence from
  being represented as learner failure.

## Related

- [Implementation plan](../implementation_plans/2026-07-18_learning_understanding_verification_agent.md)
- [Flexible rating system plan](../implementation_plans/2026-02-09_flexible_rating_system.md)
