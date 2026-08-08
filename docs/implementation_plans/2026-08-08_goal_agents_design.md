# Goal-Driven Agents — Design Specification (Phase 3)

- Status: Draft for review, 2026-08-08
- Decisions this design implements: ADR 0053 (per-goal producers), 0054
  (deterministic-first two-tier wakes), 0055 (banner-nudge channel, rating &
  reuse), 0056 (need-to-know visual brief), 0057 (decade-scale memory)
- Companions: [phase-1 assessment](2026-08-08_goal_agents_phase1_assessment.md),
  [kickoff plan](2026-08-08_goal_agents_kickoff_plan.md),
  [eval methodology](../evaluations/goal_agent_models/README.md),
  [chat requirements](2026-08-08_reusable_chat_interface_requirements.md)
- Already on the branch: the pure-Dart goal core
  (`lib/features/goals/model/`, `lib/features/goals/evaluation/`) and the
  eval harness (`test/features/agents/eval/goal/`), both green.

## 1. Wake architecture

Invariant (ADR 0054): **a tick that changes nothing costs €0 and writes no
messages.** Two tiers:

- **Phase A — deterministic, every device, every trigger.** Pure Dart, no
  model, no capture, no agent messages. Loads the goal spec head, re-arms
  the cadence wake, runs `GoalProgressEvaluator` + `GoalTrackPolicy` over a
  `GoalSignalWindow` read from the journal, upserts the `goalProgress`
  keyed register (recompute-never-accumulate → LWW-convergent), derives
  `GoalWakeFacts`, and *returns* unless something is LLM-worthy.
- **Phase B — LLM, lease-elected single device.** Runs only on state
  transitions, ad staleness, scheduled dialogue moments, or an unanswered
  user message. The system prompt + tool surface are the eval spec
  (`goal_agent_spec.dart`), graduated into `lib/`.

### Triggers and routing

```mermaid
flowchart TD
    subgraph anydevice [Every device]
        LU[localUpdateStream\nsteps, habit completion,\nnudge dismissal, rating] --> WO[WakeOrchestrator\nsubscription match]
        SY[syncUpdateStream] --> GD[GoalSignalSyncDispatcher\nsynced_audio pattern]
        SW[ScheduledWakeManager\nhourly poll] --> CAD[cadence ScheduledWakeEntity\nworkspaceKey goal-cadence]
        WO --> PA[Phase A: evaluate + upsert registers]
        GD --> PA
        CAD --> PA
    end
    PA -->|nothing LLM-worthy| DONE[return — €0, no messages]
    PA -->|escalation needed| ESC[upsert escalation ScheduledWakeEntity\nworkspaceKey goal-escalation:periodKey]
    ESC --> LEASE[leaseHostId election\nexactly one device]
    LEASE --> PB[Phase B: capture → compact →\nconstitution + FACTS → tool loop ≤8 turns]
    PB --> OUT[report editor → outputs →\nAiConsumptionEvent per turn]
```

- **Subscriptions per goal** (registered by `GoalRuntimeMaintenance
  implements AgentRuntimeMaintenance`, restored at startup, wired in
  `app_bootstrap.dart` beside the Daily OS block): the criterion tree's
  `dataType` strings (e.g. `cumulative_step_count`), its `habitId`s (NOT
  the global `HABIT_COMPLETION` sentinel), and
  `goalNudgeToken(agentId)` for dismissal/rating writes.
- **Sync blind spot** (phase-1 assessment §4): synced entries reach only
  `syncUpdateStream`, so a desktop would never wake from phone-imported
  steps. `GoalSignalSyncDispatcher` follows
  `synced_audio_inference_dispatcher.dart` 1:1 and wakes **Phase A only**
  on receiving devices — idempotent keyed registers make N devices
  converge rather than duplicate.
- **Phase B single-flight**: Phase A never invokes the LLM directly; it
  arms an *escalation* `ScheduledWakeEntity` at a deterministic id, and
  the existing `leaseHostId` election picks exactly one device. The
  arming device nudges its own scheduled-wake manager for immediacy;
  if it dies, any other device picks the wake up within the hourly poll.
  Worst case ≤1 h remote latency — accepted and documented.
- **Recurrence without schema change**: cadence wakes re-arm at Phase A
  start at a deterministic id (workspaceKey `goal-cadence`), self-healed
  by `beforeWakeScan()`. Hourly granularity is ample for a coach.
- **Registry trap** (phase-1 assessment §2): `wireWakeExecutor` falls back
  to the task-agent workflow *silently* for unregistered kinds. PR 2 ships
  a regression test asserting `goal_agent` resolves to its own runner.

### GoalWakeFacts and the tool gate (ADR 0051 designed in)

