# Sync Inbox Attachment Dedupe And Logging

## Goal

Reduce repeated inbox-side attachment work and shrink sync log volume without
rewriting the sync engine.

## Hard Facts

These are code-backed and log-backed observations from `2026-03-12`.

### Log volume

- `logs/lotti-2026-03-12.log`: about `124 MB`, `770045` lines
- `logs/sync-2026-03-12.log`: about `4.2 MB`, `29552` lines
- sync-family domains account for `677159 / 770045` lines, about `87.94%`

### Biggest general-log categories

- `MATRIX_SYNC attachment.observe`: `244891`
- `MATRIX_SYNC signal`: `170914`
- `MATRIX_SYNC attachment.save`: `83963`
- `MATRIX_SYNC attachment.download`: `83963`
- `MATRIX_SYNC attachmentIndex.record`: `42564`

### Repeated attachment work

- `attachment.observe` lines correspond to only `7033` unique attachment event
  IDs, about `34.82` observations per event ID on average
- `attachment.download` lines correspond to `5244` unique paths, about `16.01`
  downloads per path on average
- `79123 / 83963` download lines are `/agent_entities/...`

### Current code behavior that explains the repeats

- `AttachmentIngestor.process()` emits `attachment.observe` for every attachment
  event with `relativePath` and schedules download work immediately afterward
- `AttachmentIngestor._saveAttachment()` skips existing files only for
  non-agent payloads
- agent payloads under `/agent_entities/...` and `/agent_links/...` are
  explicitly re-downloaded even when the local file already exists
- `MatrixStreamProcessor` keeps only a `5000`-event LRU for duplicate
  first-pass suppression, while catch-up can replay windows up to `10000`

## Scope Of This Pass

This pass is intentionally small and targeted.

### In scope

- suppress repeated processing for the exact same attachment `eventId`
- allow repair downloads when the local file is missing or empty
- preserve current path-reuse behavior for newer agent payload versions
- add tests for duplicate-event suppression and repair
- route sync-family info logging to `sync-YYYY-MM-DD.log` instead of the
  general `lotti-YYYY-MM-DD.log`
- keep sync exceptions mirrored into the general log so failures remain visible

### Out of scope

- redesigning stable agent payload paths
- changing vector-clock or backfill logic
- rewriting catch-up/live-scan scheduling
- removing signal logging entirely

## Planned Code Changes

1. Add an attachment-event handled cache inside `AttachmentIngestor`.
2. Before logging or scheduling download work, check whether this exact
   attachment `eventId` was already handled in the current runtime.
3. If it was already handled:
   - skip `attachment.observe`
   - skip queued/eager download work
   - unless the target file is missing or empty
4. Keep the existing agent-path overwrite behavior for newer attachment events
   with different `eventId`s.
5. Leave descriptor catch-up wakeups intact so pending payload resolution can
   still be nudged forward when a descriptor path becomes available.
6. Route direct sync-family domains (`MATRIX_SYNC`, `MATRIX_SERVICE`,
   `OUTBOX`, `AGENT_SYNC`, `SYNC_SEQUENCE`, `SYNC_BACKFILL`, and logical
   `sync`) into the `sync` daily log.
7. Avoid duplicate per-line sync file writes by letting `LoggingService`
   handle sync-file routing centrally.

## Expected Impact

- far fewer repeated `attachment.observe` lines
- far fewer repeated agent attachment downloads and file writes
- lower CPU, battery, and disk I/O during large offline catch-up waves
- a much smaller general daily log, making the next investigation pass easier
- one time-ordered sync log that includes inbox, outbox, sequence, and backfill
  messages together

## Tests

Add or update targeted tests in
`test/features/sync/matrix/pipeline/attachment_ingestor_test.dart`:

- same agent attachment event does not redownload when already handled and the
  local file exists
- same agent attachment event does redownload when the local file was deleted
- existing non-agent dedupe behavior remains unchanged

## Follow-up After This Pass

The first follow-up from this plan has now landed:

- per-callback `signal.timeline` and `signal.clientStream` logging was replaced
  with summary diagnostics
- catch-up now emits one `catchup.done ... signalSummary ...` line per burst
- live scan now emits one `liveScan.summary ... signalSummary ...` line per
  pass
- the summary keeps the signal source breakdown instead of just silencing it:
  client stream, timeline callback subtype, deferred reasons, coalescing, and
  trailing scheduling are all counted explicitly

If the logs are still too large after this, the next likely cuts are:

1. increase or redesign the processor-level seen-event dedupe window
2. add an integration test with `1000+` offline-created agent entities and
   assert one reconnect pass does not redownload the same attachment event
   repeatedly
