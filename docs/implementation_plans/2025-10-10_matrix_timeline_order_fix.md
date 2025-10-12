# Implementation Plan – Matrix Timeline Ordering Fix

**Date:** 2025-10-10  
**Author:** Codex (assistant)  
**Status:** Approved

## Summary

Incoming Matrix events were processed newest-first which caused the read marker
to trail one update behind. This manifested as remote edits surfacing only on
the second sync cycle. The fix reorients processing to oldest → newest and
defers the read-marker update to the newest successfully ingested event.

While implementing this, we hardened the timeline drain: extracted a dedicated
Historical: `TimelineDrainer`, added optional metrics, implemented backpressure in the
listener, and fixed a snapshot-disposal leak during limit escalation.

## Goals

- Correct ordering: process remote timeline events oldest-first while batching.
- Exact-once advancement: move `lastReadEventContextId` to the newest
  successfully handled event and update the Matrix read marker once.
- Retain robustness: maintain retry semantics for failures and tail-settle
  retries to avoid the one-behind edge.
- Memory safety: dispose unused snapshot timelines during limit escalation.
- Observability: optional, low-overhead metrics for drains and retries.
- Maintain test green and update documentation to reflect the new flow.

## Non-Goals

- No changes to outbound sync, gateway auth flows, or read-marker persistence
  storage.
- No attempt to stream partial failures; the existing retry logic remains.
- No UI modifications.

## Deliverables

1. Code
   - Historical: Extract `TimelineDrainer` in `lib/features/sync/matrix/timeline.dart` to
     encapsulate the drain loop and compute-from-timeline logic.
   - Order events deterministically by `(originServerTs, eventId)`.
   - Replace id→index map rebuild with a reverse scan to locate last-read.
   - Defer read-marker update to the newest successfully processed event.
   - Historical: Dispose snapshot timelines created during `timelineLimits` escalation when
     unused, and after use when not the live attached instance.
   - Add optional `TimelineMetrics` and `TimelineConfig.collectMetrics` flag;
     emit a threshold log when drain passes exceed 2.
   - Add `TimelineConfig.lowEnd` preset for constrained devices.
   - Historical: Implement backpressure in `MatrixTimelineListener` (removed):
     - cap pending SDK events at 1000 (drop oldest);
     - process in deduped batches of 500.

2. Tests
   - Update `process_new_timeline_events_test.dart` expectations to assert a
     single read-marker advancement to the newest event.
   - Add/extend:
     - `timeline_ordering_test.dart` (ordering helpers)
     - `timeline_multipass_test.dart` (multi-pass sync behaviour)
     - `timeline_drainer_test.dart` (compute-from-timeline + minimal drain)
     - `matrix_timeline_listener_test.dart` (debounce flush + backpressure)
   - Keep existing suites green: `matrix_timeline_flow_test.dart`,
     `timeline_test.dart`.

3. Docs
   - Refresh `lib/features/sync/README.md` to describe the new drain,
     backpressure, metrics, and snapshot disposal.
   - Ensure `docs/architecture/sync_memory_audit.md` remains accurate.

## Risks & Mitigations

| Risk | Mitigation |
| --- | --- |
| Matrix SDK returns events descending. | Sort by `(originServerTs, eventId)` to enforce order. |
| Increased complexity in drain logic. | Historical; V1 code was removed. |
| Memory pressure from timeline snapshots. | Dispose unused snapshots immediately; dispose used snapshots after read-marker update when not live. |
| Overhead from metrics collection. | Gate counters/timers behind `TimelineConfig.collectMetrics` (default false). |
| Backpressure could drop oldest pending SDK events. | Processing is chronological with per-batch dedupe; live drains and escalation ensure eventual consistency. |

## Rollout & Monitoring

- Land behind existing tests; no runtime flags required for correctness.
- Optionally enable `collectMetrics` in dev builds to capture `drainPasses`,
  `eventsProcessed`, `retryAttempts`, and total processing time.
- Watch for `timeline.metrics` logs indicating excessive drain passes (>2).
- Re-run memory audit; ensure snapshot disposal reflects in stable RSS.
