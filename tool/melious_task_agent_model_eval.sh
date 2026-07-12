#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${LOTTI_MELIOUS_ENV_FILE:-$repo_root/../greifswald/service/.env}"

if [[ -f "$env_file" ]]; then
  # Source the private file in a subshell and import only the values used by
  # this script. Unrelated credentials never enter the eval process environment.
  eval "$(
    (
      # shellcheck disable=SC1090
      source "$env_file"
      printf 'MELIOUS_API_KEY=%q\n' "${MELIOUS_API_KEY:-}"
      printf 'UP_UPSTREAM_API_KEY=%q\n' "${UP_UPSTREAM_API_KEY:-}"
      printf 'MELIOUS_BASE_URL=%q\n' "${MELIOUS_BASE_URL:-}"
      printf 'UP_UPSTREAM_BASE_URL=%q\n' "${UP_UPSTREAM_BASE_URL:-}"
    )
  )"
fi

api_key="${MELIOUS_API_KEY:-${UP_UPSTREAM_API_KEY:-}}"
base_url="${MELIOUS_BASE_URL:-${UP_UPSTREAM_BASE_URL:-https://api.melious.ai/v1}}"
if [[ -z "$api_key" ]]; then
  printf 'Missing Melious API key. Set MELIOUS_API_KEY or LOTTI_MELIOUS_ENV_FILE.\n' >&2
  exit 2
fi

source_commit="$(git -C "$repo_root" rev-parse --short=9 HEAD)"
run_id="${LOCAL_TASK_AGENT_EVAL_RUN_ID:-$(date -u +%Y-%m-%dT%H%M%SZ)_$source_commit}"
output_root="${LOCAL_TASK_AGENT_EVAL_OUTPUT_ROOT:-$repo_root/build/task_agent_model_eval}"
output_dir="${LOCAL_TASK_AGENT_EVAL_OUTPUT_DIR:-$output_root/$run_id}"
mkdir -p "$output_dir"

candidate_json="$output_dir/candidate-results.json"
candidate_markdown="$output_dir/candidate-results.md"
judgments_json="${LOCAL_TASK_AGENT_EVAL_JUDGMENTS_JSON:-$output_dir/judgments.json}"
judgments_markdown="${LOCAL_TASK_AGENT_EVAL_JUDGMENTS_MARKDOWN:-$output_dir/judgments.md}"

export LOTTI_LOCAL_TASK_AGENT_EVAL_LIVE=1
export LOCAL_TASK_AGENT_EVAL_PROVIDER_TYPE="${LOCAL_TASK_AGENT_EVAL_PROVIDER_TYPE:-melious}"
export LOCAL_TASK_AGENT_EVAL_MATRIX=melious
export LOCAL_TASK_AGENT_EVAL_BASE_URL="$base_url"
export LOCAL_TASK_AGENT_EVAL_API_KEY="$api_key"
export LOCAL_TASK_AGENT_EVAL_TEMPERATURE="${LOCAL_TASK_AGENT_EVAL_TEMPERATURE:-0}"
export LOCAL_TASK_AGENT_EVAL_JSON="${LOCAL_TASK_AGENT_EVAL_JSON:-$candidate_json}"
export LOCAL_TASK_AGENT_EVAL_MARKDOWN="${LOCAL_TASK_AGENT_EVAL_MARKDOWN:-$candidate_markdown}"

printf 'Task-agent eval output: %s\n' "$output_dir"

cd "$repo_root"
fvm flutter test test/features/ai/eval/local_task_agent_inference_eval_live_test.dart "$@"

if [[ "${LOCAL_TASK_AGENT_EVAL_JUDGE:-1}" == "1" ]]; then
  python3 tool/task_agent_model_eval_judge.py \
    "$LOCAL_TASK_AGENT_EVAL_JSON" \
    --json "$judgments_json" \
    --markdown "$judgments_markdown"
fi
