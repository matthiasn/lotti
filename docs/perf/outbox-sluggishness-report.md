# Outbox/Sync UI Sluggishness – Investigation Plan and Recommendations

This report outlines how to reproduce the issue, the most likely hotspots causing jank, what to measure, and a prioritized plan to fix UI sluggishness observed “when saving something while Sync Outbox is active.”

## Summary
- Symptom: On the receiving device (mobile), a single edit made on desktop triggers a noticeable scroll stall (~500 ms) shortly thereafter.
- Focus (updated): This is on the receive path, not send or logging. Disabling logging on mobile had no effect.
- Top suspect: JSON descriptor prefetch (download+decrypt+atomic write) running on the main isolate before apply.
- Additional contributors: JSON decode + DB upsert + second JSON write during apply; sync FS checks.
- Immediate lever validated: Disabling JSON prefetch makes scrolling much smoother during receive.

## Reproduction Checklist
- Enable Sync (Matrix) in settings and ensure you’re logged in.
- Open a typical scrolling screen (e.g., Infinite Journal) and start smooth scrolling.
- Save a new entry or update an existing one (triggers enqueue → outbox send).
- Observe scroll stutter/jank during the next few seconds while outbox processes.
- Optional: open DevTools → Performance, record a timeline spanning save → first send.

## Suspected Hotspots (code map)
1) Logging flood during outbox and pipeline operations
- Calls are frequent in outbox and matrix layers and currently flush to disk per event.
  - `lib/services/logging_service.dart` (file + DB sinks; uses `flush: true` writes)
  - `lib/features/sync/outbox/outbox_service.dart` (many captureEvent calls along runner/drain)
  - `lib/features/sync/outbox/outbox_processor.dart` (per-item send+retry logging)
  - `lib/features/sync/matrix/matrix_service.dart` (connectivity rescans + lifecycle)
  - `lib/features/sync/matrix/matrix_message_sender.dart` (file uploads + text sends)

Why risky:
- File sink uses `await file.writeAsString(..., flush: true)` for every line. Even though it’s async, flush defeats buffering and increases I/O pressure. High-volume logging while sending files can starve the event loop and add scheduling latency noticeable in UI frames.

2) Attachment sends: synchronously materializing large byte arrays
- `lib/features/sync/matrix/matrix_message_sender.dart` `_sendFile(...)` does:
  - `await file.readAsBytes()` followed by `room.sendFileEvent(...)`.
- If image/audio files are large, memory spikes and CPU (encryption/compression by the Matrix SDK) can run on the UI isolate. This can introduce frame drops during active user interaction.

2a) Descriptor JSON prefetch (receive side)
- Path: `lib/features/sync/matrix/pipeline/attachment_ingestor.dart` → `lib/features/sync/matrix/save_attachment.dart`
  - Calls `event.downloadAndDecryptAttachment()` then `atomicWriteBytes` to save descriptor JSON before apply.
  - Uses synchronous `existsSync()` / `lengthSync()` checks and a flushy atomic write/rename pattern; all on main isolate.
  - Even a single descriptor prefetch can introduce a ~500 ms hitch if it overlaps with scrolling.

3) Bursty scheduling and repeated scans
- Outbox drain and Matrix pipeline both try to make forward progress promptly.
  - Outbox: `_drainOutbox()` loops, immediate scheduling for more work, watchdog nudges (`lib/features/sync/outbox/outbox_service.dart`).
  - Pipeline: live-scan and catch-up coalescing (debounced, but still bursty under activity) (`lib/features/sync/matrix/pipeline/matrix_stream_consumer.dart`).
- Combined with logging, these bursts amplify jank risk.

4) Activity gating policy allows sending while the user remains active
- Gate: `lib/features/user_activity/state/user_activity_gate.dart`
  - Waits until idle, but has a “hard deadline” (2s) that forces progress even if the user is still interacting. That means heavy work can start mid-scroll, by design.

5) Duplicate JSON writes during receive
- Prefetch writes descriptor JSON to disk; apply then calls `JournalDb.updateJournalEntity(...)`, which writes JSON again via `saveJournalEntityJson(updated)` (see `lib/database/database.dart:309`). This doubles write pressure for a single message.

## What to Measure (Profiling Plan)
- Use Flutter DevTools Performance/TIMELINE:
  - Record from “save” → “first outbox send” → “attachments sent”.
  - Look for long Dart tasks, GC spikes, and frame jank clusters.
- Compare with logging disabled:
  - Temporarily disable logging via the config flag and re-record.
  - If frame times improve, prioritize logging changes.
- CPU sampling:
  - Check time spent inside Matrix SDK calls during `sendFileEvent` and `sendTextEvent`.
- Event volume:
  - Count events emitted by outbox/pipeline/logging in a 5–10 second window.
  - If > few hundred log lines, it’s excessive for UI smoothness.

## Fast Experiments (no code changes to product flows)
- Toggle logging off: disable `enableLoggingFlag` in settings and observe UI.
- Reduce outbox pressure temporarily: pause outbox or disable attachments resend flag to see if sluggishness correlates strongly with uploads.
- Disable Sync temporarily: verify that save operations alone are not the bottleneck.

Observed outcome (session)
- Disabling JSON prefetch (globally or JSON-only) on the receiver significantly reduces or removes the ~500 ms scroll stall for single edits.

## Findings From Code Review
- LoggingService
  - Writes to DB (Drift in background isolate) AND to a text file per event. The file sink uses `flush: true` (forces immediate flush). High-frequency disk flushes are notorious for degrading responsiveness.
- Outbox activity gate
  - Gate allows sending to happen while the user is interacting (after a 2s forced-progress deadline). That’s a deliberate trade-off but probably too aggressive for smooth UX during scroll.
