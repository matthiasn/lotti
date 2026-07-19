# ADR 0032: Hybrid Understanding Evaluation

- Status: Proposed
- Date: 2026-07-18

## Context

Rule-based comparison can validate identifiers, citations, score ranges, and
explicit facts, but it cannot reliably judge paraphrases, causal explanations,
trade-offs, predictions, or alternate correct terminology. An unconstrained
LLM can perform semantic comparison, but may hallucinate evidence, follow
instructions embedded in code, produce inconsistent scores, or hide
uncertainty behind false precision.

The evaluator must distinguish “the user missed a concept” from “the captured
evidence cannot establish the concept.” It must also remain inspectable and
calibratable against human judgments.

## Decision

Use a hybrid evaluation pipeline.

1. Before the user responds, a frozen question blueprint defines one observable
   objective, primary concept, elicited cognitive operation, difficulty,
   evidence-bound target claims, assistance options, and assessable dimensions.
2. Blueprint construction is a tool-less, schema-constrained inference over
   evidence explicitly delimited as untrusted data. A deterministic
   `BlueprintValidator` rejects unsupported claims, invalid evidence IDs,
   unsafe universals, dimensions the operation cannot elicit, or a blueprint
   that does not meet its declared evidence-coverage rule.
3. Deterministic admission checks validate session freshness, blueprint and
   evidence digests, privacy, response bounds, recorded assistance/support, and
   blueprint-specific evidence coverage.
4. A tool-less LLM decomposes the response into claims and proposes anchored
   0–4 levels only for dimensions the blueprint elicited: correctness,
   causal/mechanistic understanding, completeness/relevance,
   boundaries/trade-offs, and validation/transfer.
   Every other dimension is `notObserved` and cannot reduce the result.
5. Every material claim, gap, contradiction, and proposed level must cite valid
   evidence item IDs from the frozen snapshot.
6. The LLM receives evidence and the response as untrusted data and has no
   tools, network, shell, or write capability.
7. A deterministic validator checks schema/citations, computes optional numeric
   detail across observed weights only, applies versioned caps, restricts a
   transfer label to an administered novel transfer item, and calculates
   assessment reliability independently of learner performance.
8. An evaluation request has a deterministic execution identity; each
   stochastic result has its own immutable content/UUID identity. Concurrent
   disagreement is preserved and audited rather than overwritten.
9. Invalid output creates one distinct repair request. Persistent failure or
   insufficient evidence produces **Not assessed**, never a guessed low score.
10. No hidden chain-of-thought is requested or stored. Persisted rationale is a
   concise claim/evidence explanation.
11. A versioned human-rated corpus, sampled second reviews, and user appeals
    calibrate the evaluator and gate rollout. Calibration includes delayed
    unaided/transfer outcomes and false-low/false-high slices by language,
    brevity, response form, input mode, assistance condition, question type,
    blueprint difficulty, and concept namespace.
12. Content—not grammar, accent, exact jargon, verbosity, or typing speed—is
    assessed. The learner may use unaided-first, open-book, hinted, or
    worked-example support; the condition is disclosed and persisted but never
    presented as proof that no external source or AI was consulted.

## Consequences

- Semantic flexibility and alternate wording can be evaluated without giving
  the model authority over evidence or final arithmetic.
- Results carry reproducible citations, explicit versions, and uncertainty.
- A focused question does not masquerade as evidence about unelicited
  dimensions or durable mastery.
- The pipeline is more complex than either rules or one LLM call and requires a
  calibration corpus plus ongoing evaluator governance.
- Provider/model changes can shift proposed dimension levels; versioned
  provenance and audits make that drift visible.
- Some answers remain unscored when evidence or evaluator reliability is weak,
  which is preferable to false certainty.
- Results from non-equated blueprints, evidence scopes, rubric majors, or
  assistance conditions cannot be compared as a score trend.

## Related

- [Implementation plan](../implementation_plans/2026-07-18_learning_understanding_verification_agent.md)
- [ADR 0011: Feedback Classification Strategy](./0011-feedback-classification-strategy.md)
