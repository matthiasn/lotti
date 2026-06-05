# Join-by-Continuation (Fork Healing) — Implementation Plan (PR 6)

- Status: **Implemented (flag-gated default-off), J1–J5 done** · Date: 2026-06-02
- Part of: [`2026-05-30_daily_os_runtime_implementation_roadmap.md`](./2026-05-30_daily_os_runtime_implementation_roadmap.md) (PR 6).
- Design baseline: [ADR 0018](../adr/0018-convergent-multi-device-execution.md) **rule 7–8** (forks are legal and multi-head tolerant; heal by lazy, capped, content-addressed join-by-continuation) and [ADR 0016](../adr/0016-agent-state-as-log-projection.md) (the DAG projection). Companion already-built: PR 3 (`messagePrev` DAG + head maintenance), PR 1 (projection kernel — already multi-head and multi-parent tolerant).
- Depends on (**all merged → PR 6 is unblocked**):
  - **PR 1** (#kernel) — `canonicalOrder` + `project()` already detect heads (`AgentProjection.headIds`) and tolerate ≥2 parents (`AgentEvent.causalParents` is a sorted-unique *set*).
  - **PR 3** (#3249) — `messagePrev` edges are populated and `recentHeadMessageId` is maintained by `AgentSyncService._appendMessage`; the storage→event adapter (`agentEventsFromLog`) already folds multi-parent edges into `causalParents`.
  - **PR 5** (#3257) — `ContentDigest.of(json)` (`sha256-v1:<base64url>`, canonical JSON) is available to mint the content-addressed join id.

## Goal

When two devices wake the same agent from a shared prefix they create a DAG
**fork** — concurrent `messagePrev` children of one parent (ADR 0016). This is
**legal and already converges**: `project()` returns both tips in `headIds` and
context assembly reads across all heads in the canonical linear extension, so no
device is wrong. But an unhealed fork means the on-device prefix never re-warms
(each branch is a distinct prefix) and context assembly fans out across an
ever-widening head set.

PR 6 **heals the fork**: emit a **join-by-continuation** node — a single
continuation message that links (`messagePrev`) to *all* current heads, so the
DAG re-converges to one head and the prefix re-warms. The join is **content-addressed**
so two devices emitting it concurrently write the *same* log entry, which
set-union merges into one node (no join storm). Per ADR 0018 rule 8 this is **an
optimization, never a correctness mechanism** — correctness already holds via the
multi-head projection.

## The model (the load-bearing decisions)

Straight from ADR 0018 rule 8, made concrete against the current code:

1. **A join is a `system` `AgentMessageEntity` with ≥2 `messagePrev` parents.**
   It flows through the projection unchanged: `agentEventsFromLog` already
   collects every `MessagePrevLink.toId` for a child into `causalParents`, and
   `AgentEvent` normalizes them to a sorted-unique set. The kernel then drops all
   joined heads out of `headIds` (they are now referenced as parents) and the
   join becomes the single head.
2. **The join id is content-addressed and domain-tagged**, distinct from the
   summary coverage `frontierDigest` so the two uses can never collide:
   `joinId = ContentDigest.of({'_tag': 'join-v1', 'parents': sortedHeadIds})`.
   Two devices over the same head set compute a byte-identical id → the DB
   (`insertOnConflictUpdate`, keyed by id) merges them into one row.
   **Convergence caveat (red-team J1):** the content-address dedupes only an
   *identical* parent set. Two devices with *different* head-set views (a
   fully-disjoint third branch one hasn't synced) heal different supersets and
   briefly *multiply* the fork; this self-corrects — the resulting join heads
   form a smaller fork the next cycle heals — converging in O(branches) bounded
   rounds, never storming (join ids are monotone children of a strictly-growing
   parent set, so a join can never re-create an existing ancestor). The
   completeness gate plus the pending-join guard (rule 5) remove the common
   "join node synced before its edges" trigger; the disjoint-branch residue is
   accepted as bounded self-healing, not a correctness risk (ADR 0018: the join
   is an optimization, never correctness).
3. **The join structure is deterministic — no wall-clock, `hostId`, or vector
   clock in the content-addressed identity.** Structure = the fixed `system`
   kind, `threadId == joinId`, empty metadata, and the sorted parent-head id set
   materialized as `messagePrev` edges. Everything device-specific (`createdAt`,
   `vectorClock`, authoring `hostId`) lives in the **sync envelope**, which the
   projection never folds into identity.
4. **Per-parent `messagePrev` link ids are also content-addressed.** The current
   single-parent scheme `msgprev-${childId}` cannot represent *n* edges from one
   child, and two devices must mint identical edge ids to set-union them. PR 6
   uses `msgprev-${joinId}-${parentId}` for join edges (one per parent), keeping
   the existing `msgprev-${childId}` scheme for ordinary single-parent messages.
5. **Emit for any fork observed at wake start over a settled view** (rule 8:
   "≥2 heads survive past one wake cycle"). The pure `planJoin` gates on two
   conditions only:
   - **≥2 heads** (a single head is no fork); and
   - **the local view is complete** — `projection.danglingParentIds.isEmpty`; and
   - no **pending join head** exists. A join node can sync before its
     `messagePrev` edges; while that happens, the join appears as an extra
     parentless or partially-parented head. If the visible heads plus the join's
     already-arrived parents reproduce the join id, healing defers until the
     missing edges arrive instead of minting a second-order join.

   A `messagePrev` edge syncs as a message separate from its endpoint node, so a
   node can arrive before the edge that marks its child as the real tip; on that
   transient view a non-tip masquerades as a head and healing would mint a join
   over the wrong set. Defer until the view settles (red-team J1 fix).

   **No cross-wake marker / no new `AgentStateEntity` field.** An earlier draft
   gated on a persisted "head set unchanged since last wake" digest to enforce
   "survived a cycle." The red-team showed this both *starves* (a peer extending
   one branch each cycle changes the set every wake → never heals) and adds a
   synced field to the most sensitive model. It also buys nothing: forks never
   self-resolve (two concurrent branches stay forked until a join links them),
   and concurrent joins dedupe by content-address — so there is no transient
   fork to "wait out" beyond the partial-sync view, which `viewComplete` already
   covers. A fork seen at *wake start* was created by a *prior* cycle (this wake
   has appended nothing yet), so healing it is faithful to "survived past the
   cycle that created it." Eager-at-wake-start is therefore correct, non-starving,
   and stateless.
6. **The join is lazy and capped.** Lazy: emitted at wake start, not eagerly on
   every sync. Capped: at most one join per wake; the content-addressed id makes
   re-emission idempotent (a re-run finds the row present and stops — the existing
   `_appendMessage` idempotency guard), so a crash-and-retry cannot storm.
7. **Envelope reconciliation is partially resolved, with vector-clock/timestamp
   canonicalization deferred.** When the same join id arrives from two devices,
   structural fields are canonical (`threadId == joinId`, empty metadata,
   deterministic edge ids). The remaining per-device sync envelope (`createdAt`,
   vector clock) may differ. That is inert today because projection ignores the
   envelope (`hostIdOf` is unpopulated) and duplicate sync applies through the
   raw repository path without re-enqueue churn. A replica-independent envelope
   canonicalizer remains planned for the same change that starts projecting
   persisted authoring host ids.

**Why this is safe to land incrementally.** The join changes nothing the
projection reads for *correctness* (heads + folds are identical with or without
it); it only *reduces* the head count and re-warms the prefix. So the pure logic
(J1), the append mechanism (J2), and the emission hook (J3) are each shippable
green on their own, and emission can ship behind a default-off flag first (J3)
exactly as PR 5's compaction did.

## Where it lives (architecture)

- **Pure logic — `lib/features/agents/projection/join_plan.dart` (new).**
  `computeJoinId(List<String> headIds)` and `planJoin({required List<String>
  headIds, required bool viewComplete})` → `JoinPlan?` (null = no join). Pure
  functions of the head set + the `viewComplete` flag; no I/O, no clocks, no
  cross-wake state. This is where the "≥2 heads over a complete view" gate and
  the content-addressed id live, and where the Glados properties bite
  (determinism, permutation-invariance over the head set, idempotence).
- **Append mechanism — `AgentSyncService` (`agent_sync_service.dart`).** A
  dedicated `appendJoin({agentId, joinId, parentIds, at})` writes the join
  message, its *n* content-addressed `messagePrev`
  links, and advances `recentHeadMessageId` to the join — all inside one
  `runInTransaction`, reusing the existing idempotency guard and the
  `_upsertAgentStatePreservingHead` overlay so the head advance is not clobbered.
- **Emission hook — `ForkHealer` + a single orchestrator pre-wake hook.**
  `ForkHealer.maybeHealFork` reads `headIds` **and** `danglingParentIds` from a
  **full-log projection** — `project(canonicalOrder(agentEventsFromLog(messages,
  messagePrevLinks)))`. Messages come from `getAgentMessages(agentId)`; the
  `messagePrev` edges (whose `fromId` is the *child message*, not the agent) come
  from `getLinksFromMultiple(messageIds, type: messagePrev)` — batched, no N+1.
  **Not** `reconciledAgentState` (red-team J1): that load fetches only `system`
  markers + slot links, so its head set would be wrong. `recentHeadMessageId` is
  likewise just *this device's* branch tip, never the head set. When `planJoin`
  approves, `maybeHealFork` calls `appendJoin`. The four wake workflows share no
  base class, but they all dispatch through the `WakeOrchestrator`, which gains
  one optional `onWakeStart` hook fired just before the executor — so the join
  emits before the wake's own messages, in **one** seam covering all agent kinds.
  A corrupt synced log (cycle / duplicate id) is caught and skipped (non-fatal),
  exactly like `reconciledAgentState`.
- **Envelope canonicalization — partially resolved, vector-clock/timestamp
  canonicalization deferred (see J4 / open decisions).** The join row now uses
  canonical structure (`threadId == joinId`, empty metadata) and deterministic
  edge ids. A content-addressed duplicate-id message's remaining per-device sync
  envelope (VC / `createdAt`; `hostIdOf` remains unpopulated) is *not* reconciled
  in the sync apply path, because it is inert for the projection today
  (`hostId = ''`, joins immutable, no re-sync churn). It becomes load-bearing
  only if `hostIdOf` is ever populated, and must be added with that change.

The kernel (`project`/`canonicalOrder`) and the adapter (`agentEventsFromLog`)
are **not** touched — they already handle multi-parent events. This is a deliberate
check on the design: if the join needed kernel changes, it would not be "just an
event."

## Fork → heal lifecycle

```mermaid
stateDiagram-v2
  [*] --> SingleHead
  SingleHead --> Forked: two devices append off the same head (concurrent messagePrev children)
  Forked --> Forked: local view still settling (dangling parent or pending join edges) — defer
  Forked --> Joining: a wake starts and observes ≥2 heads over a complete view
  Joining --> SingleHead: append content-addressed join (messagePrev → all heads); head := joinId; prefix re-warms
  Joining --> SingleHead: peer emitted the same join id concurrently → set-union merges to one node
```

## Increments (each shippable green on its own)

1. **J1 — Pure join planning + id (no wiring). ✅ done.** New
   `projection/join_plan.dart`: `computeJoinId(headIds)` (domain-tagged
   `ContentDigest.of`) and `planJoin({headIds, viewComplete})` → `JoinPlan?`
   (`{joinId, parentIds (sorted)}`), returning null unless `headIds.length >= 2`
   **and** `viewComplete` (no dangling parents — the local DAG view has settled).
   Stateless: a pure function of the head set + that boolean, no cross-wake
   marker. Glados-tested: permutation-invariance over the head set, determinism,
   the id is stable and tag-isolated from a same-input `frontierDigest`,
   single-head/empty/dups → null, `!viewComplete` → null. Unused in production.
   *Done when:* analyze clean, Glados green.
2. **J2 — Multi-parent append path.** A **dedicated** `AgentSyncService.appendJoin
   ({agentId, joinId, parentIds, at})` — **not** routed through
   `_appendMessage` (red-team J1): `_appendMessage` would add a spurious
   single-parent `msgprev-${joinId}` edge off the pointer head *and* collide with
   the per-parent edge-id scheme. `appendJoin` writes, in one `runInTransaction`:
   the canonical join `system` message (`threadId == joinId`, empty metadata)
   via `_upsertEntityRaw`; one `messagePrev` link per parent with id
   `msgprev-${joinId}-${parentId}`; and the head advance to
   `joinId` through `_upsertAgentStatePreservingHead`. **Idempotency keys on the
   join node's presence** (not on a single `prevMessageId`, which a multi-parent
   node lacks) and re-asserts all *n* edges, so a crash between node-insert and
   edge-inserts heals on retry (no join node left with missing parents).
   Integration-tested over the in-memory repo
   (`test/features/agents/sync/in_memory_agent_repository.dart`): a 2-head fork →
   `appendJoin` → `project()` yields exactly one head (the join); re-running is a
   no-op; a partial-commit retry completes the edge set; two "devices" appending
   the same join id converge to one node + one edge set. Not yet called by
   production. *Done when:* analyze clean, integration tests green, no regression
   in existing append tests.
3. **J3 — Emit on wake (flag-gated default-off). ✅ done.** A focused
   `ForkHealer` (`lib/features/agents/sync/fork_healer.dart`,
   `maybeHealFork(agentId, at)`) folds the full-log projection,
   calls `planJoin`, and `appendJoin`s when due — catching a corrupt log as
   non-fatal. It also defers while a content-addressed join head is missing part
   of its edge set, so partial sync of a peer's join cannot create a follow-on
   join. The `WakeOrchestrator` gains one optional `onWakeStart` hook fired
   just before the executor (covering all four agent kinds in one seam). DI
   (`agent_providers.dart`) always wires the hook, which consults the
   default-off `enable_fork_healing` config flag **per invocation** —
   **default false → the hook returns immediately → wakes run byte-identically
   to today**. (Originally shipped behind a `LOTTI_JOIN_HEALING` dart-define;
   migrated to the runtime config flag on 2026-06-04, mirroring compaction's
   per-wake flag read.)
   **No `AgentStateEntity` field, no `build_runner`** (the eager gate is
   stateless). Tested: `ForkHealer` over the in-memory repo (fork→heal, no-op,
   defer-on-incomplete-view, defer-on-pending-join, idempotent re-fork
   prevention, arrival-order-independent join id, projection-after-heal shape,
   non-fatal on a corrupt log); orchestrator (hook runs before the executor with the wake
   context; a throwing hook is non-fatal and the wake still completes).
4. **J4 — Convergence sim; envelope canonicalization deliberately deferred. ✅
   done.** A two-device convergence sim (in `fork_healer_test.dart`): two devices
   fork, each heals independently with its *own* envelope, and the synced union
   (deduped by id — the DB's `insertOnConflictUpdate`) has **one** join node and
   **one** head, *independent of merge order*; repeated concurrent forks stay
   bounded (every heal returns to one head; message count grows linearly — no
   storm). **Sim trap avoided (red-team J1):** `AgentEvent` equality includes the
   envelope, so the sim unions into an id-keyed map before folding — modelling the
   DB — rather than concatenating raw lists (which would trip
   `DuplicateEventIdException`).

   **Envelope canonicalization is deferred, with rationale.** The original plan
   was to canonicalize a content-addressed event's per-device envelope (min-VC /
   lowest `hostId`) in the sync apply path. Investigation showed this is **inert
   for correctness today** and not worth destabilizing the most sensitive path:
   (a) the projection orders by `(hostId, id)` with `hostId = ''` in production
   (`agentEventsFromLog` is called with no `hostIdOf`), so a divergent stored
   vector-clock/timestamp envelope never changes the order or the derived state;
   (b) a join node is **immutable**, so its vector clock is never re-resolved;
   and (c) a synced duplicate applies via the raw repository write (not
   re-enqueued), so the envelope is *stably divergent after one exchange — no
   churn*. The row's structural fields are now canonical (`threadId == joinId`,
   empty metadata); vector-clock/timestamp canonicalization becomes load-bearing
   only if `hostIdOf` is ever populated (then two devices could order the join
   differently); it must be added *with* that change. Recorded as an open
   decision below. *Done when:* the sim passes; the deferral is documented.
5. **J5 — README + capping audit + roadmap refresh. ✅ done.**
   `lib/features/agents/README.md` gained a "Fork healing: join-by-continuation"
   section (fork→heal Mermaid lifecycle + the join id / edge-id scheme + the
   flag); `projection/README.md`'s file table was completed (it was missing the
   PR 5 files too) with `join_plan.dart`. The cap holds: the hook fires once per
   wake, re-emission is idempotent, and an explicit *partial-commit retry* test
   plus the *no-storm* assertion (message count grows linearly across repeated
   forks) cover it. Roadmap PR 6 line + this plan's status refreshed. Three final
   adversarial-review polish items applied: full-projection (not just heads)
   merge-order-independence assertion; the explicit partial-commit retry test;
   and the in-memory fake's `getAgentMessages` now filters soft-deletes to match
   the real repo.

Only **J3** changes runtime behavior, and only behind the default-off flag; J1/J2
are pure/mechanism, J4 hardens convergence, J5 documents. The deliberate flag
flip (turning healing on in prod) is a separate, user-driven rollout — like PR 5's
compaction flag — with a CHANGELOG entry **then** (none now: flag off = invisible).

## Test plan

- **Pure logic (Glados, tagged `glados`):** `planJoin`/`computeJoinId` —
  permutation-invariance over the head set, determinism, tag-isolation from
  `frontierDigest`, the gate (single head / empty / dups → null; `!viewComplete`
  → null; emit iff ≥2 heads over a complete view).
- **Append mechanism (`appendJoin`, example tests):** fork → join → one head
  (real projection); idempotent re-emit; per-parent edge ids; head advances to
  the join (incl. the stale-head-with-node-present case); partial-commit retry
  completes the edge set + head; no-state-row and <2-parent branches.
- **Fork healer (`fork_healer.dart`):** two heads → one deterministic join;
  repeated healing is idempotent; arrival order does not change the join id;
  already-joined logs are untouched; dangling parents and pending join nodes
  defer without crashing; projection after healing equals the pre-heal fork plus
  the explicit join marker.
- **Convergence sim (`fork_healer.dart` two-device):** concurrent joins over the
  same heads → one node + one head; full projection independent of merge order;
  repeated forks stay bounded (linear growth, no storm).
- **Wake hook (`WakeOrchestrator`, fakeAsync):** the hook runs before the
  executor with the wake context; a throwing hook is non-fatal; a hanging hook is
  bounded by `wakeStartHookTimeout` — the wake proceeds in all three.
- **Cap/crash:** a crash between join-append and commit re-emits the same id on
  retry → still one node (no storm); a synced join node arriving before its
  edges is treated as an unsettled view, not a new fork to join.

Conventions: pure logic uses Glados; service/wake tests stay deterministic
example tests with mocks + fixed clocks (`test/README.md`); no real timers;
deterministic dates.

## Defers

- **Eager (non-wake) join emission** — PR 6 emits only at wake start. A background
  coalesced join on sync (without waiting for a wake) is a later tuning knob if
  forks linger on idle agents.
- **Join *content* beyond parent ids** — the join carries no summary/snapshot; if
  a future need arises to fold state into the join, that is additive and must keep
  the content deterministic (rule 8).
- **Generalizing `recentHeadMessageId` to a head *set*** — out of scope; the
  single pointer remains this device's branch tip, and the full head set is always
  computed from the projection (never from the pointer).

## Open decisions

- **`appendJoin` vs. generalizing `_appendMessage` — RESOLVED in J2.** A
  dedicated `appendJoin` is used so the single-parent append fast path stays
  simple and cannot accidentally add a spurious `msgprev-${joinId}` edge.
- **Envelope canonicalization (partially resolved; remaining part deferred from
  J4 — becomes load-bearing only with `hostIdOf`).** Join structural fields are
  canonical today (`threadId == joinId`, empty metadata), but the sync envelope
  still carries per-device `createdAt` and vector-clock values. The projection
  ignores that envelope (`hostId = ''` in prod; joins are immutable; a synced
  duplicate doesn't re-enqueue → stably divergent, no churn), so canonicalizing
  it in the sync apply path is inert and not worth the risk. When/if the
  projection starts deriving `hostId` from the message (populating `hostIdOf`), a
  divergent stored envelope *would* change the `(hostId, id)` order across
  devices — at that point route content-addressed duplicate-id events (joins
  **and** PR 5 summary checkpoints) through a shared replica-independent
  canonicalizer (min canonical VC, then lowest `hostId`, then earliest
  `createdAt`). Add it *with* the `hostIdOf` change, not before.
- **Survival gate precision (red-team J1 confirmed real) — RESOLVED in J3 by
  dropping the marker.** The head-set-digest "unchanged since last wake" gate
  starved under one-branch-per-cycle churn. J3 replaced it with the stateless
  eager-at-wake-start gate (`≥2 heads + viewComplete`), which cannot starve and
  removes the synced field. The residual risk it leaves — a busy second device
  re-forking right after a heal — is the *intended* steady state: the head count
  stays bounded (≤ active devices) with a periodic collapse each cycle, which is
  exactly the "bounds context" goal. No further tuning needed.
