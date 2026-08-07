---
type: Feature Module
title: Sync send path
description: Outbox staging, the CAS claim that makes merges safe, dequeue-time bundling into one gzipped Matrix envelope, and the retry lifecycle.
resource: ../../../lib/features/sync/outbox
tags: [sync, outbox, bundling, retries]
status: stable
generated: { by: codex/gpt-5, at: 2026-08-06T00:30:48+02:00 }
stale_after: 2026-11-02
sources:
  - id: outbox
    resource: ../../../lib/features/sync/outbox
    title: Outbox service, processor, repository
    last_modified: 2026-08-05
  - id: payload-sender
    resource: ../../../lib/features/sync/matrix/matrix_payload_sender.dart
    title: MatrixPayloadSender — wire encoding
    last_modified: 2026-08-06
  - id: agent-payload-sender
    resource: ../../../lib/features/sync/matrix/matrix_payload_sender_notifications.dart
    title: Agent and notification payload encoding
    last_modified: 2026-08-06
  - id: media-repair
    resource: ../../../lib/features/sync/media
    title: Media self-healing — request and response
    last_modified: 2026-07-28
  - id: attachment-policy
    resource: ../../../lib/features/sync/model/sync_attachment_policy.dart
    title: shouldSendJournalAttachments — the media-send decision
    last_modified: 2026-07-27
  - id: tuning
    resource: ../../../lib/features/sync/tuning.dart
    title: SyncTuning
    last_modified: 2026-05-30
---

# Staging

`OutboxService` stages local work in `sync_db`, merges superseded work when it
can, enriches sequence-aware payloads with covered clocks, and nudges a
`ClientRunner`-driven `OutboxProcessor`.

```mermaid
sequenceDiagram
  participant Local as "Local change"
  participant Outbox as "OutboxService"
  participant Repo as "OutboxRepository"
  participant Proc as "OutboxProcessor"
  participant Matrix as "MatrixService"

  Local->>Outbox: enqueueMessage(syncMessage)
  Outbox->>Outbox: merge/enrich covered clocks
  Outbox->>Repo: persist pending row
  Outbox->>Proc: nudge runner
  Proc->>Repo: claimNextBatch() [CAS pending→sending]
  Proc->>Matrix: sendMatrixMsg(syncMessage)
  alt send succeeds
    Proc->>Repo: markSent()
    Proc->>Repo: hasMorePending()
  else send fails
    Proc->>Repo: markRetry() or markError()
  end
```

Sends are nudged by connectivity regain, Matrix login completion, outbox
row-count changes, and a watchdog for pending-but-idle queues. The whole pass is
gated by `UserActivityGate`, so the queue waits for idle time before running.

# Media attachments: one decision, two places

Whether a `SyncJournalEntity` send carries the entry's image or audio blob is
decided by `shouldSendJournalAttachments`
(`lib/features/sync/model/sync_attachment_policy.dart`). Media rides along when
the entry is new to every peer (`SyncEntryStatus.initial`), when the payload
opts in via `SyncJournalEntity.includeAttachments`, or when the
`resend_attachments` config flag is on. An ordinary edit sends JSON only — the
blob is immutable for the life of the entry and the peer already has it.

Two collaborators consult that one function, and they must agree:

| Where | What it does with the answer |
| --- | --- |
| `OutboxEnqueueWriter` | Resolves the media file and stamps the row's `filePath` |
| `MatrixPayloadSender.sendJournalEntityPayload` | Uploads the blob as a second file event |

The enqueue-time half is not redundant. `filePath` is what excludes a row from
dequeue-time bundling (below), and a bundle ships a JSON manifest only. A row
whose message asks for media but whose `filePath` is null would be packed into a
bundle and its blob dropped with no error anywhere.

`includeAttachments` exists for the flows that hand an entire history to a peer
holding none of it — the historical re-send
(`HistoricalSyncService.reSyncInterval`) and backfill responses
(`BackfillResponseHandler`). Both are necessarily
`update` sends: the entry is not new on the sending device. Before the flag
existed, both shipped JSON without blobs, so a freshly provisioned device
received every entry's text and none of its media, while entries created after
it joined arrived complete.