Phase A's output is a typed facts object; Phase B's tool surface is gated
on it (`task_agent_tool_gate.dart` precedent — "a tool that cannot succeed
is an invitation to invent its arguments"):

| Fact | Tool exposed |
| --- | --- |
| `statusTransitioned` | `update_goal_report` (absent tool = wake CANNOT churn) |
| `hasActiveNudge` | `retire_goal_ad` |
| `offTrackOrWorseningAndNoFreshNudge` | `create_goal_ad` |
| ...and `topRatedReusableNudges` non-empty | `rerun_goal_ad` (offered alongside create; prompt prefers it) |
| `inDialogue` / clear change request | `propose_goal_revision` (ChangeSet-gated) |
| `specImpliesCadenceAndDrifted` | `upsert_standing_agreement` (ChangeSet-gated; **PR 4**, not in the eval contract) |
| always | `record_goal_observation`; plus `remember`/`search_memory` (**PR 6**, shared memory extraction) and `set_next_check_in` (**PR 2**, bounded/day) — all outside the six-tool eval contract |

`goal_agent_spec.dart` is the SINGLE Phase B tool contract: the six tools it
defines are what ships in PR 3, and every tool added later (standing
agreements, memory, scheduling) must land in the spec + scenarios first —
eval-first is the process, not just the kickoff.

The FACTS block rendered into the prompt is exactly the shape the eval
fixtures author (`buildStepsFacts`/`buildGymFacts`) — the eval is the
contract; the runtime renders the same JSON from real registers.

## 2. Ad creation (procedural — ADR 0058)

```text
Phase B decides (create_goal_ad | rerun_goal_ad)
  → goalNudge row: copy (headline/tagline/cta, tone) + animation/accent
    presets from the code-owned catalogs
  → status ready→active immediately — nothing to generate, verify or wait
    for; creation is deterministic, free, and works offline
  → activeGoalNudgesProvider (reactive) → banner surfaces
```

- **No generative imagery** (ADR 0058): no image provider, no
  `GenerateImageService`, no verification pass. Re-running a top-rated
  banner and creating a new one are both zero-cost; the rating library
  optimizes for *taste*, not spend.
- **Leakage discipline retargeted at copy** (the ADR 0056 principle): the
  handler lints headline/tagline/cta against digit+unit patterns, goal
  title terms and the private-strings inventory, and rejects rather than
  sanitizes; the eval leakage scenarios assert the same on the model side.
- **Presets are code**: `GoalBannerAnimation` (steady, typewriter, pulse,
  wave, marquee, glitch) and `GoalBannerAccent` (calm, ember, tide, neon,
  aurora) map to implementations owned by the banner widgets — design-
  system tokens only, reduced-motion respected, fragment-shader variants
  gated off on Linux (virtio-GPU freeze precedent) with plain-animation
  fallbacks.

## 3. Banner presentation

New `lib/features/goals/ui/` (tokens mandatory, l10n for static chrome in
all catalogs; generated ad copy is content, not localized):

- **`GoalAdBanner`** — shrink-to-nothing when no active nudge (the
  `KnowledgeNudge` contract). Mounts v1: Daily OS day page nudge stack
  (after `KnowledgeNudge`, `day_page.dart:411-428`) and the habits tab
  (after `HabitsSummaryCard`). The app-shell structural band
  (`DemoModeScaffold` pattern) stays a documented escalation, not built.
- **`GoalAdCard`** — animated typography over the accent treatment
  (CustomPainter/implicit animations; shader accents where available),
  persona attribution line, 44 px dismiss X, tap → goal chat. Dismiss and
  tap are never one gesture.
  The card **reports visibility sessions** (visible ≥50% → session start;
  hidden/disposed → session end, accumulated onto the nudge row).
- **`GoalAdCarousel`** — first carousel primitive: `PageView` + dots,
  manual swipe only, fixed height, reduced-motion respected.
- **Rating prompt** — on tap-through, the chat opens with a lightweight
  inline rating strip for the tapped ad (skippable; every re-run asks
  anew; skipped prompts don't nag within the same run). Ratings append to
  the nudge row; the agent reads top-/bottom-rated briefs in its FACTS.

## 4. Goal evolution

- The **only** mutation path is `propose_goal_revision` → ChangeSet →
  user approval → new `goalSpecVersion` + head move (template/soul
  version+head pattern; `authoredBy` provenance via
  `AgentAuthors.isSystemAuthored`). No auto-accept tier: over a decade of
  trust, the coach never quietly moves its own goalposts. User-authored
  edits write directly.
- "State your current goal" is a head→version read, zero inference —
  the eval's `wk_dialogue_over_report` scenario pins the behaviour.
- Habit-rule import: `GoalCriterion.fromAutoCompleteRule` (shipped, on
  this branch) seeds a goal from an existing habit in one tap; the setup
  sheet offers window/aggregation upgrades ("same threshold, but as a
  rolling weekly average").
- StandingAgreement becomes a **derived projection** with its first
  writer: ChangeSet-gated `upsert_standing_agreement` at a deterministic
  id when the spec implies calendar cadence. Planner negotiation stays a
  future seam (ADR 0023 unchanged on that axis).

## 5. Memory over a decade (ADR 0057)

- **Bounded reads are the invariant; pruning defaults to OFF.** No wake
  ever re-reads full history: context = spec head render + last ~8
  `goalProgress` periods as a table + nudge state + knowledge hooks +
  compacted tail. Raw history stays forever as cold, searchable data.
- Reuse `PlannerKnowledgeEntity` as-is; goal context reads
  `allFor(agentId)`; `remember` writes user-stated facts to `confirmed`.
- Extract shared `agent_memory_search.dart` from
  `day_agent_tool_handlers.dart:275-353`; goal agents get `search_memory`
  on day one (memory stops being write-only for non-day agents).
- Observation reads bounded: repository method "recent N + all critical";
  the task-agent read-all site gets the same one-line fix as cleanup.
- Epoch summaries: quarterly fold → `summaryDepth: 1` message; yearly →
  depth 2. ADR 0017 machinery unchanged underneath; epochs double as the
  agent's own retrospective.
- Cold-prefill budgets: `compactAndAssemble(budget: 12000,
  retainTokens: 4000)` per call (parameters exist), ≤8K input target. The
  50k/20k defaults stay for task agents whose warm-cache assumption holds.

## 6. Cost: monitoring, never caps

Session decision (2026-08-08): **no hard spending caps anywhere.**

- Every Phase B turn and every image generation already lands as an
  `AiConsumptionEvent{agentId, wakeRunKey, credits, tokens, …}` — per-goal
  rollups are a `consumption_repository` query away.
- Goal detail UI surfaces per-goal spend AND energy (`formatCredits` EUR
  presentation; `energyKwh` summed to Wh/month) — "this coach costs
  ~N Wh/month" is a headline figure, not a buried stat (ADR 0058).
- Evals report credits/case and credits/goal-month as **observed
  estimates** with the wakes/day assumption printed (see the evaluations
  README). Predictions to validate, not budgets: Phase B ~4/wk ≈
  €0.08/mo, dialogue ≈ €0.20/mo, images cents each at a few per off-track
  day — order €0.1–1/goal-month expected.
- The rating library bends the image curve down over time: the more
  history, the more often `rerun_goal_ad` (€0) beats `create_goal_ad`.
- Caps remain a documented future option if monitoring ever shows a
  problem. Phase A/B stays as engineering discipline, not quota.

## 7. Component inventory

New (`lib/features/goals/`): `model/` + `evaluation/` (shipped),
`service/goal_agent_service.dart`, `service/goal_banner_service.dart` (nudge row lifecycle; no generation),
`state/` (active-nudges, per-goal spend, goal list providers),
`workflow/goal_agent_workflow.dart` + `goal_wake_facts.dart` +
`goal_tool_dispatcher.dart`, `sync/goal_signal_sync_dispatcher.dart`,
`ui/` (banner/card/carousel/rating strip, setup sheet, goal chat page).

Modified: `agent_domain_entity.dart` (+4 variants: goalSpecVersion,
goalSpecHead, goalProgress, goalNudge), `agent_db_conversions.dart`,
`agent_constants.dart` (`goalAgent` kind), `app_bootstrap.dart`
(runner + maintenance registration), retention policy (register
exemptions, skip-deadlock repair), db-notification token helper,
`skill_inference_runner.dart` (delegates to the extracted service),
day-agent tool handlers (search extraction).

## 8. Build phasing (each PR green and mergeable)

| PR | Contents | Proof |
| --- | --- | --- |
| 0 (this branch) | ADRs, docs, goal core, eval harness | 211 tests, eval run book |
| 1 | Entity variants + conversions + spec validator (reject fractional `targetCount`/`successes`, empty composites, `successes > criteria.length`, malformed targets — decoded JSON is validated before persistence and before evaluation) | JSON round-trips, register id determinism, validator rejection tests |
| 2 | Deterministic runtime, headless | Phase A unit tests; **non-fallback regression test**; sync dispatcher tests |
| 3 | Phase B LLM tier | Workflow tests with recorded strategy; live smoke vs eval scenarios; consumption attribution asserted |
| 4 | Revision flow + StandingAgreement writer | ChangeSet approval tests; head-move provenance |
| 5 | Nudges: pipeline, banner UI, rating, visibility | Widget tests incl. dismiss/rate/reuse; screenshot pairs per surface |
| 6 | Decade hardening: epochs, search extraction, retention repair | Property tests on fold boundaries |

CHANGELOG: first user-visible entry lands with PR 5 (banners) — earlier
PRs are invisible work.

## 9. Risks

- **Wake latency bound** — lease pickup after armer death is ≤1 h; fine
  for a coach, documented so nobody "fixes" it with polling.
- **Lease race duplicate Phase B** — costs ~€0.005 and is idempotent
  (keyed registers, report editor); accepted.
- **Silent task-agent fallback** — regression test in PR 2 (the registry
  falls back silently today).
- **Evaluator vs habit-UI drift** — habit streak semantics live in
  `habits_controller.dart`; fixtures pin the shared cases; any divergence
  is a defect in whichever side changed contract-free.
- **Image-brief leakage** — dual enforcement: typed brief + no-repo
  handler (code), leakage eval (model). Neither alone is sufficient.
- **Voice/token creep in chat** — budgets are structural (§5), not
  advisory.
- **Rating-prompt fatigue** — skippable, never nags within a run; if
  telemetry shows skip-rates near 100%, drop to sampling rather than
  removing the signal.
