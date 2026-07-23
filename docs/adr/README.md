# Architecture Decision Records (ADR)

This folder stores architecture decisions that need durable rationale beyond
feature README snapshots.

## Scope

- Record decisions that affect module boundaries, lifecycle behavior, storage
  contracts, and cross-feature integration.
- Keep feature READMEs focused on the current implementation.
- Use ADRs for "why this shape exists" and migration constraints.

## File Naming

- `NNNN-short-title.md` (for example: `0001-agent-capabilities-runtime-model.md`)
- `NNNN` is a zero-padded, increasing sequence.

## ADR Template

Each ADR should contain:

1. `Status` (`Proposed`, `Accepted`, `Superseded`, `Deprecated`)
2. `Date`
3. `Context`
4. `Decision`
5. `Consequences`
6. `Related` (optional links to PRs/issues/docs)

## Index

### Task graph decision cluster

| ADR | Status | Decision ownership |
| --- | --- | --- |
| [0042: Typed Task Relationship Links](./0042-typed-task-relationship-links.md) | Proposed | `EntryLink` union variants (blocks, followsUp, duplicates, fixes, supersedes), one stored edge with rendered inverses, derived one-hop readiness, cycle tolerance, suggestion-only lifecycle coupling. |
| [0043: Dependency-Aware Planning](./0043-dependency-aware-planning.md) | Proposed | Ready frontier consumed by planning: corpus annotation (never exclusion), batch dependency resolver, drafting/digest prompt rules, task-detail visibility, explicit non-goals. |

### Relationship management decision cluster

| ADR | Status | Decision ownership |
| --- | --- | --- |
| [0037: Relationship Data Stays On-Device](./0037-relationship-on-device-storage-and-privacy.md) | Proposed | Local-only storage, opt-in E2E sync, zero external retention, explicit cloud-AI consent, deletion cascade, GDPR framing. |
| [0038: Relationship Domain Model](./0038-relationship-domain-model.md) | Proposed | `relationship`/`checkIn` journal subtypes, embedded person identity, status union, `RelationshipLink` task/timeline linking, no schema change. |
| [0039: Relationship Check-In Reminders](./0039-relationship-check-in-reminders.md) | Proposed | Importance-gated cadence rule, event-driven scheduling on the synced notification inbox, startup reconcile, platform limits. |
| [0040: Relationship Executive Briefing](./0040-relationship-executive-briefing.md) | Proposed | Relationship agent + report contract, health band, strict context boundary, privacy-weighted model routing, honesty rules. |
| [0041: Relationship Contact Linking](./0041-relationship-contact-linking.md) | Proposed | Selective per-relationship contact linking (no bulk import), channel snapshots, call/message actions from the briefing, post-interaction check-in prompt. |

### Learning verification decision cluster

| ADR | Status | Decision ownership |
| --- | --- | --- |
| [0033: Learning Verification Checkpoint Policy](./0033-learning-verification-checkpoint-policy.md) | Proposed | When quizzes start: manual-first entry from any task, deterministic suggestion triggers/guards/caps, no gating, no spaced-repetition scheduler. |
| [0034: Hybrid Understanding Evaluation](./0034-hybrid-understanding-evaluation.md) | Proposed | Frozen evidence snapshots, tailored quiz generation, deterministic validation, conversational LLM grading with bounded probes, injection resistance. |
| [0035: Learning Verification Session Persistence](./0035-learning-verification-session-persistence.md) | Proposed | Quiz events/artifacts/links on the existing agent log, identity and sync convergence, device-local boundaries, plain deletion and export. |
| [0036: Learning Understanding Rating](./0036-learning-understanding-rating.md) | Proposed | Per-item verdicts, session scores/labels, feedback-first presentation, honesty rules, storage separate from journal ratings. |

### Chronological index