`MatrixPayloadSender` also uploads blobs for any media-bearing bundle child that
reaches it anyway — defence in depth against a row enqueued by an older build,
where the attachment decision had not yet moved to enqueue time.

## Self-healing: repairing a blob that never arrived

The policy above governs sends this device chooses to make. A device can still
end up holding an entry whose blob it never received — it joined after the
upload, a download failed, a peer ran a build that predates the policy. Nothing
in the apply path treats that as an error: the JSON is the authoritative state
and the entry must apply regardless, so the miss would otherwise be observed on
every load and dropped.

`lib/features/sync/media/` closes that loop.

```mermaid
sequenceDiagram
  participant Loader as "SmartJournalEntityLoader"
  participant Repair as "MediaRepairService"
  participant Room as "Matrix room"
  participant Peer as "MediaRequestHandler (peer)"
  participant Ingest as "AttachmentIngestor (here)"

  Loader->>Loader: _ensureMediaOnMissing(entity)
  Note over Loader: AttachmentIndex has no descriptor<br/>for this path
  Loader->>Repair: onMissingMedia(entryId, relativePath)
  Repair->>Repair: debounce + dedupe + cap
  Repair->>Room: SyncMediaRequest(entryIds, requesterId)
  Room->>Peer: broadcast
  Peer->>Peer: entry known? blob on disk?
  Peer->>Room: SyncJournalEntity(includeAttachments: true)
  Room->>Ingest: m.file (the blob)
  Ingest->>Ingest: write to disk
```

Three properties are load-bearing:

- **The request travels by entry id, not by path.** The responder resolves the
  id through `JournalDb` and derives the media path itself, so no wire-supplied
  path is ever resolved against a peer's filesystem. It also means the answer is
  an ordinary journal-entity send — no media-specific upload path exists to
  drift out of step with the policy above.
- **There is no response envelope.** The blob arrives as a plain attachment
  event and `AttachmentIngestor` writes it, the same way any attachment lands.
  The requester never learns a request succeeded; it stops asking because the
  file now exists and the loader stops reporting it missing.
- **The request is broadcast and answers are optional.** Any peer holding the
  blob may answer, because the device that created the entry is often the one
  that is offline. A peer that lacks the file stays silent rather than
  answering with nothing.

Bounds live in `SyncTuning` (`mediaRepair*`): a debounce window so a catch-up's
burst of misses becomes one request, a batch cap so a backlog drains across
successive requests, an attempt cap so a blob no peer holds is eventually
abandoned, and a tracking cap so the pending set cannot grow without limit.

# The CAS claim is load-bearing

`claimNextBatch` is a per-row compare-and-set from `pending` to `sending`. That
is not an optimisation — it is what makes merging safe.

A merge that fires while a send is in flight runs
`updateOutboxMessage(... WHERE status = pending)` and gets `affectedRows = 0`.
The merged content then spills into a **fresh pending row** through the
existing fresh-insert fallback, instead of overwriting the row whose old content
is currently being serialised onto the wire.

Without this, the pre-merge Matrix event would still go out while the new
`coveredVectorClocks` list sat in a row that would never be sent — producing
scattered single-counter holes on receivers that only backfill could repair.

# File payload identity follows the claimed generation

Every JSON-backed send records the successful Matrix file-event id in the text
envelope as `attachmentEventId`. The relative path remains the cache location
and the compatibility key for older peers; it is no longer the identity of a
new payload generation.

Agent outbox rows make the send-side half explicit. A pending
`SyncAgentEntity` retains the serialized entity inline even though the sender
strips it from the wire text after upload. The uploader uses those inline bytes,
not the mutable `/agent_entities/<id>.json` sidecar. If a newer local update
overwrites that sidecar after the old row is claimed, the in-flight row still
uploads its own payload and stamps the event id returned for those exact bytes.
Legacy rows that contain only `jsonPath` continue to read the sidecar so mixed
versions remain sendable. Journal and notification senders already snapshot
their file bytes before upload and reconcile the envelope against that same
snapshot; outbox bundles use a fresh UUID path and stamp the manifest upload id.

