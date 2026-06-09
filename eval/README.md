# Agent Evaluation Harness

A custom, data-driven eval framework for Lotti's **task agent**
(`TaskAgentWorkflow`) and **planning agent** (`DayAgentWorkflow`). Design and
rationale: [ADR 0029](../docs/adr/0029-agent-evaluation-harness.md) and the
[implementation plan](../docs/implementation_plans/2026-06-09_agent_evaluation_harness.md).

It follows Hamel Husain's tiered methodology:

| Level | What | Cost | When |
|---|---|---|---|
| 1 | Deterministic assertions on agent output | free, fast | every change (CI) |
| 2 | Real local + frontier models, Claude Code as judge | tokens + time | periodic, manual |
| 3 | Online A/B | — | future |

## Layout

```
eval/
  README.md            ← you are here
  prompts/
    judge_system.md    ← judge persona + JSON output contract
    rubric_task_agent.md
    rubric_planning_agent.md
  grade_run.md         ← Claude Code runbook: trace dir -> verdicts
  run_level2.sh        ← orchestration (produce traces -> grade -> report)
  runs/                ← git-ignored artifacts: <runId>/<scenario>__<profile>.*

test/eval/harness/     ← Dart support library (models, assertions, target, IO)
test/eval/scenarios/   ← the dataset + Level 1 example tests
```

## The flow

```mermaid
flowchart LR
  DS[EvalScenario dataset<br/>plain data] --> T{EvalTarget}
  T -->|scripted/fixture| O[AgentRunOutput]
  T -->|live local+frontier| O
  O --> L1[Level 1 assertions<br/>runLevel1]
  L1 --> TR[EvalTrace JSON<br/>eval/runs/runId]
  TR --> J[Claude Code judge<br/>grade_run.md + rubrics]
  J --> V[verdict JSON]
  V --> REP[EvalReporter<br/>per-profile summary]
```

## Level 1 — every change

`runLevel1(scenario, output)` returns deterministic `EvalCheck`s (succeeded, no
hallucinated task refs, within capacity, valid status transitions, estimate
range, label cap, no duplicate checklist items, …). The example tests under
`test/eval/scenarios/` show both a passing output and a regression-catching one:

```
fvm flutter test test/eval/scenarios
```

These run with no keys, no network, deterministic time.

## Level 2 — periodic

```
LOTTI_EVAL_LIVE=1 GEMINI_API_KEY=... OLLAMA_BASE_URL=http://localhost:11434 \
  eval/run_level2.sh
```

1. Runs each scenario against each profile (`local-ollama`, `frontier-gemini`),
   writing one trace per `(scenario, profile)` to `eval/runs/<runId>/`.
2. Grade with Claude Code: `claude -p "Follow eval/grade_run.md to grade eval/runs/<runId>"`.
3. Re-run the script (or the reporter) to print the per-profile summary.

The judge scores **goal attainment**, **quality/accuracy**, and **efficiency**
(token burn + unnecessary steps), separately per profile, so a plan that is great
on a frontier model but blows the local token budget shows up as a *local*
failure.

## Adding a scenario

Add a plain-data `EvalScenario` (mocked tasks/deadlines + a user transcript +
optional hard expectations) under `test/eval/scenarios/`. No codegen. The same
scenario feeds Level 1 and Level 2 so they never drift. Scenarios may be drafted
by an LLM, but must be human-reviewed before commit.

For scripted Level 1 workflow runs, keep the golden `ScriptedAgentBehavior`
outside the scenario in a side map keyed by `scenario.id`, then pass it through
`ScriptedEvalTarget.fromMap({...})`. That keeps `EvalScenario` JSON-serializable
and keeps the pure harness barrel free of bench/mock imports.

> Level 2 executes the real workflows, which need the Flutter test binding, so
> the live runner is a tagged `flutter test` entrypoint — not a plain
> `dart run` script. See ADR 0029 for why.
