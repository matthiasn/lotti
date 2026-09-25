# ADR 0086: The Outbox Appends One Row per Version and Collapses at Send Time

- Status: Accepted
- Date: 2026-09-25
- Supersedes in part: [ADR 0085](./0085-model-checked-outbox.md) (its enqueue-time merge fixes)

## Context

Until now the outbox merged at enqueue time: an enqueue looked up the entity's
pending row (`findPendingByEntryId`) and rewrote it with the new payload and
the union of covered clocks, or inserted a fresh row, enriched from the
sequence log's last sent counter, when there was none. ADR 0085 model-checked
that merge (`specs/tla/Outbox.tla`) and patched three holes in it: two
enqueues of one entity interleaving between the read and the write lost a
counter, a late enqueue put an older inline payload back, and the enrichment
covered a counter newer than the payload. The patches were a per-entity
enqueue lock, a newest-wins guard and a dominance check on the enrichment.

Each patch guarded a read-modify-write that did not need to exist. The merge
made every enqueue read before it wrote, kept a lock so no two enqueues of an
entity overlapped, ran a sequence-log query (40–600 ms on large logs) to
enrich fresh rows, and carried a `filePath` promotion so a merged row kept
owing its attachment. ADR 0085 also left a residual: a row that reached
`error` stayed retryable after newer versions of its entity had gone out, so
the monitor's Retry sent a stale value last.

The processor is already the single serialized drain point, and it already
turns consecutive rows into one bundle. Coalescing belongs there.

## Decision

1. **Enqueue is a plain append.** Every version of every entity is its own
   immutable row, keyed by its outbox entry id, with its own counter. Journal
   entities, entry links, agent entities and links, and config flags lose
   their merge paths; the writer no longer reads the outbox. The per-entity
   lock (`_serializedByKey`), the newest-wins guard, the covered-clock race
   handling of the journal merge, `findPendingByEntryId`,
   `updateOutboxMessage` and its `filePath` promotion are deleted.
2. **The processor collapses at send time.** For every entity with a claimed
   row, `OutboxProcessor._collapse` reads the entity's other pending and
   failed rows (`collapsibleOutboxRows`), picks the newest version by vector
   clock — or, for a clockless payload such as a config flag, the one
   enqueued last — and claims every row that version supersedes
   (`claimOutboxRows`, a compare-and-set on the status read). One message
   goes out: the newest payload, covering every folded row's counter, with
   `includeAttachments` set when any folded row owed the attachment. Every
   folded row is marked sent with it, or retried with it. A row whose clock
   is concurrent with the newest is not folded; it is sent on its own. The
   pure rules live in `outbox_collapse.dart`.
3. **An attachment still goes up exactly once, and never gets lost.** A row
   owes the attachment when its `filePath` is set (status `initial`,
   `includeAttachments`, or the resend flag, as before). An audio entry and
   the location update that follows it before the first send go out as one
   send of the update, carrying the audio; a later edit ships JSON only. A
   bundle ships JSON only, so a bundled send does not fold in rows that owe
   an attachment; they go out alone.
4. **A newer send settles the entity's failed rows** — ADR 0085's residual 2.
   Failed rows are collapse candidates like pending ones, so once a newer
   version of the entity is sent, the superseded failure is marked sent with
   it (its counter covered) instead of staying retryable with a stale value.
   A failed row that is not superseded — the newest version — stays in
   `error` and retryable as before. The monitor needs no change: a settled
   row simply leaves the failed list.
5. **The sequence-log enrichment goes.** With one row per counter, every
   counter reaches the room as a payload or as a covered clock of its
   entity's collapsed send, so fresh rows no longer look up the last sent
   counter. `SyncSequenceLogService.getLastSentVectorClockForEntry`, the
   last-sent LRU in `SyncSequenceCache` and
   `SyncDatabase.getLastSentCounterForEntry` are deleted with it.
6. **A stale journal sidecar is not sent.** Without the lock, two enqueues of
   one entry can refresh its JSON sidecar out of order. When the sidecar's
   clock does not cover the queued version, `MatrixPayloadSender` sends the
   canonical database row instead, or fails the send for a retry when that
   does not cover it either. Before, it adopted the sidecar's older clock
   and covered the newer counter — the `CoversOnlyOlder` hole again.
7. ADR 0085's orphan release before each drain and its dispose quiesce stay.
   `Outbox.tla` models the new design; its switches are `NewestByClock`,
   `CoverCollapsed`, `CarryMedia` and `AbsorbErrorRows` beside the two kept
   from 0085, and a Glados trace in the enqueue writer's suite drives the
   real writer, database, repository and processor through append-and-
   collapse interleavings.

## Consequences

- Concurrent enqueues of one entity cannot lose anything: there is nothing
  to overwrite. An enqueue is one insert and a sequence-log write; the
  outbox read and the sequence-log lookup on the enqueue path are gone.
- The counter-to-row binding `SyncSequence.tla` assumes is now 1:1, and its
  `OutboxSend` — the newest counter of an entity's pending set, covering the
  rest — is exactly the collapse.
  `OwnCounterSettlement.tla`'s resend path is an ordinary append.
- The outbox grows by one row per version rather than per entity between
  sends. Rows are small, pruned seven days after sending, and collapsed
  into one Matrix event, so the room sees no more traffic than before.
- A send costs up to two more lookups per entity in the batch (the collapse
  candidates and their claim), on the partial pending index and the few
  failed rows.
- `idx_sync_sequence_log_host_entry_status_counter` now serves no query.
  Dropping it needs a schema migration, left to the next one that touches
  that table.
- **Residual (ADR 0085's residual 1, unchanged):** a send abandoned at its
  timeout can land after a newer one. Options are unchanged: a stable Matrix
  transaction id per row, a clock or timestamp for the payloads applied in
  arrival order, or no timeout while the SDK still retries.
- **Residual:** a bundle does not settle a failed row that owes an
  attachment (decision 3), so a later Retry sends that older journal version
  with its attachment after a newer one. Receivers order journal JSON by
  clock, so only the attachment takes effect.
- **Residual:** removing the newer row in the monitor and then retrying an
  older one sends the older value last. That is the user's own reversal,
  behind a confirmation.

## Verification

Five TLC configurations check the design: `Outbox` (in order, with an
attachment), `OutboxConcurrent` and `OutboxConcurrentLive` (any order),
`OutboxOperator` (the monitor's Retry, claiming `NewestLandsLast`) and
`OutboxGhost` (late landings). Turning off each of the four new switches
breaks `CoversOnlyOlder`, `NoLostCounter`, `MediaNotDropped` or
`NewestLandsLast` in 5 to 15 steps. TLC's first run of the collapse caught
an over-broad attachment rule — a bundle skipped the whole entity when one
of its other rows owed an attachment, so an older version could land after a
newer one; the rule now leaves out only the rows that owe it.
The regressions are in `outbox_processor_test.dart` (collapse),
`outbox_collapse_test.dart`, `outbox_enqueue_writer_test.dart` (appends),
`sync_db_outbox_dedup_test.dart` (the lookups) and
`matrix_message_sender_test.dart` (the stale sidecar); the conformance trace
fails with each collapse rule reverted. `specs/tla/README.md` has the traces.

## Related

- [ADR 0085](./0085-model-checked-outbox.md): the model, the orphan release
  and the dispose quiesce this design keeps.
- [ADR 0065](./0065-model-checked-sync-sequence-reservations.md): the
  sequence log whose counters the rows carry.
- `specs/tla/Outbox.tla`, `knowledge/features/sync/send-path.md`.
