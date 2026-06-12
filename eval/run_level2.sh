#!/usr/bin/env bash
#
# Level 2 eval orchestration for the Lotti task & planning agents.
#
# Pipeline:
#   1. Run the live eval entrypoint (flutter test, tagged 'eval-live'), which
#      executes each scenario against each model profile/trial index (local
#      Ollama + frontier) and writes trace JSON under eval/runs/<runId>/.
#   2. Hand the run directory to Claude Code to grade (see eval/grade_run.md),
#      producing one .verdict.json next to each trace.
#   3. Aggregate traces + verdicts into a summary table (EvalReporter).
#
# Live model calls are gated behind LOTTI_EVAL_LIVE=1 and provider credentials so
# this NEVER runs in default CI. See docs/adr/0029-agent-evaluation-harness.md.
#
# Usage:
#   eval/run_level2.sh plan [runId]
#   eval/run_level2.sh run [runId]
#   eval/run_level2.sh grade [runId]
#   eval/run_level2.sh verify [runId]
#   eval/run_level2.sh diagnose [runId]
#   EVAL_SCENARIOS=/private/path/scenarios.json eval/run_level2.sh catalog
#   eval/run_level2.sh report [runId]
#   EVAL_CALIBRATION_TEMPLATE=/private/tmp/judge_gold_v1.template.json EVAL_CALIBRATION_TEMPLATE_MAX_ROWS=24 eval/run_level2.sh template <runId>
#   EVAL_BLINDED_EXPORT=/private/tmp/lotti-blind-review eval/run_level2.sh blind [runId]
#   EVAL_BLINDED_IMPORT=/private/tmp/lotti-blind-review eval/run_level2.sh import-blind [runId]
#   EVAL_CALIBRATION=eval/calibration/judge_gold_v1.json eval/run_level2.sh calibrate [runId]
#   EVAL_PROMOTION_PLAN=/private/tmp/promotion_plan.draft.json eval/run_level2.sh run [runId]
#   EVAL_PROMOTION_PLAN=/private/tmp/promotion_plan.json EVAL_CALIBRATION=/private/tmp/judge_gold_v1.json eval/run_level2.sh report [runId]
#   EVAL_PROMOTION_CANDIDATE_PROFILE=frontier-gemini EVAL_PROMOTION_BASELINE_PROFILE=frontier-fast EVAL_CALIBRATION=/private/tmp/judge_gold_v1.json eval/run_level2.sh report [runId]
#   EVAL_SCENARIOS=/private/path/scenarios.json EVAL_RUNS_ROOT=/private/tmp/lotti-eval-runs eval/run_level2.sh run [runId]
#   EVAL_PROFILES=/private/path/profiles.json eval/run_level2.sh run [runId]
#   EVAL_PROMPT_VARIANTS=/private/path/prompt_variants.json eval/run_level2.sh run [runId]
#   EVAL_SCENARIO_IDS=task_workflow_structured_update EVAL_PROFILE_NAMES=frontier-gemini eval/run_level2.sh run [runId]
#   EVAL_SCENARIO_IDS=task_workflow_structured_update EVAL_PROFILE_NAMES=frontier-gemini EVAL_PROMPT_VARIANT_NAMES=default,metadata-first-v2 eval/run_level2.sh plan [runId]
#   EVAL_SCENARIOS=/private/path/scenarios.json EVAL_SCENARIOS_MODE=replace eval/run_level2.sh catalog
#   eval/run_level2.sh all [runId]
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

RUNS_ROOT="${EVAL_RUNS_ROOT:-eval/runs}"

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
if [[ "$MODE" != "plan" && "$MODE" != "run" && "$MODE" != "grade" && "$MODE" != "verify" && "$MODE" != "diagnose" && "$MODE" != "catalog" && "$MODE" != "report" && "$MODE" != "template" && "$MODE" != "blind" && "$MODE" != "import-blind" && "$MODE" != "calibrate" && "$MODE" != "all" ]]; then
  RUN_ID="$MODE"
  MODE="run"
