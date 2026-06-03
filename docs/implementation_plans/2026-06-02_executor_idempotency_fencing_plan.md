# Executor Idempotency & Fencing (Move 4 — idempotency-first) — Implementation Plan (PR 7)

- Status: **Paused — L1+L2 done (reusable key primitives); L3–L5 deferred to PR 8** · Date: 2026-06-02
  - Decision (after grounding): the only at-risk auto-effect today is the task-suggestion notification, whose cross-device duplication is **already mostly handled** (per-task retraction converges the bell) and whose remaining behavior is a **deliberate, documented re-surface-after-dismiss UX** — so deduping it would reverse intent, not fix a bug. The reusable key machinery (L1+L2) is landed; the effect-dedup (L3–L5) is deferred until **PR 8 (planner)** introduces genuinely *unguarded* side effects (schedule commits / external writes) where idempotency has clear value and no conflicting existing design. See "Grounding findings" below.
- Part of: [`2026-05-30_daily_os_runtime_implementation_roadmap.md`](./2026-05-30_daily_os_runtime_implementation_roadmap.md) (PR 7).
- Design baseline: [ADR 0018](../adr/0018-convergent-multi-device-execution.md) **rules 2–3, 9–10** (lease + fencing token; side-effect idempotency key; silent vs. visible reconciliation); [ADR 0019](../adr/0019-attention-negotiation-protocol.md) (the human gate is the safety boundary for irreversible effects; "convergence handles that, not the lease"); [ADR 0006](../adr/0006-change-set-deferred-tool-confirmation.md) (ChangeSet human gate); [ADR 0009](../adr/0009-redundant-change-proposal-suppression.md) (fingerprint dedup).
- Depends on: **PR 4** (convergent projection — ✅ merged) and **PR 5** (input frontier — ✅ merged; reused for `frontierDigest`). Independent of PR 6.

## The lease-backend decision (settled)

The roadmap flagged "Decision required: lease backend." **Decided: idempotency-first, no hard lease.** Grounding (from a full survey of the execution/coordination code):

- **There is no linearizable coordination primitive in Lotti.** Sync is pure local-first/P2P over Matrix (E2EE, vector-clocked, eventually-consistent CRDT). There is no backend service, no compare-and-swap, and no leader/election notion anywhere in `lib/features/sync/`. `WakeRunner` single-flight is an **in-process** lock map (`wake_runner.dart`), device-local only; self-suppression (`WakeSuppressionTracker`, 5 s TTL) is device-local only.
- So ADR 0018's "external coordinator with linearizable CAS" option is infeasible without adding server infrastructure that contradicts the architecture, and a *hard* "exactly-one-executes" lease is impossible offline. ADR 0018 already anticipates this: "**the lease is secondary to convergence … an optimization, never the thing preventing corruption**" (§Context), and rule 3 frames the guarantee as "connected-case + an offline reconciliation contract."
- **Therefore correctness comes from idempotency + the human gate, not a lease.** Two devices that execute the same wake must converge to **one** committed effect (dedup by a content-addressed idempotency key; the projection suppresses duplicates — ADR 0018 rule 9, reusing ADR 0009), and irreversible effects stay behind the existing ChangeSet human gate (ADR 0006/0019). The soft designated-primary lease + fencing token (ADR 0018 rule 2) is **deferred** — it would only cut duplicate LLM cost in the connected case, degrades to this design offline, and adds synced lease-state machinery for no correctness gain. (See Defers.)

## Goal

Make agent side effects **safe under concurrent multi-device execution without a lease**: the same wake run on two devices yields one logical effect, and irreversible effects never auto-commit. Build the **rule-9 side-effect idempotency key** as a first-class, content-addressed value, dedup at the effect-commit boundary, and confirm the human gate covers the irreversible set.

## What already protects us (so PR 7 complements, not duplicates)

