# Scoped query latency evaluation

The target is the **most directly linked task in the shipped English penguin
world**, selected by counting unique visible neighbors in both directions.
The evaluator seeds the unmodified `ManualDemoWorld.penguinLogistics` at
`manualDemoNow` into real in-memory journal and FTS databases. It runs the
production `QueryAnswerBuilder`, access checks, crawler and
`QueryTextInference.forProfile` transport. It does not read a user's database,
add convenient meeting notes, or supply ideal answers as conversation history.

The current winner is **Inspect orbital penguin habitat**, with 17 neighbors.
The task and permitted readable direct neighbors are only **12 documents and
1,201 source characters**: five neighbors belong to another category, and one
cover image has no text. The fixture test verifies these counts, the winner,
and the actual database retrieval. A changed demo world requires deliberate
review of the questions and assertions. This small home corpus makes needless
round trips visible; it does not model a task with hours of recordings.

## Reproduce

```sh
python3 tool/penguin_query_eval.py \
  --model deepseek-v4.1-flash --variant home-batched \
  --output /tmp/lotti-query-eval/deepseek-v4.1-flash-batched-1.json
```

The runner reads `MELIOUS_API_KEY` and `MELIOUS_BASE_URL` from the environment,
or those two keys from the repository's ignored `.env`. Existing environment
values take precedence. `QUERY_EVAL_API_KEY` and `QUERY_EVAL_BASE_URL` are
explicit overrides. It never executes dotenv text as shell code. The model
must be explicit; this eval does not guess the model selected in the app.
Artifacts and raw process logs must be outside the repository. Do not publish
raw provider logs without inspecting them for sensitive material.

The normal test suite skips live inference. Run only the offline fixture and
instrumentation checks locally:

```sh
fvm flutter test test/features/ai/eval/penguin_query_eval_test.dart
```

Use `--cases local,follow_up` for a smaller run. The follow-up requires the local
case in the same invocation. `--home-only --cases local,follow_up` measures the
home-only option. Add `--legacy-flow` to force the original planning, preview,
window and memory-selection path with a one-byte batch budget. This control
uses the same transport and checkout as the optimized variant; it is not an
unmodified-main binary. Use distinct variant names and output files. Do not use the
wider-category case to judge that deliberately restricted variant.

## Questions and checks

| Case | Question intent | Ground truth |
|---|---|---|
| `local` | Overnight pressure and completed roll call | Linked seal-walk note records 101.3 kPa and all 37 penguins. |
| `follow_up` | “Where was the sleeping one?” | Cargo netting; receives the preceding **actual** answer and its generated memory. |
| `wider_category` | Rehearsal overrun outside the home links | A same-category note records nine minutes long at the boarding step. |
| `absent` | Agreed habitat insurance price | Not present. Must acknowledge the missing evidence. |
| `category_boundary` | Bay C humidity rise | Nine points exists only in another category, despite a direct task link. Must not disclose it. |

Every positive result must contain the expected facts and relevant exact
quotes, cite evidence, and retain source fingerprints and category boundaries.
The wider answer must attribute its evidence as outside home. Negative cases
must acknowledge the missing information and return no evidence cards. This
last gate is intentionally conservative: inspect a negative case with partial
context manually instead of relabeling it a provider failure. These vocabulary
and provenance checks are useful gates, not a semantic judge. Review each
answer for unsupported claims, omitted qualifications and citation entailment.

## Measurements and limits

The JSON records source-code hashes, selected model and provider, corpus
ranking, question-to-built-answer wall time, time when final answering begins,
per-completion stage/duration/input characters/output characters, provider
input/output/reasoning/cache tokens and billing credits when available, shortlist
candidate count, inspected-source count, coverage, answer and evidence checks.
Each case allows at most eight source inspection calls and twelve completions;
the process stops after fifteen minutes. Authentication failures stop the run.
The existing production two-minute completion timeout still applies.

The measured interval excludes fixture seeding, app startup, chat persistence
and widget rendering. Per-call duration includes transport, generation, JSON
parsing and thinking removal. Character counts are separate from the provider token counts. It does not
measure first-token latency.
The final answer is buffered by the production path; build completion is the
first complete answer available to its caller. Provider cache and concurrent
server load are uncontrolled. Run at least three sequential samples on the
same model before comparing medians and ranges, and keep cold and warm results
visible instead of pooling model IDs.

HTTP/provider errors are failed setup or transport observations, never fast
successful answers. The initial 2026-09-12 run received HTTP 401 from the
configured Melious credential before any model completion. It therefore
establishes **no response-time baseline**. That sample is excluded. The requested comparison is `glm-5.3`, `glm-5.3-flash` and
`deepseek-v4.1-flash`, using a valid credential and sequential calls. A later
GLM-5.2 attempt was cancelled at the user's correction and is also excluded.

