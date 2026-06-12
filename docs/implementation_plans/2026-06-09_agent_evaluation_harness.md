# Implementation Plan: Tiered Agent Evaluation Harness

- Date: 2026-06-09
- ADR: [0029 — Tiered Agent Evaluation Harness](../adr/0029-agent-evaluation-harness.md)
- Status: Phase 0 + Phase 1 landed, with hardened shared scenarios,
  model-class profiles, persisted-output extraction for both real workflow
  benches, persisted proposal extraction, profile-backed AI config seeding,
  pre-existing proposal-state fixtures, rejected-history proposal suppression,
  digest-bound traces, strict Level 2 run verification including
  canonical trace payload and model-provenance checks, repeated-trial
  reliability reporting, mode-based reporting, and task-agent category/label
  app-state seeding, plus planner capture/parsed-item/baseline-plan/capacity
  seeding, capture-only planner wake coverage, and per-cell
  `EvalTargetRunContext` for repeated trials, plus task-agent active-task
  derivation from `decided_task:<id>` triggers and persisted planner observation
  extraction, plus known raw/proposal tool-name gates, persisted tool-result
  error tracing, exact trace schema loading, exact trial-index reliability
  reporting, a gated `LiveEvalTarget`, scenario governance metadata,
  hash-bound trace provenance, runtime prompt/tool fingerprints, and
  per-capability reporting, plus run manifests with manifest-bound traces,
  provider-decision evidence, split/model-class/capability denominators, and
  outer `ConversationRepository.sendMessage` model-invocation auditing, plus
  provider request-level instrumentation inside `ConversationRepository`, plus
  schemaed judge verdict provenance for calibration tracking, plus Wilson
  confidence intervals and paired profile comparisons for model-class tuning,
  plus policy-backed candidate-vs-baseline profile promotion decisions,
  plus digest-bound judge/human calibration reporting over non-secret gold-label
  JSON with score bands, stale-label detection, false-pass/false-fail counts, and
  calibration-version mismatch, verdict-digest binding, unblinded-verdict
  reporting, and non-secret human-label template generation from verified judged
  runs, plus
  scenario-authored durable-state oracles for required/forbidden proposals,
  planned blocks, parsed capture items, report/observation text, and mutated
  entries, including mutation allowlists, accepted `anyOf` alternatives,
  scoped count checks, parsed-capture confidence bands, distinct required
  matcher assignment, reusable scenario reference validation, and Level 2
  verifier enforcement of that validation, plus explicit tuning-readiness
  policies that separate artifact-valid development-smoke runs from
  model-class tuning-ready runs using live-manifest, canonical digest,
  required-profile/model-class, multi-trial, verdict, calibration, protected
  holdout, and corpus coverage gates, plus external `EVAL_SCENARIOS` catalog
  ingestion with manifest-bound non-secret catalog evidence and protected trace
  output guards, plus scenario-scoped recoverable tool-result allowances and a
  public stress-tagged adversarial corpus slice across both agents, plus
  raw-label-backed calibration readiness that rejects aggregate report spoofing,
  plus digest-bound scenario review metadata and tuning-readiness gates for
  adversarial, synthetic, production-replay holdout, and protected holdout
  evidence, including source-digest provenance for synthetic and protected
  review evidence, plus expanded public adversarial workflow coverage with
  durable-state oracles and scripted real-workflow coverage guards, plus
  deterministic bounded calibration-template queues with aggregate selection
  coverage metadata, plus raw independent-human-review reliability metrics and
  readiness gates, plus promotion evidence planning for underpowered
  candidate-vs-baseline decisions, plus optional profile-level weighted
  reported-cost promotion gates for model-class comparisons, plus paired
  discordant judge-outcome evidence for candidate-vs-baseline promotion, plus
  digest-bound pre-registered promotion plans with run-manifest evidence for
  model-selection claims, plus protected holdout source-digest uniqueness gates,
  plus profile-pair overlap/token-evidence promotion blockers and
  scenario/profile cross-product slice coverage, plus capability/profile
  denominator rendering and scenario-clustered summary confidence intervals,
  plus manifest-validated expected-matrix slice reporting, plus stricter
  provider-request provenance checks, manifest-bound profile execution
  bindings for actual provider/model/endpoint overrides, external
  `EVAL_PROFILES` profile catalogs, model-selection judge-blinding gates, and
  diagnostic pairwise A/B preference quorum records for subjective free-text
  quality, plus first-class blinded judge export packets with opaque trace
  filenames, shuffled profile/prompt aliases, public review payload digests, and
  private raw-trace mapping keys.
  Next up:
  populate a real human-labeled calibration set, private production-replay
  holdout JSON catalogs, and a larger production-scale adversarial scenario
  corpus.
  **Start at "Current state (handover)" below.**

## Goal

A custom, data-driven eval framework for the **task agent**
(`TaskAgentWorkflow`) and the **planning agent** (`DayAgentWorkflow`) with:

- **Level 1** — fast deterministic assertions on every change (CI).
- **Level 2** — run real local/frontier models on curated scenarios, capture
  traces + token burn, grade with Claude Code as judge.
- **Level 3** — online A/B (future, out of scope here).

Maps the four requested artifacts onto the real code:

| Requested artifact | Concrete deliverable |
|---|---|
| Data models / mocks | `test/eval/harness/eval_models.dart` (plain-data `EvalScenario`, `MockTask`, `UserInput`, `AgentRunOutput`, `EvalTrace`, `JudgeVerdict`) |
| Evaluation prompts | `eval/prompts/judge_system.md`, `rubric_task_agent.md`, `rubric_planning_agent.md` |
| Runner logic | `test/eval/harness/eval_target.dart` (seam) + `eval/run_level2.sh` + `eval/grade_run.md` |
| Level 1 assertions | `test/eval/harness/eval_assertions.dart` + `test/eval/scenarios/*_test.dart` |

## Current state (handover)

Branch: `test/agent_evals`; everything below is present (Phase 0 scaffold,
Phase 1 planner/task benches, `ScriptedEvalTarget`, `LiveEvalTarget`, shared
scenario catalog with governance metadata, model-class profiles, production
profile/model/provider seeding for scripted and live benches, and
trace/verdict/provenance digest binding, including outer model-invocation
records for workflow-backed traces, judge provenance in verdict artifacts, and
external protected scenario catalog loading with manifest-bound catalog
evidence and protected trace output guards, plus scenario-scoped recoverable
tool-result allowances and public stress-tagged adversarial cases for both
agents, plus digest-bound scenario review metadata that tuning-readiness uses
before counting adversarial, synthetic, production-replay holdout, or protected
holdout evidence, plus public adversarial workflow cases that carry committed
durable-state oracles and scripted workflow coverage-map guards, plus optional
bounded human-calibration review queues that cover model class, agent kind,
judge pass/fail, protection bucket, and primary-capability strata before
humans label a subset, plus optional independent human review votes on completed
gold labels with derived human-human reliability gates, plus diagnostic
pairwise A/B preference votes and quorum summaries for subjective free-text
quality).
Promotion reports now include display-only evidence planning for blocked or
inconclusive candidate-vs-baseline decisions.
ADR is **0029**
(`docs/adr/0029-agent-evaluation-harness.md`).

### Run it

```
fvm flutter test test/eval        # Level 1 — all examples, no keys/network, deterministic time
fvm dart analyze test/eval        # the analyzer GATE (see gotcha below)
fvm dart format test/eval
```

