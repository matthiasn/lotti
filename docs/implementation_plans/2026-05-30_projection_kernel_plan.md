# Projection Kernel — Implementation Plan (PR 1)

- Status: Plan · Date: 2026-05-30
- Part of: [`2026-05-30_daily_os_runtime_implementation_roadmap.md`](./2026-05-30_daily_os_runtime_implementation_roadmap.md) (this is its first PR).
- Design baseline: [`../daily_os_ai_runtime_architecture.md`](../daily_os_ai_runtime_architecture.md) §4 & §8; [ADR 0016](../adr/0016-agent-state-as-log-projection.md) rule 4; [ADR 0018](../adr/0018-convergent-multi-device-execution.md) (canonical linearization).

## Goal

A **pure, deterministic projection kernel** over an event-set view of the agent log: given a *set* of agent events, produce a canonical linear order and fold it into derived state. The kernel is **not wired into production** in this PR — it is a validated library proving the core thesis: *the same event set yields byte-identical projected state regardless of arrival order or branching.*

If permutation-invariance holds, the "log is the agent / convergent DAG" design is real. If it doesn't, we learn that here — before touching any production state.

## Non-goals (explicitly out of scope for this PR)

- No DB schema change, no `agent_repository`/sync changes, no UI.
- No population of `messagePrev`/`prevMessageId` in production (that's PR 3).
- No compaction, no joins, no lease (later PRs).
- The `project()` fold starts **minimal** — just enough derived state to exercise the fold; it grows in later PRs.

## Inputs the kernel relies on (already in the codebase)

- `lib/features/sync/vector_clock.dart` — `VectorClock` + `VclockStatus` (`equal`/`concurrent`/`a_gt_b`/`b_gt_a`), `compare`, element-wise-max `merge`. **Reused as-is.**
- `AgentMessageEntity` (carries `vectorClock`, `prevMessageId`, `kind`, `id`) and `AgentLink.messagePrev` (child→parent edge) — the *future* event source. This PR does **not** read them directly; it works against an adapter view (below) and synthetic fixtures.

## The event view

Decouple the kernel from Drift rows with a small immutable value type:

```dart
/// Minimal causal view of one agent-log event, independent of storage.
class AgentEvent {
  final String id;                 // stable, globally-unique (UUID)
  final String hostId;             // authoring host — the deterministic tiebreak key
  final VectorClock vectorClock;   // consistency metadata: diagnosed, never the ordering input
  final List<String> causalParents;// messagePrev parent ids — THE causal graph (0..n; n>1 = a join)
  final AgentEventKind kind;       // message | report | observation | summary | ...
  // Only fields the fold needs; heavy payloads stay out (referenced by id).
}
```

A thin adapter (`AgentEvent.fromMessage`/`fromLink`) is added in **PR 3**; here it is exercised with synthetic `AgentEvent`s.

> **Open implementation detail (resolve in this PR or defer to PR 3):** does `AgentMessageEntity` carry an explicit authoring `hostId`? `vectorClock` is a `Map<hostId,counter>` but not necessarily a single authoring host. The tiebreak needs a *stable per-event* host. Options: (a) add/confirm an authoring `hostId` field; (b) fall back to `id` alone (stable UUID) as the tiebreak — acceptable since `id` is globally unique, though `(hostId, id)` matches ADR 0018. For PR 1, `AgentEvent.hostId` is explicit and supplied by fixtures; production sourcing is settled in PR 3.

## Functions

### `canonicalOrder(Iterable<AgentEvent>) → List<AgentEvent>`

A deterministic linear extension of the causal partial order. The kernel takes an
`Iterable` (**not** a `Set`) so it can **validate duplicate ids before
set-membership silently collapses or duplicates them** (see "Duplicate id" in the
edge tests); internally it normalizes to an id-keyed map.

- **Canonical causal graph = `causalParents` (`messagePrev`).** The parent edges are
  the single source of truth for **both ordering and heads**, so the two can never
  diverge. Partial order: A ≺ B iff there is a directed `causalParents` path from A to
  B. Vector clocks are **consistency metadata, not the ordering input** — the kernel
  *diagnoses* them, it never reorders on them. (We choose edges-as-graph over
  VC-as-graph deliberately: it matches the production `messagePrev` model, keeps
  ordering and head-detection derived from one structure, and means head repair /
  branch / join need no VC-edge synthesis. Per ADR 0018, the VC remains the
  cross-device conflict signal; here it is validated, not trusted for order.)
- **Algorithm:** Kahn-style topological sort over the parent edges. At each step, among
  events with **no un-emitted parent present in the set**, emit the one with the
  smallest **`(hostId, id)`** key. Events with no directed path between them
  (concurrent branches) are thus ordered deterministically by `(hostId, id)`.
- **Output:** a total order that (1) respects the `causalParents` partial order and
  (2) is identical on every device holding the same event set.
- **Cycle = fail loudly.** Because edges drive ordering, a cycle in `causalParents`
  (malformed upstream input) makes Kahn stall — the kernel throws a typed
  `ProjectionCycleException` rather than emitting a partial order. This is a real,
  reachable, tested path (unlike a VC-dominance partial order, which is a DAG by
  construction and could never exercise the branch).

> **Cost note:** topological sort over the `causalParents` edges is O(V+E); the
> VC-consistency diagnostic is O(edges) — one `compare` per present edge. No O(n²)
> all-pairs VC scan is needed, because edges (not VC dominance) drive ordering.
> Bounded in production by compaction checkpoints (the fold runs over
> `summary + recent tail`, not all history).

### `project(Iterable<AgentEvent> ordered) → AgentProjection`

Fold the ordered events into derived state. **Minimal v1:**

```dart
class AgentProjection {
  final List<String> headIds;          // events with no messagePrev child (reverse-index)
  final String? latestReportId;        // last report event in canonical order
  final List<String> danglingParentIds;// referenced parent ids absent from the set
  // grows later: open proposals, recentHead/latestSummary pointers, etc.
}
```

- **Heads** = events not referenced as any other present event's `causalParent`
  (reverse-index the edges). A single chain → 1 head; a fork → ≥2 heads. This is the
  multi-head-tolerant projection. **Heads are reverse-indexed from the same
  `causalParents` graph that drives `canonicalOrder`** — there is exactly one graph,
  so ordering and head-detection cannot disagree.
- **`danglingParentIds`** = parent ids referenced by some event's `causalParents` but
  not present in the input (a partial sync window, or a parent compacted away).
  Surfaced as a structural diagnostic; ordering treats such an event as a root. Never
  a crash.
- Keep the fold a **pure function of the ordered list — no clocks, no I/O.** All
  three outputs above are structural (graph-only).
- **Vector-clock consistency is a separate diagnostic, not part of the fold.** A small
  `diagnoseVectorClocks(events) → List<VcInconsistency>` flags present parent edges
  whose `child.vc` does not strictly dominate `parent.vc`. Keeping it out of `project`
  preserves the clock-free fold; PR 3 consumes these diagnostics when wiring
  `messagePrev` against live data.

## Determinism contract (the thing under test)

> `project(canonicalOrder(S))` is a pure function of the **set of distinct events**
> `S` (distinct by `id`). For any ordering or partition of `S` that two devices might
> observe — fed in as any `Iterable` permutation — both compute an equal
> `AgentProjection`. Duplicate-id inputs are rejected before this contract applies.

## Module layout

```
lib/features/agents/projection/
  agent_event.dart            // AgentEvent + AgentEventKind
  canonical_order.dart        // canonicalOrder() + ProjectionCycleException + DuplicateEventIdException
  agent_projection.dart       // AgentProjection + project()
  projection_diagnostics.dart // diagnoseVectorClocks() + VcInconsistency (clock-aware, kept out of the fold)
test/features/agents/projection/
  canonical_order_test.dart       // property + example
  agent_projection_test.dart
  projection_diagnostics_test.dart
  projection_convergence_test.dart  // two-device simulator (shared harness)
```

## Test plan

Pure logic → **Glados property tests** (per `test/README.md` and `daily_os_next/README.md` → Testing Strategy), plus example tests for concrete shapes.

**Property tests (`canonical_order_test.dart`):**
- **Permutation-invariance:** for a random event set, **sampled random shuffles plus
  bounded exhaustive permutations for small n** (e.g. all `n!` orders when `n ≤ 6`)
  produce the identical `canonicalOrder` output. *(The whole thesis — "every shuffle"
  is the intent, but `n!` is infeasible to enumerate for large n, so we sample at scale
  and exhaust at small n.)*
- **Causal respect:** for every parent edge A → B (A in B's `causalParents`), A precedes
  B in the output.
- **Deterministic tiebreak:** events with no directed path between them (concurrent
  branches) appear in `(hostId, id)` order, stably across shuffles.
- **Generators:** build random well-formed DAGs by appending events that pick parents
  only from already-emitted events (so the edge set is acyclic by construction), each
  carrying a monotonically-merged vector clock consistent with its parents; include
  forks (multiple children of one parent) and joins (multiple parents).

**Property tests (`agent_projection_test.dart`):**
- **Multi-head:** a fork yields ≥2 `headIds`; the set of heads is invariant under input shuffle.
- **Projection determinism:** `project(canonicalOrder(S))` invariant under shuffle of `S`.

**Property tests (`projection_diagnostics_test.dart`):**
- **No false positives on well-formed DAGs:** the generator above (VC consistent with
  parents) yields zero `VcInconsistency` and zero `danglingParentIds`.
- **Detects injected inconsistency:** flipping one edge's VC to non-dominating, or
  dropping one referenced parent, surfaces exactly that one diagnostic.

**Convergence simulator (`projection_convergence_test.dart`):**
- Build set on "device A", a partially-overlapping set on "device B"; union them; assert identical projection on both. (This harness is reused by PRs 3–7.)

**Example/edge tests:**
- empty set → empty projection; single event → 1 head; a linear chain → 1 head, ordered; a clean fork → 2 heads.
- **Dangling parent** (`causalParent` id not in the set) — treat as a root for ordering,
  surface in `danglingParentIds`; never crash.
- **Cycle in `causalParents`** — `canonicalOrder` throws `ProjectionCycleException`
  (reachable because edges drive ordering; a true cycle indicates an upstream bug).
- **VC-inconsistent parent** — `canonicalOrder` still orders by edges (no crash);
  `diagnoseVectorClocks` reports the inconsistency.
- **Duplicate id in the input** — `canonicalOrder` throws `DuplicateEventIdException`
  (deterministic rejection; validated on the `Iterable` before any set collapse).

## Acceptance criteria (definition of done)

- `dart-mcp.analyze_files` / `fvm dart analyze` → zero warnings/infos.
- `fvm dart format .` clean.
- All property + example + convergence tests pass (`fvm flutter test test/features/agents/projection/`).
- No production code path imports the kernel yet (verify: the only importers are the tests).
- Public API documented with dartdoc; the determinism contract stated in the file header.

## Risks & open items to settle here

- **`hostId` sourcing** (see event-view note) — for PR 1 `hostId` is an explicit
  fixture-supplied field used only for the `(hostId, id)` tiebreak; production sourcing
  is settled in PR 3. The tiebreak degrades gracefully: even if every event shared a
  `hostId`, `id` (a globally-unique UUID) alone keeps the order total and deterministic.
- **Causal-model boundary (resolved): `causalParents` is the canonical graph; VC is
  diagnosed metadata.** Both ordering and heads derive from the edge graph, so they
  cannot diverge. The kernel does **not** assert VC dominance — it reports
  edge/VC mismatches via `diagnoseVectorClocks` so PR 3 can clean live data without the
  kernel crashing on imperfect historical rows.
- **Ordering cost** on large sets — O(V+E) topological sort; acceptable now, and bounded
  in production after compaction (PR 5) caps the working set to `summary + recent tail`.

## Follow-on

- **PR 3** adds the `AgentEvent.fromMessage`/`fromLink` adapter, populates `messagePrev` in production, and runs the projection in **shadow** against the live mutable state (assert equality).
- **PR 4** flips reads to the projection (Move 1).
- The convergence simulator built here is the shared test harness for compaction (PR 5), joins (PR 6), and the lease (PR 7).
