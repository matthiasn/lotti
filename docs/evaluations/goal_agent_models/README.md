# Goal-agent model evaluations

> **Graduated (2026-08-09, PR 3):** the system prompt and tool definitions
> now live in `lib/features/goals/workflow/goal_agent_contract.dart` — the
> production Phase B workflow and this eval suite import the SAME file, so
> the contract the evals validate is the contract the runtime ships. The
> policy matrix stays here as the scenario source of truth.

Inference-level evals for the **goal agent** (ADR 0053–0057) — originally
run *before* the production `GoalAgentWorkflow` existed, so the prompt/tool
contract was model-validated before a line of runtime code depended on it.
The contract now lives in
`lib/features/goals/workflow/goal_agent_contract.dart`;
`test/features/agents/eval/goal/support/goal_agent_spec.dart` re-exports it
and keeps the policy matrix the scenarios are derived from.

## Two tiers

There are two evals here, and they answer different questions. Their numbers
are **not comparable** — do not put them in one table.

| | Tier 1 — inference | Tier 2 — outcome |
| --- | --- | --- |
| Runner | `goal_agent_eval_runner.dart` | `goal_agent_outcome_eval.dart` |
| Input | authored FACTS block | domain entities → real `GoalFactsRenderer` |
| Under test | the model + the prompt/tool contract | the whole `GoalAgentWorkflow` |
| Scored | tool calls attempted | entities persisted |
| Strategy | records, accepts everything | the real `GoalAgentStrategy`, which rejects |
| Retries | none | `_forceReport` / `_forceAd` / `_forceReply` all run |
| Scenarios | 26, P1–P17 | 9, the rows where attempt ≠ outcome |
| Cost | ~1 call per case | 1–3 calls per case |

Tier 1 is the workhorse: cheap, broad, and every scenario is legible. But
three production layers sit between a tool call and the user, and tier 1 is
structurally blind to all of them — the FACTS are authored rather than
rendered, nothing rejects a bad call, and nothing repairs a missing output.
So a tier-1 failure can be a production success, and a tier-1 pass can
persist nothing at all.

Tier 2 exists to measure that gap, not to replace tier 1. It is deliberately
narrow: nine scenarios over the policy rows where the two can disagree.

### Tier 1 — what is measured

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
(P1–P17) in the spec file — the single source of truth. The offline
self-test enforces that every policy row has a scenario and that every
fixture number matches the REAL `GoalProgressEvaluator` + `GoalTrackPolicy`
(`lib/features/goals/evaluation/`), so the fixtures double as the executable
spec of the deterministic tier.

## Fixture world

Keeper **Signe Voss**, Ross Station (Project Waddle penguin universe — never
real user data). The catalog includes G1 "average 10,000 steps/day, rolling 7
days", G2 "station gym 3×/calendar week", and G4, a six-dimensional blood
pressure goal. G4 combines three habits (measure BP 5/7, BP medication 7/7,
weigh 3/7) with weight, systolic, and diastolic series. Its two scenarios cover
an improving 129/94 → 125/84 reading whose latest value is on target while the
127/89 averages remain behind, sparse weight observations, and a variant where
the medication habit is only 6/7. `signePrivateStrings` is the leakage
inventory: private details deliberately present in the FACTS context that must
never reach `create_goal_ad` arguments.

Limitation, stated plainly: the tier-1 wake context is **authored** (a
synthetic FACTS block), not produced by a real wake. The fixtures cross-check
their deterministic arithmetic against the real evaluator and use the
production prompt/tool contract, but the block itself is written by hand and
can drift from what `GoalFactsRenderer` actually emits. Tier 2 closes that
gap for its nine scenarios; the remaining seventeen still run on authored
FACTS.

### Tier 2 — what is measured

Nine scenarios (`goal_agent_outcome_eval_scenarios.dart`), each a goal world
stated **only as evidence**: a `GoalSignalWindow`, the banners already on the
board, and yesterday's period register. Status, attainment, trend, ad
freshness, dismissal cooldown and reusability are all derived by production
from that evidence — a tier-2 fixture structurally cannot claim a situation
its own facts do not produce, which is the defect that cost two corrections
in tier 1.

