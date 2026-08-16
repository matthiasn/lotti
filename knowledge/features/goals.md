---
type: Feature Module
title: Goal Agents — Runtime
description: Goal-driven agents — the deterministic Phase A tier evaluating criteria into convergent daily registers, and the lease-elected Phase B LLM tier consuming escalation wakes through the eval-graduated contract.
resource: ../../lib/features/goals
tags: [goals, agents, runtime, wake, evaluation]
status: draft
generated: { by: claude-code/fable-5, at: 2026-08-15T21:00:00Z }
stale_after: 2027-02-22
sources:
  - id: goals-src
    resource: ../../lib/features/goals
    title: Goals feature source
    last_modified: 2026-08-16
  - id: phase-a
    resource: ../../lib/features/goals/runtime/goal_agent_phase_a.dart
    title: GoalAgentPhaseA — the deterministic tick
    last_modified: 2026-08-13
  - id: signal-reader
    resource: ../../lib/features/goals/evaluation/goal_signal_reader.dart
    title: GoalSignalReader — journal-backed daily aggregates
    last_modified: 2026-08-13
  - id: evaluator
    resource: ../../lib/features/goals/evaluation/goal_progress_evaluator.dart
    title: GoalProgressEvaluator — pure criteria-tree fold
    last_modified: 2026-08-12
  - id: policy
    resource: ../../lib/features/goals/evaluation/goal_track_policy.dart
    title: GoalTrackPolicy — status derivation rules
    last_modified: 2026-08-12
  - id: vocabulary
    resource: ../../lib/classes/goal_criterion.dart
    title: GoalCriterion tree (shared vocabulary in lib/classes)
    last_modified: 2026-08-12
  - id: trigger-tokens
    resource: ../../lib/classes/goal_trigger_tokens.dart
    title: Goal trigger tokens — cadence, escalation, baseline, report-refresh
    last_modified: 2026-08-13
  - id: goal-service
    resource: ../../lib/features/goals/service/goal_agent_service.dart
    title: GoalAgentService — lifecycle, subscriptions and report automation
    last_modified: 2026-08-14
  - id: progress-vocabulary
    resource: ../../lib/classes/goal_progress_models.dart
    title: Persisted per-dimension progress vocabulary
    last_modified: 2026-08-12
  - id: workflow
    resource: ../../lib/features/goals/workflow/goal_agent_workflow.dart
    title: GoalAgentWorkflow — the Phase B LLM tier
    last_modified: 2026-08-14
  - id: contract
    resource: ../../lib/features/goals/workflow/goal_agent_contract.dart
    title: Goal-agent contract (eval-graduated prompt + tools)
    last_modified: 2026-08-15
  - id: strategy
    resource: ../../lib/features/goals/workflow/goal_agent_strategy.dart
    title: GoalAgentStrategy — Phase B conversation and tool dispatch
    last_modified: 2026-08-14
  - id: facts-renderer
    resource: ../../lib/features/goals/workflow/goal_facts_renderer.dart
    title: GoalFactsRenderer — the JSON fence Phase B consumes
    last_modified: 2026-08-15
  - id: goal-agent-evals
    resource: ../../docs/evaluations/goal_agent_models/README.md
    title: Goal-agent model evaluation run book and results
    last_modified: 2026-08-16
  - id: tool-dispatcher
    resource: ../../lib/features/goals/workflow/goal_tool_dispatcher.dart
    title: GoalToolDispatcher — proposal persistence and spec revision routing
    last_modified: 2026-08-12
  - id: create-edit
    resource: ../../lib/features/goals/ui/pages/create_goal_agent_page.dart
    title: Goal create/edit flow — three-step creation, two-step editing
    last_modified: 2026-08-15
  - id: unified-goals-page
    resource: ../../lib/features/goals/ui/pages/unified_goals_page.dart
    title: UnifiedGoalsPage — flag-gated Goals + Habits merge (phase 1)
    last_modified: 2026-08-16
  - id: goal-routes
    resource: ../../lib/features/goals/ui/goal_routes.dart
    title: goal route helpers — every goal page path under /goals
    last_modified: 2026-08-16
  - id: measurable-capture
    resource: ../../lib/features/goals/service/goal_measurable_capture_service.dart
    title: Approval-gated measurable capture from goal chat
    last_modified: 2026-08-12
  - id: assessments
    resource: ../../lib/features/goals/service/goal_assessment_service.dart
    title: Separate daily assessment ledger
    last_modified: 2026-08-12
  - id: sync-dispatcher
    resource: ../../lib/features/goals/sync/goal_signal_sync_dispatcher.dart
    title: GoalSignalSyncDispatcher — the sync blind-spot bridge
    last_modified: 2026-08-09
  - id: adr-0054
    resource: ../../docs/adr/0054-deterministic-first-two-tier-wakes.md
    title: "ADR 0054: Deterministic-First Two-Tier Wakes"
    last_modified: 2026-08-08
  - id: chat-composer
    resource: ../../lib/features/agents/ui/chat/agent_chat_view.dart
    title: AgentChatView — voice-enabled goal chat composer
    last_modified: 2026-08-14
  - id: recorder-controller
    resource: ../../lib/features/ai_chat/ui/controllers/chat_recorder_controller.dart
    title: ChatRecorderController — shared voice recorder
    last_modified: 2026-08-14
---

# Goal Agents — Runtime

One long-lived agent per user goal (ADR 0053), built deterministic-first
(ADR 0054): the invariant is that **a tick that changes nothing costs €0
and writes no messages**. Phase A is the model-free tier that runs on
every wake; Phase B is the lease-elected LLM tier that consumes the
escalation wakes Phase A arms, speaking the contract that was validated
in the eval harness *before* this runtime existed (the prompt and tool
definitions live in `goal_agent_contract.dart` and the eval suite imports
them — one artifact, zero drift). The banner surface, unified Goals tab,
rolling progress detail, and the first durable two-way chat slice are
visible behind the `enable_unified_goals` rollout flag.

## Runtime flow

```mermaid
flowchart TD
    subgraph triggers [Triggers — every device]
        SIG[localUpdateStream signals\nleaf dataTypes, habitIds,\nmeasurable ids] --> ORCH[WakeOrchestrator\nsubscription match]
        LOCALTIME[local category-time mutation] --> STALE[advance report-stale watermark\nno wake]
        SYNC[syncUpdateStream] --> DISP[GoalSignalSyncDispatcher]
        CAD[cadence ScheduledWakeEntity\nworkspace goal-cadence,\ndaily at 06:00 local] --> MGR[ScheduledWakeManager]
        CHAT[Goal chat composer] --> STORE[persist user message + payload]
        STORE --> USERWAKE[manual userMessage wake\nmessage id trigger token]
        STORE --> OFFER{explicit linked\nmeasurable quantity?}
        OFFER -- yes --> REVIEW[editable record offer\naccept rows or dismiss]
        REVIEW -- accept --> MEASURE[existing MeasurementEntry path]
        REVIEW --> CAPTURELOG[durable capture decision\nsource message + entry ids]
        REFLECT[detail day reflection] --> ASSESS[append assessment action\nspec id + overall/per-dimension rating]
        DAYEDIT[Goal detail day cell\nsuccess or missed] --> HABITWRITE[existing habit completion\npersistence path]
        HABITWRITE --> SIG
        REFRESH[Update now\ngoal-report-refresh] --> REFREG[persist deterministic register\nwithout duplicate escalation]
        MEASURE --> SIG
    end
    ORCH --> PA[GoalAgentPhaseA.execute]
    DISP --> SYNCROUTE{bounded signal or\ncategory-time mutation?}
    SYNCROUTE -- bounded --> PA
    SYNCROUTE -- category time --> STALE
    MGR --> PA
    PA --> HEAD[spec head → active version\nno head = clean no-op]
    HEAD --> REARM[re-arm cadence\nrecurrence by re-arm]
    REARM --> READ[GoalSignalReader\njournal → GoalSignalWindow]
    READ --> EVAL[GoalProgressEvaluator\n+ GoalTrackPolicy]
    EVAL --> REG[upsert goalProgress register\ngoal_progress:agent:evaluation-day\nrecompute, never accumulate]
    REG --> MATERIAL{status transition, register change,\nor eligible banner expiry?}
    MATERIAL -- no --> DONE[return — the €0 no-op]
    MATERIAL -- yes --> STALE2[advance report-stale watermark]
    STALE2 --> AUTO{automatic report\nupdates enabled?}
    AUTO -- no --> DONE
    AUTO -- yes --> DEFER[local goal-report-refresh job\n120-second visible countdown\nfirst deadline wins]
    DEFER --> DPA[GoalAgentPhaseA\ndeferred refresh trigger]
    DPA --> ESC[arm escalation wake\ngoal-escalation:periodKey,\nperiod-derived UTC deadline,\nlease-elected, same txn\nas the register]
    ESC --> NUDGE[nudge ScheduledWakeManager\nrequestCheck on arming device]
    NUDGE --> ROUTE{escalation trigger token\non the wake?}
    ROUTE -- no --> PA
    ROUTE -- yes --> PB[GoalAgentWorkflow — Phase B\nsame derivation as Phase A]
    USERWAKE --> PB
    REFREG --> PB
    PB --> FACTS[GoalFactsRenderer\nJSON fence: goal, evaluation,\nreporting, ads, personaTone]
    FACTS --> CONV[one bounded conversation\nglm-5.2 default, profile override,\ntemperature 0, 8-tool contract]
    CONV --> OUT[one transaction:\nreport+head, goalNudge writes,\nobservations, revision ChangeSet,\nvisible reply_to_user carrier]
    OUT --> FRESH{current report head advanced\nand no watched timer active?}
    FRESH -- yes --> REPORTDONE[clear report-stale watermark]
    FRESH -- no --> STAY[keep report stale]
```

