# Qwen 3.6 Local Eval Harness

## Purpose

Build a minimal, reviewable local evaluation harness for comparing Qwen 3.6
35B-A3B variants through the existing Lotti inference stack.

This plan is explicitly for oMLX only. Do not run, configure, or fall back to
Ollama for this harness.

The goal is not a release gate or governance workflow. The goal is a compact
developer tool that answers:

- Which installed local Qwen 3.6 oMLX model handles task-agent tool calls?
- How long does each model take on a small, representative scenario set?
- Which failures happen: transport, missing tool call, wrong tool, invalid
  arguments, argument mismatch, empty response, or scenario pass?

## Branch And Current State

- Branch: `test/agent_eval_framework`
- Status: MVP implemented and committed; follow-up strict argument/tool-selection
  eval changes are implemented and verified.
- Current follow-up diff: 6 files, 240 insertions, 31 deletions.
- New production modules are intentionally small:
  - `lib/features/ai/eval/qwen_local_eval_config.dart` — 177 lines
  - `lib/features/ai/eval/qwen_local_eval_report.dart` — 334 lines
  - `lib/features/ai/eval/qwen_local_inference_eval.dart` — 239 lines

## Files Added Or Changed

- `analysis_options.yaml`
  - Removed the `custom_lint` analyzer plugin hook. The plugin was causing the
    analyzer process to fail before useful diagnostics could be reported.
- `dart_test.yaml`
  - Added the `eval-live` tag for manual local-inference tests.
- `lib/features/ai/README.md`
  - Added a short developer-tool note for the Qwen local eval wrapper.
- `lib/features/ai/eval/qwen_local_eval_config.dart`
  - Defines default Qwen profiles, scenario definitions, profile parsing, and
    scenario selection. The default scenarios expose the five competing core
    task-field tools together.
- `lib/features/ai/eval/qwen_local_eval_report.dart`
  - Defines case results, profile summaries, JSON output, and Markdown output,
    including tool-name and argument-value match rates.
- `lib/features/ai/eval/qwen_local_inference_eval.dart`
  - Runs the profile/scenario matrix through `InferenceRepositoryInterface`,
    using the real task-agent tool definitions from `AgentToolRegistry`.
- `test/features/ai/eval/qwen_local_inference_eval_test.dart`
  - Focused unit tests for profiles, provenance, tool calls, failure categories,
    streamed tool-call argument chunks, wrong argument values, request failures,
    and compact report shape.
- `test/features/ai/eval/qwen_local_inference_eval_live_test.dart`
  - Manual live oMLX test, skipped unless `LOTTI_QWEN_EVAL_LIVE=1`.
- `tool/qwen_local_inference_eval.sh`
  - Single CLI wrapper for the live local eval.
- `docs/implementation_plans/2026-06-16_qwen_3_6_local_eval_harness.md`
  - This oMLX-only handoff and implementation plan.

## Default Models

The built-in profile matrix targets the installed oMLX model IDs:

- `Qwen3.6-35B-A3B-TurboQuant-MLX-4bit`
- `Qwen3.6-35B-A3B-4bit`
- `Qwen3.6-35B-A3B-MLX-8bit`

Current local oMLX discovery found all three under `/Users/mn/.omlx/models`.
`Qwen3.6-35B-A3B` is treated as multimodal in the app catalog: the oMLX known
model rows include both text and image input modalities, and the Local Power
seed uses the same recommended 4-bit row for thinking and image recognition.

## Default Scenarios

The MVP uses a compact task-agent tool-call scenario set. Each scenario exposes
the same five competing core task-field tools:

- `set_task_title`
- `set_task_status`
- `update_task_estimate`
- `update_task_due_date`
- `update_task_priority`

The scenarios validate both the selected tool and a small expected argument
subset:

- `task_title_tool_call`
  - Expects `set_task_title`
  - Expects `title = "Submit expense report"`
- `task_status_tool_call`
  - Expects `set_task_status`
  - Expects `status = "IN PROGRESS"`
- `task_estimate_tool_call`
  - Expects `update_task_estimate`
  - Expects `minutes = 150`
- `task_due_date_tool_call`
  - Expects `update_task_due_date`
  - Expects `dueDate = "2026-07-04"`
- `task_priority_tool_call`
  - Expects `update_task_priority`
  - Expects `priority = "P1"`

The prompt text is not written to the report. The report captures scenario IDs,
tool names, model/provider provenance, latency, token counts when available, and
failure category.

## Runtime Configuration

The runtime provider is the oMLX OpenAI-compatible server. The expected local
base URL for the current machine is `http://127.0.0.1:8003/v1`. Do not point
this harness at an Ollama endpoint.

The app now has a first-class `InferenceProviderType.omlx` provider with the
same default base URL and an OpenAI-compatible connection probe. It is separate
from `genericOpenAi` so local oMLX models can be prepopulated and local-only
profile gating can classify them correctly.

Default live wrapper:

```bash
tool/qwen_local_inference_eval.sh
```

Useful environment variables:

```bash
QWEN_EVAL_BASE_URL=http://127.0.0.1:8003/v1
QWEN_EVAL_API_KEY=<local oMLX API key>
QWEN_EVAL_PROFILES=name=model,name2=model2
QWEN_EVAL_SCENARIOS=task_title_tool_call,task_status_tool_call
QWEN_EVAL_JSON=/private/tmp/lotti-qwen-local-eval.json
QWEN_EVAL_MARKDOWN=/private/tmp/lotti-qwen-local-eval.md
QWEN_EVAL_TEMPERATURE=0
QWEN_EVAL_MAX_COMPLETION_TOKENS=512
```

