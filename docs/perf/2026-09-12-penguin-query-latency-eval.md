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
or those two keys from the repository's ignored `.env` (or `--env-file`).
The local service aliases `UP_UPSTREAM_API_KEY` and `UP_UPSTREAM_BASE_URL`
are accepted when canonical keys are absent; no other dotenv keys are loaded. Existing environment
values take precedence. `QUERY_EVAL_API_KEY` and `QUERY_EVAL_BASE_URL` are
explicit overrides. It never executes dotenv text as shell code. The model
must be explicit; this eval does not guess the model selected in the app.
Non-local endpoints require HTTPS; HTTP is accepted only for explicit loopback
hosts. Artifacts and raw process logs must be outside the repository. Do not publish
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

For the entry control, every positive result must contain the expected facts and relevant exact
quotes, cite evidence, and retain source fingerprints and category boundaries.
The wider answer must attribute its evidence as outside home. Negative cases
must acknowledge the missing information, return no evidence cards, and avoid
concrete price/humidity values in the answer itself. The English-fixture value
checks catch common numeral and spelled-out currency/measurement forms; they
are not a complete semantic hallucination detector. This
last gate is intentionally conservative: inspect a negative case with partial
context manually instead of relabeling it a provider failure. These vocabulary
and provenance checks are useful gates, not a semantic judge. Review each
answer for unsupported claims, omitted qualifications and citation entailment.

## Measurements and limits

The JSON records the Git commit/tree, a hash of tracked edits, hashes of
untracked files, selected source-code hashes, model/provider, and corpus
ranking, question-to-built-answer wall time, time when final answering begins,
per-completion stage/duration/input characters/output characters, provider
input/output/reasoning/cache tokens and billing credits when available, shortlist
candidate count, inspected-source count, coverage, answer and evidence checks.
Each case allows at most eight source inspection calls and twelve completions;
the process stops after fifteen minutes. Authentication failures stop the run.
The existing production two-minute completion timeout still applies.

The measured interval excludes fixture seeding, app startup, chat persistence,
widget rendering and synchronous artifact-checkpoint writes. The report retains
checkpoint duration and wall time including checkpoints separately. It stops the
built-answer timer before the eval’s own quality checks. Partial checkpoints are
still written before and after each model call so stalled runs remain inspectable.
The Git identity is checked again at the end; a changed checkout fails the run. Per-call duration includes transport, generation, JSON
parsing and thinking removal. Character counts are separate from provider token counts.
With `--stream-synthesis`, first synthesis token and first visible answer text
are measured separately from total built-answer time; publication still waits
for validation. Without that flag, synthesis remains buffered. Provider cache and concurrent
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
Production now selects promising tasks from TL;DRs and reads selected full
reports before answering. It attributes derived answers to owner titles without
exact-entry cards or shared conclusions. Original evidence is a separate own-task
route; asking another task's agent remains deferred. Summary authorization follows
current owner visibility/category and the report lifecycle, rather than a query-side
transitive entry-provenance graph. The runtime contract is in
[query chat](../../knowledge/features/agents/query-chat.md).

## Frozen-summary evaluation

The shipped penguin world has no precomputed agent reports. The original mode
therefore remains explicitly labelled `entry-control`. `--prepare-summary-reports`
creates an additional, query-neutral generated fixture from each task's own
same-category readable linked text. It does not see the eval questions or their
expected answers. This preparation uses live inference but **is not the production
task-agent wake workflow**. Its cost and timings are separate from query latency.
Reports are never hand-corrected to satisfy an answer check.

Use that artifact with `--summary-reports /outside/repo/reports.json` to exercise
the production summary reader, real agent report/head/link storage and the current
summary-first answer builder. Reuse identical frozen bytes across matched samples
and models. The artifact records its hash; source-input hashes reject stale bundles,
and missing/unknown owners or empty report layers fail fixture setup.

```sh
python3 tool/penguin_query_eval.py --model deepseek-v4.1-flash \
  --variant report-preparation --prepare-summary-reports \
  --output /tmp/lotti-query-eval/reports.json
python3 tool/penguin_query_eval.py --model deepseek-v4.1-flash \
  --variant summary-first --summary-reports /tmp/lotti-query-eval/reports.json \
  --stream-synthesis --output /tmp/lotti-query-eval/summary-1.json
```

