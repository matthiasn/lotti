# Implementation Plan – Matrix Timeline Ordering Fix

**Date:** 2025-10-10  
**Author:** Codex (assistant)  
**Status:** Approved

## Summary

Incoming Matrix events are currently processed in reverse order which causes the
read marker to trail one update behind. This manifests as remote edits only
surface on the second sync cycle. We will change the processing loop to respect
the natural oldest → newest ordering, defer the read-marker update until the
newest successfully ingested event, and adjust tests/documentation accordingly.

## Goals

- Process remote timeline events oldest-first while still batching work.
- Advance `lastReadEventContextId` (and the Matrix read marker) exactly once to
  the newest successfully handled event.
- Maintain retry semantics for failed events.
- Keep unit/integration tests green with updated expectations.
- Document the timeline ordering for future maintainers.

## Non-Goals

- No changes to outbound sync, gateway auth flows, or read-marker persistence
  storage.
- No attempt to stream partial failures; the existing retry logic remains.
- No UI modifications.

## Deliverables

1. **Code:**  
   - Update `lib/features/sync/matrix/timeline.dart` to:
     - Skip reversing the event list; instead sort/ensure chronological order.
     - Track the newest event ID that advances the read marker.
     - Call `SyncReadMarkerService.updateReadMarker` once after the loop.
   - Ensure we log the count of processed events (optional but nice).

2. **Tests:**  
   - Update `process_new_timeline_events_test.dart` expectations to assert that
     the newest event ID is written to the read marker.
   - Adjust `timeline_test.dart` (and any other affected suite) to match the new
     ordering.
   - Re-run the focused sync tests (`process_new_timeline_events_test.dart`,
     `matrix_timeline_flow_test.dart`, `matrix_timeline_listener_test.dart`,
     `timeline_test.dart`).

3. **Docs:**  
   - Refresh `lib/features/sync/README.md` to describe the oldest→newest pass
     and single read-marker update.

## Risks & Mitigations

| Risk | Mitigation |
| --- | --- |
| Matrix SDK returns events in descending order on some platforms. | We will sort by `(originServerTs, eventId)` before processing, ensuring deterministic ordering regardless of SDK quirks. |
| Tests rely on previous reverse-order behaviour. | Update mocks and expectations in the affected tests. |
| Regression in retry logic (skipping failed events). | Preserve `_recordProcessingFailure` handling and only advance the marker if the event succeeded. |
