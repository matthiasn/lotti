# DeepSeek V4.1 Flash image/tool investigation

On 2026-09-12, the Melious API reproduced the reported malformed DSML on
**text-only requests as well as image requests**. The necessary distinction
in this controlled comparison was forced tool choice, not image attachment.
The exact upstream implementation defect (template, constrained decoder, or
parser) is not visible from this client repository.

## Existing harness and app path

- `tool/melious_task_agent_model_eval.sh` launches the app-shaped Dart eval in
  `test/features/ai/eval/local_task_agent_inference_eval_live_test.dart`.
  `tool/task_agent_model_eval_judge.py` is its Python judge: it POSTs ordinary
  chat JSON, then reads structured tool calls from the candidate artifact.
  It does not implement image inference or a DSML decoder. The neighboring
  Greifswald Python eval is a separate orchestration-service evaluation.
- Agent conversations go through `ConversationRepository` and
  `MeliousInferenceRepository.generateTextWithMessages`. Image skills go
  through `SkillInferenceRunner.runImageAnalysis` and
  `MeliousInferenceRepository.generateWithImages`.
- Both construct requests with `CloudInferenceRequestHelpers.createBaseRequest`
  and POST to `/v1/chat/completions`. Both supply impact collectors and use
  the same buffered response parser, which reads `message.tool_calls` and
  `message.content`. Streamed variants use the same structured API contract.
- Image analysis attaches the JSON schema in `entry_summary_tool.dart`
  (`oneLiner`, `tldr`, `summary`) and explicitly pins that function. Agent
  turns normally use automatic choice, with named choices for some repairs.
  The schema is not omitted when images are present.
- Image requests use user content parts: text followed by base64 image URLs.
  `_prepareImageData` preserves original file bytes; the Melious adapter
  declares JPEG regardless of file type. The probe can vary the declared MIME
  without changing those bytes. This labeling issue is separate from the
  reproduced forced-choice failure.
- No local chat template, tokenizer, DSML parser, or explicit stop sequence is
  involved on either path. Image skills omit temperature, completion budget,
  and reasoning effort; the eval can explicitly set temperature and effort.
  The controls below omit all three to isolate tool choice.
- Image summaries fall back to nonempty response text when structured summary
  parsing fails. This explains why malformed DSML became a visible artifact.
  The supplied response contains no summary arguments to recover by stripping
  tags. The workaround does not add a speculative DSML recovery parser.

## Controlled live responses

All rows use `deepseek-v4.1-flash`, the same tool schema when present, and
`stream: false`. The image is the supplied screenshot, which itself contains
DSML. Its text-only control contains a short PR description and **no DSML**.

| Input | Tool choice | Result |
|-------|-------------|--------|
| Text | No tools | Prose summary; `finish_reason: stop` |
| Text | Named function | Literal malformed DSML; no `tool_calls`; `stop` |
| Image (PNG MIME) | No tools | Detailed visual description; `stop` |
| Image (PNG MIME) | Named function | Literal malformed DSML; no `tool_calls`; `stop` |
| Image (PNG MIME) | `auto` | Structured `publish_entry_summary`; `tool_calls` |
| Text | `required` | Literal malformed DSML; no `tool_calls`; `stop` |
| Image (PNG MIME) | `required` | Literal malformed DSML; no `tool_calls`; `stop` |
| Text, rerun | `auto` | Structured summary; all three fields pass the app contract |
| Image (JPEG MIME on PNG bytes), rerun | `auto` | Structured summary; all three fields pass the app contract |

A separate **streaming** comparison showed a transport-specific manifestation:
named choice returned a parsed `publish_entry_summary` call with empty `{}`
arguments; automatic choice returned real analysis in all three arguments.
That automatic streaming sample's `oneLiner` was 145 characters, exceeding the
app's 140-character limit, so it would be rejected by `parseEntrySummaryToolCall`.
The two buffered automatic image samples had valid 104- and 109-character labels.
This workaround addresses missing analysis under forced choice; it does not
guarantee model adherence to every field constraint. Image skills in the app
use the buffered path through their impact collector.

The empty streamed arguments also argue against merely stripping tags as a
fix: the forced response lacks the required data even when a parser recognizes
the call. Provider-side diagnosis should compare forced generation/template
handling with automatic mode, then compare its buffered and streaming parsers.

Forcing the function produced this **content field**, before any SDK parsing:

```text
<｜DSML｜ invoke name="publish_entry_summary">true</｜DSML｜ invoke>
</｜DSML｜ calls>
```

The automatic image request returned one structured call with all three
nonempty string arguments. Its summary began:

```text
## What the screenshot shows

A dark-mode screen capture, timestamped **Sep 12, 2026 12:00**, containing two
stacked regions: a browser window and a note-taking app's response panel.
```

These examples establish successful response structure and substantive image
analysis, not perfect OCR or factual accuracy. Repeated invocations alone do
not prove an EOS configuration defect: the failed controls returned `stop`,
not `length`, and did not exhaust a client-supplied token limit.

The rerun image label was:

```text
Screenshot of GitHub PR #4233 in matthiasn/lotti, plus an assistant panel showing raw tool-invocation markup.
```

Local HTTP captures are in `build/deepseek_image_probe/`: the authenticated
baseline, `required`, `after`, and `streaming` subdirectories. They are ignored
by Git and are not published. Seven Dart tests cover the workaround and its
boundaries; the six request-path regressions also fail with the workaround's
four request-site applications removed.

DeepSeek's [official V4.1 encoding reference](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash/blob/main/encoding/README.md)
documents changed DSML tags and a shared text/vision encoding implementation.
An outdated upstream implementation remains a possible explanation; it was
not inspected. Melious [documents](https://melious.ai/docs/reference/chat-completions)
named, automatic, and required tool choice on this endpoint.

## Reproduce

The probe uses only the Python standard library. It never executes a returned
tool. It prints and saves the complete HTTP response body, including DSML and
any provider reasoning fields, before SDK interpretation. These are HTTP
bytes, not internal model token IDs. Request artifacts omit image data and
credentials; response artifacts can contain descriptions of the supplied image.
Keep the output local and outside version control.

```sh
python3 tool/deepseek_image_probe.py \
  --env-file .env --image /absolute/path/screenshot.png \
  --output build/deepseek_image_probe/baseline

# Working mode, using the app's JPEG declaration on the same PNG bytes:
python3 tool/deepseek_image_probe.py \
  --env-file .env --image /absolute/path/screenshot.png \
  --cases text-auto image-auto --declared-mime image/jpeg \
  --output build/deepseek_image_probe/after

# Other dimensions, one at a time:
# --cases text-required image-required
# --stream --cases image-forced image-auto
# --temperature 0

python3 -m unittest tool.deepseek_image_probe_test
```

Use `MELIOUS_API_KEY` or `UP_UPSTREAM_API_KEY`, either in the environment or
the specified env file. Environment settings take precedence. Authentication
failures are saved verbatim and result in a nonzero exit; they do not count as
model observations. Initial attempts using the older Greifswald env returned
401; the authenticated controls used this checkout's configured env file.

The production workaround and its deliberately limited scope are documented
in [provider routing](../knowledge/features/ai/provider-routing.md).
