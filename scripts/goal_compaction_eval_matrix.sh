#!/usr/bin/env bash
# Runs the goal check-in compaction eval and renders the deterministic
# report. The judged metrics (fact recall, hallucination, recommendation
# consistency) need a scores file from the judge — see
# docs/evaluations/goal_agent_models/compaction.md — after which re-run
# only the report step:
#
#   fvm dart run tool/goal_compaction_eval_report.dart \
#     eval_artifacts/goal_compaction_<stamp>/packet.json \
#     eval_artifacts/goal_compaction_<stamp>/scores.json
#
# Usage:
#   scripts/goal_compaction_eval_matrix.sh [samples]
#
# Reads credentials from MELIOUS_API_KEY (or GOAL_COMPACTION_EVAL_API_KEY).
# GOAL_COMPACTION_EVAL_MODEL, _DIGEST_MODEL, _FIXTURES and _STRATEGIES pass
# through to the live test. The digest cache under eval_artifacts/ is shared
# between runs, so re-running costs no digest calls.
set -uo pipefail

SAMPLES="${1:-1}"
case "$SAMPLES" in (*[!0-9]*|0|'') echo "samples must be a positive integer, got '$SAMPLES'" >&2; exit 2;; esac
TEST_PATH="test/features/agents/eval/goal/compaction/goal_compaction_eval_live_test.dart"
RUN_STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="eval_artifacts/goal_compaction_${RUN_STAMP}"

if [[ -z "${GOAL_COMPACTION_EVAL_API_KEY:-${MELIOUS_API_KEY:-}}" ]]; then
  echo "Set MELIOUS_API_KEY (or GOAL_COMPACTION_EVAL_API_KEY)." >&2
  exit 2
fi
mkdir -p "$OUT_DIR"

echo "Running ${SAMPLES} sample(s) per (fixture × arm) → $OUT_DIR"
LOTTI_GOAL_COMPACTION_EVAL_LIVE=1 \
GOAL_COMPACTION_EVAL_SAMPLES="$SAMPLES" \
GOAL_COMPACTION_EVAL_PACKET="$OUT_DIR/packet.json" \
fvm flutter test "$TEST_PATH" --tags eval-live 2>&1 | tee "$OUT_DIR/run.log" | grep -E '^\[compaction-eval\]|All tests passed|Some tests failed'

if [[ ! -f "$OUT_DIR/packet.json" ]]; then
  echo "No packet written; see $OUT_DIR/run.log" >&2
  exit 1
fi
if ! fvm dart run tool/goal_compaction_eval_report.dart "$OUT_DIR/packet.json" > "$OUT_DIR/report.md"; then
  echo "Report failed; see $OUT_DIR/packet.json" >&2
  exit 1
fi
echo "Deterministic report: $OUT_DIR/report.md"
echo "Next: judge $OUT_DIR/packet.json into $OUT_DIR/scores.json, then re-run the report with both."
