---
type: Feature Module
title: Projection kernel
description: "A pure, deterministic fold over an event *set* — proving that projected state is the same regardless of arrival order or branching."
resource: ../../../lib/features/agents/projection
tags: [agents, projection, determinism, convergence]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T04:15:00Z }
stale_after: 2027-01-26
sources:
  - id: src
    resource: ../../../lib/features/agents/projection
    title: Projection kernel source
    last_modified: 2026-07-25
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

It is the foundation under [state-as-projection and fork
healing](memory-and-compaction.md): multi-head tolerance is only safe if
the fold cannot depend on which head arrived first.

The projection is plain Dart with no I/O, so it can be exercised with property
tests over shuffled event sets — the only honest way to test a claim about
permutation invariance.