## Invariants

- **Convergence over coordination.** The register row id is deterministic
  per `(agentId, evaluation-day)`; every device recomputes the same
  content from the same journal, so concurrent Phase A runs converge
  instead of duplicating. A recompute over a synced row carries that
  row's vector clock forward — dropping it would make the write causally
  concurrent with its own input.
- **Transitions compare against the last persisted status** — today's own
  earlier row first, yesterday's otherwise — so an escalation wake that
  re-runs Phase A is a no-op, not a self-re-arming loop.
- **Banner expiry can be LLM-worthy without a status transition.** Phase A's
  deterministic staleness sweep records an overdue active banner as expired.
  When the unchanged goal still qualifies for automatic copy (off track, or
  at risk on the initial/worsening path), that expiry re-arms the period's
  escalation so Phase B creates or reuses a replacement. Healthy expiry stays
  a EUR0 maintenance event.
- **Banners are dirty-tracked against their evidence.** Phase B stamps a
  `factsDigest` (coarse status plus each dimension's actual value and
  satisfaction plus a hash of the exact health timestamps and values that the
  criterion's authored window can render at that evaluation reference,
  `goalFactsDigest`) into every minted or re-run banner's provenance. Phase A's
  sweep — which runs after derivation for exactly this reason — expires an
  active banner whose stamped digest no longer matches the current derivation,
  so a banner quoting "129/94" dies when a new reading or same-value backfill
  lands inside that model-facing window, and the expiry re-arms the escalation
  for replacement copy. A prior-period backfill that FACTS cannot expose leaves
  valid copy alone. Health
  signal subscriptions also advance the standing-report stale watermark
  directly because the persisted progress register intentionally contains
  aggregates rather than the full raw series.
  Two deliberate limits: the digest comparison only runs when the goal
  qualifies for automatic copy (never strip a banner that will not be
  re-minted), and same-day banners are exempt (their replacement would
  collide with the day's deterministic creation id in Phase B, and one
  automatic banner per day is the ceiling anyway). Banners minted before the
  stamp existed keep deadline-only expiry.
- **The report is dirty-tracked before inference.** A status transition,
  eligible banner expiry, or derivation that differs from today's persisted
  register (`goalRegisterDigest` vs `goalAggregateFactsDigest`) makes Phase A
  advance the durable report-stale watermark immediately. With automatic
  updates enabled, it also queues one local `goal-report-refresh` job behind
  the shared 120-second agent countdown. Bursts merge into the first job and
  keep its original deadline; they cannot postpone inference forever. The
  detail page uses the shared automation control to expose that deadline,
  Update now, Skip once, and the persisted automatic-updates switch. The first
  tick of a day is not "new data" (the window slid), and identical
  recomputation keeps the report fresh.
  **A direct identity write must ping `UpdateNotifications` itself.**
  `AgentSyncService.upsertEntity` does not notify; the wake path only appears
  to, because `WakeOutputWriter` pings separately after its own commit. So a
  user-initiated identity write — `GoalAgentService.updateAutomaticUpdates`
  toggling that switch — pings after its transaction commits, or
  `agentIdentityProvider` keeps its cached value and the switch renders the old
  state until the page is rebuilt from scratch, which reads as a switch that
  does not work.
- **The deferred arm and its escalation commit in one transaction.** When the
  local countdown fires, its dedicated trigger re-enters Phase A and writes the
  current register together with a forced report-refresh escalation. The
  escalation deadline is derived from the period (its UTC day key), never from
  the arming device's wall clock, so every device arming the same logical
  escalation writes an identical record and the concurrent resolver's
  later-deadline preference cannot resurrect a consumed wake. The scheduled
  wake's existing lease still elects the single device that spends inference.
- **Grace history is a consecutive, same-spec-version streak**: prior-row
  collection stops at the first missing day and at the first row computed
  under a superseded spec version.
- **Every criterion leaf is an accountable dimension.** A composite goal can
  combine any number of titled metric, measurable, habit, or category-time
  leaves through `allOf`, `anyOf`, or `atLeastCount`. Stable `criterionId`
  values connect each leaf to its persisted `GoalCriterionProgress` result in
  every period register: actual, target, ratio, satisfaction, sample count,
  pace feasibility, and coverage remain inspectable instead of disappearing
  into one overall score. The composite result controls goal health, while its
  children retain the evidence for which dimension carried or missed it.
- **Borrowed data semantics.** Quantitative day totals follow the health
  charts' per-type aggregation (`cumulative_step_count` day total is the
  daily max), point-sample types keep the day's latest sample, habit days
  follow the habits UI's latest-completion-per-day collapse with
  success-only counting, measurable leaves reuse their authored data-type ids,
  and category time reuses the same category-attributed timer rows as Insights.
  A category-time leaf can enforce an `atLeast` or `atMost` number of hours and
  can clip every local day to an optional time band; a crossing band such as
  `21:30 → 07:00` spans midnight. Evaluation clips the current day at the
  evaluation instant, so future-dated entries never count as time already
  tracked. A live timer resolves category attribution through the same linked-
  task query as Insights and replaces its persisted prefix by entry id. Day
  keys re-stamp the local calendar date as midnight UTC. The goal agent must
  never disagree with the chart the user is looking at.
- **Health FACTS preserve observations, not only aggregates.** Weight and
  systolic/diastolic blood-pressure criterion results keep `actual` as the
  deterministic rolling aggregate — quantized with the card's own display
  rule (`roundGoalAggregate` in `logic/goal_aggregate_rounding.dart`, shared
  with `formatGoalAggregate`) so the agent's report and the dimension card
  cannot quote two precisions of one number — and add a bounded
  `healthSeries` for the
  criterion's authored window and evaluation reference. Its ordered
  `observations` contain the newest 100 exact journal timestamps and values,
  `observationCount` and `observationsOmitted` disclose the wider series, and
  `latest` repeats the newest reading with deterministic `onTarget` and
  `isToday` flags relative to that evaluation day. It also classifies the
  reading as `completeOnTarget`, `measuredOffTarget`, or `notMeasuredToday`,
  while `latestChange` labels only the previous-to-latest movement relative to
  the authored direction. `evaluation.todayGuidance` indexes health logging
  complete today, health logging still needed today, and rolling habits behind,
  so Phase B does not have to infer today's actionability from unrelated
  aggregates. `evaluation.referenceIsCurrentDay` distinguishes a live
  evaluation from a delayed prior-day escalation; only the live case may call
  the evaluated day "today". Future samples and samples outside the criterion window are
  excluded. A delayed escalation therefore
  evaluates at the final representable microsecond before the encoded day's
  next local midnight: fractional-second samples at the boundary remain in the
  period, while its raw evidence cannot slide beyond the aggregate it explains.
  Phase B can
  describe the latest reading, direction and sparsity without inventing an
  intermediate measured value or overflowing a provider context; high-volume
  quantitative types such as steps remain aggregate-only.
  The journal query may reach the next local midnight for complete historical
  days, but the reader clips both quantitative aggregation and raw observations
  to the captured evaluation instant before either projection is built. A
  concurrent same-day write therefore appears in both representations on the
  next wake, never in only one side of the current FACTS.
