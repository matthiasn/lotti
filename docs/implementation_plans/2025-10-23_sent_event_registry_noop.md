# Matrix Self-Event Suppression — Sent Event Registry Plan

## Summary

- Sending a sync payload echoes the same Matrix event back to the originating device; we currently
  re-fetch attachments, re-apply database writes, and trigger UI updates for our own outbound work.
- We'll capture event IDs returned by the Matrix SDK, stash them in an in-memory registry with a
  short TTL (5 minutes by default), and skip the heavy ingest path whenever those IDs appear back on the timeline.
- The registry remains device-local, automatically expiring entries to bound memory while still
  covering the immediate echo window.

## Goals

- Record every Matrix event ID emitted by this device (text + file payloads) and expose them through
  a lightweight provider.
- Short-circuit timeline ingestion when a matching event ID arrives, while still advancing read
  markers so history stays in sync.
- Add tracing/metrics so we can confirm suppression kicks in and quantify the saved work, including V1 logs and V2 metrics/statistics for suppressed events.
- Keep analyzer/tests clean (`dart-mcp.analyze_files`, focused `dart-mcp.run_tests`).

## Non-Goals

- Persisting sent-event state across launches or sharing it across devices.
- Reworking upstream Matrix SDK callbacks or server-side filtering.
- Changing how true remote events or backlog replay are handled.

## Current Findings

- `MatrixMessageSender.sendMatrixMessage` and `MatrixSdkGateway.send*` already surface the SDK event
  ID, but we drop it after logging.
- `processTimelineEventsIncremental` treats any event with `senderId != client.userID` as remote;
  echoes from our other device sessions still look remote and run through `_ingestAndComputeLatest`.
- Re-processing our own payload re-downloads attachments via `SmartJournalEntityLoader`, applies
  vector-clock checks in `SyncEventProcessor`, and increments metrics, doubling CPU and IO even
  though the data is already on disk.
- Read markers only advance after `_ingestAndComputeLatest` finishes, so any suppression still needs
  to report the event as "read" to prevent the UI from regressing.

## Design Overview

1. **Sent Event Registry**
  - New class (e.g. `SentEventRegistry`) keeping `{eventId: expiry}` in memory with a default TTL (
    configurable, initial value ~5 minutes).
  - Provide `register(String eventId, {Source source})`, `bool consume(String eventId)`, and
    `void prune(DateTime now)` helpers; entries remain until TTL expiry so repeated echoes or retries continue to short-circuit.
  - Expose via Riverpod (`sentEventRegistryProvider`) so both send and ingest layers can access the
    same instance.
2. **Register on Send Paths**
  - Update `MatrixMessageSender.sendMatrixMessage` to capture the `eventId` from
    `room.sendTextEvent`, register it, and pass it to `onSent`.
  - Change the `onSent` callback signature to
    `void Function(String eventId, SyncMessageType sentType)` (or similar) so existing metrics can
    keep their counters while we avoid extra matrix lookups.
  - Register file event IDs inside `_sendFile`, and mirror the same behaviour in
    `MatrixSdkGateway.sendText`/`sendFile`.
  - Audit other direct SDK send sites (e.g. verification, invites) to confirm they do not need
    suppression.
3. **Suppress During Ingest**
  - Inject the registry into the timeline layer (either extend `TimelineContext` or plumb via
    constructor so `_ingestAndComputeLatest` can access it).
  - At the top of the per-event loop, call `registry.consume(event.eventId)`; if true, skip
    attachment prefetch + `eventProcessor.process`, while keeping the marker advancement and retry state in sync.
  - Still update `latestAdvancingEventId` so read markers advance, and increment a dedicated
    metric (`incDbSuppressedSelfEvent`) for observability.
  - Emit a debug log (`selfEventSuppressed`) with the event ID and original sender for field
    verification.
4. **TTL & Maintenance**
  - Run `prune()` opportunistically when registering new IDs and after each timeline batch (honouring a prune interval) to evict stale entries without scanning the map on every call.
  - Guard the registry with `Clock`/`DateTime.now()` injection for deterministic tests.
  - Size footprint: worst-case a few thousand entries; add an upper bound (e.g. drop oldest once >
    5k) as a safety net.

## Data Flow & API Changes

- `MatrixMessageSender.sendMatrixMessage` signature updates `onSent` to accept the generated event
  ID (and possibly sent type). `MatrixService.sendMatrixMsg` and tests must adapt.
- Introduce `SentEventRegistry` (implemented in
  `lib/features/sync/matrix/sent_event_registry.dart`) plus a provider file
  wired through `lib/providers/service_providers.dart`.
- Extend `MatrixTimelineListener` / `TimelineContext` so `_ingestAndComputeLatest` can pull the
  registry (e.g. via constructor parameter or `listener.sentEventRegistry`).
- Add new metric counters and logging hooks within both timeline pipelines so suppression counts are visible alongside existing metrics (V1 logging, V2 metrics snapshot), and ensure suppressed events keep read markers and retry state consistent.
- No database schema or sync protocol changes; all adjustments remain client-local.

## Implementation Phases

### Phase 0 — Discovery ✅

- Confirmed send/ingest call-sites and event ID availability via quick code reads (
  `MatrixMessageSender`, `MatrixSdkGateway`, `timeline.dart`).

### Phase 1 — Registry Foundation ✅

- Implemented `SentEventRegistry` with TTL logic, prune helpers, interval-based pruning, and a size cap.
- Added shared Riverpod provider wiring and debug accessors for tests.

### Phase 2 — Capture Event IDs on Send ✅

- Updated sender/gateway paths to register event IDs and propagate them through the callback.
- Adjusted `MatrixService` and unit tests; also added coverage for failure/null paths.

### Phase 3 — Suppress During Timeline Ingest ✅

- Wired the registry into both timeline pipelines, skipping processing while keeping marker and retry state in sync.
- Added suppression logging/metrics counters for V1 logging and V2 metrics snapshots.

### Phase 4 — Validation & Docs ✅

- Added comprehensive unit/integration coverage across registry, sender, gateway, and both timelines.
- Analyzer/tests run via `dart-mcp`.
- Updated README/plan documentation to describe suppression behaviour and monitoring.

## Testing Strategy

- **SentEventRegistry tests** validating add/consume, TTL expiry, and eviction cap.
- **MatrixMessageSender tests** ensuring text/file sends register IDs and forward them to the
  callback.
- **Timeline ingest tests** (likely via existing `timeline_test.dart` helpers) confirming events
  registered as self-sent bypass `eventProcessor.process` yet still advance the marker.
- Update any golden metrics tests to expect the new suppression counter.

## Risks & Mitigations

- **Clock skew / long round-trips** — choose a TTL that comfortably covers typical echo latency; log
  when suppression misses so we can adjust.
- **Shared rooms across devices** — only suppress events originating from this registry; events from
  other devices (different event IDs) still process normally.
- **Memory growth** — enforce TTL pruning + entry cap to keep the registry lightweight.
- **API ripple** — callback signature change impacts several mocks/tests; plan updates before
  landing to keep builds green.

## Rollout & Monitoring

- Include suppression metrics in the Matrix Stats snapshot so QA can confirm reductions in apply
  counts.
- Add temporary verbose logging behind a feature flag (or debug build) to cross-check suppression in
  staging.
- Monitor sync logs post-launch to verify `selfEventSuppressed` entries line up with outbound
  traffic.
