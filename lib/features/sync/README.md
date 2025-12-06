# Sync Feature Documentation

## Overview

Lotti synchronises encrypted journal data across devices through the Matrix
protocol. Since the 2025-10-06 refactor the sync stack is composed of
constructor-injected services, Riverpod providers, and a coordinated lifecycle
that keeps the pipeline testable and observable.

## UI Surfaces

- Sync Settings (under `/settings/sync`) now pulls its Outbox and Conflicts list pages from
  `lib/features/sync/ui/...`, using a shared `SyncListScaffold` for filter chips, inline summaries,
  and animated empty/loading states.
- Segmented filter chips hide zero-value badges, suppress redundant success/resolved totals, and
  draw tinted, bordered badges for pending/error/unresolved counts so actionable numbers stand out
  while the empty state card stays within the content width on phones.
- `OutboxListItem` + `OutboxListItemViewModel` format payload metadata, retries, attachments, and
  retry affordances; retry actions are confirmed before requeueing.
- `ConflictListItem` + `ConflictListItemViewModel` present entity context, vector clock details, and
  semantics labels for accessibility. Tapping navigates to the existing conflict detail route.
- Tests for these surfaces live alongside other sync UI coverage under
  `test/features/sync/ui/...` with cross-cutting widget smoke tests in `test/widgets/sync`
  (see `test/widgets/sync/conflict_list_item_test.dart` and
  `test/widgets/sync/sync_list_scaffold_test.dart` for dedicated widget coverage).

## Architecture

### Core Services

| Component | Responsibility |
| --- | --- |
| **SyncEngine** (`matrix/sync_engine.dart`) | Owns the high-level lifecycle via `SyncLifecycleCoordinator`, runs login/logout hooks, and surfaces diagnostic snapshots. |
| **MatrixService** (`matrix/matrix_service.dart`) | Wraps the `MatrixSyncGateway`, coordinates verification flows, exposes stats/read markers, and delegates lifecycle work to the engine. |
| **MatrixSyncGateway** (`gateway/matrix_sdk_gateway.dart`) | Abstraction over the Matrix SDK for login, room lookup, invites, timelines, and logout. |
| **MatrixMessageSender** (`matrix/matrix_message_sender.dart`) | Encodes `SyncMessage`s, uploads attachments, registers the Matrix event IDs it emits, increments send counters, and notifies `MatrixService`. |
| **SentEventRegistry** (`matrix/sent_event_registry.dart`) | In-memory TTL cache of event IDs produced by this device so timeline ingestion can drop echo events without re-applying them. |
| **MatrixStreamConsumer** (`matrix/pipeline/matrix_stream_consumer.dart`) | Stream-first consumer: attach-time catch-up (SDK pagination/backfill with graceful fallback), micro-batched streaming, attachment descriptor observation, monotonic marker advancement, retries with TTL + size cap, circuit breaker, and metrics. |
| **SyncRoomManager** (`matrix/sync_room_manager.dart`) | Persists the active room, filters invites, validates IDs, hydrates cached rooms, and orchestrates safe join/leave operations. |
| **SyncEventProcessor** (`matrix/sync_event_processor.dart`) | Decodes `SyncMessage`s, mutates `JournalDb`, emits notifications (e.g. `UpdateNotifications`), and surfaces precise `applied/skipReason` diagnostics so the pipeline can distinguish conflicts, older/equal payloads, and genuine missing-base scenarios. |
| **SyncReadMarkerService** (`matrix/read_marker_service.dart`) | Writes Matrix read markers after successful timeline processing and persists the last processed event ID. |
| **OutboxService** (`outbox/outbox_service.dart`) | Stores pending messages, resolves attachments, and hands work to `MatrixMessageSender`. |
| **UserActivityGate** (`features/user_activity/state/user_activity_gate.dart`) | Exposes reactive idleness signals so heavy timeline processing defers while the user is active. |
| **SyncSequenceLogService** (`sequence/sync_sequence_log_service.dart`) | Tracks (hostId, counter) pairs for gap detection; enables self-healing backfill. |
| **BackfillRequestService** (`backfill/backfill_request_service.dart`) | Periodically scans for missing entries and broadcasts batched backfill requests. |
| **BackfillResponseHandler** (`backfill/backfill_response_handler.dart`) | Responds to backfill requests by re-sending entries; handles responses to update sequence log. |

