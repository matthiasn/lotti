# State-as-Projection (Move 1) — Implementation Plan (PR 4)

- Status: In progress — **B1 + B2 + B3 landed** (milestone marker model + emission; `agentDay` slot link) plus the end-of-wake head-clobber fix; B4–B6 pending. Refreshed against merged PR 1/2/2b/3 · Date: 2026-06-01
- Part of: [`2026-05-30_daily_os_runtime_implementation_roadmap.md`](./2026-05-30_daily_os_runtime_implementation_roadmap.md) (PR 4).
- Design baseline: [`../daily_os_ai_runtime_architecture.md`](../daily_os_ai_runtime_architecture.md) §2 / §4 (Move 1); [ADR 0016](../adr/0016-agent-state-as-log-projection.md). Companion: [ADR 0020](../adr/0020-agent-input-capture.md) extends the same projection thesis to the agent's *inputs* (per-source content-addressed capture of user content) — this plan covers derived *state*, ADR 0020 covers what the agent reads.
- Depends on (**all merged → PR 4 is unblocked**):
  - **PR 1** (projection kernel) — `canonicalOrder` + `project()` + `AgentProjection`.
  - **PR 2** (#3243: deterministic concurrent resolution) — the resolver PR 4 demotes to a transient-cache role.
  - **PR 2b** (#3251: per-host G-counters) — the monotonic counters already converge exactly; PR 4 reads their sum. *(Known deferred item: the G-counter dual-write isn't on the sync wire yet — see that plan's open item. It is local-DB-correct, so PR 4's reads are unaffected; cross-device counter propagation closes when the wire dual-write lands.)*
  - **PR 3** (#3249: `messagePrev` edges + shadow projection) — the real causal DAG, head maintenance (`recentHeadMessageId` is now actually written), and `compareShadowProjection`, which PR 4 promotes from a test/diagnostic into the read path once equivalence holds.

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

## Increments (re-scoped 2026-06-01 per grounding — option B)

A field-by-field survey of the current write sites showed agent state is only
**partially event-sourced**: `active{Task,Project,Template}Id` are backed by synced
links and `awaitingContent` by message presence, but `activeDayId` and the
ritual/review **watermarks** have **no backing synced event**, and `AgentEvent`
carries **no timestamp** and only coarse kinds. So the convergence-critical
derivations (the watermarks — the "missed/double weekly review under partition"
case) require **net-new events first**. PR 4 is therefore sequenced
event-sourcing-completeness → fold → flip, and scoped to the fields that *earn*
derivation; already-convergent and runtime-local fields stay as the cache.

**Where the derivation lives (architecture).** The kernel
(`project(canonicalOrder(events))`) stays the *minimal causal view* — heads + latest
report. The full state is a **storage-coupled composite**,
`deriveAgentState(messages, links, counters)` (alongside `compareShadowProjection`),
that calls the kernel for the structural part and aggregates the *order-independent*
fields directly off the messages/links: watermarks = `max(createdAt)` per milestone,
slots from association links, the gate from message presence; counter sums from the
PR 2b G-counters. The kernel and `AgentEvent` are **not** enriched with
derivation-specific data — those aggregates don't need canonical ordering.

1. **B1 — Milestone marker on message metadata. ✅ done.** Added the `AgentMilestone`
   enum (`wakeCompleted` / `oneOnOneCompleted` / `feedbackScanCompleted` /
   `dailyWakeCompleted` / `weeklyReviewCompleted` — one per derived watermark) and a
   nullable `AgentMessageMetadata.milestone` so a completion event can be tagged. Model
   + codegen + serialization tests only; nothing sets it yet → no behaviour change. The
   field is `@JsonKey(unknownEnumValue: nullForUndefinedEnumValue)` so a milestone an
   older client doesn't recognise decays to `null` instead of throwing. This **settles
   the marker mechanism** for B2: the marker is `metadata.milestone`, *not* a new
   `AgentMessageKind` — so the kernel/`AgentEvent` stay unenriched and the adapter is
   untouched. (Watermarks fold from `metadata.milestone` + `message.createdAt`, read
   directly in B5 — not via `AgentEvent`.)
2. **B2 — Event-source the convergence-critical watermarks. ✅ done.** Added
   `AgentSyncService.appendMilestone(...)` (a DRY helper that emits a `system`
   message tagged with `metadata.milestone`, routed through the normal append path;
   `threadId` defaults to the marker's own id for the thread-less paths). Wired it
   *after every watermark write*, alongside the still-authoritative cached row
   (dual-write — reads don't flip until B6):
   - `lastWakeAt` → `wakeCompleted`: task wake, day wake, project full wake, **and**
     the project dormant-skip path.
   - `slots.lastDailyWakeAt` → `dailyWakeCompleted`: project full wake when the
     scheduled daily wake was due (in addition to `wakeCompleted`).
   - `slots.lastFeedbackScanAt` → `feedbackScanCompleted`: improver workflow, both the
     insufficient-feedback skip and the ritual-started success paths.
   - `slots.lastOneOnOneAt` → `oneOnOneCompleted`: `ImproverAgentService.scheduleNextRitual`.
   - `weeklyReviewCompleted` has no emit site yet (the weekly-review feature is still
     unimplemented — `lastWeeklyReviewAt` is never written), so the enum value is
     reserved but dormant.

   The watermarks become `max(createdAt)` of messages carrying the matching milestone;
   B5 folds them. (Marker mechanism settled in B1 — `metadata.milestone`, mapped to no
   distinct `AgentEventKind`.)
3. **B3 — `agentDay` link. ✅ done.** Added the `AgentLink.agentDay` variant
   (`fromId` = agent, `toId` = day), the `agent_day` type constant, both DB-conversion
   directions, and the soft-delete case; `DayAgentService.createDayAgent` now emits the
   link (`fromId: agentId, toId: dayId`) alongside the `activeDayId` slot — so
   `activeDayId` joins the other three slots as link-derived. Dual-write: the slot stays
   the read source until B6 (the day-agent lookup can later move off the JSON slot).
4. **B4 — Field-classification cleanup (additive).** Re-home *config* fields
   (`feedbackWindowDays`, `recursionDepth`) to `AgentConfig`/identity; stop syncing
   *runtime-local* scheduling (`nextWakeAt`, `sleepUntil`, `scheduledWakeAt`); retire
   `revision` (display-only, never read for logic). In-band-on-read migration (PR 2b/3
   pattern — no schema change).
5. **B5 — Grow `AgentProjection` + fold (shadow-only).** Fold the watermarks (B2
   events), the active slots (links incl. `agentDay`), and the `awaitingContent` gate;
   read the counter *sums* from the PR 2b G-counters. Extend `compareShadowProjection`
   to assert the **full** derived state across the forward corpus. Still drives no read.
6. **B6 — Flip reads (the cutover).** Workflows + `agent_repository` read derived state
   through the reconciled cache (reconcile machinery per the strategy above);
   `AgentStateEntity` demoted to that cache. Convergence sim (partition + heal).

**Left as-is (not derived):** `toolCounterByKey` (date-scoped runtime-local
rate-limit; the `toolEffect` link type exists but is unused — event-sourcing it is out
of scope), `consecutiveFailureCount` (resets on success → best-effort LWW),
`pendingProjectActivityAt` (external activity, not a log event — stays cache),
`processedCounterByHost` (sequence layer). The monotonic counters are already
convergent G-counters (PR 2b); PR 4 only reads their sum.

Only **B6** changes runtime reads, and only after **B5** proves full-state equivalence
in shadow. B1–B5 are each shippable green on their own.

## Test plan

- **Shadow → live cutover:** PR 3's `compareShadowProjection` already proves the
  *head* matches live state; increment 1 extends it to assert the **full** derived
  state matches across the forward corpus, and PR 4 flips reads only after that holds.
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
- **Slots event-sourcing completeness** — confirmed *during increment 1*: every
  slot mutation must already have a backing log event/link to be foldable; any that
  doesn't gets a net-new event before its field can be reclassified as derived.
- **`frontierDigest` definition** — settled in increment 3; share the exact form
  with PR 5 (compaction reuses it).
- **`revision`** — derive from the frontier, or retire it in favor of the vector clock
  / head-set.
- **End-of-wake state write clobbered `recentHeadMessageId`** *(found during B2;
  ✅ fixed)*. Every workflow captures `state` (task: once up front; project / day: a
  `latestState` re-read at transaction start) **before** appending the wake's messages,
  then writes `state.copyWith(lastWakeAt: …)` at the end. The repository upsert is a
  full-row `insertOnConflictUpdate`, so that final write reset `recentHeadMessageId` to
  its pre-wake value — even though `_appendMessage` advanced it for each message. Net
  effect: the *live head pointer* was stale by a wake and the `messagePrev` DAG forked at
  every wake boundary (the next wake's first message chained off the pre-wake head, not
  the actual tip). B2 was unaffected (the watermark fold scans messages by
  `metadata.milestone`, never via the head), but B6's read-flip relies on a correct head /
  reconciled projection. **Fix:** `AgentSyncService.upsertEntity` now routes local
  (`!fromSync`) `AgentStateEntity` writes through `_upsertAgentStatePreservingHead`, which
  overlays the persisted (read-your-writes inside the wake transaction) head onto the
  write — so only `_appendMessage` (which writes via `_upsertEntityRaw`, bypassing this)
  ever moves the head, and sync-received state keeps its resolver-merged head. Covered by a
  glados property test over `(persisted-head, caller-head)` combinations plus a `fromSync`
  example. (The PR 3 append-path shadow test exercised raw appends, not the workflow
  end-of-wake write, so it didn't catch this.)
