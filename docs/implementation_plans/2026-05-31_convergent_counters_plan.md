# Convergent agent-state counters (per-host G-counters) — Implementation Plan (PR 2b)

- Status: Plan · Date: 2026-05-31
- Part of: [`2026-05-30_daily_os_runtime_implementation_roadmap.md`](./2026-05-30_daily_os_runtime_implementation_roadmap.md) (PR 2b).
- Design baseline: [ADR 0018](../adr/0018-convergent-multi-device-execution.md) (convergence); roadmap §10 PR 2b.
- Depends on: **PR 2** (extends the concurrent-resolution path with a per-field merge). Independent of PR 1 / PR 3. Unblocks **PR 4**'s counter story (the monotonic counters have no synced event source, so count-from-log can't cover them).

## Goal

Make the cumulative agent-state counters converge to the **exact** total across
devices, even under partition. PR 2's deterministic tiebreak converges but is
**lossy on counters** — it picks a whole-row winner and discards the loser's
increments. Turn the monotonic counters into **per-host G-counters** (grow-only
CRDTs): `Map<hostId,int>`, value = sum of entries, merge = element-wise max. No
lost increments, ever.

## Scope — exactly which counters (and why)

Grounded against the code, not the roadmap's sketch:

| Field | Where | Increment sites | Decision |
| --- | --- | --- | --- |
| `wakeCounter` | `AgentStateEntity` | **5** (task/project×2/improver/day workflows) | → **G-counter** |
| `slots.totalSessionsCompleted` | `AgentSlots` (`int?`) | **1** (`improver_agent_service.dart`) | → **G-counter** |
| `slots.weeklyReviewCount` | `AgentSlots` (`int?`) | **0** — declared, never written | → **G-counter** (convert now — decided) |
| `consecutiveFailureCount` | `AgentStateEntity` | 3 inc / 3 reset | **stays LWW** — resets on success → not grow-only |
| `toolCounterByKey` | `AgentStateEntity` | 1 (rate-limit, date-pruned) | **defer** — count-from-log (PR 4) |
| `processedCounterByHost` | `AgentStateEntity` | (sequence bookkeeping) | **don't touch** — PR 4 demotes it to the sequence-log layer |

**Decided:** `weeklyReviewCount` has no increment site yet, but we convert it now
alongside the others so it is a G-counter the moment it's wired up — no second
shape migration later. Its increment site is added when the feature lands.

Net target: **three fields** — `wakeCounter`, `totalSessionsCompleted`,
`weeklyReviewCount`.

## What we confirmed about the ground truth

- **No DB schema migration.** `AgentStateEntity` is a `serialized` JSON blob in
  `agent_entities` (`agent_db_conversions.dart:66`). Changing a field's *shape*
  is data, handled on read — there is an exact precedent: `_migrateReportContent`
  (`agent_db_conversions.dart:72-91`) rewrites a legacy `Map` `content` to a
  `String` *inside `fromEntityRow` before freezed deserialization*. The G-counter
  migration uses the same hook.
- **`fromJson` already tolerates missing fields** (`@Default` + `??`), so a row
  written by an old device (plain `int`) and a row written by a new device
  (`{host:int}`) both decode — once the migration fixup runs first.
- **`VectorClock.merge`** (`vector_clock.dart:84-103`) is `static merge(VectorClock?, VectorClock?)`,
  element-wise max over the inner `Map<String,int>`. The G-counter merge is the
  *same operation*; we extract the shared `Map<String,int>` element-wise-max
  helper so both call it (DRY) rather than duplicating the loop.
- **The merge seam.** `resolveConcurrent` (`agent_concurrent_resolver.dart:40-55`)
  only sees vector clocks + `updatedAt` and returns a whole-row winner — it has
  no entities to merge. The per-field merge therefore lives one level up, in the
  sync apply handler `_localAgentPayloadDominates` /
  `_applyAgentEntityMessage` (`sync_event_processor_agent_handlers.dart`), where
  both the local and incoming entities are in hand.

## Design

### 1. A `GCounter` value type (not a raw `Map`)

`lib/features/sync/g_counter.dart` — a small immutable CRDT primitive sitting
beside `VectorClock`:

- storage: `Map<String,int> byHost` (non-negative);
- `int get value => byHost.values.fold(0, (a, b) => a + b)` (the total);
- `GCounter increment(String host, [int by = 1])` — bump one host's entry;
- `GCounter merge(GCounter other)` — element-wise max (shared helper with `VectorClock`);
- `const GCounter.empty()`, value equality (Equatable/freezed);
- JSON: serialized as its `byHost` map via a `GCounterConverter` (so freezed
  fields round-trip cleanly).

