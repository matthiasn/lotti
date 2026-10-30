# Embedding vectors sync between a user's devices

Date: 2026-10-30
Status: plan, for an implementing agent; not started
Builds on:
- [ADR 0144](../adr/0144-on-device-embeddings-use-embeddinggemma.md): the model;
- [ADR 0148](../adr/0148-embeddings-run-only-on-the-device.md): on-device is the only provider, and it names this as a separate decision;
- [embeddings and search](../../knowledge/features/ai/embeddings-and-search.md): the pipeline;
- the sync concepts under [`knowledge/features/sync/`](../../knowledge/features/sync/).

## Goal

One device's embedding work serves every device. Today each device embeds what
it writes and nothing else: `EmbeddingService` listens only to
`localUpdateStream`, so an entry that arrives by sync is never embedded on the
receiver until someone runs the manual backfill. On a phone that backfill is
the whole journal, about 50 ms of model time per chunk.

After this change:

- **The writing device shares what it embeds.** It embeds an entry as it does
  now, then sends the vectors to the user's other devices.
- **Receivers store them.** A device stores a received vector only when its own
  copy of the entry is the text the vector was made from.
- **Search works on arrival.** A phone can search an entry by meaning as soon as
  the entry and its vectors have arrived, without embedding it. It still needs
  the model, because the query is embedded on the device.

**Owner decisions** (2026-10-30, in the session that produced this plan):

- vectors sync;
- this comes before hybrid ranking;
- the Windows ONNX worker stays earmarked for later. Until then Windows runs no
  embedding pipeline and neither sends nor receives vectors.

## What the code gives us (verified on `091db0121d`)

**Message model**

- The `SyncMessage` union is in `lib/classes/sync/sync_message.dart` (freezed,
  `SyncMessage.fromJson`).
- Whole entities travel by reference: `journalEntity` and `agentEntity` carry a
  `jsonPath` and an `attachmentEventId`, the JSON uploaded as a Matrix file
  (gzipped, `com.lotti.encoding`).
- No variant carries derived or cacheable data today.
- Untracked last-write-wins variants (`syncNodeProfile`, `gitHubAccount`,
  `companionCustomization`) are the precedent for data the sequence log does not
  track; their only guarantee is delivery (ADR 0132).

**Adding a variant:** the compiler enforces every exhaustive switch.

- `priorityForMessage` in `lib/features/sync/outbox/outbox_scheduling.dart`;
- the enqueue dispatch in `lib/features/sync/outbox/outbox_service.dart`
  (`enqueueSimple` handles untracked rows);
- apply, in `lib/features/sync/matrix/sync_event_processor_apply.dart`;
- `QueueApplyAdapter.writesJournalDb` in
  `lib/features/sync/queue/queue_apply_adapter.dart`;
- tracked kinds also append to `SyncSequencePayloadType`. Its ordinals are
  persisted, so only append.

**Apply path**

- Apply happens on the UI isolate, even with `use_isolate_sync` on (ADR 0142),
  so an apply arm can write ObjectBox directly.
- Leases are redelivered, so apply must be idempotent.
- The template for a feature-owned apply is an injected sink:
  `SyncedGitHubAccountSink` in `sync_event_processor.dart`, wired in
  `lib/get_it_sync.dart`. That keeps sync from importing the AI feature.
- `onJournalEntityApplied` on `SyncEventProcessor` is a hook after every journal
  apply.

**Sending**

- Media attachments travel alone, never in a bundle (`outbox_processor.dart`,
  `claimNextBatch`).
- The inline body is capped at 60 000 bytes (`tuning.dart`), which leaves about
  30 KB of JSON.
- A row too large to send ends in `error` for good.

**Old builds**

- A build that predates a variant cannot decode it. It records it as
  `undecodable` and replays it at every start, up to 50 times.
- A bundle holding an unknown child is replayed whole (ADR 0132).

**Hashes**

- The receiver can recompute the content hash from its own entity with
  `EmbeddingContentExtractor`.
- Task text includes label names resolved from local label definitions, so a
  label that has not synced yet changes the hash.
- A category change does not change the hash; the vector moves shard instead.
- Agent-report vectors are keyed by task, and their text lives in the agent
  database.

**Ordering:** nothing guarantees that a vector arrives after the entity version
it was made from. Claim order (priority, then `createdAt`) makes it likely but
not certain.

## Design

