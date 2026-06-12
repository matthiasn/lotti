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
- [`0029-agent-evaluation-harness.md`](./0029-agent-evaluation-harness.md)