else
  case "$MODE" in
    plan | run | all)
      RUN_ID="${2:-$(date +%Y%m%d-%H%M%S)}"
      ;;
    catalog)
      RUN_ID="${2:-catalog-preflight}"
      ;;
    template)
      if [[ $# -lt 2 ]]; then
        echo "!!! Template generation requires an explicit runId." >&2
        echo "    EVAL_CALIBRATION_TEMPLATE=<json> eval/run_level2.sh template <runId>" >&2
        exit 10
      fi
      RUN_ID="$2"
      ;;
    grade | verify | diagnose | report | blind | import-blind | calibrate)
      RUN_ID="${2:-$(latest_run_id)}"
      ;;
  esac
fi
RUN_DIR="${RUNS_ROOT}/${RUN_ID}"
CALIBRATION_PATH="${EVAL_CALIBRATION:-}"
CALIBRATION_TEMPLATE_PATH="${EVAL_CALIBRATION_TEMPLATE:-}"
CALIBRATION_TEMPLATE_VERSION="${EVAL_CALIBRATION_VERSION:-human-gold-v1}"
CALIBRATION_TEMPLATE_OVERWRITE="${EVAL_CALIBRATION_TEMPLATE_OVERWRITE:-}"
CALIBRATION_TEMPLATE_MAX_ROWS="${EVAL_CALIBRATION_TEMPLATE_MAX_ROWS:-}"
BLINDED_EXPORT_PATH="${EVAL_BLINDED_EXPORT:-}"
BLINDED_EXPORT_OVERWRITE="${EVAL_BLINDED_EXPORT_OVERWRITE:-}"
BLINDED_EXPORT_SEED="${EVAL_BLINDED_EXPORT_SEED:-}"
BLINDED_IMPORT_PATH="${EVAL_BLINDED_IMPORT:-}"
BLINDED_IMPORT_OVERWRITE="${EVAL_BLINDED_IMPORT_OVERWRITE:-}"
SCENARIO_CATALOG_PATH="${EVAL_SCENARIOS:-}"
SCENARIO_CATALOG_MODE="${EVAL_SCENARIOS_MODE:-}"
SCENARIO_IDS="${EVAL_SCENARIO_IDS:-}"
PROFILE_CATALOG_PATH="${EVAL_PROFILES:-}"
PROFILE_NAMES="${EVAL_PROFILE_NAMES:-}"
PROMPT_VARIANT_CATALOG_PATH="${EVAL_PROMPT_VARIANTS:-}"
PROMPT_VARIANT_NAMES="${EVAL_PROMPT_VARIANT_NAMES:-}"
PROTECTED_TRACE_ACK="${LOTTI_EVAL_PROTECTED_TRACE_ACK:-}"
PROMOTION_CANDIDATE_PROFILE="${EVAL_PROMOTION_CANDIDATE_PROFILE:-}"
PROMOTION_BASELINE_PROFILE="${EVAL_PROMOTION_BASELINE_PROFILE:-}"
PROMOTION_PLAN_PATH="${EVAL_PROMOTION_PLAN:-}"

DART_DEFINES=(
  "--dart-define=EVAL_RUNS_ROOT=${RUNS_ROOT}"
)
if [[ -n "$SCENARIO_CATALOG_PATH" ]]; then
  DART_DEFINES+=("--dart-define=EVAL_SCENARIOS=${SCENARIO_CATALOG_PATH}")
fi
if [[ -n "$SCENARIO_CATALOG_MODE" ]]; then
  DART_DEFINES+=("--dart-define=EVAL_SCENARIOS_MODE=${SCENARIO_CATALOG_MODE}")
fi
if [[ -n "$SCENARIO_IDS" ]]; then
  DART_DEFINES+=("--dart-define=EVAL_SCENARIO_IDS=${SCENARIO_IDS}")
fi
if [[ -n "$PROFILE_CATALOG_PATH" ]]; then
  DART_DEFINES+=("--dart-define=EVAL_PROFILES=${PROFILE_CATALOG_PATH}")
fi
if [[ -n "$PROFILE_NAMES" ]]; then
  DART_DEFINES+=("--dart-define=EVAL_PROFILE_NAMES=${PROFILE_NAMES}")
fi
if [[ -n "$PROMPT_VARIANT_CATALOG_PATH" ]]; then
  DART_DEFINES+=("--dart-define=EVAL_PROMPT_VARIANTS=${PROMPT_VARIANT_CATALOG_PATH}")
fi
if [[ -n "$PROMPT_VARIANT_NAMES" ]]; then
  DART_DEFINES+=("--dart-define=EVAL_PROMPT_VARIANT_NAMES=${PROMPT_VARIANT_NAMES}")
fi
if [[ -n "$PROTECTED_TRACE_ACK" ]]; then
  DART_DEFINES+=(
    "--dart-define=LOTTI_EVAL_PROTECTED_TRACE_ACK=${PROTECTED_TRACE_ACK}"
  )
fi
if [[ -n "$PROMOTION_PLAN_PATH" ]]; then
  DART_DEFINES+=("--dart-define=EVAL_PROMOTION_PLAN=${PROMOTION_PLAN_PATH}")
fi

if [[ "$MODE" == "catalog" ]]; then
  echo "==> Level 2 scenario catalog preflight"
elif [[ "$MODE" == "plan" ]]; then
  echo "==> Level 2 eval plan: ${RUN_ID}"
  echo "    output: ${RUN_DIR}"
else
  echo "==> Level 2 eval run: ${RUN_ID}"
  echo "    output: ${RUN_DIR}"
fi
if [[ -n "$SCENARIO_CATALOG_PATH" ]]; then
  echo "    scenario catalog: ${SCENARIO_CATALOG_PATH}"
  if [[ -n "$SCENARIO_CATALOG_MODE" ]]; then
    echo "    scenario catalog mode: ${SCENARIO_CATALOG_MODE}"
  fi
  if [[ "$PROTECTED_TRACE_ACK" != "1" ]]; then
    echo "    protected trace guard: run roots inside the repo require either" \
      "EVAL_RUNS_ROOT outside the repo or LOTTI_EVAL_PROTECTED_TRACE_ACK=1" >&2
  fi
fi
if [[ -n "$SCENARIO_IDS" ]]; then
  echo "    scenario ids: ${SCENARIO_IDS}"
fi
if [[ -n "$PROFILE_CATALOG_PATH" ]]; then
  echo "    profile catalog: ${PROFILE_CATALOG_PATH}"
fi
if [[ -n "$PROFILE_NAMES" ]]; then
  echo "    profile names: ${PROFILE_NAMES}"
fi
if [[ -n "$PROMPT_VARIANT_CATALOG_PATH" ]]; then
  echo "    prompt variant catalog: ${PROMPT_VARIANT_CATALOG_PATH}"
fi
if [[ -n "$PROMPT_VARIANT_NAMES" ]]; then
  echo "    prompt variant names: ${PROMPT_VARIANT_NAMES}"
fi
if [[ -n "$PROMOTION_CANDIDATE_PROFILE" || -n "$PROMOTION_BASELINE_PROFILE" ]]; then
  if [[ -z "$PROMOTION_CANDIDATE_PROFILE" || -z "$PROMOTION_BASELINE_PROFILE" ]]; then
    echo "!!! Set both EVAL_PROMOTION_CANDIDATE_PROFILE and EVAL_PROMOTION_BASELINE_PROFILE, or neither." >&2
    exit 11
  fi
  echo "    promotion comparison: ${PROMOTION_CANDIDATE_PROFILE} vs ${PROMOTION_BASELINE_PROFILE}"
fi
if [[ -n "$PROMOTION_PLAN_PATH" ]]; then
  echo "    promotion assertion plan: ${PROMOTION_PLAN_PATH}"
fi
if [[ -n "$BLINDED_EXPORT_PATH" ]]; then
  echo "    blinded export: ${BLINDED_EXPORT_PATH}"
fi
if [[ -n "$BLINDED_IMPORT_PATH" ]]; then
  echo "    blinded verdict import: ${BLINDED_IMPORT_PATH}"
fi

catalog_preflight() {
  if [[ -z "$SCENARIO_CATALOG_PATH" ]]; then
    echo "!!! Set EVAL_SCENARIOS=<json> to preflight a private scenario catalog." >&2
    exit 12
  fi
  echo "==> Preflighting scenario catalog..."
  fvm flutter test test/eval/scenarios/report_test.dart \
    --plain-name "renders scenario catalog preflight" \
    "${DART_DEFINES[@]}"
}

plan_run() {
  echo "==> Rendering eval matrix plan..."
  fvm flutter test test/eval/scenarios/plan_runner_test.dart \
    --plain-name "renders eval matrix plan" \
    --dart-define=EVAL_RUN="${RUN_ID}" \
    "${DART_DEFINES[@]}"
}

run_traces() {
  if [[ "${LOTTI_EVAL_LIVE:-0}" != "1" ]]; then
    echo "!!! LOTTI_EVAL_LIVE is not 1 — refusing to make live model calls." >&2
    echo "    Set LOTTI_EVAL_LIVE=1 plus provider credentials to run Level 2." >&2
    exit 2
  fi
  if [[ "${CI:-0}" == "true" && "${LOTTI_EVAL_ALLOW_CI:-0}" != "1" ]]; then
    echo "!!! Refusing live eval in CI without LOTTI_EVAL_ALLOW_CI=1." >&2
    exit 3
  fi
  if [[ -e "$RUN_DIR" ]] && compgen -G "${RUN_DIR}/*" > /dev/null; then
    echo "!!! Refusing to write into non-empty run directory: ${RUN_DIR}" >&2
    exit 4
  fi
  mkdir -p "$RUN_DIR"
  echo "==> Producing traces..."
  fvm flutter test test/eval/scenarios/live_runner_test.dart --tags eval-live \
    --dart-define=EVAL_RUN="${RUN_ID}" \
    "${DART_DEFINES[@]}"
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
    --dart-define=EVAL_RUN="${RUN_ID}" \
    "${DART_DEFINES[@]}"
}

diagnose_run() {
  echo "==> Rendering raw Level 1 diagnostics..."
  fvm flutter test test/eval/scenarios/report_test.dart \
    --plain-name "renders eval run diagnostics" \
    --dart-define=EVAL_RUN="${RUN_ID}" \
    "${DART_DEFINES[@]}"
}

report_run() {
  echo "==> Aggregating report..."
  local report_defines=("${DART_DEFINES[@]}")
  if [[ -n "$CALIBRATION_PATH" ]]; then
    report_defines+=("--dart-define=EVAL_CALIBRATION=${CALIBRATION_PATH}")
  fi
  if [[ -n "$PROMOTION_CANDIDATE_PROFILE" ]]; then
    report_defines+=(
      "--dart-define=EVAL_PROMOTION_CANDIDATE_PROFILE=${PROMOTION_CANDIDATE_PROFILE}"
      "--dart-define=EVAL_PROMOTION_BASELINE_PROFILE=${PROMOTION_BASELINE_PROFILE}"
    )
  fi
  fvm flutter test test/eval/scenarios/report_test.dart \
    --plain-name "renders eval run summary" \
    --dart-define=EVAL_RUN="${RUN_ID}" \
    "${report_defines[@]}"
}

calibrate_run() {
  if [[ -z "$CALIBRATION_PATH" ]]; then
    echo "!!! Set EVAL_CALIBRATION=<json> to render judge calibration." >&2
    exit 7
  fi
  if [[ ! -f "$CALIBRATION_PATH" ]]; then
    echo "!!! Missing calibration file: ${CALIBRATION_PATH}" >&2
    exit 8
  fi
  echo "==> Rendering judge calibration report..."
  fvm flutter test test/eval/scenarios/report_test.dart \
    --plain-name "renders judge calibration report" \
    --dart-define=EVAL_RUN="${RUN_ID}" \
    --dart-define=EVAL_CALIBRATION="${CALIBRATION_PATH}" \
    "${DART_DEFINES[@]}"
}

template_run() {
  if [[ -z "$CALIBRATION_TEMPLATE_PATH" ]]; then
    echo "!!! Set EVAL_CALIBRATION_TEMPLATE=<json> to write a label template." >&2
    exit 9
  fi
  local template_defines=("${DART_DEFINES[@]}")
  if [[ -n "$CALIBRATION_TEMPLATE_MAX_ROWS" ]]; then
    template_defines+=(
      "--dart-define=EVAL_CALIBRATION_TEMPLATE_MAX_ROWS=${CALIBRATION_TEMPLATE_MAX_ROWS}"
    )
  fi
  echo "==> Writing judge calibration label template..."
  fvm flutter test test/eval/scenarios/report_test.dart \
    --plain-name "writes judge calibration label template" \
    --dart-define=EVAL_RUN="${RUN_ID}" \
    --dart-define=EVAL_CALIBRATION_TEMPLATE="${CALIBRATION_TEMPLATE_PATH}" \
    --dart-define=EVAL_CALIBRATION_VERSION="${CALIBRATION_TEMPLATE_VERSION}" \
    --dart-define=EVAL_CALIBRATION_TEMPLATE_OVERWRITE="${CALIBRATION_TEMPLATE_OVERWRITE}" \
    "${template_defines[@]}"
}

blind_run() {
  if [[ -z "$BLINDED_EXPORT_PATH" ]]; then
    echo "!!! Set EVAL_BLINDED_EXPORT=<dir> to write a blinded judge export." >&2
    exit 13
  fi
  local blind_defines=("${DART_DEFINES[@]}")
  if [[ -n "$BLINDED_EXPORT_OVERWRITE" ]]; then
    blind_defines+=(
      "--dart-define=EVAL_BLINDED_EXPORT_OVERWRITE=${BLINDED_EXPORT_OVERWRITE}"
    )
  fi
  if [[ -n "$BLINDED_EXPORT_SEED" ]]; then
    blind_defines+=(
      "--dart-define=EVAL_BLINDED_EXPORT_SEED=${BLINDED_EXPORT_SEED}"
    )
  fi
  echo "==> Writing blinded judge trace export..."
  fvm flutter test test/eval/scenarios/report_test.dart \
    --plain-name "writes blinded judge trace export" \
    --dart-define=EVAL_RUN="${RUN_ID}" \
    --dart-define=EVAL_BLINDED_EXPORT="${BLINDED_EXPORT_PATH}" \
    "${blind_defines[@]}"
}

import_blinded_verdicts() {
  if [[ -z "$BLINDED_IMPORT_PATH" ]]; then
    echo "!!! Set EVAL_BLINDED_IMPORT=<dir> to import blinded judge verdicts." >&2
    exit 14
  fi
  local import_defines=("${DART_DEFINES[@]}")
  if [[ -n "$BLINDED_IMPORT_OVERWRITE" ]]; then
    import_defines+=(
      "--dart-define=EVAL_BLINDED_IMPORT_OVERWRITE=${BLINDED_IMPORT_OVERWRITE}"
    )
  fi
  echo "==> Importing blinded judge verdicts..."
  fvm flutter test test/eval/scenarios/report_test.dart \
    --plain-name "imports blinded judge verdicts" \
    --dart-define=EVAL_RUN="${RUN_ID}" \
    --dart-define=EVAL_BLINDED_IMPORT="${BLINDED_IMPORT_PATH}" \
    "${import_defines[@]}"
}

case "$MODE" in
  plan)
    plan_run
    ;;
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
  diagnose)
    diagnose_run
    ;;
  catalog)
    catalog_preflight
    ;;
  report)
    verify_run
    report_run
    ;;
  template)
    template_run
    ;;
  blind)
    blind_run
    ;;
  import-blind)
    import_blinded_verdicts
    ;;
  calibrate)
    verify_run
    calibrate_run
    ;;
  all)
    run_traces
    grade_prompt
    echo "==> After grading, run:"
    echo "      eval/run_level2.sh report ${RUN_ID}"
    ;;
esac