### 1. One message per embedded entity, untracked, as a file

Add a variant:

```dart
const factory SyncMessage.embeddingVectors({
  required String entityId,
  required String entityType,    // kEntityType* as stored
  required String modelId,       // 'embeddinggemma-300m-q4'
  required String contentHash,   // sha256 of the embedded text
  required String jsonPath,      // the vectors, as an attachment
  String? attachmentEventId,
  String? categoryId,
  String? taskId,                // agent reports
  String? subtype,               // agent reports
  String? originatingHostId,
}) = SyncEmbeddingVectors;
```

**The vectors travel as a gzipped JSON attachment**, the way `journalEntity`
does:

```json
{"dims": 768, "chunks": ["<base64 of little-endian float32[768]>", ...]}
```

- **Size:** a chunk is 3 072 bytes raw, so a typical entry of 1–3 chunks is
  about 4–12 KB.
- **Why a file and not inline:** it removes the inline budget, and an attachment
  already travels alone. A vector row is therefore never bundled, and an older
  build replays only that row, never a bundle of journal rows. The implementer
  must confirm in `claimNextBatch` that a JSON attachment row (not only a media
  row) travels alone. If it doesn't, add that rule for this variant.

**Untracked: no vector clock, no sequence log, no deep backfill.**

- A vector is regenerable. If one is lost, the receiver embeds the entry itself
  at its next local edit, or during a backfill. That costs a few hundred
  milliseconds, so a sequence entry per embed isn't worth it.
- This follows the precedent of `syncNodeProfile` and `gitHubAccount`.
- Priority: low (`outbox_scheduling.dart`), behind journal entities, so the
  entry usually arrives first.

**Float32, not quantized.** ADR 0144 measured float32 vectors. Quantizing to
int8 would quarter the size, but it needs its own measurement on
`tool/embedding_eval`. Leave it as a follow-up, and keep `dims` in the payload
so a later format can be told apart.

### 2. Who sends

The device that embedded the text, right after the store write:

- `EmbeddingProcessor._embedChunks`, after `replaceEntityEmbeddings`, hands the
  generated vectors to an injected `EmbeddingShare` callback. This covers
  `processEntity` (service and backfill) and `processAgentReport`.
- The sync side (`get_it_sync.dart`) implements the callback and enqueues the
  message.
- Nothing is sent when:
  - the vectors came from sync (no echo: the sink stores without calling the
    callback);
  - sync is not set up (a guest profile, or no sync capability);
  - the new flag below is off.

**Deletions do not sync as messages.** Every device already deletes vectors for
an entry that is gone or too short when it processes that entry. A vector stored
for a deleted entry is skipped by search, as it is today. Keep it that way.

A new config flag, `sync_embeddings`, off by default in the first release,
gates sending and accepting. `enable_embeddings` must be on as well.

### 3. Who stores: the receiver checks the hash

The apply arm calls an injected `SyncedEmbeddingSink`, defined in sync and
implemented in the AI feature, and returns `null`. It does not write the
journal: `writesJournalDb → false`. The sink:

1. Drops the message unless all of these hold:
   - `enable_embeddings` and `sync_embeddings` are on;
   - the pipeline is registered;
   - `modelId` equals the local `OnDeviceEmbeddingRepository.modelId`.
   It needs the model files only for queries, not to store, so a device that
   hasn't downloaded the model still stores vectors. Its index is ready the
   moment it downloads.
2. Reads the attachment and checks it (`dims == kEmbeddingDimensions`, every
   value finite). It rejects anything else.
3. Recomputes the content hash from its own copy:
   - **A journal entity:** use `journalDb.journalEntityById` and the same text
     extraction `EmbeddingProcessor` uses, label enrichment included. Factor
     that extraction out so both sides call one function.
   - **An agent report:** use the report's content from the agent database.
4. Compares:
   - **Hashes equal:** store under the entity's lock (`EmbeddingProcessor`'s
     per-entity serialization), with the sender's chunks, model id and hash. An
     agent report also runs the task's one-report cleanup (#4879).
   - **Hashes differ, or the entity is missing:** hold the message, keeping only
     the newest per `(entityId, modelId)`. Hold it in memory, bounded (for
     example 2 000 entries). When `onJournalEntityApplied` fires for that
     entity, run step 3 again.
   - **A restart loses what was held.** That costs a local embed, nothing else.