- **Reversible journal mutations** (task title/status/checklist/etc. via tools) converge for free — they are idempotent upserts folded by the CRDT/projection, so a double-execution is benign (same result).
- **Irreversible / high-impact effects** (status commits, schedule changes) are already **deferred to the ChangeSet human gate** (ADR 0006): they don't auto-commit; the user confirms once, a `ChangeDecisionEntity` is persisted *before* dispatch (`change_set_confirmation_service.dart`), and **ADR 0009 fingerprint dedup** suppresses redundant proposals across devices.
- **Net-new risk PR 7 must close:** effects that auto-fire and are *not* idempotent — chiefly **user-visible notifications** (`change_set_notification_service.dart`) and any future external write (calendar/email — none exist yet) — plus the *absence of a stable, cross-device idempotency identity* for scheduled wakes (today `runKey` for a scheduled wake is `sha256(agentId|'scheduled'|clock.now())`, so two devices mint different keys — clock skew).

## The model (idempotency-first)

1. **Side-effect idempotency key (ADR 0018 rule 9):** a content-addressed value over
   `{agentId, behaviorKind, frontierDigest, triggerId, toolName}` — domain-tagged
   (distinct from the join id and summary `frontierDigest` tags). Two devices
   executing the *same behavior over the same inputs for the same wake epoch*
   compute a **byte-identical key**.
2. **`frontierDigest` — the input state the wake acted on.** Reuse PR 5's input
   frontier: `frontierDigest = ContentDigest.of(inputFrontierDigests(projectInputFrontier(...)))`
   — a digest over the `{contentEntryId → contentDigest}` map. This ties an
   effect to the exact content version it was computed from (so a later wake over
   *changed* content is correctly a different effect).
