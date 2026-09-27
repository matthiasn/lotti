# Deep backfill — a manual inventory round that repairs what counters cannot see

Status: **Phase 1 done (model checked), Phase 2 planned, not started.**

## The gap

Counter backfill (`SyncSequence.tla`, [sequence log and backfill](../../knowledge/features/sync/sequence-and-backfill.md))
repairs a hole between `(hostId, counter)` pairs that a device has recorded, and
the responder answers only a counter that its own `sync_sequence_log` maps to a
payload (`getEntryByHostAndCounter`). Old installations miss history that
neither side can name:

- "Populate sequence log" records only the counters in each row's *current*
  clock, so superseded counters never get a row on either side.
- Gap detection only runs for hosts in `host_activity` and for the originator.
- A record a device never heard of leaves no counter to be missing.

One real installation has ~300 records on one side and many more on the agent
node. Totals that small make advertising every record feasible.

## The protocol

A round is started by hand from the sync maintenance page. It is manual only
for now; a schedule can follow once it has proved itself.

1. **Inventory.** The device pages every synced record by id, **tombstones
   included**, and advertises `(payloadType, id, vectorClock)` in batches of
   5000. Each batch also carries the id range `[lo, hi)` it covers, and the
   clocks of any open conflict versions in that range. A batch is a gzipped
   JSON attachment (`m.file`), named by a new `syncInventory` message.
2. **Diff.** Each recipient runs **one range query per record table per batch**
   (`WHERE id >= :lo AND id < :hi`, primary-key range scan) and compares clocks
   in memory. There is no per-record lookup (no N+1).
   - The recipient lacks the record, or holds an older or concurrent version →
     **request** it from the advertiser. The one exception is a concurrent
     version the recipient already holds as an open conflict, which is skipped.
   - The recipient holds a newer or concurrent version → **push** it to the
     advertiser. This includes records the batch's range covers but does not
     list, i.e. records the advertiser has no row for. The exception is a
     version the advertiser lists as one of its open conflicts, which is
     skipped.
   - Equal → nothing.
3. **Answer.** The advertiser answers an id request with its current row,
   deletions included, through the existing `_answerFromEntry` path. Answers
   and pushes are ordinary `journalEntity` / `entryLink` / `agentEntity` / …
   messages, received through the one write decision. Nothing on the receive
   side is new.

Requests and pushes are **addressed to the advertiser**, not to the room. That
way several peers don't all answer one request.

## The model

[`specs/tla/DeepBackfill.tla`](../../specs/tla/DeepBackfill.tla) checks the
protocol with TLC before any code exists. Configurations, properties, state
counts and the counterexample of every design switch are in
[`specs/tla/README.md`](../../specs/tla/README.md#deepbackfill--an-inventory-round-that-repairs-what-counters-cannot-see).
Its properties:

- `EventuallyConverged`: every device ends up holding the union of all
  versions (tombstones included), with any divergence shown as a conflict
  rather than kept silently.
- `NoLostTombstone`.
- `NoDuplicateRequest`.
- `EventuallyQuiet`: no conflict ping-pong from round to round.
- `RoundTerminates`: the round finishes across batches, under loss and a
  crash mid-flow.

What the model showed, and the plan therefore requires:

- **Range bounds.** Without them a recipient cannot tell "absent on the
  advertiser" from "not in this batch", so a record only the recipient holds
  never travels when only one device runs maintenance.
- **Durable outstanding requests.** A crash that forgets which ids are already
  requested sends the same request twice.
- **Conflicts are advertised, and held conflicts are skipped.** Otherwise a
  pair of concurrent versions is re-sent on every round forever.
- **Every batch is processed.** Fairness per sender alone let a re-emitted
  batch starve another. The inbound queue's in-order processing is what
  provides per-batch fairness.

## Phase 2: model action → code

| Model action | Component | Notes |
|---|---|---|
| `StartRound` | "Deep backfill" action on `matrix_sync_maintenance_page.dart`, driving a new `DeepBackfillService` (getIt, in `get_it_sync.dart`) | Disabled while a round is running on this device, and off in the demo world (`InertOutboxService`) |
| `EmitBatch` | `DeepBackfillService` pages each table by id with a keyset query (`WHERE id > :last ORDER BY id LIMIT 5000`), reading only `id`, the clock (`json_extract(serialized, '$.meta.vectorClock')` / `'$.vectorClock'`, the notifications' `vector_clock` column) and the deletion flag | Tables: `journal`, `linked_entries`, `agent_entities`, `agent_links`, notifications, consumption events. One batch = one gzipped JSON file uploaded via `MatrixPayloadSender`, named by a new `SyncMessage.syncInventory(roundId, batch, payloadType, lo, hi, attachmentEventId)` variant. Clockless rows are left out (they cannot be ordered, `RefuseNullClock`) and counted in the round summary |
| `Diff` | A new `DeepBackfillReceiver`, called from the event processor for `syncInventory` | Per batch: download and decode the file; run one range query over the matching table; compare with `VectorClock.compare`; open conflicts come from the conflicts table in the same range. Requests, pushes and the outstanding rows are written in **one transaction** with the outbox enqueue |
| `Req` | New `SyncMessage.recordRequest(payloadType, idsAttachmentEventId, targetHostId, requesterId)` | The id list travels as an attachment: a 5000-id list is far past Matrix's 64 KB text-event limit, which the existing 2000-entry `backfillRequest` is suspected to exceed as well (to verify separately) |
| `out` (durable) | New sync-DB table `deep_backfill_requests(target_host_id, payload_type, id, requested_at)` | Cleared by the answer, and expired after a timeout longer than a delivery (the model's `Expire`) |
| `Answer` | `BackfillResponseHandler` gains an id-keyed entry that loads with `…IncludingDeleted` and reuses `_answerFromEntry` | Rate limit and cooldown per `(requester, id)`. Answers only when `targetHostId` is this host |
| `Push` | Same enqueue as `Answer`: `journalEntity(status: update)` etc., addressed by `targetHostId` | A push the advertiser no longer needs is refused by the write decision |
| `Receive` | Unchanged: `JournalDb.updateJournalEntity` / `detectConflict`, the agent and link receive paths | The model reuses the journal decision of ADR 0083/0092 and the merge for agent records |

Tests follow the repository's contract: one test file per source file. There
will also be a Glados conformance trace in the style of
`backfill_response_handler_model_conformance.dart`, driving the diff over
in-memory databases and checking `NoDuplicateRequest` and the union after
quiescence.

## Deliberately out of scope

- Scheduling. The round is manual. A periodic trigger needs only
  `StartRound` to be fair, which is what the liveness properties already
  assume.
- Relays. Only the advertiser answers its own inventory; a third device's copy
  reaches the requester in that device's own round.
- Clockless legacy rows.
- The sequence log. A deep-backfilled version is recorded like any received
  payload. Rows the log still lacks are not reconstructed.
