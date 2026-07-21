# ADR 0033: Learning Verification Session Persistence

- Status: Proposed
- Date: 2026-07-21 (replaces the 2026-07-18 draft)

## Context

A quiz session is interactive and multi-turn: evidence is frozen, questions are
generated, answers and probe rounds accumulate, grades arrive, and the session
completes or is abandoned. That history must survive restarts, sync across the
user's devices, and stay reproducible (which question was asked against which
content).

Lotti already has the machinery for exactly this: agent state as a projection
of the append-only `AgentMessageEntity`/`AgentLink` causal log (ADR 0016),
immutable domain artifacts written atomically with their events through
`AgentSyncService`, vector clocks, and convergent multi-device execution
(ADR 0018). The 2026-07-18 draft layered a second trust system on top —
Ed25519 author attestations, trusted-control-key registries, signed clock
anchors, sequence fences, and a deletion-GC protocol with certificates and
receipts. Lotti's sync already operates among the user's own mutually trusted
devices; no other synced entity defends against a forging peer, and learning
history is not more sensitive than the journal itself. The cryptographic layer
is removed; the full draft is preserved in git history.

## Decision

1. **One verifier agent per category.** Add `AgentTemplateKind.learningVerifier`.
   A deterministic agent identity (UUID v5 over a dedicated namespace plus the
   scope) exists per Lotti category, owning the quiz sessions for that
   category's tasks; tasks without a category use a single default scope. The
   scope selects the inference profile and privacy routing exactly as existing
   agents do. Every exhaustive `AgentTemplateKind` switch is audited when the
   kind is added.
2. **Typed events, ordinary log semantics.** Add a versioned
   `LearningQuizEventEnvelope` to `AgentMessageMetadata` with a closed union:
   `quizRequested`, `quizGenerated`, `quizGenerationFailed`, `quizStarted`,
   `itemAnswered`, `itemProbed`, `itemGraded`, `itemGradingFailed`,
   `quizCompleted`, `quizAbandoned`, `suggestionOffered`,
   `suggestionDismissed`, and `quizDeleted`. Causal order
   comes from the message DAG as in ADR 0016; timestamps are ordinary
   `createdAt` values with the same best-effort semantics as the rest of the
   app. There are no signatures, attestations, clock anchors, or fences.
3. **Immutable artifacts, referenced by events.** New `AgentDomainEntity`
   variants, all immutable:
   - `LearningEvidenceSnapshotEntity` — bounded bundle of content sections
     with stable IDs, digests, source refs, and explicit truncation/missing
     markers;
   - `LearningQuizDefinitionEntity` — the frozen generated quiz: items with
     type, prompt, options/key/explanations for multiple choice, expected
     points for open items, citations, and generator provenance
     (model/profile/prompt version);
   - `LearningQuizAttemptEntity` — one answer or probe-round entry: item ID,
     round ordinal, text, input modality (typed or voice), transcript
     provenance;
   - `LearningQuizItemGradeEntity` — per-item verdict, score, what-was-missed
     feedback, citations;
   - `LearningQuizAssessmentEntity` — session score, label, strengths, gaps,
     and the config that produced them (weights/label-band versions).
   Typed `AgentLink`s connect session → task (journal entity), session →
   snapshot, session → definition, attempt → item, grade → attempt chain, and
   assessment → session.
4. **Deterministic identity where it prevents duplicates.** The UI mints a
   `quizRequestId` (UUID v4) once per user action and reuses it through
   retries; the session is keyed by it. Content-addressed artifacts (snapshot,
   definition, grades, assessment) use UUID v5 over their canonical payload
   and are insert-or-verify-identical on sync; byte-different same-ID writes
   are quarantined as elsewhere in the agent database. Attempts are
   user-authored UUID v4 facts and are never deduplicated away.
5. **Interactive work is effectively single-device; convergence is simple.**
   If concurrent devices somehow produce sibling definitions for one request,
   the session with any recorded attempt wins presentation; equally unengaged
   siblings converge on the lowest definition digest. User-authored attempts
   are never discarded by reconciliation.
6. **Device-local boundaries.** In-progress answer drafts, raw audio awaiting
   transcription, and any future workspace evidence cache stay in device-local
   tables and never enter the sync outbox. Raw audio is discarded after the
   transcript is accepted unless the user explicitly keeps it as a journal
   audio entry.
7. **Deletion is the app's normal deletion.** `quizDeleted` covers a session
   lineage (or all sessions for a task/category); projections hide covered
   history everywhere and each device purges covered payload rows when it
   observes the event. Semantics match every other synced Lotti deletion —
   there is no acknowledgment barrier, completion certificate, or collection
   receipt. Quiz history is included in agent-data export.
8. **Projections are rebuildable.** Session list, per-task quiz history, and
   an open-session view fold from the log and typed links only. Background
   refresh preserves last-rendered data per the repository's UI rules.

## Consequences

- The persistence work is a modest extension of existing agent entities,
  conversions, and projections — no new infrastructure layer.
- A hostile or compromised sync peer could forge or replay learning events.
  That is the same trust boundary as every other synced entity in Lotti and is
  accepted deliberately here.
- Multi-turn item threads make attempts/grades a small event chain rather than
  one row; projections must group by item ordinal, which is straightforward.
- Without signed time authority, timestamp skew between devices can misorder
  display of concurrent history; causal links keep per-session order correct,
  which is what matters.

## Related

- [Implementation plan](../implementation_plans/2026-07-18_learning_understanding_verification_agent.md)
- [ADR 0016: Agent-Derived State as a Projection of the Append-Only Log](./0016-agent-state-as-log-projection.md)
- [ADR 0018: Convergent Multi-Device Execution](./0018-convergent-multi-device-execution.md)
- [ADR 0031: Learning Verification Checkpoint Policy](./0031-learning-verification-checkpoint-policy.md)
- [ADR 0032: Hybrid Understanding Evaluation](./0032-hybrid-understanding-evaluation.md)
- [ADR 0034: Learning Understanding Rating](./0034-learning-understanding-rating.md)