**Why a type, not `Map<String,int>` + helpers:** retyping `int wakeCounter →
GCounter wakeCounter` makes the **compiler enumerate every read/write site** —
no read can silently treat the map as a scalar. `value` is the only way to get a
number out. This is the safety net for the ~5 increment sites *and* any display
/ log readers.

### 2. Field retyping + the increment sites

- `AgentStateEntity.wakeCounter`: `@Default(0) int` → `@Default(GCounter.empty()) GCounter`.
- `AgentSlots.totalSessionsCompleted`: `int?` → `@Default(GCounter.empty()) GCounter`
  (drop the nullable; empty ≡ zero).
- Increment sites change `state.wakeCounter + 1` → `state.wakeCounter.increment(host)`.
  The local host comes from `VectorClockService`; expose a **non-null**
  `Future<String> AgentSyncService.localHost()` passthrough (the workflows hold
  `syncService`, not the clock service directly — avoids reaching into a private
  field). Reset sites (`consecutiveFailureCount: 0`, creation `…: 0`) become
  `GCounter.empty()` where they touch a converted field; `consecutiveFailureCount`
  itself is untouched.
- Read sites (display/logging that printed the int) call `.value`.

### 3. The convergent merge (concurrent branch only)

In the sync apply handler (`_applyAgentEntityMessage` → `_mergeConcurrentAgentState`),
when the incoming entity is an `AgentStateEntity` **and** the vclock relation is
`concurrent`:

- non-counter fields: the existing `resolveConcurrent` winner (unchanged);
- counter fields: `local.X.merge(incoming.X)` element-wise for all three counters;
- **the winner's vector clock is kept** — a future update that causally dominates
  it necessarily saw, and (since every replica applies the same deterministic
  merge symmetrically) merged, both sides, so its counters are a superset and a
  later `b_gt_a` whole-row overwrite loses nothing;
- upsert the **merged** entity (fromSync) — but **only when the merge actually
  recovers a counter the winner lacked** (`merged != winner`). When the winner
  already carries the joined counters, defer to the standard whole-row path
  (keep-local / apply-incoming): correct, behaviour-compatible with the existing
  non-counter concurrent resolution, and avoids a redundant write.

`a_gt_b` / `equal` (keep local) and `b_gt_a` (take incoming) are **unchanged**:
VC dominance means the dominant side has causally seen the other, so its counters
already include the other's — element-wise max there would be a no-op. Scoping
the merge to `concurrent` keeps the change minimal and matches the roadmap. An
invalid clock (a `VclockException` from `compare`) yields `null`, so the standard
path logs and falls through exactly as before.

A pure `mergeAgentStateCounters({winner, local, incoming}) → AgentStateEntity`
(in `agent_concurrent_resolver.dart`, beside `resolveConcurrent`) holds the
field-merge logic so it's unit/property-testable without the handler.

### 4. Dual-write serialization + migration (decided: dual-write for one release)

Each G-counter serializes under a **new** JSON key (`wakeCounterByHost`,
`totalSessionsCompletedByHost`, `weeklyReviewCountByHost`), while the **legacy
scalar key** (`wakeCounter`, …) is kept as a **mirror = `.value`** for one
release — so a not-yet-updated device keeps reading a sane integer instead of
casting a map to `int` and throwing. The in-memory model has a single field (the
`GCounter`); the dual key lives entirely in the conversion layer
(`agent_db_conversions.dart`), symmetric to `_migrateReportContent`:

- **Field mapping.** The freezed field keeps its name (`wakeCounter`, so
  increment sites stay `state.wakeCounter.increment(host)`) but serializes under
  `@JsonKey(name: 'wakeCounterByHost')`.
- **Read fixup `_migrateGCounters(json)`** (before freezed `fromJson`, in
  `fromEntityRow`; descends into `slots`): if the `*ByHost` key is absent but the
  legacy scalar key holds a **number** `n` → set `*ByHost = {<sentinel>: n}`;
  absent/null → `{}`. So both legacy rows and old-client writes fold into the
  G-counter on read.
- **Write fixup `_addLegacyCounterMirrors(json)`** (after freezed `toJson`, in
  `toEntityCompanion`): inject each legacy scalar key = `gcounter.value` (int).
  Every new-client write therefore carries **both** shapes.