Pass/fail is over persisted entities:

| Scenario | Policy | Passes when |
| --- | --- | --- |
| `ot_quiet_wake` | P2 | nothing user-visible is written at all |
| `ot_transition_report` | P1 | a report lands carrying the derived status |
| `off_track_first_ad` | P5 | report + a newly authored banner |
| `off_track_fresh_ad` | P6 | no second banner reaches the board |
| `off_track_cooldown` | P5 | the same-day dismissal keeps the board quiet |
| `recovering_retires_ad` | P7 | the stale scolding ends up retired |
| `sparse_insufficient_data` | P8 | `insufficientData`, no banner |
| `off_track_reuses_top_rated` | P13 | a re-run, not fresh copy |
| `chat_question_on_track` | P10 | a reply the chat surface can render |

Two of those are only meaningful at the outcome level. `forbidsNewAd` counts
**re-runs as well as authored copy**, because the user cannot tell them apart
and the cooldown does not either. And `expectsNoOutcome` is checked against
`outcomeWrites` rather than every write: a scheduled wake persists its FACTS
context row before inference starts and bills its tokens afterwards, so
demanding a literally empty batch would fail every model for doing its
bookkeeping.

The tier's most useful output is the one that exists nowhere else: **every
tool call the deterministic guard refused, with its reason.** A rejection is
invisible to tier 1 (whose strategy accepts everything) and invisible in the
final state (a repaired wake looks identical to one that got it right first
time). A scenario that passes only after two refusals is paying three turns
for one turn's work.

Only one fake remains in the tier-2 stack: the signal reader. Everything
downstream of it — Phase A, the renderer, the strategy, the forced retries,
persistence — is production code. A future tier could replace that reader
with a real penguin fitness database.

## Complex health results — 2026-08-13

The first 3-sample baseline exposed a reasoning gap rather than a value-reading
gap. GLM 5.2 and Kimi K3 usually cited the latest readings and rolling averages
correctly, but only passed half the cases because they often failed to say that
today's on-target BP logging was complete. Both Qwen models missed more of the
series evidence and occasionally attempted a forbidden banner action.

| Baseline model | Pass | Mean input | Mean output |
| --- | ---: | ---: | ---: |
| `glm-5.2` | 3/6 | 3,588 | 941 |
| `kimi-k3` | 3/6 | 3,502 | 560 |
| `qwen3.5-122b-a10b` | 0/6 | 4,164 | 1,213 |
| `qwen3.6-27b` | 0/6 | 4,164 | 1,297 |

Prompt-only emphasis regressed GLM 5.2 to 1/6. A top-level daily-action index
or per-series labels helped in different scenarios but neither was reliable by
itself. The selected shape layers three deterministic hints instead:

- `evaluation.todayGuidance` lists health logging complete today, health
  logging still needed today, and rolling habits behind.
- Each health series labels its latest reading with `todayStatus` and its last
  two exact observations with `latestChange`.
- `evaluation.referenceIsCurrentDay` prevents delayed prior-day wakes from
  calling their historical evaluation "today".
- The system contract defines those fields, while the original
  `update_goal_report.tldr` description makes the daily-action distinction
  part of the required output.

With that shape, GLM 5.2 passed 10/10 fresh samples across both scenarios. It
cited the latest values and aggregates correctly, described the improvement,
said BP logging was complete today, isolated the 6/7 medication habit when
present, and never asked for another BP reading.

| Selected-shape model | Strict pass | Today complete | Repeat-BP nudge | Mean input | Mean output | Credits | Wh |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `glm-5.2` | 10/10 | 10/10 | 0/10 | 3,850 | 1,003 | 0.0535 | 19.34 |
| `muse-glimmer` | 1/10 | 10/10 | 0/10 | 4,173 | 1,500 | 0.0185 | 129.67 |

Muse Glimmer therefore reaches the primary daily-action conclusion, uses about
65% fewer reported credits in this small run, and avoids harmful repeat
measurement advice. It is not adequate as the default for the complete report
contract yet: only 2/10 reports bound the latest 94 kg weight to the weight
series, 5/10 explicitly described BP improvement, and 6/10 called out sparse
coverage. Its higher token and provider-reported energy use also mean the lower
credit price is not the same thing as lower resource use. These are tiny model
samples, so the conclusion is a routing signal, not a benchmark claim.

