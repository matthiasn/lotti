# ADR 0101: Equal Milliseconds at the Catch-Up Boundary

- Status: Accepted
- Date: 2026-09-27
- Amends: [ADR 0084](0084-model-checked-inbound-queue.md)

## Context

ADR 0084 recorded equal milliseconds as a residual. Its model gave every event
its own timestamp, but the catch-up boundary is a timestamp while a forward
walk's anchor is an event. The two meet in one millisecond, and several Matrix
events can share one. Event ids say nothing about their order in the timeline.

`specs/tla/InboundQueue.tla` now lets events share a millisecond (`SameMs`;
`InboundQueueSameMs` puts three of five events in one). With the code as it
was, TLC found three ways to lose an event that the homeserver holds
(`NoSilentLoss`). Each needs a limited sync and three events in the
millisecond:

1. **The anchor followed the larger event id.** `advanceIfNewer` broke an
   equal-timestamp tie by event id. Suppose A is the anchor at ms 2. A limited
   sync drops B at ms 2, the bridge claims 3, and C, also at ms 2, applies. If
   C's id sorts above A's, C becomes the anchor. The claim at 3 still reads as
   safe for the forward walk, which starts after C and never fetches B
   (16 steps).
2. **A checkpoint claimed its cursor's whole millisecond.** A forward walk
   checkpointed one millisecond above its newest event, even though the rest
   of that millisecond could still be ahead of it. Suppose a limited sync
   drops B and C at ms 2, and D, also at ms 2, applies first and becomes the
   anchor. The walk from A queues B, fails, and leaves a floor of 3. That
   floor makes D a safe anchor, and the retry walks forward past C
   (16 steps).
3. **The backward bound stopped short of the claimed millisecond.** A claim
   lowers the floor to one above the marker, at ms 2. Once E applies at ms 3,
   the backward walk's bound was `min(floor, last_applied_ts) = 3`. A page
   that crosses 3 can end partway through ms 2, so B and C, missing from that
   millisecond, can stay missing (17 steps).

## Decision

Three rules, each a switch in the model (`TRUE` in every checked-in
configuration):

- **`TieKeepsAnchor`: the marker moves only to a newer millisecond.** A commit
  in the marker's own millisecond leaves `last_applied_ts` and
  `last_applied_event_id` alone, so the anchor is the first event applied in
  its millisecond. Every event a claim at that millisecond was made for comes
  after that anchor in the timeline.
- **`CheckpointAtCursor`: a checkpoint is the cursor's millisecond.**
  `checkpointResumeWalk` sets the floor to the page's newest timestamp rather
  than one above it. Once the marker reaches that millisecond, the next walk
  goes backward.
- **`WalkBelowFloor`: the backward walk's bound is one millisecond below the
  floor.** `BridgeMarker.backwardWalkBound` is the lower of `floor − 1` and
  `last_applied_ts`, so a claim's millisecond is covered after the marker has
  moved on. For a ciphertext or checkpoint floor, the extra millisecond is
  fetched again, and the `event_id` UNIQUE constraint drops what the queue
  already holds.

A fourth rule brings the code in line with the model, which has no event
ids. **The forward walk never compares event ids.**
`collectForwardForBootstrapImpl` ordered a millisecond by id: it dropped an
event after the anchor in its millisecond whose id sorted before the anchor's,
and, across pages, a later event whose id sorted before the newest one already
emitted. It now keeps a frontier, made of the newest timestamp emitted (at
first the anchor's) and the ids emitted at it. An event is emitted when it is
newer, or when it shares that timestamp and is not among those ids. The
model's forward walk, "everything after the anchor in the timeline", is
therefore a subset of what the app fetches. The regressions are unit tests of
the strategy.

The marker treats a row as "no marker" only when it has neither a timestamp
nor an event id. Before, a zero timestamp alone counted, so a second event at
timestamp zero could still replace an anchor stored at zero.

The claim stays one millisecond above the marker. A claim at the marker's own
millisecond would make every claimed catch-up walk backward, because
`anchorIsSafe` needs the floor strictly above the marker, so it would give up
the forward walk that ADR 0084 kept as the normal path. The anchor rule makes
the claim's exclusive floor sound instead.

No schema change is needed.

## Consequences

- With the fixes, every `InboundQueue` configuration passes. With any one of
  the switches off, `InboundQueueSameMs` fails `NoSilentLoss` with the trace
  above. `MarkerMonotone` now also says that the anchor moves only to a newer
  millisecond.
- A forward walk from an anchor fetches the rest of that anchor's millisecond
  again, and a backward walk fetches one millisecond more than before. The
  queue drops both as duplicates.
- After an interrupted forward walk whose rows applied up to its cursor's
  millisecond, the retry walks backward to just below that millisecond instead of
  forward from the anchor. The retry still fetches only the part the walk had
  not reached.
- The model's backward walk stops at the first event below its bound. A real
  page that crosses the bound also carries some older events. The model is
  therefore conservative, and the fix does not rely on those extra events.
- `test/features/sync/queue/inbound_event_queue_model_conformance.dart` now
  runs over timestamps 1, 2, 2, 2, 3, with event ids that sort in timeline
  order. It fails with any one of the three fixes reverted.

## Related

- `specs/tla/InboundQueue.tla`, `specs/tla/InboundQueueSameMs.cfg`
- `specs/tla/README.md`, section `InboundQueue`
- `knowledge/features/sync/receive-path.md`
- [ADR 0084](0084-model-checked-inbound-queue.md)
