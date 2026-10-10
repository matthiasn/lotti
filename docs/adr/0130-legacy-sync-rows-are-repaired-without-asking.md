# ADR 0130: Legacy Sync Rows Are Repaired Without Asking

- Status: Accepted
- Date: 2026-10-10

## Context

Three kinds of rows written by older builds, or lost across a restart,
were left for the user or for luck to repair:

- **Clockless definitions and entry links.** ADR 0125 gave definitions a
  vector clock, and entry links had gained one earlier. Rows saved before
  then stay outside clock comparison and backfill until a device stamps
  them, which only the manual "Repair vector clocks" action did. A user
  who never pressed it kept them clockless on every device.
- **Unstamped config-flag rows.** Outbox rows queued before #4517 carry no
  stamp. The collapse would not order a stamped row against an unstamped
  one, so both were sent in enqueue order and the older value could
  arrive last.
- **The too-large bundle fallback.** After a bundle was too large, the
  outbox claimed its rows one at a time for a count it kept in memory. A
  restart bundled them again, failed by size again and fell back again.

## Decision

- **Each device stamps its clockless definitions and entry links once, at
  startup**, after the sequence log population, under the sync capability.
  A settings flag records completion and is set only when both repairs
  succeed, so a failure retries at the next start, and the inbound sync path clears it when it stores a clockless definition or link from an older peer, so the next start sweeps again. Both repairs keep the
  row's `updatedAt`, so two devices that stamp the same row settle it the
  same way and a stamp never outranks a genuine edit. Agent rows are not
  included: their stamp is dated now, and stays a manual repair.
- **An unstamped flag row ranks older than any stamped row of the same
  flag.** Every stamped row was written after the upgrade that introduced
  stamps, so a mixed pair folds into the stamped send. Two unstamped rows
  keep their enqueue order.
- **The fallback count is stored in settings** as it changes and read back
  on the first pass after a start.
- **A host resends its own counter-0 write once**, if it made one, since no
  peer would ever ask for it.

## Consequences

- The first start after this change sends one message per clockless
  definition and entry link the device holds; later starts send nothing.
- A legacy flag row superseded by a stamped one is never sent.
- One settings write per claim while the fallback runs, which happens only
  after a bundle too large to send.
- A host created by a build before #4470 issued counter 0 first, and if
  that write was lost no peer requests it: gap detection starts at 1, and
  requesting counter 0 of every host would put a phantom gap on every new
  one. The host itself knows, though. Once updated, it resends its own
  counter-0 payload once at startup, after the sequence log population
  (`BackfillResponseHandler.resendOwnCounterZero`), through the ordinary
  backfill answer; a host with no counter-0 row sends nothing, so no
  counter is burned that was never issued. A host still on an old build
  cannot, until it updates.