### Structured-report follow-up

The free-form `tldr` remained an omission bottleneck for Muse Glimmer. Replacing
it with five required report slots — evaluated-period state, rolling standing,
latest change, coverage, and actions — changed the result materially. The app
assembles those slots into the visible summary, so a fact cannot disappear in
a second summarization pass. Actions are split into `now` and `later`; a `now`
item must copy a criterion id from `healthLoggingNeededCriterionIds`, and the
runtime discards any id that deterministic FACTS did not authorize. A rolling
6/7 medication habit therefore cannot become an invented "take it today"
instruction.

Fresh five-sample confirmation runs across P16 and P17 produced:

| Structured-report model | Machine checks | Session semantic review | Due-now violations | Mean input | Mean output | Credits | Wh |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `glm-5.2` | 9/10 | 9/10 | 0/10 | 4,295 | 851 | 0.0448 | 20.67 |
| `muse-glimmer` | 10/10 | 10/10 | 0/10 | 4,618 | 2,252 | 0.0254 | 171.20 |

The two scores deliberately measure different things. Machine checks require
the complete production report shape, exact values in the correct slots,
sample counts, an empty `now` list, and absence of captured fabricated or
current-action claims. They do not require mechanistic wording such as one of
several synonyms for "on target" or "improving". The session review reads the
captured prose for the actual conclusion, trend interpretation, and tone.

Muse Glimmer reached the correct conclusion in all ten reviewed reports. It
consistently bound 94 kg to weight, understood the 129/94 → 125/84 improvement,
called out sparse coverage, kept completed logging out of `now`, and isolated
the 6/7 medication habit as future or ongoing focus. GLM did the same in nine
reports; one otherwise-correct report invented that a missed medication day
"resets the full 7-day recovery window", although FACTS only supplied
`daysToRecover: 1`. This is a factual overreach, not a harmless wording variant,
so the captured claim is also retained as a deterministic regression check.

Earlier strict iterations also caught one GLM report that encoded the report
object as a JSON string and one that invented "Take BP medication today".
Tightening the schema description and separating facts from typed actions
removed both from the final sample, but the small run does not prove they are
impossible. Muse is therefore adequate for these health scenarios, not yet a
general Goal Agent default: its mean output remained about 2.6× GLM's and its
provider-reported energy about 8.3× higher, while the small scenario set says
nothing about ads, revisions, dialogue, or no-op discipline.

The richer GLM input is about 7% larger than its baseline input. Follow-up
token-saving experiments should preserve the winning semantics while testing:

- one paired BP observation stream instead of duplicate systolic/diastolic
  timestamps;
- compact observation tuples with latest-day flags attached only once;
- removal of target/window repetition across the statement, criterion tree,
  and result rows; and
- whether summary fields such as `ratio` and `sampleCount` can be omitted when
  the exact series and deterministic status already carry the needed evidence.

Raw run artifacts stay local under ignored `eval_artifacts/`. The final GLM
sample came from the joint run ending `210834`; Muse's came from the Muse-only
run ending `211212`. GLM's table result includes reclassification of the captured
recovery-window fabrication against the committed regression check. The scenario
catalog, objective classifier, and this run record are the reproducible source
of truth committed to the repository.

## Scorer correction — 2026-08-16

The classifier scored `reply_to_user` as an unexpected tool call. That tool is
part of the shipped contract, the runner offers it to the model, and the system
prompt orders "unanswered user message → call reply_to_user exactly once
first". Every dialogue scenario was therefore unpassable by a model that obeyed
the contract: in a 3-sample GLM 5.2 baseline, 14 of 28 failures were this
artifact alone, and `evo_*`, `wk_*` and `tone_roast_request` scored 0/3 across
the board — the "all models fail" smell this README warns about.

Compounding it, the prose assertions read bare assistant text, which is empty
exactly when the model answers through the tool, so
`requiredAssistantContentTermGroups` failed even once the call was tolerated.

