# State-as-Projection (Move 1) — Implementation Plan (PR 4)

- Status: Plan · Date: 2026-05-30
- Part of: [`2026-05-30_daily_os_runtime_implementation_roadmap.md`](./2026-05-30_daily_os_runtime_implementation_roadmap.md) (PR 4).
- Design baseline: [`../daily_os_ai_runtime_architecture.md`](../daily_os_ai_runtime_architecture.md) §2 / §4 (Move 1); [ADR 0016](../adr/0016-agent-state-as-log-projection.md). Companion: [ADR 0020](../adr/0020-agent-input-capture.md) extends the same projection thesis to the agent's *inputs* (per-source content-addressed capture of user content) — this plan covers derived *state*, ADR 0020 covers what the agent reads.
- Depends on: **PR 3** (`messagePrev` wiring + shadow projection — equivalence must be proven before reads flip). Builds on **PR 1** (the projection kernel) and resolves a limitation carried from **PR 2** (counter-loss under LWW).

## Goal

Flip agent-state **reads** onto the projection of the append-only log, and demote
`AgentStateEntity` from an authoritative mutable row to a **regenerable cache**.
After this, the log is the single source of truth and per-device state is a
deterministic fold of it.

## The model (this is the load-bearing decision)

- **The append-only log (events + `AgentLink` edges) is authoritative.** It already
  converges by set-union + the canonical fold (PR 1) — no LWW, nothing lost.
- **`AgentStateEntity` stays synced, as a *regenerable cache* — we do NOT stop
  syncing it.** Keeping it on the wire is a deliberate optimization:
  - **cold-start from artifacts** — a fresh or long-offline device shows "agent is
    on task Y, 14 wakes, last woke Z" immediately, instead of backfilling and
    folding the whole log before it can render anything;
  - **cheap reads** without re-folding on every access;
  - **usable on a partial log** — a device mid-backfill still has a usable snapshot.
- **The cache is reconciled against the projection** (below); the log wins on any
  disagreement.
- **Consequence — LWW becomes self-healing, not a correctness mechanism.** Once the
  cached row is a pure function of a convergent log, it does not matter how two
  devices merge the row on sync: the next fold recomputes the same value on both, so
  a "wrong" LWW outcome is transiently stale, then corrected. PR 2's deterministic
  resolver stays (it picks a sane transient value) but stops being load-bearing —
  divergence can no longer *persist*.

## Field classification (the concrete PR 4 input)

`AgentStateEntity` + `AgentSlots` are overwhelmingly a denormalized cache of things
already in the log. Each field is one of:

| Field(s) | Class | Going-forward source |
| --- | --- | --- |
| `recentHeadMessageId` | derived | kernel `headIds` |
| `latestSummaryMessageId` | derived | active checkpoint (PR 5) |
| `revision` | derived | function of the log frontier (or retire) |
| `slots.active{Task,Day,Project,Template}Id` | derived | the agent's `AgentLink` edges (`agentTask`/`agentProject`/…) — already log events |
| `lastWakeAt`, `slots.last{OneOnOne,FeedbackScan,DailyWake,WeeklyReview}At`, "most recent unreflected activity" | derived | timestamp of the last corresponding event |
| `wakeCounter`, `slots.totalSessionsCompleted`, `slots.weeklyReviewCount` | **per-host G-counter (PR 2b)** | `Map<hostId,int>`, value = sum, merge = element-wise max (`VectorClock.merge`); exact + convergent even under partition, no lost increments. PR 4 just reads the sum. |
| `toolCounterByKey` | **count-from-log** | count synced `toolEffect` links (`agent_links`) per key — correct + convergent (nested per-host G-counter only if that proves insufficient) |
| `consecutiveFailureCount` | **best-effort / LWW** | *resets* on success → not grow-only and ill-defined across a partition; left as a synced LWW field (drives backoff heuristics only) |
| `nextWakeAt`, `sleepUntil`, `scheduledWakeAt` | runtime-local | device-local scheduling — **do not sync** (each device schedules itself; the lease, PR 7, coordinates who executes) |
| `slots.feedbackWindowDays`, `slots.recursionDepth` | config | re-home to `AgentConfig` / identity — not mutable state |
| `processedCounterByHost` | sequence bookkeeping | sequence-log / sync layer, not agent state |
| `awaitingContent` | derived gate | "has the first meaningful content/wake arrived?" |

**Counters converge by mechanism, resolving PR 2's counter-loss limitation:**
the monotonic counters (`wakeCounter`, session/review counts) become **per-host
G-counters** (PR 2b) — `Map<hostId,int>` summed and merged by element-wise max — so
they converge to the *exact* total even under partition, with no lost increments;
`toolCounterByKey` is counted from synced `toolEffect` links; `consecutiveFailureCount`
stays best-effort. (An earlier draft proposed count-from-log for the monotonic
counters, but their source — `wake_run_log` — is **device-local**, so counting it
diverges. The G-counter needs no synced source and reuses the vector-clock merge
primitive, so it supersedes that approach.)

