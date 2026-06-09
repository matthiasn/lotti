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
#   eval/run_level2.sh run [runId]
#   eval/run_level2.sh grade [runId]
#   eval/run_level2.sh verify [runId]
#   eval/run_level2.sh report [runId]
#   eval/run_level2.sh all [runId]
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

RUNS_ROOT="eval/runs"

latest_run_id() {
  if [[ ! -d "$RUNS_ROOT" ]]; then
    echo "!!! No eval run directory exists under ${RUNS_ROOT}." >&2
    exit 6
  fi
  local latest
  latest="$(find "$RUNS_ROOT" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort | tail -n 1 || true)"
  if [[ -z "$latest" ]]; then
    echo "!!! No eval runs found under ${RUNS_ROOT}." >&2
    exit 6
  fi
  basename "$latest"
}

MODE="${1:-run}"
if [[ "$MODE" != "run" && "$MODE" != "grade" && "$MODE" != "verify" && "$MODE" != "report" && "$MODE" != "all" ]]; then
  RUN_ID="$MODE"
  MODE="run"
else
  case "$MODE" in
    run | all)
      RUN_ID="${2:-$(date +%Y%m%d-%H%M%S)}"
      ;;
    grade | verify | report)
      RUN_ID="${2:-$(latest_run_id)}"
      ;;
  esac
fi
RUN_DIR="${RUNS_ROOT}/${RUN_ID}"

echo "==> Level 2 eval run: ${RUN_ID}"
echo "    output: ${RUN_DIR}"

run_traces() {
  if [[ "${LOTTI_EVAL_LIVE:-0}" != "1" ]]; then
    echo "!!! LOTTI_EVAL_LIVE is not 1 — refusing to make live model calls." >&2
    echo "    Set LOTTI_EVAL_LIVE=1 plus provider credentials to run Level 2." >&2
    exit 2
  fi
  if [[ ! -f "test/eval/scenarios/live_runner_test.dart" ]]; then
    echo "!!! LiveEvalTarget runner is not implemented yet." >&2
    echo "    Expected test/eval/scenarios/live_runner_test.dart." >&2
    exit 3
  fi
  if [[ -e "$RUN_DIR" ]] && compgen -G "${RUN_DIR}/*" > /dev/null; then
    echo "!!! Refusing to write into non-empty run directory: ${RUN_DIR}" >&2
    exit 4
  fi
  mkdir -p "$RUN_DIR"
  echo "==> Producing traces..."
  fvm flutter test test/eval/scenarios/live_runner_test.dart --tags eval-live \
    --dart-define=EVAL_RUN="${RUN_ID}"
}

grade_prompt() {
  if [[ ! -d "$RUN_DIR" ]]; then
    echo "!!! Missing run directory: ${RUN_DIR}" >&2
    exit 5
  fi
  echo "==> Grade the traces with Claude Code:"
  echo "      claude -p \"Follow eval/grade_run.md to grade ${RUN_DIR}\""
}

verify_run() {
  echo "==> Verifying trace/verdict bindings..."
  fvm flutter test test/eval/scenarios/report_test.dart \
    --plain-name "verifies complete trace/verdict matrix for an eval run" \
    --dart-define=EVAL_RUN="${RUN_ID}"
}

report_run() {
  echo "==> Aggregating report..."
  fvm flutter test test/eval/scenarios/report_test.dart \
    --plain-name "renders eval run summary" \
    --dart-define=EVAL_RUN="${RUN_ID}"
}

case "$MODE" in
  run)
    run_traces
    grade_prompt
    ;;
  grade)
    grade_prompt
    ;;
  verify)
    verify_run
    ;;
  report)
    verify_run
    report_run
    ;;
  all)
    run_traces
    grade_prompt
    echo "==> After grading, run:"
    echo "      eval/run_level2.sh report ${RUN_ID}"
    ;;
esac