### Provider Wiring & Lint Guard

- Core sync services are provided via Riverpod (`lib/providers/service_providers.dart`)
  and overridden in `lib/main.dart` when the app boots. Tests override the same
  providers to inject mocks/fakes.
- The custom lint rule `no_get_it_in_sync` (shipping from
  `tool/lotti_custom_lint`) fails analysis if `getIt` is referenced inside
  `lib/features/sync` or `lib/widgets/sync`, preventing regressions.
- Additional documentation is available in `docs/architecture/sync_engine.md`.

### Sync Pipeline

- `MatrixStreamConsumer` attaches directly to the sync room and performs
  attach-time catch-up via SDK pagination/backfill with a graceful fallback for
  large gaps.
- Signal-driven ingestion (2025-10-28):
  - Client stream events are treated as signals that always trigger a
    `forceRescan()` with catch-up. An in-flight guard prevents overlapping
    catch-ups.
  - Live timeline callbacks continue to schedule debounced live scans; on
    scheduling failure, the consumer falls back to `forceRescan()`.
  - Marker advancement happens only from ordered slices returned by
    catch-up/live scans, never directly from the client stream.
- Live streaming is micro-batched and ordered chronologically with
    de-duplication by event ID; attachment descriptors are observed and recorded before invoking
    `SyncEventProcessor`. Media is not downloaded here; retrieval happens later via separate
    download paths or on-demand processing.
  - Read markers advance monotonically using Matrix timestamps with event IDs as
    tie-breakers. The consumer persists the newest processed ID through
    `SyncReadMarkerService` so fresh sessions resume from the correct position.
  - Retries apply exponential backoff with a TTL, bounded queue, and circuit
    breaker to avoid thrashing on persistent failures. Diagnostics surface per
    event via `SyncApplyDiagnostics`.
  - Optional typed metrics (`SyncMetrics`) power the Matrix Stats UI and tooling.

- Coalescing & throttling (2025-11):
  - Catch-up coalesces with a 1s minimum gap. If signals arrive while a
    catch-up is running, exactly one trailing catch-up is scheduled ~1s after
    completion. Logging emits `catchup.start` once at the beginning of a
    coalesced burst and `catchup.done events=<n>` once after the last run.
  - Live-scan never overlaps. `_scanInFlight` is guarded by a small nesting
    counter so nested scans keep the guard asserted until the outermost scan
    finishes. Signals during a scan defer as a single trailing scan scheduled
    after completion. A small base debounce (~120ms) is extended as needed to
    honor the 1s minimum gap; log `signal.liveScan.coalesce`.
  - Attachment double-scan awaits the immediate second pass and schedules a
    delayed pass at +200ms. This reduces churn while still catching
    late-arriving text that pairs with attachments.
  - Historical windows tightened to reduce redundant work:
    - Catch-up `preContextCount = 80`, `maxLookback = 1000`.
    - Live-scan steady tail = 30; audit tails (first two scans) = 50/80/100
      sized by the offline delta.
  - Log noise reduced under `collectMetrics`: `signal.*`, `noAdvance.rescan`,
    and `doubleScan.*` are gated; `marker.local` condensed to one line with
    id+ts.
  - Marker advancement happens only from ordered slices returned by
    catch-up/live scans, never directly from the client stream.
### Outbox resiliency (2025-11)