3. **`triggerId` — a stable, source-derived wake identity** (never a per-run
   UUID). Subscription wakes already have one (`reasonId` = subscription id,
   stable cross-device). **Scheduled wakes need stabilizing**: derive `triggerId`
   from the scheduled-wake's *due-at* (a synced, deterministic value) rather than
   `clock.now()`, so two devices firing the same scheduled wake share the key.
   The **wake-epoch scoping** (rule 9: "scoped to the wake epoch, not just the
   frontier") falls out of `triggerId` — a later time-sensitive wake over an
   unchanged frontier has a *different* `triggerId`, so it is not wrongly
   suppressed.
4. **Dedup at the effect-commit boundary.** Before committing an at-risk effect
   (a notification, a future external write — *not* the CRDT-convergent journal
   upserts), check whether an effect with this key is already recorded in the
   synced log; if so, **suppress** (silent reconciliation, ADR 0018 rule 10).
   Record committed effects keyed by the idempotency key (content-addressed, like
   PR 6's join — so two devices' identical effect markers set-union to one). Reuse
   the existing (currently unused) `toolEffect` `AgentLink` as the keyed record
   where it fits.
5. **Irreversible effects stay human-gated.** PR 7 does **not** loosen the gate.
   Divergent *user-facing commitments* surface as a `ChangeSet` (rule 10); only
   reversible/idempotent effects reconcile silently.

## Where it lives (architecture)

- **Pure logic — `lib/features/agents/projection/` (new files).** `frontierDigest(...)`
  and `sideEffectKey({...})` as pure, content-addressed functions (reusing
  `ContentDigest` + PR 5's `inputFrontierDigests`). Glados-tested, unused at first.
- **Stable triggerId — the wake/scheduled-wake path** (`run_key_factory.dart` /
  `scheduled_wake_manager.dart`): derive a deterministic `triggerId` (subscription
  id, or scheduled due-at) and thread it to the effect-commit boundary. No hard
  schema change if due-at is already synced on the agent state.
- **Dedup at commit — the side-effect sites** (`change_set_notification_service.dart`
  for notifications; the tool-effect record path). A small `SideEffectLedger`
  read ("has this key already committed?") gated on the at-risk effects only.
- **No new synced lease state. No changes to the CRDT-convergent journal-write path.**

## Increments (each shippable green on its own)

1. **L1 — `frontierDigest` (pure, no wiring). ✅ done.**
   `lib/features/agents/projection/side_effect_key.dart`: a content-addressed,
   domain-tagged (`input-frontier-v1`) digest over the input frontier
   (`inputFrontierDigests` shape). Glados: insertion-order invariance over the
   frontier map, tag-isolation from an untagged digest; examples: empty frontier
   stable, changed/added source changes the digest. Unused in production.
2. **L2 — `sideEffectKey` (pure). ✅ done.** Same file:
   `sideEffectKey({agentId, behaviorKind, frontierDigest, triggerId, toolName})`
   → content-addressed, domain-tagged (`side-effect-v1`). Glados: distinct
   frontiers → distinct keys; examples: deterministic + versioned, *every*
   component changes the key (loop, no copy-paste), components keyed distinctly so
   adjacent fields don't alias (the separator-less-concat trap). Unused in
   production.
3. **L3 — Stable, source-derived `triggerId`. ⏸ deferred to PR 8.** Scheduled-wake
   determinism needs net-new synced state (a wake-instance id from the synced
   cadence + watermark, since `scheduledWakeAt` is device-local) — and the
   scheduled-wake duplicate it fixes is "duplicate expensive work" = the
   *deferred soft lease's* territory, not a duplicate committed effect.
   Subscription wakes already have a stable `triggerId` (the subscription id).
   Revisit when PR 8's planner needs it.
4. **L4 — Dedup the at-risk effects. ⏸ deferred to PR 8.** The only at-risk
   auto-effect today is the task-suggestion notification, which is **already
   mostly deduped** (per-task retraction converges the bell) and whose residual
   behavior is a **deliberate re-surface-after-dismiss UX** (see Grounding
   findings) — so there is nothing to fix here without reversing intent. The real
   unguarded effects (schedule commits / external writes) arrive with the planner;
   wire the dedup then, against effects that have no conflicting design.
5. **L5 — Convergence sim + README + roadmap. ⏸ deferred to PR 8.** Lands with the
   first real effect-dedup (L4).

Only L3/L4 touch production paths, and they are additive (dedup *suppresses*, never
double-commits). L1/L2 are pure. There is no flag to flip — the dedup is always
safe (it only collapses genuine duplicates).

## Test plan

- **Pure (Glados):** `frontierDigest` / `sideEffectKey` — determinism, permutation/
  dedup invariance, per-component sensitivity, domain-tag isolation.
- **triggerId (example):** cross-device stability for scheduled + subscription
  wakes; epoch separation for a re-scheduled wake.
- **Dedup (example/service):** duplicate effect suppressed; new effect fires;
  irreversible effect still gated.
- **Convergence sim (PR 1 harness):** two devices, same wake → one committed
  effect, either arrival order; reversible journal writes still converge.

Conventions: pure logic uses Glados; service/sim tests are deterministic with
mocks + fixed clocks; no real timers.

## Defers

- **Soft designated-primary lease + fencing token (ADR 0018 rule 2).** A
  connected-case optimization to cut duplicate LLM cost. Deferred: it needs
  synced lease state + fence-rejection-on-reconnect, degrades to this design
  offline, and is not a correctness requirement. Revisit if duplicate-inference
  cost proves material in practice.
- **External coordinator / hard lease.** Out of scope — no linearizable primitive
  in a local-first/Matrix architecture; would require a server.
- **External side effects (calendar/email).** None exist yet; the idempotency key
  + human gate are the contract for when they land.

## Grounding findings (L3/L4 — discovered after L1/L2)

A code survey of the effect sites sharpened the scope and surfaced choices:

- **Duplicate notifications are a real gap, and the root cause is upstream.**
  Notifications fire only on *local* ChangeSet creation (`ChangeSetBuilder.build()`
  → `NotificationRepository.createTaskSuggestion()`); a synced ChangeSet does not
  re-fire. But **ChangeSet ids are surrogate UUIDs, not content-addressed**, so two
  devices running the same wake create two distinct ChangeSet entities that never
  converge — each fires its own notification. ADR 0009 fingerprint dedup is
  within-device/within-wake only. So the cleanest fix may be *upstream*: make the
  ChangeSet (or the notification record) content-addressed so identical proposals
  set-union to one — rather than only deduping at the notification call.
- **Scheduled-wake duplicate firing is the *lease's* problem, not correctness.**
  `scheduledWakeAt` is device-local (PR 4 `_preserveLocalScheduling`) and `runKey`
  carries wall-clock, so two devices fire the same logical scheduled wake with
  different keys → two wakes → two *LLM calls*. That is "duplicate expensive work"
  — exactly what the **deferred soft lease** targets — not a duplicate committed
  side effect. A stable scheduled-wake `triggerId` would need net-new synced
  state (a wake-instance id derived from the synced cadence + watermark, since the
  cached `scheduledWakeAt` is device-local). **Subscription wakes already have a
  stable `triggerId`** (the subscription id = `reasonId`).
- **Plumbing cost.** The `WakeExecutor` typedef passes only `(agentId, runKey,
  triggerTokens, threadId)` — not `reason`/`reasonId` — so threading a `triggerId`
  to the effect site needs a signature change (touched in PR 6) or a zone value.
  The `toolEffect` `AgentLink` is unused and has no key field, so a keyed
  side-effect record needs a model/DB extension.

**Net:** the correctness-bearing slice (dedup the at-risk *notification*) is
achievable for **subscription wakes** (stable `triggerId`) without the harder
scheduled-wake determinism work; and it may be better solved by **content-addressing
the ChangeSet/notification record upstream** than by the rule-9 key at the call
site. The scheduled-wake duplicate-firing belongs with the deferred lease.

### Deeper read: the notification "gap" is mostly already handled (and the fix conflicts with intent)

Reading `notification_repository.dart` + `change_set_builder.dart`
`_notifyTaskNeedsAttention` closely:
- The notification id is `notificationIdForTaskSuggestion(idSeed ?? linkedTaskId)`,
  and each fire **retracts older open suggestion rows for the same task**
  (`retractTaskSuggestionsForTask`), so the bell **already converges to one
  active row per task**, cross-device (the synced `upsertNotification` merge keeps
  the earliest `actedOnAt`/`deletedAt`).
- `idSeed = changeSet.id` (a fresh UUID per wave) is **deliberate and documented**:
  it lets a *fresh wave land on a fresh durable row* so a dismissed suggestion can
  **re-surface** next wave ("once the user dismisses one inbox row, that row id can
  never be made active again").
- The sync handler does **not** fire notifications, so the residual cross-device
  "duplicate" is **one transient alert per device** (each device alerts its own
  user) — arguably intended, not a bug.

So content-addressing the seed by proposal content would dedup the residual alerts
**but reverse the documented re-surface-after-dismiss semantics** (a dismissed
identical suggestion would never re-alert). That is a **notification-UX decision
the maintainer already made the other way**, not a clean idempotency fix.
**Recommendation: do not change it under the idempotency banner.** Pause PR 7's
effect-dedup with the reusable L1+L2 key primitives landed, and revisit when PR 8's
planner introduces genuinely *unguarded* side effects (schedule commits, external
writes) — where idempotency has clear value and no conflicting existing design.

## Open decisions

- **`behaviorKind` source.** Use `WakeJob.reason` (subscription/scheduled/…) or a
  coarser agent-behavior category? Settle in L2 against how effects actually vary
  by behavior.
- **`frontierDigest` = input frontier vs. message-head frontier.** Leaning input
  frontier (PR 5) — it captures the content the effect was computed from. Confirm
  it's the right scope for the at-risk effects in L4.
- **Effect record substrate.** Reuse the existing unused `toolEffect` `AgentLink`
  keyed by `sideEffectKey`, or a dedicated keyed marker? Decide in L4 by what the
  notification + tool-effect sites need.