**Sentinel host (the overcount trap).** The legacy scalar seeds under a single
fixed host string (e.g. `'__pre_gcounter__'`), identical on every device — **not**
the local host. `wakeCounter` was one synced int that LWW-converged to a value
`n` on all devices; per-device-local seeding (`{localHost: n}` ×N) would
element-wise-max-merge to `N·n` (overcount). One shared key makes the merge
`max(n, …) = n`; forward per-host increments are never lost. (Pre-migration
history was already LWW-lossy; "preserve the largest value seen" is the honest
floor, which `max` gives.)

**Mixed-version window.** While an *old* client still writes, its `toJson` emits
only the scalar and **drops** the `*ByHost` map; a new client re-seeds the map
from that scalar on read. So the per-host breakdown collapses to the scalar sum
on each old-client write (no data lost — the sum is preserved and re-seeded), and
full per-host convergence resumes once every device is updated. **The release
after this one drops the legacy mirror keys.**

## Risks & migration

- **R1 — Overcount on naive seeding** (the trap above). Mitigated by the shared
  sentinel host. A Glados test asserts: N devices each migrating the same legacy
  `n`, then merging, yields value `n` (not `N·n`).
- **R2 — Mixed-version sync during rollout — RESOLVED: dual-write.** A
  new-format map reaching an old client would break its `int` `fromJson`
  (`(json['wakeCounter'] as num?)` throws on a map). Chosen mitigation: dual-write
  the legacy scalar mirror for one release (design §4), so old clients keep
  reading the int and never throw; the per-host breakdown is suspended (not lost)
  on old-client writes and resumes once all devices update. The mirror keys are
  dropped the release after.
- **R3 — `processedCounterByHost` is already a map but stays LWW.** Don't fold it
  into this work; PR 4 moves it to the sequence layer. Leaving it avoids a
  pointless migration of a field that's about to relocate.
- **R4 — Read-site coverage.** The retype forces the compiler to flag every read;
  CI analyzer is the safety net. No silent scalar reads survive.

## Test plan

- **`GCounter` (pure, Glados — `tags: 'glados'`):** merge is commutative,
  associative, **idempotent**; `value == sum(byHost)`; `merge` is a least-upper-
  bound (`value(merge(a,b)) ≥ value(a)` and `≥ value(b)`); **no-lost-increments**:
  a set of per-host increment sequences applied/merged in any order/grouping
  converges to the exact total (the core CRDT property); JSON round-trip.
- **`mergeAgentStateCounters` (pure):** counters merged element-wise-max,
  non-counter fields taken from the supplied winner, other fields untouched.
- **Migration + dual-write (example + Glados):** legacy `int n` → `{sentinel:n}`;
  absent/null → `{}`; N-device same-`n` migrate+merge → `n` (R1, the overcount
  trap); already-migrated map is a no-op (idempotent fixup). Round-trip: a
  new-client write carries **both** the `*ByHost` map and the legacy scalar mirror
  (= `.value`); an old-client-shaped JSON (scalar only) reads into the seeded
  G-counter; when the map key is present the scalar mirror is ignored on read.
- **Sync apply (handler, deterministic example):** two concurrent
  `AgentStateEntity` versions with disjoint host increments → applied result has
  the summed counters and the LWW winner's non-counter fields; `a_gt_b`/`b_gt_a`
  paths unchanged (no spurious merge/upsert).
- **Partition+heal simulation (the roadmap's "Done when"):** drive per-device
  increments through a partition, then merge; assert every device's counter
  equals the true sum and non-counter fields are unaffected.

## Acceptance criteria

- Analyzer/format clean; `GCounter` + migration + merge property-tested with `tags: 'glados'`.
- `wakeCounter` and `totalSessionsCompleted` are per-host G-counters; the
  `+ 1` read-modify-write pattern is gone at all sites.
- Partition+heal sim: each counter equals the true sum on every device (no lost
  increments); non-counter fields converge exactly as before (LWW + PR 2 tiebreak).
- Legacy rows migrate without overcount; every write carries both the `*ByHost`
  map and the legacy scalar mirror, so old/scalar-only clients read without throwing.
- No DB schema migration (serialized JSON + in-band read fixup, like `_migrateReportContent`).

## Decisions (resolved)

- **R2 mixed-version rollout — DECIDED: dual-write for one release** (see §4 + R2).
  Old clients keep reading the legacy scalar mirror; mirror keys are dropped the
  release after.
- **`GCounter` location — DECIDED: `lib/features/sync/`** (beside `VectorClock`;
  the shared element-wise-max helper lives there).
- **`weeklyReviewCount` — DECIDED: convert now**, alongside the others, so it is a
  G-counter the moment it's wired up — no second shape migration later.
