# ADR 0131: Current Builds Repair What Old Builds Left

- Status: Accepted
- Date: 2026-10-11

## Context

Five sync residuals were recorded as belonging to old builds, to end only as
devices update:

- **Arrival order on old receivers.** A build before #4517 (config flags) or
  #4537 (AI configurations) applies those in the order they arrive, so a
  stale message that lands after a newer one wins there (ADR 0094).
- **Counters burned under the wrong name.** Before ADR 0077 a create could
  reserve a counter under one id and write the entry under another;
  settlement then burned the counter, and peers never asked for the entry
  it carried. `burned` is terminal, so the entry waited for its next edit.
- **Purges without tombstones.** A build before #4534 removed a deleted row
  outright (ADR 0095). A device that missed the deletion keeps the entry,
  and a late copy of it, from that device or a deep backfill round, was
  stored again on the device that had purged it.
- **Media an old build cannot purge.** A tombstone was always a plain
  `JournalEntry`, so a build before #4534 that stored one in place of a
  deleted image or recording never found the file to delete.
- **Peers without media sizes.** A peer older than 1.1.34 lists no sizes in
  its inventory, so a truncated file on either side is never compared.

The first four can be narrowed from the current build; the last cannot: an
old receiver ignores a pushed copy of a file it already holds.

## Decision

- **A current device answers what an old receiver would get wrong.** On an
  unstamped config flag or AI configuration, the mark of an old sender, and
  on a stamped one older than the version it holds, which an old receiver
  would keep, it sends the version it holds. The newest version is then the
  last to arrive at the old device. A copy as new as the one held is no
  cause, so two current builds never answer each other. AI configurations
  go through the owed sender (ADR 0127); config flags through the outbox.
- **Burned own counters a payload carries are resent and rebound, once.**
  At startup, after the sequence log population, a device lists its own
  counters recorded as non-events without a payload and sweeps journal
  entries and entry links for a clock that carries one exactly. Each such
  payload is resent durably, then the row rebound to it; a row anything else
  bound meanwhile is left as it is. A settings flag records the sweep, set
  only when it returns.
- **A late copy of a purged entry is refused locally.** When a device holds
  no row for an entry and its sequence log shows it held a version of it at
  least as new as an incoming copy, the copy is not stored; its embedded
  links still apply. No tombstone is invented, so nothing propagates. The
  guard stands down for good on a device whose journal was ever restored
  from a backup — a kept `db.sqlite.corrupt-*` copy or the new
  `db.sqlite.restored` marker that a restore now writes — because a restore
  loses rows the sequence log still names that were never deleted.
- **Media tombstones keep their file.** A purge's tombstone of an image or
  an audio recording keeps its variant and the fields that name its file;
  every other entry still becomes a plain `JournalEntry`. A deleted entry no
  longer asks peers for its missing media.
- **Peers older than 1.1.34 stay as they are.** Nothing sent to them heals a
  truncated file they hold.

## Consequences

- A device that sees an old peer sends one more message per stale or
  unstamped flag or AI configuration it receives.
- A flag answer the outbox refuses is logged, not owed: config flags have
  no ledger, as their local edits have none either. The next stale or
  unstamped arrival answers again; a durable retry for flags belongs with
  the delivery of every payload that carries no sequence counter.
- The startup sweep reads the journal and links once per device.
- A device refuses a copy it would have stored before only when it held a
  version at least as new and was never restored; a concurrent edit
  recorded before the purge is refused with it.
- Tombstones already compacted have no file path, so their files on old
  builds stay orphaned; tombstones from now on carry it.
- Also fixed here, from a review of ADR 0127 and #4760: an AI configuration
  write is now owed before it commits rather than after (a flush while the
  write runs leaves the id owed, and the provider cascade owes outside its
  transaction, which a running flush would deadlock on), and the startup
  counter-0 resend is retried when the agent store it needs is not attached
  yet instead of being recorded as done.
