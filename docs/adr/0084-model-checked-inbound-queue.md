# ADR 0084: Model-Checked Inbound Queue

- Status: Accepted
- Date: 2026-09-25

## Context

The inbound Matrix pipeline had no model. Timeline events reach
`inbound_event_queue` live (`QueuePipelineCoordinator._handleLiveEvent`) and
through catch-up walks (`BridgeCoordinator`, `QueueGapRecovery`); the worker
(`InboundWorker`) leases, applies, retries and abandons rows; and the per-room
`queue_markers` row decides where the next catch-up starts. A forward walk
from the applied anchor (`last_applied_event_id`) is the normal path; when the
durable resume floor (`resume_floor_ts`) sits at or behind the applied
timestamp, the walk goes backward from the tip down to the floor instead.
[ADR 0065](./0065-model-checked-sync-sequence-reservations.md)'s
`SyncSequence` models the layer above — counters and peer backfill — and not
how timeline events are consumed.

We wrote the pipeline down in TLA+, `specs/tla/InboundQueue.tla`, modelled
the code as it was, and model-checked it with TLC. The property that matters
is `NoSilentLoss`: every event the homeserver holds is captured (a queue row
in any status) or fetched by the catch-up that the durable marker would run
after a crash. These are the holes TLC confirmed, each as a concrete trace.