Current gate: 296 eval tests green, 8 expected skips without `EVAL_RUN` /
`EVAL_SCENARIOS` / `EVAL_CALIBRATION_TEMPLATE` / `EVAL_CALIBRATION` /
`LOTTI_EVAL_LIVE`, analyzer clean.
Latest active slice adds Level 2 run-manifest promotion-plan evidence plus a
report-time assertion gate via `EVAL_PROMOTION_PLAN`; direct candidate/baseline
profile env vars now render exploratory comparisons only unless they match the
plan.
Latest active slice also sanitizes failed target exception payloads before they
are written into trace JSON, so provider errors cannot persist obvious API keys,
auth headers, private local paths, or prompt-like content.
It also requires provider-request evidence for live traces with recorded model
invocations, including failed traces after a provider call, and cross-checks
each provider request against its owning model invocation so a later clean
request cannot hide a missing or mismatched earlier provider-call record. The
verifier now also checks recorded provider request temperature against the
current `ConversationRepository` effective-temperature policy: `openAi` uses
`1.0`, while other provider types use the profile temperature.
Current active slice adds manifest-bound `profileExecutionBindings`: each
profile slot is bound to the concrete non-secret provider id/type,
provider-native model id, model/profile config ids, normalized endpoint origin,
base URL digest, and effective provider request temperature used for the run.
`LiveEvalTarget` derives those bindings after environment/profile overrides,
`EvalMatrixRunner` stores their
`profileBindingSetDigest` in `manifest.json`, and `EvalRunVerifier` compares
resolved models, provider decisions, model invocations, and provider requests
against the manifest binding so a profile label cannot silently drift to a
different actual provider/model/endpoint between runs. It also adds
`EVAL_PROFILES` JSON loading for live run, verify, report, calibration
templates, and promotion config so local/frontier profile matrices can be
changed from the command line instead of by editing Dart code.
Current active slice adds focused matrix selectors: `EVAL_SCENARIO_IDS` and
`EVAL_PROFILE_NAMES` filter the loaded matrix for run, verify, report,
calibration template, and calibration phases, while `EVAL_SCENARIOS_MODE`
supports `append` (default) or `replace` for external scenario catalogs. The
selected scenario/profile set is what the run manifest digests, so later phases
must use the same selectors or verification fails closed.
Current active slice adds `eval/run_level2.sh plan [runId]`, backed by
`EvalMatrixRunner.plan(...)`, to preview the exact scenario x profile x prompt
variant x trial matrix, trace/verdict artifact paths, non-secret live
provider/model bindings, promotion-plan evidence, and scenario-catalog evidence
before spending model calls. `run(...)` executes the same planned cells, so
dry-run and live-run matrix construction share validation and artifact
preflight. The printed preview manifest digest is not a reservation; the
subsequent live run writes the authoritative manifest at execution time.
Current active slice adds raw tool-call argument oracles:
`EvalExpectations.requiredToolCalls` / `forbiddenToolCalls` assert the
model-facing `AgentRunOutput.toolCalls` layer separately from durable
proposals. Matchers use exact tool names, recursive JSON containment, distinct
required call/list-item matching, and raw tool-schema validation, so scenarios
can hard-check due date, estimate, priority, label, and checklist arguments
before persistence or batching transforms them.
Current active slice adds scenario-authored cascade wake oracles:
`EvalExpectations.cascadeWakes` scopes raw tool-call and durable-state
expectations to a specific wake inside a same-task transcript cascade. The
live task cascade runner writes those wake-specific checks into each
`EvalTrace.level1Checks`, so the trace JSON is the source of truth for wake
success/failure. Trace schema 10 adds optional `EvalTraceCascadeWake` metadata
(`cascadeId`, `wakeIndex`, `wakeCount`); real `trialIndex` remains the repeated
trial index, and wake identity is added to trace filenames, verifier keys, and
calibration keys. Reporter and tuning-readiness code now exclude cascade wake
traces from repeated-trial reliability and promotion evidence while still
rendering provider request/cache diagnostics. The intended hard-gate boundary is
structured behavior: estimate, priority, due date, labels, checklist updates,
and persisted proposals. Generated reports and summaries are still read into
`AgentRunOutput.report`, trace JSON, and judge inputs, but free-text quality
should be judged by LLM/human comparative review and quorum rather than brittle
Level 1 string assertions.
Current active slice makes the main matrix runner fail closed on deterministic
semantic failures: `EvalMatrixRunner.run(...)` still writes the complete trace
matrix first, then exits non-zero when any `EvalTrace.level1Checks` entry
failed. Artifact/provenance verification still runs in the same pass, so a
failed live model attempt leaves debuggable traces without looking like a green
eval run.
`eval/run_level2.sh diagnose [runId]` now renders those failed raw traces
without requiring judge verdicts: it checks manifest/trace consistency, then
prints each failing trace's provider/model, tool calls, proposal tools, report
snippet, and failed Level 1 check details for fast prompt/model tuning.
Current active slice adds that comparative-review data model:
`EvalPairwisePreferenceVote` binds two trace artifacts by run, scenario,
profile, prompt variant, trial, cascade identity, trace digest, scenario
digest, profile digest, and prompt-variant digest; records reviewer and
protocol blinding metadata; and lets
`EvalPairwisePreferenceReporter` derive quorum outcomes (`optionAWins`,
`optionBWins`, `tie`, `noConsensus`, `incomplete`, or `invalid`). These
pairwise preference records remain diagnostic and separate from `JudgeVerdict`
and profile promotion until a future pre-registered policy opts them in.
The reporter supports one tuning axis per comparison: profile/model-class A/B
under the same prompt variant, or prompt-variant A/B under the same profile.
Votes that change both axes in one comparison are invalid so subjective quorum
results cannot hide a confounded experiment design.
The quorum also rejects mixed review protocols: reviewer kind/model, prompt
digest, calibration-set version, blinding flags, and trace-order randomization
must match across pooled votes.
Current active slice also makes one vote per `<safeVoteId>.preference.json`
a first-class run artifact. `TraceWriter.readRun` deliberately ignores those
files so ordinary verification, readiness, calibration, and promotion gates stay
trace/verdict-only; report mode reads them explicitly after verification and
prints a diagnostic A/B section. The preference reader rejects stale or orphaned
trace bindings by recomputing trace digests, and trace overwrite refuses to
leave old preference votes behind unless the caller explicitly deletes them.
Known limitation: the current cascade live runner is still a sidecar smoke
entrypoint rather than part of the main `EvalMatrixRunner` run path.
Current active slice adds provider response-side provenance: the real
`ConversationRepository` stream loop records authoritative provider-reported
model ids, system fingerprints, provider names, and service tiers when exposed,
or an explicit unavailable reason when the provider/adapter does not expose
authoritative response identity. Gemini native chunks are intentionally marked
response-model unavailable because their normalized `model` field is currently
adapter-synthesized from the request model. `EvalRunVerifier` now requires one
provider response metadata record per live provider request, rejects response
model drift against request/manifest binding, and requires response models for
OpenAI, Mistral, and Ollama traces.
Previous active slice adds a scenario-catalog preflight for private
`EVAL_SCENARIOS` catalogs before expensive live runs. The slice also raises
default Level 2 profiles to three trials so the planned run can satisfy
model-class tuning policy.
Current active slice expands the safe public adversarial workflow corpus
without treating it as protected holdout evidence: new task/planner cases cover
fixed-appointment preservation, ambiguous capture parsing, label scope, and
status-boundary follow-up work; all public adversarial workflow cases now carry
durable-state oracles and coverage-map tests.
Current active slice adds `EVAL_CALIBRATION_TEMPLATE_MAX_ROWS` for
deterministic bounded human-label templates. The selector validates the full
judged run first, covers calibration strata, emits aggregate coverage/cross-cell
counts and digests, and keeps default full-template behavior when no max is set.
The bounded queue is review planning only; tuning readiness still requires a
completed human-label set that passes `EvalJudgeCalibration.evaluate`.
Current active slice adds independent human-review reliability to calibration
labels: duplicate completed labels remain invalid, pre-adjudication votes live
inside the single gold label as `independentReviews`, the report derives
pairwise human pass/score agreement and unresolved-disagreement findings from
raw labels, and the default model-class tuning policy requires enough human
review pairs, high human-human agreement, Wilson lower bounds, and zero
unresolved human disagreement, plus blinded human-review protocol evidence.
Current active slice adds planning-only promotion evidence estimates: when a
candidate has a policy-positive observed judge-pass delta but the Wilson
lower-bound gate is underpowered, the report estimates additional paired judged
scenarios needed under observed pass rates. It suppresses that estimate for
missing verdicts, incomplete trial sets, weak observed effects, or hard
quality/cost rejections, and documents that new scenarios must come from a
pre-registered readiness/protected catalog.
Current active slice adds optional weighted token-cost semantics to
`EvalProfile`: profiles may record non-secret integer weights for reported
input, output, cached-input, and thought tokens. Default weights stay omitted
from JSON and preserve legacy token-ratio promotion behavior. When either side
of a promotion comparison has explicit weights, the resource gate uses weighted
reported cost instead of raw `input + output` tokens, renders token and cost
ratios plus weighted/default profile modes, and blocks promotion when required
usage evidence is missing instead of treating missing usage as free.
Current active slice adds paired discordant judge evidence to promotion
decisions: the reporter counts candidate-only and baseline-only scenario wins,
renders the discordant count and one-sided exact sign-test p-value, requires a
minimum discordant count by default, and treats low/no discordant evidence as
inconclusive. The evidence plan now estimates additional judged pairs needed to
satisfy both the Wilson lower-bound gate and the paired discordant/sign-test
gate under observed rates.
Current active slice adds `EVAL_PROMOTION_PLAN`, a pre-registered non-secret
JSON artifact for model-selection claims. `eval/run_level2.sh run` forwards a
draft plan into the manifest as non-secret subject-digest evidence, and the
report gate can derive candidate/baseline from the final plan, validates plan
scenario/profile digests against the run manifest, validates `policyDigest`
against the fixed promotion policy payload, requires the plan subject digest to
match the run-manifest evidence, and requires `manifestDigest` to match the
verified run manifest before asserting `promote`. Direct promotion profile env
vars still work for exploratory reports, but if they are used with a plan they
must match it and they are not assertion-gated by themselves.
Current active slice adds first-class prompt-policy variants as a matrix axis
separate from `EvalProfile`: `EVAL_PROMPT_VARIANTS` can name non-secret
task/day-agent `generalDirective` and `reportDirective` overlays, while
`EVAL_PROMPT_VARIANT_NAMES` selects a subset for a run. The real workflow
benches seed those into production template-version fields with deterministic
variant-digest version ids. Manifests record `agentDirectiveVariants` plus
`agentDirectiveVariantSetDigest`, traces record the selected variant and
`agentDirectiveVariantDigest`, and non-default artifacts get a
`prompt-<variant>` filename segment so model-class comparisons are not
confounded with prompt tuning.
Current active slice adds protected holdout source-digest uniqueness: tuning
readiness and catalog preflight reject duplicate protected holdout
`review.sourceDigest` values, so multiple scenario IDs cannot count as
independent protected evidence when they come from the same production-replay
source record.
Current active slice hardens reporter promotion and slice denominators:
candidate-only or baseline-only scenarios now block promotion instead of merely
rendering as low-overlap context, missing token/cost evidence blocks promotion in
both default token and weighted-cost modes, and split/model-class/capability
coverage uses the scenario x profile cross-product rather than only observed
scenario-profile cells.
Current active slice also makes reporter uncertainty harder to overread:
profile and capability rows render scenario, complete-scenario, trace,
judged-trace, judged-coverage, and `pass^k` denominators; default summary Wilson
intervals are clustered at the scenario or scenario-profile-cell level while
trace-level intervals are explicit diagnostics; and promotion still enforces
discordant paired judge evidence and the sign-test over the judged paired subset
even when an exploratory policy allows missing verdicts.
Current active slice adds `EvalReportContext` for report-mode authoritative
slice coverage: the pure reporter keeps observed-only diagnostics, but the
Level 2 report path now passes the verified scenario/profile matrix and run
manifest into `EvalReporter.render`; the reporter validates scenario/profile
digests against the manifest and computes split/model-class/capability
denominators from canonical scenarios and profiles, so completely missing
profiles, scenarios, splits, or capabilities render as zero-trace coverage.

