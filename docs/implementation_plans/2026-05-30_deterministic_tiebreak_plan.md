# Deterministic Tiebreak Hardening — Implementation Plan (PR 2)

- Status: Plan · Date: 2026-05-30
- Part of: [`2026-05-30_daily_os_runtime_implementation_roadmap.md`](./2026-05-30_daily_os_runtime_implementation_roadmap.md) (PR 2).
- Design baseline: [`../daily_os_ai_runtime_architecture.md`](../daily_os_ai_runtime_architecture.md) §8; [ADR 0018](../adr/0018-convergent-multi-device-execution.md) **rules 4–7** (LWW total order).
- Sibling: [`2026-05-30_projection_kernel_plan.md`](./2026-05-30_projection_kernel_plan.md) (PR 1). PR 2 is **independent** of PR 1 and lands on its own branch.

## Goal

Make the *existing* concurrent-branch resolution in the live agent-sync apply
path a **genuine total order**, so two devices that apply the same pair of
concurrent writes — in either arrival order — converge on the **same** stored
row. Today that case is resolved by arrival order (last to land wins), which can
diverge across replicas.

> **This PR touches live production code** (the Matrix sync apply path). Unlike
> PR 1 (pure, unused-in-production kernel), PR 2 changes which version of an
> agent entity/link survives a concurrent multi-device edit. It ships behind the
> normal sync path with regression coverage for the unchanged cases.

## Current behaviour (grounded in the code)

Agent entities and links received over sync are applied in
`lib/features/sync/matrix/sync_event_processor_agent_handlers.dart`:

- `_applyAgentEntityMessage` / `_applyAgentLinkMessage` call
  `_localAgentEntityDominates` / `_localAgentLinkDominates`, which delegate to
  **`_localAgentPayloadDominates`** (lines 418–452).
- That function does: `status = VectorClock.compare(localVc, incomingVc)` and
  `localDominates = status == a_gt_b || status == equal`.
  - `a_gt_b` → **keep local**, skip incoming, restore dominant cache. ✓
  - `equal`   → **keep local** (idempotent; same clock). ✓
  - `b_gt_a` → returns `false` → caller **applies incoming**. ✓
  - **`concurrent` → returns `false` → caller applies incoming.** ✗ — this is
    pure arrival-order LWW. Device A (incoming lands second) and device B
    (incoming lands first) can end up with different winners.
- Persistence is `agentRepository.upsertEntity` / `upsertLink` →
  `insertOnConflictUpdate` (`agent_repository.dart:44-48, 1199-1301`): an
  in-place `ON CONFLICT(id) DO UPDATE`, i.e. whatever the handler decides to
  apply overwrites the row.

So the VC machinery is already wired; **the entire fix is scoped to the
`concurrent` branch.** Non-concurrent behaviour must not change.

### What is and isn't available at the decision point

- Both `local` and `incoming` full objects are in hand in the callers
  (`_localAgentEntityDominates` reads `local`; `_localAgentLinkDominates` reads
  `local`), so their timestamps and clocks are accessible.
- **No authoring-host column exists on agent rows.** `originatingHostId` is only
  on the `SyncMessage` envelope (`msg.originatingHostId`), not persisted on the
  entity/link. The local device's own host id is available from
  `lib/services/vector_clock_service.dart`.
- `updatedAt` is present on mutable variants (`AgentIdentityEntity`,
  `AgentStateEntity`, `*HeadEntity`, templates, …) but **absent on append-only
  variants** (`AgentMessageEntity`, `AgentMessagePayloadEntity`,
  `AgentReportEntity`, observations — `createdAt` only). Every `AgentLink`
  variant has `updatedAt`.

## The fix

Replace the `concurrent` fall-through with a **deterministic, replica-independent
total order** (ADR 0018 rule 5). Resolution precedence, applied only when
`status == concurrent`:

1. **LWW primary — effective `updatedAt`.** Strictly-newer write wins. (Keep
   local iff `local.updatedAt > incoming.updatedAt`; apply incoming iff strictly
   newer.) "Effective `updatedAt`" = `updatedAt` where the variant has one, else
   `createdAt` (see append-only note below).
