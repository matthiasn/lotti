# Sync Reliability Convergence

**Date**: 2026-03-13
**Status**: Proposed

## Summary

The current sync stack on `main` is substantially more stable after the recent
merge, but it still does not guarantee passive convergence after offline
periods.

The recurring `100 missing entries` symptom is not caused by an inbox or
timeline fetch size of `100`.

The code-backed failure chain is:

1. catch-up anchors on a stored Matrix `eventId`, not on a contiguous sync
   watermark
2. when that `eventId` is no longer reachable in the local SDK timeline plus
   bounded pagination, catch-up falls back to the newest `1000` events
3. sequence-gap detection then observes a much newer counter, but materializes
   only the newest `100` missing counters
4. the high counter is still recorded as received, so the older part of the gap
   disappears from automatic backfill discovery
5. the backfill worker later reports `no missing entries` even though the older
   counters were never represented in the sequence log

This is why the UI/logs repeatedly show `100` while the true offline gap can be
much larger.

## Evidence From Friday's Logs

### Mobile startup immediately enters marker-missing fallback

From `logs/sync-2026-03-13_mobile.log`:

- `01:15:19` startup marker is
  `$W-m7tN3w2M2SESmNuGXB4NEG_rmTAqJ6w7sx5BzFiJQ`
- `01:15:23` catch-up logs:
  - `catchup.markerMissing ... snapshot=1763 returned=1000 fallbackLimit=1000`
  - `catchup.slice total=1000 payloads=676 attachments=324`

This proves the device did start catch-up on startup. The failure is that the
stored marker could not be found in the reachable history window, so catch-up
processed a bounded tail instead of the exact backlog after the stored marker.

### The visible `100` comes from sequence-gap truncation

Four seconds later, the same mobile log shows:

- `largeGapDetected ... gapSize=930 ... limiting to 100 entries`
- first generated missing counter: `243413`
- observed counter: `243513`
- previous contiguous observation in DB: `242582`

That is a 930-counter jump. The system only materialized counters
`243413..243512`, i.e. the newest `100` rows.

### Older missing counters become invisible to automatic backfill

Later in the same mobile log:

- backfill resolves/request-resolves many of those `243413..243512` counters
- then the periodic worker repeatedly logs
  `processBackfillRequests: no missing entries (useLimits=true)`

That means the older counters `242583..243412` are no longer represented as
missing even though they were part of the same jump.

## Code-Backed Findings

### 1. Catch-up is bounded by event-id reachability, not by true convergence

`lib/features/sync/matrix/pipeline/catch_up_strategy.dart`

- catch-up tries to find `lastEventId`
- SDK pagination is bounded
- if the marker is still absent, it returns only the last
  `missingMarkerFallbackLimit` events
- the default fallback limit is `1000`

This is intentional containment, but it is not a convergence-safe recovery
strategy.

### 2. The SDK pagination seam ignores the requested page size

`lib/features/sync/matrix/sdk_pagination_compat.dart`

- `backfillUntilContains()` accepts `pageSize`
- the current Matrix SDK path cannot apply it
- recovery is effectively bounded only by `maxPages`
- the current caller uses `maxPages: 20`

So a valid stored server event can still become unreachable for catch-up even
without any marker corruption.

### 3. The recurring `100` is `SyncTuning.maxGapSize`

`lib/features/sync/tuning.dart`

- `maxGapSize = 100`

`lib/features/sync/sequence/sync_sequence_log_service.dart`

- on a large observed jump, only the most recent `100` missing counters are
  inserted into `sync_sequence_log`
- older counters in the same gap are not represented at all

This is the direct source of the user-visible `100` boundary.

### 4. Host progress currently advances by max counter, not by contiguous watermark

`lib/database/sync_db.dart`

- `getLastCounterForHost()` returns `MAX(counter)`

That is the wrong progress primitive for guaranteed convergence.

If the DB contains:

- old contiguous rows up to `242582`
- only the newest `100` missing rows from a much larger gap
- a received row at `243513`

then `MAX(counter)` becomes `243513`, even though counters
`242583..243412` were never materialized.

After that, future gap detection treats the host as already advanced to the far
side of the gap.

### 5. Automatic backfill can only request rows that already exist in the sequence log

`lib/features/sync/backfill/backfill_request_service.dart`

- automatic backfill loads missing/requested rows from `sync_sequence_log`
- if a counter was never inserted as `missing`, it is not requestable

So once a large gap has been truncated to `100` rows, the rest of the gap is
outside the automatic recovery path.