- Watchdog (every 10s) enqueues a drain when `pending > 0`, logged-in, and the
  queue is idle. Log: `watchdog: pending+loggedIn idleQueue → enqueue`.
- DB nudge subscribes to outbox count changes and enqueues after a short
  debounce (50ms). Logs: `dbNudge count=<n> → enqueue` then `enqueueRequest() done`.
- Send timeout (default 20s) marks retry and logs `timedOut=true`; repeated
  failures produce breadcrumbs, and pass-cap continuation proactively schedules
  a follow-up drain so the queue advances past pathological items.
- ClientRunner guards callback errors so the queue cannot die silently.
- Logging DB writes are best-effort (exceptions captured, file breadcrumbs kept)
  so diagnostics never block outbox progress.

### Self-Healing Sync / Backfill (2025-12)

Sync messages can occasionally go missing due to network issues, corruption, or
timing problems. The self-healing sync mechanism detects these gaps and
automatically requests missing entries from peer devices.

**Problem:** When a sync message is lost, entries may never sync even after
catch-up runs. The user observes data missing on one device but present on
another.

**Solution:** A sequence log tracks `(hostId, counter, entryId)` tuples. When a
message arrives with counter N but the last seen counter for that host was N-2,
the system detects counter N-1 is missing. Periodically, missing entries are
requested via broadcast. Any device with the entry can respond.

**Components:**
- `SyncSequenceLog` table in `sync_db.dart` — stores sequence entries with
  status (received, missing, requested, backfilled, deleted)
- `HostActivity` table — tracks when each peer was last seen online
- `SyncSequenceLogService` — records received/sent entries, detects gaps,
  manages sequence status
- `BackfillRequestService` — periodically scans for missing entries and sends
  batched `SyncBackfillRequest` messages (up to 100 entries per message)
- `BackfillResponseHandler` — handles incoming requests (re-sends entries or
  responds with "deleted" if purged) and processes responses

**Gap Detection:**
- Examines ALL hosts in incoming vector clocks (not just the originator)
- For each host, compares the counter against the last seen counter
- Any counter jumps > 1 trigger gap entries marked as `missing`

**Smart Retry with Exponential Backoff:**
- Base interval: 5 minutes between backfill request cycles
- Backoff: 5min → 10min → 20min → 40min → 80min → 2hr (capped)
- Host activity filtering: only request entries from hosts that have been
  online since the last request for that entry
- Maximum 10 retry attempts before giving up

**Message Flow:**
1. Device A detects missing entry (host=X, counter=5)
2. Device A broadcasts `SyncBackfillRequest` with entries list
3. Device B receives request, looks up entry in its sequence log
4. If found: Device B re-sends the journal entity via normal sync
5. If deleted/purged: Device B sends `SyncBackfillResponse` with `deleted=true`
6. Device A receives the entry via normal sync and updates sequence log to `backfilled`
7. For deleted entries: Device A receives the response and marks entry as `deleted`

**Logging:** Key domains include `SYNC_SEQUENCE` (gap detection, status changes)
and `SYNC_BACKFILL` (request/response handling). Look for:
- `gapDetected hostId=... counter=... (last seen: ..., observed: ...)`
- `handleBackfillRequest: N entries from=...`
- `handleBackfillResponse hostId=... counter=... deleted=...`

**Configuration:** Tuning constants in `tuning.dart`:
- `backfillRequestInterval`: 5 minutes between processing cycles
- `backfillBatchSize`: 100 entries max per request message
- `backfillMaxRequestCount`: 10 retries before giving up
- `backfillBaseBackoff` / `backfillMaxBackoff`: exponential backoff bounds

### Documentation & Artefacts

- Architecture: `docs/architecture/sync_engine.md`
- Memory audit: `docs/architecture/sync_memory_audit.md`
- Provider wiring (this document) + `lib/providers/service_providers.dart`

## Setup Flow (Multi-Device)

1. **Device A** logs in, creates the encrypted sync room, and displays its user
   QR code.
