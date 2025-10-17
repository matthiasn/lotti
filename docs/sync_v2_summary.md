# Lotti Matrix Sync V2 – Debug + Behavior Summary

This note captures the current V2 pipeline behavior, recent fixes, logs to look for, and how to validate. Paste this into a fresh session to regain context.

## High‑Level
- Single-room Matrix sync.
- Event ordering uses Matrix `originServerTs` (UTC) with `eventId` tie‑breaks (timezone‑agnostic).
- Vector clocks remain authoritative for conflict detection; duplicate replays are cheap (rows=0, status=equal).
- Read markers (local + remote) are monotonic; we only advance.

## What We Fixed/Added

1) Read‑marker reliability
- Immediate local persist on advance:
  - Save both `LAST_READ_MATRIX_EVENT_ID` and `LAST_READ_MATRIX_EVENT_TS`.
  - Code: `lib/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart`
- Debounced remote set + guaranteed flush on dispose:
  - The last pending marker is flushed on app background/exit.
  - Code: `lib/features/sync/matrix/pipeline_v2/read_marker_manager.dart`
- Remote monotonic guard (production):
  - Only advance the remote read marker when strictly newer by server ts + id (uses a pure helper).
  - Skips the guard in test env for deterministic tests.
  - Code: `lib/features/sync/matrix/read_marker_service.dart`

2) Startup catch‑up (works without new events)
- Backfill/paginate until the last marker is present; then process strictly after it.
- Rewind floor: replay N=3 events before the last marker id (belt‑and‑suspenders).
- Time‑based rewind: if ts is known, slice from `ts(marker) − 1ms` (no caps).
- Initial live scan + scheduled catch‑up retry after room hydration.
- Code: `matrix_stream_consumer.dart`, `catch_up_strategy.dart`

3) Live streaming robustness (when both devices are online)
- Two concurrent triggers to schedule processing:
  - `room.getTimeline(...)` live callbacks (onNewEvent/onInsert/onChange/onRemove/onUpdate)
  - `sessionManager.timelineEvents` → pending buffer → timed flush
- Tail rescans:
  - If activity but no advancement (and no failure), schedule a tail rescan (~150 ms).
  - After any advancement, schedule a tail rescan (~100 ms).
- Double scan on attachment batches:
  - Immediate live scan, and a second scan at +200 ms (catches text that may land right after file events).
- Slightly increased live scan debounce to give the SDK time to settle.
- Code: `matrix_stream_consumer.dart`

4) Text log files (easier sharing)
- Daily file: `logs/lotti-YYYY-MM-DD.log` in app documents directory.
- All `captureEvent/Exception` also append to this file.
- Code: `lib/services/logging_service.dart`

5) Attachment prefetch dedupe + rescan throttle
- Skip re-downloading attachments that already exist on disk (non-empty).
  - This prevents repeated `writeToFile/saveAttachment` storms on mobile.
  - Code: `lib/features/sync/matrix/save_attachment.dart`
- Only trigger tail/double rescans when at least one new file was written.
  - Avoids scan loops when slices contain only existing attachments.
  - Code: `lib/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart`
- Add a minimum gap (≈500 ms) between attachment-only tail rescans.
  - Prevents rapid-fire scheduling under large attachment bursts.
  - Code: `matrix_stream_consumer.dart` (attachment-only throttle)

6) Vector‑clock aware prefetch (same‑path updates)
- Problem: entries reuse the same `jsonPath` filename across versions. A pure
  "file exists" check can wrongly skip newer content.
- Solution: make prefetch decisions using the vector clock embedded in the
  text message (SyncMessage), not the filename alone.
  - First pass (per batch): parse text events (`SyncJournalEntity`) and build
    an in‑memory map `path → incomingVectorClock`.
  - Prefetch policy per attachment:
    - If file does not exist → download.
    - If file exists → read local `meta.vectorClock` from JSON; if
      `incomingVectorClock` exists and is strictly newer than local →
      re‑download; else skip.
  - Fallback: if the attachment lands before the corresponding text event (so
    we don’t have `incomingVectorClock` yet), skip re‑download on the first
    pass; when the text arrives in a later batch, the newer vector clock will
    cause a one‑time re‑download.