### File inventory (all present)

```
eval/                                    # repo-root, non-build
  README.md  prompts/{judge_system,rubric_task_agent,rubric_planning_agent}.md
  calibration/README.md # non-secret human-label schema for judge calibration
  grade_run.md       # Claude Code judge runbook (trace dir -> verdicts)
  run_level2.sh      # Level 2 orchestration + optional calibration report
  runs/              # git-ignored run artifacts

test/eval/harness/                       # Dart support library
  eval_models.dart        # plain-data scenario/app-state proposals/output/profile/proposal/resolved-model/model-invocation/trace/verdict (+JSON); reuses InferenceUsage
  eval_assertions.dart    # Level 1 suite + ExpectedDurableState oracle checks
  eval_target.dart        # EvalTarget seam + EvalTargetRunContext + FixtureEvalTarget
  trace_writer.dart       # write traces / verify digest-bound verdicts (dart:io)
  eval_matrix_runner.dart # scenario x profile x prompt variant x trial execution + per-cell context + trace writing
  eval_reporter.dart      # per-profile summary + uncertainty/pairing (pure)
  eval_judge_calibration.dart # human-label agreement reports (pure)
  eval_run_verifier.dart  # exact run matrix + verdict/Level 1/provenance consistency checks
  eval_scenario_validation.dart # catalog reference/governance validation
  eval_tuning_readiness.dart # development-smoke vs model-class tuning-ready gates
  eval_provenance.dart    # canonical sha256 JSON/prompt/tool/runtime digest helpers
  eval_profile_config.dart              # EvalProfile -> production AiConfig rows + decoys
  profiles.dart           # local-small/local-reasoning/frontier-fast/frontier-reasoning
  proposal_record_mapper.dart            # final-state ChangeSetEntity -> ProposalRecord mapper
  scripted_agent_behavior.dart           # neutral single-/multi-turn scripted model behavior
  eval_harness.dart       # barrel — PURE files only; does NOT export the benches/targets
  scripted_eval_target.dart              # EvalTarget wrapper over the real workflow benches
  scripted_conversation_repository.dart  # ScriptedConversationRepository (real ConversationManager)
  observing_conversation_repository.dart # live ConversationRepository observer for model/prompt/tool provenance
  planner_eval_bench.dart # PlannerEvalBench.runWake/runDraftingWake + ScriptedAgentBehavior
  task_agent_eval_bench.dart             # TaskAgentEvalBench.runWake
  live_eval_target.dart                  # gated Level 2 target over real ConversationRepository
  tool_call_record_mapper.dart           # persisted AgentMessage action rows -> ToolCallRecord

test/eval/harness/*_test.dart            # pure harness regression tests
  eval_assertions_test.dart          # scenario-specific durable-state oracles
  eval_matrix_runner_test.dart       # exact matrix execution + failed-target trace capture
  eval_profile_config_test.dart      # local/frontier config rows + invariant checks
  eval_reporter_test.dart            # reliability, confidence intervals, paired comparisons, promotion gates
  eval_judge_calibration_test.dart   # judge/human agreement and coverage gaps
  eval_scenario_validation_test.dart # catalog and durable-state reference validation
  eval_tuning_readiness_test.dart    # readiness policy gates for tuning claims
  eval_run_verifier_test.dart        # missing/extra/duplicate/orphan/bad-verdict cases
  live_eval_target_test.dart         # env gates + fake live streaming provider
  eval_provenance_test.dart          # manifest/set/env provenance hashing
  proposal_record_mapper_test.dart    # stale intermediate ChangeSetEntity upsert regression
  tool_call_record_mapper_test.dart   # task/planner persisted action payload mapping
  trace_writer_test.dart             # rejects embedded verdicts in trace JSON

test/eval/scenarios/                     # dataset + Level 1 example tests
  eval_scenarios.dart                # shared plain-data scenario catalog
  eval_scenarios_test.dart           # catalog uniqueness + JSON round-trip checks
  eval_scenario_catalog.dart         # public + optional external EVAL_SCENARIOS loader
  eval_scenario_catalog_test.dart    # protected catalog evidence and validation
  planning_agent_eval_test.dart      # planner via FixtureEvalTarget + trace/reporter round-trip
  task_agent_eval_test.dart          # task via FixtureEvalTarget
  planner_workflow_eval_test.dart    # REAL DayAgentWorkflow via ScriptedEvalTarget
  task_agent_workflow_eval_test.dart # REAL TaskAgentWorkflow via ScriptedEvalTarget
  live_runner_test.dart              # tagged Level 2 runner; skips unless LOTTI_EVAL_LIVE=1
  report_test.dart                   # Level 2 report/verify entrypoint
```

### Gotchas (these cost time this session — read before editing)

- **Analyzer:** the MCP `dart-mcp.analyze_files` under-reports — it silently
  missed a missing top-level function *and* 6 lint issues. **Gate on
  `fvm dart analyze test/eval`** (CLI), not the MCP tool.
- **Task-agent bench needs GetIt + fallbacks in the test's `setUpAll`:**
  `registerAllFallbackValues()`, then `setUpTestGetIt(additionalSetup: …)`
  registering `PersistenceLogic` (`MockPersistenceLogic`) and `TimeService`;
  `tearDownTestGetIt` in `tearDownAll`. The planner bench is self-contained.