## Reconciliation strategy (when to refold the cache)

"Reconcile" = re-run the projection fold from the log and replace the cached row.
Drift happens when new events land (local wake or sync) or when a stale/clobbered
cache row syncs in.

- **Lazy-on-read, gated by a cheap frontier check.** Store the head-set digest
  (`frontierDigest`, shared with PR 5) the cache was folded from. On read: compare to
  the log's current heads — equal ⇒ trust the cache (O(1)); different ⇒ refold. So
  "lazy" means "refold only when the head-set moved," not "refold every read."
- **Strict, non-optional reconcile at wake start.** The wake is the read that must be
  correct — acting on stale state risks wrong decisions or duplicate side effects.
  This pairs with acquiring the PR 7 lease: make state authoritative right before the
  device is allowed to act.
- **Coalesced background refold on log change** (debounced per sync batch, never
  per-event) keeps the cache usually-warm without backfill thrash.
- **UI reads are eventual** — transient staleness is fine and self-heals.
- **Cost is bounded:** a full fold is O(log size) today but O(`summary + recent tail`)
  once compaction (PR 5) caps the working set — cheap enough for the wake critical
  path.

## Why this improves the actual agents (task / project / improver)

Not just plumbing — the long-lived agents benefit most:

- **Identical resume on any device.** A task agent reconstructs the same working state
  from the log instead of one device clobbering another's snapshot. Project agents
  (daily/weekly cadence) and improver agents (weekly one-on-ones) hold watermarks and
  session counts over weeks — today the fields most at risk of LWW loss (a *missed or
  double* weekly review under partition). Count-from-log makes
  `totalSessionsCompleted` / `weeklyReviewCount` exact.
- **Long-horizon memory plugs in** (PR 5): the summary pointer becomes part of the
  fold, giving long-running agents bounded context + replay-from-summary.
- **Safe iteration:** change how a derived field is computed (or fix a counting bug)
  and just replay — no mutable-row migration, no corrupting persisted state.
- **Substrate for the executive-assistant features** (planner / phases / outcomes,
  PR 8–10): all new event/edge types folded by the same projection; this is what makes
  them converge across devices.

## Touches

- `agent_projection.dart` — grow `project()`/`AgentProjection` from PR 1's minimal
  fold (heads, latest report) to the full derived state above (pointers, watermarks,
  log-derived counters, gate).
- `agent_repository` reads + state resolution in `task_agent_workflow` /
  `project_agent_workflow` / `improver_agent_workflow` — read the projection;
  reconcile per the strategy above; stop the read-modify-write `wakeCounter + 1`
  pattern.
- Re-home config fields (`feedbackWindowDays`, `recursionDepth`) to `AgentConfig`;
  drop runtime-local scheduling fields from the synced payload.

## Test plan

- **Shadow → live cutover:** PR 3 proves projection ≡ live mutable state across the
  corpus; PR 4 flips reads only after that holds.
- **Convergence sim (reused PR 1 harness):** two devices, concurrent wakes, partition +
  heal → identical derived state *and* exact counters (no lost increments) — the case
  PR 2's LWW could not guarantee.
- **Reconcile correctness:** frontier-check trusts an unchanged cache (no refold) and
  refolds when heads move; wake-start always reconciles.
- **Field-classification regression:** each derived field equals its log-derived value
  for a representative task / project / improver agent fixture.

## Done when

- Derived agent state is read from the projection; the read-modify-write
  `wakeCounter + 1` pattern is gone (monotonic counters are per-host G-counters per
  PR 2b; `toolCounterByKey` is count-from-log).
- Concurrent multi-device edits **self-heal** on agent-derived state (sim test), and
  counters are exact across a partition+heal.
- `AgentStateEntity` is demoted to a reconciled cache; PR 2's resolver is demonstrably
  reduced to a transient-cache role.

## Defers

- **Removing the cache row entirely** — optional, later; the cache earns its keep for
  cold-start.
- **Compaction** (PR 5) — `frontierDigest` and bounded working set land there; PR 4's
  reconcile uses a head-set digest in the interim.
- **Counter-CRDT** — the monotonic counters *are* per-host G-counters, delivered in
  **PR 2b** (sibling of PR 2); PR 4 only reads their sum. `consecutiveFailureCount`
  stays best-effort.

## Open decisions

- **Who reads agent state besides the wake path?** Determines whether the coalesced
  background refold is worth it or whether wake-time strict reconcile + lazy UI reads
  suffice. (Quick reader survey at PR 4 kickoff.)
- **Slots event-sourcing completeness** — confirm every slot mutation already has a
  backing log event/link; net-new events for any that don't.
- **`frontierDigest` definition** — settle here vs. share the exact form with PR 5.
- **`revision`** — derive from the frontier, or retire it in favor of the vector clock
  / head-set.