- **Health level trends can be green before the threshold is crossed.** Weight
  and systolic/diastolic blood-pressure leaves use their latest observation per
  day and a rolling seven-day average. An unmet leaf with at least four sampled
  days is projected by a deterministic least-squares daily trend. When both the
  fitted slope and the earlier-vs-later sample means move in the authored
  direction and reach the target within 28 days, the leaf is on-track. This
  changes only the coarse status to green: `satisfied` remains false and a
  passed target date still resolves to off-track. Flat, wrong-way, slower,
  under-sampled, and unsupported metric trends receive no projection. FACTS
  includes the bounded projected days so Phase B can explain the verdict
  without recomputing it.
- **Pattern evidence is richer than the threshold.** Phase A reads only the
  bounded evaluation/lookback range. When Phase B actually runs, the same
  reader additionally loads every valid attributed session for a watched
  category since the goal agent was created, including sessions outside an
  optional cutoff band. FACTS unions overlaps per category and preserves
  sub-minute precision while summarizing the complete lifetime into bounded
  local-hour and weekday distributions, then adds the 200 most recent raw
  sessions with category, local start/end and duration. The raw session count
  remains available separately from the unioned duration. The coach can
  therefore notice late-night or clustering patterns without allowing one
  current model message to grow forever. Those signals are evidence only: the
  model may discuss them but cannot replace the deterministic per-dimension
  result.
- **Subjective assessment is a separate governance layer.** Deterministic
  `goalProgress` registers are recomputed from source and never carry a mutable
  opinion. `GoalAssessmentService` appends a durable action and payload for a
  user's Met/Improving/Mixed/Missed reflection, bound to the immutable spec
  version that was visible when it was recorded. Optional ratings use stable
  criterion ids; corrections append another record instead of rewriting
  measurement history. The payload also preserves whether the user rated
  directly or accepted a suggestion.

  **A recorded verdict outranks the measurement wherever both are shown.** The
  seven-day strip colours a day from `latestRatingsByDay`, falling back to the
  measured `GoalCompactDayState` only where no verdict exists — the
  measurement is evidence about a day, the reflection is the user's ruling on
  it. Those lookups are scoped to the active `specVersionId`: spec versions are
  immutable and the history keeps them all, so an unscoped map would let a
  judgement of retired criteria colour a day under the current ones. Ties on
  `createdAt` break by record id so two devices cannot disagree.

  `improving` is the verdict a three-way split could not express — some of it
  missed, but the day moved the right way. It is newer than the shipped wire
  format, so `rating` carries the nearest legacy-decodable verdict (`mixed`)
  and `ratingV2` carries the real one: a client predating it discards any
  record whose rating it cannot decode, taking the note and per-dimension
  verdicts with it.

  `suggestedDayVerdict` proposes a starting point from the day's own evidence
  — deterministic, never a model call, because a suggestion that disagreed
  with the numbers printed above it in the same sheet would be worse than
  none. A day with no observations at all suggests nothing rather than
  Missed.
- **Conversation capture is offer-first and linked-source-only.**
  `parseGoalMeasurableRecordOffer` only recognizes an explicit positive
  quantity/unit pair for a `GoalCriterionMeasurable` in the active criteria
  tree. It does not infer from silence or from unlinked measurables. Ambiguous
  totals over multiple named recent days become editable estimated splits.
  `GoalRecordOfferCard` checks the journal for same-source/day conflicts before
  enabling a write; accepted rows go through `PersistenceLogic` as ordinary
  `MeasurementEntry` rows, while both acceptance and dismissal append a durable
  decision keyed by source message. The decision payload retains entry ids and
  agent name; progress maps those ids back to measured days and shows the quill
  provenance without creating a second measurement store.
- **Automatic Phase B is reachable only through the lease; direct chat and
  detail-page refreshes are explicit user wakes.** The orchestrator listens
  local-only. On sync, bounded habit/measured signals run Phase A directly,
  while category-time mutations only advance the receiving agent's durable
  report-stale watermark. Meaningful bounded evidence first becomes a local,
  workspace-scoped `goal-report-refresh` countdown. When it fires, its deferred
  trigger makes Phase A arm the synced `goal-escalation:<periodKey>` scheduled
  wake whose lease election picks exactly one device. Restart hydration
  reconstructs the local job with that trigger and workspace; Skip once clears
  only this pending refresh. Turning automation off cancels it but leaves the
  deterministic signal subscription live, and turning it back on schedules one
  catch-up when the standing report is absent or stale. A durable source chat
  turn instead carries a `goal-chat-message:<messageId>` trigger on a manual
  `userMessage` wake. The source exists before enqueue, the wake bypasses
  throttling, and no chat UI owns an inference loop. Update now uses a manual
  wake in the same report-refresh workspace, supersedes the pending countdown,
  persists the deterministic register from the prose snapshot, and routes to
  Phase B immediately even when the coarse status did not change.
- **Phase B re-derives, never trusts.** The workflow calls the same
  `deriveWakeFacts` Phase A used to arm the escalation and renders every
  number into the FACTS block; the prompt forbids the model to recompute.
  For supported health criteria, it explicitly distinguishes the rolling
  `actual` from the timestamped `healthSeries` anchored to
  `evaluation.reference`: when the latest reading is on target for that day,
  copy says the evaluated day's logging is complete, describes any lagging
  rolling average separately, and does not ask for another reading. A delayed
  wake names the evaluated date and makes no claim about current-day actions.
  `update_goal_report` collects evaluated-period state, rolling standing,
  latest change, coverage, and actions as separate required slots; the strategy
  parses the same complete shape used by the eval classifier and assembles the
  localized model-authored sentences without injecting English headings.
  Evaluated-period and rolling-standing slots must be non-empty. Structured
  current actions carry a criterion id and survive only when deterministic
  `healthLoggingNeededCriterionIds` authorizes that id, so a lagging rolling
  habit cannot create a current action item; delayed overdue evaluations expose
  no current-action ids at all.
  Policy rows P16 and
  P17 regress this distinction with the six-dimensional BP fixture; model
  results and context-shape experiments live in the goal-agent eval run book.
  A wake with zero tool calls is legal (the no-op policy row) — the
  strategy never nags for output. Two deterministic exceptions are forced
  with one pinned retry each: a wake missing its report where the status
  transitioned, the detail page requested a refresh, **or the pending chat
  message asked for the standing report itself to be rewritten**; and policy
  row P5 (offTrack, no fresh ad, no cooldown) or an explicit new-banner
  request missing its ad. The chat-rewrite path is deliberately NOT the
  detail page's refresh token: that token also persists the derivation and
  re-bases `previousStatus`, neither of which a rewrite of the standing text
  may do. Its trigger mirrors the banner path — an English intent heuristic
  over the pending message (plus a short affirmation following the agent's own
  offer to rewrite), a matching FACTS-block instruction, and the model's own
  tool call as the language-independent carrier — and an explicit refusal
  ("don't make the report shorter") suppresses it, because forcing a rewrite
  over a refusal destroys the report the user asked to keep. A first evaluation that lands at risk is
  also ad-eligible, so a newly created goal does not wait for a three-day trend
  before receiving its initial banner.
