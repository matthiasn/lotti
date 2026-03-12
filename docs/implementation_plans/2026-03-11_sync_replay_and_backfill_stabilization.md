# Sync Replay And Backfill Stabilization

**Date**: 2026-03-11
**Status**: Implemented

## Summary

The current sync failures do not justify a full rewrite yet.

The strongest code-backed problems are narrower:

1. catch-up can replay large old room slices when the last processed marker is
   not found
2. backfill can answer from an exact `(hostId, counter)` sequence row whose
   payload's current vector clock is already behind that counter
3. replayed duplicate journal events still mutate sequence state and amplify
   the damage

The plan is therefore a stabilization pass:

- fix the exact-backfill verification hole
- contain catch-up replay so missing markers do not trigger massive old-history
  reprocessing
- add focused tests for both behaviors
- leave the broader agent attachment/event binding redesign for a follow-up
  unless the new tests prove it is still needed immediately

## Goals

- Stop exact counter lookups from resending invalid payloads and then declaring
  the same counter unresolvable.
- Prevent missing-marker catch-up from replaying huge old room slices by
  default.
- Preserve the existing vector-clock and covered-clock model unless a test
  proves it is unsalvageable.
- Add narrow tests that pin the broken behaviors down.
- Keep analyzer clean and targeted tests green.

## Non-Goals

- No full rewrite of sync.
- No changes to vector-clock comparison semantics.
- No redesign of all sequence-log states in this pass.
- No speculative fix for the agent descriptor/path model without a dedicated
  repro.

## Code-Backed Problem Statements

### Problem 1: Exact Backfill Hits Are Not Verified Before Use

`BackfillResponseHandler._processBackfillEntry()` performs an exact
`getEntryByHostAndCounter()` lookup and treats any non-null `entryId` as an
answerable row. Only the covering-fallback path verifies whether the payload VC
actually covers the requested counter.

For agent entities, `_processAgentBackfillEntry()` currently:

1. loads the payload
2. re-enqueues the payload
3. only then checks whether the current payload VC contains the requested
   counter

This allows one handling pass to both resend the payload and emit
`unresolvable` for the same counter.

### Problem 2: Missing Catch-Up Marker Can Rewind To Full-Snapshot Replay

`CatchUpStrategy.collectEventsForCatchUp()` explicitly returns the entire
snapshot when `lastEventId` cannot be found.

The stream processor only remembers `5000` recent event IDs, so a replay batch
 above that size can reintroduce old events as if they were fresh work.

The combined 2026-03-11 sync log shows replay waves above `10000` events, which
fits this failure mode far better than live-scan tail fallback.

## Implementation Scope

### In scope now

- `lib/features/sync/backfill/backfill_response_handler.dart`
- `lib/features/sync/matrix/pipeline/catch_up_strategy.dart`
- `lib/features/sync/matrix/pipeline/matrix_stream_consumer.dart`
- targeted tests under `test/features/sync/...`
- sync docs, changelog, and Flatpak metainfo

### Explicit follow-up scope

- agent attachment/event causal binding redesign
- sequence-log schema redesign if still required after stabilization

## Proposed Changes

### 1. Verify exact backfill hits the same way covering hits are verified

When an exact `(hostId, counter)` row exists:

- load the current payload VC before resending anything
- if the VC covers the requested counter, continue normally
- if the VC is behind the requested counter:
  - do not treat the row as a valid exact answer
  - try a verified covering entry
  - if none exists, send `unresolvable` only for our own host

This aligns exact-hit behavior with the already safer covering-fallback path.

### 2. Make missing-marker catch-up bounded and explicit

When `lastEventId` is missing from the snapshot:

- do not silently return the full snapshot as normal catch-up output
- bound the replay window and make the fallback explicit in logs/metrics
- prefer a controlled resync strategy over feeding a huge historical slice into
  the normal ordered processor

Two acceptable implementation shapes:

- conservative: return an empty catch-up slice and let a separate resync path
  own recovery
- bounded replay: allow only a capped fallback slice that cannot overflow the
  processor dedupe

The key invariant is that "marker missing" must no longer mean
"process 10k-20k old events as fresh catch-up work".

### 3. Add focused regression tests

Required tests:

- exact backfill hit where payload VC is behind requested counter
- exact backfill hit where payload VC covers requested counter
- catch-up with marker found still returns normal strictly-after slice
- catch-up with marker missing no longer returns an unbounded full snapshot
- stream/catch-up behavior stays coherent with the chosen marker-missing policy

## Files Likely To Change

| File | Reason |
| --- | --- |
| `lib/features/sync/backfill/backfill_response_handler.dart` | verify exact hits before resend |
| `lib/features/sync/matrix/pipeline/catch_up_strategy.dart` | change missing-marker behavior |
| `lib/features/sync/matrix/pipeline/matrix_stream_consumer.dart` | adapt catch-up caller if policy changes |
| `test/features/sync/backfill/backfill_response_handler_test.dart` | add exact-hit regression coverage |
| `test/features/sync/matrix/pipeline/catch_up_strategy_test.dart` | add missing-marker regression coverage |
| `test/features/sync/matrix/pipeline/matrix_stream_consumer_test.dart` | verify consumer behavior if needed |
| `lib/features/sync/README.md` | keep feature docs aligned |
| `lib/features/sync/current_architecture.md` | keep investigation findings aligned |
| `CHANGELOG.md` | document released fix |
| `flatpak/com.matthiasn.lotti.metainfo.xml` | mirror changelog entry |

## Acceptance Criteria

- Exact backfill hits never resend a payload whose current VC is already behind
  the requested counter.
- Catch-up no longer replays massive old history when the marker is missing.
- Targeted tests cover the new exact-hit and missing-marker behavior.
- Analyzer reports zero warnings or infos for touched areas.
- Targeted tests pass.

## Risks

- If marker-missing fallback is made too strict, legitimate recovery after
  local marker loss could stall.
- If exact-hit verification is changed without preserving covering fallback,
  superseded counters could stop resolving.
- The agent descriptor/path issue may still remain after this stabilization
  pass and require a follow-up subsystem redesign.

## Execution Order

1. Add exact-hit regression tests and implement the backfill fix.
2. Add catch-up regression tests and implement the marker-missing containment.
3. Run formatter, analyzer, and targeted tests.
4. Update changelog, metainfo, and sync docs to match the actual behavior.
