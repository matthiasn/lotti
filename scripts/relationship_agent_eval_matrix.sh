#!/usr/bin/env bash
# Runs the relationship-agent inference eval across a model matrix, in
# parallel, and merges the per-process JSON artifacts into one markdown
# report.
#
# Each (model, sample) is its own `flutter test` process: the capture bench
# registers into GetIt, which is a global, so two runs cannot share a Dart
# VM. The compile is cached after the warm-up, so processes overlap on
# inference latency, which is where the wall-clock actually goes.
#
# SAMPLES is the whole point of this script rather than a convenience. The
# goal suite measured its own noise floor over five identical runs — range
# 10, sd 3.7 per 250 cases — so a single sample of this suite's 24 cases
# cannot distinguish a real regression from a redraw. Run at least 5.
#
# Usage:
#   scripts/relationship_agent_eval_matrix.sh [samples] [max_parallel]
#
# Reads credentials from the environment:
#   RELATIONSHIP_AGENT_EVAL_API_KEY (preferred) or MELIOUS_API_KEY
#
# The dedicated key takes precedence deliberately: relationship-eval spend
# bills separately from other eval work.
#
# Override the model list with RELATIONSHIP_AGENT_EVAL_MODELS. Commas or
# whitespace both separate: the Dart runner reading the same variable splits
# on commas (`_envList`) and the README documents that form, so a list copied
# from either place has to work here too. Cost figures in the report are
# observations for monitoring — never caps.
set -uo pipefail

SAMPLES="${1:-5}"
MAX_PARALLEL="${2:-4}"
case "$SAMPLES" in (*[!0-9]*|0|'') echo "samples must be a positive integer, got '$SAMPLES'" >&2; exit 2;; esac
case "$MAX_PARALLEL" in (*[!0-9]*|0|'') echo "max_parallel must be a positive integer, got '$MAX_PARALLEL'" >&2; exit 2;; esac
TEST_PATH="test/features/agents/eval/relationship/relationship_agent_eval_live_test.dart"
# Per-run directory: merging must never sweep up another run's artifacts, or
# the report silently mixes model lists and cost totals. The timestamp alone
# does not guarantee that — it has second resolution, so two invocations
# started in the same second would share a directory and overwrite each
# other's logs and JSON. `mktemp -d` appends an atomically-unique suffix, so
# the name still reads as a date while collisions are impossible.
RUN_STAMP="$(date +%Y%m%d-%H%M%S)"

# The target model first, then the control group. Both are PINNED dated
# snapshots: the floating `deepseek-v4-flash` alias returned five
# consecutive HTTP 503 during the goal matrix, and a run against a dead
# alias looks like a model that fails every case.
MODELS="${RELATIONSHIP_AGENT_EVAL_MODELS:-deepseek-v4-flash-0731 glm-5.2}"
# Empty fields are dropped rather than passed on: a comma is a non-whitespace
# separator, so "a,,b" splits into three, and the Dart runner's `_envList`
# discards the blank one too.
MODEL_LIST=()
IFS=$', \t\n' read -r -a _raw_models <<< "$MODELS"
for _model in ${_raw_models+"${_raw_models[@]}"}; do
  [[ -n "$_model" ]] && MODEL_LIST+=("$_model")
done
if (( ${#MODEL_LIST[@]} == 0 )); then
  echo "RELATIONSHIP_AGENT_EVAL_MODELS is set but names no model." >&2
  exit 2
fi

if [[ -z "${RELATIONSHIP_AGENT_EVAL_API_KEY:-${MELIOUS_API_KEY:-}}" ]]; then
  echo "Set RELATIONSHIP_AGENT_EVAL_API_KEY (or MELIOUS_API_KEY)." >&2
  exit 2
fi

mkdir -p eval_artifacts
OUT_DIR="$(mktemp -d "eval_artifacts/relationship_agent_${RUN_STAMP}.XXXXXX")" || {
  echo "Could not create a run directory under eval_artifacts." >&2
  exit 1
}
LOG_DIR="$OUT_DIR/logs"
mkdir -p "$LOG_DIR"

# Warm the build once. Otherwise every process in the first wave compiles the
# same test concurrently, which is slower than compiling it once.
echo "Warming the test build..."
LOTTI_RELATIONSHIP_AGENT_EVAL_LIVE='' fvm flutter test "$TEST_PATH" >/dev/null 2>&1

run_one() {
  local model="$1" sample="$2"
  local label="s${sample}"
  local log="$LOG_DIR/relationship_agent_${model}_${label}.log"
  LOTTI_RELATIONSHIP_AGENT_EVAL_LIVE=1 \
  RELATIONSHIP_AGENT_EVAL_MODELS="$model" \
  RELATIONSHIP_AGENT_EVAL_JSON="$OUT_DIR/relationship_agent_${model}_${label}.json" \
  RELATIONSHIP_AGENT_EVAL_MARKDOWN="$OUT_DIR/relationship_agent_${model}_${label}.md" \
  timeout 2400 fvm flutter test "$TEST_PATH" --tags eval-live >"$log" 2>&1
  if grep -q "All tests passed" "$log"; then
    echo "PASS $model $label"
  else
    local why
    why=$(grep -oE '(noOpViolated|forbiddenToolCall|unexpectedToolCall|forbiddenToolArguments|argumentMismatch|missingExpectedToolCall|healthBandMismatch|adToneViolation|forbiddenAssistantClaim|inferenceError|HTTP [0-9]+)[^.]{0,120}' "$log" | head -1)
    echo "FAIL $model $label :: ${why:-see $log}"
    return 1
  fi
}

FAILED_JOBS=0

echo "Running $SAMPLES sample(s) per model, up to $MAX_PARALLEL at a time."
start=$(date +%s)
for model in "${MODEL_LIST[@]}"; do
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
artifacts=("$OUT_DIR"/relationship_agent_*.json)
if (( ${#artifacts[@]} == 0 )); then
  echo "No artifacts in $OUT_DIR — every run failed; see $LOG_DIR." >&2
  exit 1
fi
if ! fvm dart run tool/agent_eval_report.dart \
  "${artifacts[@]}" > "$OUT_DIR/relationship_agent_merged_report.md"; then
  echo "Merge failed." >&2
  exit 1
fi
echo "Merged report: $OUT_DIR/relationship_agent_merged_report.md"
(( FAILED_JOBS == 0 )) || exit 1
