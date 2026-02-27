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
