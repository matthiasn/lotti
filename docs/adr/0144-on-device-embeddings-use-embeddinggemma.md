# ADR 0144: On-Device Embeddings Use EmbeddingGemma

- Status: Proposed
- Date: 2026-10-29
- Builds on: the embedding pipeline in
  [embeddings and search](../../knowledge/features/ai/embeddings-and-search.md)
  and the full-text index in
  [search index](../../knowledge/features/search/full-text-index.md)

## Context

Semantic search embeds text through a local Ollama server
(`mxbai-embed-large`). A phone has no Ollama, so semantic search works on
desktops that run one and nowhere else, and it is off by default. Search is
meant to work offline on every device, Android and Flathub included, so the
embedding model has to run inside the app.

The app already bundles ONNX Runtime on every platform — the patched
`flutter_onnxruntime` that runs the on-device voice, and `sherpa_onnx` for
speech — at 1.22 (Linux), 1.24.2 (iOS) and 1.27.0 (Android). A model exported
to ONNX needs no new native dependency, only its tokenizer in Dart.

The candidates that run on a phone and speak the app's languages were
measured on Lotti's own retrieval task with `tool/embedding_eval`:
EmbeddingGemma-300m (Google, 2025) and multilingual-e5-small, each in its
published ONNX variants, on ONNX Runtime 1.22 — the oldest the app ships — on
a desktop CPU. Qwen3-Embedding-0.6B was a candidate too; its ONNX export is a
decoder that takes past key/value inputs, not an embedder the runtime can run
as it is, and it is too large for a phone at 570 MB or more.

Two query sets over the penguin demo world's 28 tasks:

- **Paraphrase queries** — 224 searches, two per task in English, German,
  French and Czech, describing a task without its wording. 116 share no
  distinctive word with their task.
- **Membership queries** — the 1,474 checklist items and linked notes across
  all eleven languages, each answered by the task it belongs to.

| Paraphrase queries | R@1 | MRR | No shared word: R@1 | ms/text (1 thread) | File |
|---|---|---|---|---|---|
| BM25 (the app's FTS5 index) | 41% | 0.50 | 4% | — | — |
| **EmbeddingGemma-300m q4** | **79%** | **0.85** | **68%** | 16.8 | 197 MB |
| EmbeddingGemma-300m q4, cut to 256 dims | 72% | 0.81 | 62% | 16.8 | 197 MB |
| EmbeddingGemma-300m int8 | 79% | 0.85 | 71% | 97.4 | 310 MB |
| EmbeddingGemma-300m fp32 | 81% | 0.86 | 73% | 29.8 | 1,235 MB |
| multilingual-e5-small int8 | 63% | 0.74 | 47% | 2.1 | 118 MB |
| multilingual-e5-small fp32 | 68% | 0.78 | 51% | 5.6 | 470 MB |

Per language, EmbeddingGemma q4 reaches MRR 0.92 (en), 0.91 (de), 0.90 (fr)
and 0.66 (cs); every model is weakest in Czech. On membership queries all
models sit near BM25 (MRR 0.63–0.65 against 0.67): a checklist item belongs to
its task by circumstance more than by meaning, which keyword overlap already
captures.

Fusing a model with BM25 by plain reciprocal rank fusion raised the
membership MRR (0.64 → 0.68) but cut the paraphrase MRR from 0.85 to 0.66:
equal weight lets a keyword ranking that has nothing to go on drown out the
semantic one.

## Decision

1. **The on-device embedding model is EmbeddingGemma-300m, `model_q4.onnx`**
   from `onnx-community/embeddinggemma-300m-ONNX`, pinned to revision
   `5090578d9565bb06545b4552f76e6bc2c93e4a66`. It is the most accurate
   candidate that runs on ONNX Runtime 1.22, and the fastest EmbeddingGemma
   variant there (the int8 export is six times slower on CPU; the
   `no_gather` q4 three times). Queries are prefixed
   `task: search result | query: `, documents `title: none | text: `; the
   export's `sentence_embedding` output is the vector.
2. **The app downloads the model when semantic search is turned on**, not in
   the installer: Flathub, APK and store sizes stay as they are, and a user
   who never searches by meaning never fetches 197 MB.
3. **Vectors are stored at the full 768 dimensions.** Cutting them to 256
   costs 0.04 MRR; the saving only matters if vectors ever sync between
   devices, which is not decided here.
4. **The tokenizer is ported to Dart** — EmbeddingGemma's BPE with byte
   fallback, whose normaliser only maps spaces — and must produce the
   reference tokenizer's ids for the whole evaluation corpus.
5. **Hybrid ranking must not fuse BM25 and semantic rankings with equal
   weight.** The fusion step weights the semantic ranking or uses keyword
   matches to break ties, and is tuned on `tool/embedding_eval` before it
   ships.
6. **`tool/embedding_eval` decides model changes.** A new candidate or variant
   is run through it on the pinned runtime before it can replace this one.

## Consequences

- Semantic search can run on every device, offline, without Ollama; the
  Ollama path can remain as an optional provider. Changing the model means
  re-embedding, which the stored model id has to trigger (today it is
  stored but never compared).
- Embedding costs about 17 ms per text on one desktop core. Phone latency is
  not measured here; the provider work measures it on a mid-range Android
  device before the default changes, and a full backfill there is expected to
  take hours, so it runs only while charging and idle.
- 197 MB of model and a 20 MB tokenizer are fetched once per device; the
  tokenizer's 262k-token vocabulary and 515k merges are held in memory while
  the pipeline is active.
- Czech retrieval stays noticeably weaker (MRR 0.66) than the other
  languages; the evaluation tracks it per language so a better model shows.
- **Licence — open.** EmbeddingGemma is released under the Gemma Terms of
  Use, not an OSI licence; Google's own repository requires accepting them.
  Downloading from the ONNX mirror on demand means the app does not
  redistribute the weights, but whether users must see and accept the terms
  (and the prohibited-use policy) before the download is a call for the
  maintainer before the provider ships. multilingual-e5-small (MIT) is the
  fallback if the terms are not acceptable, at MRR 0.74 instead of 0.85.
- The paraphrase queries were written by an LLM-based agent; their phrasing
  may suit LLM-trained embedders. They are committed
  (`tool/embedding_eval/paraphrases.json`) so they can be reviewed, extended
  or replaced by human-written ones.

## Related

- `tool/embedding_eval/` — corpus exporter, evaluation, report and the
  paraphrase set.
