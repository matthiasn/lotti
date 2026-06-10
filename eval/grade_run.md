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

## Inputs

- `<runsRoot>/<runId>/*.trace.json` — one `EvalTrace` per
  `(scenario, profile, trialIndex)`, or per explicit `cascadeWake` inside that
  trial for cascade sidecar runs, written by the Level 2 runner.
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