# Item lifecycle

```mermaid
stateDiagram-v2
    [*] --> pending: enqueued
    pending --> sending: claimed by OutboxProcessor
    sending --> sent: delivered
    sending --> pending: recoverable failure (markRetry, retries++)
    pending --> error: retries reach maxRetries (10)
    error --> pending: manual Retry / Retry all (re-queue)
    sent --> [*]: pruned after 7 days
    error --> [*]: Remove (won't sync)
```

`DatabaseOutboxRepository.maxRetries` defaults to **10**. Retry delay is 5 s,
error delay 15 s, send timeout 20 s, claim lease 1 minute
(`SyncTuning`).

# Dequeue-time bundling

When `claimNextBatch(maxSize: SyncTuning.outboxBundleMaxSize)` — 50 — returns
more than one row, the processor wraps them in a `SyncOutboxBundle` and ships
the batch as **one** Matrix envelope. A single-row batch routes through the
per-row send instead.

**Media-attachment rows (`filePath != null`) always travel alone.** The boundary
rule lives in `claimNextBatch`, so a bundle can never carry audio or image
bytes.

Claim order is priority, then `createdAt`, then `id` — so user-visible journal
entities and entry links drain ahead of older normal-priority agent or backfill
rows, while order within a priority stays stable.

```mermaid
sequenceDiagram
  participant Proc as "OutboxProcessor"
  participant Repo as "OutboxRepository"
  participant Sender as "MatrixPayloadSender"
  participant DB as "JournalDb"
  participant Room as "Matrix room"

  Proc->>Repo: claimNextBatch(maxSize: 50)
  Repo-->>Proc: List<OutboxItem>
  Proc->>Sender: send(SyncOutboxBundle)
  Sender->>DB: journalEntityMapForIdsIncludingDeleted(ids)
  DB-->>Sender: {id: JournalEntity, …}
  Sender->>Sender: build manifest + gzip
  Sender->>Room: m.file (manifest, encoding=gzip)
  Sender->>Room: m.text (stripped envelope)
  Room-->>Sender: ack
  Sender-->>Proc: success
  Proc->>Repo: markSentBatch(items)
```

`MatrixPayloadSender.sendOutboxBundlePayload` builds the wire form:

1. **Bulk-load** every `SyncJournalEntity` child's `JournalEntity` via
   `JournalDb.journalEntityMapForIdsIncludingDeleted` in one `WHERE id IN (…)`
   query. This outbound-only read includes soft-deleted rows because their
   tombstones must reach peers; ordinary application bulk reads still hide
   them. The database is the system of record — the sender never reads
   per-child JSON files from disk.
2. **Reconcile** each child envelope's `vectorClock` against the DB version.
3. **Emit one manifest**:
   `{version: 1, entries: [{envelope: <SyncMessage>, payload: <JournalEntity?>}]}`.
   Inline-payload families (`SyncEntryLink`, `SyncAiConfig`,
   `SyncAiConfigDelete`, `SyncSavedTaskFilter`, `SyncSavedTaskFilterDelete`,
   `SyncEntityDefinition`, `SyncThemingSelection`, `SyncBackfillRequest`,
   `SyncBackfillResponse`) and agent envelopes carry their data inside the
   freezed envelope and need no separate `payload`.
4. **Gzip on a worker isolate** and upload as a single `m.file` event with
   `relativePath: /outbox_bundles/<uuid>.json`, upload name `<uuid>.json.gz` and
   `extraContent.encoding = "gzip"`. No temp file ever touches disk.
5. **Send the thin envelope** — `children: []`, `jsonPath` pointing at the
   uploaded cache path.

## Size cap and failure

The post-gzip cap `SyncTuning.outboxBundleMaxBytes` is **8 MiB**, and it is a
send-side guard only. When the gzipped manifest exceeds it,
`sendOutboxBundlePayload` returns `null`, which triggers
`OutboxRepository.markRetryBatch` to re-queue every row for the next pass.

