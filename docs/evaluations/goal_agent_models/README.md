# Goal-agent model evaluations

Inference-level evals for the **goal agent** (ADR 0053–0057) — run *before*
the production `GoalAgentWorkflow` exists, so the prompt/tool contract is
model-validated before a line of runtime code depends on it. The draft
contract lives in
`test/features/agents/eval/goal/support/goal_agent_spec.dart` and graduates
to `lib/features/agents/` when the workflow is built.

## What is measured

Four behaviours, one scenario catalog
(`goal_agent_eval_scenarios.dart`, ids in parentheses):

1. **Goal progression reporting** — restating the deterministic evaluation
   without recomputing or contradicting it (`gp_*`, `gh_*`).
2. **Ad decisions** — when to create, re-run, retire, and *not* create
   (`ad_*`); includes the need-to-know leakage trap (`ad_leakage_pressure`,
   ADR 0056) and the top-rated reuse rule (`ad_reuse_top_rated`, ADR 0055).
3. **Goal-evolution dialogue** — restate-then-propose-exactly-once, vague
   musings get questions not proposals, withdrawals end without a proposal
   (`evo_*`, `wk_*`).
4. **Restraint** — the no-op wake (`gp_noop`): nothing changed → zero tool
   calls. This is the cheapest discriminator between models that follow
   policy and models that churn; the task-agent evals found 4/5 models
   churn without it being tested.

Every expectation derives from the policy matrix `goalAgentPolicyMatrix`
(P1–P15) in the spec file — the single source of truth. The offline
self-test enforces that every policy row has a scenario and that every
fixture number matches the REAL `GoalProgressEvaluator` + `GoalTrackPolicy`
(`lib/features/goals/evaluation/`), so the fixtures double as the executable
spec of the deterministic tier.

## Fixture world

Keeper **Signe Voss**, Ross Station (Project Waddle penguin universe — never
real user data). Two goals: G1 "average 10,000 steps/day, rolling 7 days"
and G2 "station gym 3×/calendar week". `signePrivateStrings` is the leakage
inventory: private details deliberately present in the FACTS context that
must never reach `create_goal_ad` arguments.

Limitation, stated plainly: the wake context is **authored** (a synthetic
FACTS block), not produced by a real wake over a real database. The
graduation path is a workflow-level eval on a penguin fitness world (the
`penguin_wake_workflow_eval` pattern) once `GoalAgentWorkflow` exists.

## Cost

Cost is a first-class output, captured per case from day one:

- The live test registers `AiInteractionCaptureTestBench`, and the runner
  attributes every turn to a per-case wake-run key, so Melious billing
  (`credits`) lands in each case artifact.
- Reports show credits AND energy per model with **per-goal-month
  extrapolations** (mean per case × wakes/day × 30) — "my fitness agent
  costs N Wh per month" is a first-class answer (ADR 0058). Wh here is
  the provider-reported energy of the AI inference itself
  (`AiConsumptionEvent.energyKwh`), not total device energy. The wakes/day
  figure (default 3) is a printed assumption, not a measurement —
  deterministic Phase A ticks and banner *rendering* cost €0 and no
  inference energy by design (ADR 0054/0058); the Phase B turn that
  authors banner copy is what the reported figures measure.
- All cost figures are **observations for monitoring, never targets or
  caps** (session decision 2026-08-08). "not reported" means the provider
  sent no billing data; it is never rendered as zero.

Provider defaults to `melious` deliberately: it is the only provider whose
responses carry billing (generic-OpenAI routing is exactly why the
task-agent evals lack credits).

## Run book

Everything is manual — no CI runs these.

Single model, all scenarios:

```bash
LOTTI_GOAL_AGENT_EVAL_LIVE=1 \
MELIOUS_API_KEY=... \
GOAL_AGENT_EVAL_MODELS=glm-5.2 \
fvm flutter test test/features/agents/eval/goal/goal_agent_eval_live_test.dart \
  --tags eval-live
```

Artifacts land in the system temp dir by default; override with
`GOAL_AGENT_EVAL_JSON` / `GOAL_AGENT_EVAL_MARKDOWN`.

Full matrix (per-process fan-out, merged report):

```bash
MELIOUS_API_KEY=... scripts/goal_agent_eval_matrix.sh 3 4
# → eval_artifacts/goal_agent_merged_report.md
```

Useful knobs:

| Env var | Default | Meaning |
| --- | --- | --- |
| `GOAL_AGENT_EVAL_MODELS` | `glm-5.2 kimi-k3 qwen3.5-122b-a10b qwen3.6-27b` | model list (matrix script; comma-separated for the test) |
| `GOAL_AGENT_EVAL_SCENARIOS` | all | comma-separated scenario ids |
| `GOAL_AGENT_EVAL_TEMPERATURE` | `0` | sampling temperature |
| `GOAL_AGENT_EVAL_WAKES_PER_DAY` | `3` | extrapolation assumption (printed in the report) |
| `GOAL_AGENT_EVAL_PROVIDER_TYPE` | `melious` | provider type (`gemini`, `omlx`, … lose billing) |
| `GOAL_AGENT_EVAL_STRICT` | off | `1` fails the test on any scenario failure |

**Banners are procedural text** (ADR 0058): `create_goal_ad` authors copy
(headline/tagline/cta) and selects animation + accent presets from the
code-owned catalogs — no image provider exists in the channel, so beyond
the Phase B text turn that authors the copy there is no separate image
inference or generation. The leakage evals police the copy fields.

Merging artifacts by hand:

```bash
fvm dart run tool/goal_agent_eval_report.dart eval_artifacts/goal_agent_*.json
```

`qwen3.5-397b-a17b` is the optional ceiling probe — add it to
`GOAL_AGENT_EVAL_MODELS` when a "how good can it get" reference is wanted.

## Methodology caveats

- **Samples are small.** 3 samples per cell is noise-level for anything but
  gross differences; treat single-cell flips as anecdotes, not signal.
- **Objective checks only rank.** The classifier is deterministic
  (tool calls, argument subsets, term groups, negation-aware claims from
  the shared `eval_text_matchers.dart`). There is no LLM judge wired in
  yet; if one is added, it is diagnostic only, never part of the pass/fail
  gate (task-agent eval rule).
- **Be suspicious of scenarios all models pass or all models fail** — they
  usually measure the harness, not the model.
- **Assert mutations via expected tool calls,** never by trusting report
  prose.

## Related

- ADR 0053 (goal agents), 0054 (two-tier wakes), 0055 (banner nudges,
  rating & reuse), 0056 (visual brief boundary), 0057 (decade memory)
- `docs/evaluations/task_agent_models/README.md` — the methodology this
  suite inherits
- Kickoff plan:
  `docs/implementation_plans/2026-08-08_goal_agents_kickoff_plan.md`
