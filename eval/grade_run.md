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

## Inputs

- `eval/runs/<runId>/*.trace.json` — one `EvalTrace` per
  `(scenario, profile, trialIndex)`, written by the Level 2 runner.
- `eval/prompts/judge_system.md` — the judge persona + output contract.
- `eval/prompts/rubric_task_agent.md` / `rubric_planning_agent.md` — anchors.

## Procedure

1. List `eval/runs/<runId>/*.trace.json`. If `<runId>` is omitted, use the
   latest timestamp-named subdirectory of `eval/runs/`.
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
      including the computed `traceDigest`.
4. After all traces are graded, run the reporter to print the summary:

   ```
   eval/run_level2.sh report <runId>
   ```

   Omitting `<runId>` reports the latest timestamp-named run directory.

## Grading discipline

- Judge one trace at a time; do not let one scenario's quality bleed into
  another's score.
- A failed `level1Checks` entry for a correctness/safety invariant (hallucinated
  id, over-capacity plan, invalid status transition) forces `pass: false`.
- Be specific and skeptical. The point of the eval is to find real problems
  before users do, not to confirm the agent is fine.
- Keep verdicts reproducible: the verdict file plus the trace file are the audit
  record for that `(scenario, profile, trialIndex)` at that `runId`.
- Do not rewrite trace files after grading. The reporter verifies exact matrix
  coverage, rejects embedded/orphan/stale verdicts, recomputes Level 1 checks,
  validates the judge score/pass contract, and checks that every verdict's
  `traceDigest` still matches its sibling trace.
