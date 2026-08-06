---
type: Feature Module
title: Sync message model
description: The twenty-five SyncMessage families, which seven are sequence-tracked, and how onboarding control messages stay outside causal payload accounting.
resource: ../../../lib/features/sync/model/sync_message.dart
tags: [sync, wire-format, sync-message]
status: stable
generated: { by: codex/gpt-5, at: 2026-08-06T00:30:48+02:00 }
stale_after: 2026-11-02
sources:
  - id: sync-message
    resource: ../../../lib/features/sync/model/sync_message.dart
    title: SyncMessage freezed union
    last_modified: 2026-08-06
  - id: payload-type
    resource: ../../../lib/features/sync/sequence/sync_sequence_payload_type.dart
    title: SyncSequencePayloadType
    last_modified: 2026-07-05
  - id: apply
    resource: ../../../lib/features/sync/matrix/sync_event_processor_apply.dart
    title: Apply path
    last_modified: 2026-08-02
  - id: attachment-index
    resource: ../../../lib/features/sync/matrix/pipeline/attachment_index.dart
    title: AttachmentIndex exact and legacy lookup
    last_modified: 2026-08-06
  - id: agent-resolution
    resource: ../../../lib/features/sync/matrix/sync_event_processor_agent_handlers.dart
    title: Exact agent attachment resolution
    last_modified: 2026-08-06
  - id: journal-resolution
    resource: ../../../lib/features/sync/matrix/smart_journal_entity_loader.dart
    title: Exact journal attachment resolution
    last_modified: 2026-08-06
  - id: bundle-resolution
    resource: ../../../lib/features/sync/matrix/sync_event_processor_outbox_bundle.dart
    title: Exact outbox manifest resolution
    last_modified: 2026-08-06
  - id: payload-sender
    resource: ../../../lib/features/sync/matrix/matrix_payload_sender.dart
    title: File-backed payload upload and event-id binding
    last_modified: 2026-08-06
  - id: agent-payload-sender
    resource: ../../../lib/features/sync/matrix/matrix_payload_sender_notifications.dart
    title: Claimed agent payload upload
    last_modified: 2026-08-06
---

# Families

Everything on the wire is a `SyncMessage` — a freezed union with twenty-five
variants:

`journalEntity`, `entityDefinition`, `entryLink`, `aiConfig`,
`syncNodeProfile`, `aiConfigDelete`, `savedTaskFilter`,
`savedTaskFilterDelete`, `configFlag`, `themingSelection`, `dailyOsUserName`,
`notification`, `notificationStateUpdate`, `onboardingSnapshotBegin`,
`onboardingSnapshotAccepted`, `onboardingTerminalCounters`,
`onboardingSnapshotEnd`, `backfillRequest`, `backfillResponse`, `mediaRequest`,
`agentEntity`, `agentLink`, `consumptionEvent`, `agentBundle`, `outboxBundle`.

## Initial-onboarding controls

