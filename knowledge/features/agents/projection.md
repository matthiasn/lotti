---
type: Feature Module
title: Projection kernel
description: "A pure, deterministic fold over an event *set* — proving that projected state is the same regardless of arrival order or branching."
resource: ../../../lib/features/agents/projection
tags: [agents, projection, determinism, convergence]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T04:15:00Z }
stale_after: 2026-10-12
sources:
  - id: src
    resource: ../../../lib/features/agents/projection
    title: Projection kernel source
    last_modified: 2026-07-26
---

A **pure, deterministic** projection over an event-set view of the agent log:
given a *set* of agent events, produce a canonical linear order and fold it into
derived state.

The thesis it proves:

> The same event set yields equal projected state regardless of arrival order or
> branching.

**If that permutation-invariance holds, the "log is the agent / convergent DAG"
design is real** — which is why this exists as its own testable kernel rather than
as logic scattered through the wake path.

```mermaid
flowchart TD
  subgraph Inputs["The same event set, two arrival orders"]
    A["Device A received: e3, e1, e2"]
    B["Device B received: e1, e2, e3"]
  end

  A --> CO["canonicalOrder(events)"]
  B --> CO

  CO --> Dup{"two distinct events<br/>share an id?"}
  Dup -->|yes| DupEx["throw DuplicateEventIdException"]
  Dup -->|no| Kahn["Kahn topological sort over causalParents<br/>ready set ordered by (hostId, id)"]

  Kahn --> Stuck{"every event emitted?"}
  Stuck -->|no — edges form a cycle| CycEx["throw ProjectionCycleException"]
  Stuck -->|yes| Ordered["one canonical linear extension"]

  Ordered --> Fold["project(ordered)"]
  Fold --> Result["AgentProjection<br/>headIds · latestReportId · danglingParentIds"]

  Result --> Equal(["Both devices compute an equal AgentProjection"])
```

Three properties of that pipeline carry the whole design:

- **The tie-break is total.** Among events whose present parents are all emitted,
  the smallest `(hostId, id)` goes next — so concurrent branches, which the partial
  order leaves genuinely unordered, still linearise identically everywhere.
- **A dangling parent is not an error.** A `causalParents` id that is absent from
  the input — a partial sync window, or a parent compacted away — imposes no edge,
  so the event is treated as a root and the id is reported in
  `danglingParentIds`. It never throws.
- **The fold reads only structure.** `headIds`, `latestReportId` and
  `danglingParentIds` come from event ids, `kind` and the parent graph — never
  from vector clocks or wall-clock time. Nothing in the output can depend on when
  an event happened to arrive.

It is the foundation under [state-as-projection and fork
healing](memory-and-compaction.md): multi-head tolerance is only safe if
the fold cannot depend on which head arrived first.

The projection is plain Dart with no I/O, so it can be exercised with property
tests over shuffled event sets — the only honest way to test a claim about
permutation invariance.