### 6. Startup now does initialize the agent path, but not with immediate guaranteed drain

The latest merged code does start the sync/backfill machinery on app startup,
and Friday's mobile log proves it begins catch-up immediately after startup.

However, the periodic backfill request worker still sends on its timer cadence.
That is not the main bug here, but it means newly detected missing rows are not
requested "immediately" in the strict sense unless another trigger is added.

## Why The System Still "Eventually Converges"

It can appear to converge because the newest `100` missing rows are real rows in
the sequence log and therefore do participate in backfill. Many of those rows
do get resolved in Friday's mobile log.

But this is only partial convergence:

- the newest tail of the gap is recoverable
- the older unmaterialized part of the same gap is not represented
- once the tail is resolved, the worker reports `no missing entries`

That is not an email-like reliability model.

## Root Cause Statement

The main bug is not "there is a hardcoded batch size of 100 in Matrix sync."

The actual bug is that the receive-side recovery model mixes two incompatible
ideas:

1. catch-up recovery is anchored on a single Matrix event id
2. convergence tracking is anchored on per-host monotonic counters

When event-id recovery fails, the system falls back to a recent room tail and
then incorrectly lets sparse high counters advance host progress past older
unmaterialized gaps.

That breaks the invariant required for 100% convergence:

> the system must never consider a host progressed beyond the first unresolved
> counter in that host's sequence.

## Required Reliability Invariants

We need the implementation to preserve all of the following:

1. A missing catch-up marker must never be treated as a successful catch-up.
2. A host's progress must be defined by its highest contiguous resolved counter,
   not by the maximum counter seen in any row.
3. Large gaps must remain fully representable until they are resolved, even if
   they are stored as compressed ranges instead of one row per counter.
4. Automatic backfill must operate on all unresolved ranges/counters, not only
   on whichever subset happened to be materialized first.
5. The app must not report `no missing entries` while unresolved earlier
   counters still exist for that host.

## Proposed Implementation Plan

### Phase 1: Stop marker-missing fallback from pretending to converge

Files:

- `lib/features/sync/matrix/pipeline/catch_up_strategy.dart`
- `lib/features/sync/matrix/pipeline/matrix_stream_catch_up.dart`
- `lib/features/sync/matrix/sdk_pagination_compat.dart`

Changes:

1. Make marker-missing a distinct recovery outcome, not a normal catch-up slice.
2. Return structured metadata from catch-up:
   - marker found: yes/no
   - snapshot size
   - pagination attempts/pages
   - earliest/latest visible event ids and timestamps
   - fallback/exhaustion reason
3. If the marker is not found after bounded pagination:
   - do **not** feed the fallback tail into normal ordered processing as if it
     were the exact backlog after the marker
   - instead trigger a dedicated recovery path and mark catch-up incomplete
4. Log the incomplete recovery explicitly so this state is observable in UI and
   logs.

Acceptance criteria:

- a missing marker no longer causes normal tail processing that can create false
  large-gap observations
- catch-up can report "incomplete recovery" without silently advancing state

### Phase 2: Replace `MAX(counter)` progress with contiguous host watermarks

Files:

- `lib/database/sync_db.dart`
- `lib/features/sync/sequence/sync_sequence_log_service.dart`
- possibly a new helper/model for contiguous host progress

Changes:

1. Introduce a contiguous watermark per host:
   - "highest counter such that all counters `1..N` are resolved or explicitly
     terminal (`deleted`/`unresolvable` if that is truly terminal)"
2. Stop using `MAX(counter)` as the basis for gap detection.
3. During receive processing:
   - high observed counters may be recorded
   - but host progress must not jump past earlier unresolved counters
4. Backfill and UI stats should read unresolved state from the contiguous model,
   not from sparse maxima.

Acceptance criteria:

- observing counter `243513` while `242583..243412` are unresolved does **not**
  move host progress to `243513`
- the unresolved older interval remains visible to automatic recovery

### Phase 3: Represent full gaps instead of truncating them to the newest 100 rows

Files:

- `lib/features/sync/tuning.dart`
- `lib/features/sync/sequence/sync_sequence_log_service.dart`
- `lib/database/sync_db.dart`

Changes:

1. Remove the current semantic meaning of `maxGapSize` as "older missing
   counters cease to exist."
2. Replace it with one of:
   - compressed gap ranges in DB, or
   - chunked missing rows that preserve the full interval while paging work
3. If row explosion is a concern, page the work representation, not the logical
   existence of the gap.

Preferred direction:

- store unresolved ranges per host, e.g. `[242583, 243512]`
- expand into request batches when sending backfill requests

Acceptance criteria:

- a 930-counter gap remains a 930-counter unresolved interval until resolved
- UI may still page/render a subset, but recovery state remains complete

### Phase 4: Make backfill operate on unresolved ranges and/or contiguous gaps

Files:

- `lib/features/sync/backfill/backfill_request_service.dart`
- `lib/features/sync/sequence/sync_sequence_log_service.dart`
- `lib/database/sync_db.dart`

Changes:

1. Drive automatic backfill from unresolved intervals/contiguous watermarks,
   not only from pre-existing `missing` rows.
2. Page outgoing requests into bounded batches for network safety.
3. Add an immediate nudge when new unresolved gaps are detected at startup or
   on reconnect so mobile begins requesting without waiting for the full timer
   interval.

Acceptance criteria:

- new missing work is requestable immediately after detection
- batch safety remains bounded, but convergence is no longer timer-limited or
  representation-limited

### Phase 5: Add startup repair/rebuild paths for already-corrupted sparse state

Files:

- `lib/features/sync/state/sequence_log_populate_controller.dart`
- `lib/features/sync/sequence/sync_sequence_log_service.dart`
- UI/maintenance entry points as needed

Changes:

1. Add a repair mode that recomputes contiguous host progress from local
   sequence rows and payloads.
2. Add a deeper rebuild option that repopulates the sequence log from journal
   entries, entry links, agent entities, and agent links.
3. Consider running a lightweight integrity check on startup:
   - if sparse high counters exist beyond the contiguous watermark, flag repair

Acceptance criteria:

- old hidden gaps caused by the current bug can be surfaced and recovered

## Test Plan

### Catch-up tests

Add/extend tests under:

- `test/features/sync/matrix/pipeline/catch_up_strategy_test.dart`
- `test/features/sync/matrix/pipeline/matrix_stream_consumer_test.dart`
- `test/features/sync/matrix/pipeline/matrix_stream_consumer_stream_test.dart`

Required scenarios:

1. stored marker is a valid server id but lies beyond the bounded SDK history
   window
   - result must be `markerMissing/incomplete`
   - no normal tail processing
2. marker found
   - catch-up still returns the normal strictly-after slice
3. repeated startup/connectivity triggers
   - no duplicate incomplete-catch-up side effects

### Sequence-progress tests

Add/extend tests under:

- `test/features/sync/sequence/sync_sequence_log_service_test.dart`
- `test/database/sync_db_test.dart`

Required scenarios:

1. large observed jump does not advance contiguous watermark past unresolved
   counters
2. a 930-counter gap remains fully represented logically
3. resolving the newest `100` counters does not hide the earlier `830`
4. `no missing entries` is impossible while earlier unresolved counters remain

### Backfill tests

Add/extend tests under:

- `test/features/sync/backfill/backfill_request_service_test.dart`
- `test/features/sync/backfill/backfill_integration_test.dart`

Required scenarios:

1. newly detected startup gap triggers immediate request scheduling
2. unresolved ranges are paged into bounded outgoing batches
3. periodic worker continues from previous batches until full convergence

## Rollout Order

1. Add tests that reproduce the current hidden-gap failure.
2. Land Phase 1 so marker-missing no longer masquerades as successful catch-up.
3. Land Phase 2/3 together so progress and gap representation share the same
   contiguous model.
4. Land Phase 4 to restore automatic convergence under bounded batching.
5. Add repair tooling for already-affected local databases.

## Short-Term Diagnostic Follow-Up

Before or alongside implementation, add one more compact log line whenever
catch-up cannot find the marker:

- stored marker id and timestamp
- earliest visible event id and timestamp
- latest visible event id and timestamp
- number of pagination attempts
- whether pagination exhausted because history ended or because the page cap was
  hit

That will let us distinguish:

- genuinely old/off-screen markers
- SDK history visibility limits
- corrupted local markers

without guessing from secondary symptoms.

## Acceptance Criteria For This Task

We can call this solved only when all of the following are true:

1. A device returning from offline reads from a provably correct contiguous
   recovery point.
2. No gap is hidden merely because it is larger than a UI/network batching
   threshold.
3. Automatic backfill continues until the full unresolved interval is gone.
4. The system never reports `0 missing` while older counters in the same host
   interval remain unresolved.
5. The logs no longer show the misleading pattern:
   - `markerMissing`
   - `largeGapDetected ... limiting to 100 entries`
   - later `no missing entries`