The four `onboarding*` variants coordinate one target device's bounded
full-history transfer. They carry no vector clock and never become sequence-log
payload rows. Begin freezes per-origin-host counter bounds and a fixed lease;
accepted returns the target's host identity; terminal counters carry bounded
inclusive ranges for the sender host's authoritative burns; end carries
`complete` or `aborted`.
Their persistence, ordering and suppression semantics live in
[sequence log and backfill](sequence-and-backfill.md#initial-onboarding-suppression).

## Sequence-tracked payloads

Only a subset participates in `(hostId, counter)` accounting — the seven
members of `SyncSequencePayloadType`:

`journalEntity`, `entryLink`, `agentEntity`, `agentLink`, `notification`,
`notificationStateUpdate`, `consumptionEvent`.

The enum's ordinal is **persisted** in the sequence log, so existing values
must never be reordered. New values are appended at the end only —
`consumptionEvent` was added that way.

Sequence-tracked payloads may carry:

- `originatingHostId` — the host that created or modified this payload version.
- `coveredVectorClocks` — the counters this payload semantically replaces.

`coveredVectorClocks` is not decoration. `SyncSequenceLogService` pre-marks
covered counters before normal gap detection, so a newer payload can *prove*
older counters were superseded rather than lost. See
[sequence log and backfill](sequence-and-backfill.md).

## `agentBundle` is receive-only legacy

The variant still exists so messages from peers predating the wake-bundle
removal continue to parse, but the receiver no-ops them and the producer never
builds new ones. Agent-wake writes hit the outbox as individual
`agentEntity` / `agentLink` rows, and the generic dequeue-time bundler
coalesces them (see [send path](send-path.md)). Children of any in-flight legacy
bundle resurface through per-`(host, counter)` backfill on demand.

# Saved task filters: per-item, not sequence-tracked

Saved task-filter definitions sync like AI configs — fire-and-forget, no vector
clock, no `originatingHostId`.

```mermaid
flowchart TD
  Edit["Local edit"] --> Enqueue["SavedTaskFiltersRepository enqueues SyncSavedTaskFilter"]
  Enqueue --> Wire["Matrix"]
  Wire --> Apply["SyncSavedTaskFilter apply path"]
  Apply --> LWW{"incoming updatedAt strictly older?"}
  LWW -->|yes| Drop["drop"]
  LWW -->|no| Upsert["upsert by filter.id, fromSync: true"]
  Upsert --> NoEcho["fromSync suppresses re-enqueue"]
```

Three details make this safe:

- **Last-write-wins on `updatedAt`.** A strictly older incoming revision is
  dropped.
- **`fromSync` breaks the echo.** The apply path passes the flag into
  `SavedTaskFiltersRepository`, so an applied remote change never re-enqueues
  itself.
- **An in-class async lock serialises the read-modify-write.** Persistence is a
  per-item update over a single `SettingsDb` JSON blob; without the lock a
  concurrent local edit and inbound apply would clobber each other's slice.

Local-only filters that predate sync converge through the
`SyncStep.savedTaskFilters` maintenance step (*Settings → Sync → Sync
Entities*), which re-enqueues every persisted definition.

Per-device list order and derived per-filter task counts are computed locally
and **never** synced.

# File-backed payloads

Journal entities and agent payloads can travel by reference: the envelope
carries a `jsonPath` and the bytes ride as a Matrix attachment. Those payloads
are resolved through the attachment index and loader before they are applied,
which is why attachment ordering and dedupe are load-bearing for sync
correctness rather than a storage detail.

The transition away from mutable-path identity is backward compatible. A
file-backed envelope may also carry `attachmentEventId`, the Matrix event id of
the exact JSON attachment generation it represents. When that field is present,
journal, agent, notification and outbox-manifest resolution looks up only that
event and waits when it has not arrived; it never reads another descriptor or
the on-disk cache at the same `jsonPath`. `AttachmentIndex` therefore retains
every observed event by id while still exposing latest-by-path lookup for legacy
envelopes. Older peers omit the field and continue through the path-first,
disk-fallback compatibility path. The field is additive and generated decoders
ignore unknown keys, so older receivers can still read current envelopes and
use their `jsonPath`; they simply cannot enforce exact-generation identity.
Exact causality therefore activates per envelope when a current sender includes
the id and a current receiver understands it, without a flag-day upgrade.

The wire field stays optional for mixed-version rollout, but every current JSON
attachment sender populates it from the successful upload: journal entities,
notifications, agent entities and links, and outbox bundle manifests. Agent
rows carry their exact serialized payload inline while pending, so the sender
uploads those claimed bytes before stripping the large entity from the wire
envelope; a newer enqueue overwriting the stable sidecar cannot change the
generation already claimed for send. A legacy file-only outbox row still reads
its sidecar as a compatibility fallback. Exact journal payloads are parsed
directly from their referenced attachment rather than written through the
mutable stable-path cache; outbox manifests retain their existing cache write
because each current sender allocates a fresh UUID path per manifest.

A journal entity's media blob is a *second* file event, sent alongside the JSON
only when the payload calls for it — `status == initial`,
`includeAttachments == true`, or the `resend_attachments` flag. The decision and
why it is taken at enqueue time as well as at send time are in
[sync send path](send-path.md#media-attachments-one-decision-two-places).

## Attachment encoding

An attachment event may carry a `com.lotti.encoding` key declaring an on-wire
encoding. The only defined value is `gzip`: the bytes returned from
`event.downloadAndDecryptAttachment()` are a gzip stream and must be inflated
before the file is written. `relativePath` remains the logical target path,
unchanged by the encoding.

| Direction | Rule |
|-----------|------|
| Receive | Decode the header unconditionally. |
| Send | Gzip any attachment whose `relativePath` ends in `.json` — the sole gate is `relativePath.toLowerCase().endsWith('.json')` in `MatrixPayloadSender`. The upload name gains a `.gz` suffix and the event carries the header. |
| Send (media) | Verbatim. Images and audio are already compressed and would not benefit; no header, no suffix. |