2. **Device B** logs in with its own Matrix account, scans the QR (or enters
   Device A’s Matrix ID), and waits for the invite surfaced by `SyncRoomManager`.
3. Device A approves the invite. Both devices verify each other using the emoji
   SAS flow.
4. `SyncLifecycleCoordinator` starts the streaming pipeline once both devices are
   logged in and the room has been hydrated. Synchronisation continues
   automatically while both devices are idle.

### Data Flow

The stream-first consumer replaces the legacy multi-pass drain:

- Attach-time catch-up: backfills/paginates until the last processed event is
  present, then processes strictly after it (no rewind before the marker).
- Micro-batches: orders oldest→newest with in-batch de-duplication by event ID.
- Self-event suppression: consumes locally produced event IDs from `SentEventRegistry` so echoed payloads advance the marker without redundant database or attachment work; suppression counters and logs surface in the pipeline so Matrix Stats reflects the saved work.
- Attachment descriptors only; descriptors are recorded to speed up local resolution.
- Marker advancement: monotonic by server timestamp with eventId tie-breaker;
  remote updates are guarded to avoid downgrades.
- Rescans: schedules a tail rescan on activity without advancement, and after
  any advancement. Attachment-only rescans are throttled and only scheduled
  when at least one new file was written.

Key helpers:
- `matrix/pipeline/catch_up_strategy.dart`: no-rewind catch-up via SDK seam and
  snapshot-limit escalation fallback.
- `matrix/pipeline/attachment_index.dart`: in-memory relativePath→event map used by
  the apply phase.
- `matrix/sync_event_processor.dart` smart loader: vector-clock aware JSON
  fetching that uses `AttachmentIndex` to fetch newer JSON for same-path
  updates before applying.
- `matrix/read_marker_service.dart`: remote monotonic guard comparing candidate
  vs `fullyRead` using the timeline when available.

## Diagnostics & Logging

- Use `matrixServiceProvider.read().getDiagnosticInfo()` in debug builds to
  inspect saved room IDs, active room state, lifecycle activity, joined rooms,
  and login status. Note: typed metrics are not included in this payload; use
  `MatrixService.getSyncMetrics()` or the Matrix Stats UI instead.
- Key log domains: `MATRIX_SERVICE`, `MATRIX_SYNC`, `SYNC_ENGINE`,
  `SYNC_ROOM_MANAGER`, `SYNC_EVENT_PROCESSOR`, `SYNC_READ_MARKER`, and `OUTBOX`.
  - Coalescing signals to look for: `signal.liveScan.coalesce debounceMs=…`,
    `trailing.liveScan.scheduled`, `catchup.start`, `catchup.done events=…`.
- Typical messages include invite acceptance/filters, hydration retries, send
  attempts, and timeline processing outcomes.

## Testing

- **Integration:** `integration_test/matrix_service_test.dart` exercises the
  full flow with the fake gateway (room creation, invites, verification, message
  exchange). Run with `dart-mcp.run_tests` targeting the file or via the project
  Make target.
- **Backfill Integration:** `integration_test/backfill_integration_test.dart`
  tests the self-healing backfill mechanism with real Matrix transport. After
  normal sync completes, gaps are artificially injected into the sequence log
  and backfill is triggered to verify end-to-end recovery. Run with
  `./integration_test/run_backfill_tests.sh` (requires Docker with Dendrite and
  Toxiproxy).