The same five questions and expected facts remain. Summary answers must carry
owner attribution, same-category dependencies, no original evidence cards, no raw
source inspection and no durable shared memory. Expected exact quotes and citation
numbers remain gates for the entry control only: a derived report is not an original
source. Missing facts in generated reports remain quality failures, not reasons to
edit the fixture or relax expectations. In particular, the wider case explicitly
asks to search notes: summary-first must honestly disclose that notes were not
inspected. Manual review checks entailment, qualifications and owner attribution
in addition to automated vocabulary checks.

Synthesis streaming is merged. Provisional text and first-token measurements are
available for both variants; total latency remains the question-to-built-answer
measurement. This harness does not measure widget rendering, durable publication,
the task-agent summary lifecycle, or real-world long transcripts.

## Summary-first model comparison (2026-09-12)

Three repeats of all five unchanged cases per model used streamed synthesis and
one frozen query-neutral bundle of 28 generated task reports. Eighteen authorized
same-category TL;DRs reached selection. Runtime was merged main `e6763975518e`,
with only harness changes. Every matched invocation verified unchanged checkout
identity. DeepSeek entry/summary controls were interleaved, then GLM-5.3 Flash,
GLM-5.3 and Nemotron alternated each round. Caches and provider load were uncontrolled.

These are **first answer text / complete validated built answer**, median seconds.
Both include selection and retrieval; neither includes widget painting or durable
chat publication. Each numerical cell below has three completed samples.

| Model | Local | Follow-up | Wider category | All gates passed |
|---|---:|---:|---:|---:|
| deepseek-v4.1-flash | 9.84 / 11.30 | 13.64 / 14.88 | 20.43 / 21.67 | 13/15 |
| glm-5.3-flash | 2.06 / 3.02 | 2.22 / 3.03 | 1.87 / 2.82 | 9/15 |
| glm-5.3 | 6.19 / 6.99 | 1.41 / 1.85 | 12.10 / 12.82 | 15/15 |

Nemotron (`nemotron-3-nano-30b-a3b`) passed only 2/15 planned cases: six
`FormatException` failures prevented publication and blocked two follow-ups.
Its only completed local sample took 3.45 / 3.86 seconds; this is **not** a
three-sample successful median. A separate diagnostic replay later passed both
local and wider questions; it is excluded from these matched results and does
not erase the validation failures. The harness now retains parsed synthetic
responses for diagnosing such failures.

GLM-5.3 Flash completed all 15 responses in 2.52–3.93 seconds, but all six negative
cases set `needsHomeEvidence=true`, bypassed the full-summary answer, and inspected
seven own-task originals. No cross-category value was disclosed, but the summary
ladder gates failed. DeepSeek took this fallback once; two price refusals also
missed the unchanged lexical absence gate despite correctly declining to invent a
price on manual review. GLM-5.3 passed all gates, with completion times ranging
from 1.74 to 33.96 seconds. DeepSeek's slowest follow-up took 41.31 seconds,
including 37.94 seconds for selection; keep this outlier visible.

The three DeepSeek entry-control local samples completed in 13.86, 14.23 and
12.47 seconds, versus summary-first 9.47, 11.30 and 13.01. Broader summary-first
questions were slower than that entry control. Do not generalize the local gain
to all queries, or treat the two answer bases as identical products.

Per-call token, reasoning and cache usage are recorded. Melious omitted billing
and energy metadata for streamed synthesis, so complete per-question cost/energy
totals remain unknown. The report-preparation calls took 415.2 seconds separately
from chat timing; they are not task-wake workflow measurements. Long-source and
actual UI/controller timing remain unmeasured.

Raw artifacts use `deepseek-summary-matched-{entry,summary}-20260912-{1,2,3}.json`
and `{glm-5.3-flash,glm-5.3,nemotron-3-nano-30b-a3b}-summary-20260912-{1,2,3}.json`
in the external `query_latency_eval` directory. The full report
`2026-09-12-summary-chat-eval-results.md` retains every sample, range, failed gate,
answer, and token count. The shared report bundle SHA-256 is
`0a707519eac60c94933221181ff50d8a05d52dfb4e663010dd1300909cd4de93`.

## Flash guidance iteration (2026-09-12)

The final shared selection/synthesis prompts passed **33/33** checks with
`glm-5.3-flash`: three repeats of the five original cases (**15/15**, versus
9/15 before) and six additional paraphrase/original-quote cases (**18/18**).
The added cases were used during tuning and are regression cases, not unseen
holdouts. The shipped corpus, frozen reports, canonical questions, expected
facts, forbidden values and production validators were unchanged. No automatic
repair retry or model switch was added.