Two changes in `goal_agent_eval_runner.dart`: `reply_to_user` joins the
tolerated set (the no-op scenario forbids every tool by name, so restraint is
unaffected), and the prose checks — required terms and forbidden claims alike —
read the reply rather than the bare assistant text.

Both were tightened again the same day, after review of the merged change:
the carrier is tolerated only where FACTS carry a pending user message (an
unsolicited reply on a scheduled status wake is chat nobody asked for), at most
one reply per exchange is allowed (tracked by a per-exchange index on each
recorded call, since a follow-up turn is a separate wake to the runtime), a
blank or
non-string `message` is `invalidToolArguments` as the runtime's `_handleReply`
would reject it, and the prose checks take the surfaced reply in PRECEDENCE
over assistant prose rather than concatenating both — mirroring
`strategy.replyToUser ?? strategy.finalResponse`, under which assistant text is
a hidden thought once a reply exists.

**Results above this line predate the correction.** Dialogue and evolution
scores are not comparable across it; a jump in those rows is the scorer, not
the model. Cost, latency and the health-scenario rows are unaffected.

## Blocked ad tools are withheld, not forbidden — 2026-08-17

Ad over-creation was the largest failure mode of every model measured against
this contract: all 73 `forbiddenToolCall` failures in a 10-sample two-model
baseline involved `create_goal_ad` or `rerun_goal_ad`, 58% of all failures.
Prompt wording could not fix it. Stating the prohibition as a closed list cut
those failures 73 → 30 but made both models skip ads policy REQUIRES
(`missingExpectedToolCall` 15 → 37, `cx_retire_then_rerun` 10/10 → 4/10);
restoring the obligation swung it straight back. The two halves trade against
each other and the net was a wash.

The deterministic tier already knows the answer — `automaticGoalAdEligible`
plus the dismissal cooldown — so `GoalAgentWorkflow` now withholds the ad
tools on a scheduled wake that has ruled a banner out. A tool that is not on
the wire cannot be called. The runner mirrors this via
`GoalAgentEvalScenario.adToolsOffered`, so the eval measures the surface the
app presents rather than a harder problem the runtime never poses.

Two exceptions, both deliberate: the no-op scenario keeps the full surface
because choosing silence while tools are available IS the measurement, and
interactive wakes keep it because an explicit request overrides eligibility
and cooldown (P5) — a judgment made during the turn, not one FACTS can
precompute.

| Model | Pre-gate | With gate | `forbiddenToolCall` | Credits/goal-month | Wh/goal-month |
| --- | ---: | ---: | ---: | ---: | ---: |
| `glm-5.2` | 203/250 | 206/250 | 37 → 27 | 0.376 | 167.0 |
| `qwen3.5-122b-a10b` | 171/250 | 174/250 | 36 → 22 | 0.057 | 67.4 |

**+3 per model, not the +29 first measured.** The first run of this change
carried an eval-only bug: `adToolsOffered` dropped the `priors.isEmpty` branch
of `automaticGoalAdEligible`, so a FIRST at-risk evaluation lost tools the
runtime offers. That withheld ads on `gp_slightly_off` and `gh_gym_pace` —
scenarios where over-creation is the very failure under measurement — and
inflated the result. Two independent reviewers caught it. The rule now mirrors
production exactly, and a property test asserts every atRisk/no-priors/no-trend
scenario keeps its ad tools.

The surviving wins are real and mechanical: `cx_dismiss_cooldown_no_ad` 2→10
and `gp_recovering` 3→10 for qwen3.5-122b-a10b, both cases where the
deterministic tier had already ruled the banner out.

**The +3 is not a clean measurement of the gate.** That run also carried four
scorer tightenings (pending-message gating, reply cardinality and ordering,
payload validation, surfaced-reply precedence), so stricter scoring is mixed
into the same delta — 122b's `unexpectedToolCall` (7) is the pending-message
rule biting, and `ad_no_double` moved 10→3 in a scenario whose tool list never
changed at all. Isolating the gate needs the corrected scorer run WITHOUT it,
which has not been done.