Usage is collected through `QueryTextInference.forProfile`'s existing
`AiInteractionCapture` hook, with the shared in-memory accounting test bench.
This preserves the production transport and returns provider-reported token
counts and Melious credits without storing private request bodies. The report
records the explicit variant and sampling settings. There is no app model row
in this synthetic setup: temperature is 0.2, and token/thinking limits use
provider defaults. Missing provider metrics remain null.

## Implemented retrieval change

For a task or project whose home input fits 12,000 source characters and
24,000 UTF-8 bytes including instructions and chat context, one isolated
inspection request interprets the question, extracts exact passages, selects
eligible memories and reports sufficiency. Only accepted evidence reaches the
separate synthesis request. This fitting-home path needs two completions.
Insufficiency, incomplete home coverage or an explicit wider question enables
the existing category-scoped discovery. Already inspected representations are
deduplicated using source ID, fingerprint, representation version and date.
Fitting remaining entries share a second inspection request.

Category queries and oversized inputs retain bounded preview/window retrieval.
The new path does not yet pack large corpora into multiple batches or reuse
source inspections across questions. Each question still refreshes home access;
follow-ups fold memory selection into inspection. Source bytes are sorted by
ID and precede the changing question for a stable prefix when sources are
unchanged. This is not reuse of the task agent's wake prefix.

The live runs also exposed a cancellation defect: the two-minute query deadline
could wait for a buffered HTTP call's five-minute timeout. Capture now owns the
provider subscription directly, and buffered Melious calls use a request-scoped
abort trigger. Cancellation does not close the shared client or abort sibling
requests. This is separate from incremental answer streaming.

## Follow-up chronology correction

The prepared harness originally assigned every event `manualDemoNow`. After
PR #4236 added the retry cutoff, same-time ID ordering could exclude the actual
preceding memory from a follow-up. The corrected harness places the actual
answer and memory one second after their question, and the follow-up one second
later. It never seeds an ideal answer. A regression verifies both actual-object
identity and ordering relative to the production cutoff, and fails when the
clock correction is reverted.

Earlier artifacts remain retained, but their follow-up times do not establish
memory recall performance. Corrected reports identify `turnOrdering`,
`memoryCandidateCount`, `legacyFlow` and the batch byte limit. Compare the
corrected variants with one another. The corpus and expected facts did not
change.

## Wake-prefix investigation (merged main, 2026-09-12)

Direct reuse is not safe for this change. `TaskAgentExecute` selects either
`buildTaskStateMarkdown` plus `memoryView.compactedLog`, or the older full
`buildTaskDetailsJson` path. A compacted log is a checkpoint summary plus the
uncovered event tail, not all current whole-entry representations. The wake
starts with its task-mutating system prompt and tool definitions; query
inspection starts with its isolated evidence-inspection system prompt and no
tools. Copying just a later user-message block does not establish an identical
request prefix. Copying the entire wake request would carry different
instructions and would need independent live category/privacy authorization.
No measured cache-reuse benefit is claimed. Keep a fresh bounded inspection
request, and retain provider-reported cached-token metrics separately.

Task/project summaries do exist. `AgentReportEntity` persists `oneLiner`,
`tldr`, and `content` (older reports may omit the first two). Resolve task IDs
through `AgentRepository.getLatestTaskReportsForTaskIds`, which batches the
agent-task links and current report heads. Parent project reports use
`getLatestProjectReportForProjectId`. The wake builder already loads linked
summaries in bulk and annotates directed relations; those summaries sit in the
wake's volatile tail so a neighbour update cannot invalidate its earlier log.
These assets can orient query inspection but cannot replace exact entry spans.

The merged handover is the implementation direction: fitting home batching,
chat-stable same-category neighbourhood orientation, insufficiency-driven
expansion, then secondary overhead. Budget-extension and cost UI follow the
retrieval change as a separate surface change. Ordinary report updates may
leave orientation stale; privacy, deletion, lockdown and category changes must
still invalidate its use immediately. Agent-to-agent questioning is deferred.

The canonical corpus has no guaranteed precomputed agent reports. Missing
reports must remain explicit absences; never invent summaries for a live eval.
Use deterministic report fixtures to test orientation independently, and keep
the shipped penguin world unchanged for the original comparison.


## Separate synthesis-streaming follow-up

After retrieval is measured, a separate PR will stream synthesis only. The
inspection response stays disposable and hidden. Draft prose is explicitly
provisional, citation links remain unavailable until validated, and successful
publication must preserve the displayed text byte-for-byte. Validation failure
retracts the draft visibly into the existing per-question Retry path. Privacy
changes, cancel, delete and forget cut the stream and clear all provisional
state; no draft text is persisted or sent to TTS. Unsupported routes retain
buffering and the selected model. Measure first synthesis token separately from
total built-answer time. Provider impact availability on streaming responses
must be checked rather than silently dropping accounting. This follow-up does
not change discovery, inspection, evidence or memory semantics.