- Attachment sending
  - Reads entire file into memory (`readAsBytes`) before sending; can be heavy for large media. If SDK encryption is CPU-heavy on the same isolate, it can cause visible jank.
- Pipeline scheduling
  - Catch-up and live scans are coalesced, but they still run soon after activity (connectivity, new events), adding load during UI use.

## Prioritized Fix Plan
1) Logging volume and sink strategy (likely high ROI)
- Coalesce/single-writer:
  - Introduce a buffered queue and a periodic writer (e.g., 5–10 writes/second) instead of per-log flush.
  - Avoid `flush: true` for every line in production; reserve flush for app shutdown or explicit diagnostics.
- Sampling + deduplication:
  - Deduplicate repeated outbox/pipeline messages and add counters (e.g., “retry cap reached xN”).
  - Introduce a per-domain rate limit (e.g., max 50/sec) with “dropped N similar logs” summaries.
- Configuration:
  - Keep `enableLoggingFlag` but also add `logSampleRate` and `logFlushPolicy` for flexible troubleshooting.

2) Respect user activity more strictly during heavy work
- Increase or remove the 2s “forced progress” deadline in `lib/features/user_activity/state/user_activity_gate.dart` so heavy work doesn’t start mid-scroll.
- Alternatively, time-slice outbox processing while the user is active (e.g., send at most 1 item, then back off for 1–2s of idle to yield frames), maintaining throughput when idle.

3) Reduce per-send payload cost
- Prefer streaming/chunked reads if the Matrix SDK supports it; otherwise, constrain image/audio sizes before sending (ensure thumbnails or compression logic is applied earlier if not already).
- If unavoidable to read entire file, consider using an isolate for preprocessing (e.g., image resize/compress) to minimize main-isolate CPU.

4) Burst coalescing for outbox
- After each successful send, insert a small delay (e.g., 50–100ms) when UI is active to give the scheduler breathing room.
- Keep the existing coalescing in the matrix pipeline as-is, but ensure it doesn’t overlap aggressively with outbox when the user is interacting (light backoff if outbox is busy and user is active).

5) Instrumentation (targeted)
- Add `dart:developer` timeline events around:
  - Outbox: `sendNext`, `_drainOutbox`, and the repository calls.
  - Matrix sender: `_sendFile`, `sendTextEvent`.
  - Logging: write-to-file block (behind a debug flag to avoid more overhead in prod).
- These spans make it easy to pinpoint whether the wall time is dominated by I/O, crypto, or logging.

6) Receive-side specific mitigations (based on findings)
- JSON-only prefetch off by default (mobile recommended):
  - In `lib/features/sync/matrix/utils/timeline_utils.dart`, have `shouldPrefetchAttachment` return `isMedia` instead of `isSupported` to skip `application/json` prefetch.
  - Effect: descriptor JSON is fetched on demand during apply, avoiding prefetch work on the main isolate while scrolling.
- Avoid duplicate JSON writes:
  - When apply runs after a just-fetched descriptor, skip the second `saveJournalEntityJson` write if unchanged.
- Make FS checks async and yield:
  - Replace `existsSync` / `lengthSync` with async checks (or `FileStat.stat`) and insert a micro‑yield after N attachments to keep frames responsive.
- Idle-only prefetch:
  - Gate prefetch on user idleness so descriptor/media hydration runs when the UI is not actively interacting.

## Validation Criteria
- With logging improvements and stricter activity gating, scrolling stays smooth (no >16ms frame spikes) during active outbox sends.
- Outbox throughput remains acceptable; when idle, the system catches up quickly.
- DevTools timeline shows fewer long Dart tasks and reduced GC pressure during sends.

## Rollout Strategy
- Start with logging changes (buffering + sampling), behind a feature flag.
- Adjust activity gating thresholds (increase idle requirement; avoid forced progress while scrolling) and measure user-perceived smoothness.
- Iterate on outbox pacing and, if needed, isolate-based preprocessing for large attachments.
 - For receive: disable JSON prefetch (or JSON-only) and validate that single‑edit stalls are gone or below perceptible levels.

## References (code)
- Logging sinks: `lib/services/logging_service.dart`
- Outbox service: `lib/features/sync/outbox/outbox_service.dart`
- Outbox processor: `lib/features/sync/outbox/outbox_processor.dart`
- Matrix service: `lib/features/sync/matrix/matrix_service.dart`
- Matrix sender (attachments): `lib/features/sync/matrix/matrix_message_sender.dart`
- Activity gate: `lib/features/user_activity/state/user_activity_gate.dart`
- Pipeline (coalescing): `lib/features/sync/matrix/pipeline/matrix_stream_consumer.dart`

---
If you want, I can next: (a) run a quick profiling session and append a short timeline analysis, or (b) implement JSON-only prefetch off (and/or idle-only prefetch) behind a flag to A/B the receive-path improvement, and (c) separately land the low-risk logging buffering.

## Session Findings & Open Questions
- Confirmed: Receive-side pipeline is the jank source; logging off doesn’t help.
- Disabling JSON prefetch improves smoothness for single edits (receiver-side stall drops significantly).
- Likely duplicated JSON writes on receive (prefetch write, then apply write) worsen stalls.

Open questions
- How long do the individual stages take on device: `downloadAndDecryptAttachment`, `atomicWriteBytes`, `jsonDecode`, and `updateJournalEntity`? Add timeline spans to quantify.
- Does Matrix SDK decrypt on the main isolate for our target platforms, and can we offload it?
- Are UI rebuilds from `UpdateNotifications` causing additional hitches on certain screens? If yes, should we increase fromSync debounce or coalesce more aggressively during bursts?
- Should JSON-only prefetch be permanently disabled on mobile (keep media prefetch), or gated by idleness?
