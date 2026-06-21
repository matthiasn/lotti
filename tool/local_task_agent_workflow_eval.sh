#!/usr/bin/env bash
set -euo pipefail

export LOTTI_LOCAL_TASK_AGENT_WORKFLOW_EVAL_LIVE=1

fvm flutter test test/features/ai/eval/local_task_agent_workflow_eval_live_test.dart "$@"
