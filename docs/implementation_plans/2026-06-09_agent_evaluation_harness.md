# Implementation Plan: Tiered Agent Evaluation Harness

- Date: 2026-06-09
- ADR: [0029 — Tiered Agent Evaluation Harness](../adr/0029-agent-evaluation-harness.md)
- Status: Phase 0 + Phase 1 landed — both real-workflow benches and the
  `ScriptedEvalTarget` wrapper are green. Next up: Phase 2
  (live local/frontier + run loop).
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
Phase 1 planner/task benches, and the `ScriptedEvalTarget` wrapper). ADR is **0029**
(`docs/adr/0029-agent-evaluation-harness.md`).

### Run it

```
fvm flutter test test/eval        # Level 1 — all examples, no keys/network, deterministic time
fvm dart analyze test/eval        # the analyzer GATE (see gotcha below)
fvm dart format test/eval
```

Today: 9 tests green, analyzer clean.

### File inventory (all present)

```
eval/                                    # repo-root, non-build
  README.md  prompts/{judge_system,rubric_task_agent,rubric_planning_agent}.md
  grade_run.md       # Claude Code judge runbook (trace dir -> verdicts)
  run_level2.sh      # Level 2 orchestration (gated behind LOTTI_EVAL_LIVE=1)
  runs/              # git-ignored run artifacts

test/eval/harness/                       # Dart support library
  eval_models.dart        # plain-data scenario/output/trace/verdict (+JSON); reuses InferenceUsage
  eval_assertions.dart    # Level 1 suite — runLevel1(scenario, output, {profile})
  eval_target.dart        # EvalTarget seam + FixtureEvalTarget
  trace_writer.dart       # write traces / reattach verdicts (dart:io)
  eval_reporter.dart      # per-profile summary (pure)
  profiles.dart           # kLocalOllamaProfile / kFrontierProfile
  eval_harness.dart       # barrel — PURE files only; does NOT export the benches
  scripted_eval_target.dart              # EvalTarget wrapper over the real workflow benches
  scripted_conversation_repository.dart  # ScriptedConversationRepository (real ConversationManager)
  planner_eval_bench.dart # PlannerEvalBench.runDraftingWake + ScriptedAgentBehavior
  task_agent_eval_bench.dart             # TaskAgentEvalBench.runWake

test/eval/scenarios/                     # dataset + Level 1 example tests
  planning_agent_eval_test.dart      # planner via FixtureEvalTarget + trace/reporter round-trip
  task_agent_eval_test.dart          # task via FixtureEvalTarget
  planner_workflow_eval_test.dart    # REAL DayAgentWorkflow via ScriptedEvalTarget
  task_agent_workflow_eval_test.dart # REAL TaskAgentWorkflow via ScriptedEvalTarget
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
- **Task report:** mapped from the scripted `update_report` tool call — the same
  source `TaskAgentStrategy.extractReportContent()` parses. Always include an
  `update_report` call in the behavior, or the workflow fires a forced-report
  retry.
- **Two scripting patterns, both work:** planner bench uses
  `ScriptedConversationRepository` (a REAL `ConversationManager`, drives
  `strategy.processToolCalls`); task bench uses the existing
  `MockConversationRepository.sendMessageDelegate` + a MOCK `ConversationManager`.
  The model seam either way is `ConversationRepository.sendMessage(... strategy:)`
  returning `InferenceUsage` — that is the scripted/live switch.
- **Scripted behavior storage:** keep `ScriptedAgentBehavior` outside
  `EvalScenario`. Use `ScriptedEvalTarget.fromMap({...})` with a side map keyed
  by `scenario.id`, so the scenario model remains plain JSON and the pure
  `eval_harness.dart` barrel stays free of bench/mock imports.

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

### Next task — Phase 2 skeleton

Add the live runner entrypoint while keeping it gated by
`LOTTI_EVAL_LIVE=1`:

- introduce `LiveEvalTarget` beside `ScriptedEvalTarget`, using the same
  `EvalTarget` contract and the real `ConversationRepository`/provider path;
- add a tagged `test/eval/scenarios/live_runner_test.dart` (or equivalent)
  that iterates scenarios × profiles and writes `EvalTrace`s;
- keep the default `fvm flutter test test/eval` path deterministic and free of
  keys/network;
- after the runner exists, grow the scripted dataset to ≥6 scenarios per agent
  using `ScriptedEvalTarget.fromMap({...})` side maps for golden behaviours.

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
- `test/eval/harness/task_agent_eval_bench.dart` — `TaskAgentEvalBench.runWake`.
  Mirrors the planner for `TaskAgentWorkflow.execute(...)`, reusing the existing
  task-agent test helpers (`createTestWorkflow` / `stubFullExecutePath` /
  `MockConversationRepository.sendMessageDelegate`); the report is read from the
  scripted `update_report` call (what `TaskAgentStrategy.extractReportContent`
  parses). Requires the caller to set up GetIt (`PersistenceLogic`,
  `TimeService`) + fallbacks in `setUpAll`.
- `test/eval/harness/scripted_eval_target.dart` — `ScriptedEvalTarget`, the
  agent-agnostic `EvalTarget` wrapper over the two benches. It intentionally
  stays out of the pure `eval_harness.dart` barrel and offers
  `ScriptedEvalTarget.fromMap({...})` for side-map scripted behaviours keyed by
  `scenario.id`.
- `test/eval/scenarios/planner_workflow_eval_test.dart` and
  `task_agent_workflow_eval_test.dart` — exercise each real workflow end-to-end
  through `ScriptedEvalTarget` and grade with `runLevel1` (good-path pass + a
  regression caught). Analyzer clean; full `test/eval` suite (9 tests) green.

This exercises the real orchestration (profile→provider resolution, conversation
loop, real strategy tool dispatch + change-set deferral, report extraction, state
reconciliation, persistence). Backend services (`planService`) and, for the task
agent, the journal mutations are mocked, so in scripted mode the tool outputs are
caller-fixed — intended: Level 1 guards plumbing + invariants + the mapping;
Level 2 supplies real model behavior.

**Remaining:**

- Optionally wire the real `DayAgentPlanService` so `draft_day_plan` produces a
  persisted `DayPlanEntity` (non-circular block normalization) and map from
  `DayPlanEntity.plannedBlocks` / `ChangeSetEntity.items` /
  `WakeTokenUsageEntity`.
- Grow `test/eval/scenarios/` into a real dataset (≥6 scenarios per agent),
  including LLM-*generated* scenarios reviewed by a human before commit.

## Phase 2 — `LiveEvalTarget` + Level 2 run loop

- `LiveEvalTarget` builds the real `ConversationRepository` against a provider
  resolved by `resolveInferenceProvider` for the profile's `modelId`; Ollama for
  `isLocal`, frontier otherwise. Gated behind env (`LOTTI_EVAL_LIVE=1`,
  provider keys / `OLLAMA_BASE_URL`) so it never runs in default CI.
- `run_level2.sh`: run the tagged live entrypoint → traces under
  `eval/runs/<runId>/` → `eval/grade_run.md` (Claude Code) writes verdicts →
  `EvalReporter` prints the summary table.

## Phase 3 — A/B (future)

Out of scope. The trace/verdict schema is the hand-off point: online experiment
results slot into the same `JudgeVerdict`/report shape.

## Testing & quality gates

- **`fvm dart analyze test/eval` must be clean** — this is the gate. Do NOT rely
  on `dart-mcp.analyze_files`; it under-reports (see Gotchas above).
- `fvm dart format test/eval`.
- `fvm flutter test test/eval` green (9 tests today). Each example verifies both
  a pass and a regression-catch path, per the repo's Test Quality Rules.
- No CHANGELOG / metainfo entry: developer tooling, not user-visible (per
  AGENTS.md "skip CHANGELOG for invisible work").

## Risks

- **Judge noise** — mitigated by explicit 1–5 rubrics + hard `pass`, versioned
  verdicts, human spot-checks.
- **Scripted/live drift** — both targets consume the same `EvalScenario`.
- **Flutter-binding coupling** — Level 2 is a tagged `flutter test` entrypoint,
  documented in `eval/README.md`.