Review added separate `boldOwnerAttribution` and `requestedVerbatimAnswer`
gates: an unformatted title no longer satisfies the guidance-format check, and
paraphrase with valid evidence does not satisfy the explicit quote request.
The historical attribution gate remains separately recorded. Rechecking the
33 saved final answers against the additional requirements passed; this was
an artifact audit, not another live latency sample. Earlier baseline pass counts
above retain their original gate definitions.

The original guidance let ordinary factual or unanswered questions request raw
home entries. It also left Flash prone to unescaped title quotation marks,
prose outside JSON, and owner IDs without exact title attribution. The revised
selector explicitly keeps missing details on the full-summary path and reserves
the original route for explicit home-task requests. Synthesis puts the JSON
contract first, uses exact bold owner titles and permits a wholly unanswered,
unresolved response without attributed factual claims. These are instructions,
not a new deterministic intent classifier; malformed answers still fail checks.

| Case | First text median [range], seconds | Validated answer median [range], seconds | Calls |
|---|---:|---:|---:|
| Local | 2.523 [1.503–2.822] | 4.004 [2.337–4.530] | 2 |
| Follow-up | 1.503 [1.382–2.194] | 2.733 [2.166–3.273] | 2 |
| Wider category | 1.583 [1.505–1.736] | 2.542 [2.416–2.706] | 2 |
| Absent | 2.356 [1.483–2.483] | 2.960 [2.079–3.128] | 2 |
| Category boundary | 1.758 [1.599–2.359] | 2.324 [2.214–3.110] | 2 |
| Explicit home quote | 6.017 [4.457–6.548] | 6.682 [5.062–7.136] | 3 |

The timing boundary is unchanged: answer callback and validated built answer,
excluding screen painting and chat persistence. Every ordinary final case stayed
on summaries with no original evidence or shared conclusions; the explicit quote
required validated home evidence. Two unnecessary raw-inspection paths were
removed from the original negative cases. The local completion median increased
from 3.02 to 4.00 seconds, while the other original-case medians decreased.
This is a routing/reliability improvement, not a speedup on every question.

Median input tokens for local increased from 4,602 to 5,276 with the longer
contract and different selected owners. Median output tokens across the original
cases were 200–292 after versus 284–442 before. Full cost/energy remains unknown
because streamed synthesis omits those provider metrics. No total cost saving is
claimed. Cache state and service load were uncontrolled.

All failed iterations remain in external artifacts. Reverting only the production
prompts after the final sweeps reproduced failures (**6/11** passed); ordinary
questions again selected raw entries. The final prompts were restored. Manual
review retained the intended facts and uncertainty, but found unnecessary detail
in some refusals and one seals-versus-bays paraphrase. Automated passes therefore
are not a claim of perfect semantic quality or general reliability.

Raw final files are `glm-5.3-flash-guidance-v6-20260912-{1,2,3}.json`, with every
answer and diagnostic in `2026-09-12-flash-guidance-eval-results.md` and
`flash-guidance-v6-aggregates-20260912.json` outside the repository. The same frozen
report bundle and settings as the model comparison above were used throughout.

Single post-change control sweeps also passed **11/11** each for `glm-5.3` and
`deepseek-v4.1-flash`. These are regression controls, not three-sample latency
comparisons. Their total times ranged 1.43–9.30 seconds and 3.80–18.94 seconds
respectively; each artifact records an unchanged checkout.
Manual review found DeepSeek incorrectly treating a missing count in one report
as conflicting with 37 in another. This escapes the current fact/attribution
gates; its automated control pass is not a complete semantic endorsement. The
same weakness occurs in two earlier DeepSeek baseline local answers.

## Historical timing caveat

The numerical tables below precede the checkpoint-I/O correction. Their
`totalMs` includes artifact writes and the eval’s post-build quality checks.
Per-completion durations exclude checkpoint I/O. Across the GLM matched local
and follow-up samples, the entire difference between total time and the sum of
model-call durations is 28–95 ms per question; that includes all database and
other harness overhead, so checkpoint I/O cannot exceed it. This bound is far
smaller than the multi-second observed differences, but it is not a measurement
of the writes themselves. Retain the raw samples; do not silently subtract an
assumed overhead. Future samples record the exact checkpoint exclusion.

Older artifacts also lack the newly added Git identity fields. Their selected
source hashes and recorded checkout history remain available; they must not be
presented as though they had the new provenance or timing schema.

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
same comparison settings and unchanged gates; its results follow below.