On this machine, oMLX settings showed the active server at:

```text
http://127.0.0.1:8003/v1
```

The repo's generic OpenAI-compatible default is still `http://localhost:8002/v1`,
so live runs need `QWEN_EVAL_BASE_URL` unless oMLX is moved to that port.

## Verification Already Completed

Focused formatting:

```bash
fvm dart format \
  lib/features/ai/eval/qwen_local_eval_config.dart \
  lib/features/ai/eval/qwen_local_eval_report.dart \
  lib/features/ai/eval/qwen_local_inference_eval.dart \
  test/features/ai/eval/qwen_local_inference_eval_test.dart \
  test/features/ai/eval/qwen_local_inference_eval_live_test.dart
```

Focused tests:

```bash
fvm flutter test \
  test/features/ai/eval/qwen_local_inference_eval_test.dart \
  test/features/ai/eval/qwen_local_inference_eval_live_test.dart
```

Result:

```text
+11 ~1: All tests passed!
```

Targeted analyzer:

```bash
fvm flutter analyze --no-pub \
  lib/features/ai/eval/qwen_local_eval_config.dart \
  lib/features/ai/eval/qwen_local_eval_report.dart \
  lib/features/ai/eval/qwen_local_inference_eval.dart \
  test/features/ai/eval/qwen_local_inference_eval_test.dart \
  test/features/ai/eval/qwen_local_inference_eval_live_test.dart
```

Result:

```text
No issues found!
```

Full analyzer:

```bash
make analyze
```

Result:

```text
No issues found! (ran in 24.7s)
```

Whitespace check:

```bash
git diff --check
```

Result: clean.

Live oMLX eval:

```bash
QWEN_EVAL_BASE_URL=http://127.0.0.1:8003/v1 \
QWEN_EVAL_API_KEY=$(jq -r '.auth.api_key' /Users/mn/.omlx/settings.json) \
tool/qwen_local_inference_eval.sh
```

Result:

```text
+1: All tests passed!
```

Fresh Markdown report:

```text
/private/tmp/lotti-qwen-local-eval-competing-tools.md
```

Fresh live summary:

| Profile | Pass | Avg latency | Tool match | Arg match |
| --- | ---: | ---: | ---: | ---: |
| `qwen36-a35b-a3b-turboquant-mlx4` | 5/5 | 4169 ms | 5/5 | 5/5 |
| `qwen36-a35b-a3b-mlx4` | 5/5 | 1914 ms | 5/5 | 5/5 |
| `qwen36-a35b-a3b-mlx8` | 5/5 | 2339 ms | 5/5 | 5/5 |

## Analyzer Issue And Fix

The analyzer initially failed with analysis server exit code `-9`, then macOS
crash reports showed:

```text
CODESIGNING Invalid Page
```

Useful findings:

- A standalone smoke file analyzed cleanly.
- The package analyzer failed before returning diagnostics.
- Moving `/Users/mn/.dartServer/.analysis-driver` aside allowed analyzer to
  rebuild its cache and report real diagnostics.
- After removing the `custom_lint` plugin hook from `analysis_options.yaml` and
  fixing normal analyzer warnings, both targeted and full analyzer runs passed.

The old cache was moved to:

```text
/private/tmp/dart-analysis-driver-cache-before-qwen-eval-20260616
```

## Explicit Non-Goals

This MVP intentionally does not add:

- release plans
- review attestations
- decision ledgers
- rollout/runtime ledgers
- source-replay marker chains
- broad model-class promotion gates
- a new artifact pipeline
- exhaustive scenario coverage
- Ollama execution or fallback paths

## Next Session Checklist

1. Reconfirm branch and staged diff:

   ```bash
   git status --short --branch
   git diff --cached --stat
   ```

2. Review the staged diff for accidental scope creep:

   ```bash
   git diff --cached
   ```

3. Re-run fast verification if anything changed:

   ```bash
   fvm dart format \
     lib/features/ai/eval/qwen_local_eval_config.dart \
     lib/features/ai/eval/qwen_local_eval_report.dart \
     lib/features/ai/eval/qwen_local_inference_eval.dart \
     test/features/ai/eval/qwen_local_inference_eval_test.dart \
     test/features/ai/eval/qwen_local_inference_eval_live_test.dart

   fvm flutter test \
     test/features/ai/eval/qwen_local_inference_eval_test.dart \
     test/features/ai/eval/qwen_local_inference_eval_live_test.dart

   make analyze
   ```

4. Optionally re-run the live oMLX check if the local server is running:

   ```bash
   QWEN_EVAL_BASE_URL=http://127.0.0.1:8003/v1 \
   QWEN_EVAL_API_KEY=$(jq -r '.auth.api_key' /Users/mn/.omlx/settings.json) \
   tool/qwen_local_inference_eval.sh
   ```

5. Decide whether to commit as-is or make one final scope trim. The current
   diff is small enough to review, but the PR should call out that custom lint
   was disabled to unblock analyzer stability.

## Suggested Commit Message

```text
feat(ai): add local Qwen eval harness
```