## Summary authorization gap

The standard report writers (`WakeOutputWriter` and `ProjectAgentExecute`)
record inference/accounting provenance, but no complete set of contributing
journal source references. Owner-task visibility alone therefore cannot prove
that a retained report excludes an entry subsequently hidden, deleted, or moved
to another category. The legacy task-input reader applies the privacy setting
at the time of that wake; that is not a durable authorization record for later
query use. Compacted history and other agents' reports make reconstructing the
complete dependency set from current links insufficient.

The retrieval implementation consequently does not inject stored report text.
The safe summary follow-up needs complete transitive source dependencies and
live access validation, with unknown provenance failing closed. This limitation
also rules out importing the task wake's cached context wholesale. 

## Measured GLM-5.3 comparison (2026-09-12)

Three sequential samples per variant, interleaved legacy → batched → legacy home-only.
All use the corrected event chronology, the same production transport, temperature 0.2,
provider-default thinking/token limits and the unmodified corpus. These are successful
question-to-built-answer durations, excluding fixture setup and UI publication.

| Variant | Case | Raw seconds, sample order | Median [range], seconds | Calls | Median provider credits | Median provider kWh |
|---|---|---|---|---|---|---|
| `clocked-legacy` | `local` | 7.554, 10.499, 6.331 | 7.554 [6.331–10.499] | 9, 10, 9 | 0.0073618 | 0.0019372 |
| `clocked-legacy` | `follow_up` | 4.201, 6.289, 2.337 | 4.201 [2.337–6.289] | 8, 10, 6 | 0.0052820 | 0.0011960 |
| `clocked-legacy-home-only` | `local` | 7.717, 5.614, 4.852 | 5.614 [4.852–7.717] | 8, 9, 9 | 0.0040044 | 0.0016228 |
| `clocked-legacy-home-only` | `follow_up` | 5.049, 3.896, 2.697 | 3.896 [2.697–5.049] | 7, 7, 7 | 0.0038260 | 0.0011170 |
| `clocked-batched` | `local` | 2.439, 2.399, 1.770 | 2.399 [1.770–2.439] | 2, 2, 2 | 0.0018894 | 0.0006610 |
| `clocked-batched` | `follow_up` | 2.335, 2.448, 1.294 | 2.335 [1.294–2.448] | 2, 2, 2 | 0.0019304 | 0.0007495 |

Local median falls 68%; follow-up median falls 44%. Median billed credits also
fall, by 74% and 63% respectively. Credits are the provider’s reported unit,
not an assumed euro conversion. Provider energy estimates are reported as
returned, not independently measured power. The first sample is not asserted
cold: earlier requests may have warmed provider caches. Raw token/cache usage
and sample order remain available in each artifact; server load is uncontrolled.

The first full five-case sweep passed every unchanged gate in both variants.
Wider-category latency was 3.206 → 2.859 seconds (6 → 3 completions), absent
8.327 → 2.453 (11 → 3), and category-boundary 9.096 → 2.153 (11 → 3). These
three comparisons have one sample each and are quality observations, not
three-sample median claims. Manual review confirmed the nine-minute boarding
overrun’s exact source, and empty evidence lists with explicit uncertainty for
both negative cases. The local answer retained 101.3 kPa and all 37 penguins;
the follow-up retained the cargo-netting location with exact citations.

The optimized follow-up has one eligible prior memory in every corrected run;
the model may decline to recall it when fresh evidence answers the question.
The legacy control still pays a memory-selection completion in that situation.

Artifacts are named `glm-5.3-clocked-{legacy,batched,legacy-home-only}-{1,2,3}.json`
in the external `query_latency_eval` artifact directory. Each records source
hashes, raw per-call metrics, answers and exact evidence. No generated artifact
or raw provider log is committed.

## Additional model observations

DeepSeek Flash v4.1 remains in the evaluation. Earlier successful optimized
requests used two completions for local/follow-up and three for wider/negative
cases. The latest pre-chronology full sweep returned correct local facts,
cargo-netting location and the nine-minute boarding overrun; both negative
answers had empty evidence. Their uncertainty wording missed the existing
keyword gate, which remains unchanged. Those follow-up timings are not used
for the corrected memory comparison above.

The first corrected DeepSeek rounds returned HTTP 503 in both legacy and
batched paths. They remain failed transport observations, with no speedup
claim. Retries are spaced between other model rounds. GLM-5.3 Flash uses the
same comparison settings and unchanged gates; its measurements are pending.