## Measured GLM-5.3 Flash comparison (2026-09-12)

Same fixture, transport and parameters. Four original/batched attempts were
retained; the third original follow-up failed with `FormatException` in memory
selection after 7.808 seconds and seven completions. An additional pair was
run instead of counting that failed response as successful latency.

| Variant | Case | Matched sample IDs | Raw seconds for those IDs | Median [range], seconds | Calls | Median credits | Median kWh |
|---|---|---|---|---|---|---|---|
| `clocked-legacy` | `local` | 1, 2, 3, 4 | 14.228, 12.610, 13.592, 17.514 | 13.910 [12.610–17.514] | 10, 10, 11, 11 | 0.00091081 | 0.0046474 |
| `clocked-legacy` | `follow_up` | 1, 2, 4 | 8.770, 8.916, 7.651 | 8.770 [7.651–8.916] | 8, 9, 7 | 0.00081108 | 0.0030360 |
| `clocked-legacy-home-only` | `local` | 1, 2, 3 | 10.620, 11.019, 11.349 | 11.019 [10.620–11.349] | 9, 9, 9 | 0.00051732 | 0.0036255 |
| `clocked-legacy-home-only` | `follow_up` | 1, 2, 3 | 7.316, 6.116, 7.775 | 7.316 [6.116–7.775] | 8, 8, 7 | 0.00040660 | 0.0023182 |
| `clocked-batched` | `local` | 1, 2, 3, 4 | 6.432, 5.579, 5.360, 3.921 | 5.469 [3.921–6.432] | 2, 2, 2, 2 | 0.00028310 | 0.0019579 |
| `clocked-batched` | `follow_up` | 1, 2, 4 | 4.975, 5.162, 3.277 | 4.975 [3.277–5.162] | 2, 2, 2 | 0.00029084 | 0.0018388 |

The third batched follow-up also succeeded (4.625 seconds, two completions);
it is excluded only from the paired follow-up median because its original-flow
counterpart failed. Original follow-up completion success was 3/4 versus 4/4
batched. All other local/follow-up attempts completed and passed the unchanged
gates. These small samples do not establish a long-run reliability rate.

The full first sweep passed automated gates in both variants. Wider retrieval
was 9.364 → 4.181 seconds, absent 9.904 → 2.942, and category boundary
9.449 → 3.152; each dropped from eleven completions to three. These are
single-sample observations. Negative answers had no evidence cards.

Manual review found a pre-existing synthesis weakness in **both** variants:
Flash describes `categoryChecked` as “6 of 8 sources checked” in the original
wider answer and “48 of 60” in the batched answer, although the totals actually
checked are 8 and 60. It also refers to “some categories” despite one-category
retrieval. The stored coverage metadata is correct; the prose is misleading.
This is not a privacy disclosure, but the automated keyword/citation gates do
not detect it. A synthesis-quality follow-up should correct and evaluate this
wording. The Flash follow-up also adds an explicitly labelled, unnecessary
identity inference about the sleeping penguin. Do not treat these automated
passes as a complete endorsement of its answer quality.

In these hosted samples GLM-5.3 Flash was slower than GLM-5.3 but had lower
provider credits. Provider load and cache state differ across model rounds,
so this is an observed tradeoff, not a universal model ranking. Routing is
unchanged. Artifacts are `glm-5.3-flash-clocked-*-{1,2,3,4}.json` outside the
repository, with only three home-only samples.

## DeepSeek Flash v4.1 availability and incomplete matched set

Corrected retry sample 3 completed both paths: local 21.027 seconds / eleven
completions → 8.457 / two; follow-up 20.579 / six → 4.186 / two. Both passed
the unchanged gates and manual review retained exact pressure, roll-call and
cargo-netting evidence. These are one pair, not a three-sample median or a
reliable latency claim. The next original-flow local attempt failed with
HTTP 503 after 41.556 seconds and seven completions; its dependent follow-up
was blocked, and wider/negative requests also returned 503. Earlier corrected
rounds and two spaced probes likewise returned 503. All failed samples remain
in external artifacts and are excluded from successful latency statistics.

DeepSeek is therefore included but the corrected matched comparison remains
incomplete because of intermittent provider availability. Retry with distinct
artifact names; do not pool the earlier equal-timestamp follow-up artifacts
into this set or replace failures with their short HTTP rejection times.
