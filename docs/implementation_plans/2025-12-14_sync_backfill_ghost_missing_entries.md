# Sync Backfill: Ghost Missing Entries from EntryLink Counters

**Date:** 2025-12-14
**Status:** Implementation Complete (Steps A-E, Tests done; Step F optional)
**Scope:** Debugging/refinement of self-healing sync backfill based on vector clocks (host UUID +
monotonic counter).

## Implementation Status (Updated 2025-12-15)

| Step | Description | Status |
|------|-------------|--------|
| A | Schema migration: `payload_type` column | ✅ Done |
| B | Record EntryLink counters on send/receive | ✅ Done |
| C | Backfill responder supports EntryLinks | ✅ Done |
| D | Type-aware hint storage and verification | ✅ Done |
| E | Populate/reconcile from local EntryLinks | ✅ Done |
| F | Safety valve: "Unmappable counter" response | ❌ Not implemented (optional) |
| Tests | Add tests for EntryLink backfill scenarios | ✅ Done |

### Files Modified
- `lib/database/sync_db.dart` - Schema v3 with `payload_type` column
- `lib/database/sync_db.g.dart` - Generated code
- `lib/features/sync/sequence/sync_sequence_payload_type.dart` - New enum
- `lib/features/sync/sequence/sync_sequence_log_service.dart` - Link-aware methods
- `lib/features/sync/matrix/sync_event_processor.dart` - Records received EntryLink counters
- `lib/features/sync/outbox/outbox_service.dart` - Records sent EntryLink counters
- `lib/features/sync/backfill/backfill_response_handler.dart` - Multi-payload backfill
- `lib/features/sync/model/sync_message.dart` - Extended with `payloadType`/`payloadId`
- `lib/features/sync/state/sequence_log_populate_controller.dart` - Two-phase populate
- `lib/features/sync/ui/sequence_log_populate_modal.dart` - UI updates for links

## Summary

We see large, persistent counts of `missing` sequence entries that do not resolve even after
re-syncing and running backfill. The primary issue is not “hint processing”, but a mismatch between
what *consumes* the vector-clock counter and what the sequence log/backfill system can represent.

In Lotti today:
- `VectorClockService` is a **single global monotonic counter per host**.
- That counter is used for **journal entry versions** and **entry links**.
- `sync_sequence_log` and the backfill responder currently model **journal entries only**
  (mapping `(hostId,counter) → journal entryId`).

This creates “ghost missing” counters: gaps that correspond to EntryLink updates and therefore
cannot be fulfilled by the current backfill protocol.

## Current Implementation (where hints are processed)

**Responder → requester hint transport**
- `SyncMessage.backfillResponse(entryId: ...)` carries a response-side mapping for
  `(hostId,counter) → entryId`.
- Responder sends both:
  - `SyncMessage.journalEntity(...)` (actual data)
  - `SyncMessage.backfillResponse(..., entryId: <id>)` (mapping)
  - Code: `lib/features/sync/backfill/backfill_response_handler.dart`

**Requester-side hint storage + verification**
- Stores the mapping: `SyncSequenceLogService.handleBackfillResponse(...)`
- Marks as `backfilled` only when data exists locally:
  - immediate: `BackfillResponseHandler.handleBackfillResponse(...)`
  - deferred: `SyncSequenceLogService.resolvePendingHints(...)` called from
    `recordReceivedEntry(...)`
  - Code: `lib/features/sync/sequence/sync_sequence_log_service.dart`

## Key Finding: The global counter is shared with EntryLinks

**Evidence in code**
- `VectorClockService.getNextVectorClock()` is used by:
  - journal metadata: `createMetadata(...)` / `updateMetadata(...)`
  - entry links: `createLink(...)` / `updateLink(...)`
  - Files: `lib/logic/persistence_logic.dart`,
    `lib/features/journal/repository/journal_repository.dart`

**What we confirmed in debugging**
- For stuck missing `(hostId,counter)` rows, the originating device has **no**
  `sync_sequence_log` row for that `(hostId,counter)`.
- Given the code above, that strongly indicates the counter was spent on an EntryLink operation
  (and never logged), not on a journal entry.

## Why the current backfill loop cannot fix this

1. `BackfillResponseHandler._processBackfillEntry(...)` only responds when it can map
   `(hostId,counter)` to a **journal entryId**, then reload the journal entity.
2. Ghost-missing link counters have no journal `entryId` mapping anywhere, so responders skip and
   nothing is sent.
3. Hint resolution (`resolvePendingHints`) is journal-only (keyed by `entryId` and verified against
   journal VCs), so it cannot resolve EntryLink counters.

## Goal

Make “Missing” reflect reality and converge to zero by ensuring that every vector-clock counter
that can create a gap is either:
- representable and backfillable, or
- intentionally excluded from gap detection (by design), without producing permanent `missing`
  rows.

## Proposed Fix (primary): Make sequence log/backfill multi-payload (JournalEntry + EntryLink)

### A) Generalize `sync_sequence_log` to store payload kind

