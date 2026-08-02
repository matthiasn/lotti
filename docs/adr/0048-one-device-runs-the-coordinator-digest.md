# ADR 0048: One device runs the coordinator digest

## Status

Accepted

## Date

2026-08-01

## Context

ADR 0032 specified the coordinator digest's *cadence* but never said which
device performs it. That gap had a cost. The digest is armed as a single synced
`scheduledWake` record with a deterministic id, so every device signed in to the
account saw the same record come due, and every device ran the same inference:
N devices, N model charges, one useful result, every window, forever.

It is a spend and battery problem rather than a correctness one — the digest's
writes are registers recomputed from source, so duplicate runs converge on the
same answer — but it recurs indefinitely and scales with how many devices a
person uses.

## Decision

A scheduled-wake record whose work is **shared** rather than device-local
carries a lease. The coordinator digest is the only such record today; per-day
agent wakes remain device-local and unleased.

A device that finds a leased record due writes `leaseHostId` and `leaseUntil`
into it, waits a settle period, re-reads the record, and proceeds only if the
surviving claim is still its own.

The election needs no coordinator because the record is already a
last-write-wins register: concurrent claims converge to exactly one surviving
host, and the settle period is what gives that convergence time to happen before
anyone acts on it. The lease expires, so a device that claims and then crashes or goes offline
before consuming the record delays the window rather than dropping it: any
device may take over past `leaseUntil`.

That recovery covers the claim, **not** the run. A device that crashes *after*
the record flips to `consumed` but before its in-memory job finishes loses that
day's briefing: cold-start bootstrap sees a consumed record and arms the next
day's slot rather than retrying today's. This predates the lease — it follows
from consuming the record before running — and is tracked separately rather
than fixed here.

`leaseUntil` is stored in **UTC**. Entities cross devices as JSON, and
`toIso8601String()` on a local `DateTime` emits no offset, so a peer's
`DateTime.parse` would re-read the same wall-clock components in its own zone: a
west-to-east claim would appear already expired and be taken over immediately —
both devices firing, the exact duplicate this lease exists to prevent — while
the opposite direction would stretch a 30-minute lease by hours. For the same
reason the settle is measured from `leaseUntil` minus the lease duration rather
than from `updatedAt`, which is serialized without an offset.

## Consequences

- **While devices can see each other's writes**, the digest costs one inference
  per window regardless of device count. That is the whole point of the change,
  and it is conditional on sync — see the third bullet for what happens when it
  is unavailable.
- A window can be delayed by up to `leaseDuration + leaseSettle` when a claimant
  dies immediately after claiming: the record stays claimed until `leaseUntil`,
  and the device that takes over then writes its own claim and waits out its own
  settle before firing. With the defaults that is about 33 minutes. It is never
  skipped.
- The lease is a **cost** mechanism, not a correctness one. It narrows the
  double-fire window rather than closing it: devices partitioned from sync while
  their model providers stay reachable can each hold a locally-consistent claim
  and both fire. That is acceptable because a duplicate digest is redundant
  spend, not a wrong result, and closing it fully would require a consensus
  round the app has no coordinator for.

## Related

- ADR 0032 (hierarchical day-agent coordination — establishes the digest and its
  cadence; this ADR fills in which device runs it)
- ADR 0022 (long-lived planner)