- **Unit/Widget:** Coverage includes the client runner queue, activity gating,
  timeline error recovery, verification modals (provider overrides),
  dependency-injection helpers, and the modern sync pipeline:
  - `test/features/sync/matrix/pipeline/matrix_stream_consumer_test.dart` covers SDK pagination seams,
    streaming/flush batching, metrics accuracy, and retry/circuit-breaker logic.
  - `test/features/sync/matrix/pipeline/*` helper suites validate catch-up, descriptor hydration, and
    attachment ingestion.
  - Lifecycle tests exercise activation, deactivation, and login/logout races with the pipeline.
  - `matrix_service_pipeline_test.dart` covers metrics exposure, retry/rescan
    delegation, diagnostics text, and resource disposal.
  - `test/features/sync/sequence/sync_sequence_log_service_test.dart` covers gap detection,
    host activity tracking, and sequence status management.
  - `test/features/sync/backfill/backfill_request_service_test.dart` covers timer-based
    processing, batching, exponential backoff, and lifecycle management.
  - `test/features/sync/backfill/backfill_response_handler_test.dart` covers request
    handling (re-send vs deleted response) and response processing.
- Always run `dart-mcp.analyze_files` before committing. The custom lint will
  block any reintroduction of `getIt`.

## Troubleshooting

- **One-way sync:** Compare diagnostics across devices (saved room vs active
  room). If they diverge, leave the room via `SyncRoomManager`, clear the stored
  ID, and repeat the invite flow.
- **Stalled sends:** Inspect the Outbox Monitor, verify that all devices are
  trusted/verified, and look for `Unverified devices found` messages in
  `MATRIX_SERVICE`.
- **Verification loops:** Ensure both devices accepted the emoji SAS prompt and
  the verification modal tests still pass (`test/widgets/sync/matrix/verification_modal_test.dart`).
- **Memory concerns:** Re-run the procedure described in
  `docs/architecture/sync_memory_audit.md` and compare against baseline numbers.
  The drain now disposes unused snapshot timelines during escalation to avoid
  leaks; if you see RSS growth, inspect timeline creation/disposal logs.
- **Missing entries not syncing:** Check `SYNC_SEQUENCE` logs for `gapDetected`
  events. If gaps are detected but not backfilled, verify peer devices are online
  and check `SYNC_BACKFILL` logs for request/response activity. The sequence log
  table can be queried to see missing entries and their request counts.

## Current Status

- Provider overrides and custom lint rules enforce the dependency model.
- When extending the sync feature, update both this README and the architecture
  documents so the narrative stays aligned with the implementation.

## UI & Navigation (2025-10)

- Sync now has a top-level Settings entry: `/settings/sync`.
  - The tile is only visible when the Matrix sync flag is enabled.
- Matrix Sync Settings is surfaced as a card on `/settings/sync` that launches
  the existing modal flow (no intermediate page).
- Matrix Sync Maintenance is a dedicated page under
  `/settings/sync/matrix/maintenance` for deleting the Sync database,
  replaying sync definitions, and forcing a re-sync window.
  - Supported definition sync steps: Tags, Measurables, Labels, Categories,
    Dashboards, Habits, and AI Settings. Each step reports per-step progress
    and totals; you can select any subset to sync.
- Outbox Monitor lives under `/settings/sync/outbox` and no longer exposes
  its own on/off toggle. The global Matrix sync flag governs enablement.
- Outbox Monitor adopts the shared `SyncListScaffold` with modern cards,
  segmented filters, payload metadata, and confirmation-backed retry actions.
- Matrix Stats is a full page under `/settings/sync/stats`, rendered in a
  styled card with a large, subtle loading indicator.
- Advanced Settings no longer contains Matrix/Outbox/Conflicts tiles; those
  have moved under Sync (Conflicts is still routed under advanced paths but
  linked from the Sync page).
- Conflicts list pages now use the shared scaffold with modern cards,
  entity badges, and inline counts for resolved/unresolved filters.
- Beamer route matching for the Sync section uses exact path matching to avoid
  brittle substring checks.

## Sync – Observability