Add columns:
- `payload_type` (enum/int): `journalEntity`, `entryLink`
- `payload_id` (text): entity identifier (`journalEntity.meta.id` or `EntryLink.id`)

We can keep the existing `entry_id` column for backward compatibility and treat it as the
`payload_id` when `payload_type == journalEntity` (or migrate/rename in a schema bump).

### B) Record EntryLink counters on send and receive

**On send** (`OutboxService.enqueueMessage` for `SyncEntryLink`)
- Derive `(hostId,counter)` from `entryLink.vectorClock`.
- Upsert `sync_sequence_log` with `payload_type=entryLink`, `payload_id=entryLink.id`.

**On receive** (`SyncEventProcessor` after applying `SyncEntryLink`)
- Call a new `SyncSequenceLogService.recordReceivedLink(...)` that:
  - updates host activity
  - detects gaps for the link counter (same host-counter model)
  - marks existing `missing/requested` rows as `received/backfilled`

This prevents “ghost missing” gaps caused by interleaving link and journal operations.

### C) Backfill responder supports EntryLinks

In `BackfillResponseHandler._processBackfillEntry(...)`:
- Lookup `(hostId,counter)` in sequence log and branch by `payload_type`:
  - `journalEntity`: existing behavior
  - `entryLink`:
    - load link by id from `linked_entries`
    - enqueue `SyncMessage.entryLink(...)`
    - enqueue a type-aware `SyncMessage.backfillResponse(...)` so the requester can attach the
      mapping even if the resent link is a newer version

### D) Type-aware hint storage and verification

Extend `SyncBackfillResponse` to include optional `payloadType` (default `journalEntity` for older
clients).

Update `SyncSequenceLogService`:
- store mapping for `(hostId,counter)` with `payload_type/payload_id`
- verification:
  - `journalEntity`: verify journal entry exists and its VC covers requested counter (current logic)
  - `entryLink`: verify link exists locally and its VC covers requested counter
- pending hint resolution should query by `(payload_type,payload_id)` (not just `entryId`)

### E) Populate/reconcile from local EntryLinks (to clear existing ghost missing without network)

Extend the existing populate/maintenance tooling to also scan `linked_entries` and upsert:
`(hostId,counter,payload_type=entryLink,payload_id=link.id)` for link vector clocks.

This clears the common case where the EntryLink message arrived (state is present) but the counter
was never recorded, which is exactly what creates “ghost missing” rows today.

### F) Safety valve: “Unmappable counter” response (optional but likely needed)

Even after adding link population, some historical counters may remain unmappable (e.g., if the app
never persisted a stable `(hostId,counter) → payload_id` mapping at the time).

To avoid infinite re-requests and a permanently non-zero “Missing” count:
- if a responder is the *originating host* for `hostId` and has no mapping for `(hostId,counter)`,
  respond with an explicit “cannot backfill / unknown payload” response
- requester marks the row as a terminal status (e.g., `ignored`/`unbackfillable`) so it stops being
  counted/requested

This status should be distinct from `deleted` (which implies a known item was purged).

## Alternative (simpler but less robust): Stop spending the global counter on EntryLinks

- Move EntryLink updates to a separate counter (or use `vectorClock: null`) so journal-entry
  counters don’t skip over link operations.
- Still requires a cleanup step to resolve/delete already-created ghost missing rows.
- Does not provide self-healing backfill for missing EntryLink messages.

## Longer-term option (most robust): Dedicated per-message sync counter

Decouple self-healing sequencing from vector clocks entirely:
- add a per-host `syncCounter` to every sync message (or to the outbox envelope)
- detect gaps and backfill by `syncCounter`, independent of entity version clocks

This guarantees that every “missing” item refers to a concrete sync message that can be resent.

## Implementation Steps

1. ✅ Schema migration in `lib/database/sync_db.dart` (version bump) adding `payload_type/payload_id`
   and required queries.
2. ✅ Extend `SyncSequenceLogService` with link-aware record/verify helpers.
3. ✅ Extend `SyncEventProcessor` to record received `SyncEntryLink` counters.
4. ✅ Extend `BackfillResponseHandler` to backfill EntryLinks (and extend `SyncBackfillResponse` with
   `payloadType`).
5. ✅ Extend population/maintenance to include EntryLinks.
6. ✅ Add tests covering:
  - receiving an EntryLink counter resolves a previously-created `missing` row
  - interleaved link/journal ops do not create permanent missing gaps
  - populateFromEntryLinks functionality (stream processing, skip existing, multi-host VCs)

## Validation Checklist (manual)

On a device with a previously “stuck” missing count:
1. Run the sequence-log population/reconciliation (journal + links).
2. Confirm “Missing/Requested” drops substantially (ideally to near-zero).
3. Trigger a manual full backfill and verify remaining pending items drain.

## Observability

Add logs/metrics for:
- pending rows with `payload_id IS NULL`
- pending rows by `payload_type`
- rows cleared by EntryLink reconciliation
- “unmappable counter” responses (if enabled)

## Risks

- **Performance:** reconciliation must be batched; avoid per-row transactions.
- **Schema compatibility:** `payloadType` in backfill responses must be optional for older clients.