The case for the change does not rest on the delta: a tool that deterministic
policy forbids should not be on the wire, and prompt wording provably could not
achieve the same thing — it only traded ad over-creation against skipping ads
policy demands.

## Muse Glimmer across the full catalog — 2026-08-17

The health-only runs above rated `muse-glimmer` highly and warned that the
sample "says nothing about ads, revisions, dialogue, or no-op discipline."
Measured across all 25 scenarios at 10 samples, it is last:

| Model | Pass | Credits/goal-month | Wh/goal-month | Mean output | Mean latency |
| --- | ---: | ---: | ---: | ---: | ---: |
| `glm-5.2` | 206/250 (0.82) | 0.376 | 167.0 | 840 | 4.86s |
| `qwen3.5-122b-a10b` | 174/250 (0.70) | 0.057 | 67.4 | 922 | 8.33s |
| `muse-glimmer` | 151/250 (0.60) | 0.201 | 1921.8 | 1994 | 53.62s |

Its failure mode is one-sided: **77 `missingExpectedToolCall`** — it writes
prose instead of acting, scoring 0/10 on `ad_create_worsening`,
`cx_retire_then_rerun`, `evo_adjust_target`, `evo_replace_metric`,
`cx_gym_done_steps_collapse`, `gp_recovering`, `tone_roast_request` and
`wk_mixed_musing_question`. Its provider-reported energy is 28x
qwen3.5-122b-a10b's and 11x GLM's, and a 54-second mean wake is an order of
magnitude off both. Cheap credits are not cheap resources (ADR 0058), and the
earlier two-scenario result did not generalise.

Run-to-run variance was never quantified (the same contract was never run
twice), so single-scenario moves of ±3 in this table are not interpretable;
the category shifts and the 29-case total are far outside plausible noise.

## DeepSeek V4 Flash, and the noise floor — 2026-08-17

`deepseek-v4-flash-0731` matches or beats the default on policy compliance at
roughly a tenth of the price, reproduced across two independent 10-sample runs:

| Model | Run 1 | Run 2 | Credits/goal-month | Wh/goal-month | Mean latency | P95 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `deepseek-v4-flash-0731` | 216/250 | 215/250 | 0.032 | 115.3 | 3.44s | 5.96s |
| `glm-5.2` | 206/250 | 210/250 | 0.359 | 137.1 | 4.04s | 7.32s |

**11.2x cheaper, faster at mean and p95, somewhat less energy.** Each margin
sits differently against its own noise, measured over the same five identical
runs (per 250 cases): credits 0.089/0.090/0.087/0.088/0.089 (cv 1.2%), mean
latency 3.33/3.43/3.24/3.19/3.87s (cv 7.1%), energy 304/310/291/290/353 Wh
(cv 7.5%). So the 11.2x cost gap is roughly three orders of magnitude clear of
its noise and is not in doubt; the ~18% latency and ~20% energy gaps are about
2.5x their noise — real, but not decisive on one run each for GLM. The quality
gap is the weakest of the four; see below.

