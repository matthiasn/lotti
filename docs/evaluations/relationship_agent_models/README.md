# Relationship-agent model evaluations

Inference-level evals for the **relationship agent** (plan v2 phases 4–5,
ADR 0059) — run **before** any model is trusted with a briefing, on the
goal-agent suite's chassis. The prompt and tool definitions under test are
the production contract itself:
`lib/features/relationships/workflow/relationship_agent_contract.dart`;
`test/features/agents/eval/relationship/support/relationship_agent_spec.dart`
re-exports it and keeps the policy matrix the scenarios are derived from.

**The target model is `deepseek-v4-flash-0731`.** It is the viable option
on cost for an agent that may run for many tracked people every day, so
the contract is tuned until it works well there — stronger models are the
control group, not the goal. Use the **dated snapshot**, never the
floating `deepseek-v4-flash` alias: the goal matrix caught that alias
returning five consecutive `HTTP 503`, and a run against a dead alias is
indistinguishable from a model that fails every case. Pinning carries a
staleness cost, and that is the cheaper of the two.

## What is measured

Six scenario families, one catalog
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

Every expectation derives from the policy matrix
`relationshipAgentPolicyMatrix` (R1–R17) in the spec file — the single
source of truth. The offline self-test enforces that every policy row has
a scenario.

## FACTS are production-rendered

The goal suite's tier 1 stated its own headline limitation: authored FACTS
blocks that can drift from what the runtime actually sends. This suite
closes that from day one — every scenario's world (relationship,
check-ins, linked tasks, previous briefing, banners) is rendered through
the REAL `RelationshipFactsRenderer` over a cadence derivation from the
REAL `RelationshipAgentPhaseA.deriveCadenceFacts`, and the wake message is
composed with the workflow's own suffixes. A renderer change moves the
eval with it; the offline self-test pins what the pipeline says about each
world (due vs ok, the REQUIRED-banner line, the quiet window, staleness,
the baseline lapse line) so drift breaks offline before a live run burns
money on stale expectations.

The classifier mirrors `RelationshipAgentStrategy` exactly — every shape
rule it enforces is one the runtime rejects in-conversation (band enum,
required briefing fields, banner tone/animation catalogs, the
explicit-offset snooze instant, the active-adId allow-list, one reply and
one banner per wake), and where the runtime is lenient the classifier is
too (an unknown accent defaults to `calm`). Stricter than the code under
test is the same defect as looser: both measure the harness.

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

Offline (free, runs in CI like any test):

```bash
fvm flutter test test/features/agents/eval/relationship/
```

Live (costs money; everything is manual, no CI runs these):

```bash
LOTTI_RELATIONSHIP_AGENT_EVAL_LIVE=1 \
RELATIONSHIP_AGENT_EVAL_API_KEY=$RELATIONSHIP_EVALS_MELIOUS_KEY \
RELATIONSHIP_AGENT_EVAL_MODELS=deepseek-v4-flash-0731 \
fvm flutter test test/features/agents/eval/relationship/ \
  --tags eval-live --plain-name 'relationship-agent inference report'
```

One sample is not a measurement. The goal suite measured its own noise
floor over five identical runs — total range 10, sd 3.7 per 250 cases — so a
single pass over this suite's 24 cases cannot separate a real regression
from a redraw. Use the matrix runner, which drives N samples per model as
separate processes (GetIt is a global, so two runs cannot share a Dart VM)
and merges the artifacts into one report:

```bash
RELATIONSHIP_AGENT_EVAL_API_KEY=$RELATIONSHIP_EVALS_MELIOUS_KEY \
scripts/relationship_agent_eval_matrix.sh 5 4    # 5 samples, 4 at a time
```

It defaults to `deepseek-v4-flash-0731` (the target) plus `glm-5.2` (the
control group), and writes
`eval_artifacts/relationship_agent_<stamp>/relationship_agent_merged_report.md`
with the leaderboard, the scenario x model matrix, every failure and the
cost table. The merge is `tool/agent_eval_report.dart`, shared with the goal
suite: it derives the subject noun and the wakes-per-day default from the
artifact `kind`, and refuses to merge two suites into one table.

`RELATIONSHIP_AGENT_EVAL_API_KEY` takes precedence over `MELIOUS_API_KEY`
deliberately: relationship-eval spend runs on its own key so it bills
separately from other eval work. Optional knobs:
`RELATIONSHIP_AGENT_EVAL_MODELS` (comma-separated; defaults to
`deepseek-v4-flash-0731`), `RELATIONSHIP_AGENT_EVAL_SCENARIOS` (id
filter),
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
- **No model results yet.** The first `deepseek-v4-flash-0731` matrix run
  is pending a dedicated API key; record results here the way the goal
  README does, with pass matrices and the cost table per run.