- **`MockTask` name clash:** mocktail defines a `MockTask` (mock of `Task`) in
  `test/mocks/mocks.dart`; the eval models also define `MockTask`. In tests that
  need both, import mocks with `show` (e.g. `show MockPersistenceLogic`).
- **`AgentDomainEntity.agent(...)` requires `vectorClock:`** (pass `null`).
- **Planner wakes:** drafting days resolve from a `drafting:<dayId>` trigger
  token via `resolvePlannerWakeDay`; the bench also passes the bare `dayId`
  token only for those day-scoped wakes. Capture-only wakes resolve the day from
  the submitted capture fixture and keep the production trigger set as
  `capture_submitted:<captureId>`. The bench wires the real
  `DayAgentPlanService` and real `DayAgentCaptureService` to an eval-local
  entity/link store and scenario-backed journal task map, so `plannedBlocks` are
  read back through `DayAgentPlanService.draftPlanForDay`,
  `parsedCaptureItems` are read from persisted `ParsedItemEntity` rows, and
  observations are read from persisted `AgentMessageEntity` payloads. Plan-diff
  proposals are read from persisted `ChangeSetEntity.items`. It maps
  `MockedAppState.captures` into `CaptureEntity` rows, nested parsed fixtures
  into `ParsedItemEntity` rows linked with production `AgentLink`s,
  `existingBlocks` into a seeded `DayPlanEntity`, and scenario capacity into
  both `DayAgentConfig` and the seeded baseline plan. The real workflow tests
  parse `ScriptedConversationRepository.lastUserMessage` and prove the
  production prompt contains the expected `capture`, `taskCorpus`,
  `drafting.baselinePlan`, `drafting.decidedTasks`,
  `drafting.decidedCaptureItems`, trigger tokens, and non-default capacity. This
  covers production validation, sorting, forced-retry behavior, prompt
  materialization, capture parsing, and proposal normalization.
- **Task bench output:** raw scripted tool calls are kept as diagnostics, but
  `report`, `observations`, `usage`, and `proposals` now map from the entities
  the real `TaskAgentWorkflow` persisted (`AgentReportEntity`, observation
  `AgentMessageEntity` + payload, `WakeTokenUsageEntity`,
  `ChangeSetEntity.items`). Scenarios can seed pre-existing `proposalSets` and
  `proposalDecisions`; the bench converts them into production
  `ChangeSetEntity` and `ChangeDecisionEntity` rows, exposes them through an
  eval-local entity store, builds a decision-driven `ProposalLedger`, and maps
  `AgentRunOutput.proposals` from the final entity store after production
  consolidation, and maps persisted `AgentMessageKind.toolResult` rows into
  `AgentRunOutput.toolResults` so rejected tool attempts remain visible. The
  regression tests deliberately include a
  rejected `update_report` call, a batch deferred tool that explodes into
  persisted per-item proposals, and a merged-pending-set case where raw tool
  args attempt a duplicate but final durable state has one consolidated open
  copy and one retired/retracted row. They also seed a resolved/rejected prior
  proposal and prove a later valid-looking duplicate raw tool call does not
  create a fresh pending proposal. The bench also maps scenario tasks and
  checklist items into real `Task`/`ChecklistItem` entities, so production
  checklist-state and existing-title resolvers can suppress no-op proposals
  before persistence. Its active `AgentSlots.activeTaskId` now resolves from one
  unambiguous `decided_task:<id>` trigger token when present, rejects unknown or
  conflicting decided-task tokens, and falls back to the first task only for
  triggerless scenarios. It also maps scenario category definitions, correction
  examples, task `labelIds`, task `aiSuppressedLabelIds`, and label definitions
  into production `JournalDb` lookups, so available-label prompt context and
  label proposal summaries use scenario-backed production data. Level 1 rejects
  pending label proposals for unknown, deleted, already-assigned, suppressed, or
  out-of-category labels.
- **Profile/model/provider-decision provenance:** both real workflow benches seed
  `AiConfigInferenceProfile` → `AiConfigModel` → `AiConfigInferenceProvider`
  rows from `EvalProfile`, bind `AgentConfig.profileId` plus template/version
  `profileId`, and record `output.resolvedModel` plus `output.providerDecision`.
  The seed includes resolvable legacy fallback rows and duplicate
  provider-native decoys, so tests prove the workflow resolves by profile
  model-config id, not by label, legacy template model id, or provider-native
  coincidence. `providerDecision` records the canonical profile/model class,
  selected model/provider rows, candidate/decoy/legacy row ids, and non-secret
  environment-key presence. `resolvedModel` also records
  `updateWakeRunTemplate.resolvedModelId` and `WakeTokenUsageEntity.modelId`,
  and the verifier compares it against the provider decision instead of static
  default provider assumptions so live provider overrides remain verifiable.
- **Two scripting patterns, both work:** planner bench uses
  `ScriptedConversationRepository` (a REAL `ConversationManager`, drives
  `strategy.processToolCalls`); task bench uses the existing
  `MockConversationRepository.sendMessageDelegate` + a MOCK `ConversationManager`.
  The model seam either way is `ConversationRepository.sendMessage(... strategy:)`
  returning `InferenceUsage` — that is the scripted/live switch.
- **Scripted behavior storage:** keep `ScriptedAgentBehavior` outside
  `EvalScenario`. Use `ScriptedEvalTarget.fromMap({...})` with a side map keyed
  by `scenario.id`, or `fromProfileMap({...})` for profile-specific baselines,
  so the scenario model remains plain JSON.
- **Trace/verdict integrity:** `TraceWriter.writeTrace` refuses silent
  overwrites and strips verdicts from trace JSON. `TraceWriter.readTraces`
  rejects embedded verdicts, non-current `EvalTrace.schemaVersion` values, and
  missing/stale sibling verdict digests by default. Verdict files have their
  own `JudgeVerdict.schemaVersion` and judge provenance block. SHA-256 digests
  must use the exact `sha256:` + 64 lowercase-hex shape. `EvalRunVerifier` then
  checks the exact
  scenario × profile × prompt variant × trial matrix, rejects orphan verdicts, recomputes Level 1
  checks, validates workflow run/thread provenance when a target records it,
  validates resolved model/provider provenance against `EvalProfile`, validates
  recorded model invocations and provider requests against `providerDecision`
  and the owning model invocation, requires provider request and response
  provenance for live traces with recorded model invocations, rejects response
  model drift where providers report model identity, and validates
  the judge score/pass contract plus judge runner/model, prompt digest,
  calibration set version, profile visibility, and run-level consistency so one
  report cannot average mixed judge models or calibration regimes.
- **Scenario governance + provenance:** every committed scenario must declare at
  least one capability id (`agent.domain.behavior` shape), a split/source, and
  adversarial metadata when applicable. Scenario review metadata is optional for
  loading but, when present, must carry reviewer/rationale/review time and a
  `subjectDigest` over the scenario JSON with the review block omitted; optional
  `sourceDigest` provenance is required before synthetic or protected scenarios
  count as tuning-ready evidence. Stale review digests are catalog validation
  failures. `EvalTrace.schemaVersion` is
  now 9 and
  includes `provenance` (`manifestDigest`, `scenarioDigest`, `profileDigest`,
  eval prompt/rubric digest, tool-schema digest, code revision). Level 2 runs
  write `manifest.json` first; `TraceWriter.readRun` requires that manifest,
  recomputes its hash, checks the trace schema version, and rejects traces bound
  to another manifest. `EvalRunVerifier` then recomputes the scenario/profile,
  prompt, tool-schema, and run-manifest digests from the canonical catalog,
  profiles, current prompt/tool files, and run artifact. Real workflow benches
  also record `output.runtimePrompt` hashes from the actual
  `ConversationRepository` call surface plus one `modelInvocations` record per
  observed outer `sendMessage` call and one `providerRequests` record per
  internal provider request; raw prompt text is not stored.
- **Repeated-trial context:** `EvalMatrixRunner` now passes
  `EvalTargetRunContext(runId, scenarioId, profileName, trialIndex)` into every
  target call. `ScriptedEvalTarget` forwards it into both real workflow benches,
  which derive workflow `runKey`/`threadId` values from `context.cellId` and
  record them on `AgentRunOutput.workflowRun`. `LiveEvalTarget` uses the same
  context-bound run keys and thread IDs; any future cache keys or stochastic
  seeds should also derive from this context so `pass^k` reliability reflects
  independent attempts rather than accidental reuse.
