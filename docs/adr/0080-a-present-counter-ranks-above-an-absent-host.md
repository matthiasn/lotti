# ADR 0080: A Present Counter Ranks Above an Absent Host, and New Hosts Start at 1

- Status: Accepted
- Date: 2026-09-25

## Context

A vector clock maps each host that has written a version to that host's
counter. `VectorClockService` handed a new host counter 0 first, and
`VectorClock.compare` read a host absent from a clock as counter 0. The two
together made a host's first write invisible. A device set up or reinstalled
gets a new host id. Its first edit of an existing entry or agent row extends
the stored clock by `host: 0`, and that clock compared *equal* to the version
it extended. [ADR 0078](./0078-entry-link-versions-are-ordered.md) found this
while ordering entry links, fixed the link order locally and left the rest
open. With two simulated devices through the real code:

1. **The edit was refused on the device that made it.** The local journal
   write goes through `JournalDb.updateJournalEntity`, which applies only a
   version that dominates the stored one (`b_gt_a`). The first edit of each
   existing entry on a new device compared equal, was skipped as
   older-or-equal, and its counter was burned. The user's edit did not stick.
2. **Peers dropped it.** Every receive path that applies only a newer version
   kept the local row: `JournalDb.updateJournalEntity` and the stale-descriptor
   pre-check on the journal receive, `resolveAgentEntityVersions`,
   `AgentVcDominanceCheck` (which skipped the download) and the agent-link
   dominance check in `SyncEventProcessor`. An agent entity's first write from
   a new host applied locally but reached no other device.
3. **A concurrent edit was taken as newer.** A's own later edit `{A: 2}` read
   as dominating B's first edit `{A: 1, B: 0}`, so B's edit was dropped with
   no conflict. Two new hosts that each extended one version, `{A: 1, B: 0}`
   and `{A: 1, C: 0}`, compared equal, and each device kept its own.
4. **The concurrent tiebreak could not order them.** The canonical clock order
   that agent entities use on an `updatedAt` tie (`compareClocksCanonically`)
   also read absent as 0, returned 0 for that pair, and each replica kept its
   local version.

`AgentReplication.tla` modelled clocks with 0 standing for "absent" and
counters from 1, so it could not express this. Clocks now map a host to a
counter or to `Absent`. `FirstCounter` is a new host's first counter, and two
switches say how the receive path reads an absent host. With `FirstCounter =
0` and the old reading TLC finds `NoLostSuccessor` violated in two steps: B
writes its first version, `{B: 0}`, and C receives it and keeps the row it
had. With only the old canonical tiebreak it finds `Converged` violated: A
and B each write a first version at the same instant, and each keeps its own.

The sequence log counts from 1 as well. `SyncSequence.tla` hands out counters
`1..MaxCounter`, a watermark of 0 means nothing resolved, gap detection
materializes `watermark + 1 .. counter - 1`, and the contiguous-prefix
watermark counts from 1. A host's counter 0 was outside all of it: never
marked missing, and the watermark rebuild numbered a counter-0 row as the
first of the prefix. That shifted every later row by one. A contiguous run
`0..3` rebuilt to 0, and `0..3, 5` rebuilt to 5, past the hole at 4, which
gap detection would then never request.

## Decision

1. **An absent host ranks below every counter, 0 included.** A present entry
   says the host wrote. `VectorClock.compare` reads an absent host as -1, so a
   version extended by `host: 0` dominates the one it extends, and only
   identical clocks are `equal`. This fixes the receive side for the clocks
   already out there. Every host an older build created has counter 0 in its
   clocks, on every device and in every synced payload, and devices that have
   not updated keep sending them. Starting new hosts at 1 alone would leave
   all of those broken.
2. **One canonical order.** `VectorClock.compareCanonically` replaces the
   agent resolver's `compareClocksCanonically` and the link order's private
   comparator, with the same reading of an absent host. It is total, returns
   0 only for identical clocks and ranks a dominating clock higher.
3. **New hosts start at 1.** `VectorClockService` hands a new host
   `firstVectorClockCounter` (1) first. A host whose persisted watermark is
   still 0 has handed out nothing, because the watermark is persisted before
   a counter is returned, so it moves to 1 at startup. A host already past 0
   continues where it is. A device that has not updated still reads an
   absent host as 0, and a new host's first write, `host: 1`, dominates there
   too. The sequence log's numbering and its model now agree.
4. **The watermark rebuild counts from 1.** The prefix query ignores rows
   below counter 1.

## Consequences

- On a new or reinstalled device the first edit of each existing entry, link
  and agent row is saved and reaches every other device.
- A version that lacks only another host's counter 0 is now concurrent with
  that host's edit. For a journal entry that raises a `Conflict` the user
  resolves, where before one side was dropped silently. Agent entities merge
  it like any concurrent pair.
- Clocks that differ only by a 0 entry are no longer "the same version" to
  the sender's freshness checks (`MatrixPayloadSender` and the notification
  sender). They are different versions, and the check now says so.
- `AgentReplication.tla` checks the fix on both halves of a mixed fleet:
  `AgentReplicationLegacyCounter` (every host started at 0, received by this
  build) and `AgentReplicationLegacyReceiver` (hosts started at 1, received by
  a build that still reads absent as 0). The four existing configurations
  keep their state counts.
- Residual: two devices that both run a build older than this one still
  compare a new host's first write equal. Nothing on the receiving side can
  change that, and it ends as they update.
- Residual: a counter 0 that a host created by an older build handed out is
  outside gap detection, so if its message is lost it is never requested. It
  is that host's first write, usually superseded, and the next version of
  the same payload carries its clock.

## Related

- [ADR 0078](./0078-entry-link-versions-are-ordered.md) — the entry-link
  order, where this was first found
- [ADR 0068](./0068-model-checked-agent-convergence.md) — the agent receive
  order this corrects
- [ADR 0065](./0065-model-checked-sync-sequence-reservations.md) — the
  sequence-log numbering
- `specs/tla/AgentReplication.tla`, `specs/tla/README.md`
- [Vector clocks and conflicts](../../knowledge/features/sync/vector-clocks-and-conflicts.md)
- [Sequence log and backfill](../../knowledge/features/sync/sequence-and-backfill.md)
