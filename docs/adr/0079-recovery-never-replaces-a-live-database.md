# ADR 0079: Recovery Never Replaces a Database Another Connection Can Read

- Status: Accepted
- Date: 2026-09-25

## Context

`openDbConnection` runs `recoverDatabaseIfUnreadable` before it builds a
connection. If `isReadableDatabaseFile` says the file cannot be read,
recovery moves the file aside and puts the newest backup in its place. The
backup is older than the file, so a wrong verdict is data loss.

PR #4464 made the probe open the file `immutable`. A normal read-write
connection deletes the `-wal` and `-shm` when it closes beside a file that is
not a database, and immutable reads never touch them. But immutable also
skips locking and change detection. It reads the main file as it is on disk
at that moment, and SQLite's normal readers do not. If another connection is
checkpointing, a page of the main file can be half-written. An immutable read
of that page can fail with `SQLITE_NOTADB` or `SQLITE_CORRUPT`, and both mean
"unreadable".

Nothing ensures that the probe's process is the only one with the file open:

- **Other processes.** The desktop builds have no single-instance lock. A
  second instance opens the same profile's databases while the first still
  writes and checkpoints them.
- **Other handles in the same process.** Every Drift database is a
  `LazyDatabase`, and any second handle on the same file runs the probe when
  it opens. Examples are a non-active world opened through `WorldHandle`, or a
  store opened again during a generation switch. The design keeps these apart,
  but no code enforces it.

A deterministic test shows the torn read. A live WAL writer has every commit
in its WAL, and the main file's header is overwritten as a half-written
checkpoint would leave it. The immutable look reports "not a database". A
locking reader reads the same database whole, because it takes page 1 from
the WAL.

## Decision

1. **An unreadable verdict needs two looks that agree.** The immutable look
   runs first, and almost every launch stops there with "readable". Only when
   it fails is the file checked again, read-only (`mode=ro`), with SQLite's
   normal locking and a two-second busy timeout.
   - A locking reader sees a consistent snapshot, so a database that another
     connection can read always passes.
   - A read-only connection that closes beside a non-database leaves the
     `-wal` in place. It may rebuild the `-shm`, which is only an index of the
     WAL.
   - A lock it still cannot get after the timeout is not a corruption verdict,
     so the file counts as readable.
2. **The file is checked again right before it is moved aside.** Copying the
   snapshot takes time. A file that reads by then is left in place, and the
   staged copy is removed.
3. **Every probe connection is closed before it returns** (as in PR #4464).

## Consequences

- A healthy database is never replaced because another process or connection
  was checkpointing while the probe ran. Regression tests cover a live WAL
  database with a torn main file, both through the probe and through the
  whole recovery. Removing the second look, making it read-write, or skipping
  the recheck before the rename each makes a test fail.
- A truly damaged file fails both looks, so recovery still restores it.
- Only the damaged-file path pays for the second look: one more open, plus up
  to two seconds if a lock is held.
- **Residual:** a file that becomes damaged between the final recheck and the
  rename is still replaced. That is the case recovery exists for.

## Related

- `lib/database/common.dart` (`isReadableDatabaseFile`,
  `restoreDatabaseFromBackup`, `recoverDatabaseIfUnreadable`)
- [Persistence layer](../../knowledge/architecture/persistence.md)
- [ADR 0077](./0077-a-reservation-names-the-id-written.md) — the PR (#4464)
  that introduced the immutable probe
