# ADR 0062: Check-ins Hold Entries, and Changed Evidence Drives the Briefing

- Status: Accepted — data and agent layer implemented (entries, evidence
  signal, agent context, delete cascade); the check-in detail view, the
  composer saving without waiting for a transcript, photos and the logbook
  follow.
- Date: 2026-09-19
- Refines: ADR 0038 Decision 2, ADR 0040 Decision 4, ADR 0059 Decision 2

## Context

ADR 0038 Decision 2 made a check-in's narrative its own `entryText`. In use
that shape broke down:

- a dictated check-in could not be saved until its transcript arrived, so a
  failed transcript lost the check-in;
- a correction ("that name was misheard") had to be a second, separate
  check-in, which the briefing then narrated as an event;
- the recording itself was linked to the person, not the check-in, and
  photos had nowhere to go.

Separately, the refresh escalation of ADR 0059 Decision 2 keyed the
briefing's staleness to the newest check-in's *date* and allowed one refresh
per UTC day. A check-in logged after the briefing but dated before it —
yesterday's call, logged this morning — never made the briefing stale, and a
second check-in on the same day never produced a new one.

## Decision

1. **A check-in is a container.** Comments, recordings and photos are
   entries of their own, linked check-in → entry with a `BasicLink`, and
   inherit the check-in's category and privacy. A check-in's `entryText`
   remains readable as the text it was saved with; it is migrated **at read
   time**, never rewritten: every surface and the agent show it first, then
   the entries in the order they were added. No device on an older build
   loses anything.
2. **The agent's context includes the entries** (refining ADR 0040
   Decision 4): per check-in, up to eight entries — the comment's text, a
   recording's transcript, a photo's description — each bounded like the
   narrative, and a recording or photo without words says so rather than
   reading as silence. Entries are read unfiltered by the private-display
   preference, like check-ins, so devices agree.
3. **A check-in's `updatedAt` is when its evidence last changed.** Adding an
   entry saves the check-in again, and so does a transcript (or, later, a
   photo description) arriving after the check-in was saved. The save syncs,
   so every device sees the same signal.
4. **One refresh per evidence change** (refining ADR 0059 Decision 2): the
   refresh episode is keyed by the instant the evidence last changed, to the
   millisecond, instead of the newest check-in's UTC day. The key is taken
   from the stored date and time components, which every device reads alike;
   the deadline is the instant those components and the check-in's recorded
   UTC offset name, plus a 30-second settle, so a burst of additions is briefed
   once; while a changed check-in's recording still awaits its transcript,
   the deadline moves to the transcript timeout, so the agent never briefs on
   a check-in that says nothing yet.
5. **Deleting cascades to entries** (ADR 0037): deleting a check-in, or its
   person, tombstones the entries the check-ins alone hold; an entry that
   also belongs to something else still live is left alone.

## Consequences

- Cost is bounded by what the user does — at most one briefing per change —
  rather than by a daily ceiling.
- Every write path that changes what a check-in holds must touch the
  check-in; `RelationshipRepository.addCommentToCheckIn`,
  `attachEntryToCheckIn` and `touchCheckInsHolding` are those paths.