- **Reporter reliability:** `EvalReporter` counts scenario-level `pass^k`
  reliability only when the trace set has exactly one trial for every expected
  index `0..trialCount-1`; duplicate, shifted, extra, or missing trial indexes
  are incomplete. A complete Level 1 trial set with a missing verdict still has
  zero judge `pass^k`. Profile and capability rows render scenario,
  complete-scenario, trace, judged-trace, judged-coverage, and `pass^k`
  denominators next to trace pass rates. It also reports
  split/model-class/primary-capability rows with profile count, scenario count,
  scenario-profile cells, complete
  scenario-profile cells, expected trial count, trace count, judged trace count,
  and coverage. With an `EvalReportContext`, those slice denominators come from
  the canonical scenario/profile matrix after validating its digests against the
  run manifest; observed-only rendering remains available for ad hoc debugging.
  Default summary Wilson 95% confidence intervals cluster repeated trials at the
  scenario or scenario-profile-cell level; explicit trace-level intervals remain
  diagnostic. Paired profile comparisons use only scenarios where both profiles
  have complete trial sets while surfacing missing verdicts, profile-only
  scenarios, and incomplete/ambiguous scenario groups. Rendered comparisons mark
  zero-overlap pairs as `not comparable` and fewer than eight paired scenarios
  as `low n`.
  `EvalReporter.evaluateProfilePromotion` is the claim gate above those
  descriptive comparisons: it compares an explicit candidate to an explicit
  baseline, orients deltas as candidate-minus-baseline, and returns `promote`,
  `reject`, `inconclusive`, or `blocked`. The default policy requires tuning
  readiness, at least 12 paired judged scenarios, no missing verdicts, observed
  and conservative Wilson-bound judge-pass improvement, enough discordant paired
  judge outcomes, a supplemental candidate-vs-baseline one-sided sign-test
  p-value, no Level 1/goal/quality regression, bounded efficiency regression,
  and no more than 25% paired token-or-weighted-cost regression. Relaxing the
  missing-verdict policy for exploratory use does not disable the discordance or
  sign-test gates over the judged paired subset. Promotion decisions also render
  a planning-only evidence estimate for underpowered
  lower-bound and paired-sign gates; the estimate uses the exact current
  reporting gates under observed pass and candidate-only/baseline-only win
  rates, never changes promotion status, and is suppressed for missing verdicts,
  incomplete trial sets, weak observed effects, or hard quality/cost rejections.

### Source-of-truth references

- Workflows (identical entry point `execute({agentIdentity, runKey, triggerTokens,
  threadId})`): `lib/features/agents/workflow/task_agent_workflow.dart`,
  `lib/features/daily_os_next/agents/workflow/day_agent_workflow.dart`.
- Tool-name constants: `lib/features/agents/tools/agent_tool_registry.dart`
  (`TaskAgentToolNames`), `lib/features/daily_os_next/agents/tools/day_agent_tool_names.dart`.
- Inference seam + token type: `inference_repository_interface.dart`,
  `lib/features/ai/model/inference_usage.dart`.
- Benches mirror these tests:
  `test/features/daily_os_next/agents/workflow/day_agent_workflow_test.dart`
  (`_ConversationHarness` + drafting stubs) and
  `test/features/agents/workflow/task_agent_workflow_test_helpers.dart`
  (`createTestWorkflow` / `stubFullExecutePath` / `MockConversationRepository`).

### Next task — Holdouts + calibration data

The next hardening slice should add protected data, not more plumbing:

- populate a small human-reviewed calibration JSON using
  `eval/calibration/README.md`. Start with:

  ```
  EVAL_CALIBRATION_TEMPLATE=/private/tmp/judge_gold_v1.template.json \
  EVAL_CALIBRATION_TEMPLATE_MAX_ROWS=24 \
    eval/run_level2.sh template <runId>
  ```

  Have humans fill the null pass/score fields, then run
  `eval/run_level2.sh calibrate <runId>` to track judge/human disagreement by
  capability and profile class. For tuning-readiness reporting, run
  `EVAL_CALIBRATION=/private/tmp/judge_gold_v1.json eval/run_level2.sh report <runId>`
  so the human calibration report participates in the readiness gates;
- create private production-replay scenario JSON outside the repo and run with
  `EVAL_SCENARIOS=/private/path/catalog.json`. The external catalog envelope is
  `schemaVersion: 1`, `catalogId`, `protectedHoldout: true`, and `scenarios`.
  Protected holdout scenarios must use `split: holdout` and
  `source: productionReplay`. Their review metadata must include unique
  `sourceDigest` values per underlying production replay record. Before live
  model calls, run
  `EVAL_SCENARIOS=/private/path/catalog.json eval/run_level2.sh catalog` to
  enforce catalog-only tuning gates for protected holdout depth, planned
  profile/model-class/trial coverage, primary-capability stress coverage, and
  digest-current review/source metadata;
- expand the public `test/eval/scenarios/` catalog only with cases that are safe
  to commit. A public `holdout` split is process metadata, not a real private
  holdout.

## Phase 0 — Scaffold + one working example

Compiling, analyzer-green, with one passing example test. No live model calls,
no judge invocation wired into CI.

### Files

```
eval/
  README.md                     # how the whole thing fits together
  prompts/
    judge_system.md             # judge persona + output contract
    rubric_task_agent.md        # goal/quality/efficiency rubric — task agent
    rubric_planning_agent.md    # goal/quality/efficiency rubric — planner
  grade_run.md                  # Claude Code runbook: trace dir -> verdicts
  run_level2.sh                 # orchestration: produce traces, then grade
  runs/                         # git-ignored artifacts (created at runtime)

test/eval/harness/
  eval_models.dart              # scenario, app state, user input, profile,
                                #   run output, trace, verdict, EvalCheck (+JSON)
  eval_assertions.dart          # Level 1 assertion library (pure functions)
  eval_target.dart              # EvalTarget seam + FixtureEvalTarget
  trace_writer.dart             # write traces / read verdicts (dart:io)
  eval_reporter.dart            # aggregate verdicts+traces -> summary
  profiles.dart                 # canonical local/frontier EvalProfiles
  eval_harness.dart             # barrel export

test/eval/scenarios/
  planning_agent_eval_test.dart # ONE working example (Level 1, green)
```

### Data model contract (plain Dart, JSON-serialisable)

- `enum AgentKind { taskAgent, planningAgent }`
- `EvalScenario { id, title, agentKind, appState, userInput, expectations }`
- `MockedAppState { now, tasks, captures, existingBlocks, proposalSets, proposalDecisions, capacityMinutes, categoryIds, categories, labels }`
- `MockTask { id, title, status, due?, estimateMinutes?, categoryId?, labelIds, aiSuppressedLabelIds, checklist }`
- `MockChecklistItem { id, title, isChecked }`
- `MockDayBlock { id, taskId?, categoryId, start, end, title?, type, state, reason?, note? }`
- `MockCapture { id, transcript, capturedAt?, createdAt?, dayId?, audioRef?, deletedAt?, parsedItems }`
- `MockParsedCaptureItem { id, title, categoryId, kind, confidence, confidenceScore, lowConfidence, spokenPhrase?, matchedTaskId?, estimateMinutes?, timeAnchor?, proposedUpdate?, createdAt?, deletedAt? }`
- `MockCategoryDefinition { id, name, color, private, active, isAvailableForDayPlan?, deletedAt?, correctionExamples }`
- `MockCorrectionExample { before, after, capturedAt? }`
- `MockLabelDefinition { id, name, color, applicableCategoryIds?, deletedAt? }`
- `MockProposalSet { id, targetId?, status, items, createdAt?, resolvedAt?, deletedAt? }`
- `MockProposalItem { toolName, args, humanSummary, status, groupId? }`
- `MockProposalDecision { id, changeSetId, itemIndex, toolName, verdict, actor, targetId?, createdAt?, reason?, humanSummary?, args }`
- `UserInput { transcript, triggerTokens }`
- `EvalScenarioMetadata { capabilityIds, split, source, isAdversarial, tags }`
- `EvalExpectations { maxTokenBudget?, maxToolCalls?, mustCallTools, mustNotCallTools, requiredToolCalls, forbiddenToolCalls, allowedFailedToolNames, maxAllowedToolResultFailures, durableState }`
- `ExpectedToolCallState { toolName, argsContain }`
- `ExpectedDurableState { proposal/plannedBlock/parsedCapture/mutatedEntry counts, reportContains, observationContains, allowed/required/forbidden mutatedEntryIds, required/forbidden proposals, proposal anyOf groups + scoped counts, required/forbidden plannedBlocks, plannedBlock anyOf groups + scoped counts, required/forbidden parsedCaptureItems, parsedCapture anyOf groups + scoped counts }`
- `ExpectedProposalState { toolName?, targetId?, status?, changeSetStatus?, argsContain, humanSummaryContains }`
- `ExpectedPlannedBlockState { id?, taskId?, categoryId?, min/maxDurationMinutes?, startAtOrAfter?, endAtOrBefore? }`
- `ExpectedParsedCaptureState { id?, captureId?, kind?, titleContains?, categoryId?, matchedTaskId?, confidence?, min/maxConfidenceScore?, lowConfidence? }`
- `AgentRunOutput { success, error?, toolCalls, toolResults, plannedBlocks, plannedCapacityMinutes?, report?,`
  `observations, proposals, resolvedModel?, providerDecision?, workflowRun?, runtimePrompt?,`
  `mutatedEntryIds, usage` `(InferenceUsage), turnCount, wallClockMs }`