1. **A walk let the anchor pass the part it had not fetched yet.** A
   backward walk pages the tip first; its newest event applies, becomes the
   anchor, and if the walk stops early — an error, the five-minute budget,
   back-pressure, a crash — the retry and the startup walk after a crash both
   walk forward from that anchor and never fetch the older pages. A forward
   walk that stops on its budget (it is designed to "resume from the new
   anchor") loses the same way as soon as a newer live event applies past
   its cursor. Twelve steps (thirteen through a coalesced "Catch up now").
2. **A limited sync during a walk was caught up from a later marker.** The
   rerun it requested read the marker only when it started, by which time the
   worker had applied the post-gap slice and moved the anchor past the gap.
   Ten steps.
3. **The startup walk read the marker after live events could apply.**
   `startImpl` subscribes to the live stream and starts the worker before the
   startup bridge reads the marker, so a live event applied first puts the
   events that arrived while the app was down behind the anchor (seven
   steps). On a fresh device, the first live ciphertext set a floor that
   bounded the startup walk, and history older than it was never fetched
   (four steps).
4. **A live insert that threw was dropped.** `_safeEnqueue` logged it; the
   live stream never delivers an event twice, so once the next event applied,
   the dropped one was behind the anchor for good. Ten steps.
5. **A throw in the worker loop ended it.** Nothing restarts the worker while
   the coordinator runs, so after one transient database error every queued
   row waited for the next restart (`QueuedEventuallySettled`).
6. **Resurrection could re-arm an applied row.** `_resurrectWhere` selects
   abandoned rows, then updates them by id. A concurrent pass (attachment
   landed, journal update, "Retry all") could re-arm a selected row and the
   worker apply it in between, and the UPDATE flipped the applied row back to
   `enqueued` (`AppliedIsFinal`, eleven steps). Guarding only on the status
   was not enough either: a row the worker abandoned again in between was
   resurrected past its hard cap (`CapHolds`, twelve steps), or by a
   reason-scoped pass after its reason changed.

Losses 1–4 are silent at the queue level. For sequenced payloads the
sequence-log backfill of ADR 0065 eventually re-requests the missing counter
from a peer, so they cost a round trip to another device rather than data,
as long as that device still has it.

## Decision

The range above the marker is claimed before anything newer can apply there.
A claim lowers the resume floor to one millisecond above `last_applied_ts`
(`InboundQueue.claimAboveMarker`). One above, so the claim alone keeps
`anchorIsSafe` true and the forward walk stays the normal path; once a newer
event applies past it, the next walk goes backward to the claim. A completed
walk clears it through the existing compare-and-set; an incomplete one leaves
it for the next pass.

- **Every walk claims** at its start in the per-room walk lane, as a
  walk-local observation that does not invalidate its own completion
  (`_serializeResumeFloorWalk`). This covers bridge passes, "Catch up now",
  gap recovery and full-history collection alike.
- **A limited sync claims at once** (`BridgeCoordinator`'s `claimGap`), as an
  observation that does invalidate an in-flight walk's completion, before it
  requests the pass.
- **`startImpl` claims** before it subscribes to the live stream and starts
  the worker.
- **A forward walk checkpoints** after every page
  (`InboundQueue.checkpointResumeWalk`): the floor moves up to one above the
  page's newest event, or to the oldest ciphertext the walk still holds. A
  retry after a capped or failed forward walk then resumes forward from the
  anchor its own rows reached, and walks backward only over the remainder when
  something newer applied past it. TLC shows the checkpoint needs no
  compare-and-set.
- **The backward walk's bound** is the lower of the floor and
  `last_applied_ts` (`BridgeMarker.backwardWalkBound`), so a claim never
  narrows a walk past the applied millisecond.
- **A live insert that throws** lowers the floor to the event, as ciphertext
  does, and requests a bridge pass.
- **The worker loop outlives a throw**: it logs, waits one idle tick (or for
  `stop()`), and carries on.
- **Resurrection's UPDATE repeats every eligibility predicate of its
  SELECT**: the status, the hard cap and the path or reason filter.
- **A claim whose marker read throws is retained** in the queue, like a
  failed floor write, and resolved against the marker as it then is before
  any queue insert or floor read. Dropping it let a live event apply past the
  range (`NoSilentLoss`, five steps).

## Consequences

- Every checked-in configuration of `InboundQueue` passes: safety over up to
  15 million states with a crash or stop and one injected fault, a
  ciphertext configuration with failing floor writes, two crashes over four
  events, and liveness under fairness. With each switch turned back to the
  old behaviour, TLC reproduces the traces above.
- A catch-up after an interrupted walk, or after a newer event applied past
  a claim, walks backward from the tip to the claim instead of forward from
  the anchor. It fetches the same events, newest first, within the backward
  walk's five-minute budget; the checkpoint keeps this to the part the walk
  had not reached.
- A limited sync, start and every walk now write the floor once more; the
  forward walk writes it once per page.
- `advanceIfNewer`'s clamp is not what prevents loss: TLC passes without it,
  since a row it holds the marker behind is already captured. It stays, as
  it keeps `last_applied_ts` meaning "applied".

Residuals, recorded in `specs/tla/README.md`:

- **A limited sync's slice can apply before the bridge sees the sync.** The
  Matrix SDK emits the slice on `onTimelineEvent` before `onSync`, with
  database writes in between; if the worker applies a post-gap event first,
  the claim comes too late (`SliceRace`, ten steps; excluded from the
  checked-in configurations). The window is narrow, and backfill repairs
  sequenced payloads. Closing it is a decision between taking live events
  from `Client.onSync`'s room updates, so the claim precedes the enqueue;
  moving the anchor only by walk-contiguous rows, which needs a durable
  captured-frontier column and a migration; or accepting the window.
- **Equal milliseconds**: a claim or a checkpoint one millisecond above an
  event can leave a same-millisecond event later in timeline order outside a
  backward walk bounded there. The model has distinct timestamps.
- **The bridge still gives up after three incomplete passes in a row**; the
  durable floor waits for the next trigger.

## Related

- `specs/tla/InboundQueue.tla` and its four configurations
- `specs/tla/README.md`, section `InboundQueue`
- `test/features/sync/queue/inbound_event_queue_model_conformance.dart`
- [ADR 0065](./0065-model-checked-sync-sequence-reservations.md), the sequence
  log and backfill that repair a lost sequenced payload
- `knowledge/features/sync/receive-path.md`
