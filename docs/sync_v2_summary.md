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
- Code touch points:
  - Attachment prefetch call site: `lib/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart:547` (prefetch loop) and rescan triggers at `lib/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart:729`, `:742`, `:748`.
  - Attachment writer/dedupe: `lib/features/sync/matrix/save_attachment.dart`.

## Design Rationale
- Local is authoritative; remote is a hint only to avoid skipping messages.
- Rewind (id floor + time) prefers small replays (safe with vector clocks) over any chance of missing items.
- Double scans and tail scans eliminate ordering/timing races on live streams.