- Metrics (typed + diagnostics)
  - Consumer surfaces counters via `metricsSnapshot()` including:
    - processed, skipped, failures, flushes, catchupBatches,
      skippedByRetryLimit, retriesScheduled, circuitOpens
    - processed.<type>, droppedByType.<type>
    - dbApplied, dbIgnoredByVectorClock, conflictsCreated
    - heartbeatScans, markerMisses
  - `MatrixService.getSyncMetrics()` maps these into a typed `SyncMetrics` model
    for UI display. The Matrix Stats page renders them and supports:
    - Refresh
    - Force Rescan (triggers live rescan + focused catch-up)
    - Copy Diagnostics (copies a readable metrics snapshot)
  - `getDiagnosticInfo()` intentionally omits metrics; prefer the typed API
    or diagnostics text for tooling/UI.
- Catch-up and Pagination
  - On attach, the pipeline attempts SDK pagination/backfill first (best-effort across
    SDK versions); if unavailable, it falls back to escalating snapshot limits.
  - Startup lookback: include a bounded pre-context since the last processed
    timestamp and up to a fixed number of events before the stored marker to
    provide context for attachment descriptors (no rewind of payloads).
  - Initial catch-up is retried with exponential backoff and gives up after
    roughly 15 minutes; logs will indicate `catchup.timeout`.
- Reliability safeguards
  - Streaming micro-batches are ordered oldest→newest. Retries apply exponential backoff with TTL and a size cap; a circuit breaker opens after sustained failures to prevent thrash.
  - Read-marker advancement is sync-payload only (or valid fallback-decoded JSON)
    to avoid silently skipping payloads when non-sync events arrive late.
  - A heartbeat rescan (every 5s) runs; if the last marker isn’t in the live
    window, a focused catch-up recovers gaps.
  - Service nudges: shortly after startup and whenever connectivity resumes,
    `MatrixService` triggers a `forceRescan(includeCatchUp=true)` to close any
    gaps introduced while offline or before room readiness.

### Reliability tracker

For ongoing issues, hypotheses, and the current mitigation plan, see the
reliability documents under `docs/progress/`. These outline current challenges,
landed fixes, and how to verify behaviour using Matrix Stats and logs.

## Implementation Notes & Consistency

- Ordering tie-breakers
  - `TimelineEventOrdering.compare` uses timestamp ordering; on equal timestamps,
    events are ordered lexicographically by event ID. `isNewer` applies the same
    rule to ensure monotonic advancement.
- Sent metrics
  - `MatrixService.sendMatrixMsg` maps each `SyncMessage` variant to a typed bucket
    (`journalEntity`, `entityDefinition`, `tagEntity`, `entryLink`, `aiConfig`,
    `aiConfigDelete`) and debounces emissions; unit tests cover each variant along
    with timer cancellation on `dispose`.
- Vector‑clock aware JSON
  - `SmartJournalEntityLoader` reads local JSON first; if a vector clock is
    provided and the local is older, it uses `AttachmentIndex` to fetch the
    newer JSON, writes it atomically, then applies it.
- File operations
  - JSON writes are atomic: write to a `*.tmp` file then rename to the final
    path. A best-effort fallback moves an existing target aside as `*.bak` to
    make the rename succeed; temporary/backup files are cleaned up when possible.
  - Attachment writes use the same atomic pattern. Existing non-empty files are
    not re-downloaded.
- Read markers
  - `SyncReadMarkerService` gates updates via `client.isLogged()` and prefers
    room-level `setReadMarker`; falls back to timeline-level when available.
  - Non-server/local event IDs (e.g., `lotti-…`) are persisted locally but skipped for
    remote updates; matching M_UNKNOWN responses are logged once and suppressed to
    avoid noisy error streams.
  - Remote monotonic guard: only advance if the candidate is strictly newer
    than the current `fullyRead` by server timestamp + eventId tie-breaker.


## References

- [Matrix Protocol](https://matrix.org/)
- [matrix-dart-sdk](https://pub.dev/packages/matrix)
- [End-to-End Encryption implementation guide](https://matrix.org/docs/guides/end-to-end-encryption-implementation-guide)
