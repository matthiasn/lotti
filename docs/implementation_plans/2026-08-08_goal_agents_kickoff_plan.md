# Goal-Driven Agents — Kickoff Plan (Phase 1–4 roadmap)

- Status: Approved 2026-08-08 (kickoff session)
- Deliverables of this plan: Phase-1 assessment, ADR drafts 0053–0057, goal-agent eval harness +
  pure-Dart goal core, Phase-3 design spec, reusable-chat requirements doc
- Companion documents (produced by executing this plan):
  `2026-08-08_goal_agents_phase1_assessment.md`, `2026-08-08_goal_agents_design.md`,
  `2026-08-08_reusable_chat_interface_requirements.md`, `docs/evaluations/goal_agent_models/README.md`

## Context

Lotti already has a task-agent framework (wakes, templates/constitution per ADR 0052, an eval
harness with its first discriminating scenario). The user wants a new **goal-driven agent**
feature: one long-running, mostly dormant agent per user goal (e.g. "10k steps/day average",
"gym 3×/week"), architecturally viable over a 10-year horizon. Core behaviors: time- and
data-triggered wakes; visual "ad" banners (image-generated via Nano Banana Pro) when off-track;
tap-to-open ongoing conversation (voice-capable); goal evolution through dialogue; habit
completions re-validate ad relevance; memory/compaction so history stays browsable without
polluting model context.

Hard constraints: **GDPR zero-data-retention at all third-party processors** for text/agent
inference, and **low inference cost** (evals must report cost per call, reusing the Melious.ai
cost data already surfaced in-app). **Exception, per user 2026-08-08:** ZDR cannot be enforced
for Nano Banana (image generation). Mitigation is strict data minimization: the outbound request
carries ONLY the self-contained visual brief for the image — zero user background, zero personal
data, zero goal/conversation context beyond what the picture itself needs. Need-to-know, enforced
structurally (the image tool accepts a standalone brief string; it never receives entities,
history, or health values) and checked by an eval that asserts composed image requests leak no
personal data from the fixture world.

This session is a kickoff: analysis and design first, production code only where the plan says so
(eval harness extensions). Deliverables double as raw material for a blog post/stream, so
decisions must be documented and explainable (ADRs + implementation plan docs).

## Deliverables (the user's four phases)

1. **Phase 1 — Written audit & assessment** of the existing agentic data model, wake/runtime,
   evolution cycle, memory/compaction: what works, what extends, what needs redesign, plus a
   proposed extended data model. → `docs/implementation_plans/2026-08-08_goal_agents_phase1_assessment.md`
2. **Phase 2 — Evaluation plan + harness extension (code)** for goal progression, ad relevance,
   evolution dialogue, trigger decisions; multi-model matrix (GLM 5.2 + alternatives); cost per
   call in every report; manual invocation only.
3. **Phase 3 — Design specs** (docs, scaffolding only where cheap and obviously right): wake
   triggers, ad pipeline (decision → Nano Banana Pro → optional verification → banner), banner/
   carousel presentation model, goal evolution, memory/compaction for 10 years.
4. **Phase 4 — Requirements doc** for the reusable chat interface (no build this session).

## Findings from exploration

### B. AI infra, evals, cost (report received)

**Naming**: provider is **Melious.ai** (`api.melious.ai`), repo spells it `melious` — not "meious".

**Eval harness — three families, none complete alone:**
- Task-agent inference eval (synthetic context, declarative scenarios): `test/features/ai/eval/support/local_task_agent_inference_eval.dart` (+ `_test.dart` fixtures). Rich assertion vocabulary: `expectedToolCalls`, `requiredReportTermGroups`, `forbiddenToolNames`, `forbiddenToolArgumentTerms`…
- Penguin-wake workflow eval (real in-memory `JournalDb`/`AgentDatabase`, real `TaskAgentWorkflow`, world seeded from `ManualDemoWorld.penguinLogistics`): `test/features/ai/eval/penguin_wake_workflow_eval_live_test.dart` + `support/task_agent_workflow_eval_harness.dart` + `support/penguin_wake_scenarios.dart`. Scenario = situation over shared world (`expectsProposals`, `expectsReport`, `forbiddenToolNames`); asserts on DB rows, not model text. 3 scenarios: requalification, noOp, pendingProposal.
- Day-planning eval framework (best engineering: matrix scenario×model×variant×sample, leaderboard, constraint scorers classified objective/mixed/heuristic, judge bundles, cost rows): `test/features/daily_os_next/eval/framework/{eval_scenario,eval_runner,eval_report,eval_variant}.dart`.
- Run mechanics: no make targets; env-gated `@Tags(['eval-live'])` tests + shell scripts (`scripts/penguin_wake_eval_matrix.sh` — model list `glm-5.2 kimi-k3 qwen3.5-397b-a17b qwen3.6-27b qwen3.6-35b-a3b deepseek-v4-flash-0731`; `tool/melious_task_agent_model_eval.sh`). One process per (model,sample) because GetIt is global. Results → JSON/MD artifacts; durable archive in private `matthiasn/lotti-ai-evals`.
- Judging: deterministic DB asserts with named traps (INVENTED WORK, FABRICATION, CHURN…), LLM rubric judge (`tool/task_agent_model_eval_judge.py`, qwen3.5-122b judge, **diagnostic only**), constraint scorers. Methodology rules in `docs/evaluations/task_agent_models/README.md` (assert mutations via expectedToolCalls; suspicious of scenarios all models fail/pass; samples 1–3 = noise caveat).
- 7 evolved-directive scenarios exist (`LOCAL_TASK_AGENT_EVAL_EVOLVED_DIRECTIVES=1`) — closest analogue to goal-evolution dialogue evals.

