# Matrix Self-Event Suppression — Sent Event Registry Plan

## Summary

- Sending a sync payload echoes the same Matrix event back to the originating device; we currently
  re-fetch attachments, re-apply database writes, and trigger UI updates for our own outbound work.
- We'll capture event IDs returned by the Matrix SDK, stash them in an in-memory registry with a
  short TTL, and skip the heavy ingest path whenever those IDs appear back on the timeline.
- The registry remains device-local, automatically expiring entries to bound memory while still
  covering the immediate echo window.

## Goals

- Record every Matrix event ID emitted by this device (text + file payloads) and expose them through
  a lightweight provider.
- Short-circuit timeline ingestion when a matching event ID arrives, while still advancing read
  markers so history stays in sync.
- Add tracing/metrics so we can confirm suppression kicks in and quantify the saved work.
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
    `void prune(DateTime now)` helpers; consuming removes the entry to avoid matching historical
    replays.
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
    attachment prefetch + `eventProcessor.process`.
  - Still update `latestAdvancingEventId` so read markers advance, and increment a dedicated
    metric (`incDbSuppressedSelfEvent`) for observability.
  - Emit a debug log (`selfEventSuppressed`) with the event ID and original sender for field
    verification.
4. **TTL & Maintenance**
  - Run `prune()` opportunistically when registering new IDs and after each timeline batch to evict
    stale entries.
  - Guard the registry with `Clock`/`DateTime.now()` injection for deterministic tests.
  - Size footprint: worst-case a few thousand entries; add an upper bound (e.g. drop oldest once >
    5k) as a safety net.

## Data Flow & API Changes

- `MatrixMessageSender.sendMatrixMessage` signature updates `onSent` to accept the generated event
  ID (and possibly sent type). `MatrixService.sendMatrixMsg` and tests must adapt.
- Introduce `SentEventRegistry` (likely in
  `lib/features/sync/matrix/state/sent_event_registry.dart`) plus a provider file.
- Extend `MatrixTimelineListener` / `TimelineContext` so `_ingestAndComputeLatest` can pull the
  registry (e.g. via constructor parameter or `listener.sentEventRegistry`).
- Add new metric counters and logging hooks within `MatrixStreamConsumer` for suppressed events.
- No database schema or sync protocol changes; all adjustments remain client-local.

## Implementation Phases

### Phase 0 — Discovery ✅

- Confirmed send/ingest call-sites and event ID availability via quick code reads (
  `MatrixMessageSender`, `MatrixSdkGateway`, `timeline.dart`).

### Phase 1 — Registry Foundation

- Implement `SentEventRegistry` with TTL logic, prune helpers, and optional size cap.
- Provide Riverpod wiring and expose a simple interface for tests (mockable via `ProviderContainer`
  override).

### Phase 2 — Capture Event IDs on Send

- Update `MatrixMessageSender`, `_sendFile`, and `MatrixSdkGateway` to register IDs and adapt
  callbacks/metrics.
- Adjust `MatrixService` + unit tests to handle the new callback signature while preserving existing
  sent counters.

### Phase 3 — Suppress During Timeline Ingest

- Inject the registry into timeline processing, skip `eventProcessor.process` when consuming an ID,
  and ensure read marker advancement still occurs.
- Add suppression logging + metrics, and make sure `_retryTracker`/diagnostics ignore suppressed
  events.

### Phase 4 — Validation & Docs

- Unit-test the registry (TTL eviction, consume semantics, size cap) and add targeted tests around
  `MatrixMessageSender` + timeline suppression.
- Run analyzer/tests (`dart-mcp.analyze_files`, focused `dart-mcp.run_tests`).
- Update `lib/features/sync/README.md` (and any feature-specific docs) to describe self-event
  suppression behaviour.
- Note the change in the next CHANGELOG entry.

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