- **Report freshness follows the durable standing head.** Producing report
  material or writing a historical report row is insufficient: the shared
  drain clears the stale watermark only when this wake actually advances the
  current report head. A report that includes a watched category timer's live
  elapsed prefix also remains stale, because in-memory timer ticks continue
  changing evidence without journal notifications.
- **The escalation carries its own baseline and period.** The wake record
  encodes the PRE-transition status as a `goal-baseline:<status>` trigger
  token (Phase A's register write hides it from any re-derivation, and a
  same-day double transition makes the prior-day row an insufficient
  reconstruction) and is evaluated at ITS period — a stale escalation
  resolves the spec version its register row recorded, and an older
  period never advances the current report head. A failed Phase B wake
  re-arms its escalation with a later deadline (the resolver's supported
  reschedule-beats-consume path), so a transient failure cannot orphan
  the period. Completed historical periods read category time through the next
  local midnight as an exclusive bound, so their final second is not lost;
  live periods remain clipped at the evaluation instant.
- **Ad contracts are enforced at persistence, not just in the prompt.**
  `persistOutputs` re-reads the nudge rows (a dismissal during inference
  must count), and suppresses creates/re-runs during the same-day dismissal
  cooldown, while a fresh active ad exists (ads retired in the same wake
  don't count — the P14 swap stays legal), and for duplicate brief
  digests. Automatic transition ads keep their period/baseline identity;
  chat-created replacements add the durable source message id so a retired
  transition ad cannot silently collide with the requested replacement.
  An affirmative chat request for a new banner is recognized from direct
  want/need/show language, replacement language, or a missing-banner report in
  the durable user message before inference. A short affirmation also qualifies
  when the immediately preceding visible assistant reply offered a banner.
  For every language, a typed create/re-run tool action on an interactive turn
  is the structured intent carrier and upgrades the same permission before
  persistence; the English heuristic is only the early force-action path.
  These interactive requests override
  the automatic dismissal cooldown and automatic health gates, and remain
  ad-eligible for the whole wake, so a recovering or healthy goal can serve
  explicitly requested positive copy without its persistence pass retiring the
  banner it just created. Negated
  requests, unrelated courtesy, and explanation prompts do not trigger that
  exception. The current active banner
  retires only after a sanitized, non-duplicate create or valid retired-ad rerun
  has been identified,
  so a replayed/invalid candidate cannot leave the goal bannerless. If the
  primary model replies with a cooldown refusal and omits the tool, the workflow
  forces `create_goal_ad` and withholds the now-contradictory refusal. A
  temporary-hide request instead calls `snooze_goal_ad` with any future instant
  carrying an explicit UTC marker or numeric offset, and an id from the
  active-ad subset (a retired reusable ad is not a snooze target): the same active nudge
  keeps its activation and rating history, stores typed current snooze state,
  appends timing evidence, disappears from the SHELL banner surfaces (the
  rotating dock and its reserved lane — the goal's own detail page keeps the
  banner with a return countdown, see the banner-surface invariant below),
  and returns to the dock
  when the active-banner provider reaches the deadline or reloads after it.
  Snooze extends the
  activation's `staleAt` past that reveal instant so the hidden interval cannot
  consume its remaining visible lifetime. A day dismissal likewise extends
  staleness past the next local midnight. A re-run clears current snooze and
  day-dismissal state but retains the historical timing evidence. Legacy
  provenance deadlines remain readable and are dual-written with typed snooze
  and day-dismissal state so mixed-version devices preserve the quiet period;
  a re-run clears that compatibility deadline. After a chat wake commits, the controller reads the persisted
  snooze deadlines into a short-lived local suppression map before invalidating
  the async projection; retained stale-while-revalidate data therefore cannot
  flash the hidden banner, and unrelated active banners remain visible.
  The three-day worsening requirement remains the automatic `atRisk` gate;
  an interactive `atRisk` wake that emits a structured create/rerun action
  honors the user's request while still enforcing duplicate-copy and stale-spec
  guards. Report prose passes
  `sanitizeAgentReportText`.
- **The goal spec never mutates in a wake.** `propose_goal_revision_v2`
  lands as a pending ChangeSet for user approval and persists the originating
  immutable spec version in its tool arguments; ad state is validated
  in-conversation against the ids the FACTS offered, and all outputs
  commit in one transaction.
- **Revision is approval-gated and conservative.** Accepting the proposal
  (`goalChangeSetConfirmationServiceProvider` → `GoalToolDispatcher` →
  `GoalSpecRevisionService`) applies the changes to the criteria tree via
  `applyGoalRevisionChanges` — which REJECTS anything ambiguous (two
  candidate leaves and no name, unparseable period/cadence, free-form
  `successCriteria` alone) rather than guessing — then supersedes the
  current version, mints `v(n+1)` with full provenance (`authoredBy:
  goal_agent`, `diffFromVersionId`, the proposal's rationale) and moves
  the head in one transaction. Approval refuses the item when that persisted
  base version is no longer the current head, including proposals that arrive
  late from an offline peer. The v2 tool name is also the capability fence for
  mixed client versions: an older client does not recognize or apply it, while
  a current client rejects and auto-retracts legacy v1 proposals. Malformed or
  stale v2 proposals are deterministic failures and are likewise retracted,
  rather than restored to a pending state that can never succeed. A missing
  spec head or a head whose immutable version has not synced yet is transient,
  so that approval stays retryable instead of being retracted. Grace history
  resets naturally: Phase A's
  prior-row streak breaks at the version change. The revision service rechecks
  that the identity is still an active goal inside the serialized path;
  inactive details hide the approval card as well. After acceptance the
  signal subscription re-registers from the NEW criteria; on other
  devices the synced-in head triggers the same re-registration through
  the sync processor's identity re-offer. A revision also retires the
  superseded goal's whole ad surface and pending inference in the same
  transaction: every non-terminal nudge (`draft`, `ready`, `active`,
  `retired`) moves to `superseded` — `retired` rows are the reuse library
  (`reusableTopRated`), so a top-rated ad written for the old target cannot
  be re-activated beside the revised statement — and every pending
  `goal-escalation` wake is consumed, so a wake armed under the old spec
  cannot later spend inference on a transition the new goal never made.
  The immediate post-acceptance evaluation re-arms anything genuinely due.
- **Owner edits are versioned, never in-place.** The explicit edit route uses
  `GoalSpecRevisionService.reviseFromOwner` with the complete user-authored
  title, intention, persona name and criteria tree. It serializes against the
  current head, refuses a no-op or a save whose loaded base version is no
  longer the head, supersedes the current version and mints `v(n+1)` with
  `authoredBy: user` and `diffFromVersionId`. The create/edit UI
  rewrites rolling-seven-day habit and measurable leaves, the supported
  at-least rolling-average steps metric, and rolling-average weight plus
  systolic/diastolic blood-pressure leaves with either target direction. It
  also creates and edits category-time sums with a rolling-seven-day hour
  target and either direction;
  `all`, `any`, and `atLeastCount` wrappers round-trip through an explicit
  composite-rule picker. Category-time leaves with a local time band, other
  health leaves, and opposite-direction step
  criteria are retained exactly and shown read-only. Supported trees retain
  authored leaf titles, composite wrappers and stable collision-free node ids.
  Manual mapping choices survive back-navigation while the intention is
  unchanged. A category-stream refresh adds newly available intention matches
  without resetting other manual signals or targets, and a manually removed
  category match stays suppressed until the user reselects it.
  **An edited intention re-maps additively, and an explicit deselection
  outranks the re-map.** Health signals the user unticked are remembered for
  the lifetime of the form: a re-map still offers them as unchecked
  suggestions but never re-seeds their targets, and re-selecting one clears
  the memory and restores its default target. The same rule already governs
  category-time matches, so no back-edit of the statement can silently
  resurrect a signal the user removed.
  Signals added through the picker likewise stay on the card as unchecked rows
  once unticked, until the step is re-entered and the row order is re-frozen —
  deselecting is never a deletion the user has to undo through the picker. Saving validates
  category-time selections through a direct database snapshot that includes
  hidden rows, retaining an active private category if it disappears from the
  discovery stream while removing newly selected inactive or deleted
  categories. It likewise
  reconciles selected habits against the latest active-habit stream so a paused
  or removed habit cannot be minted into a dead criterion. After a minted edit,
  the runtime re-registers the new signal set and enqueues an immediate `goal
  revised` wake so the report and health do not describe the old spec.
- **Nudge accumulators are CRDTs.** Terminal retirement is monotonic in the
  concurrent resolver, and exposure counters (per-host G-counters),
  rating histories, append-only snooze and day-dismissal histories, and shown-at
  watermarks merge losslessly on concurrent sync — the labeled ad library and
  its timing evidence must survive whole-row LWW. Concurrent snoozes for the
  same activation keep the later quiet deadline while retaining both events;
  their staleness extensions merge by the later deadline so the selected
  reveal cannot immediately disappear as stale. Successive snooze requests in
  one model turn fold over the just-written row rather than the turn's initial
  snapshot. Both the choice-time and requested-return offsets are retained, so
  a daylight-saving transition cannot shift learned return-hour evidence;
  interaction-event ids deterministically de-duplicate the append-only
  histories across peers.
- **Calendar arithmetic is component-based** (`DateTime(y, m, d ± n)`),
  never `Duration` math, so DST transitions cannot shift the cadence hour,
  skip a prior-day register key, or truncate a 25-hour day's query range.

## The visible layer (PR 5)

- **Banners** (`ui/goal_banner_*.dart`): procedural text banners per
  ADR 0058 — model-authored copy, code-owned animation presets (all
  degrade to plain text under reduced motion) and accent presets bound to
  design-system tokens. The register TINTS the accent (`goalBannerStyle`):
  one hue at graded washes (`SurfaceAlphas.washBorder/washChip/washControl`
  plus the `tint` fill) for the card fill, border, persona chip and CTA
  pill, so the banner's state reads before a word is (celebrate green,
  restart teal, nudge ember, roast the hand-authored `GoalAccentHues.neon`
  lime). Rendered in a single **shell-level dock** (`GoalBannerDock`,
  mounted in `beamer_app.dart`) — one rotating slot at the bottom of the
  content region on desktop (beside the sidebar) and above the bottom nav
  on mobile, on the main working tabs only (Tasks, DailyOS, Habits). One
  shared rotation state cycles every standing banner ~15s each; a fresh
  acknowledgment (a re-run) jumps the queue;
  hover/touch and app-backgrounding pause the cycle; the dock collapses to
  nothing when no goal is speaking. Every dock tenant NAMES its goal — the
  persona chip and a goal-title caption above the headline, on the desktop
  and compact (bottom) docks alike, so the voice is never anonymous; the
  reserved-lane math (`goalBannerDockReservedHeight`) covers the chip and
  caption. The goal detail page shows that goal's
  banners uncycled via `GoalBannerCard` directly — and applies NO snooze
  filter: snoozes, day dismissals and the optimistic local echo quiet the
  SHELL dock only (`goalBannerShellHiddenUntil`), while the page keeps the
  banner captioned with a live countdown until it returns to the bar
  (`goal-banner-shell-return-countdown`, the shared `WakeCountdownState`
  tick). Tapping a banner opens
  its goal's detail page (the banner→conversation flow); the star button
  — rendered only while an outcome is due — opens the per-activation
  rating prompt (one outcome per activation, skips count). Snooze is the
  prominent visibility action and opens fixed 1/3/6/8-hour choices as
  compact secondary duration chips. The
  de-emphasized final action dismisses the banner only for the current local
  calendar day; there is no direct X or swipe-to-dismiss shortcut.

  ```mermaid
  stateDiagram-v2
      [*] --> shown
      shown --> snoozed: choose 1h / 3h / 6h / 8h
      snoozed --> shown: deadline reached or app resumes after it
      shown --> dismissedForDay: choose Dismiss for today
      dismissedForDay --> shown: next local calendar day
      shown --> snoozed: chat chooses another future instant
  ```

  Every visibility choice persists on the `GoalNudgeEntity`: the effective
  `snoozedUntil`, `lastSnoozeDuration`, and `dismissedForDayAt` drive current
  projection state. Each snooze appends a `GoalNudgeSnooze` carrying its
  activation, start/deadline, exact duration in minutes, and the offset at the
  time of the choice. Each day dismissal likewise appends a
  `GoalNudgeDayDismissal` with its activation, start, local-midnight deadline,
  and local offset. Both histories are stable-id, append-only sync
  accumulators. The provider checks persisted state on every load and app
  resume, and also invalidates itself at the next snooze or local-midnight
  boundary, so expiry while the app is closed is handled without trusting a
  timer that did not run. Interaction writes return the exact persisted quiet
  deadline to optimistic local suppression, so a transaction crossing midnight
  cannot extend a day dismissal into the following day. That temporary local
  suppression is activation-scoped: a concurrent re-run of the same row id is
  immediately visible instead of inheriting the prior activation's quiet
  interval. Synchronized snooze
  and day-dismissal histories accept only timestamps with explicit UTC markers
  or numeric offsets, keeping expiry and learned local-hour evidence
  replica-independent. `GoalFactsRenderer` summarizes duration, local start,
  requested-return hour, weekday, and recent choices under
  `ads.snoozeBehavior`, and summarizes day-dismissal local hours, weekdays, and
  recent quiet intervals under `ads.dismissalBehavior`. Repeated interaction
  hours are evidence for future initial display timing, not an automatic
  scheduling command.
  Exposure is measured in visibility episodes by
  `GoalBannerExposureTracker` gated on THREE signals — the tracker's
  stopwatch runs only while the app lifecycle is `resumed`, `TickerMode`
  reports the host tab on screen, AND the banner intersects its enclosing
  viewport (rechecked on scroll events, lifecycle changes and post-rebuild
  frames, never per frame; the dock and other non-scrollable hosts use the
  other two signals alone). Every
  visible→hidden transition — backgrounding, tab switch, scroll-out,
  unmount — flushes its own episode into the per-host G-counters, so
  returning starts a new episode. Writes per nudge are serialized in
  `GoalNudgeInteractions` so a rapid flush/visibility-action pair cannot lose an
  update to a stale read.
  The dock and the full detail card both render the selected animation through
  `GoalBannerAnimatedText`; the dock and its animated tenant span their host,
  and both desktop and compact docks show the complete authored headline with
  no avatar, secondary tagline, or line cap; compact snooze remains at the
  trailing edge. A chat-requested snooze accepts an arbitrary future duration
  or date/time and automatically restores the exact banner at that deadline.
  The card keeps `cardPadding` on its lateral and bottom edges but uses
  `spacing.step2` above the fixed-height action header, preventing the rating
  and snooze tap targets from creating a visually double-padded top edge.
- **The goal detail surface** (hosted by the unified Goals tab under
  `/goals/details/:agentId`): per-goal health at a glance — a coarse-health
  chip
  (`coarseHealthOf` collapses the runtime `GoalTrackStatus` into Healthy /
  Behind / Restarting / Not enough data; `recovering` reads Restarting, never
  a failure), the report one-liner, a pending-proposal badge and a trend
  arrow (`GoalHealthDirection`, computed in `goalAgentHealthProvider` from the
  two most-recent non-deleted registers for the ACTIVE spec version with a
  0.02 deadband — withheld when either register is insufficient-data, and only
  for rolling-window goals, since calendar/day windows reset attainment each
  period and a consecutive-register delta there is a boundary reset, not a
  decline). The detail header surfaces that independent direction as a second
  semantic pill, allowing combinations such as Behind + Trending up and
  Healthy + Trending down. The row shows a coarse chip rather than a raw attainment
  percentage; the one-liner is the agent's own prose, so keeping percentages
  out of it is a matter for the agent's instructions, not widget-level
  filtering. Below the one-liner a rolling-window habit goal shows a
  deterministic hint — days-to-recovery when behind (`deficit`) or the buffer
  before the oldest success ages out when exactly at rate (`buffer`; surplus
  completions do not receive an aging warning) — lifted from the
  root leaf to `GoalEvaluation`, persisted on the `goalProgress` register, and
  surfaced through `goalAgentHealthProvider`. A row whose per-agent
  health has not resolved shows no chip rather than a false "Not enough data",
  and the settled-empty state is a first-run explainer whose CTA is the sole
  creation affordance (the global FAB hides). When a spec is available,
  `goalAgentProgressViewProvider` reads the evaluator's daily aggregates and
  adds a seven-cell compact strip to the list — at the detail page's day-cell
  size, so the two surfaces draw the same instrument at the same scale (the
  strip's earlier 12px list default read as illegible dots). The detail page
  is the §4b dashboard: a centered column capped at the unified-Goals
  measure (`kUnifiedGoalsContentMaxWidth`) whose hero stack puts the
  deterministic This-week card (`GoalThisWeekCard` — whole-goal strip,
  Reflect-on-today, yesterday tally) above the timestamped Agent's-read
  card, both at the full content width on every viewport,
  with the Habits and Signals sections beneath (habit cards name the other
  goals sharing them via `goalHabitMembershipsProvider` — one recording,
  reflected everywhere), a goal-scoped completion-rate chart (`HabitsChartCard(habitIds: …)` — the shared card
  computed on the goal's slice of the habits day maps via
  `scopeHabitsStateToHabits`, same range tabs), and the cost/automation
  plumbing riding the read card itself. The read card wears the SAME
  "intelligence" panel as the task agent section on Task Details — the
  shared `aiCardDecoration` chrome and `TldrHeader`, the shared
  `AgentAutomationRow` reload affordances, and the goal's cumulative
  inference cost pills (`GoalAgentLifetimePills`) in its footer — one
  panel language, changed in one place for both. A refresh that DIES
  (provider out of credits, network down, the executor timeout) says so on
  the card: it watches `goalReportWakeOutcomeProvider` — report-refresh and
  escalation wakes only, so a failed chat run or a passing Phase A
  subscription tick can neither raise nor clear the line — and renders the
  last failure's reason in an error line above the automation row. The line
  hides while a report wake runs (`goalReportWakeInFlightProvider`: the
  refresh workspace or any `goal-escalation:` workspace — never the
  agent-wide flag, which every chat and subscription tick flips), clears on
  the next completed report wake, and yields to durable evidence newer than
  the failure's start: a `reportFreshAt` watermark (a successful refresh,
  local or synced) or a displayed report published later — a timed-out
  executor is allowed to finish late, and its report must not sit beside
  its own stale timeout error. Fourteen silent 429s once read
  as a dead button. The page has ONE time
  range: a picker on the first evidence heading (Habits, or Signals for a
  signal-only goal; backed by the habits controller's shared
  `timeSpanDays`) keys `goalAgentProgressViewForSpanProvider`, which
  renders the whole-goal strip and every habit and signal day track over
  the same span ending today. Every extended track is a trailing-anchored
  (`reverse: true`) scroller joined to one `LinkedScrollGroup`, so a span
  wider than the viewport opens with today on screen and every track
  scrolls in unison — the same date stays vertically aligned down the
  page, chart included. Aggregates never fold the rendered list — the
  evaluator's numbers win — so a longer rendering cannot change a verdict,
  and the ages-out ring anchors at the window's own first day rather than
  the list head. The
  reading measure applies to the content *inside* the scroll view, never to
  the scroll view itself. The detail page builds **eagerly** — a `Column`
  in a `SingleChildScrollView`, never a lazy list: its section count is
  small and bounded, lazy mounting made scrolling janky, and a scrolled-away
  lazy section could unmount the `ensureVisible` anchor the banner CTA
  scrolls to. The detail page expands the
  same source into a habit grid or metric series using each leaf criterion's
  actual day/rolling/week/month range. Canonical weight data uses the shared
  time-series line treatment, while paired systolic and diastolic dimensions
  render as one dual-line blood-pressure chart with both authored targets;
  a partial blood-pressure import remains two separate cards so the available
  component is not hidden. Singleton health series render a visible point until
  a second observation can form a line. These daily health charts format their
  canonical midnight-UTC keys as date-only values, so devices west of UTC do
  not shift a goal day backward in tooltips or the shared date axis. Other
  numeric dimensions retain the progress-bar series. Rolling habit projections keep the
  immediately preceding slipped day separate from active-period arithmetic,
  and periods longer than seven days scroll horizontally instead of being
  relabelled as a trailing week. Every surface that marks a single metric day
  — the bars, the compact strip cells, the reflection sheet's per-dimension
  marks, and the composite card's met-yesterday tally — shares one policy
  (`GoalMetricProgressView.dayMark`): where the target is a per-day quantity
  (`dailySumThenAverage` and the point samples) the day's own value decides
  the mark, so a 12,400-step day beats a 10,000 target even inside a weak
  week; where the target belongs to the whole period (`sum`, `count`) the
  mark is the evaluator's verdict for the window ending that day, because a
  single day's contribution cannot be judged against a period total.
  Composite detail keeps every metric and measurable
  leaf instead of silently collapsing the evidence to the first one, and the
  habit-only legend is omitted when no habit grid is rendered. The compact
  strip combines that per-day policy with daily accomplishment: a metric cell
  is green when `dayMark` holds, and a habit-composite cell when the authored
  `allOf`, `anyOf`, or `atLeastCount` tree folds
  to true over that day's habit completions. A fully completed routine day can
  therefore be green while the current goal remains Behind or Restarting.
  Numeric leaves still respect `atLeast` versus `atMost` direction, and missing
  samples never count as successful days. Both the compact strip and the
  detail day cells are tri-state (`GoalCompactDayState`): the
  `alert.success` family at full strength when the goal requirement held as
  of that day, the same hue at `SurfaceAlphas.muted` (no new token) plus a
  full-strength inner dot — the non-color cue — for a partial success (the
  routine was kept while the window target was still building), and neutral
  otherwise. Day states never wear the interactive teal: data-that-happened
  and things-you-tap are different greens, `recovering` chips read in the
  info hue rather than a second green, the ages-out ring is a quiet
  `text.lowEmphasis` outline (never warning orange on an on-track row), and
  the deterministic days-to-healthy countdown is neutral prose — the
  header's verdict caption alone carries warning ink. ONE legend renders per
  page after the last habit card, and it is truthful: the today swatch is
  dashed like the cell, the partial swatch carries the dot. Each day square
  shows its concrete date in a hover/long-press tooltip (the same localized
  string as its semantics), and the Success/Missed menu opens with the
  selected day's date as a disabled header row; a day cell's visual stays at
  the compact chip size while its interactive slot meets
  `TapTargets.minimum` vertically. Weekday labels render directly above
  their squares inside ONE shared horizontal scroller, so labels and cells
  cannot drift apart; the reliability tail is captioned in weeks ("N / 6
  weeks"). The composite "whole goal" card labels its strip's time frame
  ("Last 7 days") and its summary counts dimensions with an explicit
  "Yesterday:" frame, so the day-dots and the dimension arithmetic stop
  reading as one contradictory statistic. Point-sample health headers (weight, blood pressure — the
  `GoalHealthDataTypes.supported` set) quote the LATEST observation while
  the persisted evaluator result stays on its rolling-average basis. If the
  latest observation was recorded today and meets the target, the card uses a
  positive daily status and encouragement; otherwise an over-target rolling
  average still shows Needs attention, including when today is unmeasured.
  Aggregate dimensions keep quoting their period aggregate. When a
  health/measurable
  dimension records an observation today and a habit whose name shares a
  distinctive whole word with it (generic words excluded — see
  `_genericNameTokens` in `goal_progress_view.dart`) has no outcome for
  today, the habit card offers a one-tap "Mark done" through the same
  completion service; category-time dimensions never trigger the suggestion
  because their days are observed by definition.
  The provider invalidates itself at the next local midnight so Today,
  ages-out and window boundaries cannot remain stuck on yesterday. The data
  dimensions render under a Signals heading whose footnote states the
  deterministic freshness contract (live within seconds, bounded to what is
  listed). A reliability tail is shown
  only for an authored rolling-seven-day habit; other windows do not reinterpret
  their period as weekly reliability. Every
  habit day in that grid — including previous days — opens success/missed
  actions only when the selected day lies inside the habit's active lifetime
  and is not in the future; future calendar cells stay read-only and the
  persistence service enforces the same boundary.
  Both the detail callback and persistence service gate edits on an active goal
  identity, so a dormant or destroyed direct route cannot mutate habit history.
  Selecting the already-recorded outcome is a no-op. The write goes through
  `GoalHabitCompletionService` into the existing habit-completion path, so
  privacy, sync and reminder behavior remain shared. Historical corrections
  keep the selected calendar day but use the current wall-clock fields so
  deterministic entry ids do not collide when an outcome is changed back.
  The resulting local journal signal wakes Phase A immediately. When the
  register changes, Phase A marks the report stale and joins the shared
  two-minute fact-grounded refresh countdown; the progress evidence therefore
  updates immediately while model work remains coalesced. The shared controls
  keep Update now available beside the countdown, offer Skip once without
  disabling later automatic updates, and show the running state while the
  active agent works. They are absent after the goal leaves the active
  lifecycle.
  The detail page groups the agent's voice at the top: the standing report
  and this goal's active banners (`_AgentSayingSection`) sit directly under
  the goal definition header, with the automation controls BELOW the report
  they describe, the progress evidence — habit cards first, then charts —
  below them, and, only while active, the revision-approval card
  (`ChangeSetSummaryCard.selfTargeted`).

  The report card hides its Show more toggle when the full text is identical
  to the TLDR **and** the report carries no renderable structured sections.
  Sections live in provenance rather than in `content`, so a report whose
  flat text happens to equal its TLDR would otherwise lose the toggle and
  make its sections unreachable. The goal statement is explicitly labelled ("Your goal") so it
  cannot read as a status claim against the health chip, the persona chip
  anchors to the title's first line, the app bar reveals the goal name only
  after the header scrolls away (no doubled title in one viewport), and
  phones get a persistent chat action in the app bar. On the detail page a
  banner's CTA performs its verb instead of navigating to the current route:
  `GoalBannerCard.onCtaPressed` opens `GoalLogTodaySheet` — one-tap Mark
  done per habit through the shared completion path, read-only rows naming
  the update source for data dimensions — falling back to an anchor-scroll
  to the evidence for goals without habit dimensions. The chat pane's
  subtitle is the coarse-health label, current state rather than the
  aspiration statement. Mobile opens durable conversation
  at `/goals/details/:agentId/chat`; desktop hosts the same
  `GoalAgentChatPane` in a ~400px **non-modal overlay drawer**
  (`kGoalChatDrawerWidth`): it slides over the dashboard without reflow,
  stays mounted while closed so the draft survives, closes on Esc, ×, or an
  outside tap (a shared `TapRegion` group keeps the Talk-to and Ask-why
  openers from counting as outside), and its header carries the same
  `UnifiedGoalStatusPill` as the page so the two can never disagree. The
  Agent's-read card's Ask-why link opens that conversation pre-filled with
  the computed status (never clobbering an existing draft); the card also
  carries the read's "as of" age, self-demoting to the out-of-date notice
  when the runtime marks the report stale. The mobile route mounts the composer only
  for an active goal identity, shows the coarse-health label (current state,
  never the aspiration statement) in its compact
  chat header, and persists the detail
  route after system/gesture back. **Every one of a goal's own pages — detail,
  chat, create and edit — slides the mobile bottom nav away**
  (`goalsRouteHidesBottomNav`; the `/goals` list root keeps it), because each
  docks its own surface at the bottom edge: the day-assessment sheet's record
  button and the wizards' pinned Continue band. Hiding the bar also stops it
  being reserved, so those surfaces reach the edge instead of floating above a
  bar-sized gutter — see
  [navigation](../architecture/navigation.md#chrome-rules-are-pure-functions-of-router-state).
  The visible reply list owns its measured heights
  (`_AgentChatViewState._measuredHeights`, keyed by message id): a collapsible
  reply's clamp is height-measured, `ListView.builder` disposes an item's State
  once it leaves the cache extent, and an item that came back without its
  measurement rendered full-height for one frame — which grew the content above
  the viewport and made the list jump on every re-entry.
  `agentChatProjectionProvider`
  filters and sorts the log first, retains the latest fifty durable visible
  candidates, and only then reads their payloads (no automatic `runKey`);
  projected turns are user messages and content-bearing `reply_to_user` actions;
  thoughts, system FACTS, legacy run-scoped FACTS rows, and tool bookkeeping
  never enter the visible history. Visible replies pass through the report
  sanitizer before persistence, so internal ids and annotations cannot leak
  into chat. Draft state is keep-alive per agent, waiting comes from the wake
  completion, and failure keeps the source turn available for retry by
  re-enqueueing its existing message id rather than duplicating it. A failure
  before the durable append returns an id retries by sending the retained draft
  as a new durable turn. The chat service rechecks active goal identity before
  writing that source turn. Payload ownership is checked before inference, chat failures
  cannot re-arm scheduled escalations, and a user wake cannot complete without
  a visible reply. Agent turns render through `AgentMarkdownView`; a long
  reply starts collapsed to a bounded-height clipped viewport with a bottom
  fade and a localized Show more / Show less control, while user turns stay
  literal. The collapse is HEIGHT-measured, never `maxLines`-based:
  `GptMarkdown` renders block elements as `WidgetSpan`s that each count as
  one "line", so a line clamp never bites on markdown-heavy replies — the
  toggle appears exactly when the laid-out content overflows the collapsed
  viewport, so it can never be a visible no-op. Goal FACTS include the local timestamp, UTC offset, and time-zone name
  beside their canonical UTC generation time, allowing relative snooze requests
  to be interpreted against the user's clock. A successful chat wake explicitly
  invalidates the visible-chat, active-banner, and history projections because
  workflow writes bypass the
  interaction notifier; the colored card therefore appears in the mounted
  desktop split without a route round-trip. Interactive reply payload/message
  ids are deterministic per `(agentId, runKey)`; if the output transaction
  committed and only the deferred outbox flush failed, the reply is re-read as
  the commit marker and the turn completes without another billed inference.
  Creation and owner editing share one route through the same controls.
  Creation is a three-stage intention → mapping → confirmation flow; owner
  editing skips the intention stage — the statement is a single-line field
  (with the example pills) at the top of the mapping page — so editing is two
  steps, and the step indicator renders the count of the steps actually
  walked. The mapping stage matches observable active habits and
  the supported steps metric, gives every selected habit its own one-to-seven
  rolling-week cadence, can add a searchable existing measurable with a
  numeric rolling-week target, and offers Weight or one Blood pressure source
  that expands to separate systolic and diastolic targets. Every health target
  chooses `at least` or `no more than` and uses a rolling seven-day average.
  The same controls load during owner editing, retain existing criterion ids,
  and expose `all`, `any`, or `at least N` when multiple dimensions are
  selected. The combination sheet applies every choice to the page
  immediately while rendering from local mirrors, and stays open until the
  explicit Done (or a dismiss gesture) — the at-least stepper adjusts the
  count on its own full-width line without dismissing the sheet. An empty measurable library links to the
  existing measurable setup flow. Mapping waits for the active-habit snapshot before caching a
  match, uses whole-word matching that excludes generic cadence terms, and
  explicitly refuses an intention for which no observable proxy exists.
  **Both word lists the matcher subtracts — the generic cadence terms and the
  bookkeeping verbs — come from the ARB catalogs
  (`goalFormGenericIntentionWords`, `goalFormMeasurementVerbs`), not from Dart
  constants.** They are matched against text the user wrote in their own
  language, so an English-only list silently disables matching in every other
  locale. An intention naming a health capability pre-selects that signal, and
  a habit whose entire name is the health label plus a bookkeeping verb
  ("Measure blood pressure", "Gewicht messen") is demoted to an unchecked
  suggestion so the goal never watches one reading twice; a habit with any
  other distinctive word left over ("Weight training") is a real habit and
  keeps its selection.
  Existing criteria outside the form's representable range stay losslessly
  read-only. Before creation or editing saves, every selected habit is checked
  through an unfiltered integrity lookup. This retains an active private habit
  already authored into the goal without exposing it in discovery, while any
  selected habit confirmed deleted or inactive is removed before save.
  Confirmation names the goal and its
  conversational persona and states the inference-cost contract. Editing opens
  only for active goal agents, preloads the current values, explains the next
  immutable version, and preserves version history. A successful owner edit
  exhaustively retracts pending and partially-resolved agent-authored
  goal-revision proposals based on the old version and invalidates the mounted
  proposal-card projection. The persisted base-version fence independently
  prevents a proposal synced in later from overwriting the owner's newer
  intent. If disconnected replicas independently mint the same successor
  ordinal, revision ids mark direct owner authorship and the type-specific head
  resolver deterministically chooses owner intent over an agent-proposal
  approval; a genuinely higher spec ordinal still wins. A supported MULTI-habit
  routine is stored as an `allOf` composite;
  when another writer moves the spec head first, the stale editor returns to
  the refreshed goal details instead of retrying against the obsolete base;
  deletion cancels queued work, aborts an in-flight local wake, and soft-retires
  the whole agent through
  `GoalAgentService.deleteGoalAgent`. The shared drain lifecycle guard rejects
  any queued non-active goal wake that survives a race or arrives from sync and
  emits an aborted completion, so an interactive caller never waits forever for
  a lifecycle-dropped request. Every explicit cancellation or superseding queue
  removal emits the same aborted completion, so a waiting interactive caller
  also terminates. A source-message append that committed before an outbox error
  is reconciled by id and reused rather than duplicated. Deletion first performs
  the durable lifecycle transition; only a successful transition cancels queued
  work, aborts an in-flight wake, and removes the goal's in-memory signal
  subscription, preventing future matching journal updates from
  repeatedly enqueueing work that the lifecycle guard would only discard.
  Goal-list rows and banner semantics resolve the active spec title; the
  identity display name remains the conversational persona used by chat.
  The current form represents rolling habit quotas, linked measurable targets,
  weight and blood-pressure targets, tracked category hours, composite rules,
  and the supported steps metric. Category-time criteria with an optional
  local time band and other quantitative health criteria remain read-only when
  already authored; they still render as typed dimension cards. Direct daily
  assessment is available on detail, while an
  agent-suggested assessment still needs its approval UI.
- **Tracked time invalidates without churning wakes.** Category-time leaves
  observe the journal, link, task, category and privacy notifications used by
  Insights, but those mutations only advance the durable report-stale
  watermark. They do not queue Phase A or inference for every timer edit. The
  existing 06:00 cadence evaluates accumulated changes automatically, while
  Update now remains the explicit immediate report path. A deterministic
  cadence pass may refresh progress registers but does not clear the stale
  badge unless a report-producing wake durably replaces the standing report.
  Synced category-time journal facts re-advance the watermark on their receiving
  device, including when they arrive after an earlier Update now. Habit and
  measured-data signals stay immediate because each write is a bounded
  observation.
- **Conversation scope is the goal.** The contract identifies the agent as a
  dedicated coach rather than a general assistant. Coding, trivia and other
  unrelated requests receive a short purpose reminder and a redirect to the
  goal; the agent does not attempt the off-topic answer. Chat entry points are
  mounted only for active goal agents. If the spec head moves while an
  interactive inference is running, output fencing fails the wake so the
  durable user turn remains retryable instead of completing without a reply.
  The chat composer reuses the shared `chatRecorderControllerProvider` (the
  same recorder the task-agent evolution chat uses) for voice input: a mic
  trailing icon, waveform with cancel/stop, streaming partial transcript, and
  auto-fill on completion. The recorder watch lives inside `_ChatComposer`
  (a `ConsumerWidget`) so the 10 Hz amplitude stream rebuilds only the
  composer subtree, not the full message list.

  ```mermaid
  stateDiagram-v2
      [*] --> idle
      idle --> recording: tap mic (no text)
      recording --> processing: stop
      recording --> idle: cancel
      processing --> idle: transcript ready (auto-fills draft)
      processing --> idle: error (localized toast)
  ```

- **Standing reports and governance remain visible.** The detail page always
  renders the report referenced by the authoritative current-scope report head;
  a delayed historical row cannot displace it merely by carrying a later local
  timestamp. Active banner interactions appear after the report rather than
  replacing it. Its top-level pills query the AI-consumption ledger
  by `agentId` over the full recorded lifetime. The shared consumption pill is
  the same component used by Task Details: provider-reported Melious credits,
  energy and carbon when available, otherwise tokens, with water and the full
  breakdown and localized compute duration in the tooltip. A second pill sums
  recorded invocation duration as lifetime compute time, including a localized
  sub-minute threshold. The compute-time pill is withheld when legacy usage has
  no positive recorded duration. No model price table or invented monetary
  estimate is involved.
- **Agent Internals attributes only actual inference.** Conversation wake rows
  resolve their model from persisted token usage first, then the wake-run
  snapshot. A source-only user-message thread has no model label: it did not run
  Gemini (or any model), while the separately enqueued goal wake can correctly
  show GLM. Live agent config is never projected backward onto a source turn.
- **Interaction writes bypass the notifier by design** (they go through
  the sync service): the banner handlers invalidate
  `activeGoalNudgesProvider` after snooze/day-dismiss/rate.

- **The unified Goals surface (phase 1, flag `enable_unified_goals`)**:
  `ui/pages/unified_goals_page.dart` merges the Habits and Goal Agents
  tabs into one goal-centric list at `/goals`, in the Habits nav slot —
  the Habits page's visual language (Done-today card, due/later/done/all
  filter tabs, consistency heatmap, completion-rate chart) with one
  expanded card per goal (`ui/unified/unified_goal_card.dart`). Cards
  carry a four-pill status vocabulary
  (`ui/unified/unified_goal_status.dart`: On track / At risk / Behind /
  No data, collapsed from `GoalTrackStatus`; `recovering` reads as At
  risk with the deterministic recovery hint folded into the pill), a
  templated summary computed locally (never generated prose — it cannot
  go stale), and the shared `HabitActionRow` per habit dimension. Row
  done-state uses **success-only** completions (`successfulByDay[today]`,
  not `successfulToday`, which also counts skips) because goal criteria
  credit only real successes; the page reads the category-UNFILTERED
  buckets (`openNowAll` etc.) so it cannot inherit the Habits tab's
  hidden category filter, and every filter branch intersects with
  `GoalHabitCompletionService.isRecordableDay` — the recording path's own
  lifecycle gate (active flag plus the activeFrom/activeUntil window) — so
  no row offers a quick-complete the service would reject. Habits that no goal's criteria tree claims
  (`goalCriterionHabitIds`) render in a "not in a goal" group — gated on
  every per-goal health having resolved, so cached habits never flash in
  as ungrouped. `GoalsLocation` is the sole host of the detail/chat/wizard
  pages, all under `/goals/...` paths built by the plain helpers in
  `goal_routes.dart` (see [navigation](../architecture/navigation.md)); the
  never-released `/agents` twin tab was removed after this surface landed.

## Gotchas

- `agent_wiring.dart` silently routes unregistered kinds to the
  task-agent workflow; the bootstrap merges the Daily OS and Goals runner
  maps, and `test/app_bootstrap_test.dart` pins both registrations — do
  not turn that merge back into a replacement.
- Subscriptions are in-memory: `GoalRuntimeMaintenance.restoreSubscriptions`
  rebuilds them at startup, and `onIdentityReceived` (the
  `AgentRuntimeMaintenance` hook the sync processor offers every
  contributor) mirrors a goal agent synced in mid-session.
- Imported workout rules currently produce metric leaves whose dataTypes
  only match `QuantitativeEntry` rows; workout-entry signals are a
  documented follow-up.

## Related

- [Agents](agents/) — the shared runtime this plugs into.
- [Daily OS](daily_os_next/) — the reference plug-in implementation.
- ADRs 0053–0058 in `docs/adr/` — the decision record for this feature.
