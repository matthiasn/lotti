# Projection kernel

A **pure, deterministic** projection over an event-set view of the agent log:
given a *set* of agent events, produce a canonical linear order and fold it into
derived state. The thesis it proves is

> the same event set yields equal projected state regardless of arrival order or
> branching.

If that permutation-invariance holds, the "log is the agent / convergent DAG"
design is real. This module is **not wired into production** (PR 1 of the Daily
OS runtime roadmap) — its only importers are its tests. PR 3 adds the adapter
from storage rows and runs it in shadow against live state.

## Files

| File | Responsibility |
| --- | --- |
| `agent_event.dart` | `AgentEvent` — storage-independent causal view + `AgentEventKind`. |
| `canonical_order.dart` | `canonicalOrder()` — deterministic topological sort; `DuplicateEventIdException`, `ProjectionCycleException`. |
| `agent_projection.dart` | `AgentProjection` + `project()` — the clock-free structural fold. |
| `projection_diagnostics.dart` | `diagnoseVectorClocks()` + `VcInconsistency` — vector-clock consistency surface, kept out of the fold. |

## The causal model (the load-bearing decision)

`causalParents` (the `messagePrev` graph) is the **single canonical source of
truth** for both ordering *and* head detection. Vector clocks are **consistency
metadata** that the kernel *diagnoses* but never orders by.

This matters because the two could otherwise diverge: if vector-clock dominance
drove ordering while heads were reverse-indexed from edges, a missing edge would
leave the order looking causal while the head set was wrong. Deriving both from
one graph makes that divergence impossible by construction. It also means:

- **Cycle detection is a real, reachable, tested path** — a malformed
  `causalParents` cycle makes the topological sort stall and throw. (A
  vector-clock-dominance order is a DAG by construction and could never exercise
  that branch.)
- **Imperfect historical vector clocks do not crash the kernel** — they surface
  as `VcInconsistency` diagnostics for PR 3 to reconcile against live data.

Per ADR 0018 the vector clock remains the cross-device *conflict* signal; here
it is validated, not trusted for order.

## Pipeline

```mermaid
flowchart LR
  S["Iterable&lt;AgentEvent&gt;<br/>(any arrival order)"] --> CO["canonicalOrder()"]
  CO -->|"DuplicateEventIdException<br/>ProjectionCycleException"| ERR["fail loudly"]
  CO --> ORD["List&lt;AgentEvent&gt;<br/>(canonical total order)"]
  ORD --> PR["project()"]
  PR --> AP["AgentProjection<br/>headIds · latestReportId · danglingParentIds"]
  S -.->|clock-aware, separate| DG["diagnoseVectorClocks()"]
  DG -.-> VC["List&lt;VcInconsistency&gt;"]
```

### `canonicalOrder(Iterable<AgentEvent>) → List<AgentEvent>`

Kahn-style topological sort over the parent edges. Among events with no
un-emitted *present* parent, the one with the smallest `(hostId, id)` key is
emitted next — so concurrent branches order deterministically and the result is
identical on every device holding the same set. Cost is `O(V + E)`.

- Takes an `Iterable`, not a `Set`, so duplicate ids are rejected *before* set
  membership could silently collapse or duplicate them.
- Parents referenced but absent from the input (**dangling**) impose no
  constraint — such an event is treated as a root.
- A cycle throws `ProjectionCycleException` rather than emitting a partial order.

### `project(Iterable<AgentEvent> ordered) → AgentProjection`

A pure fold over the canonically-ordered list — **no clocks, no I/O**. Every
field is structural (graph-only):

- `headIds` — events no present event references as a `causalParent` (the DAG
  tips), in canonical order. One chain → one head; a fork → ≥2.
- `latestReportId` — id of the last `report`-kind event in canonical order.
- `danglingParentIds` — referenced-but-absent parent ids, sorted.

### `diagnoseVectorClocks(Iterable<AgentEvent>) → List<VcInconsistency>`

Reports each present parent edge whose `child.vc` does not strictly dominate
`parent.vc`. Deliberately separate from `project()` so the fold stays
clock-free.

## Determinism contract

`project(canonicalOrder(S))` is a pure function of the **set of distinct events**
`S` (distinct by `id`). For any ordering or partition two devices might observe,
both compute an equal `AgentProjection`.

## Testing

Pure logic → Glados property tests (tagged `glados`) plus example/edge tests:

- **Permutation-invariance** — sampled random shuffles plus bounded exhaustive
  permutations for small `n`.
- **Causal respect** — every parent precedes its child.
- **Deterministic tiebreak** — concurrent events sort by `(hostId, id)`.
- **Projection determinism & multi-head** — equal projection under any shuffle.
- **Diagnostics** — well-formed DAGs yield none; injected inconsistencies and
  dangling parents are surfaced.
- **Two-device convergence** (`projection_convergence_test.dart`) — the shared
  harness reused by PRs 3–7.
