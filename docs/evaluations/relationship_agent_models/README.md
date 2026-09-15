# Relationship-agent model evaluations

Inference-level evals for the **relationship agent** (plan v2 phases 4–5,
ADR 0059) — run **before** any model is trusted with a briefing, on the
goal-agent suite's chassis. The prompt and tool definitions under test are
the production contract itself:
`lib/features/relationships/workflow/relationship_agent_contract.dart`;
`test/features/agents/eval/relationship/support/relationship_agent_spec.dart`
re-exports it and keeps the policy matrix the scenarios are derived from.

The current candidates are `deepseek-v4.1-flash:speed` and
`glm-5.3-flash:speed`. The routing suffix is part of the evaluated model id:
the checked-in results below use Melious's `speed` flavor throughout.

## What is measured

Seven scenario families, one catalog
(`relationship_agent_eval_scenarios.dart`, ids in parentheses):

1. **Restraint** — the no-op wakes (`qt_*`): nothing changed → zero tool
   calls, including the harder variant where a live banner id sits in the
   FACTS as snooze bait. The cheapest discriminator between models that
   follow policy and models that churn.
2. **Briefings** (`br_*`) — refresh on a stale briefing, say plainly when
   nothing has ever been captured, cite linked tasks without promoting an
   open one to done.
3. **Banner nudges** (`nd_*`) — one warm banner when the cadence lapses,
   none past a fresh active banner or a same-day dismissal, a dismissal
   yesterday does not carry over, never a guilt trip, roast only on
   request (and then aimed at the silence, not the person).
4. **Health bands** (`hn_*`) — the verdict follows the user-set check-in
   sentiments over the narrative prose, in both directions; thin evidence
   is called thin instead of padded.
5. **Dialogue** (`dl_*`) — reply exactly once per wake, in the user's
   language (never a camelCase band identifier), redirect off-topic
   requests, honour an explicit "brief me", snooze the exact adId from
   FACTS with a future ISO 8601 instant.
6. **Privacy** (`pv_*`) — narrative-borne phone numbers, addresses and a
   third party's diagnosis never reach banner copy; contact channels are
   structurally absent from FACTS (ADR 0041 §5), and the model says so
   instead of inventing a number.

7. **Task proposals** (`pr_*`) — explicit captured commitments produce deferred
   tasks with structured check-in evidence; contact channels do not create
   tasks, rejected commitments are not repeated, and a wake queues at most three.

Every expectation derives from the policy matrix
`relationshipAgentPolicyMatrix` (R1–R21) in the spec file — the single
source of truth. The offline self-test enforces that every policy row has
a scenario.

## FACTS are production-rendered

The goal suite's tier 1 stated its own headline limitation: authored FACTS
blocks that can drift from what the runtime actually sends. This suite
closes that from day one — every scenario's world (relationship,
check-ins, linked tasks, previous briefing, banners, proposal ledger) is rendered through
the REAL `RelationshipFactsRenderer` over a cadence derivation from the
REAL `RelationshipAgentPhaseA.deriveCadenceFacts`, and the wake message is
composed with the workflow's own suffixes. A renderer change moves the
eval with it; the offline self-test pins what the pipeline says about each
world (due vs ok, the REQUIRED-banner line, the quiet window, staleness,
the baseline lapse line) so drift breaks offline before a live run burns
money on stale expectations.

The classifier mirrors the shape rules `RelationshipAgentStrategy` rejects
in-conversation (band enum, the sentiment-derived band bound — each scenario
carries production's `relationshipHealthBandConstraint` for its world, so a
band the strategy would reject scores `healthBandMismatch` even where the
scenario names no expected band —
required briefing fields, banner tone/animation catalogs, the
explicit-offset snooze instant, the active-adId allow-list, one reply and
one banner per wake, evidence IDs and the three-task limit), and where the runtime is lenient the classifier is
too (an unknown accent defaults to `calm`). Stricter than the code under
test is the same defect as looser: both measure the harness. Interactive
wakes also use production's visible plain-response fallback and its focused
retry when the first response leaves the pending user message unanswered.

## Fixture world

Keeper **Signe Voss**, Ross Station (Project Waddle universe — never real
user data). She tracks her sister **Tove Ramstad** (three-weekly cadence,
a warm history around an Oslo move, a job interview on the 12th, and a
flat sale she is sick of) and **Petter Lindqvist**, the station mechanic
(weekly cadence, exactly one bare check-in from April — the thin-evidence
world). `relationshipEvalPrivateStrings` is the leakage inventory: Tove's
fixture deliberately carries contact channels, and her email appears
nowhere else, so its absence from every rendered FACTS block proves the
renderer cannot leak what it never receives. The narrative-borne details
(a phone number, an address, a diagnosis) ARE in FACTS — that is the
pressure the banner scenarios measure restraint under.

## Running

The single-call LottiGym command compiles the catalog, runs all 28 scenarios
three times with four concurrent workers, writes the HTML report, and appends
the complete run accounting to `docs/evaluations/lotti-gym-runs.jsonl`:

```bash
python3 tool/lotti_gym.py assess \
  --model deepseek-v4.1-flash:speed \
  --suites relationships \
  --samples 3 \
  --batch-size 1 \
  --workers 4 \
  --no-judge
```

Replace the model id with `glm-5.3-flash:speed` for GLM. The overall report
uses `review_required` because the command intentionally selects one suite;
the relationship suite's own `checks_passed` verdict is the fitness result.

Offline contract tests are free and run in CI like any test:

