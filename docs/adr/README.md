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

### Learning verification decision cluster

| ADR | Status | Decision ownership |
| --- | --- | --- |
| [0031: Learning Verification Checkpoint Policy](./0031-learning-verification-checkpoint-policy.md) | Proposed | Staged prompt-checkpoint policy, global burden/delivery, immutable source-attempt schedule lineages, registered activity/recovery bindings, trusted schedule-policy activation, and deterministic selection/timing/due folding. |
| [0032: Hybrid Understanding Evaluation](./0032-hybrid-understanding-evaluation.md) | Proposed | Exact-question full-item admission, response-evaluation inputs/validation, assessment reliability, and separate fail-closed calibration clearance. |
| [0033: Learning Verification Session Persistence](./0033-learning-verification-session-persistence.md) | Proposed | Signed causal events, key/time/deadline and trusted control-key authority, registered typed links, normalized schedule persistence, convergence, compatibility, and deletion-GC finality. |
| [0034: Learning Understanding Rating](./0034-learning-understanding-rating.md) | Proposed | Dimensions, rating availability, scores/caps/labels, transfer, feedback, comparability, qualifying activity semantics, and the exact independent promotion/schedule-eligibility contract. |

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
- [`0031-learning-verification-checkpoint-policy.md`](./0031-learning-verification-checkpoint-policy.md)
- [`0032-hybrid-understanding-evaluation.md`](./0032-hybrid-understanding-evaluation.md)
- [`0033-learning-verification-session-persistence.md`](./0033-learning-verification-session-persistence.md)
- [`0034-learning-understanding-rating.md`](./0034-learning-understanding-rating.md)