2. **Equal `updatedAt` → stable tiebreak.** Decision point below — a
   replica-independent key derived without a schema change.

`a_gt_b` / `equal` / `b_gt_a` keep their current outcomes untouched.

### Extract a pure resolver (kernel-style, property-testable)

Pull the concurrent decision into a **pure function** so it gets PR-1-grade
property testing and stays free of sync/DB I/O:

```dart
// lib/features/agents/sync/agent_concurrent_resolver.dart
enum ConcurrentWinner { local, incoming }

/// Deterministic LWW + tiebreak for two *concurrent* versions of one id.
/// Pure: depends only on its arguments; identical on every replica.
ConcurrentWinner resolveConcurrent({
  required VectorClock localVc,
  required VectorClock incomingVc,
  required DateTime localUpdatedAt,
  required DateTime incomingUpdatedAt,
});
```

The handler change is then minimal: in `_localAgentPayloadDominates`, when
`status == concurrent`, call `resolveConcurrent(...)` and return
`winner == ConcurrentWinner.local` (true ⇒ skip incoming, restore cache) instead
of the current unconditional `return false`. Thread the two effective
`updatedAt`s in from the callers via a small `effectiveUpdatedAt(...)` accessor
(one for `AgentDomainEntity`, one for `AgentLink`).

## Decision to settle in this PR — the equal-`updatedAt` tiebreak key

ADR rule 5 says "break equal `updatedAt` by `hostId` then `id`." For
**mutable-register LWW the two versions share the same `id`**, so `id` never
discriminates — the real key is an authoring-host equivalent. Two options:

- **Option A (recommended) — comparator-only, VC-derived canonical key.** Both
  replicas hold both vector clocks at decision time, so break the tie by a
  canonical comparison of the two clocks (sorted `(hostId, counter)` entries,
  lexicographic). On `concurrent` the clocks always differ (identical clocks
  would compare `equal`, not `concurrent`), so this is a *total* order with no
  residual ties. **No schema migration, no write-path plumbing, fully
  convergent, trivially property-testable.** Realizes rule 5's *intent* (a
  replica-independent stable tiebreak); deviates from its literal `hostId`
  wording — so this PR would add a one-line note to ADR 0018 rule 5.
- **Option B — add `originatingHostId` to agent rows.** Stamp it on every write
  (local = `localHostId` from `VectorClockService`; synced =
  `msg.originatingHostId`), then tiebreak by `hostId` then `id`, matching the
  ADR literally. Cost: schema migration + write-path plumbing on every agent
  write + null-backfill for existing rows + envelope→row plumbing. Larger blast
  radius; rows authored before the migration have a null host.

**Recommendation: Option A** for PR 2 (minimal, convergent, isolated, testable).
Revisit Option B only if a *true authoring host* is independently needed (e.g.
provenance UI). Note this is **distinct from PR 1's `(hostId, id)` event order**:
that orders *distinct* events (different ids); this resolves *competing versions
of one id*, where the VC is the natural discriminator.

## Module layout / touch points

```
lib/features/agents/sync/
  agent_concurrent_resolver.dart   // NEW — pure resolveConcurrent() + ConcurrentWinner
lib/features/sync/matrix/
  sync_event_processor_agent_handlers.dart  // concurrent branch → resolveConcurrent; thread updatedAt
lib/features/agents/model/  (or conversions)
  effectiveUpdatedAt(...) accessor for AgentDomainEntity + AgentLink  // small helper
test/features/agents/sync/
  agent_concurrent_resolver_test.dart        // Glados property + example
test/features/sync/matrix/
  ...agent_handlers concurrent-application tests  // deterministic, mocks, fixed clocks
```

No dependency on the PR-1 kernel; no new sync envelope fields (Option A).

## Test plan

