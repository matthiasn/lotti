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
# Runs every scenario in PENGUIN_WAKE_EVAL_SCENARIOS for every model, so the
# matrix covers the restraint cases and not only the live test's default.
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

# Every scenario, not just the live test's default.
#
# The default is `requalification`, and this script never set the variable, so
# the whole matrix has only ever run that one case. It is also the easy one:
# both models measured on 2026-08-18 passed it and failed `noOp` and
# `pendingProposal`, so the matrix reported 6/6 for a suite that was really
# 2/6. A restraint scenario that never runs cannot catch churn, which is the
# failure these scenarios exist for.
#
# Derived from the enum, not listed here. A hand-kept copy went stale within
# the hour: `materialChange` was added and the first matrix run after it
# silently measured three scenarios while reporting totals out of 9, which is
# the same failure this script was just fixed for at the scenario level.
SCENARIO_NAMES=$(
  sed -n '/^enum PenguinWakeScenarioId {/,/^}/p' \
    test/features/ai/eval/support/penguin_wake_scenarios.dart |
    grep -oE '^  [a-z][a-zA-Z]*,' | tr -d ' ,'
)
SCENARIOS="${PENGUIN_WAKE_EVAL_SCENARIOS:-$SCENARIO_NAMES}"
# Whitespace of any kind, not just literal spaces: a tab-only or newline-only
# override expands to zero scenarios, and the script would otherwise finish
# cleanly having evaluated nothing.
if [[ -z "${SCENARIOS//[[:space:]]/}" ]]; then
  echo "Could not derive the scenario list from PenguinWakeScenarioId." >&2
  exit 2
fi

if [[ -z "${PENGUIN_WAKE_EVAL_API_KEY:-}" ]]; then
  echo "PENGUIN_WAKE_EVAL_API_KEY is not set." >&2
  exit 2
fi

mkdir -p "$LOG_DIR"

# Warm the build once. Otherwise every process in the first wave compiles the
# same test concurrently, which is slower than compiling it once.
echo "Warming the test build..."
LOTTI_PENGUIN_WAKE_EVAL_LIVE= fvm flutter test "$TEST_PATH" >/dev/null 2>&1

# The named traps the scenarios assert, so a failure line says which one bit
# rather than "a test failed".
#
# Read out of the live test rather than listed here. A hand-kept copy has now
# drifted twice — it was missing INVENTED WORK and DUPLICATE PROPOSAL, then
# REPUBLISHED and FABRICATION — and each time the symptom was a real failure
# printing "unknown, see log", which is worse than no diagnosis because it
# reads like a harness problem. Deriving it means a trap added to the test
# cannot go missing here.
TRAP_NAMES=$(grep -oE "'[A-Z][A-Z ]{4,}:" "$TEST_PATH" | tr -d "':" | sort -u | paste -sd '|')
# Provider failures are not model behaviour, and reading "unknown, see log"
# for a five-minute timeout sends the reader hunting for a defect that is not
# there.
TRAPS="(${TRAP_NAMES:-INVENTED WORK|DUPLICATE PROPOSAL}|HTTP [0-9]+|[A-Za-z]*InferenceException|TimeoutException)"

run_one() {
  local model="$1" scenario="$2" sample="$3"
  local label="${scenario}_s${sample}"
  local log="$LOG_DIR/${model}_${label}.log"
  LOTTI_PENGUIN_WAKE_EVAL_LIVE=1 \
  PENGUIN_WAKE_EVAL_MODEL="$model" \
  PENGUIN_WAKE_EVAL_SCENARIO="$scenario" \
  PENGUIN_WAKE_EVAL_RUN_LABEL="$label" \
  timeout 900 fvm flutter test "$TEST_PATH" >"$log" 2>&1
  if grep -q "All tests passed" "$log"; then
    echo "PASS $model $label"
  else
    # Surface the named trap rather than a bare failure.
    local why
    why=$(grep -oE "$TRAPS[^.]{0,120}" "$log" | head -1)
    echo "FAIL $model $label :: ${why:-see $log}"
  fi
}

# Printed because the silent version fooled the person who wrote this fix: a
# run covering one scenario looks exactly like a run covering all of them.
echo "Models:    $(tr '\n' ' ' <<<"$MODELS")"
echo "Scenarios: $(tr '\n' ' ' <<<"$SCENARIOS")"
echo "Running $SAMPLES sample(s) per model per scenario, up to $MAX_PARALLEL at a time."
start=$(date +%s)
for model in $MODELS; do
  for scenario in $SCENARIOS; do
    for sample in $(seq 1 "$SAMPLES"); do
      while (( $(jobs -rp | wc -l) >= MAX_PARALLEL )); do wait -n; done
      run_one "$model" "$scenario" "$sample" &
    done
  done
done
wait
echo "Wall clock: $(( $(date +%s) - start ))s"

echo
echo "===== SUMMARY ====="
for model in $MODELS; do
  pass=0; total=0; reasons=""
  for scenario in $SCENARIOS; do
    spass=0; stotal=0
    for sample in $(seq 1 "$SAMPLES"); do
      log="$LOG_DIR/${model}_${scenario}_s${sample}.log"
      [[ -f "$log" ]] || continue
      total=$((total+1)); stotal=$((stotal+1))
      if grep -q "All tests passed" "$log"; then
        pass=$((pass+1)); spass=$((spass+1))
      else
        why=$(grep -oE "$TRAPS[^.]{0,90}" "$log" | head -1)
        reasons="$reasons\n      - ${scenario}: ${why:-unknown, see $log}"
      fi
    done
    # Per scenario as well as per model: one weak restraint case is the whole
    # finding, and a single model total hides it behind the cases that pass.
    [[ $stotal -gt 0 ]] &&
      reasons="$reasons\n      = ${scenario}: ${spass}/${stotal}"
  done
  printf '%-26s %s/%s' "$model" "$pass" "$total"
  [[ -n "$reasons" ]] && printf '%b' "$reasons"
  printf '\n'
done