- Scans remain gated on "new file written" and subject to the 500 ms
  attachment‑only throttle — preventing both misses and storms.
- Code touch points (when implemented):
  - Prefetch phase: `lib/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart`
  - Message decode / vector clock semantics: `lib/features/sync/matrix/sync_event_processor.dart`, `lib/features/sync/model/sync_message.dart`

## Logs To Watch

Marker lifecycle
- `MATRIX_SYNC_V2 marker.local id=…`
- `MATRIX_SYNC_V2 marker.local.ts ts=…`
- `MATRIX_SYNC_V2 marker.schedule id=…` → `marker.flush id=…`
- `MATRIX_SERVICE setReadMarker` (or `setReadMarker.timeline`)
- `MATRIX_SYNC_V2 marker.disposeFlush id=…` (on shutdown)

Startup
- `MATRIX_SYNC_V2 start.liveScan` (first live scan)
- `MATRIX_SYNC_V2 start.catchUpRetry` (when a stored marker exists)
- `MATRIX_SYNC_V2 catchup.rewind` (count floor) and/or
- `MATRIX_SYNC_V2 catchup.rewindTs` (time‑based slice)

Live recovery
- `MATRIX_SYNC_V2 noAdvance.rescan` (activity w/o advancement)
- `MATRIX_SYNC_V2 doubleScan.attachment immediate` and `doubleScan.attachment delayed` (attachments)

## Flags / Config
- `enable_sync_v2` (on for V2; off falls back to legacy listener for stability)
- `enable_logging` (turns on typed V2 metrics and detailed logs)
- Flags UI: Settings → Flags. Read at startup (restart after toggles).

## Validation Checklist

1) Startup catch‑up (no new events)
- Expect:
  - `start.liveScan` and, if marker exists, `start.catchUpRetry`.
  - If id known: `catchup.rewind` with `rewindCount=3`.
  - If ts known: `catchup.rewindTs`.
- Then apply `rows>0`, `marker.local`, `marker.flush`, and `setReadMarker`.

2) Online updates (both devices running)
- For attachments:
  - Expect `doubleScan.attachment immediate` and `.delayed` logs.
  - Apply logs with `rows>0` and marker advancement.
- If activity but no advancement:
  - Expect `noAdvance.rescan` shortly after.

3) Metrics sanity (V2 Metrics panel)
- Fresh sends should not make `dbIgnoredByVectorClock` or `droppedByType.journalEntity` creep.
- `dbApplied` should increase for new payloads.

## File Pointers (changed)
- Consumer: `lib/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart`
- Catch‑up: `lib/features/sync/matrix/pipeline_v2/catch_up_strategy.dart`
- Read marker service + guard helper: `lib/features/sync/matrix/read_marker_service.dart`
- Read marker manager: `lib/features/sync/matrix/pipeline_v2/read_marker_manager.dart`
- Daily text log sink: `lib/services/logging_service.dart`

## Tests (new/updated)
- `test/features/sync/matrix/pipeline_v2/catch_up_strategy_test.dart`
  - Time‑based rewind pagination + slicing by ts
  - Count floor (rewindCount) applies when marker id is present
- `test/features/sync/matrix/pipeline_v2/matrix_stream_consumer_test.dart`
  - Persist id + ts on marker advancement
  - Tail rescan on “activity but no advancement”
  - Existing test adjusted for rewind floor
- `test/features/sync/matrix/pipeline_v2/read_marker_manager_test.dart`
  - Dispose flushes pending marker; exceptions captured
- `test/features/sync/matrix/read_marker_service_test.dart`
  - Service happy paths remain deterministic (guard skipped under `isTestEnv`)
- `test/features/sync/matrix/read_marker_guard_test.dart`
  - Helper `isStrictlyNewerInTimeline` semantics (ts compare + id tie‑break + missing events)

## Behavior Deep‑Dive

Ordering
- `originServerTs` (UTC) ascending; tie‑break by `eventId` lex order.
- Local timezone changes have no effect on ordering or read marker logic.