5. Is idempotent: a stored row whose hash already matches is a no-op. That
   covers lease redelivery.

**Receivers still do not embed synced edits.** That's today's behaviour, and it
stays: a missing vector is filled by the next local edit or the backfill.
Whether a receiver should embed synced entries that never got vectors is a
separate question; see Residuals.

### 4. A new device

Add a vectors phase to the Add Device history (`historical_sync_service.dart`,
`ReSyncPhase`), after journal entities:

- it walks the local store;
- it sends one `embeddingVectors` per stored entity whose hash still matches the
  local text.

Vectors staged before the onboarding End barrier would delay End, because they
are low priority. Stage them after End, and the new device stores them as they
arrive.

The manual backfill on a device that just received vectors skips those entries
already: their hashes match.

### 5. Privacy and trust

- Vectors stay inside the user's end-to-end encrypted room. They are accepted
  only from verified devices, like every other message.
- A vector reveals roughly what its text says, so it goes exactly where its
  entry goes.
- Before sending, check how private entries and private categories travel today.
  Vectors must follow the same rule, never wider.

## Implementation slices

Each slice is one PR, green on CI with codecov ≥ 99 % on the patch, and covers
the knowledge docs it touches.

1. **Message and plumbing.**
   - The variant, `priorityForMessage` (low), the enqueue path (untracked,
     attachment), a `writesJournalDb → false` arm, an apply arm calling the
     injected sink (null sink: drop).
   - The `sync_embeddings` flag, seeded off.
   - Tests:
     - encoding and decoding;
     - the row travels alone;
     - an old-build decode failure stays one row, never a bundle.
   - Docs: `message-model.md` (the variant list, and the untracked set),
     `send-path.md`.
2. **Sending.**
   - The `EmbeddingShare` callback from `_embedChunks`, implemented in sync.
   - The attachment writer: float32 to base64, gzipped.
   - No echo for synced vectors; flag gating.
   - Tests:
     - one message per stored embed;
     - nothing when the flag is off, when sync is absent, or when the vectors
       arrived by sync;
     - the agent-report path.
3. **Storing.**
   - The `SyncedEmbeddingSink`, with the hash check against the receiver's own
     text, the shared text extraction, the held-message map and its re-check on
     `onJournalEntityApplied`, the agent-report variant, and validation.
   - Tests:
     - match → stored;
     - mismatch → held, then stored after the entity applies;
     - a label difference keeps it held;
     - a wrong model id or dims is dropped;
     - redelivery is a no-op;
     - the bound holds the newest per entity.
4. **Add Device phase.**
   - The vectors phase after journal entities and after End.
   - Tests on `historical_sync_service`.
5. **TLA+ and docs.**
   - Extend `specs/tla/EmbeddingFreshness.tla` with a `SyncVector` actor
     (send after store, arrival in any order, the hash check, holding, and
     loss), under the practice in `specs/tla/README.md`:
     - fix switches;
     - mutations, each with its counterexample;
     - the ledger row.
   - Properties:
     - a stored vector always matches its entry's current text on the device
       that stored it;
     - nothing reaches the index from an unverified device.
   - Update `knowledge/features/ai/embeddings-and-search.md`: the residual
     "synced edits are not embedded" now reads "synced edits arrive with their
     vectors".
   - Add a new ADR recording the decision. Number it from `docs/adr/` at the
     time.

A changelog fragment comes when the flag is first turned on by default, not
before.

## Verification beyond unit tests

- **Two-device integration:** `integration_test/` has a Matrix two-device
  harness (`matrix_service_test.dart`, run with Docker). Alice embeds an entry;
  Bob receives it and finds it by meaning without embedding. Add this as an
  opt-in case: it needs the model, like `embedder_parity_test.dart`.
- **Mixed versions:** a build without the variant receives the messages, logs
  each one as undecodable, and retries only those rows. Check it with a
  fixture, not a second build.

## Residuals

- **Synced entries that never got vectors** (sent before the flag, or lost)
  stay unembedded on receivers until a local edit or a backfill. A later step
  could let a receiver with the model embed those in the background, on a
  charger.
- **Label renames** change task hashes on every device, so the next local
  edit's vectors replace the old ones everywhere. The task is unsearchable
  only in the window before that.
- **Windows** neither sends nor receives until its ONNX worker lands
  (earmarked).
- **Int8 vectors** are left out; they need their own measurement first.