Two operational notes. The floating alias `deepseek-v4-flash` was down when
this ran (five consecutive `HTTP 503`, "the model provider encountered an
error"), so only the dated snapshot is usable; adopting it means pinning, with
the staleness cost that implies. And its residual failures cluster in the
INTERACTIVE half, where the runtime discards unauthorised banners at
persistence anyway (`goal_agent_workflow.dart`, the `!adsEligible` /
`cooldownBlocksAds` / `freshActiveExists` guards on the create and rerun
loops) — so 18 of its 34 failures cost tokens without reaching the user. Its
user-visible defect is the complex-health reporting gap, not ad restraint.

### The noise floor, measured across five identical runs

Running the same model on the same code five times is the control this suite
never had. Totals: **219, 213, 223, 215, 214** — mean 216.8, range 10, sd 3.7.

**Observed range 10 across five runs (sd 3.7, n=5).** A t-based 95% interval
for a single future run is about +/-11 around the mean, so treat any total
delta under ~10 cases as unmeasured, whatever direction it points. Five runs
is itself a small sample for estimating sd, so this bound is indicative, not
exact.

Per-scenario noise is wildly uneven, and the noisy ones are exactly where
report quality is judged:

| Scenario | Five identical runs | Range |
| --- | --- | ---: |
| `gh_complex_habit_behind` | 9, 5, 8, 8, 5 | 4 |
| `evo_withdrawn` | 5, 8, 9, 8, 6 | 4 |
| `wk_mixed_musing_question` | 3, 3, 4, 1, 2 | 3 |
| `gh_complex_latest_on_target` | 7, 8, 7, 5, 6 | 3 |
| `evo_ambiguous` | 6, 4, 3, 4, 4 | 3 |

17 of 25 scenarios have range <= 1 and are effectively deterministic. Five are
unreadable at 10 samples: passing them requires many terms to land at once, so
the pass probability is a product of chances rather than a single draw.

**Rules this imposes:**

- Treat a total delta under ~10 cases as unmeasured. Resolving a 3-case effect
  needs roughly 50 samples per cell (~1250 cases per model), not 10.
- The floor above is for PASS COUNTS. Cost is far steadier (cv 1.2%) and
  latency and energy noisier in relative terms (cv ~7%); judge each metric
  against its own spread, not against the pass-count floor.
- Never read per-scenario movement on the five noisy rows.
- Deltas already published under the old assumption: the ad-tool gate's +3 per
  model and the rolling-aggregate check's +4 are both inside the floor and are
  justified by mechanism, not measurement. The muse-glimmer gap (66 cases), the
  11.6x cost gap and the 28x energy gap are far outside it. DeepSeek versus GLM
  at +5 to +10 is about one sd — "at least as good", not "better".

## The interactive ad bucket was mostly a fixture defect — 2026-08-17

`forbiddenToolCall` — creating a banner where policy forbids one — was the
largest failure class on this suite for every model. The tool-withholding gate
fixed the scheduled half. The interactive half survived, and the reason was
not the model.

Six dialogue scenarios (`evo_*`, `wk_*`, `tone_roast_request`) set
`lastReportStatus` while carrying an EMPTY `priorPeriodAttainments`. A goal
with a previous report necessarily had previous periods, so those FACTS
described a state the runtime cannot produce. `automaticGoalAdEligible` reads
empty priors as a first evaluation, which earns a welcome banner (P4/P5) — so
the deterministic tier said ads were permitted, the gate correctly offered the
tools, the model correctly used them, and the scenario then scored it a
violation.

Giving those fixtures flat (non-declining, so the authored `trendWorsening`
still holds) priors makes them internally consistent. Measured on
`deepseek-v4-flash-0731`, ten samples:

| | Baseline (5 runs) | Consistent priors (2 runs) |
| --- | --- | --- |
| Pass | 216.8/250 (0.867) | 243 and 244 /260 (0.935, 0.938) |
| `forbiddenToolCall` | 21, 14, 14, 13, 15 | 0, 0 |

**Read this as a measurement correction, not a model improvement.** Those
failures were the eval feeding the runtime an impossible state and penalising
the correct response to it. In production a real ongoing goal carries priors,
the tier says ineligible, the gate withholds, and none of it arises.

Two things did change for real. `ad_requested_while_ineligible` is new and
covers P5 — an explicit request for a banner on a wake whose status blocks
automatic ads — which nothing tested before; the runtime could have started
refusing users who asked and no scenario would have noticed. And the
classifier's reply-ORDERING rule is gone: `GoalAgentStrategy` enforces
at-most-once per wake and says nothing about position, so requiring the reply
to come first failed sequences production accepts. It had become the largest
remaining failure category. A harness stricter than the code it measures is
the same defect as one that is looser.

Remaining failures are ~7-9 `missingAssistantContent` (mostly `evo_ambiguous`,
where the model answers instead of asking the clarifying question) and ~5-7
`missingRequiredReportContent` on the complex-health pair. Both are genuine
model behaviour, and both sit in the high-variance scenarios, so more samples
beat more fixes from here.

## Prompt edits need full-suite confirmation — 2026-08-18

`evo_ambiguous` (vague musing: ask one clarifying question, do not propose)
sat at 4-6/10. Reading the captured replies showed genuine model behaviour,
not a harness artifact: warm coaching that never asks anything. The suspected
cause was structural — "for vague musings, ask one clarifying question" lived
inside rule 2, *Goal-change requests*, and a user sighing "this feels a bit
much" never reads as a change request, so the model never reached the clause.

Moving it into rule 1 produced a clean, large, targeted win. Measured on 40
samples of that scenario alone (a cheap way to buy a real error bar):

| Measure | Before | After | Delta (95% band) |
| --- | ---: | ---: | --- |
| any `?` anywhere | 0.525 | 0.900 | +0.375 (+/-0.181) |
| question in the final quarter | 0.375 | 0.900 | +0.525 (+/-0.177) |

Both cleared their bands, and loose and strict agreed afterwards — the
questions had moved to the END of the reply, so it was not rhetorical-aside
inflation.

**The full suite then killed it.** Two runs each side:

| | Before | After |
| --- | --- | --- |
| Total | 243, 244 /260 | 236, 231 /260 |
| `evo_withdrawn` | 10, 10 | 3, 2 |
| `forbiddenToolCall` | 0 | 15 |

The change was reverted. The target gain did not even hold consistently
(10 then 6) while `evo_withdrawn` collapsed in both runs and ad over-creation
returned.

**The lesson is about method, not this rule.** A targeted measurement flatters
a prompt edit, because it measures the one place the edit was aimed and none
of the places it leaks. This is the third prompt change in two days with a
local win and distributed damage; the two structural fixes (withholding tools
the deterministic tier has ruled out, enforcing the aggregates) had no such
tail. At 3572 of 3600 characters this prompt is dense enough that moving text
between precedence rules redistributes attention rather than adding a rule.

**Rule: never accept a prompt edit on a targeted measurement. Confirm on the
full suite, twice, both sides.**

What was kept is the stricter check. `evo_ambiguous` now requires the question
in the last sentence (`\?[^?]{0,60}$`) rather than a `?` anywhere, because the
loose form credited "Some days the win is just getting out the door?" buried
mid-pep-talk. That LOWERS the reported score — 0.375 is the honest rate where
0.525 was flattering — and it is the number to beat from here.

## Tier 2's first run finds a report-loss path — 2026-08-18

Nine scenarios, three samples each, two models. Tier 2's first live run, and
it immediately found something no tier-1 run could have.

| Scenario | Policy | deepseek-v4-flash-0731 | glm-5.2 |
| --- | --- | ---: | ---: |
| `ot_quiet_wake` | P2 | 3/3 | 3/3 |
| `ot_transition_report` | P1 | 3/3 | 2/3 |
| `off_track_first_ad` | P5 | 3/3 | **0/3** |
| `off_track_fresh_ad` | P6 | 3/3 | **1/3** |
| `off_track_cooldown` | P5 | 3/3 | **0/3** |
| `recovering_retires_ad` | P7 | 3/3 | 3/3 |
| `sparse_insufficient_data` | P8 | 3/3 | 3/3 |
| `off_track_reuses_top_rated` | P13 | 3/3 | 3/3 |
| `chat_question_on_track` | P10 | 3/3 | 3/3 |
| **Total** | | **27/27** | **18/27** |

Every one of glm-5.2's nine failures is the same category: `missingReport`.
The wake persisted a banner, or nothing, and left the user with no standing
report at all.

**Why.** All nine were refused by the deterministic guard, twice, and in
eight of the nine the two refusals cite *different rules*:

```
1. "atRisk" is a status field value, not prose. Rewrite the visible text…
2. the rolling standing must quote the FACTS aggregates verbatim —
   6000 is missing.
```

The model fixes what it was told, and trips the next rule on the way out.
`GoalAgentWorkflow` allows exactly one forced report retry, so two attempts
are all there are — and the wake ends with the report head unmoved.

This is not a glm-only story. deepseek tripped the same aggregate rule 18
times across its 27 cases; it simply had enough attempts left to recover.
The rejection counts across both models:

| Rule | deepseek | glm-5.2 |
| --- | ---: | ---: |
| rolling aggregate not quoted verbatim | 18 | 17 |
| status value used as prose | 1 | 12 |
| status field missing entirely | 1 | 2 |

The aggregate rule (shipped in #3961, to stop models substituting the latest
reading for the mean) is by a wide margin the most-tripped rule in the
system. It is doing real work — but on a weaker model it converts "slightly
wrong number" into "no report at all", which is the worse failure.

**Two defects, both in production, not in the harness:**

1. **The guard reports one violation at a time.** `_validateReport` returns
   on the first failed check, so a report breaking two rules costs two round
   trips to learn that. Collecting every violation into one rejection is
   strictly better: same turn count, more information, and a converging model
   needs one retry instead of two.
2. **One forced retry is not enough when rejections are sequential.** Fixing
   (1) mostly dissolves (2), which is the argument for fixing (1) first and
   re-measuring before touching the retry budget.

**Caveats.** Three samples per cell is thin — the tier-1 noise floor work is
explicit that n=3 cannot rank two close models. It is enough here because the
failures are not a scatter: they are one category, concentrated in one model,
with a mechanism visible in the rejection log. The ranking claim
("deepseek > glm") is weak at this n; the defect claim is not.

Cost over the same run, and note this is per WAKE, not per call — a repaired
wake pays for its retries:

| Model | Cases | Credits | Credits/goal-month | Wh/goal-month |
| --- | ---: | ---: | ---: | ---: |
| `deepseek-v4-flash-0731` | 27 | 0.0113 | 0.0376 | 80.6 |
| `glm-5.2` | 27 | 0.1421 | 0.4737 | 81.5 |

## Cost and latency

Cost and wall-clock latency are first-class outputs, captured per case:

- Each result records `latencyMs` across the full scenario, including every
  follow-up turn. The merged leaderboard reports mean and p95 latency per model
  so uniformly slow inference can be distinguished from a long tail.

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

### Tier 2 (outcome eval)

Separate driver, separate env vars — deliberately, so a tier-1 command line
cannot silently launch the slower, more expensive tier.

```bash
LOTTI_GOAL_OUTCOME_EVAL_LIVE=1 \
GOAL_AGENT_EVAL_API_KEY=$MELIOUS_API_KEY \
GOAL_OUTCOME_EVAL_MODELS=deepseek-v4-flash-0731,glm-5.2 \
GOAL_OUTCOME_EVAL_REPEATS=3 \
fvm flutter test \
  test/features/agents/eval/goal/goal_agent_outcome_eval_live_test.dart \
  --tags eval-live
```

| Env var | Default | Meaning |
| --- | --- | --- |
| `GOAL_OUTCOME_EVAL_MODELS` | `glm-5.2` | comma-separated model list |
| `GOAL_OUTCOME_EVAL_SCENARIOS` | all 9 | comma-separated scenario ids |
| `GOAL_OUTCOME_EVAL_REPEATS` | `1` | samples per (model, scenario) |
| `GOAL_OUTCOME_EVAL_JSON` / `_MARKDOWN` | temp dir | artifact paths |

`REPEATS` is a first-class parameter rather than an outer loop because a
single sample of a live model says almost nothing — see the noise floor
above. Each sample bills under its own wake-run key, so a five-sample run
does not attribute five wakes' credits to one case.

Resolution goes through a **profile**, not the goal agent's built-in
`glm-5.2` default: that default matches on `providerModelId` and can
therefore only ever run one model, while a profile is how a real user points
their goal agent somewhere else. Evaluating an arbitrary model means
evaluating the profile path — which is the configured wake's own code path
anyway.

## Methodology caveats

- **Samples are small.** 3 samples per cell is noise-level for anything but
  gross differences; treat single-cell flips as anecdotes, not signal.
- **Machine checks and prose review are separate.** The classifier is
  deterministic (tool calls, complete shared report parsing, argument subsets,
  values pinned to structured slots, and negation-aware forbidden claims from
  `eval_text_matchers.dart`). It does not approximate semantic quality with an
  expanding synonym list. Captured prose is reviewed separately for conclusions,
  tone, and unsupported implications. There is no LLM judge wired in; if one is
  added, it is diagnostic only, never part of the pass/fail gate (task-agent
  eval rule).
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
