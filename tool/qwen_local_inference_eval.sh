#!/usr/bin/env bash
set -euo pipefail

export LOTTI_QWEN_EVAL_LIVE=1

fvm flutter test test/features/ai/eval/qwen_local_inference_eval_live_test.dart "$@"
