# ADR 0110: A Clockless Row Is Covered When the Peer Read It

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
nothing at all, whatever the protocol around it did: fixes to the claim and
completion handling (#4544, #4562) changed nothing on a real pair of devices.

A watermark cannot help with these rows. They carry no counter, so nothing
says whether a peer ever received one. Deep backfill treats a clockless row
the peer lacks as something to request (#4557), so peers can differ here.

## Decision

A claim or completion also names the clockless rows its run read
(`clocklessInputs`, the input keys). A clockless row is covered when the peer
named it. Such a row was saved before its type carried a clock and has not
changed since, because an edit stamps one. A run that read it read the same
row this device holds. A row the peer did not name is not covered, and the
reason names it.

Every other input still has to be under the peer's watermark. In
`specs/tla/AgentWakeCoordination.tla` these rows are initial state, not
edits, so the model is unchanged.

## Consequences

- Coordination works on tasks with rows from before clocks, whenever both
  devices hold those rows.
- A device holding an old row that the peer lacks still runs. Its prompt
  includes that row, and the peer's run did not read it.
- The list is bounded by one task's neighbourhood. It travels on every claim
  and heartbeat.
- A 1.1.33 peer sends no list, so a device with clockless inputs runs beside
  it, as it did before.
- The *Vector clocks* recovery action still gives old links clocks, which
  deep backfill needs. Coordination no longer depends on it having been run.