Rows stay pending until acknowledged, so a failed manifest send simply
re-bundles from outbox state next drain — no on-disk artifact survives across
attempts.

A journal child absent even from the including-deleted lookup was hard-purged,
not merely soft-deleted. The sender aborts that bundle rather than silently
acknowledging a manifest that omitted the child. Soft deletion therefore no
longer sends every valid sibling through the retry loop; genuinely missing
payloads still surface through the existing retry/error diagnostics.

## Receiver side

`SyncEventProcessor._resolveOutboxBundleManifest` reverses it:

1. Reuse the descriptor pipeline; `decodeAttachmentBytes` gunzips transparently.
2. Bulk-load the local `JournalEntity` map for every `SyncJournalEntity` id in
   the manifest — one query, no N+1.
3. Per entry, run a clock dominance check against the database. When the local
   copy already covers the incoming clock, **leave the on-disk JSON cache
   alone** so `SmartJournalEntityLoader` returns the canonical local entity.
   Otherwise write the inlined payload to its declared `jsonPath` so the apply
   pipeline reads it as a cache hit and skips the descriptor index.
4. Hand the reconstructed children to `OutboxBundleUnpacker.prepare`.

The manifest is dropped (`null`) when `version` is absent or unequal to
`SyncTuning.outboxBundleManifestVersion`, or when `entries` is missing. The
receiver has no outbox rows to re-queue, so a dropped manifest surfaces its
missing children through per-`(host, counter)` backfill.

# Agent wake writes

Agent wake execution installs **no** wake-scoped sync interceptor. Each
`AgentRepository` write inside a wake commits immediately, receives a vector
clock at write time, and enqueues its own `SyncAgentEntity` or `SyncAgentLink`
row. The generic bundler coalesces them at dequeue time like anything else.

```mermaid
sequenceDiagram
  participant Wake as "Wake executor"
  participant Sync as "AgentSyncService"
  participant Repo as "AgentRepository"
  participant Outbox as "OutboxService"

  Wake->>Sync: upsertEntity / upsertLink
  Sync->>Repo: persist stamped entity/link
  Sync->>Outbox: enqueueMessage(SyncAgentEntity / SyncAgentLink)
  Outbox->>Outbox: row stored, drains via OutboxProcessor
```

An earlier design coalesced wake writes into a `SyncAgentBundle` envelope
flushed at the terminal edge of the wake scope. The wire variant remains
parseable so older peers interoperate, but the producer no longer builds it. If
a peer is missing a child that an in-flight legacy bundle dropped, gap detection
reopens it and backfill pulls each child individually.

# Outbox monitor

*Settings → Sync → Outbox* is the user-facing view. It reads a **one-shot
snapshot** (`getOutboxItems`) with pull-to-refresh, deliberately not a live
`watch()` — the queue churns hundreds of rows per minute during sync.

The page opens with a plain-language summary driven by the pure
`summarizeOutbox()`: "Everything's synced", "Sending N…", "N waiting to send",
"N couldn't send" (with a one-tap **Retry all**), or — when sync is off — "N
will send when you reconnect", so an offline user is reassured rather than
alarmed.

Each row is an `OutboxMessageCard` with a status pill (waiting / sending /
failed / sent → warning / info / error / success). Failed items add a
reassurance ("still saved on this device") plus **Retry** (safe, no
confirmation) and **Remove** (guarded by a confirmation spelling out that the
change won't reach other devices). Per-row diagnostics and the daily-volume
chart hide behind a "show technical details" toggle.

Manual actions write straight to `SyncDatabase`.

# Directional queue badges

The Settings destination carries compact queue depth rather than a separate
sidebar status row. `SyncQueueCounts` reads
`outboxPendingCountProvider` for the outgoing `↑ count` pill and reuses
`inboundQueueDepthProvider` for the incoming `↓ count` pill. Both use the
neutral outlined badge tone because queued work is normal operation, and each
direction disappears independently at zero. The former per-packet pulse
signaler and its opt-in config flag no longer exist.
