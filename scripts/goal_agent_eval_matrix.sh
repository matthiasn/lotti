#!/usr/bin/env bash
# Runs the goal-agent inference eval across a model matrix, in parallel, and
# merges the per-process JSON artifacts into one markdown report.
#
# Each (model, sample) is its own `flutter test` process: the capture bench
# registers into GetIt, which is a global, so two runs cannot share a Dart
# VM. The compile is cached after the warm-up, so processes overlap on
# inference latency, which is where the wall-clock actually goes.
#
# Usage:
#   scripts/goal_agent_eval_matrix.sh [samples] [max_parallel]
#
# Reads credentials from the environment:
#   MELIOUS_API_KEY (or GOAL_AGENT_EVAL_API_KEY)
#
# Override the model list with GOAL_AGENT_EVAL_MODELS (space separated).
# Cost figures in the report are observations for monitoring — never caps.
set -uo pipefail

SAMPLES="${1:-3}"
MAX_PARALLEL="${2:-4}"
case "$SAMPLES" in (*[!0-9]*|0|'') echo "samples must be a positive integer, got '$SAMPLES'" >&2; exit 2;; esac
case "$MAX_PARALLEL" in (*[!0-9]*|0|'') echo "max_parallel must be a positive integer, got '$MAX_PARALLEL'" >&2; exit 2;; esac
TEST_PATH="test/features/agents/eval/goal/goal_agent_eval_live_test.dart"
# Per-run directory: merging must never sweep up a previous run's
# artifacts, or the report silently mixes model lists and cost totals.
RUN_STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="eval_artifacts/goal_agent_${RUN_STAMP}"
LOG_DIR="$OUT_DIR/logs"

MODELS="${GOAL_AGENT_EVAL_MODELS:-glm-5.2 kimi-k3 qwen3.5-122b-a10b qwen3.6-27b}"

if [[ -z "${GOAL_AGENT_EVAL_API_KEY:-${MELIOUS_API_KEY:-}}" ]]; then
  echo "Set MELIOUS_API_KEY (or GOAL_AGENT_EVAL_API_KEY)." >&2
  exit 2
fi

mkdir -p "$LOG_DIR"

# Warm the build once. Otherwise every process in the first wave compiles the
# same test concurrently, which is slower than compiling it once.
echo "Warming the test build..."
LOTTI_GOAL_AGENT_EVAL_LIVE='' fvm flutter test "$TEST_PATH" >/dev/null 2>&1

run_one() {
  local model="$1" sample="$2"
  local label="s${sample}"
  local log="$LOG_DIR/goal_agent_${model}_${label}.log"
  LOTTI_GOAL_AGENT_EVAL_LIVE=1 \
  GOAL_AGENT_EVAL_MODELS="$model" \
  GOAL_AGENT_EVAL_JSON="$OUT_DIR/goal_agent_${model}_${label}.json" \
  GOAL_AGENT_EVAL_MARKDOWN="$OUT_DIR/goal_agent_${model}_${label}.md" \
  timeout 2400 fvm flutter test "$TEST_PATH" --tags eval-live >"$log" 2>&1
  if grep -q "All tests passed" "$log"; then
    echo "PASS $model $label"
  else
    local why
    why=$(grep -oE '(noOpViolated|forbiddenToolCall|forbiddenToolArguments|argumentMismatch|missingExpectedToolCall|inferenceError|HTTP [0-9]+)[^.]{0,120}' "$log" | head -1)
    echo "FAIL $model $label :: ${why:-see $log}"
    return 1
  fi
}

FAILED_JOBS=0

echo "Running $SAMPLES sample(s) per model, up to $MAX_PARALLEL at a time."
start=$(date +%s)
for model in $MODELS; do
  for sample in $(seq 1 "$SAMPLES"); do
    while (( $(jobs -rp | wc -l) >= MAX_PARALLEL )); do wait -n || FAILED_JOBS=$((FAILED_JOBS + 1)); done
    run_one "$model" "$sample" &
  done
done
while (( $(jobs -rp | wc -l) > 0 )); do
  wait -n || FAILED_JOBS=$((FAILED_JOBS + 1))
done
echo "Matrix finished in $(( $(date +%s) - start ))s; $FAILED_JOBS job(s) failed."

echo "Merging artifacts..."
shopt -s nullglob
artifacts=("$OUT_DIR"/goal_agent_*.json)
if (( ${#artifacts[@]} == 0 )); then
  echo "No artifacts in $OUT_DIR — every run failed; see $LOG_DIR." >&2
  exit 1
fi
if ! fvm dart run tool/agent_eval_report.dart \
  "${artifacts[@]}" > "$OUT_DIR/goal_agent_merged_report.md"; then
  echo "Merge failed." >&2
  exit 1
fi
echo "Merged report: $OUT_DIR/goal_agent_merged_report.md"
(( FAILED_JOBS == 0 )) || exit 1
