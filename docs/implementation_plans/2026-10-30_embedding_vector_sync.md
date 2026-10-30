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

**The template for a tracked, versioned register** is the AI configuration
(ADR 0136).

- It appends `SyncSequencePayloadType.aiConfig` (`lib/classes/sync_sequence_payload_type.dart`).
- It has its own vector clock per row.
- It enqueues through `outbox_enqueue_writer_simple.dart`.
- It is answered by `backfill_response_builders.dart` /
  `backfill_response_handler.dart`.
- Deep backfill is `ai_config_deep_backfill_store.dart`, implementing
  `DeepBackfillStore` (`lib/features/sync/deep_backfill/deep_backfill_store.dart`:
  count, changes, page, range, enqueueCurrent).
- It is applied and merged in `lib/features/ai/repository/ai_config_repository_sync.dart`.

Follow that wiring end to end.

**Ordering:** nothing guarantees that a vector arrives after the entity version
it was made from. Claim order (priority, then `createdAt`) makes it likely but
not certain.

## Design

### 1. A tracked register per entry and model

The vectors of one entry under one model form a **register**: id
`<entityId>|<modelId>`, the way an AI configuration is one register per id. It
is synced like any tracked kind, so no device silently misses one, and devices
converge on the same vectors:

- **its own vector clock**, bumped by the host that writes it (embeds, or
  accepts and stores);
- **a sequence entry per version**: a new `SyncSequencePayloadType.embeddingVectors`,
  appended last (ordinals are persisted);
- **a vector-clock reservation and a bind at enqueue**;
- **receipts on arrival;**
- **gap discovery and backfill**, like every other tracked kind
  (`knowledge/features/sync/sequence-and-backfill.md`);
- **deep backfill**, through a vectors `DeepBackfillStore`;
- **sequence-log population after restore.**

```dart
const factory SyncMessage.embeddingVectors({
  required String id,                    // '<entityId>|<modelId>'
  required String entityId,
  required String entityType,            // kEntityType* as stored
  required String modelId,               // 'embeddinggemma-300m-q4'
  required VectorClock vectorClock,      // the register's own clock
  required VectorClock? sourceVectorClock, // the entry's clock when embedded
  required String contentHash,           // sha256 of the embedded text
  required String jsonPath,              // the vectors, as an attachment
  String? attachmentEventId,
  String? categoryId,
  String? taskId,                        // agent reports
  String? subtype,                       // agent reports
  String? originatingHostId,
  List<VectorClock>? coveredVectorClocks,
}) = SyncEmbeddingVectors;
```

**Why two clocks.**

- The register's own clock carries the sync guarantees: reservation, receipts,
  dominance and backfill, exactly as for every other tracked row.
- The source clock says which version of the entry the vectors describe, so a
  receiver can tell vectors of an older text from vectors of the current one,
  even when two devices embedded concurrently.

**Merge on the receiver**, per register:

| Incoming vs stored clock | Result |
|---|---|
| Dominated or equal | Stale or a duplicate: drop it, and record the receipt. |
| Dominates | Candidate; it goes through the hash check in §3. |
| Concurrent (two devices embedded the same entry) | The candidate whose `contentHash` matches the receiver's own text wins. If both or neither match, the larger `sourceVectorClock` wins, then the lower host id, so every device picks the same one. Merge the clocks, as AI configurations do. |

**Persisting the clocks** is a schema change in ObjectBox. The register's
clock, source clock and content hash must be stored per entry and model,
because the backfill responder, deep backfill and restore read them.

- Either add fields to `EmbeddingChunkEntity` (repeated on each chunk of an
  entry), or add a small register entity per shard.
- Prefer the register entity: one row per entry, and the chunk table stays
  untouched.
- Regenerate `objectbox.g.dart` with the full `make build_runner`. A filtered
  build deletes other outputs.

**The vectors travel as a gzipped JSON attachment**, the way `journalEntity`
does:

```json
{"dims": 768, "chunks": ["<base64 of little-endian float32[768]>", ...]}
```

- **Size:** a chunk is 3 072 bytes raw, so a typical entry of 1–3 chunks is
  about 4–12 KB.
- **Why a file and not inline:** it removes the inline budget, and an
  attachment travels alone. A vector row is therefore never bundled, and an
  older build that can't decode it replays only that row, never a bundle of
  journal rows. Confirm in `claimNextBatch` that a JSON attachment row, not only
  a media row, travels alone, and add the rule if it doesn't.
- **Priority:** low (`outbox_scheduling.dart`), behind journal entities, so the
  entry usually arrives first.

**Backfill answers** (`backfill_response_builders.dart`), per requested
`(host, counter)` whose register this device holds:

- **The same clock:** resend exactly, with the attachment.
- **A newer version:** a hint pointing at it, as other kinds answer.
- **Removed** (the entry was deleted or fell under the length minimum, see
  below): `deleted`.
- **Never held:** `unresolvable`, from the originator only.

**Removals are versions too.** When a device deletes an entry's vectors, it
writes a tombstone version of the register: a bumped clock, no chunks. A
receiver therefore removes them too, instead of keeping vectors for text that is
gone. Deep backfill counts and pages tombstones like live rows, as its contract
already says.

**Float32, not quantized.** ADR 0144 measured float32 vectors. Quantizing to
int8 would quarter the size, but it needs its own measurement on
`tool/embedding_eval`. Leave it as a follow-up, and keep `dims` in the payload
so a later format can be told apart.

### 1a. The register, its chunks and its entry

**The unit is the entry, never the chunk.**

- An entry's text is cut into chunks (`TextChunker`, about 256 tokens each, 48
  overlapping), and the store holds one vector per chunk.
- A register version carries the entry's **complete** chunk set, in order.
- Storing a version replaces every chunk the entry had, atomically, as
  `replaceEntityEmbeddings` does locally today.
- No chunk is tracked, sent or removed on its own, so a receiver can never be
  left with a mix of an old and a new chunk set, or with an orphan chunk.
- The receiver does not chunk again; it stores the sender's chunks as they are.
  Chunking is a function of the text, and the text is pinned by the content
  hash.

**How a version relates to its indexed entry.**

| Register field | What it ties to |
|---|---|
| `entityId` | The journal entity, or the agent report, whose text was embedded |
| `contentHash` | The exact text that was chunked, label enrichment included; the receiver's admission check (§3) |
| `sourceVectorClock` | The entry's version at embedding time: older or newer text, even when two devices embedded concurrently |
| `vectorClock` | The register's own history: sync ordering, receipts, backfill |
| `categoryId` | Not part of the register's identity. Each device files the chunks in the shard of its own copy's category, as today; a recategorisation moves them locally and sends nothing |

**Removing old embeddings: every removal is a version.**

A tombstone version (a bumped register clock, no chunks) is written and sent
whenever a device removes an entry's vectors:

- **The entry is deleted.** Today processing finds it gone and deletes its
  vectors (`EmbeddingProcessor`'s "gone means no vectors").
- **The text fell under the 20-character minimum.**
- **An agent report is superseded.** `processAgentReport` deletes every other
  report vector of the task (#4879). Each of those reports is its own register
  (`<reportId>|<modelId>`), so each deletion is a tombstone of that register.
  Without them, a receiver would keep a task's old reports searchable, which is
  exactly what #4879 fixed locally.
- **An embed was replaced by a newer one.** That's not a tombstone but the next
  version of the same register. It replaces the chunk set, so the old chunks are
  gone on every device that applies it.

Tombstones matter more than they would for a tracked entity. **Receivers do not
process synced edits** (`EmbeddingService` hears only local writes). A receiver
therefore never discovers by itself that an entry is gone or too short, and the
writer's tombstone is how its vectors leave the receiver's index. A deleted
entry's leftover vector is still skipped at search time, as today. Treat that as
a backstop, not the mechanism.

**A model change starts new registers.**

- A register is per model, so vectors of a model this device doesn't run
  (`modelId` differs) are dropped on arrival, with their receipts recorded.
- The retired store's local deletion (ADR 0148) sends nothing.
- No tombstones are sent for a whole model.

**Agent reports and their task.**

- A report register is keyed by the report, not the task. Its version carries
  `taskId` and `subtype` so the receiver files it under the task.
- The receiver does **not** run the one-report-per-task cleanup itself, and
  writes no tombstones of its own. The writer already sends a tombstone for each
  report its cleanup removed, and a receiver that wrote its own would send a
  duplicate removal from every device. Until those tombstones arrive, a task
  may briefly have its old and new report on a receiver; search collapses a
  task's report hits into one result (`agent:<taskId>`), so the user sees one
  task either way.

### 2. Who sends

The device that embedded the text, right after the store write:

- `EmbeddingProcessor._embedChunks`, after `replaceEntityEmbeddings`, hands the
  generated vectors to an injected `EmbeddingShare` callback. This covers
  `processEntity` (service and backfill) and `processAgentReport`.
- The sync side (`get_it_sync.dart`) implements the callback and enqueues the
  message.
- Nothing is sent when:
  - the vectors came from sync. There's no echo: storing a received version
    records its receipt and keeps its clock, and sends nothing;
  - sync is not set up (a guest profile, or no sync capability);
  - the new flag below is off.

**Removals send a tombstone version** (§1): when processing deletes an entry's
vectors (the entry is gone, or its text fell under the minimum), the register
gets a new, empty version, sent like any other.

A new config flag, `sync_embeddings`, off by default in the first release,
gates sending and accepting. `enable_embeddings` must be on as well.

### 3. Who stores: the receiver checks the hash

The apply arm calls an injected `SyncedEmbeddingSink`, defined in sync and
implemented in the AI feature. It does not write the journal:
`writesJournalDb → false`. The sink:

1. Drops the message unless all of these hold:
   - `enable_embeddings` and `sync_embeddings` are on;
   - the pipeline is registered;
   - `modelId` equals the local `OnDeviceEmbeddingRepository.modelId`.

   A dropped message still records its receipt, so the sequence log never asks
   for it again. A device that hasn't downloaded the model still stores
   vectors: it needs the model only for queries, so its index is ready the
   moment it downloads.
2. Merges clocks (§1). A dominated version is dropped here.
3. Reads the attachment and checks it (`dims == kEmbeddingDimensions`, every
   value finite). It rejects anything else.
4. Recomputes the content hash from its own copy:
   - **A journal entity:** use `journalDb.journalEntityById` and the same text
     extraction `EmbeddingProcessor` uses, label enrichment included. Factor
     that extraction out so both sides call one function.
   - **An agent report:** use the report's content from the agent database.
5. Compares:
   - **Hashes equal:** store under the entity's lock (`EmbeddingProcessor`'s
     per-entity serialization), with the sender's chunks, the register's merged
     clock, the source clock and the hash. An agent report is stored alone; the
     writer's tombstones remove the task's older reports (§1a).
   - **Hashes differ, or the entity is missing:** the vectors describe a text
     this device doesn't have yet. Hold the version, keeping the newest per
     register, in a small persisted table (it must survive a restart now that
     the receipt is recorded). Run step 4 again when `onJournalEntityApplied`
     fires for that entity.
   - **A held version whose source clock is dominated by the local entry's
     clock** will never match, because the entry has moved on. It is
     discarded, and the device's own next embed of that entry supersedes it.
6. Is idempotent: a version already stored (equal clock) is a no-op. That
   covers lease redelivery.

**Receivers still do not embed synced edits.** The vectors now come with them,
and the writer is responsible for sending. If the writer never embeds (its flag
is off, it runs Windows, or it has no model), a receiver that does embed keeps
the local fallback: the next local edit or the backfill. Whether receivers
should also embed synced entries that never got vectors is listed under
Residuals.

### 4. A new device

Add a vectors phase to the Add Device history (`historical_sync_service.dart`,
`ReSyncPhase`), after journal entities:

- it walks the local store;
- it sends the current version of each register through `enqueueCurrent`, the
  same path deep backfill uses.

Because the vectors are tracked, a device that misses any of them later finds
the gap and asks for them, like every other tracked row.

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
the knowledge docs it touches. Read ADR 0136 and its code before slice 1, and
follow the AI-config wiring wherever this plan doesn't say otherwise.

1. **Register storage.**
   - The ObjectBox register entity (or fields), with the register's clock, the
     source clock and the content hash. Generate it with the full
     `make build_runner`.
   - `EmbeddingStore` methods to read and write a register's version, and
     tombstones.
   - The processor writes a new version, bumping the local host's counter, on
     each store and each removal.
   - Tests on both stores and on the processor.
2. **Message, sequence and outbox.**
   - The variant.
   - `SyncSequencePayloadType.embeddingVectors`, appended last.
   - Reservation and bind at enqueue (through the simple enqueue writer, as
     `aiConfig` does); priority low; the attachment writer; it travels alone.
   - The `writesJournalDb → false` arm.
   - The `sync_embeddings` flag, seeded off.
   - Tests:
     - encoding and decoding;
     - reservation and bind;
     - the row travels alone;
     - an old build's decode failure stays one row.
   - Docs: `message-model.md` (the variant list and the tracked set),
     `send-path.md`, `sequence-and-backfill.md`.
3. **Sending.**
   - The `EmbeddingShare` callback from `_embedChunks` and from removals,
     implemented in sync.
   - No echo; flag gating.
   - Tests: one message per new version; nothing when the flag is off or sync
     is absent; the agent-report path; tombstones.
4. **Receiving.**
   - The `SyncedEmbeddingSink`: the merge table, the hash check against the
     receiver's own text, the shared text extraction, the persisted hold and
     its re-check on `onJournalEntityApplied`, discarding superseded holds,
     agent reports, validation, and receipts recorded on every outcome.
   - Tests:
     - dominated / dominating / concurrent;
     - match → stored;
     - mismatch → held → stored after the entity applies;
     - a held version superseded by a newer entry is discarded;
     - wrong model or dims → dropped, receipt recorded;
     - redelivery is a no-op;
     - a held version survives a restart.
5. **Backfill, deep backfill, restore, Add Device.**
   - The backfill response builder: resend, hint, `deleted`, `unresolvable`.
   - The vectors `DeepBackfillStore`.
   - Sequence-log population after restore.
   - The `ReSyncPhase` for vectors.
   - Tests on each, following the `aiConfig` ones.
6. **TLA+ and docs.**
   - Add the vectors family to `specs/tla/SyncPipeline.tla` (`Family`), and
     check it in `SyncSequence.tla` and `DeepBackfill.tla` as the other tracked
     kinds are.
   - Add a `SyncVector` actor to `specs/tla/EmbeddingFreshness.tla`: send after
     store, arrival in any order, the merge, the hash check, holding, and
     tombstones.
   - Properties:
     - every device converges on the same register version once quiescent;
     - a stored vector always matches its entry's current text on the device
       that stored it;
     - nothing reaches the index from an unverified device.
   - Follow the practice in `specs/tla/README.md`: fix switches, mutations with
     their counterexamples, the ledger row.
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

- **Synced entries their writer never embedded** (written with its flag off,
  on Windows, or without the model) stay unembedded on receivers until a local
  edit or a backfill. A later step could let a receiver with the model embed
  those in the background, on a charger, and share them like any other version.
- **Label renames** change task hashes on every device, so the next local
  edit's vectors replace the old ones everywhere. The task is unsearchable
  only in the window before that.
- **Windows** neither sends nor receives until its ONNX worker lands
  (earmarked).
- **Int8 vectors** are left out; they need their own measurement first.