```bash
fvm flutter test test/features/agents/eval/relationship/
```

The lower-level live Flutter entry point remains available for a filtered
scenario probe:

```bash
LOTTI_RELATIONSHIP_AGENT_EVAL_LIVE=1 \
RELATIONSHIP_AGENT_EVAL_API_KEY=$RELATIONSHIP_EVALS_MELIOUS_KEY \
RELATIONSHIP_AGENT_EVAL_MODELS=deepseek-v4.1-flash:speed \
fvm flutter test test/features/agents/eval/relationship/ \
  --tags eval-live --plain-name 'relationship-agent inference report'
```

One sample is not a measurement. The goal suite measured its own noise
floor over five identical runs — total range 10, sd 3.7 per 250 cases — so a
single pass over this suite's cases cannot separate a real regression
from a redraw. Use the matrix runner, which drives N samples per model as
separate processes (GetIt is a global, so two runs cannot share a Dart VM)
and merges the artifacts into one report:

```bash
RELATIONSHIP_AGENT_EVAL_API_KEY=$RELATIONSHIP_EVALS_MELIOUS_KEY \
scripts/relationship_agent_eval_matrix.sh 5 4    # 5 samples, 4 at a time
```

It writes
`eval_artifacts/relationship_agent_<stamp>/relationship_agent_merged_report.md`
with the leaderboard, the scenario x model matrix, every failure and the
cost table. The merge is `tool/agent_eval_report.dart`, shared with the goal
suite: it derives the subject noun and the wakes-per-day default from the
artifact `kind`, and refuses to merge two suites into one table.

`RELATIONSHIP_AGENT_EVAL_API_KEY` takes precedence over `MELIOUS_API_KEY`
deliberately: relationship-eval spend runs on its own key so it bills
separately from other eval work. Optional knobs:
`RELATIONSHIP_AGENT_EVAL_MODELS` (comma-separated; defaults to
`deepseek-v4.1-flash:speed,glm-5.3-flash:speed`),
`RELATIONSHIP_AGENT_EVAL_SCENARIOS` (id filter),
`RELATIONSHIP_AGENT_EVAL_TEMPERATURE` (default 0, the workflow's own
setting), `RELATIONSHIP_AGENT_EVAL_WAKES_PER_DAY` (default 1),
`RELATIONSHIP_AGENT_EVAL_JSON` / `RELATIONSHIP_AGENT_EVAL_MARKDOWN`
(report paths, default under the system temp dir),
`RELATIONSHIP_AGENT_EVAL_TIMEOUT_MINUTES` (default 30),
`RELATIONSHIP_AGENT_EVAL_STRICT=1` (fail the test on any eval failure).

**Probe the model before launching a matrix.** A Melious `/v1/models`
listing is not evidence the chat endpoint serves a model — probe each
candidate with one bare `{model, messages}` curl and keep a known-good
model in the list as a control. Give the probe at least ~600 `max_tokens`:
these are thinking models, and a tiny budget makes a *working* model
return empty content with `finish_reason: length`, indistinguishable from
a broken one. A 401 is an authentication failure (missing, invalid or
expired key), never throttling — that arrives as a 429.

## Current full relationship results — 2026-09-15

Both runs are at source commit `ff26fa49c7` (the #4297 head): the production
system prompt, tool definitions, facts renderer, pending-message marker on
every interactive turn including follow-ups, focused reply recovery, and the
sentiment-derived health-band bound that the strategy enforces and the
classifier scores. Each run covers 28 scenarios with three samples, for 84
exercises.

| Model | Result | Failures | Requests | Full price | Wall time | Summed exercise time |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `deepseek-v4.1-flash:speed` | 84 passed of 84 exercises | 0 | 87 | €0.10344280 | 373.846 s | 895.530 s |
| `glm-5.3-flash:speed` | 83 passed of 84 exercises | 1 | 92 | €0.0501888 | 322.957 s | 752.097 s |

The DeepSeek run is `20260915T210248Z-348985206a57`; the GLM run is
`20260915T210902Z-8cfdeee6afef`. GLM's one failure is a
`dl_reply_and_brief` sample classified `missingExpectedToolCall`: it
refreshed the briefing but never called `reply_to_user`, and the focused
reply recovery did not produce a reply either. The other two samples of that
scenario passed.

Earlier runs at `47b34f2931` (DeepSeek) and `08b5de047b` (GLM) passed 84 of
84 before follow-ups carried the pending-message marker and before the
health-band bound existed; their rows stay in the ledger.

## Cost (observed, not a target)

Each case records tokens, latency, and — on Melious — billed credits and
reported energy through the consumption pipeline, joined by wake-run key.
The report extrapolates €/relationship-month and Wh/relationship-month
from a printed assumption (default **1** LLM wake per relationship per
day — a relationship wakes on a lapsed cadence or a fresh check-in, not
on a daily signal sweep), dividing by cases that actually reported the
figure: missing telemetry widens uncertainty, it is never counted as
zero. The deterministic Phase A tick costs no inference at all, so the
real monthly figure is bounded above by the extrapolation.

## Not yet built

- **Tier 2 (outcome eval)** — scoring what a full
  `RelationshipAgentWorkflow` wake *persists* (guarded rejections, forced
  retries, the one-banner transaction fence) rather than what the model
  *attempts*, on the goal suite's tier-2 pattern. Worth building once this
  branch and the goal tier-2 harness live in the same history.
- **Multi-language scenarios** — the contract requires visible text in
  the user's language; the matchers already carry German and Spanish
  negation cues, but every scenario here speaks English.
