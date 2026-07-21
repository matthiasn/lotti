# ADR 0033: Learning Verification Session Persistence

- Status: Proposed
- Date: 2026-07-21

## Context

A quiz session is interactive and multi-turn: evidence is frozen, questions
are generated, answers and probe rounds accumulate, grades arrive, and the
session completes or is abandoned. That history must survive restarts, sync
across the user's devices, and stay reproducible (which question was asked
against which content). Lotti's agent framework already provides the needed
machinery: the append-only `AgentMessageEntity`/`AgentLink` causal log
(ADR 0016), immutable artifacts written atomically through
`AgentSyncService`, vector clocks, and convergent multi-device execution
(ADR 0018). Learning data deliberately adds no trust layer of its own — sync
runs among the user's own devices, and quiz history is no more sensitive
than the journal content it derives from.

## Decision

1. **One verifier agent per category.** Add
   `AgentTemplateKind.learningVerifier`; a deterministic agent identity
   (UUID v5 over the scope) per category owns that category's quiz sessions
   and selects the inference profile and privacy route. Tasks without a
   category use a single default scope. Audit every exhaustive
   `AgentTemplateKind` switch.
2. **Typed events, ordinary log semantics.** A versioned
   `LearningQuizEventEnvelope` in `AgentMessageMetadata` with a closed
   union: `quizRequested`, `quizGenerated`, `quizGenerationFailed`,
   `quizStarted`, `itemAnswered`, `itemProbed`, `itemGraded`,
   `itemGradingFailed`, `quizCompleted`, `quizAbandoned`,
   `suggestionOffered`, `suggestionDismissed`, `quizDeleted`. Causal order
   comes from the message DAG; timestamps are ordinary `createdAt` values.
3. **Immutable artifacts, referenced by events.**
   `LearningQuizSessionEntity` (per-run anchor, ID equal to its
   `quizRequestId`, task ref, scope, depth choice; no status field —
   lifecycle is projected), `LearningEvidenceSnapshotEntity` (sectioned
   content with digests and truncation markers), `LearningQuizDefinitionEntity`
   (frozen items, keys, citations, generator provenance),
   `LearningQuizAttemptEntity` (answer or probe reply with modality),
   `LearningQuizItemGradeEntity`, and `LearningQuizAssessmentEntity`. Typed
   links: session → task/snapshot/definition, attempt → item thread,
   grade → thread, assessment → session.
4. **Identity.** `quizRequestId` is minted once per UI action and reused
   through retries. Content-addressed artifacts are UUID v5 over canonical
   payload and insert-or-verify-identical on sync; attempts are UUID v4 and
   never deduplicated. A session with any attempt wins presentation over
   unengaged siblings; equally unengaged siblings converge on the lowest
   definition digest.
5. **Device-local boundaries.** Answer drafts and raw audio awaiting
   transcription stay local; audio is discarded after transcript acceptance
   unless explicitly kept as a journal audio entry.
6. **Deletion is the app's normal deletion.** `quizDeleted` covers a
   session, task, or category selector; projections hide covered history and
   devices purge covered payloads on observing it. History is exportable
   with agent data.
7. **Projections are rebuildable** from the log: session-detail timeline
   (questions, answers, probes, grades, assessment in causal order), open
   sessions, per-task and per-category history.

## Consequences

- Persistence is a modest extension of existing agent entities — no new
  infrastructure layer.
- A hostile sync peer could forge learning events; that is the same accepted
  trust boundary as every other synced Lotti entity.
- Clock skew can misorder cross-session display; causal links keep
  per-session order correct, which is what matters.

## Related

- [Implementation plan](../implementation_plans/2026-07-18_learning_understanding_verification_agent.md)
- [ADR 0016: Agent-Derived State as a Projection of the Append-Only Log](./0016-agent-state-as-log-projection.md)
- [ADR 0018: Convergent Multi-Device Execution](./0018-convergent-multi-device-execution.md)
- [ADR 0031: Learning Verification Checkpoint Policy](./0031-learning-verification-checkpoint-policy.md)
- [ADR 0032: Hybrid Understanding Evaluation](./0032-hybrid-understanding-evaluation.md)
- [ADR 0034: Learning Understanding Rating](./0034-learning-understanding-rating.md)
