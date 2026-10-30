# ADR 0148: Embeddings Run Only on the Device

- Status: Accepted
- Date: 2026-10-30
- Builds on: [ADR 0144](./0144-on-device-embeddings-use-embeddinggemma.md),
  which chose EmbeddingGemma-300m q4 for on-device embeddings
- Concept: [embeddings and search](../../knowledge/features/ai/embeddings-and-search.md)

## Context

Semantic search embedded text through a local Ollama server
(`mxbai-embed-large`, 1024 dimensions): it worked on a desktop that runs one
and nowhere else. ADR 0144 chose the model to run inside the app instead, and
the app now has its tokenizer in Dart and its ONNX embedder, with vectors that
match ONNX Runtime in Python.

Two providers would mean two vector widths — an ObjectBox HNSW index has the
width of its model compiled into the entity — two failure models (an Ollama
endpoint that goes away and comes back, a model file that is or is not on the
device), and a setting to choose between them. The weights are distributed
under the Gemma Terms of Use, not an open-source licence, which the user has
to be able to read before downloading them.

## Decision

1. **The on-device model is the only embedding provider.** The Ollama
   embedding path (`OllamaEmbeddingRepository`, its availability circuit and
   `mxbai-embed-large` in the Ollama model catalogue) is removed. Ollama stays
   a chat and transcription provider.
2. **The model is downloaded only when the user asks**, from the "generate
   embeddings" flow, which shows its name, its size and a link to the Gemma
   Terms of Use. Its files are pinned by revision, size and SHA-256 and are
   published only once verified. Until the download is done nothing is
   embedded, search finds nothing, and none of it is an error.
3. **One store per model.** The index lives in a directory named for the
   model; the retired 1024-wide stores are deleted at start, since they cannot
   be opened with the current entity and match no query the current model
   makes. The backfill rebuilds the index.
4. **Embedding indexing records its work and its vector, without
   interactions.** No provider is called and nothing is consumed, so the
   consumption ledger gets no row per chunk.
5. **Every writer is gated the same way**: the embeddings flag and the model
   on this device — the task agent's report writer included, which until now
   was gated only by an Ollama provider existing.
6. **Only where the model runs off the UI thread**: macOS, iOS, Linux and
   Android, the platforms on-device speech already runs on. The ONNX plugin
   answers on Windows' platform thread, which would freeze the window for each
   chunk indexed; there the pipeline does not start until the plugin gets the
   worker that macOS and Linux have.

## Consequences

- Semantic search works offline on macOS, iOS, Linux and Android, after one
  download of about 218 MB per device. Windows has none until its plugin runs
  inference on a worker; a Windows user who had Ollama embeddings loses them.
- A device that had Ollama embeddings starts from an empty index; the user
  downloads the model and runs the backfill from Maintenance.
- A later model change gets a directory and an entity of its own and runs
  through `tool/embedding_eval` first.
- Every device embeds its own copy of the journal. Syncing the vectors,
  keyed by entry, content hash and model, would spare devices that work,
  phones above all; that is a separate decision.