- `ToolCallRecord { name, args }`
- `PlannedBlockRecord { id, taskId?, categoryId, start, end }`
- `AgentReportRecord { oneLiner, tldr, content }`
- `ProposalRecord { changeSetId, changeSetStatus, targetId, itemIndex,`
  `toolName, args, humanSummary, status }`
- `ResolvedModelRecord { profileId, modelConfigId, providerModelId, providerId,`
  `providerType, templateId?, templateVersionId?, wakeRunResolvedModelId?,`
  `usageModelId? }`
- `ProviderDecisionRecord { profileName, modelClass, isLocal, profileId,`
  `selectedModelConfigId, selectedProviderId, selectedProviderType,`
  `selectedProviderModelId, candidateModelConfigIds, decoyModelConfigIds,`
  `legacyModelConfigIds, candidateProviderIds, envPresence }`
- `RuntimePromptRecord { systemDigest?, userDigest?, toolSchemaDigest?, toolCount }`
- `ModelInvocationRecord { invocationIndex, providerModelId, providerId,`
  `providerType, runtimePrompt, toolNames, forcedToolName? }`
- `ProviderRequestRecord { invocationIndex, requestIndex, turnIndex,`
  `providerModelId, providerId, providerType, messageDigest, messageCount,`
  `toolSchemaDigest, toolCount, toolNames, forcedToolName?, temperature,`
  `thoughtSignatureCount }`
- `ProviderResponseRecord { invocationIndex, requestIndex, turnIndex,`
  `providerType, chunkCount, responseModelIds, systemFingerprints,`
  `providerNames, serviceTiers, responseModelUnavailableReason? }`
- `EvalProfile { name, isLocal, modelClass, modelId, temperature,
  maxCompletionTokens?, tokenBudget, trialCount, inputTokenCostMicros?,
  outputTokenCostMicros?, cachedInputTokenCostMicros?,
  thoughtsTokenCostMicros? }`
- `EvalCheck { name, passed, detail }`
- `JudgeProvenanceRecord { judgeName, judgeModel, promptDigest,`
  `calibrationSetVersion, profileVisible, modelIdentityVisible }`
- `EvalScenarioCatalogEvidence { scenarioSetDigest, publicScenarioCount,
  externalScenarioCount, externalCatalogDigest?, externalCatalogId?,
  externalSourceLabel?, protectedHoldout, protectedScenarioIds,
  protectedHoldoutScenarioIds }`
- `EvalRunManifest { schemaVersion=2, runId, traceSchemaVersion, targetName, targetKind, createdAt, command, scenarioSetDigest, profileSetDigest, profileBindingSetDigest, agentDirectiveVariantSetDigest, promptDigest, toolSchemaDigest, codeRevision, gitDirty, dirtyDiffDigest?, envPresence, scenarioCatalogEvidence?, agentDirectiveVariants, manifestDigest? }`
- `EvalTrace { schemaVersion=11, runId, scenario, profile, agentDirectiveVariant, provenance, output,`
  `trialIndex, cascadeWake?, level1Checks, verdict? }`
- `EvalTraceCascadeWake { cascadeId, wakeIndex, wakeCount }`
- `JudgeVerdict { schemaVersion=1, traceDigest?, judge,`
  `goalAttainment(1-5), quality(1-5), efficiency(1-5), pass, rationale, issues }`

The harness reuses `package:lotti/features/ai/model/inference_usage.dart`
(`InferenceUsage`) verbatim for token accounting, so Level 2 numbers match what
`WakeTokenUsageEntity` records in production.

### Level 1 assertion library

Pure `EvalCheck Function(...)` helpers, grounded in real tool/field contracts:

Shared: `checkSucceeded`, `checkReportPublished`, `checkNoHallucinatedTaskRefs`,
`checkTokenBudget`, `checkToolCallBudget`, `checkOnlyAllowedTools`,
`checkExpectations`. Tool-result errors fail by default; explicit tool-recovery
stress scenarios may allow a bounded count of named failed tools through
`EvalExpectations.allowedFailedToolNames` and
`maxAllowedToolResultFailures`.

Task agent: `checkValidStatusTransitions` (rejects user-only `DONE`/`REJECTED`;
agent-settable enum is `OPEN`/`IN PROGRESS`/`GROOMED`/`BLOCKED`/`ON HOLD` — note
the spaces, see `task_agent_tool_definitions.dart:775`), `checkEstimateRange`
(`minutes` `1..1440`), `checkLabelCap` (≤3), `checkNoDuplicateChecklistTitles`.

Planner: `checkWithinCapacity` (Σ block minutes ≤ `capacityMinutes`),
`checkPlanCapacityMatchesScenario` (when the target records persisted plan
capacity), `checkNoOverlappingBlocks`, `checkBlocksUseKnownCategories`,
`checkProducedPlanForCapture`.

Each returns `EvalCheck`; a `runLevel1(scenario, output)` helper returns the
full `List<EvalCheck>` for the relevant agent. Tests assert on `.passed` with the
`.detail` as the failure reason; the runner records the same list on the trace.

### Execution seam

`abstract class EvalTarget { String get profileName; Future<AgentRunOutput> run(...); }`

Phase 0 ships `FixtureEvalTarget` (returns a pre-baked `AgentRunOutput`) so the
example test exercises the full scenario → output → assertions → trace pipeline
without live deps. `ScriptedEvalTarget` and `LiveEvalTarget` are specified here
and land in Phase 1/2.

### Working example

`planning_agent_eval_test.dart` defines a realistic planner scenario (a morning
capture transcript, three in-progress tasks with deadlines, 480-min capacity),
runs it through a `FixtureEvalTarget`, asserts the **Level 1** library both
(a) passes on a good output and (b) fails on a deliberately bad output
(over-capacity plan, hallucinated task id) — proving the assertions actually
catch regressions, not just that a widget built.

## Phase 1 — scripted bench over the real workflow

**Landed (both agents):**

- `test/eval/harness/scripted_conversation_repository.dart` — a public
  `ScriptedConversationRepository` (generalises the private `_ConversationHarness`)
  that returns canned tool calls + a fixed `InferenceUsage`.
- `test/eval/harness/planner_eval_bench.dart` — `PlannerEvalBench.runDraftingWake`
  + `ScriptedAgentBehavior`. Seeds an `EvalScenario` onto the centralized mocks
  (`makeTestIdentity` / `makeTestState` / `makeTestTemplate*` /
  `evalProfileConfig`), runs the REAL `DayAgentWorkflow.execute(...)` under
  `withClock`, and maps raw tool-call diagnostics plus resolved model
  provenance and persisted `DayPlanEntity` / `WakeTokenUsageEntity` /
  `ChangeSetEntity` output into `AgentRunOutput`.
- `test/eval/harness/task_agent_eval_bench.dart` — `TaskAgentEvalBench.runWake`.
  Mirrors the planner for `TaskAgentWorkflow.execute(...)`, reusing the existing
  task-agent test helpers (`createTestWorkflow` / `stubFullExecutePath` /
  `MockConversationRepository.sendMessageDelegate`); report, observations,
  token usage, and deferred proposals are read from persisted workflow entities.
  Requires the caller to set up GetIt (`PersistenceLogic`, `TimeService`) +
  fallbacks in `setUpAll`.
