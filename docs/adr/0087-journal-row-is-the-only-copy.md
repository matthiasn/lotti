# ADR 0087: The Journal Row Is the Only Copy of an Entry

- Status: Accepted
- Date: 2026-09-25
- Supersedes in part: [ADR 0083](./0083-model-checked-journal-replication.md) (its sidecar fixes, `RestoreSidecar` and `RefreshThroughQueue`)

## Context

Every applied journal write also wrote the entity to a JSON file in the
documents directory — the *sidecar*, `/<folder>/<yyyy-MM-dd>/<id>.<type>.json`
or `<media path>.json` next to an image or recording. It dated from when Lotti
was file-based, and sync used it as the payload: the outbox enqueue refreshed
it from the row and read it back, and the sender uploaded its bytes.

The row in `journal.serialized` was already authoritative. Keeping a second
copy of it in step cost:

- a per-entity ticket queue (`_publishSidecar`), so two accepted writes could
  not leave the earlier document on disk for the later row;
- `JournalDb.restoreSidecar`, called by the outbox before it read the payload
  and by a receive that refused a path-only envelope whose JSON the loader had
  saved over the file;
- a sender that re-read the file and fell back to the row whenever the file was
  missing or older than the queued version;
- a TLA+ invariant, `SidecarMatchesRow`, and two TLC configurations
  (`JournalReplicationSidecar`, `JournalReplicationSidecarRollback`) to prove
  all of that. ADR 0083 records two bugs where the file described a version
  the device did not hold.

The file is also a plaintext copy of every entry on disk, which defeats
encrypting the database.

## Decision

1. **Nothing writes a journal entry to a file.** `_publishSidecar`,
   `persistEntityJson`, `restoreSidecar`, `saveJournalEntityJson` and
   `readEntityFromJson` are deleted, with the ticket queue and `JournalDb`'s
   `documentsDirectory` parameter that only they used.
2. **Enqueue reads the stored row** (`journalEntityByIdIncludingDeleted`, a
   deletion included). A missing row fails the enqueue, as a failed refresh
   did before, so recovery cannot settle a counter against a payload that
   does not exist.
3. **The sender serializes the stored row** at send time. The row must cover
   the queued clock and every covered clock, as ADR 0086 requires; otherwise
   the send fails and the outbox retries it. A JSON file that an older build
   left at the path is ignored.
4. **The wire format is unchanged.** The upload keeps `jsonPath` as its
   `relativePath`, gzip and the `.json` name, so peers on older versions
   receive exactly what they did.
5. **The model follows.** `JournalReplication.tla` loses the sidecar, its
   queue, the outbox refresh and the path-only receive's separate
   prepare/apply/commit/rollback steps. With no file escaping the receive's
   transaction, a rolled-back receive is indistinguishable from a delivery not
   yet made, which `Deliver` already covers. The two sidecar configurations
   are deleted; the four others check the same five properties and reach the
   same state counts.

## Consequences

- The per-write file I/O and the sidecar ordering machinery are gone, and with
  them the class of bug where the payload and the row disagreed.
- Files written by older builds stay on disk until a later change sweeps them.
  `purgeDeletedFiles` still removes the ones next to deleted entries.
- Other JSON files remain for now and are separate changes: the legacy
  path-only receive and outbox-bundle materialization still write downloaded
  JSON to disk before reading it, and agent-entity and notification payloads
  still pass through files.
