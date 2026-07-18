# ADR 0033: Learning Verification Session Persistence

- Status: Proposed
- Date: 2026-07-18

## Context

Verification spans multiple devices and times: a checkpoint is created, evidence
is frozen, the user may defer or answer, evaluation may retry, and an assessment
may be appealed. A mutable session row would create last-write-wins conflicts
between answer, deferral, evaluation, and appeal events. Evaluating against live
source state would also make historical results irreproducible.

The journal database is the source of truth for user records. A verification
assessment is agent-generated interpretation, similar to agent messages,
reports, and evolution sessions; it is not a journal fact or a subjective
`RatingEntry`.

## Decision

Persist verification as causal events plus immutable artifacts, with a strict
synced-manifest/device-local-evidence split.

1. The verifier's `AgentMessageEntity`/`AgentLink.messagePrev` DAG is the sole
   source of truth, as required by ADR 0016. Its event vocabulary covers
   candidate observation/suppression, evidence capture, session offer, attempt,
   disposition, evaluation request/cancellation/result, appeal/audit,
   supersession, and deletion.
2. Add immutable structured artifacts for candidate/session, privacy-safe
   evidence manifest, pre-response question blueprint, user attempt,
   evaluation request, assessment result, prompt disposition, appeal, and
   optional audit. Causal events reference artifacts; row timestamps do not
   order state.
3. Write synced events, artifacts, and typed links atomically through
   `AgentSyncService`. Same-ID immutable insertion verifies byte-identical
   content; a mismatch is quarantined rather than overwritten. Causal messages
   always use fresh append IDs; semantic IDs live in payloads. The only allowed
   same-ID artifact/link change is a monotonic tombstone.
4. Derive session presentation state, assessment outcome, audit badge, burden,
   and concept-review history from causal events. Regenerable local session and
   concept indexes serve pending/due/history queries and never sync as
   authority.
5. Use a deterministic candidate ID based on verifier scope and stable source
   signal. Connected generation uses ADR 0018 lease/idempotency. Offline
   evidence/question variance creates separate content-addressed branches;
   the lowest validated `(manifestDigest, blueprintDigest, sessionId)` tuple is
   presented, and a reconciliation behavior appends supersession events for the
   rest.
6. Separate deterministic evaluation request identity from stochastic result
   identity. Every result is immutable and unique; concurrent disagreement is
   preserved for audit. Attempt order is derived, not a uniqueness field.
7. Freeze typed source revisions, concept identity, question blueprint,
   assistance condition, rubric/evaluator versions, and evidence digest before
   evaluation.
8. Synced Lotti evidence uses ADR 0020 consuming messages and actual
   `messagePayload` links. Local-only external workspace excerpts live in a
   separate nonsynced content-addressed cache; synced manifests contain only
   sanitized descriptors/digests and never link to local blobs or persist
   absolute paths.
9. Retain synced cited evidence under ADR 0020 coverage rules until its
   assessment is deleted. Device-local raw context has a versioned engineering
   TTL and may expire, after which history labels citations unavailable.
   Deletion appends synced tombstones and physical GC waits for global
   reachability plus convergence/retention conditions. An undeleted assessment
   is a compaction coverage root for its cited payloads.
10. Enforce typed `SourceRef`/`ConceptRef`, endpoint/cardinality checks, digest
    recomputation, and assessment → request → attempt → session → blueprint →
    snapshot consistency. Older clients show unsupported records and do not
    mutate versions they cannot interpret. Verification sync requires a minimum
    payload version; upgraded clients rehydrate from the sync sequence log and
    rebuild local projections.
11. Keep machine assessments out of the journal rating catalog. A future,
    explicit “save reflection to journal” action may create a user-authored
    journal entry, but is not automatic.

## Consequences

- Concurrent answer, deferral, and appeal events remain auditable and converge
  without overwriting one another.
- Assessments are reproducibly tied to the evidence revision they judged.
- Verification history follows the existing agent sync/privacy boundary and can
  be deleted with agent data.
- Causal event adapters, projection/index rebuilds, offline branch
  supersession, atomic integrity, and global graph cleanup are more complex than
  a mutable session table.
- Expired device-local evidence can limit later re-evaluation. Manifests still
  explain scope/provenance, but unavailable citations must be labeled and a
  fresh evaluation requires recapture or a new snapshot.
- Learning history is not a permanent credential or journal fact, which must be
  clear in the UI and manual.

## Related

- [Implementation plan](../implementation_plans/2026-07-18_learning_understanding_verification_agent.md)
- [ADR 0016: Agent-Derived State as a Projection of the Append-Only Log](./0016-agent-state-as-log-projection.md)
- [ADR 0020: Agent Input Capture](./0020-agent-input-capture.md)
- [ADR 0018: Convergent Multi-Device Execution](./0018-convergent-multi-device-execution.md)