- `test/eval/harness/scripted_eval_target.dart` — `ScriptedEvalTarget`, the
  agent-agnostic `EvalTarget` wrapper over the two benches. It intentionally
  stays out of the pure `eval_harness.dart` barrel and offers
  `ScriptedEvalTarget.fromMap({...})` / `fromProfileMap({...})` for side-map
  scripted behaviours keyed by `scenario.id` and optionally `profile.name`.
- `test/eval/scenarios/eval_scenarios.dart` — shared scenario catalog used by
  Level 1 tests and future runners, with uniqueness and JSON round-trip tests.
- `TraceWriter` now refuses accidental trace overwrites, rejects embedded
  verdicts, binds sibling verdicts to `sha256:` trace digests, and supports
  `trialIndex` stems for repeated runs plus cascade wake stems when a trace has
  `EvalTraceCascadeWake` metadata.
- `EvalMatrixRunner` executes the full
  `scenario × profile × prompt variant × trialIndex` matrix, recomputes Level 1
  checks, writes one trace per cell, keeps trace read order deterministic,
  records target exceptions as failed traces so matrix cells are auditable
  instead of silently missing, and fails the run after artifact writes when any
  deterministic Level 1 check fails.
- `EvalRunVerifier` enforces exact run matrix coverage, rejects orphan verdicts,
  rejects trace-embedded scenario/profile payload drift from the canonical
  catalog, recomputes Level 1 checks from the canonical scenario/profile,
  validates `output.resolvedModel` against `output.providerDecision`, and
  validates verdict score/pass consistency. For cascade sidecar traces it
  expects one wake trace per authored task-log wake while preserving real
  repeated-trial identity.
- `EvalReporter` reports both per-trace pass rates and per-scenario `pass^k`
  reliability across repeated trials, so model-class tuning can distinguish
  occasional success from consistent behavior. It also reports
  split/model-class/primary-capability denominators. Cascade wake traces are
  excluded from reliability and promotion denominators and kept as diagnostics.
- `test/eval/scenarios/planner_workflow_eval_test.dart` and
  `task_agent_workflow_eval_test.dart` — exercise each real workflow end-to-end
  through `ScriptedEvalTarget` and grade with `runLevel1` (good-path pass + a
  regression caught). Analyzer clean; full `test/eval` suite green.

This exercises the real orchestration (profile→provider resolution, conversation
loop, real strategy tool dispatch + change-set deferral, report extraction,
planner plan service validation, state reconciliation, persistence). Both real
workflow benches now keep raw scripted tool calls only as diagnostics and map
graded durable output from persisted entities: planner blocks from the final
  `DayPlanEntity`, task reports/observations from persisted message/report rows,
token usage from `WakeTokenUsageEntity`, and confirmable proposal evidence from
final-state `ChangeSetEntity.items`. The task bench also seeds scenario
`proposalSets` and `proposalDecisions` as production `ChangeSetEntity` and
`ChangeDecisionEntity` rows, then builds `ProposalLedger` with the same
decision-driven item lifecycle used by `AgentRepository.getProposalLedger`, so
cross-wake proposal deduplication, consolidation, and rejected-history
stickiness run through the real `ChangeSetBuilder`. They also seed
production-style
`AiConfigInferenceProfile`/`AiConfigModel`/`AiConfigInferenceProvider` rows from
`EvalProfile` and record resolved model provenance on the trace. Level 2
supplies real model behavior.

**Remaining:**

- Expand adversarial proposal-state coverage beyond the current public
  stress-tagged task/planner slice, especially agent retraction/reproposal
  churn and stale resolved-parent rows with embedded pending items.
- Grow `test/eval/scenarios/` into a real dataset (≥6 scenarios per agent),
  including LLM-*generated* scenarios reviewed by a human before commit.

## Phase 2 — `LiveEvalTarget` + Level 2 run loop

**Landed first slice:**

- `LiveEvalTarget` gates on `LOTTI_EVAL_LIVE=1`, refuses default CI without
  `LOTTI_EVAL_ALLOW_CI=1`, binds profiles to provider-native model/provider
  config from env, and runs the same real workflow benches with an observing
  real `ConversationRepository`.
- Local profiles require an Ollama model (`LOTTI_EVAL_LOCAL_MODEL`,
  `OLLAMA_MODEL`, or profile-specific variants). Frontier profiles default to
  Gemini unless `LOTTI_EVAL_FRONTIER_PROVIDER` / profile-specific provider env
  points to OpenAI-compatible, Mistral, OpenRouter, etc.
- `live_runner_test.dart` is the tagged `eval-live` entrypoint. It self-skips
  unless both `LOTTI_EVAL_LIVE=1` and `--dart-define=EVAL_RUN=<runId>` are set.
- The fake streaming-provider test proves the live path uses persisted
  `AgentMessageKind.action` rows for raw tool-call diagnostics, real persisted
  usage for `InferenceUsage`, observed provider/model provenance, workflow
  run/thread IDs bound to the matrix cell, runtime prompt/tool digests, and
  per-`sendMessage` model invocation records.
- `run_level2.sh`: mode-based shell (`run`, `grade`, `verify`, `report`, `all`).
  `grade`/`verify`/`diagnose`/`report` default to the latest timestamp-named run
  directory when no run id is supplied. `diagnose` renders raw Level 1 failures
  without requiring verdicts. `report` never regenerates traces; it verifies
  exact matrix coverage, digest-bound verdicts, recomputed Level 1 checks,
  scenario governance, trace provenance, runtime prompt/tool digest shape,
  model-invocation consistency, judge provenance, and verdict score/pass
  consistency before printing profile and capability summaries.
- Run manifests: `EvalMatrixRunner` writes `manifest.json` before traces and
  binds each trace to its `manifestDigest`. `TraceWriter.readRun` requires the
  manifest, rejects stale/tampered manifests, checks manifest trace-schema
  currency, and rejects traces bound to another manifest before report
  aggregation. `EvalRunVerifier` recomputes manifest, scenario/profile set,
  prompt, tool-schema, and dirty-state digest invariants.
- Provider decisions: traces now include the intended profile/model/provider
  decision with canonical profile id, model class, selected model/provider rows,
  candidate/decoy/legacy row ids, and env-key presence booleans. The verifier
  compares resolved runtime model fields against that decision and rejects
  selected decoy/legacy rows.
- Model invocations: workflow-backed traces record each observed outer
  `ConversationRepository.sendMessage` call with selected provider/model,
  runtime prompt/tool digests, advertised tool names, and forced tool choice
  when present. The verifier requires sequential invocation indexes, checks
  that the final top-level runtime prompt matches the last invocation, and
  rejects invocations outside `providerDecision`.
- Provider requests: live traces record each internal
  `ConversationRepository` provider request made inside an outer `sendMessage`,
  including continuations after tool calls. Records include the outer invocation
  index, internal request index, provider turn index, message/tool-schema
  digests, tool names, forced tool choice, temperature, and thought-signature
  count. Live traces with recorded model invocations must include these records,
  including failed traces after a provider call; the verifier checks sequential
  request indexes, strict digest shape, matching outer invocation, provider/model
  consistency with `providerDecision`, and provider/model/tool/tool-schema
  consistency with the owning `ModelInvocationRecord`, plus effective request
  temperature against the current `ConversationRepository` policy (`openAi` ->
  `1.0`, other provider types -> profile temperature).
- Judge provenance: verdict files now carry `JudgeVerdict.schemaVersion`,
  digest binding to the exact trace file, and a nested `judge` block with
  runner/model identity, prompt digest, calibration-set version, and
  profile/model visibility. The verifier rejects stale prompt digests, empty
  judge/model/calibration fields, and profile-blind verdicts because efficiency
  is profile-aware. It also rejects mixed judge provenance inside one verified
  run, and all digest-looking fields must be full SHA-256 digests rather than
  arbitrary `sha256:` prefixes.
