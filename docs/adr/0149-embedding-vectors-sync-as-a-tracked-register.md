# ADR 0149: Embedding Vectors Sync as a Tracked Register

- Status: Accepted
- Date: 2026-10-30
- Builds on: [ADR 0148](./0148-embeddings-run-only-on-the-device.md), which
  left syncing the vectors as a separate decision, and
  [ADR 0136](./0136-ai-configurations-carry-vector-clocks.md), whose tracked
  register this follows
- Concept: [embedding vectors sync](../../knowledge/features/ai/embedding-vector-sync.md)
- Plan: [2026-10-30 embedding vector sync](../implementation_plans/2026-10-30_embedding_vector_sync.md)

## Context

Every device embeds its own copy of the journal, and only what it writes: an
entry that arrives by sync is not embedded until it is next edited locally or
a backfill covers it. On a phone that backfill is the whole journal at about
50 ms of model time per chunk. The device that wrote an entry has already done
that work.

Vectors are derived data: a vector of a text the receiver does not have yet
must not be searchable as if it described the text it has, and a vector of a
deleted entry must leave every index. Untracked, last-write-wins delivery would
lose a version on a dropped message with nothing to repair it.

## Decision

1. **Vectors sync, behind `sync_embeddings`, off by default.** It needs
   `enable_embeddings` as well. A changelog entry comes when the flag is first
   turned on by default.
2. **A tracked register per entry and model.** `<entityId>|<modelId>` has its
   own vector clock and a sequence type of its own
   (`SyncSequencePayloadType.embeddingVectors`, appended): reservation and bind
   at enqueue, receipts on arrival, gap discovery, backfill, deep backfill, and
   sequence-log population after a restore. Only the device that embeds, or
   removes, bumps the clock; receivers merge it.
3. **The unit is the entry's complete chunk set.** A version replaces every
   chunk atomically, with its register row in the same ObjectBox transaction,
   so no receiver keeps a mix of two chunk sets.
4. **The receiver stores only what describes its own text.** The source clock
   and the content hash travel with the version; a version is stored only when
   the receiver's copy hashes the same, held — persisted — until the entry, the
   report or a task's label arrives, and discarded once the entry moved past
   it.
5. **A deterministic merge.** Of two concurrent versions the larger source
   clock wins in the canonical order, then a tombstone over live vectors of the
   same text, then the lower host. The rule reads the two versions only, never
   the receiver's text, so every device keeps the same winner.
6. **Every removal is a tombstone version**, whose row a receiver keeps. A
   deletion announces itself even from a device that never held the vectors,
   with the deleted version as its source, and nothing is embedded over a
   tombstone that covers the entry's version.
7. **A gzipped JSON attachment, one file per version, travelling alone.**
   Float32, with `dims` in the payload; the row's subject keeps it out of
   bundles, so an older build replays only that row. Priority low.
8. **Add Device sends the vectors after the onboarding End barrier**, outside
   the history sweep, and a device that first becomes able to store for a model
   runs one deep backfill round of the vectors alone.
9. **Windows neither sends nor receives** until its ONNX worker lands.

## Consequences

- A phone can search what a desktop embedded as soon as the entry and its
  vectors arrive; it still needs the model to embed the query.
- Every embed and removal spends a counter of its host while sharing is on,
  and a deleted entry costs one tombstone message.
- Vectors travel as far as their entry: inside the user's end-to-end encrypted
  room, from verified devices only.
- Entries written with the flag off, on Windows or without the model stay
  unembedded on receivers until a local edit or a backfill; whether receivers
  should embed those in the background is open.
- `EmbeddingVectorSync` (TLA+) checks the merge; `SyncPipeline` runs the family
  through the transport.
