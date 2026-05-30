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
  final VectorClock vectorClock;   // causal stamp
  final List<String> causalParents;// messagePrev parent ids (0..n; n>1 = a join)
  final AgentEventKind kind;       // message | report | observation | summary | ...
  // Only fields the fold needs; heavy payloads stay out (referenced by id).
}
```

A thin adapter (`AgentEvent.fromMessage`/`fromLink`) is added in **PR 3**; here it is exercised with synthetic `AgentEvent`s.

> **Open implementation detail (resolve in this PR or defer to PR 3):** does `AgentMessageEntity` carry an explicit authoring `hostId`? `vectorClock` is a `Map<hostId,counter>` but not necessarily a single authoring host. The tiebreak needs a *stable per-event* host. Options: (a) add/confirm an authoring `hostId` field; (b) fall back to `id` alone (stable UUID) as the tiebreak — acceptable since `id` is globally unique, though `(hostId, id)` matches ADR 0018. For PR 1, `AgentEvent.hostId` is explicit and supplied by fixtures; production sourcing is settled in PR 3.

## Functions

### `canonicalOrder(Set<AgentEvent>) → List<AgentEvent>`

A deterministic linear extension of the causal partial order:

- **Partial order:** A ≺ B iff `A.vectorClock` is strictly dominated by `B.vectorClock` (vector clock is the source of truth for causality). `causalParents` (`messagePrev`) is a denormalized convenience and **must be consistent** with the VC order — assert `child.vc` dominates each parent's `vc`.
- **Algorithm:** Kahn-style topological sort. At each step, among events with **no un-emitted causal predecessor**, emit the one with the smallest **`(hostId, id)`** key. Concurrent events (`VclockStatus.concurrent`) are thus ordered deterministically by `(hostId, id)`.
- **Output:** a total order that (1) respects causality and (2) is identical on every device holding the same set.

> **Cost note:** the naïve partial order is O(n²) pairwise VC compares. Fine for the kernel and bounded in production by compaction checkpoints (the fold runs over `summary + recent tail`, not all history). An optimization (use `causalParents` edges to prune comparisons) can come later; correctness first.

### `project(Iterable<AgentEvent> ordered) → AgentProjection`

Fold the ordered events into derived state. **Minimal v1:**

```dart
class AgentProjection {
  final List<String> headIds;        // events with no messagePrev child (reverse-index)
  final String? latestReportId;      // last report event in canonical order
  // grows later: open proposals, recentHead/latestSummary pointers, etc.
}
```

- **Heads** = events not referenced as any other event's `causalParent` (reverse-index the edges). A single chain → 1 head; a fork → ≥2 heads. This is the multi-head-tolerant projection.
- Keep the fold a pure function of the ordered list — no clocks, no I/O.

## Determinism contract (the thing under test)

> `project(canonicalOrder(S))` is a pure function of the **set** `S`. For any permutation/partition of `S` that two devices might observe, both compute byte-identical `AgentProjection`.

## Module layout

```
lib/features/agents/projection/
  agent_event.dart          // AgentEvent + AgentEventKind
  canonical_order.dart      // canonicalOrder()
  agent_projection.dart     // AgentProjection + project()
test/features/agents/projection/
  canonical_order_test.dart // property + example
  agent_projection_test.dart
  projection_convergence_test.dart  // two-device simulator (shared harness)
```

## Test plan

Pure logic → **Glados property tests** (per `test/README.md` and `daily_os_next/README.md` → Testing Strategy), plus example tests for concrete shapes.

**Property tests (`canonical_order_test.dart`):**
- **Permutation-invariance:** for a random event set, every shuffle of the input produces the identical `canonicalOrder` output. *(The whole thesis.)*
- **Causal respect:** for every pair where A ≺ B (VC dominance / `causalParents`), A precedes B in the output.
- **Deterministic tiebreak:** concurrent events appear in `(hostId, id)` order, stably across shuffles.
- **Generators:** build random DAGs by appending events with monotonically-merged vector clocks (so the partial order is well-formed); include forks (multiple children of one parent) and joins (multiple parents).

**Property tests (`agent_projection_test.dart`):**
- **Multi-head:** a fork yields ≥2 `headIds`; the set of heads is invariant under input shuffle.
- **Projection determinism:** `project(canonicalOrder(S))` invariant under shuffle of `S`.

**Convergence simulator (`projection_convergence_test.dart`):**
- Build set on "device A", a partially-overlapping set on "device B"; union them; assert identical projection on both. (This harness is reused by PRs 3–7.)

**Example/edge tests:**
- empty set → empty projection; single event → 1 head; a linear chain → 1 head, ordered; a clean fork → 2 heads.
- **Dangling parent** (`causalParent` id not in the set) — define behavior: treat as a root for ordering, surface via a diagnostic; never crash.
- **Cycle / VC-inconsistent parent** — must be impossible by construction; assert and fail loudly in debug (a cycle indicates a bug upstream).
- **Duplicate id in the set** — reject/dedupe deterministically.

## Acceptance criteria (definition of done)

- `dart-mcp.analyze_files` / `fvm dart analyze` → zero warnings/infos.
- `fvm dart format .` clean.
- All property + example + convergence tests pass (`fvm flutter test test/features/agents/projection/`).
- No production code path imports the kernel yet (verify: the only importers are the tests).
- Public API documented with dartdoc; the determinism contract stated in the file header.

## Risks & open items to settle here

- **`hostId` sourcing** (see event-view note) — decide explicit-field vs `id`-only tiebreak; if `id`-only, update ADR 0018 wording to match.
- **VC-vs-`messagePrev` consistency** — confirm children's VCs dominate parents'; the kernel asserts it.
- **Ordering cost** on large sets — acceptable now; revisit after compaction (PR 5) bounds the working set.

## Follow-on

- **PR 3** adds the `AgentEvent.fromMessage`/`fromLink` adapter, populates `messagePrev` in production, and runs the projection in **shadow** against the live mutable state (assert equality).
- **PR 4** flips reads to the projection (Move 1).
- The convergence simulator built here is the shared test harness for compaction (PR 5), joins (PR 6), and the lease (PR 7).
