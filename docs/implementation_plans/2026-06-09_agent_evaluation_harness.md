# Implementation Plan: Tiered Agent Evaluation Harness

- Date: 2026-06-09
- ADR: [0029 — Tiered Agent Evaluation Harness](../adr/0029-agent-evaluation-harness.md)
- Status: Phase 0 + Phase 1 landed, with hardened shared scenarios,
  model-class profiles, task-agent persisted-output extraction,
  digest-bound traces, strict Level 2 run verification, and mode-based
  reporting. Next up: planner persisted-state extraction, then
  `LiveEvalTarget`.
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
Phase 1 planner/task benches, `ScriptedEvalTarget`, shared scenario catalog,
model-class profiles, and trace/verdict digest binding). ADR is **0029**
(`docs/adr/0029-agent-evaluation-harness.md`).

### Run it

```
fvm flutter test test/eval        # Level 1 — all examples, no keys/network, deterministic time
fvm dart analyze test/eval        # the analyzer GATE (see gotcha below)
fvm dart format test/eval
```

Current gate: 18 eval tests green, 2 report tests skipped without `EVAL_RUN`,
analyzer clean.

### File inventory (all present)

```
eval/                                    # repo-root, non-build
  README.md  prompts/{judge_system,rubric_task_agent,rubric_planning_agent}.md
  grade_run.md       # Claude Code judge runbook (trace dir -> verdicts)
  run_level2.sh      # Level 2 orchestration (gated behind LOTTI_EVAL_LIVE=1)
  runs/              # git-ignored run artifacts

test/eval/harness/                       # Dart support library
  eval_models.dart        # plain-data scenario/output/profile/trace/verdict (+JSON); reuses InferenceUsage
  eval_assertions.dart    # Level 1 suite — runLevel1(scenario, output, {profile})
  eval_target.dart        # EvalTarget seam + FixtureEvalTarget
  trace_writer.dart       # write traces / verify digest-bound verdicts (dart:io)
  eval_reporter.dart      # per-profile summary (pure)
  eval_run_verifier.dart  # exact run matrix + verdict/Level 1 consistency checks
  profiles.dart           # local-small/local-reasoning/frontier-fast/frontier-reasoning
  scripted_agent_behavior.dart           # neutral single-/multi-turn scripted model behavior
  eval_harness.dart       # barrel — PURE files only; does NOT export the benches/targets
  scripted_eval_target.dart              # EvalTarget wrapper over the real workflow benches
  scripted_conversation_repository.dart  # ScriptedConversationRepository (real ConversationManager)
  planner_eval_bench.dart # PlannerEvalBench.runDraftingWake + ScriptedAgentBehavior
  task_agent_eval_bench.dart             # TaskAgentEvalBench.runWake

test/eval/harness/*_test.dart            # pure harness regression tests
  eval_run_verifier_test.dart        # missing/extra/duplicate/orphan/bad-verdict cases
  trace_writer_test.dart             # rejects embedded verdicts in trace JSON

test/eval/scenarios/                     # dataset + Level 1 example tests
  eval_scenarios.dart                # shared plain-data scenario catalog
  eval_scenarios_test.dart           # catalog uniqueness + JSON round-trip checks
  planning_agent_eval_test.dart      # planner via FixtureEvalTarget + trace/reporter round-trip
  task_agent_eval_test.dart          # task via FixtureEvalTarget
  planner_workflow_eval_test.dart    # REAL DayAgentWorkflow via ScriptedEvalTarget
  task_agent_workflow_eval_test.dart # REAL TaskAgentWorkflow via ScriptedEvalTarget
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
- **Planner drafting wake:** the day resolves from a `drafting:<dayId>` trigger
  token via `resolvePlannerWakeDay`; the bench also passes the bare `dayId`
  token. Backend `planService` is mocked (`executeTool` returns canned success),
  so drafted blocks are caller-fixed in scripted mode.
- **Task bench output:** raw scripted tool calls are kept as diagnostics, but
  `report`, `observations`, and `usage` now map from the entities the real
  `TaskAgentWorkflow` persisted (`AgentReportEntity`, observation
  `AgentMessageEntity` + payload, `WakeTokenUsageEntity`). The regression test
  deliberately includes a rejected `update_report` call so the bench cannot
  silently grade scripted intent.
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
  rejects embedded verdicts and missing/stale sibling verdict digests by
  default. `EvalRunVerifier` then checks the exact
  scenario × profile × trial matrix, rejects orphan verdicts, recomputes Level 1
  checks, and validates the judge score/pass contract.

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

### Next task — planner persisted-state extraction

Before `LiveEvalTarget`, stop grading replayed scripted intent as if it were
durable app state:

- task-agent report/observation/token usage extraction is now persisted-state
  based; do the same for planner output and task deferred proposals;
- capture persisted `DayPlanEntity`, planner `ChangeSetEntity`, and task-agent
  `ChangeSetEntity` items from the real workflow benches;
- map `AgentRunOutput.plannedBlocks` from persisted `DayPlanEntity.data` first,
  keeping raw tool calls as diagnostics/tool-contract evidence;
- seed task/category/capture/profile config from `EvalScenario` and
  `EvalProfile` so local/frontier/model-class labels cannot lie;
- add adversarial divergence tests where scripted tool args look valid but
  persistence rejects or normalizes them;
- then add `LiveEvalTarget` + `live_runner_test.dart` behind
  `LOTTI_EVAL_LIVE=1`.

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
- `MockedAppState { now, tasks, existingBlocks, capacityMinutes, categoryIds }`
- `MockTask { id, title, status, due?, estimateMinutes?, categoryId?, checklist }`
- `MockChecklistItem { id, title, isChecked }`
- `MockDayBlock { id, taskId?, categoryId, start, end }`
- `UserInput { transcript, triggerTokens }`
- `EvalExpectations { maxTokenBudget?, maxToolCalls?, mustCallTools, mustNotCallTools }`
- `AgentRunOutput { success, error?, toolCalls, plannedBlocks, report?,`
  `observations, mutatedEntryIds, usage (InferenceUsage), turnCount, wallClockMs }`
- `ToolCallRecord { name, args }`
- `PlannedBlockRecord { id, taskId?, categoryId, start, end }`
- `AgentReportRecord { oneLiner, tldr, content }`
- `EvalProfile { name, isLocal, modelId, temperature, maxCompletionTokens?, tokenBudget }`
- `EvalCheck { name, passed, detail }`
- `EvalTrace { runId, scenarioId, profileName, agentKind, userInput, output,`
  `level1Checks, verdict? }`
- `JudgeVerdict { goalAttainment(1-5), quality(1-5), efficiency(1-5), pass, rationale, issues }`

The harness reuses `package:lotti/features/ai/model/inference_usage.dart`
(`InferenceUsage`) verbatim for token accounting, so Level 2 numbers match what
`WakeTokenUsageEntity` records in production.

### Level 1 assertion library

Pure `EvalCheck Function(...)` helpers, grounded in real tool/field contracts:

Shared: `checkSucceeded`, `checkReportPublished`, `checkNoHallucinatedTaskRefs`,
`checkTokenBudget`, `checkToolCallBudget`, `checkOnlyAllowedTools`,
`checkExpectations`.

Task agent: `checkValidStatusTransitions` (rejects user-only `DONE`/`REJECTED`;
agent-settable enum is `OPEN`/`IN PROGRESS`/`GROOMED`/`BLOCKED`/`ON HOLD` — note
the spaces, see `task_agent_tool_definitions.dart:775`), `checkEstimateRange`
(`minutes` `1..1440`), `checkLabelCap` (≤3), `checkNoDuplicateChecklistTitles`.

Planner: `checkWithinCapacity` (Σ block minutes ≤ `capacityMinutes`),
`checkNoOverlappingBlocks`, `checkBlocksUseKnownCategories`,
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
  `testInferenceProfile`), runs the REAL `DayAgentWorkflow.execute(...)` under
  `withClock`, maps `(WakeResult, scripted tool calls)` → `AgentRunOutput`.
  **Still needs persisted `DayPlanEntity` extraction.**
- `test/eval/harness/task_agent_eval_bench.dart` — `TaskAgentEvalBench.runWake`.
  Mirrors the planner for `TaskAgentWorkflow.execute(...)`, reusing the existing
  task-agent test helpers (`createTestWorkflow` / `stubFullExecutePath` /
  `MockConversationRepository.sendMessageDelegate`); report, observations, and
  token usage are read from persisted workflow entities. Requires the caller to
  set up GetIt (`PersistenceLogic`, `TimeService`) + fallbacks in `setUpAll`.
- `test/eval/harness/scripted_eval_target.dart` — `ScriptedEvalTarget`, the
  agent-agnostic `EvalTarget` wrapper over the two benches. It intentionally
  stays out of the pure `eval_harness.dart` barrel and offers
  `ScriptedEvalTarget.fromMap({...})` / `fromProfileMap({...})` for side-map
  scripted behaviours keyed by `scenario.id` and optionally `profile.name`.
- `test/eval/scenarios/eval_scenarios.dart` — shared scenario catalog used by
  Level 1 tests and future runners, with uniqueness and JSON round-trip tests.
- `TraceWriter` now refuses accidental trace overwrites, rejects embedded
  verdicts, binds sibling verdicts to `sha256:` trace digests, and supports
  `trialIndex` stems for repeated runs.
- `EvalRunVerifier` enforces exact run matrix coverage, rejects orphan verdicts,
  recomputes Level 1 checks, and validates verdict score/pass consistency.
- `test/eval/scenarios/planner_workflow_eval_test.dart` and
  `task_agent_workflow_eval_test.dart` — exercise each real workflow end-to-end
  through `ScriptedEvalTarget` and grade with `runLevel1` (good-path pass + a
  regression caught). Analyzer clean; full `test/eval` suite green.

This exercises the real orchestration (profile→provider resolution, conversation
loop, real strategy tool dispatch + change-set deferral, report extraction, state
reconciliation, persistence). The task bench now maps durable report,
observation, and token-usage entities. Planner `planService` is still mocked, so
scripted planner blocks remain caller-fixed until the next persisted-plan slice.
Level 2 supplies real model behavior.

**Remaining:**

- Wire the real `DayAgentPlanService` or a narrow recording fake so
  `draft_day_plan` produces a persisted `DayPlanEntity` (non-circular block
  normalization) and map from `DayPlanEntity.data` /
  planner `ChangeSetEntity.items`.
- Map task-agent deferred proposal evidence from persisted `ChangeSetEntity`
  items, including merged pending-set cases.
- Seed production profile/model/provider configs from `EvalProfile` and record
  the resolved provider-native model path in each trace.
- Grow `test/eval/scenarios/` into a real dataset (≥6 scenarios per agent),
  including LLM-*generated* scenarios reviewed by a human before commit.

## Phase 2 — `LiveEvalTarget` + Level 2 run loop

- `LiveEvalTarget` builds the real `ConversationRepository` against a provider
  resolved by `resolveInferenceProvider` for the profile's `modelId`; Ollama for
  `isLocal`, frontier otherwise. Gated behind env (`LOTTI_EVAL_LIVE=1`,
  provider keys / `OLLAMA_BASE_URL`) so it never runs in default CI.
- `run_level2.sh`: mode-based shell (`run`, `grade`, `verify`, `report`, `all`).
  `grade`/`verify`/`report` default to the latest timestamp-named run directory
  when no run id is supplied. `report` never regenerates traces; it verifies
  exact matrix coverage, digest-bound verdicts, recomputed Level 1 checks, and
  verdict score/pass consistency before printing the summary. `run` currently
  refuses until `live_runner_test.dart` and `LiveEvalTarget` land.

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
