# ADR 0110: A Clockless Row Counts as Covered

- Status: Accepted
- Date: 2026-09-27
- Amends: [ADR 0091](0091-wake-coordination-by-vector-clock-coverage.md)

## Context

ADR 0091 decided that a row among a wake's inputs without a vector clock is
never covered, which seemed the conservative choice. Entry links saved before
links carried a clock are common, though: thousands per database, as the
deep-backfill work in #4557 found. Any task with one such link — an early log
entry, an old time entry, the link to its project — could therefore never be
covered by any peer's run, on any device. On such tasks, coordination did
nothing at all, whatever the protocol around it did: three rounds of fixes to
the claim and completion handling (#4544, #4562) changed nothing on a real
pair of devices.

## Decision

A row without a vector clock counts as covered, like a row with an empty
clock. It was saved before its type carried a clock and has not been edited
since, because an edit stamps one. It carries no write that any peer's run
could lack. In the model it is part of the initial state every device holds,
not an edit, so `specs/tla/AgentWakeCoordination.tla` is unchanged.

A clockless row does not hide anything else: every other input still has to
be under the peer's watermark.

## Consequences

- Coordination works on tasks with rows from before clocks.
- If a peer never received such an old row, its run did not read it, and a
  covered device still stands down. That row predates clocks, and so it
  predates the wake that is being dropped: an earlier run on this device read
  it. The row is not new work.
- The *Vector clocks* recovery action still gives old links clocks, which
  deep backfill needs. Coordination no longer depends on it having been run.