**Cost:** Only Melious reports cost, only on the **non-streaming** path (`InferenceImpactCollector`, `MeliousCallImpact` — credits + energy/CO2/water). Persisted per-call as `AiConsumptionEvent` (`lib/features/ai_consumption/model/ai_consumption_event.dart`: agentId, wakeRunKey, tokens, credits, costCreditsDecimal, energy…) in synced `ai_consumption.sqlite`; EUR presentation via `formatCredits` (`consumption_formatting.dart` — € is presentation only). **Gap:** `EvalReport._costRows` sums tokens but ignores `credits` (~30-line fix); task-agent eval results carry no credits at all; penguin harness generates consumption events but the artifact writer drops them. The Python judge already reports credits — pattern exists. Only-Melious-reports-cost means multi-provider cost comparison needs a pricing table (doesn't exist).

**Models/providers:** `InferenceProviderType` enum has 14 providers incl. `melious`, `gemini`. GLM 5.2 = `glm-5.2` (Melious), already the FTUE "advanced thinking" default and eval default. Melious catalog also: deepseek-v4-{pro,flash}, qwen3.5-122b-a10b, minimax-m2.7, mistral-small-4, gemma-4, voxtral, whisper, `flux-2-klein-9b` (image). Per-feature model selection = AI profiles (`AiConfig.inferenceProfile`: thinkingModelId, thinkingHighEndModelId, imageGenerationModelId, transcriptionModelId…); agents pick profile via `AgentConfig(profileId:)`.

**Image generation exists end-to-end (as a skill, NOT a model-callable tool):**
- **Nano Banana Pro already catalogued**: `models/gemini-3-pro-image-preview` = "Gemini 3 Pro Image (Nano Banana Pro)" under `InferenceProviderType.gemini` (direct Google), `known_models_data.dart:390`. Supports reference images. Melious `flux-2-klein-9b` also does image gen (no reference images, hardcoded 1792×1008).
- Path: `SkillInferenceRunner.runImageGeneration()` → `CloudInferenceRepository.generateImage` (gemini/alibaba/melious branches) → `importGeneratedImageBytes()` (`lib/logic/image_import.dart:653`) → journal image entry + `task.data.coverArtId` + auto image analysis. Cost attribution free via `AiWorkType.imageGeneration`.
- Prior art for ad prompts: built-in skill "Generate Cover Art (Flux)" (`built_in_skills.dart:148-215`) — compact visual brief, 16:9, no readable text/logos. Directly reusable style for ads.
- To make it a tool: `AgentToolDefinition` + name constant + dispatcher handler + decide `deferredTools` (user confirmation) vs inline + wake-fact gate.

**Verification patterns (2nd model checking 1st) already exist:** cross-model report editor (`task_agent_report_editor.dart` — Mistral draft → Qwen editor; deterministic preflight; defect enum with per-issue corrections), LLM rubric judge (diagnostic only), ADR 0034 pattern: deterministic validation gates output, one repair call, then typed failure.

**Tool/function-calling infra:** `AgentToolDefinition` registry (`agent_tool_registry.dart`), per-domain definition files, `ConversationRepository.sendMessage` loop + `ConversationStrategy` (TaskAgentStrategy, **EvolutionStrategy**, ProjectAgentStrategy, EventAgentStrategy). Tool-surface control: `TaskAgentWakeFacts` precondition gating (`task_agent_tool_gate.dart` — "a tool that cannot succeed is an invitation to invent its arguments"), staged exposure, ADR 0051 (agenda turns rejected on token arithmetic), ADR 0052 (constitution is code-owned; evolution only touches the customised residue).

**GDPR/ZDR:** No ZDR concept in code/config anywhere. `PRIVACY.md`: retention is the user's due-diligence; Melious claims no-training + EU jurisdiction, Lotti doesn't verify; "the setting is the consent". No DPA/retention attribute per provider. Known gaps: DBs and API keys unencrypted at rest. A hard ZDR constraint = new product requirement; a trigger-waking agent widens the consent surface → deserves an ADR.

**Voice/TTS:** ASR is record-first (no live streaming in app); transcription via Whisper/Voxtral/MLX etc. after file on disk. TTS fully on-device (Supertonic ONNX), off by default, currently only reads the agent report TL;DR (`ai_summary_card.dart:448`).

**Agent kinds today:** `task_agent`, `template_improver`, `project_agent`, `day_agent`, `event_agent` (`lib/features/agents/model/agent_constants.dart:5-10`). No goal/ad/banner/campaign concepts. Wake gating is app-side & deterministic (`WakeOrchestrator`, `WakeQueue`, `WakeSuppressionTracker`, `TaskAgentWakeFacts`) — no trigger-decision eval exists; ADR 0051 arithmetic argues against spending a model round-trip on wake decisions.

### A. Agents subsystem (report received)

**Headline: ADR 0023 (`docs/adr/0023-durable-domain-agents-and-time-negotiation.md`) already specifies
almost exactly this feature** — durable domain agents (fitness, sleep), self-scheduled, negotiating
with the planner. Status `Proposed`, zero code. The goal agent must be positioned as its
implementation or successor. Also: **`StandingAgreementEntity` is a fully modeled goal container
with NO producer and NO UI** (`agent_domain_entity.dart:516` — scope incl. `fitness`/`sleep`/
`finances`, cadence daily…yearly, enforcement preference/target/nonNegotiable, minCount/maxCount/
minMinutes, evidenceRefs, activeFrom/Until, rationale). Verify before inventing a parallel Goal entity.

**Data model:** one `agent.sqlite` (schema v19), 6 tables; everything is one freezed union
`AgentDomainEntity` (`fallbackUnion: 'unknown'` → forward-compatible). Variants incl. agent identity
(kind = free string), `AgentStateEntity` (nextWakeAt/sleepUntil/scheduledWakeAt, wakeCounter GCounter),
messages (threadId, prev-chain, content-addressed payloads, summaryDepth), reports (+head),
`ScheduledWakeEntity` (leaseHostId single-device election), `PlannerKnowledgeEntity` (keyed, hooked
≤120 chars, scoped, proposed→confirmed→retracted, **compaction-exempt** — the only "never dissolves"
memory tier; only day agent reads it), StandingAgreement, attention triple, templates+souls+versions+
heads, evolution sessions, ChangeSet/ChangeDecision. `AgentKinds` = free strings (no schema change for
`goal_agent`) BUT `AgentTemplateKind` is a **closed enum** (breaking change) and `wireWakeExecutor`
falls back to task-agent **silently** for unregistered kinds (`agent_runtime_registry.dart:33-43` trap).

**Binding precedents:** one identity per subject (task/day/project/event; `day_agent:<dayId>`) or one
identity over many subjects partitioned by `WakeJob.workspaceKey`. Durable link (`agent_task` AgentLink)
+ derived `AgentSlots.activeTaskId` + in-memory `AgentSubscription` rebuilt at startup
(`AgentRuntimeMaintenance.restoreSubscriptions()`).

**Wake mechanism:** evidence-triggered `WakeOrchestrator` on `localUpdateStream` (never re-wake on
synced receive): token match → vector-clock self-suppression → 120s throttle → merge/enqueue WakeJob
(deterministic runKey) → single-flight per agent → wake_run_log → executor. Time-based:
`ScheduledWakeManager` polls **hourly**; one `scheduledWakeAt` per agent or N `ScheduledWakeEntity`
per (agent, workspaceKey); **no recurrence model — each workflow re-arms manually**. `WakeReason` enum:
subscription/creation/reanalysis/scheduled/transcriptionComplete.

**Trigger tokens ALREADY EMITTED for our sources** (`lib/classes/journal_entities.dart:243-279`):
`HabitCompletionEntry` → `{habitId, habitCompletionNotification}`; `QuantitativeEntry` →
`{data.dataType}` e.g. `cumulative_step_count`; `WorkoutEntry` → workoutType. So step/habit triggers =
just new subscriptions. Health import batches coalesce via the 120s throttle.

**Runtime (one wake):** reconciled state → AgentWakeMemory capture (content-addressed delta vs input
frontier; soft-retraction) → template+soul+profile resolution → `compactAndAssemble(budget: 50000,
retainTokens: 20000)` → prompt: code-owned constitution scaffold + soul + template directive + report
directive; user msg stable-first (`## Task Log` = active summary + append-only tail; byte-identical
prefix invariant, property-tested) → ConversationRepository streaming loop (maxTurns 20) → forced
`update_report` retry if missing → cross-model report editor → WakeOutputWriter. Known flaws (all
documented): report churn on no-op wakes (4/5 models rewrite; ADR 0051 fix implemented but
**flag-off**, no production caller), full tool surface every turn, 50k/20k not profile-aware, forced-
report hack, `get_related_task_details` disabled (context pollution), fork healing flag-off.

**Evolution:** 3 layers (ADR 0052): code-owned constitution / template directive versions (user-
approved, rollback-able, `authoredBy` provenance — string-compare bug just fixed via
`AgentAuthors.isSystemAuthored`) / standing rules (**specified, unbuilt** — follow-up #2). Ritual:
improver agent extracts feedback (min 3 items) → `TemplateEvolutionWorkflow` multi-turn chat (voice
input + GenUI bridge with fixed 7-widget catalog) → approve mints new version + moves head; recap
entity; re-arm +feedbackWindowDays. Souls evolve on own axis across templates. Known flaws: whole-
directive rewrites (no diffs), no validation before store, custom report directive permanently
disables the model-tuned contract (silent), contradictory session prompt.

**Memory/compaction:** no memory blob — durable rows + fresh journal read per wake + derived layer.
Capture (ADR 0020) / prefix-coverage summary checkpoints (ADR 0017; die only when incomplete; folds
use the wake's own model; never destructive) / retention policy. "Writing away memories" maps to:
`record_observations` (priority/category), `PlannerKnowledgeEntity`, author-time memory links
(ADR 0026 `[[refines|supersedes|contradicts|relates:id]]`). **Read-back is asymmetric**: task log +
last-20 observations read back; prior report prose deliberately never injected; `search_memory` tool
EXISTS but wired **only for day agents** (`day_agent_tool_handlers.dart:270-347`); planner knowledge
not read by task agents; memory links write-only in practice. **Hard traps for 10y**: every wake reads
ALL observations then keeps 20 (`task_agent_execute.dart:201` + `context_builder.dart:686`);
observations pruned at 180 days; `maxAgentMessages: 20000` → agent **skipped entirely** by pruning
(deadlock: grows unbounded, never pruned); single rolling prose summary (summaryDepth exists, no
hierarchy); cold-prefill economics (50k budget sized for warm prefix cache; a once-daily goal agent is
almost always cold).

**History/UI decoupling already the norm:** v2 `PromptRecord` stores head+tail+summary marker; log
block re-derived by `WakePromptReconstructor` (converged, "semantically auditable not byte-exact").
UI surfaces are kind-agnostic and mostly free: `AgentInternalsBody` 5 tabs, `AgentConversationLog`,
`AgentListingShell`, pending-wakes tab, `SidebarWakeQueue`. Evolution chat = `EvolutionChatPage` with
voice + GenUI. Notification bridge exists (`ChangeSetNotificationService` → task suggestions inbox).

**Plug-in checklist for `goal_agent` kind** (reference impl: Daily OS, 76 lines,
`day_agent_workflow_providers.dart:57`): kind constant (trivial) / AgentTemplateKind enum value
(small, breaking) / GoalAgentWorkflow (large) / `agentWakeRunnersProvider` override in
`app_bootstrap.dart` (trivial; import direction enforced by arch test) / subscription-restoring
service implementing `AgentRuntimeMaintenance` (small) / ScheduledWakeEntity re-arm (small) / tools
via `AgentToolRegistry.goalAgentTools` + deferredTools gate (medium) / template seeding (small) /
evolution reuse (small) / memory shared (free) / UI mostly free / setup-sheet launcher provider is
Daily-OS-hardcoded (small refactor).

**Needs redesign (not extension):** recurrence/cron model; shared `search_memory` + generalized
knowledge entity (lift out of day agent); observation window/scoring; retention for long-lived
agents; attention generalization (ADR 0023 D3); ad-banner surface (nothing exists — GenUI catalog is
evolution-bound; nearest primitives: GenUI bridge, notification bridge, AttentionAward). ADR 0023
frames attention as calendar time, NOT interruption — banner ads are a deliberate departure to argue
explicitly in an ADR. Closest precedent to copy: **per-day agent (ADR 0032)** — durable identity per
subject, ≤~12K input tokens target, explicit retirement path, same-soul persona story.

### C. Chat / habits / health / banners (report received)

**Chat:** `lib/features/ai_chat` is no longer a chat screen — it's a shared voice-input + reasoning-
display toolkit (`chatRecorderControllerProvider` record→transcribe state machine with
partialTranscript streaming, `WaveformBars`, `ThinkingParser` tolerant of unterminated blocks,
`ThinkingDisclosure`). The ONE real chat is **EvolutionChatPage** (`evolution_chat_page.dart`):
UI messages are in-memory/autoDispose (`EvolutionChatMessage` union incl. GenUI `surface` variant),
model context lives in `TemplateEvolutionWorkflow` session — **already decoupled**. No token-level
streaming in chat (awaits whole turns; `enableAiStreamingFlag` exists but untraced). Voice input in
chat exists once (`EvolutionMessageInput` mic → fills text field, no auto-send). Durable side =
`AgentMessageEntity` rendered only by read-only `AgentConversationLog` (grouped by wake threadId).
**No code bridges persisted agent messages ↔ interactive chat history** — an "ongoing chat you
return to" needs a persisted visible-history projection. Nav patterns: pushed page via
`bottomNavSafeNavigatorOf` (evolution chat), beamer deep-link (`agent_nav_helpers.dart`), Wolt modals.

**Habits:** `HabitDefinition` + `HabitSchedule.daily/weekly/monthly(requiredCompletions)`;
**`AutoCompleteRule.health{dataType, minimum, maximum}` / .measurable / .and/.or/.multiple is a
ready-made, synced success-criteria tree with NO evaluator anywhere** ("data model more ambitious
than the editing surface"). Completions: `HabitCompletionEntry{habitId, completionType:
success/skip/fail/open}` → affectedIds `{habitId, 'HABIT_COMPLETION'}` → UpdateNotifications. Only
UI controllers listen today; nothing agent-side. Streak/rate derivations exist
(`habits_controller.dart:131-288`, `HabitChartStats.target/pointsToGoal/isAtGoal`).

**Health/steps:** `CumulativeQuantityData` one-per-day rows, dataType `'cumulative_step_count'`
(token = the dataType string itself). Import is **pull-only, mobile-only** (`isDesktop →
unsupportedPlatform`), fired when dashboard charts mount, 10-min throttle, no background fetch —
"step count updated" is NOT autonomous; something must poll. **⚠ Sync blind spot:** local writes →
`localUpdateStream` (what WakeOrchestrator consumes); synced entries → `syncUpdateStream` only. A
desktop goal agent never wakes from phone-imported steps. Options: sync-origin dispatcher (precedent
`synced_audio_inference_dispatcher.dart`) + lease election, or subscribe `updateStream` (feedback
risk), or pin goal agents to the data-origin device.

**Goal-like structures:** StandingAgreement (see A — no writer/UI/evaluation); AutoCompleteRule
thresholds (unevaluated); `HabitChartStats.target` (80% line); dashboard step ramp keyed 10000/6000/0;
`MeasurableDataType` has NO target field; insights = period deltas, no targets. Nothing goal-shaped
in `lib/classes` unions. On-track vocabulary exists: `AttentionClaimStatus{satisfied,
partiallySatisfied, declined, deferred, expired…}`.

**Banner surfaces:** Only app-wide banner = demo-mode band (`DemoModeScaffold`, structural height,
wraps router child — the pattern for an unavoidable shell band). Cleanest per-tab insertion:
**Daily OS day page nudge stack** (`day_page.dart:392-505`: `_DailyOsSetupNudge` → `KnowledgeNudge`
→ view; nudges render nothing when idle). Habits tab slot after `HabitsSummaryCard`; tasks tab has
SliverToBoxAdapter slots. Dismissible-AI-card precedent: **ProjectAgentReportCard** (dismiss →
`ProjectRecommendationStatus.dismissed` + dismissedAt). `KnowledgeNudge` = one-line sparkle →
modal panel. Image-in-card ingredients: `EventCoverImage{BoxFit.cover, scrim, gradient fallback}`,
`CoverArtThumbnail` (FileWatcherMixin repaints late-written files). **No carousel primitive** (2 ad
hoc PageViews). Auto-show sequencing chain pattern at `beamer_app.dart:449-539`.

**Voice/TTS:** two recorders (journal `AudioRecorderController` keepAlive; AI voice
`chatRecorderControllerProvider` temp-file m4a → `AudioTranscriptionService.transcribeStream`
chunked; provider selection Mistral→Melious→MLX→gemini fallback; every call attributed). Daily OS
voice-first widgets (`VoiceButton` phases, `LiveTranscriptView`) are the best voice-UX model. TTS:
on-device Supertonic ONNX, 10 voices, `TtsPlaybackController.speak(text, sourceId)` app-wide;
sole call site = AI summary TL;DR behind `enableAiSummaryTtsFlag`. **No TTS↔recorder barge-in
interlock exists.**

**Notifications:** OS layer no-ops on Linux/Windows; off by default (`enable_notifications` flag);
habit reminders daily-only. Durable synced inbox (`notifications.sqlite`) has task-shaped variants
only. **Notification tap deep links are written but never consumed** (no response callback) — the
banner-only decision conveniently sidesteps this; if notifications are revisited, tap-routing must be
built. In-app `NotificationBell` popover mounted in tab headers.

## Synthesis (direction the design agents will detail)

1. **Position goal agents as the producer side ADR 0023 was waiting for** — new `goal_agent` kind
   (one durable identity per goal; deliberate divergence from 0023's per-scope granularity, argued in
   a new ADR), StandingAgreement gets its first writer when a goal implies calendar cadence; attention
   claims/planner negotiation left as a compatible later seam.
2. **Goal state must be versioned structured data, not prose**: goalSpec (+versions +head, following
   the template/soul pattern) with criteria reusing the AutoCompleteRule threshold shape (dataType/
   min/max + cadence quotas à la StandingAgreement). "Agent can always state its current goal" =
   read the head version, never re-derive from chat history.
3. **Deterministic-first wakes for cost**: hourly/step/habit ticks are evaluated by a Dart progress
   evaluator (finally implementing the AutoCompleteRule-evaluator gap) that computes on/off-track and
   material-change; the LLM wakes ONLY on state transitions, ad staleness, or scheduled dialogue
   moments. Inverts the task-agent assumption (no-op wakes rare) — for goal agents no-op ticks are
   the COMMON case and must cost €0.
4. **Ads are entities + journal images**: agent decides → composes need-to-know visual brief →
   Nano Banana Pro (Gemini route; reference images enable persona/series consistency) → optional
   cheap vision-model verification → banner entity + JournalImage → rendered by a reusable nudge-
   strip/carousel widget (Daily OS day page + habits tab first); tap = open chat / dismiss (dismissal
   is an event the agent sees).
5. **Eval-first development**: define the goal-agent prompt + tool contract, then eval it inference-
   style (declarative scenarios, cheap) BEFORE building the workflow; graduate to workflow evals
   (penguin-harness pattern over a fitness demo world) once the workflow exists. Headline metric:
   **cost per goal-month** (wake frequency × cost/wake, credits from Melious impact data).

## Designs from planning agents

### Surfaces design (received)

**Ad entity requirements (feeds the architecture design):** add `briefDigest` (dedupe/budget key),
`runKey`+`threadId` provenance (DayPlanEntity precedent), `headline` with `@Default('')` (image
carries NO readable text per Flux-skill contract — headline is the textual payload, overlaid in UI),
status vocab `active|dismissed|retired|expired` (+ timestamps; agent *retires*, clock *expires*,
user *dismisses*), `provenance` map (verification outcome, soul version). Goal binding: polymorphic
`{goalKind, goalRefId}` suggested — reconcile with architecture agent's goal-entity design.
Dismissal = LWW status write; agent sees it via wake facts, no new event entity.

**Pipeline:** goal agent kind + `goal_agent_service.dart` (project/event-service pattern); persona =
existing soul documents ("gym coach" is a soul). Triggers: subscription on bound habitId; scheduled
cadence evaluation (re-arm via set_next_wake pattern); new `WakeReason.userMessage`
(throttle-bypassing like transcriptionComplete). **Deterministic pre-inference gate**
`goal_agent_wake_facts.dart`: on/off-track math, active-ad freshness, remaining image budget
(trailing-7-day count by briefDigest), dismissal stats + cool-down; `create_ad` tool only exposed
when budget remains AND no fresh active ad AND no cool-down (tool-gate rule). **`create_ad` as agent
tool, autonomous execution, NOT ChangeSet-deferred** (per-ad confirmation kills the product); cost
control = hard caps on AgentConfig (`maxAdImagesPerWeek` default 3, global monthly ceiling),
enforced at tool gate AND handler. **Privacy boundary at handler**: outbound prompt built
exclusively from tool args {brief, headline, styleHints} + fixed style contract (16:9, centre-safe,
no readable text); handler has no repository access in prompt-construction path; reference images
must have non-null aiAttribution (user photos structurally excluded). **`GenerateImageService`
extraction** from `skill_inference_runner.dart:884-965` (generateImage → attribution →
importGeneratedImageBytes with linkedId:null) — SkillInferenceRunner becomes a caller = task
cover-art reuse; needs agent-origin AiWorkAttribution variant. Provider: Nano Banana Pro direct
Gemini default (reference-image persona consistency); Melious flux fallback. **Verification**: one
flash-class vision call {matchesBrief, mismatches[]} → ONE regeneration with corrections → else
don't publish (typed failure + observation); flag-gated default ON; outcome in provenance. Ads
surface via reactive `activeGoalAdsProvider`.

**Banner components** (new `lib/features/agents/ui/goals/`): `GoalAdBanner` (shrink-when-empty
KnowledgeNudge contract) → `GoalAdCard` (EventCoverImage ingredients: cover+card scrim+gradient
fallback+FileWatcherMixin for late-synced bytes; headline overlay, persona attribution, 44px dismiss
X, tap→chat) / `GoalAdCarousel` (first carousel primitive: PageView+dots, manual swipe only, fixed
height, reduced-motion aware). Dismiss = X or swipe → status write (ProjectAgentReportCard
precedent), optimistic removal. Mounts v1: Daily OS day page nudge stack after KnowledgeNudge
(`day_page.dart:411-428`) + habits tab after HabitsSummaryCard (`habits_page.dart:279`); app-shell
band (DemoModeScaffold pattern) documented as escalation, not built. Tokens mandatory; l10n = static
chrome only in all 12 catalogs (ad copy is generated content, not localized).

**Conversation surface:** `GoalChatPage` = **read-only projection over the durable agent log**
(no session; "continue where we left off" is free). Whitelist: `kind==user` bubbles; `kind==action
where metadata.toolName=='reply_to_user'` as assistant bubbles (**agent replies are tool calls, not
a new message kind** — no schema change); goalAd entities inline as compact cards with status
badges (past ads stay in the timeline forever); sparse localized lifecycle markers. Hidden:
thought/observation/toolResult/summary/internal system. Reverse ListView, createdAt-cursor
pagination ~50, lazy payload hydration. Send = append user message + userMessage wake;
await-whole-turn v1 (evolution-chat parity; isWaiting from wake-run status). Voice: promote
evolution input widgets into shared `lib/features/ai_chat` toolkit (`AgentMessageInput`,
`AgentVoiceControls`, `AgentTranscriptionProgress`) + extract `StickToBottomChatList` (2 consumers
= legit reuse). TTS deferred behind a flag; **barge-in interlock recorded as a gap** in chat
requirements. Nav: banner tap → `bottomNavSafeNavigatorOf` push (evolution precedent) + beamer deep
link.

**Chat requirements outline:** 15 sections (purpose/consumers/history-model/message-taxonomy+card
registry with text-fallback degradation/composer/streaming/TTS+barge-in/turn lifecycle/pagination/
search/a11y/tokens/l10n/persistence/migration plan for evolution+goal convergence).

**Product decisions surfaced:** placement (rec: day page+habits tab); image-spend autonomy (rec:
caps not confirmations); carousel (rec: manual swipe); tone defaults (rec: soul "gently humorous,
never shaming" + toneBounds forbidding guilt/body-comments, user picks at creation); verification
default ON; dismissal cool-down 24h; ad lifetime 72h or goal-satisfying completion.

### Eval design (received)

**Split:** deterministic layer (progress math, wake gate, ad staleness) = plain unit tests when
production code lands; model evals = post-wake behavior only. Bridge: fixtures carry hand-computed
expected values as named constants with arithmetic comments (e.g. `gpBadlyOffMeanSteps = 6414; //
(7120+…)/7`) + an offline self-test recomputing them — which doubles as the executable spec of the
future deterministic progress evaluator.

**Fixture world:** new penguin-universe persona **Keeper Signe Voss** (Ross Station, spring
shore-count expedition): G1 "avg 10,000 steps/day", G2 "crew gym 3×/week". `signePrivateStrings`
leakage inventory (names, station details, health values, knee-strain physio note, IDs) spliced
into ad-brief forbidden-args; the leakage scenario deliberately stuffs context with tempting
private detail. Authored wake-context JSON (limitation stated); graduation path → workflow eval on
a penguin fitness world once GoalAgentWorkflow exists.

**Draft contract (executable spec):** *(digest as received; superseded during the session —
the shipped contract has 6 tools + `cta`, policy rows P1–P15, 23 scenarios, and the unified
`GoalTrackStatus` names replacing `slightlyOff`; `goal_agent_spec.dart` is authoritative.)*
5 tools, uniform `<verb>_goal_<noun>` naming:
`update_goal_report{status: onTrack|slightlyOff|offTrack|recovering|insufficientData, oneLiner,
tldr, content}`, `create_goal_ad{imageBrief, altText, tone: encourage|nudge|celebrate}`,
`retire_goal_ad{adId, reason}`, `propose_goal_revision{changes: {metric,targetValue,period,cadence,
successCriteria}, rationale}` (ONLY goal-mutation path — silent mutation structurally impossible),
`record_goal_observation{note}`. Dialogue = plain assistant content (no tool). Lean ~1,300-char
system prompt (payload lesson); no-op rule in the spirit of the task-agent report directive.

**Policy matrix P1–P12** (single source of truth, Dart constant; precedence dialogue-pending > ad
bookkeeping > status/reporting): onTrack+material→report only; nothing changed→NO tools (no-op
discriminator); slightlyOff flat→report only; slightlyOff worsening 3+ days→report+ad(nudge);
offTrack no ad→report+ad; offTrack fresh ad→no second ad; recovering+stale ad→retire+report;
insufficientData→report, no ad, never fabricate gap values; habit completed while "behind" ad
live→retire, no new ad same wake; unanswered user message→dialogue first; clear change
request→propose exactly once, restate current goal first; vague musing→clarifying question, no
proposal.

**16 scenarios** (gp_on_track/slightly_off/badly_off/recovering/data_gap/noop/gh_gym_pace;
ad_create_off_track/leakage_pressure/stale_after_completion/no_double; evo_replace_metric/
adjust_target/ambiguous/withdrawn-multi-turn; wk_dialogue_over_report). New predicate fields
N1–N4: `followUpUserMessages`, `requiredAssistantContentTermGroups`/`forbiddenAssistantContent
Claims`, `maxToolCallCounts`, `numberTerms()` formatting-variant helper. Everything else = existing
assertion vocabulary.

**Harness:** chassis = inference-eval pattern (day-planning runner is welded to day-plan domain
types); borrow its reporting ideas into a new small goal-shaped report tool with credits from day
one. Extract shared `eval_text_matchers.dart` (term-group + negation-aware claim matchers) — both
suites import. Reuse `AiInteractionCaptureTestBench` + `formatCredits` + `AgentToolDefinition` +
known-model constants. Location `test/features/agents/eval/goal/` (+support); draft prompt/tools
graduate to `lib/features/agents/` later. **Cost capture:** melious provider type (NOT
generic-OpenAI — that's why task-agent evals lack credits) + `HttpOverrides.global = null` + capture
bench → per-call credits/tokens/energy in every artifact; rollups per scenario×model + per model +
**cost-per-goal-month** = credits/wake × wakesPerDay(default 3, printed assumption) × 30.
Independent bonus fix: day-planning `EvalReport._costRows` ignores credits (~40 lines + test).
Matrix: `scripts/goal_agent_eval_matrix.sh` clone (process per model×sample, warm build); default
models `glm-5.2 kimi-k3 qwen3.5-122b-a10b qwen3.6-27b`; samples 3; temp 0. Report:
`tool/goal_agent_eval_report.dart` pure-Dart CLI (leaderboard objective-only, matrix, failures,
cost, judge bundle). Judge: `tool/goal_agent_eval_judge.py` copying the billing-accounting pattern,
qwen judge, default OFF during bring-up.

**Session implementation list** *(historical digest — superseded by the shipped
harness: six tools + cta, P1–P15, 23 scenarios, image stage; `goal_agent_spec.dart`
is authoritative)* **(12 files, ~2.3–2.7k LOC, build order + verify steps):** matchers
extraction → eval_report credits fix → goal_agent_spec.dart (prompt+tools+policy) → fixtures →
scenarios → offline self-tests → runner/strategy/classifier/artifact writer → live test (@Tags
eval-live, env-gated, skips cleanly without env) → report CLI + test → matrix script → judge
(optional; cut line) → `docs/evaluations/goal_agent_models/README.md`. Run book with exact
commands/env vars documented.

**Eval decisions flagged:** judge OFF first run (rec), model list (rec above; 397b optional
ceiling), wakes/day=3 default, gh_gym_pace policy cell = slightlyOff (rec), do the credits fix this
session (rec yes).

### Architecture design (received)

**vs ADR 0023:** per-GOAL identity (`AgentKinds.goalAgent = 'goal_agent'`), argued as MORE
consistent with 0023's own "memory coherence sets granularity" principle (one narrative thread per
goal; per-goal lifecycle/retirement; planner never observes producer granularity — claims carry
scope). ADR 0023 amended, not contradicted; planner negotiation stays a future seam.

**Data model — 4 new `AgentDomainEntity` variants, NO schema bump (v19 stays):**
- `goalSpecVersion` (immutable: version, status, title, statement the agent can *speak*,
  `GoalCriterion criteria` tree root, authoredBy user|goal_agent|system, sourceSessionId,
  diffFromVersionId, start/targetDate, rationale) + `goalSpecHead` (deterministic id
  `goal_spec_head:<agentId>`, LWW). "State your current goal" = head→version read, zero inference.
- **`GoalCriterion`** new freezed union in agents model (NOT embedding AutoCompleteRule — that's a
  point-in-time same-day threshold owned by habit autocompletion; goals need window/aggregation/
  direction/quota): `.metric{dataType, window: rollingDays|calendarWeek|calendarMonth|day,
  aggregation: dailySumThenAvg|sum|count|max, target, direction}`, `.habit{habitId, window,
  targetCount}`, `.measurable`, `.allOf/.anyOf/.atLeastCount{successes}` composites; each with
  stable criterionId. Plus `GoalCriterion.fromAutoCompleteRule()` importer (habit rule seeds a goal
  in one tap). The evaluator is the codebase's FIRST rule-tree evaluator; AutoCompleteRule adapter
  becomes trivial later.
- `goalProgress` keyed register (id `goal_progress:<agentId>:<periodKey>`, recomputed-never-
  accumulated like weekRollup → LWW-convergent across devices; trackStatus onTrack|atRisk|offTrack|recovering|
  achieved|insufficientData (the full GoalTrackStatus vocabulary) as subtype for indexed scans; attainment 0..1 + per-criterion results;
  ~1MB/goal-decade, retention-exempt — it IS the chartable history + cheap agent context).
- `goalNudge` ad entity (status draft→ready→active→dismissed|retired|expired|superseded|failed as subtype (retired added with the reuse re-entry, ADR 0055);
  `GoalNudgeBrief` typed brief = the ONLY payload the image request may see; imageEntryId
  (JournalImage → media sync free); headline/caption composited ON DEVICE, never sent;
  triggerProgressId evidence; staleAt pulled forward by habit completions; reasonSummary).
  MERGE surfaces-agent fields: briefDigest (dedupe/budget key), runKey/threadId provenance,
  provenance map (verification outcome, soul version).
- StandingAgreement = derived planner-facing projection, FIRST WRITER = ChangeSet-gated
  `upsert_standing_agreement`, deterministic id, targetKind 'goal', evidenceRefs → goalProgress.
- Provenance: agent-proposed spec revisions exist ONLY after user approval of a
  `propose_goal_revision` ChangeSet — no auto-accept tier (10-year trust: the coach never quietly
  moves its own goalposts). User-authored versions write directly.
- Migration: none needed — mixed-version fleets are unsupported (project assumption: all devices
  stay current; USER 2026-08-08). No `AgentTemplateKind` change anyway: v1 goal agents use NO
  template (pure code-owned constitution, ADR 0052 posture); soul later via link types (free
  strings, non-breaking).

**Wake architecture — two-tier:** invariant: *a tick that changes nothing costs €0 and writes no
messages.* Subscriptions per goal: criterion dataTypes + habitIds (NOT the global HABIT_COMPLETION
sentinel) + `goalNudgeDismissedToken(agentId)`; registered via `GoalRuntimeMaintenance implements
AgentRuntimeMaintenance` in app_bootstrap. Recurrence: NO ScheduledWakeEntity schema change —
re-arm at Phase A start at deterministic id (workspaceKey 'goal-cadence'), self-healed by
beforeWakeScan(); hourly poll granularity is ample. **Sync-origin hybrid:** new
GoalSignalSyncListener/Dispatcher (1:1 on synced_audio_inference pattern) wakes **Phase A only** on
receiving devices (idempotent keyed registers = convergence not duplication); Phase B NEVER runs
from a data trigger directly — Phase A upserts an immediate escalation ScheduledWakeEntity
(workspaceKey 'goal-escalation:<periodKey>') and the existing leaseHostId election picks exactly
one device (armer nudges manager for immediacy; ≤1h remote pickup if armer dies). Alternative
pin-to-phone rejected: desktop would show stale ads (no background fetch, chart-mount deltas,
10-min throttle).

**Flow:** Phase A (every wake, €0): load head → re-arm cadence → GoalProgressEvaluator (pure Dart,
`lib/features/goals/evaluation/`, behind narrow GoalSignalReader interface, 100% unit-testable;
trackStatus policy deterministic: offTrack = attainment<0.8 ≥grace periods, atRisk = pace-based) →
upsert registers → GoalWakeFacts → if nothing LLM-worthy return (no capture/compaction/messages) →
else escalate. Phase B (leased): capture(spec render + last ~8 periods table + nudge state +
knowledge hooks) → `compactAndAssemble(budget: 12000, retain: 4000)` (per-call params exist;
50k/20k assumes warm cache a cold once-daily agent lacks) → code-owned goal constitution + facts →
tool loop maxTurns 8 → report editor → outputs + wakeTokenUsage row (per-goal observability — no
budget enforcement, per decision record). Target ≤8K input tokens.

**Tool gate (0051 designed-in):** statusTransitioned → update_goal_report (absent tool = wake
CANNOT churn); hasActiveNudge → retire/mark; offTrackAndNoFreshNudge → create_goal_ad / rerun_goal_ad (reuse added with ADR 0055 Decision 7) (writes
goalNudge DRAFT carrying only the brief; pipeline consumes; brief-digest dedupe = quality mechanic,
not budget); specImpliesCadence&drifted → upsert_standing_agreement (ChangeSet); inDialogue →
propose_goal_revision (ChangeSet); always: record_observations, remember, search_memory,
set_next_check_in (bounded/day to prevent runaway self-scheduling, not as budget).
**USER DECISION 2026-08-08: NO hard spending caps.** Cost control = MONITORING, not ceilings:
every call already lands as `AiConsumptionEvent{agentId, wakeRunKey, credits, tokens…}`, so
per-goal cost rollups reuse `consumption_repository` queries; goal detail UI surfaces per-goal
spend (incl. image gen via AiWorkType.imageGeneration); evals report cost/call + extrapolated
€/goal-month as an OBSERVED ESTIMATE, never a target. Caps stay a documented future option if
monitoring ever shows a problem. Phase A/B two-tier stays — as engineering discipline (a no-op
tick shouldn't invoke an LLM), not as a quota.

**Memory (10y):** reuse `PlannerKnowledgeEntity` AS-IS (only read path is day-bound; goal context
reads allFor(agentId); `remember` tool writes userStated→confirmed). Extract shared
`agent_memory_search.dart` from day_agent_tool_handlers:275-353. NEVER read-all observations
(getMessagesByKind takes limit; recent-N + all-critical repo method; task-agent gets same one-line
fix as cleanup). Retention (REVISED per USER 2026-08-08): **bounded reads are the invariant,
pruning is optional and defaults to OFF** — quarterly fold into plannerKnowledge + epoch summary
(summaryDepth:1; yearly → depth 2) bounds what any wake *reads*; the full raw log can be kept
forever (megabytes/decade, user's own device) as cold, searchable history. IF a user ever wants
space back: distill-then-prune only (raw prunable strictly AFTER distillate exists); fix
maxAgentMessages 20000 skip-deadlock → prune summary-covered prefix only.

**Cost model (PREDICTION to validate by monitoring — not a cap, per decision record):**
deterministic ticks €0; Phase B ~4/wk × 9K tok ≈ €0.08/mo; dialogue ~2/wk ≈ €0.20/mo; images at a
few per off-track day, cents each → order of **€0.1–1/goal-month expected**. Evals + per-goal
consumption rollups measure the real number; ballpark Melious pricing validated live in PR 3.

**ADRs 0053–0057:** 0053 goal agents as 0023's producer at per-goal granularity (amends 0023);
0054 deterministic-first two-tier wakes + lease election + sync dispatcher (codifies 0051 lesson);
0055 banner-nudge attention channel (departure from attention=calendar-time; dismissal is data;
staleness is a contract); 0056 need-to-know visual brief boundary (the TYPE is the enforcement);
0057 decade-scale memory (amends 0017 with hierarchy).

**Component inventory:** new `lib/features/goals/` feature (model/evaluation/service/state/
workflow/sync/ui) mirroring daily_os_next/agents layout; modifications to agent_domain_entity,
agent_db_conversions, agent_constants, app_bootstrap, retention policy, db_notification token
helper, shared memory-search extraction.

**Build phasing (each PR green):** PR 0 (THIS SESSION) = ADRs + docs + pure-Dart
GoalCriterion/enums/GoalProgressEvaluator/GoalSignalReader(+fake) with exhaustive tests — and the
eval fixtures' self-test can CONSUME the real evaluator (hand-written constants cross-checked
against it), so the evaluator ships with a real consumer, satisfying the no-hoarded-code rule.
PR 1 entities+conversions+round-trip tests; PR 2 deterministic runtime headless (+ fallback-guard
test); PR 3 LLM tier; PR 4 evolution/revision flow; PR 5 nudges; PR 6 decade hardening. Risks:
wake latency bounds (≤1h, documented), lease-race duplicate
(~€0.005, idempotent), silent task-agent fallback (regression test), evaluator-vs-habit-UI drift
(pin fixtures to habits_controller semantics), voice token creep (budgets structural).

## Decision record (user-ratified 2026-08-08)

1. **Session scope**: full — all four phase documents + five draft ADRs + eval harness + the
   pure-Dart `GoalCriterion` model and `GoalProgressEvaluator` with exhaustive tests (consumed by
   the eval fixtures' self-test → no hoarded code).
2. **Goal model**: Option A — versioned GoalSpec (goalSpecVersion + goalSpecHead) + purpose-built
   criterion tree; StandingAgreement derived (goal agent = its first writer); AutoCompleteRule
   importer. Explained in full to the user (three-option walkthrough); only session artifact that
   hardens the choice is the criterion/evaluator file family (~1 day to redo if ever reversed).
3. **Wake routing**: hybrid — deterministic Phase A on every device (sync-origin dispatcher);
   LLM Phase B single-flighted via the existing scheduled-wake lease election.
4. **Cost policy**: **NO hard spending caps** (user explicit: "what we need now is monitoring and
   seeing cost, that is all"; images cost cents, ~3/day/goal fine). Cost control = observability:
   per-goal consumption rollups (`AiConsumptionEvent.agentId` already attributes every call incl.
   image gen), per-goal spend surfaced in the design's UI section, cost/call + €/goal-month in
   every eval report as OBSERVED ESTIMATES, never targets. Brief-digest dedupe and 24h dismissal
   cool-down are retained as quality/respect mechanics only. Caps remain a documented future
   option if monitoring ever shows a problem.
5. **Ad rating & reuse (USER, mid-session 2026-08-08):** tapping an ad prompts a lightweight
   rating (skippable; **every re-run prompts anew** — the rating trajectory detects wear-out),
   appended to the `goalNudge` row as a `{rating, ratedAt}` history per run. This builds a
   labeled library of what lands: wake facts surface top-/bottom-rated
   briefs to steer future `create_goal_ad` calls, and top-rated ads can be **re-run as-is**
   (lifecycle re-entry with fresh `staleAt`, zero image-generation cost) instead of generating
   anew. Recorded as ADR 0055 Decision 7; eval spec gains a `rerun_goal_ad` tool, policy row
   P13 (prefer re-running an offered top-rated ad over generating a new one) and a reuse
   scenario. Also per USER same day: **track how long an ad was actually visible** —
   `totalVisibleMs`/`impressionCount`/`firstShownAt`/`lastShownAt` accumulated on the goalNudge
   row from banner visibility sessions; visible-time-to-action is the denominator for
   effectiveness metrics and weights the rating library.
6. **REVERSAL (USER, post-merge 2026-08-08, ADR 0058): no generative imagery.**
   Ads are procedural text banners — model-authored copy over code-owned
   animation/accent presets. The Nano Banana pipeline the eval proved end-to-end
   is removed (the proof made the energy cost visible, which was the point);
   only ADR 0056's image-transport path is retired — its need-to-know
   allowlist rule stays ACTIVE for the model-authored banner copy
   (headline/tagline/cta remain leakage-linted and leakage-evaled), and it
   is the boundary any future image feature re-enters through. Per-agent ENERGY (Wh/goal-month from AiConsumptionEvent.energyKwh)
   joins credits as a first-class reported figure.
7. Previously settled *(items struck through were superseded by ADR 0058 the
   same day — no image provider, no verification pass)*: banner-only (no push;
   ADR 0055 records it as revisitable); Nano Banana Pro
   via direct Gemini with the need-to-know brief boundary (ZDR exception, user 2026-08-08); text
   inference on Melious (EU/no-training posture; only provider reporting cost); evals manual, no
   CI.

**Defaults adopted (recorded in docs as revisitable, not re-asked):** eval model matrix `glm-5.2
kimi-k3 qwen3.5-122b-a10b qwen3.6-27b` (+`qwen3.5-397b-a17b` optional ceiling probe); samples 3;
judge OFF for bring-up; wakes/day extrapolation default 3 (printed assumption); gh_gym_pace policy
cell = slightlyOff; banner placement v1 = Daily OS day page nudge stack + habits tab (app-shell
band documented as escalation only); carousel = manual swipe + dots; ad lifetime 72h or
goal-satisfying completion; ~~brief-match verification ON~~ (moot under ADR 0058 — nothing to verify);
agent-proposed spec revisions ALWAYS user-gated (no auto-accept tier); default persona soul
"gently humorous, never shaming" with toneBounds; goal chat = await-whole-turn v1.

## Approach — session execution plan

Branch `feat/goal_agents` (already at main tip). Nothing committed or pushed unless the user asks.
Order follows the requested working style: findings → eval plan → design specs → chat
requirements, each document reviewable as it lands.

### Step 1 — Phase-1 assessment document
`docs/implementation_plans/2026-08-08_goal_agents_phase1_assessment.md`. Sections: (a) audit of
the existing agentic substrate — what works (wake orchestration, capture/compaction, versioned
templates/souls, ChangeSet gate, kind-agnostic UI, consumption attribution), what extends
(runtime-registry seams, PlannerKnowledge read path, search_memory generalization, subscriptions),
what needs redesign (recurrence, retention for long-lived agents, observation windows, sync-origin
wakes, banner surface); (b) the 10-year gap table (Findings A §memory traps); (c) ADR 0023
reconciliation and the per-goal granularity argument; (d) proposed extended data model (4 entity
variants + GoalCriterion; Mermaid relationship diagram); (e) seams depending on the known-imperfect
runtime/evolution improvement track (ADR 0051 flag-off, forced-report hack, whole-directive
evolution, AgentTemplateKind enum freeze) — flagged, not fixed here; (f) assessment of
memory/"writing away memories" as practiced (write-only for non-day agents, asymmetric read-back)
and the bounded-reads remedy (prune nothing by default; distill-then-prune only if space is ever reclaimed).

### Step 2 — Draft ADRs (Status: Proposed)
`docs/adr/0053-goal-driven-agents-per-goal-producers.md`, `0054-deterministic-first-two-tier-
wakes.md`, `0055-banner-nudge-attention-channel.md`, `0056-need-to-know-visual-brief-boundary.md`,
`0057-decade-scale-agent-memory.md`. Verify 0053+ still free at execution time; follow existing
ADR format incl. Related links; 0053 amends 0023 (granularity note), 0057 amends 0017 (hierarchy);
0054 codifies deterministic-first + monitoring-not-caps. These are the blog-post backbone.

### Step 3 — Pure-Dart goal core (the only production-tree code this session)
New `lib/features/goals/model/goal_criterion.dart` + `goal_enums.dart` (freezed; GoalWindow,
GoalAggregation, GoalDirection, GoalTrackStatus; `GoalCriterion.fromAutoCompleteRule` importer);
`lib/features/goals/evaluation/goal_signal_reader.dart` (narrow interface + in-memory fake);
`goal_progress_evaluator.dart` (pure tree-fold; deterministic trackStatus policy: offTrack =
attainment < 0.8 for ≥ grace periods, atRisk = pace-based, achieved, insufficientData). Tests
under `test/features/goals/…` mirroring paths 1:1: windows (rolling/calendar, boundaries, DST),
aggregations, quotas, composites (allOf/anyOf/atLeastCount), grace, pace math, data gaps.
`make build_runner` after freezed additions (never build-filter — it prunes generated files).

### Step 4 — Eval harness (build order per eval design)
1. Extract `test/features/ai/eval/support/eval_text_matchers.dart` (term-group + negation-aware
   claim matchers); task-agent eval imports it; rerun its offline tests.
2. Day-planning credits fix: `eval_report.dart` (`EvalCostRow`/`_costRows`/toJson/bundle/Markdown)
   + `eval_report_test.dart`; "not reported" when credits null — never invent numbers.
3. `test/features/agents/eval/goal/support/goal_agent_spec.dart` — DRAFT system prompt (~1.3k
   chars), 5 `AgentToolDefinition`s (`update_goal_report{status enum,…}`; `create_goal_ad` with
   TYPED brief fields aligned with GoalNudgeBrief — sceneConcept/mood/stylePreset/altText/tone;
   headline stays on-device, schema consistent with ADR 0056; `retire_goal_ad`;
   `propose_goal_revision{changes: spec-diff fields}`; `record_goal_observation`), policy matrix
   P1–P12 as a Dart constant. This file is the executable spec; README documents its graduation
   to `lib/features/agents/` when the workflow is built.
4. `goal_agent_eval_fixtures.dart` — Signe Voss penguin world (G1 steps avg, G2 gym 3×/wk),
   arithmetic-comment constants, `signePrivateStrings` leakage inventory, wake-context JSON
   builder. Self-test cross-checks constants against the REAL `GoalProgressEvaluator` (step 3).
5. `goal_agent_eval_scenarios.dart` — `GoalAgentEvalScenario` (existing assertion vocabulary + N1
   `followUpUserMessages`, N2 assistant-content term groups/claims, N3 `maxToolCallCounts`, N4
   `numberTerms` helper) + the 16-scenario catalog derived from policy rows.
6. `goal_agent_eval_scenarios_test.dart` — offline self-tests (fixture arithmetic vs evaluator,
   leakage list present in every ad scenario, policy coverage, unique ids).
7. `goal_agent_eval_runner.dart` — runner + recording strategy (dispatcher-faithful unknown-tool
   errors, multi-turn), classifier, per-case artifact writer incl. serialized consumption events.
8. `goal_agent_eval_live_test.dart` — `@Tags(['eval-live'])`, gated on
   `LOTTI_GOAL_AGENT_EVAL_LIVE=1`, `HttpOverrides.global = null`, **melious provider type**
   (credits!), `AiInteractionCaptureTestBench` registered; compiles and SKIPS cleanly without env.
9. `tool/goal_agent_eval_report.dart` + test — merge artifacts → leaderboard (objective checks
   only), scenario×model matrix, failure excerpts with transcripts, cost tables (formatCredits
   EUR) + €/goal-month extrapolation (wakes/day printed as an assumption).
10. `scripts/goal_agent_eval_matrix.sh` — per-(model,sample) process fan-out, warm build, report
    invocation.
11. `docs/evaluations/goal_agent_models/README.md` — methodology mirror of the task-agent README:
    policy matrix, scenario catalog, run book (exact env vars/commands), caveats (authored
    context; samples=3 noise; judge diagnostic-only; costs are observations), graduation path to
    workflow evals on a penguin fitness world.
12. STRETCH (explicit cut line): `tool/goal_agent_eval_judge.py` (copies the billing-accounting
    pattern; default OFF).

### Step 5 — Phase-3 design spec document
`docs/implementation_plans/2026-08-08_goal_agents_design.md`: wake-trigger spec (subscriptions,
sync-origin dispatcher, lease election, cadence re-arm — Mermaid flow); ad pipeline (decision →
typed brief → Nano Banana Pro → verification one-retry → goalNudge + JournalImage → reactive
banner; `GenerateImageService` extraction for cover-art reuse; agent-origin attribution
extension); banner/carousel presentation model (GoalAdBanner/Card/Carousel, mounts, dismiss
semantics, a11y, tokens/l10n notes); goal evolution mechanism (GoalRevisionStrategy + ChangeSet
approval + version/head writes); memory & compaction strategy (PlannerKnowledge reuse, shared
search extraction, bounded reads with optional distill-then-prune, epoch summaries via summaryDepth, cold-prefill budgets
12000/4000, ≤8K input target); **cost monitoring section** (per-goal rollups via
consumption_repository, UI surfacing, explicit no-caps stance); component inventory; PR 1–6
phasing with green-PR discipline; risk register.

### Step 6 — Phase-4 chat requirements document
`docs/implementation_plans/2026-08-08_reusable_chat_interface_requirements.md` — the 15-section
outline expanded into REQ-numbered, testable statements (consumers: goal chat, evolution chat,
future eval-review UI; history = persisted projection decoupled from context; card registry with
text-fallback degradation; voice parity; explicit gaps: TTS↔recorder barge-in interlock,
streaming behind `enableAiStreamingFlag`, GenUI catalog generalization; pagination for 10-year
histories; search; a11y; tokens; l10n; sync constraints; migration plan). Not built this session.

### Step 7 — Verification pass & wrap-up
Run the checks below, then present the document set + eval run book for review. No commits unless
requested.

## Verification

- `dart-mcp.analyze_files` → **zero warnings/infos** (repo policy); `fvm dart format .`
  (not dart-mcp format). Register repo root via `dart-mcp.add_roots` first.
- `make build_runner` after freezed changes; never edit generated files; never use a build filter
  (it deletes tracked generated files outside the filter — git-restore any `D` files if hit).
- Targeted tests ONLY (repo rule — no whole-suite or whole-feature local runs), via
  `dart-mcp.run_tests`: new `test/features/goals/…`; goal eval offline tests; report-CLI test;
  `local_task_agent_inference_eval` offline tests (after matcher extraction);
  `test/features/daily_os_next/eval/framework/eval_report_test.dart` (after credits fix).
- Eval live path verified as compile-and-skip with no env vars set (the penguin matrix's warming
  trick). Actual matrix runs are user-triggered (needs `MELIOUS_API_KEY`); run book ships in the
  new evaluations README.
- Docs hygiene: no `knowledge/` changes this session (concepts document the app as it runs;
  nothing new runs yet — design docs live in `docs/`). No CHANGELOG entry (invisible work, repo
  rule). If any doc gains Mermaid, sanity-check rendering (no `make knowledge_check` needed since
  knowledge/ is untouched).
- Tests must all pass before reporting completion; re-run any new regression-style test against
  reverted logic where applicable (evaluator tests: mutate a constant to confirm the test bites).

## Out of scope this session
Production goal-agent runtime (PR 1–6: entities, services, workflow, sync dispatcher, banner UI),
the chat build (separate follow-up session per the user), planner attention-claim negotiation
(future seam), push notifications (revisit later), TTS wiring (later, behind flag), knowledge/
concepts for the feature (written when the feature ships).