Startup
- Backfill until last id contained; replay strictly after it.
- Count floor: replay 3 items before the marker id (cheap, safe).
- If ts known, also slice from `ts(marker) − 1ms` (no caps) to avoid skipping same-timestamp neighbors.
- Initial live scan + scheduled catch‑up retry after room hydration.

Live
- Debounced live scans (slightly larger to give the SDK time to settle).
- If attachments present: double scan (now + 200 ms).
- Tail rescan: on activity without advancement; and again after any advancement.

Remote read marker (prod only)
- With a timeline, require candidate to be strictly newer than `room.fullyRead` by `originServerTs` + id tie‑break (helper).
- Without a timeline, skip sending to avoid downgrading; local remains authoritative and will republish later.

## Quick Recovery (if you still see misses)
- Share logs from `logs/lotti-YYYY-MM-DD.log` around the miss:
  - `liveScan processed=…`, `noAdvance.rescan`, `doubleScan.*`
  - `marker.local` / `marker.flush` and `setReadMarker`
  - Apply logs: `rows=… status=…`
- If needed, temporarily disable `enable_sync_v2` to run the legacy listener while diagnosing.

## Known Issues (field logs)

Attachment prefetch storm (high CPU/network, noisy logs)
- Symptoms observed on mobile during desktop burst updates:
  - Repeated `MATRIX_SERVICE writeToFile: downloading /text_entries/YYYY-MM-DD/<id>.text.json` followed by `saveAttachment: wrote file …` for the same paths every 150–300 ms.
  - Frequent `MATRIX_SYNC_V2 noAdvance.rescan: no advancement; scheduling tail rescan (attachments=true, syncEvents=0)` with `liveScan processed=1` loops.
  - Metrics show `prefetch` counts spiking (e.g., `prefetch=400+`) without corresponding marker advancement.
- Likely root cause:
  - Attachment prefetch is unconditional; the consumer re-downloads the same attachment on each live rescan/double-scan even if it’s already on disk.
  - Seeing only attachment events in the live slice (`syncEvents=0`) triggers tail rescans, which in turn trigger more unconditional prefetches — a positive feedback loop.
- Supporting log signatures to look for:
  - `writeToFile: downloading /text_entries/2025-10-16/2542ad70-….text.json` repeating many times.
  - `noAdvance.rescan (attachments=true, syncEvents=0)` and `doubleScan.attachment immediate/delayed` repeating.
- Fixed in V2 pipeline:
  - Per-path dedupe before download; skip when file exists and is non-empty.
  - Gate rescans (tail + double) on “new file written”, not merely “attachment present”.
  - Attachment-only tail rescans are throttled by a 500 ms minimum gap.
  - Metrics still record prefetch attempts and lastPrefetched paths for diagnostics.

Same-path updates (newer content with the same filename)
- Symptom: updates can be skipped if dedupe uses existence only.
- Status: addressed by vector‑clock aware prefetch (see What We Fixed/Added → 6).
- Validation: for a burst of updates on the same `jsonPath`, mobile should
  re‑download exactly when `incomingVectorClock` > local, then advance marker.
- Code touch points:
  - Attachment prefetch call site: `lib/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart:547` (prefetch loop) and rescan triggers at `lib/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart:729`, `:742`, `:748`.
  - Attachment writer/dedupe: `lib/features/sync/matrix/save_attachment.dart`.

## Design Rationale
- Local is authoritative; remote is a hint only to avoid skipping messages.
- Rewind (id floor + time) prefers small replays (safe with vector clocks) over any chance of missing items.
- Double scans and tail scans eliminate ordering/timing races on live streams.

## Message‑Driven JSON Apply

Motivation
- JSON `journalEntity` files reuse the same `jsonPath` across versions. Prefetching by filename causes storms and can skip newer content if we only check for existence.
- The authoritative version is carried in the text message (`SyncMessage.journalEntity`), which includes `jsonPath`, `vectorClock`, and `status`.

Approach
- Treat the text message as the decision point:
  - Parse `jsonPath` and `incomingVectorClock` from the event text.
  - Read local JSON (if any) and compare `meta.vectorClock`.
  - If incoming is strictly newer or concurrent → fetch JSON bytes and write atomically; then apply to DB.
  - If older/equal → skip fetch and apply.
