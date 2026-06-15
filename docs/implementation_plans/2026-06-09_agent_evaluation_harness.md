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
  private raw-trace mapping keys, plus first-class scenario corpus governance
  for required capability/split cells, per-agent stress-tag cells, protected
  holdout coverage by required capability, safe capability selectors, and
  redacted aggregate preflight matrices.
  Next up:
  populate a real human-labeled calibration set, private production-replay
  holdout JSON catalogs that satisfy the governance cells, and a larger
  production-scale adversarial scenario corpus.
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
Latest active slice adds manifest-bound use-case work-order launch evidence,
the private-to-public `model-class-evidence` extractor, and source-checked
coverage writer: follow-up run manifests bind launched work-order batches to a
source work-order digest, verified run manifests/traces are reduced to
sanitized model-class evidence rows, and the public coverage ledger rechecks
that evidence against the concrete work order, experiment plan, and run
artifacts before export.
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
success/failure. Trace schema 11 adds optional `EvalTraceCascadeWake` metadata
(`cascadeId`, `wakeIndex`, `wakeCount`); real `trialIndex` remains the repeated
trial index, and wake identity is added to trace filenames, verifier keys, and
calibration keys. Cascade sidecar manifests now also record
`traceTopologyEvidence`, a digest-bound pre-run declaration of the task-log
cascade id and per-scenario wake counts. The verifier builds expected cascade
keys from that manifest evidence instead of inferring topology from whatever
trace files exist, and rejects cascade wake traces or direct-trace substitution
when topology evidence is missing or drifted. Reporter and tuning-readiness code
now exclude cascade wake traces from repeated-trial reliability and promotion
evidence while still rendering provider request/cache diagnostics. The intended
hard-gate boundary is structured behavior: estimate, priority, due date, labels,
checklist updates, and persisted proposals. Generated reports and summaries are
still read into
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
and profile promotion. `EvalTuningPolicy` can now opt into blinded pairwise
readiness gates with a minimum decided-pair count and exact pre-registered
comparison keys. Plans generated from pre-run readiness intent can also bind an
explicit expected outcome for each pair: a named intent option must either win
or, when the requirement is `mustNotLose`, avoid a strict loss. The gate
evaluates that expectation against the winning trace after canonicalizing
randomized A/B order, so reviewer-facing option labels never define candidate
direction.
The reporter supports one tuning axis per comparison: profile/model-class A/B
under the same prompt variant, or prompt-variant A/B under the same profile.
Votes that change both axes in one comparison are invalid so subjective quorum
results cannot hide a confounded experiment design.
The quorum also rejects mixed review protocols: reviewer kind/model, prompt
digest, calibration-set version, blinding flags, and trace-order randomization
must match across pooled votes.
Current active slice tightens blinded judge verdict provenance. Imported
blinded verdicts already carry `blindedImport` records; verifier and
model-class readiness now require those records whenever
`judge.modelIdentityVisible` is false. The record must bind the blinded trace
id, review payload digest, judge manifest digest, private key digest, source
run manifest digest, and raw trace digest back to the verified run. Raw verdicts
with a self-reported blind flag but no importer provenance, stale raw-trace
digest, or source-manifest drift cannot satisfy tuning readiness.
Current active slice adds pairwise-specific blinded review artifacts:
`EvalBlindedPairwisePreference.writePairs` creates reviewer-facing
`*.blinded-pair.json` packets plus a private key, with aliases and redacted
outputs in public files and raw digest mappings only in the private key.
`importVotes` validates the judge manifest, private key, pair payload digest,
raw trace digests, packet contract, and missing/extra wrappers before writing
raw `.preference.json` votes with `blindedImport` provenance. Pairwise results
remain diagnostic; stricter policies can now require blinded-import provenance,
hidden profile/model/peer-vote identity, randomized trace order, decided
quorums, registered comparison keys, manifest provenance matches, and raw
trace-digest matches without promoting A/B outcomes automatically. Registered
readiness plans are closed sets: extra comparison keys fail, only registered
comparisons count toward minimum decisions, and all counted votes must share one
review protocol fingerprint across the gate. Pairwise readiness also requires
the run manifest and re-binds every vote option to writer-derived raw trace refs
from the same artifact read used for the votes, so stale, orphaned, or
in-memory-only trace refs cannot satisfy the gate.
Pairwise vote and trace-reference JSON now rejects unknown audit-looking fields,
blank identifiers, malformed digests, malformed issue lists, and inconsistent
reviewer-kind/model protocol claims at parse/validation time. Diagnostic
pairwise reports also flag imported-looking votes as not readiness-plan
verified unless an explicit pairwise readiness plan supplies the judge
manifest, private-key, review-payload, source-manifest, and raw-trace digest
bindings.
Run and plan mode can load an explicit pre-run `EvalPairwiseReadinessIntent`
via `EVAL_PAIRWISE_READINESS_INTENT`; the intent is bound to the
scenario/profile/profile-binding/prompt-variant digests and records stable
`intentKey` values plus per-pair `mustWin` or `mustNotLose` expectations without
raw trace digests, review-payload digests, or import bindings. The run manifest
stores the intent subject as `pairwiseReadinessPlanEvidence`, so a first run can
be manifest-bound to a closed pairwise review set before traces exist.
`blind-pairwise` can derive its review pairs from the same intent and then emits
the post-run private `EvalPairwiseReadinessPlan`, mapping each `intentKey` to
the full digest-bearing comparison key, review payload digest, and
intent-bound outcome expectation.
Report mode loads that completed plan via `EVAL_PAIRWISE_READINESS_PLAN`; the
plan is bound to the scenario/profile/profile-binding set digests, the completed
manifest digest, the embedded intent when present, and manifest-embedded plan
evidence.
The run-side `pairwise_readiness_plan.registration.json` artifact written by
`blind-pairwise` is diagnostic only; it helps report mode discover that a
generated private plan exists, but it cannot replace evidence inside the run
manifest because it is mutable outside `manifestDigest`. Exact comparison keys
include raw trace digests, so `blind-pairwise` now generates the private
`pairwise_readiness_plan.json` after traces exist and records the same intent
subject digest for diagnostics. Operators can tune the generated plan id,
minimum registered decisions, quorum, vote count, and human-vs-LLM review
protocol through the `EVAL_PAIRWISE_READINESS_*` and `EVAL_PAIRWISE_REVIEW_*`
export-time variables when no intent supplies them. The plan is also a closed
schema over registered comparison keys, intent keys, review protocol
fingerprint, judge-manifest/private-key digests, and per-comparison
review-payload digests. Report mode revalidates registered vote trace refs
against the embedded intent comparison before counting them, so post-hoc
comparison remapping, sidecar-only registration, and stale or mismatched blinded
imports cannot satisfy the readiness gate.
`eval/run_level2.sh blind-pairwise` accepts either an explicit
`EVAL_PAIRWISE_PAIRS` JSON file or derives pairs from
`EVAL_PAIRWISE_READINESS_INTENT`; it writes the blinded pair packet, private key,
private readiness plan, and run-side registration. `import-blind-pairwise`
imports completed blinded preference wrappers.
Current active slice also makes one vote per `<safeVoteId>.preference.json`
a first-class run artifact. `TraceWriter.readRun` deliberately ignores those
files so ordinary verification, readiness, calibration, and promotion gates stay
trace/verdict-only; report mode reads them explicitly after verification and
prints a diagnostic A/B section. The preference reader rejects stale or orphaned
trace bindings by recomputing trace digests, and trace overwrite refuses to
leave old preference votes behind unless the caller explicitly deletes them.
Current active slice adds an explicit use-case capability contract:
`EvalTuningPolicy.requiredPrimaryCapabilityIds` and
`EVAL_REQUIRED_CAPABILITIES` let operators name exact primary capability ids
that must be present before report/verify can claim tuning readiness. The
runner now records those ids as manifest-bound
`tuningReadinessContractEvidence`, report mode uses the run-bound contract by
default and rejects contradictory report-time env, and the verifier audits the
contract digest plus required primary capability coverage. The readiness report
renders required and missing use cases, and a run with enough aggregate
capabilities still fails if a named app use case is absent.
Current active slice now also records `tuningReadinessPolicyEvidence`
(`policyName` plus canonical policy digest) in the run manifest. The digest is
computed from every `EvalTuningPolicy` field, including required capabilities,
policy-evidence enforcement, outcome-quality thresholds, slice gates, and
pairwise preference thresholds plus oriented pairwise outcome expectations, and
report/verifier paths reject drift from the manifest-bound policy. Model-class
tuning readiness now fails closed when a run
manifest lacks `tuningReadinessPolicyEvidence`. The default model-class policy
now requires judge-pass outcomes, a Wilson pass-rate lower bound, measured
token/weighted-cost budget ratios, and minimum goal-attainment/quality/efficiency
floors globally and for every primary-capability x agent-kind x model-class x
prompt-variant slice, so a green aggregate cannot hide a failing use case or
model class.
Runs with manifest-registered pairwise readiness evidence, whether from a
pre-run intent or a completed plan, can no longer drop that gate by omitting
`EVAL_PAIRWISE_READINESS_PLAN` at report time.
Current active slice adds `eval/run_level2.sh tune`, a machine-readable
post-run contract for tuning loops. It runs the same verification gate as
`report`, then writes a versioned `lotti.evalTuningReport` JSON file with typed
gates, blocker codes, use-case/model slices, recommendations, a
next-experiment plan, and a stable snapshot over logical manifest/trace/verdict
refs plus exact loaded trace/verdict content. The snapshot excludes sidecar run
directory files such as a previous `tuning_report.json`, so overwrite runs do
not report false drift. The writer validates the assembled JSON with
`EvalTuningReportContract` before touching the output path, then applies the
external-catalog output guard,
refuses accidental overwrites, and recursively redacts protected scenario ids
from strings and map keys before writing.
Current active slice adds a multi-run tuning portfolio comparator:
`eval/run_level2.sh compare-tuning` reads existing `lotti.evalTuningReport`
JSON files, validates every input with `EvalTuningReportContract`, groups only
reports that share fixed target/scenario/policy/capability/redaction evidence,
and writes a versioned `lotti.evalTuningPortfolio` JSON file. Profile/model
class and prompt-variant differences are treated as explicit tuning axes, while
incompatible evidence groups are never ranked against each other. The portfolio
distinguishes `promotionReady` candidates from diagnostic leaders and
data-deficient evidence, omits scenario ids entirely, and preserves digest
evidence so operators can tune model classes and prompt variants without
inventing private holdout data or human calibration labels. Its contract
validator checks summary/count consistency, compatibility-key digest binding,
candidate metric shape, group-scoped next-experiment plans, safe selector/env
values, and a recursive no-scenario-id privacy rule before the runner writes the
JSON artifact. Portfolio next plans separate a static `compare-tuning` refresh
command from manual prerequisites, reject `EVAL_SCENARIO_IDS` in `nextRunEnv`,
reject command env maps and live `plan`/`run`/`tune` recommendations, and keep
incompatible evidence groups isolated instead of merging selectors across
model-selection cohorts.
Catalog preflight follows the same public-handoff boundary: static
`catalog`/`plan`/`run`/`tune` command templates are exact strings with omitted
values, below-minimum profile trial counts are represented by opaque profile
slots, and forged executable command/env payloads are rejected.
Current active slice adds a privacy-safe evidence intake planner:
`eval/run_level2.sh evidence-intake` reads existing
`lotti.evalTuningReport` JSON files and writes
`lotti.evalTuningEvidenceIntakePlan`. The artifact turns model-class tuning
blockers into digest-bound manual tasks for human calibration labels, protected
production-replay holdout catalogs, scenario review metadata, blinded pairwise
review, verdict grading, and coverage expansion. Slice-specific blockers carry
only public capability, agent-kind, model-class, and prompt-variant scope;
report-level blockers stay attached to opaque report refs. The planner creates
no labels, no protected rows, no scenario reviews, no live commands, and no
promotion claims, and it rejects leaked scenario ids, profile names, raw run
ids, private paths, env values, and live `run`/`tune` command text.
Current active slice adds a use-case tuning matrix projection:
`eval/run_level2.sh use-case-matrix` reads existing `lotti.evalTuningReport`
JSON files, source-checks each report against the referenced run artifacts, and
writes a versioned `lotti.evalUseCaseTuningMatrix` artifact. The matrix is a
privacy-safe projection, not another readiness engine: it references inputs by
opaque `report-N` ids, treats raw run ids and scenario ids as denied values,
digests candidate/cell keys, and recursively rejects scenario-id fields,
redacted placeholders, and `EVAL_SCENARIO_IDS`. Source checks recompute the run
manifest binding, artifact snapshot, policy payload digest, readiness summary,
use-case slices, blocked reason codes, supplied calibration/pairwise evidence,
and manifest-bound promotion plans. Promotion decisions are recomputed from the
source traces and plan before matrix cells may become `promotionReady`, and
successful source-check results are validator-marked so fabricated
`sourceChecked` objects remain invalid inputs. Missing or invalid source checks
make the public report invalid even when its JSON contract is self-consistent.
It keeps compatibility groups isolated by target kind, scenario-set digest,
policy digest, protected-id
redaction mode, visible required capabilities, and a digest over the raw
required-capability selector set so protected selector differences cannot be
merged after visible redaction. Cell statuses distinguish `promotionReady`
source evidence from clean-but-unpromoted diagnostics, unready/data-deficient
reports, and blockers. Missing required primary capability coverage is emitted
as digest-bound `requiredPrimaryCapability` gap evidence with safe public labels
only when available, omitted-value counts, and `coverage.capabilityMissing`
blocker codes; these gaps block promotion-ready claims without leaking
protected catalog dimensions. Matrix next plans emit only static
`use-case-matrix` and `experiment-plan` refresh commands, never command env maps
or live `plan`/`run`/`tune` recommendations.
Current active slice adds a bounded use-case experiment-plan artifact:
`eval/run_level2.sh experiment-plan` consumes one
`lotti.evalUseCaseTuningMatrix` JSON file and writes a versioned
`lotti.evalUseCaseExperimentPlan`. The artifact is matrix-only: it does not
re-read traces, create labels, re-run catalog governance, expose scenario ids or
raw run ids, invent profile selectors, or create promotion claims. It emits
bounded batch plans only for compatible `diagnosticOnly` or `dataDeficient`
matrices whose capability and prompt selectors are public-safe and non-opaque;
public recommended commands are static `experiment-plan` and
`next-run-work-order` artifact commands only. The artifact now also carries an
`operatorHandoff`
section: non-secret action categories, private-input env key names, and static
templates for catalog preflight, missing-verdict grading, calibration,
pairwise review, report regeneration, matrix regeneration, and plan
regeneration. The contract binds summary counts to arrays, binds status to
runnable batches and handoff state, rejects recursive scenario/profile/run-id
fields, rejects private path strings and value-bearing private env maps, and
uses tokenized `eval/run_level2.sh` command detection so shell-wrapped
`plan`/`run`/`tune` commands cannot appear in public plan scopes. It also emits a
pending `adversarialReviewQueue` with fixed audit kinds for privacy, command
safety, selector safety, evidence sufficiency, and conditional holdout/catalog,
calibration, and pairwise reliability checks. Queue tasks are digest-bound,
contain no executable fields or env values, cannot claim completion, and must
include the holdout/catalog governance audit whenever blocker codes indicate
catalog, source, review, adversarial, or protected-holdout work.
Current active slice adds a use-case next-run work-order artifact:
`eval/run_level2.sh next-run-work-order` consumes one
`lotti.evalUseCaseExperimentPlan` and writes a versioned
`lotti.evalUseCaseNextRunWorkOrder`. The work order is the bounded operator
handoff for running the next eval pass: it turns ready plan batches into
opaque run batches whose `workOrderBatchRef` is bound to the plan digest,
source matrix digest, source plan batch ref, source cell keys, compatibility
key, and public env. It allows exactly two public env values:
`EVAL_REQUIRED_CAPABILITIES` and `EVAL_PROMPT_VARIANT_NAMES`. Scenario ids,
profile names, raw run ids, private paths, provider/model ids, raw prompt text,
and concrete private env values remain withheld. Non-ready, invalid, and
selector-deficient plans produce no runnable batches. Command content is
template-only: exact `eval/run_level2.sh plan|run|tune <nextRunId>` strings
with command-template refs, no inline env assignments, shell wrappers, pipes,
or separators. The artifact also carries pending adversarial review tasks for
privacy, env allowlisting, command-template safety, and evidence-objective
preservation so `collectData` batches cannot be mislabeled as promotion
evidence. `workOrderRef` binds the source plan summary, run batches, command
templates, blocker codes, privacy/limitation claims, and review queue; the
review task validator recomputes required `reviewRef`, `sourceRefs`, and
checklist content from the work-order sources. Import boundaries can call the
source-aware validator against the original experiment plan so a restamped
work order from unrelated matrix/plan inputs is rejected even when local
artifact hashes were recomputed. The privacy validator also catches
`/home/...` and `file:///...` paths.
Current active slice adds a private-to-public model-class execution evidence
extractor: `eval/run_level2.sh model-class-evidence` consumes a validated
`lotti.evalUseCaseNextRunWorkOrder`, the concrete source experiment plan,
private follow-up run ids, and the same private scenario/profile/prompt
catalogs used by the verifier, then writes
`lotti.evalUseCaseModelClassExecutionEvidence`. The extractor source-checks the
work order against that experiment plan, rereads each run with
`TraceWriter.readRun`, verifies it with `EvalRunVerifier`, binds source run refs
to manifest and catalog digests, and emits only sanitized
`evidenceRows`: source-run refs, work-order batch refs, enum `EvalModelClass`
names, profile-slot refs, expected/observed/verified trace counts, and boolean
resolved-model/provider-request evidence. The validator recomputes
`sourceRunRef`, every `evidenceRowRef`, and the top-level
`executionEvidenceRef`; ready bundles require source runs, and rows must cite a
source run. Raw run ids, scenario ids, profile names, provider/model ids,
endpoints, prompt text, private paths, and env values are rejected recursively.
Duplicate source runs are blocked before they inflate counts, stale manifests
invalidate the source, and missing runtime evidence reduces verified counts
without leaking the private trace payload. The public source-work-order summary
records source plan and matrix digests, so a restamped work-order artifact
cannot seed public coverage evidence. Contributing runs must carry manifest
readiness-contract evidence for the work-order public capabilities and prompt
variants plus matching `useCaseWorkOrderLaunchEvidence`; otherwise evidence
extraction emits an `invalidSource` blocker. Follow-up `plan` and `run`
commands can take `EVAL_USE_CASE_RUN_WORK_ORDER` plus optional
`EVAL_USE_CASE_RUN_WORK_ORDER_BATCH_REFS` and record the source work-order
ref/digest, source plan/matrix digests, launched batch refs, batch-ref set
digest, public selectors, and launch-subject digest in the manifest without
persisting the private work-order path. The extractor recomputes that launch
subject, checks the work-order ref/digest and batch set, and emits rows only
for batches listed in the source run's launch evidence, so a
selector-compatible run launched from another work order cannot seed coverage.
Current active slice adds a post-execution model-class coverage ledger:
`eval/run_level2.sh model-class-coverage` consumes a validated
`lotti.evalUseCaseNextRunWorkOrder`, the same source experiment plan and
follow-up run ids used for evidence extraction, plus one validated
`lotti.evalUseCaseModelClassExecutionEvidence` bundle and writes public
`lotti.evalUseCaseModelClassExecutionCoverage`. The coverage
policy names the four canonical `EvalModelClass` enum values explicitly
(`localSmall`, `localReasoning`, `frontierFast`, `frontierReasoning`) so the
artifact can detect omitted model classes instead of only summarizing observed
classes. The public ledger aggregates extractor evidence into counts, source
evidence bundle digests, and digest refs only: no profile names, provider ids,
provider model ids, local config ids, endpoints, raw run ids, scenario ids,
prompt text, private paths, or env values. Extractor bundles are mandatory and
validated before their rows count; raw row lists cannot mint public coverage,
stale bundle work-order digests invalidate source evidence, and the bundle-set
digest is bound into every `coverageCellRef` and `coverageRef`. The writer also
rebuilds the supplied evidence bundle from the concrete run artifacts, checks it
against the source experiment plan and work order, and source-checks the
finished coverage artifact against the supplied work order so forged evidence
or restamped coverage source metadata cannot be exported. Public coverage now
records whether execution evidence was concretely source-checked; unchecked
bundles can only produce `invalidSource` coverage blockers. `coverageArtifactRef`
binds source summaries, policy, model-class summaries, coverage cells,
privacy/limitation claims, issues, and exact recommended command templates.
Source status fields are constrained to the work-order/evidence status enums,
and command templates must match the generated static artifact commands so
shell-smuggled public commands cannot validate after ref recomputation. Non-enum
classes such as
`frontier`, `local-small`, and
`model-*` fallbacks are invalid source evidence, while missing enum classes
produce `partialCoverage` or `noCoverage`.
Current active slice adds a use-case tuning campaign artifact:
`eval/run_level2.sh campaign` consumes one
`lotti.evalUseCaseExperimentPlan`, follow-up `lotti.evalTuningReport` JSON
files, and optional `lotti.evalUseCaseModelClassExecutionCoverage` JSON files,
then writes a versioned `lotti.evalUseCaseTuningCampaign`. The campaign
source-checks follow-up reports before linking them to planned batches; missing
or invalid report source checks keep the report visible as invalid input and
cannot close a batch. Source-checked reports must still be validator-marked,
recompute the same fixed compatibility key shape used by the matrix, carry
source-derived public selectors, and cover the planned public capability and
prompt-variant selectors through matching work-order launch evidence. Ready
evidence is stricter than
report-level readiness: it requires validated, ready, blocker-free relevant
use-case slices for the planned selectors plus covered model-class execution
coverage for the exact plan-derived work-order batch ref. Missing, partial,
stale, source-mismatched, or invalid model-class execution coverage adds
blocker codes and keeps the campaign in progress; forged
`readyEvidenceCollected` batches and fabricated source-check objects are
rejected unless they carry complete source and coverage proof. Coverage inputs
require the matching coverage work order; campaign import validates coverage
against that work order before it can close a batch.
Invalid reports, selector-only
compatibility mismatches, partial selector coverage, and blocked follow-up
reports are retained as opaque refs and blocker codes but cannot close a batch.
The artifact emits only static campaign/matrix/plan refresh commands, carries a
pending adversarial review queue for privacy/report linkage/model-class
coverage/blocker-regression checks, requires the model-class coverage audit for
planned coverage even when evidence is otherwise ready, and recursively rejects
scenario/profile/run fields, private paths, private env values, executable
queue fields, and review-completion claims. `campaignRef` binds source plan,
input reports, model-class coverage summaries, batch progress, blockers, and
the review queue, while validation independently recomputes the required review
categories, `reviewRef`s, source refs, and checklist text from blockers and
batch progress so a recomputed campaign cannot drop required audits.
Current active slice promotes campaign adversarial review to first-class
artifacts. `eval/run_level2.sh review-packet` consumes one validated campaign
and writes `lotti.evalUseCaseAdversarialReviewPacket`, a reviewer-facing
packet with the campaign ref, campaign digest, source review-queue digest,
exact required `reviewRef`s, categories, checklist items, opaque batch refs,
blocker codes, and pending attestation templates. `reviewPacketRef` binds the
source campaign summary, tasks, templates, issues, and contract claims. The
packet creates no approvals or review completion claims.
`eval/run_level2.sh import-review` consumes the campaign plus completed review
JSON and writes
`lotti.evalUseCaseAdversarialReviewAttestationBundle`. Import binds every
attestation to the source campaign digest, queue digest, `reviewRef`, and
category; recomputes each attestation `evidenceDigest` from source digests,
review ref, category, status, reviewer digest/timestamp fields, and
non-executable/privacy flags; rejects stale source/queue digests, wrong
refs/categories, missing or duplicate tasks, and malformed status evidence; and
preserves rejected or needs-changes attestations without letting them satisfy
decision gates. `attestationBundleRef` binds source campaign summary, required
tasks, imported attestations, issues, and contract claims. Bundle validation
rechecks source campaign digest, source queue digest, required task coverage,
duplicate tasks, and pending-template inputs from public fields before
exporting approved attestations to later gates. The review artifacts reject
commands, env maps, live `plan`/`run`/`tune`/`all` strings, private paths, raw
run ids, profile/scenario fields, redacted placeholders, and raw
reviewer identity fields.
Current active slice adds a use-case tuning decision ledger:
`eval/run_level2.sh decision-gate` consumes a refreshed
`lotti.evalUseCaseTuningMatrix`, an optional
`lotti.evalUseCaseTuningCampaign`, optional previous decision ledger, and
optional adversarial review attestation bundle files, then writes a versioned
`lotti.evalUseCaseTuningDecisionLedger`. The ledger is the governance layer
above matrix/plan/campaign evidence. It accepts a use-case/model-class/prompt
choice only when the refreshed matrix cell is `promotionReady`, the matrix input
report digest is present in campaign-ready follow-up evidence with a batch-bound
model-class coverage proof, the campaign compatibility key and public
capability/prompt selectors match, and every required campaign review category
has an approved non-executable attestation. Accepted candidates carry only proof
refs and digests for the campaign coverage snapshot, source work-order digest,
report digest, and exact work-order batch; coverage cells, source runs, model
ids, scenario/profile selectors, and prompt text stay out of the ledger.
Diagnostic-only and data-deficient cells remain watch/blocked decisions even
when their metrics are strong; multiple promotion-ready cells for the same
compatibility/use-case/agent scope become conflicts even when only one carries
coverage proof; stale matrices are blocked when they omit campaign-ready report
digests; and previous accepted decisions are carried forward as rollback or
revalidation requirements when later evidence regresses. `decisionLedgerRef`
binds the source matrix/campaign summaries, including the campaign subject ref,
review gate, matrix refresh evidence, decisions, continuity, blocker summary,
and issues so exported ledgers cannot silently relabel accepted choices or
rewrite the campaign-review outcome. The review gate carries sanitized
approved-attestation evidence refs, and validation derives approval,
missing-review, status, blocked-reason, and summary counts from public ledger
fields instead of trusting stored counters. The contract emits only
digests, opaque refs, safe capability/model-class/prompt labels, blocker codes,
static decision/matrix/campaign command templates, and recursive privacy checks;
it rejects scenario/profile/run-id fields, private paths, private env values,
live `plan`/`run`/`tune`/`all` command smuggling, and review attestations that
carry env or executable fields.
Current active slice adds a cross-ledger use-case tuning roadmap:
`eval/run_level2.sh roadmap` consumes one or more
`lotti.evalUseCaseTuningDecisionLedger` files and writes a versioned
`lotti.evalUseCaseTuningRoadmap`. The roadmap is the aggregate governance layer
above individual decision gates. It groups decisions by scope key, keeps
different compatibility keys isolated, carries rollback/revalidation continuity
forward, flags independent ledgers that accept different cells for the same
use-case/agent scope, and refuses to mark a scope accepted when another ledger
contests that evidence. It consumes decision ledgers only, applies no runtime
configuration, emits only static roadmap/decision-gate command templates, and
uses valid source ledgers' `decisionLedgerRef` values as public ledger refs
while redacting all ledger paths from stdout. The contract rejects scenario/profile/raw
run-id fields, private paths, private env values, env maps, and live
`plan`/`run`/`tune`/`all` command smuggling.
Current active slice adds a dry-run use-case tuning release plan:
`eval/run_level2.sh release-plan` consumes a validated
`lotti.evalUseCaseTuningRoadmap`, source decision ledgers when the roadmap is
accepted, and an optional previous release plan, then writes
`lotti.evalUseCaseTuningReleasePlan`. This is a reviewable runtime-assignment
manifest, not an apply tool. It turns accepted roadmap scopes into stable
assignment refs over public `primaryCapabilityId`, `agentKind`, `modelClass`,
and `promptVariantName` labels plus the public model-class coverage proof ref,
work-order batch ref, coverage digest, and source work-order digest, records
`applyState: notApplied`, publishes `modelClassCoverageProofSummary`, binds
`releasePlanRef` and the release-review queue to
`modelClassCoverageProofSummaryDigest`, and asserts that no runtime
configuration or `AiConfig` mutation was written. When source decision ledgers
are supplied, release planning replays the roadmap source contract against those
concrete ledgers before trusting accepted choices, rollback evidence, or
revalidation evidence; accepted roadmaps additionally fail closed when the
roadmap's ledger refs and digests are missing. Rollback and revalidation
roadmap states emit no assignments; rollback review requires source
decision-ledger continuity evidence such as `previousAcceptedCellKey` because
the roadmap itself
intentionally does not preserve enough private runtime identity. The contract
rejects private paths, env values,
scenario/profile/raw run fields, local config ids, agent/task/template/category
ids, live eval commands, shell/mutation commands, executable review tasks, and
unsafe prompt-variant tokens.
Current active slice adds release-plan review packet/import governance:
`eval/run_level2.sh release-review-packet` consumes a ready
`lotti.evalUseCaseTuningReleasePlan` and writes
`lotti.evalUseCaseTuningReleaseReviewPacket`; `import-release-review` consumes
the same plan plus completed release-review JSON and writes
`lotti.evalUseCaseTuningReleaseReviewAttestationBundle`. The packet binds
review work to the full release-plan digest, `releasePlanRef`, source roadmap
digest, release review-queue digest, exact `reviewRef`, category, and
assignment-ref set digest plus the model-class coverage proof-summary digest.
Each exported task carries a `sourceReviewTaskDigest` and finalized
`releaseReviewPacketRef`, while `releaseReviewPacketRef` binds the source
release-plan summary, tasks, pending templates, issues, safe command templates,
and contract claims. The importer rejects non-ready release plans, unchanged
pending templates, stale source/queue/packet/task/assignment-set/proof-summary
attestations, missing tasks, duplicate tasks, and unmatched extra tasks.
Completed attestations recompute `evidenceDigest` from source digests, packet
ref, review-task digest, review ref, category, assignment/proof digests, status,
reviewer digest/timestamp fields, and non-executable/privacy flags, while
`attestationBundleRef` binds the imported bundle subject. It
preserves the
dry-run contract: no runtime configuration is applied, no `AiConfig` mutation
is written, and all review paths remain redacted from stdout. Standalone packet
and bundle validation recomputes `assignmentRefsDigest`, `reviewRef`, source
digest consistency, and task/template/attestation coverage from public fields.
Current active slice adds the final non-mutating use-case release gate:
`eval/run_level2.sh release-gate` consumes a ready
`lotti.evalUseCaseTuningReleasePlan` plus one or more
`lotti.evalUseCaseTuningReleaseReviewAttestationBundle` files, then writes
`lotti.evalUseCaseTuningReleaseGate`. The gate approves only when the release
plan is `readyForReleaseReview`, every required release-review task has exactly
one matching approved attestation bound to the expected release-review packet
ref and review-task digest, at least one approved review bundle is present, and
no duplicate, unmatched, stale, invalid, or rejected review gaps remain. The CLI
import path fails fast unless each input is a valid release-review attestation
bundle. It publishes approved assignment refs plus the source model-class
coverage proof-summary digest for downstream manual action while binding
`releaseGateRef` to the exact approved assignment-ref set, consumed
release-review bundle refs/digests, packet refs, approved review-task digest
summaries, and the gate's embedded release-plan source summary. The writer and
runtime handoff steps source-check that embedded release-plan summary and
review-bundle provenance against the concrete release plan, including full
assignment refs, review-queue digest, packet ref, review-task digest summary,
and proof-summary digest, so public gates cannot silently become a shortened or
restamped downstream root of truth while preserving
`runtimeConfigurationApplied: false`, `aiConfigMutationsWritten: false`, and
`releaseApprovalAppliesConfig: false`.
Current active slice adds private runtime resolver packet/import governance:
`eval/run_level2.sh runtime-resolver-packet` consumes the release plan, approved
release gate, and exact release-review attestation bundles, then writes
`lotti.evalUseCaseRuntimeResolverPacket` as a private resolver work order. Each
pending binding template is bound to the release-plan digest, release-gate
digest/ref, approved assignment-ref set, model-class coverage proof-summary
digest, public assignment dimensions, production agent-kind mapping, and the
required effective runtime digest fields. Packet build and handoff validation
run source-aware release-gate validation against the concrete release plan and
review attestation bundles, reject approved gate JSON that was restamped or
deserialized without replaying those review sources, reject source-summary drift
between required bindings, templates, the release plan, and the release gate,
including review-bundle summary drift, proof-summary drift, and release gates
whose source assignment-ref digest no longer matches the release plan's full
runtime assignment set, and require every template to match a required binding.
`eval/run_level2.sh observe-runtime-state`
then consumes that resolver packet, a private selector-only
`lotti.evalRuntimeBindingLocatorPacket`, and a private
`lotti.evalPrivateRuntimeStateExport` containing production agent/template,
agent-link, and AI-config rows. The observer also receives the source release
plan, release gate, and release-review attestation bundles so a JSON-loaded
resolver packet is replayed and source-marked before private runtime rows can
become snapshot evidence. The observer refuses source drift between the release
plan, release gate, resolver packet, and locator packet; rejects locator/proof
fields from the runtime-state export; fails missing locator targets closed; and
writes the canonical private
`lotti.evalUseCaseRuntimeResolverSnapshot`. `eval/run_level2.sh
import-runtime-resolver` remains the manual attestation path: it consumes
completed resolver bindings and writes the canonical private
`lotti.evalUseCaseRuntimeResolverSnapshot`. The importer also consumes the
source release plan, release gate, release-review attestation bundles, and
resolver packet, then derives the observation source from that replayed packet
instead of trusting packet metadata supplied by the binding input. Import
rejects missing, duplicate, unapproved, pending, stale-source, mismatched
public-dimension, and wrong production-kind rows, allows private runtime ids
only inside the snapshot sidecar, and canonicalizes `resolverBindingDigest`
from the completed effective runtime digests rather than trusting
caller-supplied digest text. The private snapshot
now carries a `runtimeObservationSource` block before it crosses the
private/public boundary: manual imports record
`manualCompletedBindingImport` plus a canonical resolver-packet digest, direct
in-process observations record `directRuntimeObservation`, and private runtime
state observations record `privateRuntimeStateLocator` plus the exact
resolver-packet and locator-packet digests. `runtimeResolverSnapshotRef` binds
that observation-source digest along with `capturedAt`, source digests,
summary, privacy/limitations, and binding rows, while each
`resolverBindingDigest` binds the assignment dimensions, coverage/work-order
source refs, runtime target, expected and observed effective runtime digests,
resolution status, and shadowing flag.
`eval/run_level2.sh runtime-locator-packet` closes the private observation
handoff by converting a simple private locator-row JSON file into the full
source-bound `lotti.evalRuntimeBindingLocatorPacket`; the generated resolver
packet now recommends both this mode and `observe-runtime-state` alongside the
manual `import-runtime-resolver` path. The writer replays the JSON-loaded
resolver packet against the release plan, release gate, and release-review
attestation bundles before minting the locator packet, so a forged but
contract-valid resolver packet cannot create a locator source root. Locator
packets now also carry a `sourceResolverPacket.requiredAssignmentRefsDigest`
over their private required-ref list, and the observer compares the digest and
required refs back to the resolver packet before resolving runtime rows.
Current active slice adds read-only post-apply runtime verification:
`eval/run_level2.sh runtime-verify` consumes the source
`lotti.evalUseCaseTuningReleasePlan`, the approved
`lotti.evalUseCaseTuningReleaseGate`, and a private
`lotti.evalUseCaseRuntimeResolverSnapshot`, then writes a public
`lotti.evalUseCaseRuntimeVerification`. The verifier binds to the release-plan
digest, release-gate digest/ref, approved assignment-ref set, and model-class
coverage proof-summary digest. `runtimeVerificationRef` also binds status,
summary counts, verified refs, issues, public expected-assignment rows, and
observed binding rows plus the resolver snapshot ref and digest. Validation
recomputes assignment issues, summary counts, verified refs, and status from
the public expected/observed rows; source-aware validation rechecks the
concrete release plan, release gate, and resolver snapshot, including the
snapshot observation-source digest and the source-verified runtime resolver
packet, so a restamped artifact cannot relabel not-applied or drifted runtime
evidence as verified. Artifact-only resolver packet JSON replay is rejected
even when the public packet contract and digest fields are self-consistent.
The writer accepts serialized resolver packets only after replaying them
against the source release plan, release gate, and release-review bundles from
`EVAL_USE_CASE_RUNTIME_VERIFY_RELEASE_REVIEW_ATTESTATIONS`, which marks the
loaded packet inside the current process without relaxing artifact-only replay
checks. Every JSON-loaded resolver snapshot is then replayed from source
evidence before it can be trusted: completed-binding snapshots require
`EVAL_USE_CASE_RUNTIME_VERIFY_RESOLVER_INPUTS`, direct observations require
`EVAL_USE_CASE_RUNTIME_VERIFY_DIRECT_OBSERVATIONS` containing
`lotti.evalUseCaseRuntimeDirectObservationSource` artifacts, and private
runtime-state snapshots require `EVAL_USE_CASE_RUNTIME_VERIFY_STATE_INPUTS` and
the matching locator packet. Direct-observation sources bind observed completed
bindings to the source release plan, release gate, source-verified resolver
packet digest, observation source digest, observation time, and
privacy/limitation contract; extra fields or source drift fail closed. Manual
completed-binding inputs cannot be used to restamp provenance as direct
observation. The verifier requires each approved assignment to resolve
exactly once; maps public eval agent kinds to the production `task_agent` /
`day_agent` vocabulary; and compares effective
resolved profile, provider/model binding, thinking-model binding,
prompt-variant, and active prompt-directive digests. The private resolver
snapshot may carry production runtime ids, but the public artifact reduces them
to opaque resolver/runtime digests and rejects leaked runtime ids, profile
names, provider ids, base URLs, API keys, raw prompt/directive text, private
paths, env values, and mutation commands. The harness still performs no runtime
configuration writes and no `AiConfig` mutations. Rewritten release-gate
assignment source digests fail closed instead of becoming the downstream root of
truth.
Current active slice adds the runtime rollout feedback ledger:
`eval/run_level2.sh runtime-ledger` consumes one or more public
`lotti.evalUseCaseRuntimeVerification` artifacts, the concrete
`lotti.evalUseCaseRuntimeResolverSnapshot` artifacts named by
`EVAL_USE_CASE_RUNTIME_LEDGER_RESOLVER_SNAPSHOTS`, the matching resolver
packets for every snapshot, source release-review bundles, plus the source
release plan and release gate, then writes
`lotti.evalUseCaseRuntimeRolloutLedger`. The writer replays each JSON-loaded
resolver packet against the source release plan/gate/review bundles before
building the ledger, so serialized handoffs do not bypass the process-local
source marker. It then replays every resolver snapshot from its completed
binding source (`EVAL_USE_CASE_RUNTIME_LEDGER_RESOLVER_INPUTS`), direct
observation source (`EVAL_USE_CASE_RUNTIME_LEDGER_DIRECT_OBSERVATIONS`), or
private runtime-state source (`EVAL_USE_CASE_RUNTIME_LEDGER_STATE_INPUTS`)
before marking that snapshot trusted. Private runtime-state locator snapshots
also require their matching locator packets. The
ledger classifies each approved assignment as `runtimeVerified`, `notApplied`,
`drift`, or `invalid`; fails closed on stale release-plan/gate/proof-summary
digests, release-gate assignment source-digest drift, missing assignment
evidence, duplicate verification artifacts, duplicate assignment evidence,
missing resolver snapshot artifacts, unused resolver snapshot artifacts, and
verification/snapshot source drift; source-aware validates each verification
against its concrete resolver snapshot; compares each verification's expected
assignment rows back to the approved release-plan assignment subject; requires
each assignment to cite an actual runtime verification source; requires each
verification source to cite an actual resolver snapshot source; and
contract-checks non-verified assignment blockers plus top-level blocker
flattening. It keeps only source refs, digests, public assignment dimensions,
blocker codes, and next actions. Its public `rolloutLedgerRef` binds source
summaries, previous-ledger provenance, runtime verification sources, resolver
snapshot sources, summary counts, assignment rows, blocker rows, and final
status so exported ledgers cannot silently relabel blocked assignments as
verified or rewrite ledger-chain history. Runtime ledgers consumed by
`release-plan` must be source-verified by the runtime-ledger builder/source
assertion in the current harness process; artifact-only JSON replay is recorded
as `sourceArtifactVerified: false`, invalidates the release plan, and cannot
carry previous assignments forward as `unchanged`. `eval/run_level2.sh
release-plan` can consume prior rollout ledgers with
`EVAL_USE_CASE_RUNTIME_ROLLOUT_LEDGERS` when a previous release plan is
supplied; the writer now replays each serialized runtime ledger against the
matching release gate, release-review bundle, runtime verification, resolver
snapshot, resolver packet, locator packet, and snapshot source-input artifacts
including completed-binding inputs, direct-observation sources, or private
runtime-state exports before marking the ledger source-verified in-process.
Runtime ledger chains are
also replayed: when a ledger cites `sourcePreviousLedger`, the release-plan
writer requires the cited previous runtime ledger artifact through
`EVAL_USE_CASE_RELEASE_RUNTIME_PREVIOUS_ROLLOUT_LEDGERS` and recursively
source-marks it before trusting the newer ledger. This lets unchanged assignment
refs with
previous `notApplied`, `drift`, or `invalid` runtime evidence become
`revalidateRequired` continuity blockers instead of being silently carried
forward, while incomplete source handoffs still fail closed.
Runtime and use-case governance artifact writer tests now use a shared JSON
writer that refuses existing files unless the matching overwrite env var is set,
rejects symlink output paths, omits concrete local paths from error messages,
writes to a same-directory temp file, and then renames into place. The Level 2
shell banner reports configured file inputs and outputs as set while omitting
concrete local paths.
Current active slice adds a private read-only runtime-state resolver adapter:
`lotti.evalRuntimeBindingLocatorPacket` is the non-exported bridge from
approved public `assignmentRef`s to local runtime selectors such as `agentId`,
`taskId`, primary `templateId`, or active template-version id. Locator packets
are selector-only: they cannot carry expected/observed digests,
`resolutionStatus`, or shadowing claims, so they cannot self-certify runtime
verification. They are source-bound to the resolver-packet digest, release-plan
digest, release-gate ref/digest, and approved assignment-ref set, and validation
requires exactly one locator per required assignment. `EvalUseCaseRuntimeStateResolver`
accepts those locators plus production `AgentIdentityEntity`, `AgentLink`,
`AgentTemplateEntity`, active template-version, and `AiConfig` rows, rejects
agent/task/template/version selector conflicts against primary links and active
versions, mirrors `ProfileResolver` precedence (`agent.config.profileId`,
version profile, template profile, then legacy model fallback), and emits
completed resolver bindings for the existing private snapshot importer. It
hashes sanitized profile/provider/model/directive observations and never
serializes provider base URLs, API keys, raw directives, raw prompt text,
private paths, or local selectors in public reports.
Current active slice adds a machine-readable scenario-catalog governance
preflight artifact: `EVAL_CATALOG_PREFLIGHT_REPORT=<json>
eval/run_level2.sh catalog` writes `kind:
lotti.evalScenarioCatalogPreflight` before the existing text readiness gate.
The artifact is built from `EvalTuningReadiness.assessScenarioCatalog`, not a
parallel policy implementation, and records policy/source/profile digests,
aggregate coverage/adversarial/holdout/review counts, structured blocker
codes, explicit anti-claims for traces/verdicts/provider provenance/model
performance/calibration/promotion, and a static next-experiment plan. Its
contract rejects scenario-id fields and protected-id placeholders recursively,
omits `EVAL_SCENARIO_IDS`, represents selected subsets only as counts, and
guards in-repo outputs for external/protected catalogs unless
`LOTTI_EVAL_PROTECTED_TRACE_ACK=1` is set.
Known limitation: the current cascade live runner is still a sidecar smoke
entrypoint rather than part of the main `EvalMatrixRunner` run path, but its
trace topology is now manifest-bound and verified fail-closed.
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
must match it and they are not assertion-gated by themselves; when the manifest
already records promotion evidence, report mode fails closed until the matching
plan is supplied.
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
  eval_scenario_catalog_preflight.dart # machine-readable catalog governance artifact contract
  eval_tuning_report_contract.dart # machine-readable tuning-report JSON contract
  eval_tuning_evidence_intake_plan.dart # privacy-safe calibration/holdout/review intake plan
  eval_tuning_portfolio.dart # multi-run model/prompt tuning portfolio contract
  eval_use_case_adversarial_review.dart # review packet/import contract for use-case campaigns
  eval_use_case_experiment_plan.dart # bounded privacy-safe experiment batches from a use-case matrix
  eval_use_case_model_class_execution_evidence.dart # private-run extractor to sanitized model-class evidence rows
  eval_use_case_model_class_execution_coverage.dart # enum model-class execution coverage ledger
  eval_use_case_next_run_work_order.dart # public-env next-run batch handoff from an experiment plan
  eval_use_case_tuning_campaign.dart # use-case experiment follow-up campaign progress contract
  eval_use_case_tuning_decision_ledger.dart # governed use-case acceptance decision contract
  eval_use_case_tuning_matrix.dart # use-case/model-class/prompt tuning matrix artifact contract
  eval_use_case_runtime_resolver_snapshot.dart # private resolver packet/import for post-apply verification
  eval_use_case_runtime_state_resolver.dart # private read-only runtime locator/observer adapter
  eval_use_case_runtime_verification.dart # post-apply runtime resolver snapshot verification contract
  eval_use_case_runtime_rollout_ledger.dart # public runtime verification feedback ledger
  eval_use_case_tuning_release_gate.dart # final non-mutating release approval gate
  eval_use_case_tuning_release_plan.dart # dry-run runtime assignment/release review manifest
  eval_use_case_tuning_release_review.dart # release-plan review packet/import attestation contract
  eval_use_case_tuning_roadmap.dart # cross-ledger use-case tuning roadmap contract
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
  eval_scenario_catalog_preflight_test.dart # catalog preflight JSON contract/privacy tests
  eval_tuning_report_contract_test.dart # tuning report JSON contract tests
  eval_tuning_evidence_intake_plan_test.dart # evidence-intake task/privacy/writer tests
  eval_tuning_portfolio_test.dart # multi-run portfolio status/privacy/writer tests
  eval_use_case_adversarial_review_test.dart # review packet/import contract tests
  eval_use_case_experiment_plan_test.dart # experiment-plan status/privacy/writer tests
  eval_use_case_model_class_execution_evidence_test.dart # extractor/privacy/writer tests
  eval_use_case_model_class_execution_coverage_test.dart # model-class coverage/privacy/writer tests
  eval_use_case_next_run_work_order_test.dart # next-run work-order privacy/writer tests
  eval_use_case_tuning_campaign_test.dart # campaign progress matching/privacy/writer tests
  eval_use_case_tuning_decision_ledger_test.dart # governed decision coverage-proof/privacy/writer tests
  eval_use_case_tuning_matrix_test.dart # use-case matrix status/privacy/runner writer tests
  eval_use_case_runtime_resolver_snapshot_test.dart # resolver packet/import/privacy/writer tests
  eval_use_case_runtime_state_resolver_test.dart # runtime locator/profile precedence/privacy tests
  eval_use_case_runtime_verification_test.dart # post-apply runtime verification/privacy/writer tests
  eval_use_case_runtime_rollout_ledger_test.dart # runtime rollout ledger/privacy/writer tests
  eval_use_case_tuning_release_gate_test.dart # final release gate contract/writer tests
  eval_use_case_tuning_release_plan_test.dart # dry-run release assignment/privacy/writer tests
  eval_use_case_tuning_release_review_test.dart # release review packet/import/writer tests
  eval_use_case_tuning_roadmap_test.dart # cross-ledger roadmap status/privacy/writer tests
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
  consolidation while filtering stale resolved/expired parent rows whose
  embedded items still claim `pending` without a decision, and maps persisted
  `AgentMessageKind.toolResult` rows into
  `AgentRunOutput.toolResults` so rejected tool attempts remain visible. The
  regression tests deliberately include a
  rejected `update_report` call, a batch deferred tool that explodes into
  persisted per-item proposals, and a merged-pending-set case where raw tool
  args attempt a duplicate but final durable state has one consolidated open
  copy and one retired/retracted row. They also seed a resolved/rejected prior
  proposal and prove a later valid-looking duplicate raw tool call does not
  create a fresh pending proposal, a same-wake retract-and-repropose churn case
  that must leave the original open suggestion untouched, plus a resolved parent
  row whose embedded pending item must stay out of final eval proposal records.
  The bench also maps scenario tasks and checklist items into real
  `Task`/`ChecklistItem` entities, so production
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
- `ExpectedProposalState { changeSetId?, toolName?, targetId?, status?, changeSetStatus?, argsContain, humanSummaryContains }`
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
- `EvalRunManifest { schemaVersion=2, runId, traceSchemaVersion, targetName, targetKind, createdAt, command, scenarioSetDigest, profileSetDigest, profileBindingSetDigest, agentDirectiveVariantSetDigest, promptDigest, toolSchemaDigest, codeRevision, gitDirty, dirtyDiffDigest?, envPresence, scenarioCatalogEvidence?, promotionPlanEvidence?, pairwiseReadinessPlanEvidence?, tuningReadinessContractEvidence?, tuningReadinessPolicyEvidence?, agentDirectiveVariants, manifestDigest? }`
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
  agent/capability/split corpus coverage, required primary-capability x split
  cells, plus explicit adversarial coverage by agent/capability, required
  adversarial failure-mode tags per required agent kind, and protected
  production-replay holdout depth by required agent kind and required primary
  capability, and completed digest-current scenario review metadata before
  adversarial, synthetic, production-replay holdout, or protected scenarios can
  count as tuning-ready evidence. Synthetic and protected evidence also
  requires a review `sourceDigest`, and protected holdout source digests must be
  unique. The default stress tags are
  `ambiguous-reference`, `scope-boundary`, `stale-state`, and `tool-recovery`
  from `kDefaultAdversarialStressTags`; catalog validation and run verification
  reject adversarial scenarios that lack one of those canonical stress tags.
  Readiness counts only scenarios whose canonical `isAdversarial` flag is true,
  and protected holdout counts use unique manifest-bound production-replay IDs
  with unique source digests distributed across required agent kinds and
  required primary capabilities.
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
  model-class tuning.
  Tuning-readiness outcome gates also inspect actual judge verdict outcomes:
  all judge verdicts must pass under the default model-class policy, aggregate
  and per primary-capability x agent-kind x model-class x prompt-variant slices
  must satisfy pass-rate lower bounds, score floors, and measured
  token/weighted-cost budget ratios, and the report renders outcome coverage,
  pass lower bound, mean goal/quality/efficiency diagnostics, and budget
  evidence.
  The default model-class policy also rejects unblinded
  judge verdicts where exact provider/model identity was visible during grading.
  `eval/run_level2.sh blind` now creates a separate model-identity-redacted
  review packet, and `eval/run_level2.sh import-blind` validates the retained
  private key, judge manifest digest, review payload digests, raw trace digests,
  and blinded verdict wrappers before writing raw digest-bound sibling verdict
  files with `blindedImport` audit provenance.
  The rendered readiness block now includes the
  evidence counts behind those gates: corpus by agent/split, primary capability
  count, primary capability x split cells, model-class profile coverage, trial
  range, adversarial totals and tags, adversarial stress-tag x agent-kind cells,
  production-replay holdout depth, protected holdout distribution by agent and
  primary capability, and duplicate protected evidence ids, plus
  required/completed/missing/incomplete/stale scenario review counts.
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
