# ADR 0090: Hold the Anchor, Not the Events

- Status: Accepted
- Date: 2026-09-26

## Context

A Matrix `/sync` response whose room timeline is `limited` omits the events
between the room's applied marker and the slice it delivers. The SDK emits the
slice's events on `onTimelineEvent` first and reports `limited` only in the
response's `onSync`. The live path queues and applies the slice meanwhile, and
each commit moves `queue_markers.last_applied_ts`
(`QueueMarkerAdvancer.advanceIfNewer`). When the bridge then claims the range
above the marker for catch-up, the marker is already past the gap and the
omitted events are never fetched. [ADR 0084](./0084-model-checked-inbound-queue.md)
left this as the `SliceRace` residual of `specs/tla/InboundQueue.tla`.

#4502 closed the window by holding every live event behind a barrier opened on
`onSyncStatus(processing)` and released on `onSync`. It was reverted (#4515):
the Matrix integration suite failed in 23 of 27 runs of commits containing it
and in 0 of 29 without, each time with a bundle's attachment descriptor never
recorded, so the bundle's entries waited forever. Holding descriptors held up
what the rest of the pipeline needs to make progress, and the SDK's synthetic
`handleSync` passes — a late Megolm key re-decrypting a room's last event
(`KeyManager`), history, send and redaction fake syncs — emit `processing` and
`onSync` inside a real response, so the barrier's signals did not belong to the
response it guarded.

## Decision

Hold the marker, never the events.

- **Events are admitted and applied at once**, as before #4502, descriptors
  included.
- **A commit moves the marker only while every live arrival is sealed.**
  `LiveAnchorHold` counts each arrival synchronously in the `onTimelineEvent`
  listener, before `asyncMap`; `advanceIfNewer` settles the row and leaves the
  marker while an arrival is unsealed.
- **A seal belongs to the real sync loop.** `QueueLiveSeal` seals on
  `SyncStatus.cleaningUp`, which only `Client._sync` emits, once per response,
  after its timeline events and its `onSync`; `SyncStatus.error` seals
  conservatively. No synthetic pass emits either.
- **A limited response is claimed before it is sealed.** When any `onSync`
  since the last seal was limited for the room (or after an error), the seal
  claims the range above the still-held marker, then seals its snapshot. A
  failed claim leaves the arrivals unsealed for the next seal. Seals run one at
  a time.
- **The marker catches up from the database.** After a seal, with nothing newer
  arrived, `InboundQueue.catchUpMarker` advances over the newest settled row,
  clamped below the oldest active row as a commit would be — never from a
  remembered commit, which might have rolled back.
- **A retained claim holds the marker too.** A claim or floor kept in memory
  after a failed write resolves against the marker as it is when finally
  written, so no commit may move the marker first.

The hold is in memory. A stop or crash loses it; rows committed under it never
moved the marker, and the claim `startImpl` makes covers what they had not
sealed.

## Verification

`InboundQueue.tla` gains `HoldAnchor`, `HoldWhileRetained` and
`IgnoreSyntheticSync`, and the property `NoSilentLossAfterRestart`: every event
is captured or fetched by the catch-up that follows the next start's claim. The
original `NoSilentLoss` asks the durable floor alone to cover the gap, which the
design cannot provide while a limited response's claim waits for its seal —
though no marker has moved. Today's code before this change breaks the weaker
property too, in 11 states. With `SliceRace` on, the design passes every base
configuration; `IgnoreSyntheticSync = FALSE` fails in 12 states and
`HoldWhileRetained = FALSE` in 15. TLC found the second while the design was
being checked: a row queued behind a gap outlived a stop, the startup claim's
marker read threw and was retained, the row settled in the new process, and the
retained claim resolved above the gap.

## Consequences

- The marker lags the applied rows by up to one sync response, so a restart
  re-fetches a little more history; the rows are duplicates the queue ignores.
- A sync loop that never reaches `cleaningUp` or `error` never seals. Every
  iteration of `Client._sync` ends in one of them.
- A synthetic `onSync` reporting `limited` only causes an extra claim.
