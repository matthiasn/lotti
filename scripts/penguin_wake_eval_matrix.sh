#!/usr/bin/env bash
# Runs the penguin-wake task-agent eval across a model matrix, in parallel.
#
# Each (model, sample) is its own `flutter test` process: the harness registers
# into GetIt, which is a global, so two harnesses cannot share a Dart VM. The
# compile is cached after the first process, so the processes overlap on
# inference latency, which is where the wall-clock actually goes.
#
# Usage:
#   scripts/penguin_wake_eval_matrix.sh [samples] [max_parallel]
#
# Reads credentials from the environment:
#   PENGUIN_WAKE_EVAL_BASE_URL, PENGUIN_WAKE_EVAL_API_KEY
#
# Override the model list with PENGUIN_WAKE_EVAL_MODELS (space separated).
set -uo pipefail

SAMPLES="${1:-3}"
MAX_PARALLEL="${2:-4}"
TEST_PATH="test/features/ai/eval/penguin_wake_workflow_eval_live_test.dart"
OUT_DIR="eval_artifacts"
LOG_DIR="$OUT_DIR/logs"

MODELS="${PENGUIN_WAKE_EVAL_MODELS:-glm-5.2 kimi-k3 qwen3.5-397b-a17b qwen3.6-27b qwen3.6-35b-a3b deepseek-v4-flash-0731}"

if [[ -z "${PENGUIN_WAKE_EVAL_API_KEY:-}" ]]; then
  echo "PENGUIN_WAKE_EVAL_API_KEY is not set." >&2
  exit 2
fi

mkdir -p "$LOG_DIR"

# Warm the build once. Otherwise every process in the first wave compiles the
# same test concurrently, which is slower than compiling it once.
echo "Warming the test build..."
LOTTI_PENGUIN_WAKE_EVAL_LIVE= fvm flutter test "$TEST_PATH" >/dev/null 2>&1

run_one() {
  local model="$1" sample="$2"
  local label="s${sample}"
  local log="$LOG_DIR/${model}_${label}.log"
  LOTTI_PENGUIN_WAKE_EVAL_LIVE=1 \
  PENGUIN_WAKE_EVAL_MODEL="$model" \
  PENGUIN_WAKE_EVAL_RUN_LABEL="$label" \
  timeout 900 fvm flutter test "$TEST_PATH" >"$log" 2>&1
  if grep -q "All tests passed" "$log"; then
    echo "PASS $model $label"
  else
    # Surface the named trap rather than a bare failure.
    local why
    why=$(grep -oE '(UNSUPPORTED COMPLETION|NEGATION|RESTRAINT|CHURN|MISSED|HTTP [0-9]+)[^.]{0,120}' "$log" | head -1)
    echo "FAIL $model $label :: ${why:-see $log}"
  fi
}

echo "Running $SAMPLES sample(s) per model, up to $MAX_PARALLEL at a time."
start=$(date +%s)
for model in $MODELS; do
  for sample in $(seq 1 "$SAMPLES"); do
    while (( $(jobs -rp | wc -l) >= MAX_PARALLEL )); do wait -n; done
    run_one "$model" "$sample" &
  done
done
wait
echo "Wall clock: $(( $(date +%s) - start ))s"

echo
echo "===== SUMMARY ====="
for model in $MODELS; do
  pass=0; total=0; reasons=""
  for sample in $(seq 1 "$SAMPLES"); do
    log="$LOG_DIR/${model}_s${sample}.log"
    [[ -f "$log" ]] || continue
    total=$((total+1))
    if grep -q "All tests passed" "$log"; then
      pass=$((pass+1))
    else
      why=$(grep -oE '(UNSUPPORTED COMPLETION|NEGATION|RESTRAINT|CHURN|MISSED|HTTP [0-9]+)[^.]{0,90}' "$log" | head -1)
      reasons="$reasons\n      - ${why:-unknown, see $log}"
    fi
  done
  printf '%-26s %s/%s' "$model" "$pass" "$total"
  [[ -n "$reasons" ]] && printf '%b' "$reasons"
  printf '\n'
done
