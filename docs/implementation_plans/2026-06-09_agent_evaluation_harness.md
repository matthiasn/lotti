# Implementation Plan: Tiered Agent Evaluation Harness

- Date: 2026-06-09
- ADR: [0029 — Tiered Agent Evaluation Harness](../adr/0029-agent-evaluation-harness.md)
- Status: Phase 0 (scaffold + one working example) landed; later phases pending

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

## Phase 0 — Scaffold + one working example (this change)

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

Task agent: `checkValidStatusTransitions` (`IN_PROGRESS|BLOCKED|ON_HOLD`),
`checkEstimateRange` (`1..1440`), `checkLabelCap` (≤3),
`checkNoDuplicateChecklistTitles`.

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

## Phase 1 — `ScriptedEvalTarget` + dataset (next)

- Implement DB seeding from `EvalScenario` reusing `makeTestCapture`,
  `makeTestDayPlan`, `makeTestState`, `makeTestIdentity`, journal `Task`
  insertion, and `testInferenceProfile`/`testInferenceProvider`.
- Wrap a `ConversationRepository` subclass (generalise `_ConversationHarness`)
  whose scripted tool calls are derived from the scenario's "golden" actions.
- Run `DayAgentWorkflow.execute` / `TaskAgentWorkflow.execute`, then map persisted
  entities (`DayPlanEntity.plannedBlocks`, `ChangeSetEntity.items`,
  `AgentReportEntity`, observation messages, `WakeTokenUsageEntity`) into
  `AgentRunOutput`.
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

- `dart-mcp.analyze_files` zero warnings/infos across the repo.
- `fvm dart format .`.
- `test/eval/scenarios/planning_agent_eval_test.dart` passes (meaningful
  assertions per the repo's Test Quality Rules — verifies both pass and
  regression-catch paths).
- No CHANGELOG / metainfo entry: developer tooling, not user-visible (per
  AGENTS.md "skip CHANGELOG for invisible work").

## Risks

- **Judge noise** — mitigated by explicit 1–5 rubrics + hard `pass`, versioned
  verdicts, human spot-checks.
- **Scripted/live drift** — both targets consume the same `EvalScenario`.
- **Flutter-binding coupling** — Level 2 is a tagged `flutter test` entrypoint,
  documented in `eval/README.md`.