- Conflicts (`concurrent`) continue to be recorded in the sync DB for manual resolution. Marker still advances.

Implementation plan
- Consumer:
  - Eliminate JSON prefetch; file events no longer trigger downloads/rescans.
  - Optionally maintain an AttachmentIndex mapping `relativePath → latest descriptor` as file events arrive (no side effects).
- Loader:
  - Replace the current file loader with a smart loader which:
    - Reads local JSON when up‑to‑date
    - Otherwise resolves a descriptor and downloads JSON bytes
    - Writes atomically (temp + rename), then returns parsed entity
- Apply:
  - SyncEventProcessor uses the smart loader; apply logic remains the same (DB updates, metrics, conflict reporting).

Benefits
- Correctness: vector clocks, not filenames, decide when to fetch/write.
- Stability: no JSON prefetch storms; rescans occur only on meaningful changes and remain throttled for attachment‑only activity.
- Simplicity: single decision point (text) for JSON; file events become an index source.

### Media Prefetch (Images/Audio/Video)

- Policy
  - Prefetch media on-missing: download images/audio/video when attachment events arrive and the file is not on disk.
  - Never prefetch JSON; JSON is applied via the message‑driven path above.
  - Do not trigger rescans from media; prefetch must not affect the pipeline schedule.
- Implementation
  - Attachment events are always recorded into an in‑memory `AttachmentIndex` keyed by `relativePath`.
  - The consumer increments a `prefetch` counter and records `lastPrefetched` paths for diagnostics for all attachments, but only downloads media (`image/*`, `audio/*`, `video/*`).
  - JSON writes happen during apply using `AttachmentIndex` and atomic write (temp + rename) when the incoming vector clock is newer or concurrent.
- Rationale
  - Keeps the stream stable by avoiding JSON write storms while ensuring media is readily available when referenced.
  - One decision point for JSON correctness (vector clocks), optional on-missing prefetch for media responsiveness.

### AttachmentIndex and Loader Details

- Single shared instance
  - The consumer and the Smart loader MUST share the same `AttachmentIndex`.
  - Enforced by construction: `MatrixService` now requires an `AttachmentIndex` and passes it to both sides (no fallbacks).
  - Why: avoids split-index races where `record()` and `find()` operate on different instances (observed as miss → record → miss).

- Path normalization and robust recording
  - Index records any event that includes `content.relativePath` (not just those with attachment mimetypes). This is robust to SDK MIME quirks.
  - Keys are stored in both forms: with leading slash (`/path`) and without (`path`). Lookups try both, eliminating format mismatches.
  - File: `lib/features/sync/matrix/pipeline_v2/attachment_index.dart`.

- SmartJournalEntityLoader behavior
  - With incoming vector clock: compare to local; fetch JSON only if newer/concurrent; write atomically (temp + rename); then parse + apply.
  - Without vector clock: if JSON missing/empty, fetch via `AttachmentIndex`; otherwise read local.
  - After parsing JSON, ensure referenced media (images/audio) only if missing; write atomically.
  - Logging added for diagnostics:
    - `smart.fetch.miss` / `smart.json.written` for JSON
    - `smart.media.ensure` / `smart.media.written` for media
  - File: `lib/features/sync/matrix/sync_event_processor.dart`.

- Consumer first pass logging
  - For any event with a `relativePath`, logs a compact summary of the attachment: id, path, mime, msgtype, hasUrl, hasFile.
  - Still downloads only media (image/audio/video) on-missing; JSON is never downloaded here.
  - Files: `lib/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart`.

- Missing descriptor handling
  - If a text apply misses a JSON descriptor (`attachment descriptor not yet available`), it is treated as a retriable failure.
  - We keep retrying beyond the normal cap for this specific condition and avoid marking the event as handled, so the marker does not advance spuriously.
  - File: `matrix_stream_consumer.dart` (`retry.missingAttachment`).

### Invite Flow (desktop QR) – Brief

- Invites are only surfaced when targeted to this client (Matrix `state_key == client.userID`).
- The QR page shows an accept dialog when an invite arrives while that page is open.
- Files: `gateway/matrix_sdk_gateway.dart` (filter), `ui/matrix_logged_in_config_page.dart` (prompt).