**Pure resolver (`agent_concurrent_resolver_test.dart`) — Glados, tagged
`glados`:**
- **Replica-symmetry (the convergence property):** for any two versions, the
  *physical* winner is identical regardless of which is passed as `local` vs
  `incoming` — i.e. swapping the arguments swaps the returned enum but selects
  the same underlying version. This is what guarantees two devices agree.
- **LWW primacy:** a strictly-newer effective `updatedAt` always wins, for any
  pair of concurrent clocks.
- **Tiebreak determinism:** equal `updatedAt` → canonical-VC winner, stable and
  total (never a residual tie on genuinely concurrent clocks).
- Generators: pairs of concurrent vector clocks (build two clocks that diverge
  on different hosts) with chosen `updatedAt` deltas (`<`, `=`, `>`).

**Handler concurrent-application (deterministic example tests, mocks, fixed
clocks — per `test/README.md`):**
- Two devices apply the same concurrent pair in **opposite arrival orders** →
  the final stored row is identical (the convergence claim end-to-end).
- Equal-`updatedAt` tie resolves to the same row on both.
- **Regression guards (no behaviour change):** `a_gt_b` keeps local, `b_gt_a`
  applies incoming, `equal` is idempotent — unchanged from today.
- Append-only variant (`AgentMessageEntity`) concurrent collision falls back to
  `createdAt` and still converges (anomalous but deterministic).

## Acceptance criteria (definition of done)

- `dart-mcp.analyze_files` / `fvm dart analyze` → zero warnings/infos; `fvm dart
  format .` clean.
- Pure resolver at **100% line coverage**; property tests carry `tags: 'glados'`.
- Handler tests prove order-independent convergence on the concurrent branch and
  prove the non-concurrent branches are unchanged.
- ADR 0018 rule 5 wording reconciled with the chosen tiebreak (one-line note if
  Option A).
- `agent_repository`/sync README updated to describe the concurrent-resolution
  rule (it currently documents only `insertOnConflictUpdate` arrival-order).

## Risks & deferred (explicitly out of scope)

- **LWW is lossy for cumulative fields — and `AgentStateEntity` bundles
  counters.** The resolver picks a whole-row winner and discards the loser
  entirely, so `wakeCounter` / `processedCounterByHost` / `toolCounterByKey`
  lose the losing side's increments when two devices update one agent's state
  concurrently. The deterministic tiebreak does **not** fix this — a loser is
  still a loser; it only makes *which* side loses agree across replicas. The
  lease (PR 7) makes that row effectively single-writer per agent, so this is a
  partition/split-brain edge case, but "rare" is not "safe." The correct fix is
  to **derive counters from the log** (count the wake/tool events) or use a
  **counter-CRDT** — classified in PR 4 (derived vs runtime-local vs counter)
  and the §11 / PR 10 counter flag. Until then PR 2 converges the row
  deterministically but is **convergent-but-lossy** for its counter fields, and
  this must not be read as "nothing is lost."
- **Clock skew on the LWW primary (ADR rule 6).** A later concurrent write wins
  by wall-clock `updatedAt` even when it "shouldn't"; the equal-timestamp
  tiebreak never fires for it. Bounding this needs an HLC / bounded-drift
  comparator — deferred, only if skew bites in practice.
- **Append-only concurrent collisions** (`message`/`payload`): two different
  contents under one id are anomalous; `createdAt` fallback keeps resolution
  deterministic, but the real fix is content-addressing (PR 6).
- **No conflict row for agent derived state.** Unlike journal entries (which
  raise a user-facing `Conflict`), agent-derived state is designed to converge
  silently (ADR 0016 / 0018 rule 1). PR 2 deliberately keeps the
  converge-silently path; it does not add a conflict UI.

## Follow-on

- PR 3/PR 4 move *reads* onto the PR-1 projection; PR 2's hardened LWW keeps the
  *mutable-row* path convergent in the meantime, so nothing diverges before the
  projection takes over.
- If Option B is later adopted, the `originatingHostId` column also feeds PR 3's
  production `AgentEvent.hostId` sourcing (the open item flagged in the kernel
  plan).
