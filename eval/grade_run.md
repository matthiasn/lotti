# Grade Run — Claude Code Judge Runbook

This is the **judge script run from Claude Code** (the "scripts called from
Claude Code and evaluated" step). It turns a directory of trace JSON files into
verdict JSON files. It does not touch the app or call any model API directly —
*you* (Claude Code) are the judge.

## Invocation

From the repo root, point Claude Code at a run directory:

```
claude -p "Follow eval/grade_run.md to grade eval/runs/<runId>"
```

…or, interactively, just say: *"Grade the latest eval run."*

Protected production-replay runs may use `EVAL_RUNS_ROOT` outside the repo.
Point Claude Code at that explicit directory instead of `eval/runs/<runId>`.
Trace JSON contains the raw scenario payload and model output needed for
judging; do not copy protected trace files into tickets, docs, prompts, or
committed fixtures.

For model-identity-blinded review, export a separate judge packet first:

```
EVAL_BLINDED_EXPORT=/private/tmp/lotti-blind-review \
  eval/run_level2.sh blind <runId>
```

Give Claude Code only `/private/tmp/lotti-blind-review/judge`, not
`private/key.json`. The private key maps opaque blinded trace ids back to raw
trace/verdict filenames, raw trace digests, and raw manifest fingerprints; it
is operator audit material, not judge input.

## Inputs

- `<runsRoot>/<runId>/*.trace.json` — one `EvalTrace` per
  `(scenario, profile, trialIndex)`, or per explicit `cascadeWake` inside that
  trial for cascade sidecar runs, written by the Level 2 runner.
- For blinded review only:
  `<exportDir>/judge/traces/*.blinded-trace.json` plus
  `<exportDir>/judge/manifest.json`. These hide exact profile/model/provider
  identities and raw trace filenames/digests, while preserving a review payload
  digest and coarse profile context for the efficiency rubric.
- `eval/prompts/judge_system.md` — the judge persona + output contract.
- `eval/prompts/rubric_task_agent.md` / `rubric_planning_agent.md` — anchors.

## Procedure

1. List `<runsRoot>/<runId>/*.trace.json`. If `<runId>` is omitted, use the
   latest timestamp-named subdirectory of the configured runs root.
2. Read `eval/prompts/judge_system.md` once. It defines the scoring and the exact
   output JSON contract.
3. For **each** trace file:
   1. Read the trace JSON.
   2. Compute the trace digest as `sha256:<hex>` from the exact `.trace.json`
      bytes, for example:

      ```
      shasum -a 256 eval/runs/<runId>/<stem>.trace.json
      ```

   3. Read the rubric matching `scenario.agentKind`
      (`taskAgent` → `rubric_task_agent.md`, `planningAgent` →
      `rubric_planning_agent.md`).
   4. Evaluate the trace strictly against the system prompt + rubric. Cite
      specifics (tool names, block times, token counts) in `rationale`.
   5. Write the verdict to a sibling file with the same stem and the
      `.verdict.json` extension — e.g.
      `morning_capacity__local-ollama.trace.json` →
      `morning_capacity__local-ollama.verdict.json`. The file content is exactly
      the `JudgeVerdict` JSON object from the contract (no surrounding prose),
      including `schemaVersion: 1`, the computed `traceDigest`, and a `judge`
      block. Set `judge.promptDigest` to the trace's
      `provenance.promptDigest`. Set `judge.calibrationSetVersion` to the
      current human-labeled calibration set version; if no calibration set has
      been run yet, write `"uncalibrated"` explicitly.
   6. For blinded traces, write a sibling `*.blinded-verdict.json` wrapper
      instead of a raw `.verdict.json` file. Copy `blindedTraceId` and
      `reviewPayloadDigest` from the blinded trace packet, omit
      `verdict.traceDigest`, and set `judge.modelIdentityVisible: false`.
4. After all traces are graded, run the reporter to print the summary:

   ```
   eval/run_level2.sh report <runId>
   ```

   Omitting `<runId>` reports the latest timestamp-named run directory.
5. If a human-label calibration set exists, render judge/human agreement:

   ```
   EVAL_CALIBRATION=eval/calibration/judge_gold_v1.json eval/run_level2.sh calibrate <runId>
   ```

   Calibration labels are trace-keyed, digest-bound, and non-secret; see
   `eval/calibration/README.md`.

## Blinded Review Discipline

Raw run directories are not blinded: filenames and payloads expose profile
names, model ids, provider ids/types, endpoint evidence, prompt variant names,
and provider response metadata. A reviewer may set
`judge.modelIdentityVisible: false` only when they graded from the `blind`
mode's `judge/` packet and did not see the private key or raw run directory.

For blinded reviews, write one wrapper per blinded trace next to the blinded
trace file:

```json
{
  "schemaVersion": 1,
  "kind": "lotti.blindedTraceExport.verdict",
  "blindedTraceId": "blind-0001",
  "reviewPayloadDigest": "sha256:<copy from blinded trace>",
  "verdict": {
    "schemaVersion": 1,
    "judge": {
      "judgeName": "claude-code",
      "judgeModel": "<model shown by Claude Code for this grading run>",
      "promptDigest": "sha256:<copy reviewPayload.promptDigest>",
      "calibrationSetVersion": "<human calibration set version, or uncalibrated>",
      "profileVisible": true,
      "modelIdentityVisible": false
    },
    "goalAttainment": 4,
    "quality": 5,
    "efficiency": 3,
    "pass": true,
    "rationale": "One short paragraph citing the blinded trace id and specifics.",
    "issues": []
  }
}
```

Then import the completed wrappers back to raw digest-bound verdicts:

```
EVAL_BLINDED_IMPORT=/private/tmp/lotti-blind-review \
  eval/run_level2.sh import-blind <runId>
```

The importer validates `private/key.json`, the judge manifest digest, each
blinded trace's recomputed review payload digest, the raw trace digest, and the
wrapper provenance before writing raw sibling `.verdict.json` files with a
`blindedImport` audit block. It refuses to overwrite existing raw verdicts
unless `EVAL_BLINDED_IMPORT_OVERWRITE=1` is set.

## Optional Pairwise A/B Review

Use pairwise preference votes when the question is subjective free-text quality
rather than a hard fact like due date, priority, estimate, label assignment, or
planner block time. A pairwise vote compares two trace artifacts for the same
run, scenario, trial, optional cascade wake, agent kind, and primary capability,
with different profiles.

Each vote is an `EvalPairwisePreferenceVote` JSON object, not a `JudgeVerdict`.
It must bind both sides through `optionA` and `optionB` trace refs, including
`runId`, `scenarioId`, `profileName`, `agentKind`, `modelClass`,
`capabilityId`, `trialIndex`, optional `cascadeWake`, `traceDigest`,
`scenarioDigest`, and `profileDigest`. It also records `reviewerId`,
`reviewerKind`, optional `reviewerModel`, `promptDigest`,
`calibrationSetVersion`, `profileVisible`, `modelIdentityVisible`,
`peerVotesVisible`, `traceOrderRandomized`, `choice` (`optionA`, `optionB`, or
`tie`), `rationale`, and `issues`.

Write one vote per `<safeVoteId>.preference.json` file in the run directory.
The safe vote id must use only letters, digits, dot, underscore, or dash. The
ordinary verifier ignores these files; report mode reads them separately after
normal trace/verdict verification and prints a diagnostic-only A/B section.
Stale or orphaned trace bindings are rejected by the preference reader. Raw run
directories are not blinded because trace filenames and payloads include profile
names; for blinded review, use `eval/run_level2.sh blind` and keep the private
key away from reviewers.

Run multiple independent reviewers with profile/model identity and peer votes
hidden when possible. Randomize option order for each reviewer when the
review protocol requires it, and record that in `traceOrderRandomized`. The
pairwise reporter derives `optionAWins`, `optionBWins`, `tie`, `noConsensus`,
`incomplete`, or `invalid` from the configured minimum vote count and quorum
fraction after canonicalizing reversed option order; `preferredTrace` points at
the winning trace when there is a strict preference. These records are audit
evidence for A/B comparison; they do not feed promotion or tuning-readiness
gates unless a future pre-registered policy explicitly says so.

## Grading discipline

- Judge one trace at a time; do not let one scenario's quality bleed into
  another's score.
- A failed `level1Checks` entry for a correctness/safety invariant (hallucinated
  id, over-capacity plan, invalid status transition) forces `pass: false`.
- Be specific and skeptical. The point of the eval is to find real problems
  before users do, not to confirm the agent is fine.
- Keep verdicts reproducible: the verdict file plus the trace file are the audit
  record for that `(scenario, profile, trialIndex[, cascadeWake])` at that
  `runId`. The verdict must name the judge runner/model, prompt digest, judge
  calibration set version, and whether profile/model identity was visible.
- Keep exact provider/model identity hidden for blinded comparison exports when
  possible. If the judge saw exact model identity, set
  `judge.modelIdentityVisible: true`; calibration reports count those verdicts
  so model-class comparisons can treat them as diagnostic rather than blinded.
  The model-class tuning policy requires `judge.modelIdentityVisible: false`
  verdicts before a run can be tuning-ready. Set that flag to `false` only when
  you actually graded a blinded input that hid exact provider/model identity.
- Do not rewrite trace files after grading. The reporter verifies exact matrix
  coverage, rejects embedded/orphan/stale verdicts, recomputes Level 1 checks,
  validates the judge score/pass contract and judge provenance, and checks that
  every verdict's `traceDigest` still matches its sibling trace.