- [`0001-agent-capabilities-runtime-model.md`](./0001-agent-capabilities-runtime-model.md)
- [`0002-wake-scheduling-and-throttling-policy.md`](./0002-wake-scheduling-and-throttling-policy.md)
- [`0003-task-agent-linked-task-context-contract.md`](./0003-task-agent-linked-task-context-contract.md)
- [`0004-task-agent-tool-execution-policy.md`](./0004-task-agent-tool-execution-policy.md)
- [`0005-template-model-resolution-policy.md`](./0005-template-model-resolution-policy.md)
- [`0006-change-set-deferred-tool-confirmation.md`](./0006-change-set-deferred-tool-confirmation.md)
- [`0007-token-usage-wake-run-log-storage.md`](./0007-token-usage-wake-run-log-storage.md)
- [`0008-inference-profiles-agent-provider-mapping.md`](./0008-inference-profiles-agent-provider-mapping.md)
- [`0009-redundant-change-proposal-suppression.md`](./0009-redundant-change-proposal-suppression.md)
- [`0010-scheduled-wake-infrastructure.md`](./0010-scheduled-wake-infrastructure.md)
- [`0011-feedback-classification-strategy.md`](./0011-feedback-classification-strategy.md)
- [`0012-recursive-self-improvement-depth-policy.md`](./0012-recursive-self-improvement-depth-policy.md)
- [`0013-outbox-priority-queue.md`](./0013-outbox-priority-queue.md)
- [`0014-cross-wake-critical-observation-injection.md`](./0014-cross-wake-critical-observation-injection.md)
- [`0015-outbox-message-bundling.md`](./0015-outbox-message-bundling.md)
- [`0016-agent-state-as-log-projection.md`](./0016-agent-state-as-log-projection.md)
- [`0017-deterministic-log-compaction.md`](./0017-deterministic-log-compaction.md)
- [`0018-convergent-multi-device-execution.md`](./0018-convergent-multi-device-execution.md)
- [`0019-attention-negotiation-protocol.md`](./0019-attention-negotiation-protocol.md)
- [`0020-agent-input-capture.md`](./0020-agent-input-capture.md)
- [`0021-llm-mediated-attention-claim-weighing.md`](./0021-llm-mediated-attention-claim-weighing.md)
- [`0022-long-lived-daily-os-planner.md`](./0022-long-lived-daily-os-planner.md)
- [`0023-durable-domain-agents-and-time-negotiation.md`](./0023-durable-domain-agents-and-time-negotiation.md)
- [`0024-correction-lexicon-and-transcript-correction.md`](./0024-correction-lexicon-and-transcript-correction.md)
- [`0025-insights-time-analysis-data-layer.md`](./0025-insights-time-analysis-data-layer.md)
- [`0026-author-time-memory-links.md`](./0026-author-time-memory-links.md)
- [`0027-wake-notification-propagation-and-storm-prevention.md`](./0027-wake-notification-propagation-and-storm-prevention.md)
- [`0028-tagged-plaintext-payload-and-day-summaries.md`](./0028-tagged-plaintext-payload-and-day-summaries.md)
- [`0029-knowledge-graph-explorer.md`](./0029-knowledge-graph-explorer.md)
- [`0030-desktop-keyboard-command-system.md`](./0030-desktop-keyboard-command-system.md)
- [`0031-batch-first-day-audio-capture.md`](./0031-batch-first-day-audio-capture.md)
- [`0032-hierarchical-day-agent-coordination.md`](./0032-hierarchical-day-agent-coordination.md)
- [`0033-learning-verification-checkpoint-policy.md`](./0033-learning-verification-checkpoint-policy.md)
- [`0034-hybrid-understanding-evaluation.md`](./0034-hybrid-understanding-evaluation.md)
- [`0035-learning-verification-session-persistence.md`](./0035-learning-verification-session-persistence.md)
- [`0036-learning-understanding-rating.md`](./0036-learning-understanding-rating.md)
- [`0037-relationship-on-device-storage-and-privacy.md`](./0037-relationship-on-device-storage-and-privacy.md)
- [`0038-relationship-domain-model.md`](./0038-relationship-domain-model.md)
- [`0039-relationship-check-in-reminders.md`](./0039-relationship-check-in-reminders.md)
- [`0040-relationship-executive-briefing.md`](./0040-relationship-executive-briefing.md)
- [`0041-relationship-contact-linking.md`](./0041-relationship-contact-linking.md)
- [`0042-typed-task-relationship-links.md`](./0042-typed-task-relationship-links.md)
- [`0043-dependency-aware-planning.md`](./0043-dependency-aware-planning.md)