- Reporting slices: `EvalReporter` now emits split/model-class/primary-capability
  rows with profile, scenario, scenario-profile, expected-trial, trace,
  judged-trace, and coverage denominators, with scenario-profile and expected
  trial counts inferred from the scenario x profile cross-product so sparse
  matrix cells cannot look fully covered. It also exposes Wilson 95%
  confidence intervals for pass rates and paired profile comparisons that report
  paired-scenario coverage, Level 1/judge pass deltas, and mean judge-score
  deltas over shared complete scenario trial sets, with `not comparable`,
  `low n`, discordant judge wins, and paired one-sided sign-test evidence for
  weak pair coverage. Promotion decisions are explicit
  candidate-vs-baseline policy checks over those same paired complete scenario
  sets; they default to blocking non-tuning-ready, profile-asymmetric,
  partially judged, or token/cost-incomplete evidence and rejecting
  token/cost-regressing candidates. They also carry a display-only
  evidence plan estimating additional paired judged scenarios needed to satisfy
  the current Wilson lower-bound and paired discordant/sign-test gates under
  observed pass and candidate-only/baseline-only win rates, with caveats for
  missing/incomplete cells, weak effects, and non-sample rejections.
  `eval/run_level2.sh report`
  enforces the policy as a shell gate when `EVAL_PROMOTION_PLAN` is supplied,
  and exits non-zero unless the status is `promote`. Promotion plans bind
  candidate/baseline names, scenario/profile set digests, a canonical
  fixed-policy digest, and the verified manifest digest; the run manifest must
  also contain matching plan-subject evidence recorded before the run outcomes
  existed. Direct profile env vars remain descriptive unless they match such a
  plan.
- Judge calibration: `EvalJudgeCalibration` loads non-secret human-label sets
  keyed by
  `(scenarioId, profileName, agentDirectiveVariantName, trialIndex)` and bound
  to `scenarioDigest`, `profileDigest`, `agentDirectiveVariantDigest`,
  `JudgeVerdict.traceDigest`, and a parsed-verdict digest in completed
  calibration files. It keeps the human
  gold-label set `version` separate from the verdicts'
  `judgeCalibrationSetVersion`, so a first `human-gold-v1` set can audit
  verdicts produced while the judge was explicitly `uncalibrated`. It compares
  verdict pass plus goal/quality/efficiency scores against inclusive human score
  bands, reports gold-label coverage, pass and score agreement with Wilson
  intervals, false-pass/false-fail counts, slices agreement by capability,
  model class, prompt variant, and model-class prompt-variant pair, and
  surfaces duplicate labels, stale labels, missing traces, missing verdicts,
  verdicts graded under another judge calibration-set version, unblinded
  verdicts, and judged traces without gold labels. Completed labels
  cannot remain marked `needs_review` and must include reviewer provenance.
  Completed labels may include `independentReviews`; those raw votes are kept
  inside the one final gold label per trace, derive pairwise human pass/score
  agreement and unresolved human-disagreement findings, and preserve duplicate
  gold-label rejection. Each independent review carries blinding protocol flags
  for judge verdict, exact model identity, and peer votes; clean calibration
  readiness rejects duplicate gold labels and the default model-class policy
  rejects unblinded human-review evidence.
  `eval/run_level2.sh calibrate <runId>` renders this report when
  `EVAL_CALIBRATION=<json>` is set.
  `eval/run_level2.sh template <runId>` can optionally receive
  `EVAL_CALIBRATION_TEMPLATE_MAX_ROWS=<n>` to emit a deterministic bounded
  review queue after validating the complete judged run. The selector covers
  agent kind, model class, prompt variant, judge pass/fail,
  protected/non-protected bucket, and primary-capability strata, then records
  only aggregate selection coverage and digest metadata so protected scenario
  IDs are not written into the template.
- Tuning readiness: `EvalTuningReadiness` evaluates a run against an explicit
  policy after artifact verification. `developmentSmoke` can pass small
  diagnostic matrices; `modelClassTuning` requires a live manifest, canonical
  scenario/profile-set digests, required profile names/model classes,
  multi-trial profiles, complete trace and verdict coverage, calibrated
  model-identity-blinded verdicts, a completed human calibration label set whose
  derived report
  satisfies evaluated-label coverage and agreement gates, protected holdout
  evidence, and minimum
  agent/capability/split corpus coverage, plus explicit adversarial coverage
  by agent/capability, required adversarial failure-mode tags, and protected
  production-replay holdout depth, and completed digest-current scenario review
  metadata before adversarial, synthetic, production-replay holdout, or
  protected scenarios can count as tuning-ready evidence. Synthetic and
  protected evidence also requires a review `sourceDigest`, and protected
  holdout source digests must be unique. The default stress tags are
  `ambiguous-reference`, `scope-boundary`, `stale-state`, and `tool-recovery`
  from `kDefaultAdversarialStressTags`; catalog validation and run verification
  reject adversarial scenarios that lack one of those canonical stress tags.
  Readiness counts only scenarios whose canonical `isAdversarial` flag is true,
  and protected holdout counts use unique manifest-bound production-replay IDs
  with unique source digests distributed across required agent kinds.
  Calibration readiness recomputes
  `JudgeCalibrationReport` from the raw `JudgeCalibrationSet`; aggregate
  reports are display-only and cannot satisfy readiness gates. The calibration
  gates include evaluated-label minimums overall and per required model
  class/capability/prompt variant/model-class prompt-variant pair,
  global and per-prompt-variant pass/score rates plus Wilson lower bounds,
  false-pass/false-fail limits, exact judge calibration provenance, optional
  human gold-label version, clean stale/missing/mismatch/unlabeled counts, and
  model-identity blinding, plus independent human-review pair counts,
  human-human pass/score agreement with Wilson lower bounds, and zero unresolved
  human disagreement plus blinded human-review protocol evidence for
  model-class tuning. The default model-class policy also rejects unblinded
  judge verdicts where exact provider/model identity was visible during grading.
  `eval/run_level2.sh blind` now creates a separate model-identity-redacted
  review packet, and `eval/run_level2.sh import-blind` validates the retained
  private key, judge manifest digest, review payload digests, raw trace digests,
  and blinded verdict wrappers before writing raw digest-bound sibling verdict
  files with `blindedImport` audit provenance.
  The rendered readiness block now includes the
  evidence counts behind those gates: corpus by agent/split, primary capability
  count, model-class profile coverage, trial range, adversarial totals and
  tags, production-replay holdout depth, protected holdout distribution, and
  duplicate protected evidence ids, plus required/completed/missing/incomplete/
  stale scenario review counts.
  `EvalRunVerifier` can take an optional `tuningPolicy` to hard-fail
  under-covered tuning matrices, and `eval/run_level2.sh report` prints
  readiness before the ordinary summary.
- Durable-state oracles: `EvalExpectations.durableState` lets a scenario encode
  required/forbidden persisted proposals, planned blocks, parsed capture items,
  report text, observation text, allowed/required/forbidden mutated entry IDs,
  accepted `anyOf` alternatives, exact total counts, scoped min/max/exact count
  checks, parsed-capture confidence bands, and collateral-damage guards.
  Required matchers and `anyOf` groups consume distinct actual records, so one
  proposal/block/parsed item cannot satisfy two expected outcomes. Scoped counts
  are aggregate checks over matching final-state records; proposal count
  matchers must include item or change-set status so retired history does not
  distort model-class tuning. `validateEvalScenarioCatalog` cross-checks
  trigger tokens, fixture references, proposal-history references, and
  durable-state expectation references, and `EvalRunVerifier` rejects Level 2
  runs whose supplied catalog fails that validation.

**Remaining:**

- Populate and maintain a real human-reviewed gold-label JSON, replace
  `"uncalibrated"` verdict metadata with that calibration-set version, and track
  disagreement over time.
- Expand the scenario corpus with private holdout and production-replay derived
  cases. Public `holdout` labels in this repo are process metadata only; they
  are not a real private holdout by themselves.

## Phase 3 — A/B (future)

Out of scope. The trace/verdict schema is the hand-off point: online experiment
results slot into the same `JudgeVerdict`/report shape.

## Testing & quality gates

- **`fvm dart analyze test/eval` must be clean** — this is the gate. Do NOT rely
  on `dart-mcp.analyze_files`; it under-reports (see Gotchas above).
- `fvm dart format test/eval`.
- `fvm flutter test test/eval` green. Each example verifies both
  a pass and a regression-catch path, per the repo's Test Quality Rules.
- No CHANGELOG / metainfo entry: developer tooling, not user-visible (per
  AGENTS.md "skip CHANGELOG for invisible work").

## Risks

- **Judge noise** — mitigated by explicit 1–5 rubrics + hard `pass`, versioned
  verdicts, human spot-checks.
- **Scripted/live drift** — both targets consume the same `EvalScenario`.
- **Flutter-binding coupling** — Level 2 is a tagged `flutter test` entrypoint,
  documented in `eval/README.md`.
