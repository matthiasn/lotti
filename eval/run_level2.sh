#!/usr/bin/env bash
#
# Level 2 eval orchestration for the Lotti task & planning agents.
#
# Pipeline:
#   1. Run the live eval entrypoint (flutter test, tagged 'eval-live'), which
#      executes each scenario against each model profile (local Ollama +
#      frontier) and writes one <scenario>__<profile>.trace.json per run under
#      eval/runs/<runId>/.
#   2. Hand the run directory to Claude Code to grade (see eval/grade_run.md),
#      producing one .verdict.json next to each trace.
#   3. Aggregate traces + verdicts into a summary table (EvalReporter).
#
# Live model calls are gated behind LOTTI_EVAL_LIVE=1 and provider credentials so
# this NEVER runs in default CI. See docs/adr/0029-agent-evaluation-harness.md.
#
# Usage:
#   LOTTI_EVAL_LIVE=1 GEMINI_API_KEY=... OLLAMA_BASE_URL=http://localhost:11434 \
#     eval/run_level2.sh [runId]
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

RUN_ID="${1:-$(date +%Y%m%d-%H%M%S)}"
RUN_DIR="eval/runs/${RUN_ID}"
mkdir -p "$RUN_DIR"

echo "==> Level 2 eval run: ${RUN_ID}"
echo "    output: ${RUN_DIR}"

if [[ "${LOTTI_EVAL_LIVE:-0}" != "1" ]]; then
  echo "!!! LOTTI_EVAL_LIVE is not 1 — refusing to make live model calls." >&2
  echo "    Set LOTTI_EVAL_LIVE=1 plus provider credentials to run Level 2." >&2
  exit 2
fi

# 1. Produce traces. The live runner reads EVAL_RUN to know where to write.
#    (Phase 2: test/eval/scenarios/live_runner_test.dart drives LiveEvalTarget.)
echo "==> Producing traces..."
fvm flutter test test/eval/scenarios --tags eval-live \
  --dart-define=EVAL_RUN="${RUN_ID}"

# 2. Grade with Claude Code (judge). Human review encouraged after.
echo "==> Grade the traces with Claude Code:"
echo "      claude -p \"Follow eval/grade_run.md to grade ${RUN_DIR}\""
echo "    (run this step interactively, then re-run with the reporter below)"

# 3. Report — only meaningful once verdicts exist.
if compgen -G "${RUN_DIR}/*.verdict.json" > /dev/null; then
  echo "==> Aggregating report..."
  fvm flutter test test/eval/scenarios/report_test.dart \
    --dart-define=EVAL_RUN="${RUN_ID}"
else
  echo "==> No verdicts yet — grade with Claude Code, then re-run for the report."
fi
