# ADR 0031: Learning Verification Checkpoint Policy

- Status: Proposed
- Date: 2026-07-18

## Context

Understanding checks are useful only when they follow meaningful work and do
not become another stream of interruptions. A model could infer that a topic is
interesting, but letting a model decide when to interrupt would make prompting
non-deterministic, difficult to test, hard to explain, and vulnerable to source
content that asks the model to trigger a quiz.

The existing `WakeOrchestrator` schedules background agent work. Verification
is different: it is an interactive user turn that may be deferred, skipped, or
answered on another device.

## Decision

Use a separate `LearningCheckpointCoordinator` with a versioned deterministic
policy.

1. Source workflows emit normalized signals only after meaningful durable
   events such as a completed implementation, resolved consequential decision,
   terminal task transition, pre-finalization boundary, due spaced review, or
   explicit manual request.
2. The coordinator first appends a causal candidate event with a deterministic
   candidate ID derived from verifier scope, stable source signal, checkpoint
   type, and policy version. Source-event replay is idempotent and crash-safe.
3. Event-level hard guards apply privacy, activity, source authorization,
   cooldown, and burden constraints before evidence/model work.
4. Provisionally eligible automatic candidates receive a deterministic priority
   based on checkpoint importance, novelty, consequence/risk, prior gaps,
   evidence quality, and fatigue.
5. Evidence and a one-concept question blueprint are then frozen. Final guards
   apply evidence coverage and concept spacing. A model may suppress a candidate
   by finding no supportable concept; it cannot make an otherwise ineligible
   candidate interrupt the user.
6. Connected devices use ADR 0018 lease/idempotency. Offline evidence/question
   branches remain separate content-addressed sessions; projection chooses one
   canonically and preserves/supersedes alternatives without same-ID overwrite.
7. Immediate post-work self-explanation and delayed unaided retrieval/transfer
   are distinct checkpoint types. Cadence, threshold, and burden numbers are
   versioned experimental hypotheses calibrated from delayed outcomes and
   learner burden.
8. Prompts are non-modal, advisory, and never gate finalization. Users can choose
   concept, operation, depth, assistance mode, quiet window, Later, Skip,
   Already know this, Not relevant, disable, or manual invocation. A skipped
   concept does not automatically resurface without fresh consent/context.
9. `WakeOrchestrator` continues to run background agents; it does not own the
   interactive prompt queue.

## Consequences

- Prompt behavior is replayable, testable, explainable, and resistant to prompt
  injection.
- Burden limits are enforceable independently of model behavior.
- The coordinator, causal candidate events, offline branch convergence, and
  signal adapters add orchestration and policy-versioning responsibility.
- Deterministic signals can miss a pedagogically useful moment until a source
  workflow emits the right event; manual verification remains the fallback.
- Concept selection may vary by model, but it cannot increase prompt frequency;
  offline variance may create preserved superseded branches.
- No fixed cadence is treated as pedagogically valid until delayed-outcome
  calibration supports it.

## Related

- [Implementation plan](../implementation_plans/2026-07-18_learning_understanding_verification_agent.md)
- [ADR 0002: Wake Scheduling and Throttling Policy](./0002-wake-scheduling-and-throttling-policy.md)
- [ADR 0016: Agent-Derived State as a Projection of the Append-Only Log](./0016-agent-state-as-log-projection.md)
- [ADR 0018: Convergent Multi-Device Execution](./0018-convergent-multi-device-execution.md)
